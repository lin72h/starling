// drm_screenshot — Captures the active DRM framebuffer to a PPM file.
// Works on AMD/Intel/VMware by importing the scanout buffer via EGL.
//
// Build: gcc -o drm_screenshot drm_screenshot.c -ldrm -lgbm -lEGL -lGLESv2
// Usage: sudo ./drm_screenshot [/dev/dri/card1] [output.ppm]

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

#include <xf86drm.h>
#include <xf86drmMode.h>
#include <gbm.h>

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>

#ifndef EGL_PLATFORM_GBM_MESA
#define EGL_PLATFORM_GBM_MESA 0x31D7
#endif

int main(int argc, char** argv) {
    const char* card = argc > 1 ? argv[1] : "/dev/dri/card1";
    const char* output = argc > 2 ? argv[2] : "/tmp/drm_screenshot.ppm";

    // 1. Open DRM device.
    int drm_fd = open(card, O_RDWR);
    if (drm_fd < 0) {
        fprintf(stderr, "Failed to open %s: %s\n", card, strerror(errno));
        return 1;
    }

    // 2. Find active CRTC with a framebuffer.
    drmModeRes* res = drmModeGetResources(drm_fd);
    if (!res) {
        fprintf(stderr, "drmModeGetResources failed\n");
        close(drm_fd);
        return 1;
    }

    uint32_t fb_id = 0;
    uint32_t crtc_id = 0;
    for (int i = 0; i < res->count_crtcs; i++) {
        drmModeCrtc* crtc = drmModeGetCrtc(drm_fd, res->crtcs[i]);
        if (crtc && crtc->buffer_id) {
            fb_id = crtc->buffer_id;
            crtc_id = crtc->crtc_id;
            fprintf(stderr, "Found active CRTC %u with FB %u\n", crtc_id, fb_id);
            drmModeFreeCrtc(crtc);
            break;
        }
        if (crtc) drmModeFreeCrtc(crtc);
    }
    drmModeFreeResources(res);

    if (!fb_id) {
        fprintf(stderr, "No active framebuffer found\n");
        close(drm_fd);
        return 1;
    }

    // 3. Get framebuffer info.
    drmModeFB2* fb = drmModeGetFB2(drm_fd, fb_id);
    if (!fb) {
        fprintf(stderr, "drmModeGetFB2 failed\n");
        close(drm_fd);
        return 1;
    }

    uint32_t w = fb->width, h = fb->height;
    uint32_t stride = fb->pitches[0];
    uint32_t fourcc = fb->pixel_format;
    fprintf(stderr, "FB: %ux%u stride=%u format=%.4s\n", w, h, stride, (char*)&fourcc);

    // 4. Export GEM handle to DMA-BUF fd.
    int dmabuf_fd = -1;
    if (drmPrimeHandleToFD(drm_fd, fb->handles[0], DRM_RDWR, &dmabuf_fd) != 0) {
        fprintf(stderr, "drmPrimeHandleToFD failed: %s\n", strerror(errno));
        drmModeFreeFB2(fb);
        close(drm_fd);
        return 1;
    }
    fprintf(stderr, "DMA-BUF fd=%d\n", dmabuf_fd);

    // 5. Create GBM device on render node for EGL.
    // Use the same card fd (we have DRM master).
    struct gbm_device* gbm = gbm_create_device(drm_fd);
    if (!gbm) {
        fprintf(stderr, "gbm_create_device failed\n");
        close(dmabuf_fd);
        drmModeFreeFB2(fb);
        close(drm_fd);
        return 1;
    }

    // 6. Initialize EGL.
    PFNEGLGETPLATFORMDISPLAYEXTPROC eglGetPlatformDisplayEXT =
        (PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress("eglGetPlatformDisplayEXT");
    EGLDisplay egl_display = EGL_NO_DISPLAY;
    if (eglGetPlatformDisplayEXT) {
        egl_display = eglGetPlatformDisplayEXT(EGL_PLATFORM_GBM_MESA, gbm, NULL);
    }
    if (egl_display == EGL_NO_DISPLAY) {
        egl_display = eglGetDisplay((EGLNativeDisplayType)gbm);
    }
    if (egl_display == EGL_NO_DISPLAY) {
        fprintf(stderr, "eglGetDisplay failed\n");
        goto cleanup;
    }

    EGLint major, minor;
    if (!eglInitialize(egl_display, &major, &minor)) {
        fprintf(stderr, "eglInitialize failed\n");
        goto cleanup;
    }
    fprintf(stderr, "EGL %d.%d\n", major, minor);

    eglBindAPI(EGL_OPENGL_ES_API);

    // Surfaceless config.
    const EGLint config_attribs[] = {
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
        EGL_NONE,
    };
    EGLConfig config;
    EGLint num_configs;
    eglChooseConfig(egl_display, config_attribs, &config, 1, &num_configs);

    const EGLint ctx_attribs[] = { EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE };
    EGLContext ctx = eglCreateContext(egl_display, config, EGL_NO_CONTEXT, ctx_attribs);
    if (ctx == EGL_NO_CONTEXT) {
        fprintf(stderr, "eglCreateContext failed\n");
        goto cleanup;
    }

    if (!eglMakeCurrent(egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE, ctx)) {
        fprintf(stderr, "eglMakeCurrent failed\n");
        goto cleanup;
    }

    // 7. Import DMA-BUF as EGLImage.
    PFNEGLCREATEIMAGEKHRPROC eglCreateImageKHR =
        (PFNEGLCREATEIMAGEKHRPROC)eglGetProcAddress("eglCreateImageKHR");
    PFNEGLDESTROYIMAGEKHRPROC eglDestroyImageKHR =
        (PFNEGLDESTROYIMAGEKHRPROC)eglGetProcAddress("eglDestroyImageKHR");
    PFNGLEGLIMAGETARGETTEXTURE2DOESPROC glEGLImageTargetTexture2DOES =
        (PFNGLEGLIMAGETARGETTEXTURE2DOESPROC)eglGetProcAddress("glEGLImageTargetTexture2DOES");

    if (!eglCreateImageKHR || !eglDestroyImageKHR || !glEGLImageTargetTexture2DOES) {
        fprintf(stderr, "Missing EGL image extensions\n");
        goto cleanup;
    }

    // XRGB8888 = DRM_FORMAT_XRGB8888 = 0x34325258
    const EGLint img_attribs[] = {
        EGL_WIDTH, (EGLint)w,
        EGL_HEIGHT, (EGLint)h,
        EGL_LINUX_DRM_FOURCC_EXT, (EGLint)fourcc,
        EGL_DMA_BUF_PLANE0_FD_EXT, dmabuf_fd,
        EGL_DMA_BUF_PLANE0_OFFSET_EXT, (EGLint)fb->offsets[0],
        EGL_DMA_BUF_PLANE0_PITCH_EXT, (EGLint)stride,
        EGL_NONE,
    };
    EGLImageKHR image = eglCreateImageKHR(egl_display, EGL_NO_CONTEXT,
                                           EGL_LINUX_DMA_BUF_EXT, NULL, img_attribs);
    if (image == EGL_NO_IMAGE_KHR) {
        fprintf(stderr, "eglCreateImageKHR failed: 0x%x\n", eglGetError());
        goto cleanup;
    }
    fprintf(stderr, "EGLImage created\n");

    // 8. Bind to texture + FBO.
    GLuint tex, fbo_id;
    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);
    glEGLImageTargetTexture2DOES(GL_TEXTURE_2D, image);

    glGenFramebuffers(1, &fbo_id);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo_id);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex, 0);

    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        fprintf(stderr, "FBO incomplete: 0x%x\n", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        goto cleanup;
    }

    // 9. Read pixels.
    uint8_t* pixels = (uint8_t*)malloc(w * h * 4);
    glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    fprintf(stderr, "glReadPixels done\n");

    // 10. Save as PPM. The EGLImage-backed FBO reads top-down (not flipped).
    // Format from glReadPixels GL_RGBA: R, G, B, A.
    // But XRGB8888 imported as EGLImage may read as B, G, R, X — try both.
    {
        FILE* f = fopen(output, "wb");
        if (!f) {
            fprintf(stderr, "Failed to open %s: %s\n", output, strerror(errno));
            free(pixels);
            goto cleanup;
        }
        fprintf(f, "P6\n%u %u\n255\n", w, h);
        // Detect channel order: check if first non-black pixel looks BGR.
        // For XRGB8888 surfaces, EGL typically gives us BGRA in GL_RGBA reads.
        int swap_rb = 0;  // AMD EGLImage gives RGBA directly for XRGB8888.
        for (uint32_t y = 0; y < h; y++) {
            for (uint32_t x = 0; x < w; x++) {
                uint8_t* p = pixels + (y * w + x) * 4;
                uint8_t rgb[3];
                if (swap_rb) {
                    rgb[0] = p[2]; rgb[1] = p[1]; rgb[2] = p[0];  // BGR→RGB
                } else {
                    rgb[0] = p[0]; rgb[1] = p[1]; rgb[2] = p[2];
                }
                fwrite(rgb, 1, 3, f);
            }
        }
        fclose(f);
        fprintf(stderr, "Saved to %s (%ux%u, swap_rb=%d)\n", output, w, h, swap_rb);
    }
    free(pixels);

    // Cleanup.
    glDeleteFramebuffers(1, &fbo_id);
    glDeleteTextures(1, &tex);
    eglDestroyImageKHR(egl_display, image);

cleanup:
    if (egl_display != EGL_NO_DISPLAY) {
        eglMakeCurrent(egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        eglTerminate(egl_display);
    }
    if (gbm) gbm_device_destroy(gbm);
    close(dmabuf_fd);
    drmModeFreeFB2(fb);
    close(drm_fd);
    return 0;
}
