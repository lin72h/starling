// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#include "include/h264_decoder.h"

#include "h264_bits.h"
#include "mp4_demux.h"

#include <fcntl.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <va/va.h>
#include <va/va_drm.h>
#include <va/va_drmcommon.h>

// Surfaces: one being decoded, one reference, and the rest absorbing frames
// the compositor still has bound. The player keeps at most two in flight.
#define VD_SURFACES 8

typedef struct {
    VASurfaceID id;
    int in_use;                     // handed out, awaiting release
    VADRMPRIMESurfaceDescriptor desc;
    int exported;
    uint32_t frame_num;
    int32_t poc;
} Surface;

struct H264Decoder {
    Mp4Reader mp4;
    H264Sps sps;
    H264Pps pps;

    int drm_fd;
    VADisplay dpy;
    VAConfigID config;
    VAContextID context;
    Surface surfaces[VD_SURFACES];

    uint32_t next_sample;
    int prev_ref;                   // index into surfaces, or -1
    int32_t poc_counter;

    uint8_t* sample_buf;
    uint32_t sample_buf_size;

    atomic_int aborted;
    char err[256];
};

static void vd_err(H264Decoder* d, const char* what, VAStatus st) {
    snprintf(d->err, sizeof d->err, "%s%s%s", what,
             st == VA_STATUS_SUCCESS ? "" : ": ",
             st == VA_STATUS_SUCCESS ? "" : vaErrorStr(st));
}

// Silence libva's own chatter by default; a refusal here is routine (the
// player falls back), not something to print on the user's console. Set
// STARLING_H264_DEBUG to get the driver's side of a failure back.
static void vd_log_null(void* ctx, const char* msg) { (void)ctx; (void)msg; }
static void vd_log_stderr(void* ctx, const char* msg) {
    (void)ctx;
    fputs(msg, stderr);
}
static int vd_debug(void) {
    const char* v = getenv("STARLING_H264_DEBUG");
    return v && v[0];
}

// ─── open / close ───────────────────────────────────────────────────────────

/// Everything the narrow path assumes, checked in one place. Anything false
/// means "hand this file to PipeDecoder", never "decode it anyway".
static const char* unsupported_reason(const H264Sps* s, const H264Pps* p) {
    if (s->profile_idc != 66 && s->profile_idc != 77 && s->profile_idc != 100) {
        return "profile not modelled";
    }
    if (s->chroma_format_idc != 1) return "not 4:2:0";
    if (s->bit_depth_luma_minus8 != 0 || s->bit_depth_chroma_minus8 != 0) {
        return "not 8-bit";
    }
    if (!s->frame_mbs_only_flag) return "interlaced";
    if (s->separate_colour_plane_flag) return "separate colour planes";
    if (s->max_num_ref_frames > 1) return "more than one reference frame";
    if (s->seq_scaling_matrix_present_flag || p->pic_scaling_matrix_present_flag) {
        return "scaling matrices";
    }
    if (p->num_slice_groups_minus1 > 0) return "slice groups (FMO)";
    if (p->weighted_pred_flag || p->weighted_bipred_idc) return "weighted prediction";
    return NULL;
}

static int read_parameter_sets(H264Decoder* d) {
    if (h264_parse_sps(d->mp4.sps, d->mp4.sps_size, &d->sps) != 0) {
        vd_err(d, "SPS parse failed", VA_STATUS_SUCCESS);
        return -1;
    }
    if (h264_parse_pps(d->mp4.pps, d->mp4.pps_size, &d->sps, &d->pps) != 0) {
        vd_err(d, "PPS parse failed", VA_STATUS_SUCCESS);
        return -1;
    }
    const char* why = unsupported_reason(&d->sps, &d->pps);
    if (why) {
        snprintf(d->err, sizeof d->err, "unsupported: %s", why);
        return -1;
    }
    return 0;
}

int h264_decoder_probe_info(const char* path, H264Info* out) {
    Mp4Reader r;
    if (mp4_open(path, &r) != 0) return -1;
    H264Sps sps;
    int ok = (r.sps && h264_parse_sps(r.sps, r.sps_size, &sps) == 0);
    if (ok) {
        out->width = sps.width;
        out->height = sps.height;
        out->duration = (r.timescale && r.duration)
                            ? (double)r.duration / (double)r.timescale : 0.0;
        // Frame rate from the sample table, not a declared value: it is the
        // rate the file actually ticks at, which on a sparse screen recording
        // is what the reader must pace against.
        double fps = 30.0;
        if (r.sample_count > 1 && out->duration > 0) {
            fps = (double)r.sample_count / out->duration;
        }
        if (fps < 1) fps = 1;
        if (fps > 30) fps = 30;
        out->fps = fps;
    }
    mp4_close(&r);
    return ok ? 0 : -1;
}

int h264_decoder_supported(const char* path) {
    H264Decoder d;
    memset(&d, 0, sizeof d);
    if (mp4_open(path, &d.mp4) != 0) return 0;
    int ok = (read_parameter_sets(&d) == 0);
    mp4_close(&d.mp4);
    return ok;
}

static VAProfile profile_for(uint32_t profile_idc) {
    switch (profile_idc) {
        case 66:  return VAProfileH264ConstrainedBaseline;
        case 77:  return VAProfileH264Main;
        default:  return VAProfileH264High;
    }
}

H264Decoder* h264_decoder_open(const char* path, const char* render_node,
                               double start) {
    H264Decoder* d = calloc(1, sizeof *d);
    if (!d) return NULL;
    d->drm_fd = -1;
    d->dpy = NULL;
    d->config = VA_INVALID_ID;
    d->context = VA_INVALID_ID;
    d->prev_ref = -1;
    atomic_init(&d->aborted, 0);
    for (int i = 0; i < VD_SURFACES; i++) d->surfaces[i].id = VA_INVALID_SURFACE;

    if (mp4_open(path, &d->mp4) != 0) { vd_err(d, "not a readable MP4", VA_STATUS_SUCCESS); goto fail; }
    if (read_parameter_sets(d) != 0) goto fail;

    d->drm_fd = open(render_node, O_RDWR | O_CLOEXEC);
    if (d->drm_fd < 0) { vd_err(d, "open render node", VA_STATUS_SUCCESS); goto fail; }

    d->dpy = vaGetDisplayDRM(d->drm_fd);
    if (!d->dpy) { vd_err(d, "vaGetDisplayDRM", VA_STATUS_SUCCESS); goto fail; }
    vaSetInfoCallback(d->dpy, vd_debug() ? vd_log_stderr : vd_log_null, NULL);
    vaSetErrorCallback(d->dpy, vd_debug() ? vd_log_stderr : vd_log_null, NULL);

    int major = 0, minor = 0;
    VAStatus st = vaInitialize(d->dpy, &major, &minor);
    if (st != VA_STATUS_SUCCESS) { vd_err(d, "vaInitialize", st); goto fail; }

    VAProfile profile = profile_for(d->sps.profile_idc);
    VAConfigAttrib attrib = { .type = VAConfigAttribRTFormat };
    st = vaGetConfigAttributes(d->dpy, profile, VAEntrypointVLD, &attrib, 1);
    if (st != VA_STATUS_SUCCESS || !(attrib.value & VA_RT_FORMAT_YUV420)) {
        vd_err(d, "no YUV420 VLD config for this profile", st);
        goto fail;
    }
    attrib.value = VA_RT_FORMAT_YUV420;
    st = vaCreateConfig(d->dpy, profile, VAEntrypointVLD, &attrib, 1, &d->config);
    if (st != VA_STATUS_SUCCESS) { vd_err(d, "vaCreateConfig", st); goto fail; }

    // Decode at macroblock-aligned size; the visible rect is the SPS crop.
    unsigned int aligned_w = (d->sps.pic_width_in_mbs_minus1 + 1) * 16;
    unsigned int aligned_h = (d->sps.pic_height_in_map_units_minus1 + 1) * 16;

    VASurfaceID ids[VD_SURFACES];
    st = vaCreateSurfaces(d->dpy, VA_RT_FORMAT_YUV420, aligned_w, aligned_h,
                          ids, VD_SURFACES, NULL, 0);
    if (st != VA_STATUS_SUCCESS) { vd_err(d, "vaCreateSurfaces", st); goto fail; }
    for (int i = 0; i < VD_SURFACES; i++) d->surfaces[i].id = ids[i];

    st = vaCreateContext(d->dpy, d->config, (int)aligned_w, (int)aligned_h,
                         VA_PROGRESSIVE, ids, VD_SURFACES, &d->context);
    if (st != VA_STATUS_SUCCESS) { vd_err(d, "vaCreateContext", st); goto fail; }

    uint32_t biggest = 0;
    for (uint32_t i = 0; i < d->mp4.sample_count; i++) {
        if (d->mp4.samples[i].size > biggest) biggest = d->mp4.samples[i].size;
    }
    d->sample_buf = malloc(biggest ? biggest : 1);
    if (!d->sample_buf) goto fail;
    d->sample_buf_size = biggest;

    d->next_sample = mp4_seek_keyframe(&d->mp4, start);
    return d;

fail:
    fprintf(stderr, "[H264Decoder] %s\n", d->err[0] ? d->err : "open failed");
    h264_decoder_close(d);
    return NULL;
}

void h264_decoder_close(H264Decoder* d) {
    if (!d) return;
    if (d->dpy) {
        for (int i = 0; i < VD_SURFACES; i++) {
            if (d->surfaces[i].exported) {
                for (uint32_t k = 0; k < d->surfaces[i].desc.num_objects; k++) {
                    close(d->surfaces[i].desc.objects[k].fd);
                }
                d->surfaces[i].exported = 0;
            }
        }
        if (d->context != VA_INVALID_ID) vaDestroyContext(d->dpy, d->context);
        if (d->config != VA_INVALID_ID) vaDestroyConfig(d->dpy, d->config);
        VASurfaceID ids[VD_SURFACES];
        int n = 0;
        for (int i = 0; i < VD_SURFACES; i++) {
            if (d->surfaces[i].id != VA_INVALID_SURFACE) ids[n++] = d->surfaces[i].id;
        }
        if (n) vaDestroySurfaces(d->dpy, ids, n);
        vaTerminate(d->dpy);
    }
    if (d->drm_fd >= 0) close(d->drm_fd);
    mp4_close(&d->mp4);
    free(d->sample_buf);
    free(d);
}

// ─── decode ─────────────────────────────────────────────────────────────────

static int free_surface(H264Decoder* d) {
    for (int i = 0; i < VD_SURFACES; i++) {
        if (!d->surfaces[i].in_use && i != d->prev_ref) return i;
    }
    return -1;
}

static VAPictureH264 invalid_pic(void) {
    VAPictureH264 p;
    memset(&p, 0, sizeof p);
    p.picture_id = VA_INVALID_SURFACE;
    p.flags = VA_PICTURE_H264_INVALID;
    return p;
}

static VAPictureH264 ref_pic(const Surface* s) {
    VAPictureH264 p;
    memset(&p, 0, sizeof p);
    p.picture_id = s->id;
    p.frame_idx = s->frame_num;
    p.flags = VA_PICTURE_H264_SHORT_TERM_REFERENCE;
    p.TopFieldOrderCnt = s->poc;
    p.BottomFieldOrderCnt = s->poc;
    return p;
}

static int decode_sample(H264Decoder* d, uint32_t index, int slot) {
    const Mp4Sample* sample = &d->mp4.samples[index];
    if (mp4_read_sample(&d->mp4, index, d->sample_buf) != 0) {
        vd_err(d, "sample read", VA_STATUS_SUCCESS);
        return -1;
    }

    // Walk the NALs. In-band parameter sets take precedence over avcC, and
    // that is not belt-and-braces: our own recordings carry a PPS that DIFFERS
    // from the one the muxer wrote into avcC (68 ee 38 30 in-band vs
    // 68 ee 0b 8b in avcC — different pic_init_qp and transform_8x8_mode).
    // Decoding against avcC alone hands the hardware the wrong quantiser and
    // transform mode, CABAC diverges on the first macroblock, and every
    // surface comes back untouched. The driver reports success throughout.
    const uint8_t* slice = NULL;
    uint32_t slice_len = 0;
    uint32_t pos = 0;
    int slice_count = 0;
    while (pos + d->mp4.nal_length_size <= sample->size) {
        uint32_t len = 0;
        for (int k = 0; k < d->mp4.nal_length_size; k++) {
            len = (len << 8) | d->sample_buf[pos + k];
        }
        pos += d->mp4.nal_length_size;
        if (len == 0 || pos + len > sample->size) break;
        const uint8_t* nal = d->sample_buf + pos;
        uint32_t type = nal[0] & 0x1f;
        if (type == 7) {
            H264Sps s;
            if (h264_parse_sps(nal, len, &s) == 0) {
                // A mid-stream resolution change would invalidate the surface
                // pool and the context; refuse rather than decode into the
                // wrong geometry.
                if (d->sps.width && (s.width != d->sps.width ||
                                     s.height != d->sps.height)) {
                    snprintf(d->err, sizeof d->err,
                             "unsupported: resolution changes mid-stream");
                    return -1;
                }
                d->sps = s;
            }
        } else if (type == 8) {
            H264Pps p;
            if (h264_parse_pps(nal, len, &d->sps, &p) == 0) d->pps = p;
        } else if (type == 1 || type == 5) {
            slice = nal;
            slice_len = len;
            slice_count++;
        }
        pos += len;
    }
    {
        const char* why = unsupported_reason(&d->sps, &d->pps);
        if (why) {
            snprintf(d->err, sizeof d->err, "unsupported: %s", why);
            return -1;
        }
    }
    if (!slice) { vd_err(d, "no slice NAL in sample", VA_STATUS_SUCCESS); return -1; }
    if (slice_count > 1) {
        snprintf(d->err, sizeof d->err, "unsupported: multiple slices per picture");
        return -1;
    }

    H264SliceHeader sh;
    if (h264_parse_slice_header(slice, slice_len, &d->sps, &d->pps, &sh) != 0) {
        snprintf(d->err, sizeof d->err, "unsupported: %s",
                 sh.reject ? sh.reject : "slice header");
        return -1;
    }
    if (sh.has_list_modification) {
        snprintf(d->err, sizeof d->err, "unsupported: reference list modification");
        return -1;
    }
    if (sh.slice_type == H264_SLICE_P && d->prev_ref < 0) {
        // A P frame with nothing to reference: seeking landed mid-GOP, which
        // mp4_seek_keyframe should prevent. Skip rather than decode garbage.
        return 1;
    }

    if (sh.is_idr) {
        d->prev_ref = -1;
        d->poc_counter = 0;
    }

    Surface* cur = &d->surfaces[slot];
    cur->frame_num = sh.frame_num;
    cur->poc = d->poc_counter;
    d->poc_counter += 2;

    // ── picture parameters ──
    VAPictureParameterBufferH264 pp;
    memset(&pp, 0, sizeof pp);
    pp.CurrPic.picture_id = cur->id;
    pp.CurrPic.frame_idx = sh.frame_num;
    pp.CurrPic.flags = 0;
    pp.CurrPic.TopFieldOrderCnt = cur->poc;
    pp.CurrPic.BottomFieldOrderCnt = cur->poc;
    for (int i = 0; i < 16; i++) pp.ReferenceFrames[i] = invalid_pic();
    if (d->prev_ref >= 0) pp.ReferenceFrames[0] = ref_pic(&d->surfaces[d->prev_ref]);

    pp.picture_width_in_mbs_minus1 = (uint16_t)d->sps.pic_width_in_mbs_minus1;
    pp.picture_height_in_mbs_minus1 = (uint16_t)d->sps.pic_height_in_map_units_minus1;
    pp.bit_depth_luma_minus8 = (uint8_t)d->sps.bit_depth_luma_minus8;
    pp.bit_depth_chroma_minus8 = (uint8_t)d->sps.bit_depth_chroma_minus8;
    pp.num_ref_frames = (uint8_t)d->sps.max_num_ref_frames;

    pp.seq_fields.bits.chroma_format_idc = d->sps.chroma_format_idc;
    pp.seq_fields.bits.residual_colour_transform_flag = d->sps.separate_colour_plane_flag;
    pp.seq_fields.bits.gaps_in_frame_num_value_allowed_flag =
        d->sps.gaps_in_frame_num_value_allowed_flag;
    pp.seq_fields.bits.frame_mbs_only_flag = d->sps.frame_mbs_only_flag;
    pp.seq_fields.bits.mb_adaptive_frame_field_flag = d->sps.mb_adaptive_frame_field_flag;
    pp.seq_fields.bits.direct_8x8_inference_flag = d->sps.direct_8x8_inference_flag;
    pp.seq_fields.bits.MinLumaBiPredSize8x8 = (d->sps.level_idc >= 31);
    pp.seq_fields.bits.log2_max_frame_num_minus4 = d->sps.log2_max_frame_num_minus4;
    pp.seq_fields.bits.pic_order_cnt_type = d->sps.pic_order_cnt_type;
    pp.seq_fields.bits.log2_max_pic_order_cnt_lsb_minus4 =
        d->sps.log2_max_pic_order_cnt_lsb_minus4;
    pp.seq_fields.bits.delta_pic_order_always_zero_flag =
        d->sps.delta_pic_order_always_zero_flag;

    pp.pic_init_qp_minus26 = (int8_t)d->pps.pic_init_qp_minus26;
    pp.pic_init_qs_minus26 = (int8_t)d->pps.pic_init_qs_minus26;
    pp.chroma_qp_index_offset = (int8_t)d->pps.chroma_qp_index_offset;
    pp.second_chroma_qp_index_offset = (int8_t)d->pps.second_chroma_qp_index_offset;

    pp.pic_fields.bits.entropy_coding_mode_flag = d->pps.entropy_coding_mode_flag;
    pp.pic_fields.bits.weighted_pred_flag = d->pps.weighted_pred_flag;
    pp.pic_fields.bits.weighted_bipred_idc = d->pps.weighted_bipred_idc;
    pp.pic_fields.bits.transform_8x8_mode_flag = d->pps.transform_8x8_mode_flag;
    pp.pic_fields.bits.field_pic_flag = sh.field_pic_flag;
    pp.pic_fields.bits.constrained_intra_pred_flag = d->pps.constrained_intra_pred_flag;
    pp.pic_fields.bits.pic_order_present_flag =
        d->pps.bottom_field_pic_order_in_frame_present_flag;
    pp.pic_fields.bits.deblocking_filter_control_present_flag =
        d->pps.deblocking_filter_control_present_flag;
    pp.pic_fields.bits.redundant_pic_cnt_present_flag = d->pps.redundant_pic_cnt_present_flag;
    pp.pic_fields.bits.reference_pic_flag = (sh.nal_ref_idc != 0);
    pp.frame_num = (uint16_t)sh.frame_num;

    // ── flat inverse quantisation matrices ──
    // Sent even though no scaling matrices are present: the buffer is not
    // optional, and "no scaling list" means the flat 16s, not "omit it".
    VAIQMatrixBufferH264 iq;
    memset(&iq, 16, sizeof iq);
    memset(iq.va_reserved, 0, sizeof iq.va_reserved);

    // ── slice parameters ──
    VASliceParameterBufferH264 sp;
    memset(&sp, 0, sizeof sp);
    sp.slice_data_size = slice_len;
    sp.slice_data_offset = 0;
    sp.slice_data_flag = VA_SLICE_DATA_FLAG_ALL;
    sp.slice_data_bit_offset = (uint16_t)sh.slice_data_bit_offset;
    sp.first_mb_in_slice = (uint16_t)sh.first_mb_in_slice;
    sp.slice_type = (uint8_t)sh.slice_type;
    sp.direct_spatial_mv_pred_flag = 0;
    sp.num_ref_idx_l0_active_minus1 = (uint8_t)sh.num_ref_idx_l0_active_minus1;
    sp.num_ref_idx_l1_active_minus1 = 0;
    sp.cabac_init_idc = (uint8_t)sh.cabac_init_idc;
    sp.slice_qp_delta = (int8_t)sh.slice_qp_delta;
    sp.disable_deblocking_filter_idc = (uint8_t)sh.disable_deblocking_filter_idc;
    sp.slice_alpha_c0_offset_div2 = (int8_t)sh.slice_alpha_c0_offset_div2;
    sp.slice_beta_offset_div2 = (int8_t)sh.slice_beta_offset_div2;
    for (int i = 0; i < 32; i++) {
        sp.RefPicList0[i] = invalid_pic();
        sp.RefPicList1[i] = invalid_pic();
    }
    if (sh.slice_type == H264_SLICE_P && d->prev_ref >= 0) {
        sp.RefPicList0[0] = ref_pic(&d->surfaces[d->prev_ref]);
    }

    // ── submit ──
    VABufferID bufs[4];
    int nbufs = 0;
    VAStatus st;
    st = vaCreateBuffer(d->dpy, d->context, VAPictureParameterBufferType,
                        sizeof pp, 1, &pp, &bufs[nbufs++]);
    if (st == VA_STATUS_SUCCESS) {
        st = vaCreateBuffer(d->dpy, d->context, VAIQMatrixBufferType,
                            sizeof iq, 1, &iq, &bufs[nbufs++]);
    }
    if (st == VA_STATUS_SUCCESS) {
        st = vaCreateBuffer(d->dpy, d->context, VASliceParameterBufferType,
                            sizeof sp, 1, &sp, &bufs[nbufs++]);
    }
    if (st == VA_STATUS_SUCCESS) {
        st = vaCreateBuffer(d->dpy, d->context, VASliceDataBufferType,
                            slice_len, 1, (void*)slice, &bufs[nbufs++]);
    }
    if (st != VA_STATUS_SUCCESS) {
        vd_err(d, "vaCreateBuffer", st);
        for (int i = 0; i < nbufs; i++) vaDestroyBuffer(d->dpy, bufs[i]);
        return -1;
    }

    st = vaBeginPicture(d->dpy, d->context, cur->id);
    if (st == VA_STATUS_SUCCESS) {
        st = vaRenderPicture(d->dpy, d->context, bufs, nbufs);
    }
    if (st == VA_STATUS_SUCCESS) {
        st = vaEndPicture(d->dpy, d->context);
    }
    for (int i = 0; i < nbufs; i++) vaDestroyBuffer(d->dpy, bufs[i]);
    if (st != VA_STATUS_SUCCESS) { vd_err(d, "decode submit", st); return -1; }

    st = vaSyncSurface(d->dpy, cur->id);
    if (st != VA_STATUS_SUCCESS) { vd_err(d, "vaSyncSurface", st); return -1; }

    // Every picture here is a reference (nal_ref_idc != 0 throughout our
    // streams); if one is not, the previous reference stays current.
    if (sh.nal_ref_idc != 0) d->prev_ref = slot;
    return 0;
}

static int fill_frame_from_desc(H264Decoder* d, Surface* s, H264Frame* out);

static int export_surface(H264Decoder* d, int slot, H264Frame* out) {
    Surface* s = &d->surfaces[slot];
    // Exported once per surface, not once per frame. A surface's underlying
    // buffer does not change when it is reused, so re-exporting only churns
    // fds and driver state — and at 60fps that churn, plus the EGLImage
    // import it forces downstream, was most of the player's CPU.
    if (s->exported) {
        fill_frame_from_desc(d, s, out);
        return 0;
    }
    VAStatus st = vaExportSurfaceHandle(
        d->dpy, s->id, VA_SURFACE_ATTRIB_MEM_TYPE_DRM_PRIME_2,
        VA_EXPORT_SURFACE_READ_ONLY | VA_EXPORT_SURFACE_SEPARATE_LAYERS,
        &s->desc);
    if (st != VA_STATUS_SUCCESS) { vd_err(d, "vaExportSurfaceHandle", st); return -1; }
    s->exported = 1;
    return fill_frame_from_desc(d, s, out);
}

/// Map an already-exported surface descriptor onto the caller's frame.
static int fill_frame_from_desc(H264Decoder* d, Surface* s, H264Frame* out) {
    // NV12 comes back either as one layer of two planes or as two
    // single-plane layers; radeonsi does the latter (R8 then GR88).
    const VADRMPRIMESurfaceDescriptor* desc = &s->desc;
    if (desc->num_objects < 1 || desc->num_layers < 1) {
        vd_err(d, "empty PRIME descriptor", VA_STATUS_SUCCESS);
        return -1;
    }
    uint32_t o0, off0, pitch0, o1, off1, pitch1;
    if (desc->layers[0].num_planes >= 2) {
        o0 = desc->layers[0].object_index[0];
        off0 = desc->layers[0].offset[0];
        pitch0 = desc->layers[0].pitch[0];
        o1 = desc->layers[0].object_index[1];
        off1 = desc->layers[0].offset[1];
        pitch1 = desc->layers[0].pitch[1];
    } else if (desc->num_layers >= 2) {
        o0 = desc->layers[0].object_index[0];
        off0 = desc->layers[0].offset[0];
        pitch0 = desc->layers[0].pitch[0];
        o1 = desc->layers[1].object_index[0];
        off1 = desc->layers[1].offset[0];
        pitch1 = desc->layers[1].pitch[0];
    } else {
        vd_err(d, "not a two-plane surface", VA_STATUS_SUCCESS);
        return -1;
    }
    if (o0 != o1) {
        vd_err(d, "planes span multiple dma-bufs", VA_STATUS_SUCCESS);
        return -1;
    }

    out->fd = desc->objects[o0].fd;
    out->width = d->sps.width;
    out->height = d->sps.height;
    out->modifier = desc->objects[o0].drm_format_modifier;
    out->offset0 = off0;
    out->pitch0 = pitch0;
    out->offset1 = off1;
    out->pitch1 = pitch1;
    out->token = s;
    return 0;
}

int h264_decoder_next(H264Decoder* d, H264Frame* out) {
    if (!d || !out) return 0;
    while (!atomic_load(&d->aborted)) {
        if (d->next_sample >= d->mp4.sample_count) return 0;
        int slot = free_surface(d);
        if (slot < 0) {
            vd_err(d, "no free surface", VA_STATUS_SUCCESS);
            return 0;
        }
        uint32_t index = d->next_sample++;
        int rc = decode_sample(d, index, slot);
        if (rc < 0) return 0;
        if (rc > 0) continue;              // skipped, try the next sample
        if (export_surface(d, slot, out) != 0) return 0;
        d->surfaces[slot].in_use = 1;
        out->position = mp4_sample_time(&d->mp4, index);
        return 1;
    }
    return 0;
}

void h264_decoder_release(H264Decoder* d, void* token) {
    if (!d || !token) return;
    for (int i = 0; i < VD_SURFACES; i++) {
        if (token == (void*)&d->surfaces[i]) {
            d->surfaces[i].in_use = 0;
            return;
        }
    }
}

void h264_decoder_abort(H264Decoder* d) {
    if (d) atomic_store(&d->aborted, 1);
}

const char* h264_decoder_error(const H264Decoder* d) {
    return d ? d->err : "";
}

// ─── test accessors ─────────────────────────────────────────────────────────
// Used only by the offline decode test, which reads surfaces back with
// vaGetImage to check the picture is right. Surfaces belong to a VADisplay,
// so the test cannot open its own.

void* h264_decoder_test_display(H264Decoder* d) { return d ? d->dpy : NULL; }

unsigned int h264_decoder_test_surface(void* token) {
    return token ? ((Surface*)token)->id : 0xffffffffu;
}
