// Drive the REAL vaapi_encoder.c through its public API with real dmabufs at
// the real recording resolution. Whatever the shell hits, this should hit.
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <va/va.h>
#include <va/va_drm.h>
#include <va/va_drmcommon.h>
#include "include/vaapi_encoder.h"

#ifndef W
#define W 2560
#endif
#ifndef H
#define H 1600
#endif
#define NF 60
#define CK(st,w) do{VAStatus _s=(st); if(_s!=VA_STATUS_SUCCESS){fprintf(stderr,"%s: %s\n",w,vaErrorStr(_s));return 1;}}while(0)

int main(int argc, char** argv) {
    const char* node = "/dev/dri/renderD129";
    const char* out = argc > 1 ? argv[1] : "real.mp4";
    int fd = open(node, O_RDWR|O_CLOEXEC); if (fd<0) return 1;
    VADisplay dpy = vaGetDisplayDRM(fd);
    int mj,mn; CK(vaInitialize(dpy,&mj,&mn),"init");

    // A pool of BGRA surfaces exported as dmabufs — the capture ring's shape.
    enum { RING = 4 };
    VASurfaceID s[RING]; VADRMPRIMESurfaceDescriptor d[RING];
    VASurfaceAttrib fmt = {.type=VASurfaceAttribPixelFormat,.flags=VA_SURFACE_ATTRIB_SETTABLE,
        .value={.type=VAGenericValueTypeInteger,.value={.i=VA_FOURCC_BGRX}}};
    CK(vaCreateSurfaces(dpy,VA_RT_FORMAT_RGB32,W,H,s,RING,&fmt,1),"surfaces");
    for (int i=0;i<RING;i++)
        CK(vaExportSurfaceHandle(dpy,s[i],VA_SURFACE_ATTRIB_MEM_TYPE_DRM_PRIME_2,
                                 VA_EXPORT_SURFACE_READ_WRITE,&d[i]),"export");

    printf("probe: %d\n", vaapi_encoder_probe(node));
    VaapiEncoder* e = vaapi_encoder_open(node, W, H, W, H, 30, 24, out);
    if (!e) { fprintf(stderr,"open failed\n"); return 1; }

    for (int f=0; f<NF; f++) {
        VASurfaceID cur = s[f % RING];
        VAImage img; CK(vaDeriveImage(dpy,cur,&img),"derive");
        uint8_t* p; CK(vaMapBuffer(dpy,img.buf,(void**)&p),"map");
        // High-entropy moving content, so the encoder has real work to do.
        for (int y=0;y<H;y+=1) {
            uint8_t* row = p + img.offsets[0] + y*img.pitches[0];
            for (int x=0;x<W;x++) {
                uint32_t v = (uint32_t)(x*7 + y*13 + f*97) * 2654435761u;
                row[x*4+0]=(uint8_t)(v>>24); row[x*4+1]=(uint8_t)(v>>16);
                row[x*4+2]=(uint8_t)(v>>8);  row[x*4+3]=255;
            }
        }
        vaUnmapBuffer(dpy,img.buf); vaDestroyImage(dpy,img.image_id);

        int rc = vaapi_encoder_encode(e, d[f%RING].objects[0].fd,
                                      d[f%RING].layers[0].pitch[0],
                                      d[f%RING].layers[0].offset[0],
                                      d[f%RING].layers[0].drm_format,
                                      d[f%RING].objects[0].drm_format_modifier,
                                      (uint64_t)f * 33333);
        if (rc != 0) { fprintf(stderr,"encode %d failed: %s\n", f, vaapi_encoder_error(e)); return 1; }
    }
    if (vaapi_encoder_finish(e) != 0) { fprintf(stderr,"finish failed\n"); return 1; }
    printf("wrote %s\n", out);
    return 0;
}
