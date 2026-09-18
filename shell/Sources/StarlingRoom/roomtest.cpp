// A stand-alone check of the room renderer, with no shell: stands in for
// the engine (a GBM EGL display and an ES context on the render node),
// renders one frame through libstarling_room into a texture, reads it
// back and writes it out as a PPM.
//
//   roomtest <room.glb> <ibl.ktx> <skybox.ktx> <out.ppm> [w h] [x y z yaw pitch]
#include "starling_room.h"

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES3/gl3.h>
#include <gbm.h>

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <unistd.h>
#include <vector>
#include <chrono>

static double nowMs() {
    using namespace std::chrono;
    return duration<double, std::milli>(steady_clock::now().time_since_epoch()).count();
}

// The shell's lens and look-at, transcribed from EnvironmentRenderer.swift.
static void projection(float* m, double aspect, double tanHalfFovX, double n, double f) {
    double tx = tanHalfFovX, ty = tanHalfFovX / aspect;
    memset(m, 0, 16 * sizeof(float));
    m[0] = float(1 / tx);
    m[5] = float(1 / ty);
    m[10] = float(-(f + n) / (f - n));
    m[11] = -1;
    m[14] = float(-2 * f * n / (f - n));
}
static void viewMatrix(float* m, double x, double y, double z, double yaw, double pitch) {
    double cy = cos(-yaw), sy = sin(-yaw), cp = cos(-pitch), sp = sin(-pitch);
    double r[9] = { cy, 0, -sy, sp * sy, cp, sp * cy, cp * sy, -sp, cp * cy };
    memset(m, 0, 16 * sizeof(float));
    for (int col = 0; col < 3; col++)
        for (int row = 0; row < 3; row++) m[col * 4 + row] = float(r[row * 3 + col]);
    m[12] = float(-(r[0] * x + r[1] * y + r[2] * z));
    m[13] = float(-(r[3] * x + r[4] * y + r[5] * z));
    m[14] = float(-(r[6] * x + r[7] * y + r[8] * z));
    m[15] = 1;
}

int main(int argc, char** argv) {
    if (argc < 5) { fprintf(stderr, "usage: see source\n"); return 2; }
    int W = argc > 6 ? atoi(argv[5]) : 1280, H = argc > 6 ? atoi(argv[6]) : 800;
    double cx = 0, cy = 1.68, cz = 9.3, yaw = 0, pitch = 0;
    if (argc > 11) { cx = atof(argv[7]); cy = atof(argv[8]); cz = atof(argv[9]);
                     yaw = atof(argv[10]) * M_PI / 180; pitch = atof(argv[11]) * M_PI / 180; }

    const char* node = getenv("ROOMTEST_NODE") ? getenv("ROOMTEST_NODE") : "/dev/dri/renderD128";
    int fd = open(node, O_RDWR | O_CLOEXEC);
    if (fd < 0) { perror(node); return 1; }
    gbm_device* gbm = gbm_create_device(fd);
    auto gpd = (PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress("eglGetPlatformDisplayEXT");
    EGLDisplay dpy = gpd(EGL_PLATFORM_GBM_MESA, gbm, nullptr);
    EGLint maj, min;
    if (!eglInitialize(dpy, &maj, &min)) { fprintf(stderr, "eglInitialize failed\n"); return 1; }
    eglBindAPI(EGL_OPENGL_ES_API);
    EGLint attrs[] = { EGL_SURFACE_TYPE, EGL_WINDOW_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT, EGL_NONE };
    EGLConfig cfg; EGLint n = 0;
    eglChooseConfig(dpy, attrs, &cfg, 1, &n);
    EGLint cattrs[] = { EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE };   // what the engine asks for
    EGLContext ctx = eglCreateContext(dpy, cfg, EGL_NO_CONTEXT, cattrs);
    if (!eglMakeCurrent(dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, ctx)) {
        fprintf(stderr, "makeCurrent failed 0x%x\n", eglGetError()); return 1;
    }
    fprintf(stderr, "engine-side context: %s\n", glGetString(GL_VERSION));

    // The texture the registry would have made: RGBA8, nearest.
    GLuint tex = 0;
    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, W, H, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glBindTexture(GL_TEXTURE_2D, 0);

    double t0 = nowMs();
    sr_room* room = sr_room_create(dpy, ctx);
    if (!room) return 1;
    fprintf(stderr, "engine up in %.0f ms\n", nowMs() - t0);
    if (sr_room_load(room, argv[1], argv[2], argv[3]) != 0) return 1;

    float sunDir[3] = { 0.35f, 0.45f, -0.82f }, sunCol[3] = { 1.0f, 0.95f, 0.85f };
    if (getenv("ROOMTEST_SUN")) {
        sscanf(getenv("ROOMTEST_SUN"), "%f,%f,%f", &sunDir[0], &sunDir[1], &sunDir[2]);
    }
    float sunLux = getenv("ROOMTEST_SUN_LUX") ? atof(getenv("ROOMTEST_SUN_LUX")) : 100000.0f;
    float iblLux = getenv("ROOMTEST_IBL_LUX") ? atof(getenv("ROOMTEST_IBL_LUX")) : 30000.0f;
    sr_room_set_light(room, sunDir, sunCol, sunLux, iblLux);
    if (getenv("ROOMTEST_EXPOSURE")) {
        float a = 16, s = 1.0f / 125, iso = 100;
        sscanf(getenv("ROOMTEST_EXPOSURE"), "%f,%f,%f", &a, &s, &iso);
        sr_room_set_exposure(room, a, s, iso);
    }
    if (sr_room_set_output(room, tex, W, H) != 0) return 1;

    // ROOMTEST_PANE=1: hang a test picture (a gradient with a checker
    // corner) on the left wall and look straight at it from the 1:1 spot.
    GLuint paneTex = 0;
    if (getenv("ROOMTEST_PANE")) {
        const int tw = 512, th = 320;
        std::vector<unsigned char> px(size_t(tw) * th * 4);
        for (int y = 0; y < th; y++) for (int x = 0; x < tw; x++) {
            unsigned char* p = &px[(size_t(y) * tw + x) * 4];
            bool checker = x < 128 && y < 128 && (((x / 16) + (y / 16)) & 1);
            p[0] = checker ? 255 : (unsigned char)(x * 255 / tw);   // red across
            p[1] = checker ? 255 : (unsigned char)(y * 255 / th);   // green down (row 0 = bottom in GL)
            p[2] = checker ? 255 : 40;
            p[3] = 255;
        }
        glGenTextures(1, &paneTex);
        glBindTexture(GL_TEXTURE_2D, paneTex);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, tw, th, 0, GL_RGBA, GL_UNSIGNED_BYTE, px.data());
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glBindTexture(GL_TEXTURE_2D, 0);
        glFinish();
        float c[3] = { -3.955f, 1.6f, 1.5f };
        const float s = 0.0019f;
        if (sr_room_set_pane(room, 1, c, float(M_PI / 2), 1280 * s, 800 * s,
                             -38 / 2.0f * s, 1280 * s, (800 - 38) * s,
                             paneTex, tw, th, 0, 1) != 0) return 1;
        cx = -3.955 + 3.47; cy = 1.6; cz = 1.5; yaw = -M_PI / 2; pitch = 0;
    }

    float proj[16], view[16];
    projection(proj, double(W) / H, 0.7002, 0.08, 4000.0);
    viewMatrix(view, cx, cy, cz, yaw, pitch);
    sr_room_set_camera(room, view, proj, 0.08f, 4000.0f);

    int frames = getenv("ROOMTEST_FRAMES") ? atoi(getenv("ROOMTEST_FRAMES")) : 3;
    for (int i = 0; i < frames; i++) {
        double f0 = nowMs();
        if (sr_room_render(room) != 0) return 1;
        fprintf(stderr, "render %d: %.1f ms\n", i, nowMs() - f0);
    }

    // Read it back through an FBO in the engine-side context.
    GLuint fbo = 0;
    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex, 0);
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        fprintf(stderr, "readback FBO incomplete\n"); return 1;
    }
    std::vector<unsigned char> px(size_t(W) * H * 4);
    glReadPixels(0, 0, W, H, GL_RGBA, GL_UNSIGNED_BYTE, px.data());
    FILE* f = fopen(argv[4], "wb");
    fprintf(f, "P6\n%d %d\n255\n", W, H);
    // GL row 0 is the bottom of the screen and a PPM starts at the top,
    // so write the rows last to first: an upright picture here is an
    // upright room on the desktop.
    for (int y = H - 1; y >= 0; y--) {
        const unsigned char* row = &px[size_t(y) * W * 4];
        for (int x = 0; x < W; x++) fwrite(row + x * 4, 1, 3, f);
    }
    fclose(f);
    long sum = 0;
    for (size_t i = 0; i < px.size(); i += 4) sum += px[i] + px[i + 1] + px[i + 2];
    fprintf(stderr, "wrote %s, mean %.1f\n", argv[4], double(sum) / (px.size() / 4 * 3));
    sr_room_destroy(room);
    return 0;
}
