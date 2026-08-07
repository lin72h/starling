// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// See vaapi_encoder.h. Straight VA-API, no libav: the compositor's dmabuf is
// imported as a surface, a VPP pass converts and scales it to NV12, the
// hardware encodes that, and mp4_mux.c writes the file.
//
//   dmabuf(BGRA/XRGB) -> vaCreateSurfaces(DRM_PRIME_2)
//                     -> VPP (colour convert + scale)  [was scale_vaapi]
//                     -> VAEntrypointEncSlice          [was h264_vaapi]
//                     -> mp4_mux                       [was libavformat]
//
// This mirrors what VideoPlayerApp's CH264Decoder does in the other
// direction, and for the same reasons: libva is MIT and present wherever
// VA-API is, so it links directly, while libav had to be dlopen'd behind a
// soname check to keep it off the runtime dependency list.
//
// The one thing the driver will not do for us is write the parameter sets.
// Asked to encode with no packed headers supplied, radeonsi returns the slice
// payload behind a NAL header byte of 0x00 — type "unspecified", which no
// decoder will touch. So h264_headers.c emits the SPS, PPS and slice header,
// and they must agree exactly with the VAEnc*ParameterBufferH264 structs
// submitted alongside them.
//
// "Agree exactly" includes one thing the API appears to let you choose and
// does not: pic_init_qp. See H264_PIC_INIT_QP — the driver writes every
// slice_qp_delta against a hard-wired 26 and ignores what we put in the
// picture parameter buffer, so the PPS has to say 26 too.

#include "include/vaapi_encoder.h"

#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include <va/va.h>
#include <va/va_drm.h>
#include <va/va_drmcommon.h>
#include <va/va_enc_h264.h>
#include <va/va_vpp.h>

#include "h264_bitwriter.h"
#include "h264_headers.h"
#include "mp4_mux.h"

// MP4 media timescale. Microseconds, so the caller's pts_us maps in with no
// rounding and no drift over a long recording.
#define VE_TIMESCALE 1000000

// Imported dmabufs, keyed by the buffer's identity. The capture ring cycles a
// handful of slots, so this is a hit on all but the first few frames — and a
// miss costs a vaCreateSurfaces round trip into the kernel. Keyed on the
// dma-buf INODE rather than the fd number for the reason LinuxTextureRegistry
// records: fds are recycled, so the same number turns up as two unrelated
// buffers, while two references to one dma-buf always share an inode.
#define VE_IMPORT_CACHE 8

typedef struct {
    int valid;
    uint64_t dev, ino;
    uint32_t stride, offset, fourcc;
    uint64_t modifier;
    VASurfaceID surface;
} ImportedBuffer;

struct VaapiEncoder {
    int drm_fd;
    VADisplay dpy;

    VAConfigID vpp_config;
    VAContextID vpp_ctx;
    VAConfigID enc_config;
    VAContextID enc_ctx;

    VASurfaceID input;        // VPP target and encoder source (NV12, out size)
    VASurfaceID recon[2];     // reconstructed pictures, ping-ponged
    VABufferID coded;

    ImportedBuffer imports[VE_IMPORT_CACHE];
    int import_next;          // round-robin eviction

    H264Config cfg;
    int quality_qp;   // the caller's knob — sets the bitrate budget, NOT pic_init_qp
    Mp4Mux* mux;

    int in_w, in_h;
    int gop;                  // frames between IDRs
    int64_t frames;           // encoded so far
    uint32_t frame_num;       // H.264 frame_num, resets at each IDR
    uint32_t idr_pic_id;
    int gop_pos;              // frames since the last IDR

    int have_first_pts;
    uint64_t first_pts;

    // Kept for avcC (bare, escaped) and for the packed headers (Annex-B,
    // unescaped — the driver inserts emulation bytes).
    uint8_t sps_annexb[512], pps_annexb[512];
    size_t sps_annexb_len, pps_annexb_len;
    uint8_t sps_bare[512], pps_bare[512];
    size_t sps_bare_len, pps_bare_len;

    uint8_t* bitstream;       // one access unit, assembled from the segments
    size_t bitstream_cap;

    char err[256];
    char path[PATH_MAX];
};

static void ve_set_err(VaapiEncoder* e, const char* what, VAStatus st) {
    if (st != VA_STATUS_SUCCESS) {
        snprintf(e->err, sizeof e->err, "%s: %s", what, vaErrorStr(st));
    } else {
        snprintf(e->err, sizeof e->err, "%s", what);
    }
}

static void ve_log_null(void* ctx, const char* msg) { (void)ctx; (void)msg; }

// ─── probe ──────────────────────────────────────────────────────────────────

int vaapi_encoder_probe(const char* device) {
    if (!device) return 0;
    int fd = open(device, O_RDWR | O_CLOEXEC);
    if (fd < 0) return 0;
    VADisplay dpy = vaGetDisplayDRM(fd);
    if (!dpy) { close(fd); return 0; }
    vaSetInfoCallback(dpy, ve_log_null, NULL);
    vaSetErrorCallback(dpy, ve_log_null, NULL);

    int major = 0, minor = 0, ok = 0;
    if (vaInitialize(dpy, &major, &minor) == VA_STATUS_SUCCESS) {
        // Everything the encoder actually relies on, asked for together: an
        // H.264 Main encode entrypoint that takes YUV420 and will accept our
        // packed headers, plus the VPP entrypoint that replaces scale_vaapi.
        // Anything less and the caller must stay on the pipe path.
        VAConfigAttrib enc[2] = {
            { .type = VAConfigAttribRTFormat },
            { .type = VAConfigAttribEncPackedHeaders },
        };
        VAConfigAttrib vpp = { .type = VAConfigAttribRTFormat };
        VAStatus a = vaGetConfigAttributes(dpy, VAProfileH264Main,
                                           VAEntrypointEncSlice, enc, 2);
        VAStatus b = vaGetConfigAttributes(dpy, VAProfileNone,
                                           VAEntrypointVideoProc, &vpp, 1);
        ok = a == VA_STATUS_SUCCESS && b == VA_STATUS_SUCCESS
             && (enc[0].value & VA_RT_FORMAT_YUV420)
             && enc[1].value != VA_ATTRIB_NOT_SUPPORTED
             && (enc[1].value & VA_ENC_PACKED_HEADER_SEQUENCE)
             && (enc[1].value & VA_ENC_PACKED_HEADER_SLICE);
        vaTerminate(dpy);
    }
    close(fd);
    return ok ? 1 : 0;
}

// ─── open ───────────────────────────────────────────────────────────────────

static int ve_setup_vpp(VaapiEncoder* e) {
    VAStatus st = vaCreateConfig(e->dpy, VAProfileNone, VAEntrypointVideoProc,
                                 NULL, 0, &e->vpp_config);
    if (st != VA_STATUS_SUCCESS) { ve_set_err(e, "vaCreateConfig(vpp)", st); return -1; }
    st = vaCreateContext(e->dpy, e->vpp_config, e->cfg.width, e->cfg.height,
                         VA_PROGRESSIVE, &e->input, 1, &e->vpp_ctx);
    if (st != VA_STATUS_SUCCESS) { ve_set_err(e, "vaCreateContext(vpp)", st); return -1; }
    return 0;
}

static int ve_setup_encoder(VaapiEncoder* e, int fps, int qp) {
    VAConfigAttrib attrs[3] = {
        { .type = VAConfigAttribRTFormat, .value = VA_RT_FORMAT_YUV420 },
        { .type = VAConfigAttribRateControl, .value = VA_RC_VBR },
        { .type = VAConfigAttribEncPackedHeaders,
          .value = VA_ENC_PACKED_HEADER_SEQUENCE | VA_ENC_PACKED_HEADER_PICTURE
                 | VA_ENC_PACKED_HEADER_SLICE },
    };
    VAStatus st = vaCreateConfig(e->dpy, VAProfileH264Main, VAEntrypointEncSlice,
                                 attrs, 3, &e->enc_config);
    if (st != VA_STATUS_SUCCESS) { ve_set_err(e, "vaCreateConfig(enc)", st); return -1; }

    VASurfaceID targets[3] = { e->input, e->recon[0], e->recon[1] };
    st = vaCreateContext(e->dpy, e->enc_config, e->cfg.width, e->cfg.height,
                         VA_PROGRESSIVE, targets, 3, &e->enc_ctx);
    if (st != VA_STATUS_SUCCESS) { ve_set_err(e, "vaCreateContext(enc)", st); return -1; }

    // A coded buffer big enough for an intra frame of this size. 3/2 bytes per
    // pixel is the uncompressed NV12 size — an encoded picture that exceeds it
    // would be larger than the raw frame.
    st = vaCreateBuffer(e->dpy, e->enc_ctx, VAEncCodedBufferType,
                        (unsigned)(e->cfg.width * e->cfg.height * 3 / 2), 1, NULL,
                        &e->coded);
    if (st != VA_STATUS_SUCCESS) { ve_set_err(e, "vaCreateBuffer(coded)", st); return -1; }
    (void)fps; (void)qp;
    return 0;
}

/// Capped VBR, carried over verbatim from the libav configuration this
/// replaces — the reasoning there was earned the hard way and still holds.
/// Constant QP has no upper bound on rate, and on high-entropy screen content
/// it runs away: a scrolling hex dump at 1640x1100/60 produced 278 MB for 37
/// seconds, 60 Mbps, and every byte has to be read back to play it. The target
/// scales with the picture rate and is clamped at both ends — a floor so a
/// small window still looks right, a ceiling so a busy 4K capture cannot
/// produce a file nothing wants to handle.
///
/// `qp` keeps its meaning as quality (lower is better) by selecting the
/// bits-per-pixel budget rather than being handed to the encoder: passing a QP
/// would put the hardware in CQP mode and this rate control would be ignored.
static int ve_send_rate_control(VaapiEncoder* e, int fps, int qp) {
    double bpp = 0.15 * (24.0 / (qp > 0 ? (double)qp : 24.0));
    double target = (double)e->cfg.width * (double)e->cfg.height * (double)fps * bpp;
    if (target < 4e6) target = 4e6;
    if (target > 30e6) target = 30e6;
    double peak = target * 1.5;

    VABufferID buf;
    // Rate control. VA-API's bits_per_second is the PEAK; the average is
    // expressed as a percentage of it, which is how the old rc_max_rate /
    // bit_rate pair maps across.
    {
        VAEncMiscParameterBuffer* misc = NULL;
        VAStatus st = vaCreateBuffer(
            e->dpy, e->enc_ctx, VAEncMiscParameterBufferType,
            sizeof(VAEncMiscParameterBuffer) + sizeof(VAEncMiscParameterRateControl),
            1, NULL, &buf);
        if (st != VA_STATUS_SUCCESS) { ve_set_err(e, "vaCreateBuffer(rc)", st); return -1; }
        if (vaMapBuffer(e->dpy, buf, (void**)&misc) != VA_STATUS_SUCCESS) {
            ve_set_err(e, "vaMapBuffer(rc)", VA_STATUS_SUCCESS); return -1;
        }
        misc->type = VAEncMiscParameterTypeRateControl;
        VAEncMiscParameterRateControl* rc = (VAEncMiscParameterRateControl*)misc->data;
        memset(rc, 0, sizeof *rc);
        rc->bits_per_second = (uint32_t)peak;
        rc->target_percentage = (uint32_t)(target * 100.0 / peak);
        rc->window_size = 1000;          // ms — hold the rate over a second
        rc->initial_qp = (uint32_t)qp;
        rc->min_qp = 0;                  // 0 = let the driver choose
        rc->max_qp = 0;
        vaUnmapBuffer(e->dpy, buf);
        if (vaRenderPicture(e->dpy, e->enc_ctx, &buf, 1) != VA_STATUS_SUCCESS) {
            ve_set_err(e, "vaRenderPicture(rc)", VA_STATUS_SUCCESS); return -1;
        }
    }
    // Frame rate, so the rate-control window means what it says.
    {
        VAEncMiscParameterBuffer* misc = NULL;
        VAStatus st = vaCreateBuffer(
            e->dpy, e->enc_ctx, VAEncMiscParameterBufferType,
            sizeof(VAEncMiscParameterBuffer) + sizeof(VAEncMiscParameterFrameRate),
            1, NULL, &buf);
        if (st != VA_STATUS_SUCCESS) { ve_set_err(e, "vaCreateBuffer(fr)", st); return -1; }
        if (vaMapBuffer(e->dpy, buf, (void**)&misc) != VA_STATUS_SUCCESS) {
            ve_set_err(e, "vaMapBuffer(fr)", VA_STATUS_SUCCESS); return -1;
        }
        misc->type = VAEncMiscParameterTypeFrameRate;
        VAEncMiscParameterFrameRate* fr = (VAEncMiscParameterFrameRate*)misc->data;
        memset(fr, 0, sizeof *fr);
        fr->framerate = (uint32_t)fps;
        vaUnmapBuffer(e->dpy, buf);
        if (vaRenderPicture(e->dpy, e->enc_ctx, &buf, 1) != VA_STATUS_SUCCESS) {
            ve_set_err(e, "vaRenderPicture(fr)", VA_STATUS_SUCCESS); return -1;
        }
    }
    return 0;
}

VaapiEncoder* vaapi_encoder_open(const char* device,
                                 int in_w, int in_h,
                                 int out_w, int out_h,
                                 int fps, int qp,
                                 const char* out_path) {
    if (!device || !out_path || in_w <= 0 || in_h <= 0) return NULL;
    if (out_w <= 0 || out_h <= 0 || (out_w & 1) || (out_h & 1)) return NULL;

    VaapiEncoder* e = calloc(1, sizeof *e);
    if (!e) return NULL;
    e->drm_fd = -1;
    e->dpy = NULL;
    e->vpp_config = e->enc_config = VA_INVALID_ID;
    e->vpp_ctx = e->enc_ctx = VA_INVALID_ID;
    e->coded = VA_INVALID_ID;
    e->input = e->recon[0] = e->recon[1] = VA_INVALID_SURFACE;
    e->in_w = in_w;
    e->in_h = in_h;
    snprintf(e->path, sizeof e->path, "%s", out_path);
    if (fps <= 0) fps = 30;
    h264_config_init(&e->cfg, out_w, out_h, fps);
    e->quality_qp = qp > 0 ? qp : 24;
    // A keyframe every two seconds: enough for seeking without spending the
    // bitrate an all-intra stream would.
    e->gop = fps * 2;

    e->drm_fd = open(device, O_RDWR | O_CLOEXEC);
    if (e->drm_fd < 0) { ve_set_err(e, "open render node", VA_STATUS_SUCCESS); goto fail; }
    e->dpy = vaGetDisplayDRM(e->drm_fd);
    if (!e->dpy) { ve_set_err(e, "vaGetDisplayDRM", VA_STATUS_SUCCESS); goto fail; }
    vaSetInfoCallback(e->dpy, ve_log_null, NULL);
    vaSetErrorCallback(e->dpy, ve_log_null, NULL);

    int major = 0, minor = 0;
    VAStatus st = vaInitialize(e->dpy, &major, &minor);
    if (st != VA_STATUS_SUCCESS) { ve_set_err(e, "vaInitialize", st); goto fail; }

    st = vaCreateSurfaces(e->dpy, VA_RT_FORMAT_YUV420, (unsigned)out_w,
                          (unsigned)out_h, &e->input, 1, NULL, 0);
    if (st != VA_STATUS_SUCCESS) { ve_set_err(e, "vaCreateSurfaces(input)", st); goto fail; }
    st = vaCreateSurfaces(e->dpy, VA_RT_FORMAT_YUV420, (unsigned)out_w,
                          (unsigned)out_h, e->recon, 2, NULL, 0);
    if (st != VA_STATUS_SUCCESS) { ve_set_err(e, "vaCreateSurfaces(recon)", st); goto fail; }

    if (ve_setup_vpp(e) != 0) goto fail;
    if (ve_setup_encoder(e, fps, qp) != 0) goto fail;

    // Parameter sets, in both spellings: Annex-B without emulation for the
    // packed headers (the driver escapes), bare and escaped for avcC.
    e->sps_annexb_len = h264_write_sps(&e->cfg, H264_NAL_START_CODE,
                                       e->sps_annexb, sizeof e->sps_annexb);
    e->pps_annexb_len = h264_write_pps(&e->cfg, H264_NAL_START_CODE,
                                       e->pps_annexb, sizeof e->pps_annexb);
    e->sps_bare_len = h264_write_sps(&e->cfg, H264_NAL_EMULATION,
                                     e->sps_bare, sizeof e->sps_bare);
    e->pps_bare_len = h264_write_pps(&e->cfg, H264_NAL_EMULATION,
                                     e->pps_bare, sizeof e->pps_bare);
    if (!e->sps_annexb_len || !e->pps_annexb_len || !e->sps_bare_len || !e->pps_bare_len) {
        ve_set_err(e, "could not build the H.264 parameter sets", VA_STATUS_SUCCESS);
        goto fail;
    }

    e->mux = mp4_mux_open(out_path, out_w, out_h, VE_TIMESCALE,
                          e->sps_bare, e->sps_bare_len,
                          e->pps_bare, e->pps_bare_len);
    if (!e->mux) { ve_set_err(e, "could not open the recording for writing", VA_STATUS_SUCCESS); goto fail; }

    return e;

fail:
    // Keep the error readable: the caller logs it, then aborts.
    if (e->err[0] == '\0') ve_set_err(e, "encoder setup failed", VA_STATUS_SUCCESS);
    vaapi_encoder_abort(e);
    return NULL;
}

// ─── per-frame ──────────────────────────────────────────────────────────────

#define VE_DRM_FOURCC(a, b, c, d) \
    ((uint32_t)(a) | ((uint32_t)(b) << 8) | ((uint32_t)(c) << 16) | ((uint32_t)(d) << 24))

/// DRM fourcc -> VA fourcc for the packed 32-bit formats the compositor can
/// hand us. 0 for anything else, which sends the caller to the pipe path
/// rather than importing a buffer we would misinterpret.
static uint32_t ve_va_fourcc(uint32_t drm) {
    switch (drm) {
        case VE_DRM_FOURCC('X', 'R', '2', '4'): return VA_FOURCC_BGRX;  // XRGB8888
        case VE_DRM_FOURCC('A', 'R', '2', '4'): return VA_FOURCC_BGRA;  // ARGB8888
        case VE_DRM_FOURCC('X', 'B', '2', '4'): return VA_FOURCC_RGBX;  // XBGR8888
        case VE_DRM_FOURCC('A', 'B', '2', '4'): return VA_FOURCC_RGBA;  // ABGR8888
        default: return 0;
    }
}

/// Import the caller's dmabuf as a VA surface, reusing the cached surface when
/// this is a buffer we have seen before.
static int ve_import(VaapiEncoder* e, int fd, uint32_t stride, uint32_t offset,
                     uint32_t fourcc, uint64_t modifier, VASurfaceID* out) {
    struct stat sb;
    uint64_t dev = 0, ino = 0;
    if (fstat(fd, &sb) == 0) { dev = (uint64_t)sb.st_dev; ino = (uint64_t)sb.st_ino; }

    if (ino) {
        for (int i = 0; i < VE_IMPORT_CACHE; i++) {
            ImportedBuffer* b = &e->imports[i];
            if (b->valid && b->dev == dev && b->ino == ino && b->stride == stride
                && b->offset == offset && b->fourcc == fourcc
                && b->modifier == modifier) {
                *out = b->surface;
                return 0;
            }
        }
    }

    // The descriptor wants BOTH spellings and they are not the same value:
    // `fourcc` is VA's name for the layout, `layers[].drm_format` is DRM's.
    // DRM names channels in little-endian word order and VA names them in
    // memory order, so DRM_FORMAT_XRGB8888 ("XR24") is bytes B,G,R,X — which
    // VA calls BGRX. Getting this backwards swaps red and blue in every
    // recording, which is exactly the sort of thing that ships.
    uint32_t va_fourcc = ve_va_fourcc(fourcc);
    if (!va_fourcc) {
        ve_set_err(e, "captured frame is in a format the encoder does not import",
                   VA_STATUS_SUCCESS);
        return -1;
    }
    VADRMPRIMESurfaceDescriptor desc;
    memset(&desc, 0, sizeof desc);
    desc.fourcc = va_fourcc;
    desc.width = (uint32_t)e->in_w;
    desc.height = (uint32_t)e->in_h;
    desc.num_objects = 1;
    desc.objects[0].fd = fd;
    // The kernel knows the real size; lseek to the end is how the old path
    // asked, and it is exact for a dma-buf.
    off_t sz = lseek(fd, 0, SEEK_END);
    desc.objects[0].size = sz > 0 ? (uint32_t)sz : stride * (uint32_t)e->in_h + offset;
    desc.objects[0].drm_format_modifier = modifier;
    desc.num_layers = 1;
    desc.layers[0].drm_format = fourcc;
    desc.layers[0].num_planes = 1;
    desc.layers[0].object_index[0] = 0;
    desc.layers[0].offset[0] = offset;
    desc.layers[0].pitch[0] = stride;

    VASurfaceAttrib attrs[2] = {
        { .type = VASurfaceAttribMemoryType, .flags = VA_SURFACE_ATTRIB_SETTABLE,
          .value = { .type = VAGenericValueTypeInteger,
                     .value = { .i = VA_SURFACE_ATTRIB_MEM_TYPE_DRM_PRIME_2 } } },
        { .type = VASurfaceAttribExternalBufferDescriptor,
          .flags = VA_SURFACE_ATTRIB_SETTABLE,
          .value = { .type = VAGenericValueTypePointer, .value = { .p = &desc } } },
    };
    VASurfaceID s = VA_INVALID_SURFACE;
    VAStatus st = vaCreateSurfaces(e->dpy, VA_RT_FORMAT_RGB32,
                                   (unsigned)e->in_w, (unsigned)e->in_h,
                                   &s, 1, attrs, 2);
    if (st != VA_STATUS_SUCCESS) { ve_set_err(e, "import the captured frame", st); return -1; }

    // Round-robin eviction. The ring is small and cycles in order, so the
    // oldest entry is reliably the one no longer coming back.
    ImportedBuffer* slot = &e->imports[e->import_next];
    e->import_next = (e->import_next + 1) % VE_IMPORT_CACHE;
    if (slot->valid) vaDestroySurfaces(e->dpy, &slot->surface, 1);
    slot->valid = 1;
    slot->dev = dev; slot->ino = ino;
    slot->stride = stride; slot->offset = offset; slot->fourcc = fourcc;
    slot->modifier = modifier;
    slot->surface = s;
    *out = s;
    return 0;
}

/// Colour-convert and scale into `e->input`. The colour properties are stated
/// rather than defaulted: the desktop is full-range sRGB and the SPS declares
/// limited-range BT.709, so the conversion has to be told to produce exactly
/// that or the recording plays back over-contrasted.
static int ve_vpp(VaapiEncoder* e, VASurfaceID src) {
    VAProcPipelineParameterBuffer pipe;
    memset(&pipe, 0, sizeof pipe);
    VARectangle src_rect = { 0, 0, (uint16_t)e->in_w, (uint16_t)e->in_h };
    VARectangle dst_rect = { 0, 0, (uint16_t)e->cfg.width, (uint16_t)e->cfg.height };
    pipe.surface = src;
    pipe.surface_region = &src_rect;
    pipe.output_region = &dst_rect;
    pipe.filter_flags = VA_FILTER_SCALING_HQ;
    pipe.input_color_properties.color_range = VA_SOURCE_RANGE_FULL;
    pipe.surface_color_standard = VAProcColorStandardSRGB;
    pipe.output_color_properties.color_range = VA_SOURCE_RANGE_REDUCED;
    pipe.output_color_standard = VAProcColorStandardBT709;

    VABufferID buf;
    VAStatus st = vaCreateBuffer(e->dpy, e->vpp_ctx,
                                 VAProcPipelineParameterBufferType,
                                 sizeof pipe, 1, &pipe, &buf);
    if (st != VA_STATUS_SUCCESS) { ve_set_err(e, "vaCreateBuffer(vpp)", st); return -1; }
    st = vaBeginPicture(e->dpy, e->vpp_ctx, e->input);
    if (st == VA_STATUS_SUCCESS) st = vaRenderPicture(e->dpy, e->vpp_ctx, &buf, 1);
    if (st == VA_STATUS_SUCCESS) st = vaEndPicture(e->dpy, e->vpp_ctx);
    vaDestroyBuffer(e->dpy, buf);
    if (st != VA_STATUS_SUCCESS) { ve_set_err(e, "colour-convert the frame", st); return -1; }
    st = vaSyncSurface(e->dpy, e->input);
    if (st != VA_STATUS_SUCCESS) { ve_set_err(e, "vaSyncSurface(vpp)", st); return -1; }
    return 0;
}

static int ve_grow_bitstream(VaapiEncoder* e, size_t need) {
    if (e->bitstream_cap >= need) return 0;
    size_t cap = e->bitstream_cap ? e->bitstream_cap : 1 << 18;
    while (cap < need) cap *= 2;
    uint8_t* p = realloc(e->bitstream, cap);
    if (!p) { ve_set_err(e, "out of memory for the bitstream", VA_STATUS_SUCCESS); return -1; }
    e->bitstream = p;
    e->bitstream_cap = cap;
    return 0;
}

int vaapi_encoder_encode(VaapiEncoder* e, int fd, uint32_t stride,
                         uint32_t offset, uint32_t fourcc, uint64_t modifier,
                         uint64_t pts_us) {
    if (!e || fd < 0 || !e->mux) return -1;

    VASurfaceID src = VA_INVALID_SURFACE;
    if (ve_import(e, fd, stride, offset, fourcc, modifier, &src) != 0) return -1;
    if (ve_vpp(e, src) != 0) return -1;

    int is_idr = (e->gop_pos == 0);
    if (is_idr) {
        e->frame_num = 0;
        e->idr_pic_id = (e->idr_pic_id + 1) & 0xffff;
    }
    VASurfaceID cur = e->recon[e->frames & 1];
    VASurfaceID ref = e->recon[(e->frames + 1) & 1];

    // pic_order_cnt_type 0 counts in field order, so twice the display index.
    uint32_t poc_lsb = (uint32_t)((e->gop_pos * 2) &
                                  ((1u << (e->cfg.log2_max_poc_lsb_minus4 + 4)) - 1));

    VAEncSequenceParameterBufferH264 seq;
    memset(&seq, 0, sizeof seq);
    seq.level_idc = (uint8_t)e->cfg.level_idc;
    seq.picture_width_in_mbs = (uint16_t)e->cfg.mb_width;
    seq.picture_height_in_mbs = (uint16_t)e->cfg.mb_height;
    seq.intra_period = (uint32_t)e->gop;
    seq.intra_idr_period = (uint32_t)e->gop;
    seq.ip_period = 1;                     // no B-frames
    seq.max_num_ref_frames = 1;
    seq.seq_fields.bits.chroma_format_idc = 1;
    seq.seq_fields.bits.frame_mbs_only_flag = 1;
    seq.seq_fields.bits.direct_8x8_inference_flag = 1;
    seq.seq_fields.bits.log2_max_frame_num_minus4 =
        (uint32_t)e->cfg.log2_max_frame_num_minus4;
    seq.seq_fields.bits.pic_order_cnt_type = 0;
    seq.seq_fields.bits.log2_max_pic_order_cnt_lsb_minus4 =
        (uint32_t)e->cfg.log2_max_poc_lsb_minus4;
    seq.time_scale = (uint32_t)e->cfg.fps * 2;
    seq.num_units_in_tick = 1;
    // Frame cropping, to match the SPS exactly.
    if (e->cfg.mb_width * 16 != e->cfg.width || e->cfg.mb_height * 16 != e->cfg.height) {
        seq.frame_cropping_flag = 1;
        seq.frame_crop_left_offset = 0;
        seq.frame_crop_right_offset =
            (uint32_t)((e->cfg.mb_width * 16 - e->cfg.width) / 2);
        seq.frame_crop_top_offset = 0;
        seq.frame_crop_bottom_offset =
            (uint32_t)((e->cfg.mb_height * 16 - e->cfg.height) / 2);
    }

    VAEncPictureParameterBufferH264 pic;
    memset(&pic, 0, sizeof pic);
    pic.CurrPic.picture_id = cur;
    pic.CurrPic.frame_idx = e->frame_num;
    pic.CurrPic.flags = 0;
    pic.CurrPic.TopFieldOrderCnt = (int32_t)(e->gop_pos * 2);
    pic.CurrPic.BottomFieldOrderCnt = pic.CurrPic.TopFieldOrderCnt;
    for (int i = 0; i < 16; i++) {
        pic.ReferenceFrames[i].picture_id = VA_INVALID_SURFACE;
        pic.ReferenceFrames[i].flags = VA_PICTURE_H264_INVALID;
    }
    if (!is_idr) {
        pic.ReferenceFrames[0].picture_id = ref;
        pic.ReferenceFrames[0].frame_idx = e->frame_num - 1;
        pic.ReferenceFrames[0].flags = VA_PICTURE_H264_SHORT_TERM_REFERENCE;
        pic.ReferenceFrames[0].TopFieldOrderCnt = (int32_t)((e->gop_pos - 1) * 2);
        pic.ReferenceFrames[0].BottomFieldOrderCnt =
            pic.ReferenceFrames[0].TopFieldOrderCnt;
    }
    pic.coded_buf = e->coded;
    pic.frame_num = (uint16_t)e->frame_num;
    pic.pic_init_qp = (uint8_t)e->cfg.pic_init_qp;
    pic.num_ref_idx_l0_active_minus1 = 0;
    pic.num_ref_idx_l1_active_minus1 = 0;
    pic.pic_fields.bits.idr_pic_flag = (uint32_t)is_idr;
    pic.pic_fields.bits.reference_pic_flag = 1;
    pic.pic_fields.bits.entropy_coding_mode_flag = 1;   // CABAC
    pic.pic_fields.bits.deblocking_filter_control_present_flag = 1;
    pic.pic_fields.bits.transform_8x8_mode_flag = 0;

    VAEncSliceParameterBufferH264 sl;
    memset(&sl, 0, sizeof sl);
    sl.macroblock_address = 0;
    sl.num_macroblocks = (uint32_t)(e->cfg.mb_width * e->cfg.mb_height);
    sl.slice_type = is_idr ? 2u : 0u;      // I or P
    sl.idr_pic_id = (uint16_t)e->idr_pic_id;
    sl.pic_order_cnt_lsb = (uint16_t)poc_lsb;
    sl.num_ref_idx_active_override_flag = 0;
    for (int i = 0; i < 32; i++) {
        sl.RefPicList0[i].picture_id = VA_INVALID_SURFACE;
        sl.RefPicList0[i].flags = VA_PICTURE_H264_INVALID;
        sl.RefPicList1[i].picture_id = VA_INVALID_SURFACE;
        sl.RefPicList1[i].flags = VA_PICTURE_H264_INVALID;
    }
    if (!is_idr) {
        sl.RefPicList0[0].picture_id = ref;
        sl.RefPicList0[0].frame_idx = e->frame_num - 1;
        sl.RefPicList0[0].flags = VA_PICTURE_H264_SHORT_TERM_REFERENCE;
        sl.RefPicList0[0].TopFieldOrderCnt = (int32_t)((e->gop_pos - 1) * 2);
        sl.RefPicList0[0].BottomFieldOrderCnt = sl.RefPicList0[0].TopFieldOrderCnt;
    }
    sl.slice_qp_delta = 0;
    sl.disable_deblocking_filter_idc = 0;

    uint8_t sh[512];
    unsigned sh_bits = 0;
    if (h264_write_slice_header(&e->cfg, is_idr, e->frame_num, e->idr_pic_id,
                                poc_lsb, 0, sh, sizeof sh, &sh_bits) == 0) {
        ve_set_err(e, "could not build the slice header", VA_STATUS_SUCCESS);
        return -1;
    }

    // Submit. The parameter sets only ride along with an IDR — a decoder that
    // joins mid-stream seeks to a keyframe, and the MP4's avcC carries them
    // for the file as a whole.
    VABufferID ids[9];
    int n = 0;
    VAStatus st = vaCreateBuffer(e->dpy, e->enc_ctx, VAEncSequenceParameterBufferType,
                                 sizeof seq, 1, &seq, &ids[n]);
    if (st != VA_STATUS_SUCCESS) { ve_set_err(e, "vaCreateBuffer(seq)", st); return -1; }
    n++;

    VAEncPackedHeaderParameterBuffer ph;
    if (is_idr) {
        memset(&ph, 0, sizeof ph);
        ph.type = VAEncPackedHeaderSequence;
        ph.bit_length = (uint32_t)(e->sps_annexb_len * 8);
        ph.has_emulation_bytes = 0;
        if (vaCreateBuffer(e->dpy, e->enc_ctx, VAEncPackedHeaderParameterBufferType,
                           sizeof ph, 1, &ph, &ids[n]) != VA_STATUS_SUCCESS) goto submit_fail;
        n++;
        if (vaCreateBuffer(e->dpy, e->enc_ctx, VAEncPackedHeaderDataBufferType,
                           (unsigned)e->sps_annexb_len, 1, e->sps_annexb,
                           &ids[n]) != VA_STATUS_SUCCESS) goto submit_fail;
        n++;
        memset(&ph, 0, sizeof ph);
        ph.type = VAEncPackedHeaderPicture;
        ph.bit_length = (uint32_t)(e->pps_annexb_len * 8);
        ph.has_emulation_bytes = 0;
        if (vaCreateBuffer(e->dpy, e->enc_ctx, VAEncPackedHeaderParameterBufferType,
                           sizeof ph, 1, &ph, &ids[n]) != VA_STATUS_SUCCESS) goto submit_fail;
        n++;
        if (vaCreateBuffer(e->dpy, e->enc_ctx, VAEncPackedHeaderDataBufferType,
                           (unsigned)e->pps_annexb_len, 1, e->pps_annexb,
                           &ids[n]) != VA_STATUS_SUCCESS) goto submit_fail;
        n++;
    }

    if (vaCreateBuffer(e->dpy, e->enc_ctx, VAEncPictureParameterBufferType,
                       sizeof pic, 1, &pic, &ids[n]) != VA_STATUS_SUCCESS) goto submit_fail;
    n++;
    memset(&ph, 0, sizeof ph);
    ph.type = VAEncPackedHeaderSlice;
    ph.bit_length = sh_bits;
    ph.has_emulation_bytes = 0;
    if (vaCreateBuffer(e->dpy, e->enc_ctx, VAEncPackedHeaderParameterBufferType,
                       sizeof ph, 1, &ph, &ids[n]) != VA_STATUS_SUCCESS) goto submit_fail;
    n++;
    if (vaCreateBuffer(e->dpy, e->enc_ctx, VAEncPackedHeaderDataBufferType,
                       (sh_bits + 7) / 8, 1, sh, &ids[n]) != VA_STATUS_SUCCESS) goto submit_fail;
    n++;
    if (vaCreateBuffer(e->dpy, e->enc_ctx, VAEncSliceParameterBufferType,
                       sizeof sl, 1, &sl, &ids[n]) != VA_STATUS_SUCCESS) goto submit_fail;
    n++;

    st = vaBeginPicture(e->dpy, e->enc_ctx, e->input);
    if (st == VA_STATUS_SUCCESS && is_idr) {
        // Rate control is per-sequence state; resend it with each IDR so a
        // long recording cannot drift away from the configured budget.
        if (ve_send_rate_control(e, e->cfg.fps, e->quality_qp) != 0) {
            vaEndPicture(e->dpy, e->enc_ctx);
            goto submit_fail;
        }
    }
    if (st == VA_STATUS_SUCCESS) st = vaRenderPicture(e->dpy, e->enc_ctx, ids, n);
    if (st == VA_STATUS_SUCCESS) st = vaEndPicture(e->dpy, e->enc_ctx);
    for (int i = 0; i < n; i++) vaDestroyBuffer(e->dpy, ids[i]);
    if (st != VA_STATUS_SUCCESS) { ve_set_err(e, "encode the frame", st); return -1; }

    st = vaSyncSurface(e->dpy, e->input);
    if (st != VA_STATUS_SUCCESS) { ve_set_err(e, "vaSyncSurface(enc)", st); return -1; }

    // Collect the coded bitstream. It arrives as a segment chain — on this
    // driver the parameter sets come back as their own segments.
    VACodedBufferSegment* seg = NULL;
    st = vaMapBuffer(e->dpy, e->coded, (void**)&seg);
    if (st != VA_STATUS_SUCCESS) { ve_set_err(e, "vaMapBuffer(coded)", st); return -1; }
    size_t total = 0;
    for (VACodedBufferSegment* s = seg; s; s = (VACodedBufferSegment*)s->next) {
        if (ve_grow_bitstream(e, total + s->size) != 0) {
            vaUnmapBuffer(e->dpy, e->coded);
            return -1;
        }
        memcpy(e->bitstream + total, s->buf, s->size);
        total += s->size;
    }
    vaUnmapBuffer(e->dpy, e->coded);
    if (total == 0) { ve_set_err(e, "the encoder produced no bitstream", VA_STATUS_SUCCESS); return -1; }

    if (!e->have_first_pts) { e->first_pts = pts_us; e->have_first_pts = 1; }
    uint64_t dts = pts_us >= e->first_pts ? pts_us - e->first_pts : 0;
    if (mp4_mux_write_sample(e->mux, e->bitstream, total, dts, is_idr) != 0) {
        ve_set_err(e, mp4_mux_error(e->mux), VA_STATUS_SUCCESS);
        return -1;
    }

    e->frames++;
    e->frame_num = (e->frame_num + 1) &
                   ((1u << (e->cfg.log2_max_frame_num_minus4 + 4)) - 1);
    e->gop_pos = (e->gop_pos + 1) % e->gop;
    return 0;

submit_fail:
    for (int i = 0; i < n; i++) vaDestroyBuffer(e->dpy, ids[i]);
    ve_set_err(e, "could not submit the encode buffers", VA_STATUS_SUCCESS);
    return -1;
}

int64_t vaapi_encoder_frame_count(const VaapiEncoder* e) {
    return e ? e->frames : 0;
}

// ─── teardown ───────────────────────────────────────────────────────────────

static void ve_free_va(VaapiEncoder* e) {
    if (e->dpy) {
        for (int i = 0; i < VE_IMPORT_CACHE; i++) {
            if (e->imports[i].valid) {
                vaDestroySurfaces(e->dpy, &e->imports[i].surface, 1);
                e->imports[i].valid = 0;
            }
        }
        if (e->coded != VA_INVALID_ID) vaDestroyBuffer(e->dpy, e->coded);
        if (e->enc_ctx != VA_INVALID_ID) vaDestroyContext(e->dpy, e->enc_ctx);
        if (e->enc_config != VA_INVALID_ID) vaDestroyConfig(e->dpy, e->enc_config);
        if (e->vpp_ctx != VA_INVALID_ID) vaDestroyContext(e->dpy, e->vpp_ctx);
        if (e->vpp_config != VA_INVALID_ID) vaDestroyConfig(e->dpy, e->vpp_config);
        if (e->input != VA_INVALID_SURFACE) vaDestroySurfaces(e->dpy, &e->input, 1);
        if (e->recon[0] != VA_INVALID_SURFACE) vaDestroySurfaces(e->dpy, e->recon, 2);
        vaTerminate(e->dpy);
        e->dpy = NULL;
    }
    if (e->drm_fd >= 0) { close(e->drm_fd); e->drm_fd = -1; }
    free(e->bitstream);
    e->bitstream = NULL;
}

int vaapi_encoder_finish(VaapiEncoder* e) {
    if (!e) return -1;
    if (e->frames == 0) {
        ve_set_err(e, "no frames were encoded", VA_STATUS_SUCCESS);
        return -1;
    }
    if (mp4_mux_finish(e->mux) != 0) {
        ve_set_err(e, mp4_mux_error(e->mux), VA_STATUS_SUCCESS);
        return -1;
    }
    e->mux = NULL;   // finish freed it
    ve_free_va(e);
    free(e);
    return 0;
}

void vaapi_encoder_abort(VaapiEncoder* e) {
    if (!e) return;
    if (e->mux) { mp4_mux_abort(e->mux); e->mux = NULL; }
    ve_free_va(e);
    if (e->path[0]) unlink(e->path);
    free(e);
}

const char* vaapi_encoder_error(const VaapiEncoder* e) {
    return e ? e->err : "";
}
