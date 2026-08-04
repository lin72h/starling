// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// See vaapi_encoder.h. The pipeline is the in-process twin of the CLI the
// pipe path spawns —
//   ffmpeg -f rawvideo ... -vf hwupload,scale_vaapi=format=nv12
//          -c:v h264_vaapi -qp 24 -movflags +faststart out.mp4
// — with the hwupload (a CPU→GPU copy of every frame) replaced by mapping
// the engine's dmabuf straight into VAAPI:
//   buffer(DRM_PRIME) → hwmap=derive_device=vaapi → scale_vaapi(nv12) →
//   h264_vaapi → mp4.

#include "include/vaapi_encoder.h"

#include <dlfcn.h>
#include <limits.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <libavcodec/avcodec.h>
#include <libavfilter/avfilter.h>
#include <libavfilter/buffersink.h>
#include <libavfilter/buffersrc.h>
#include <libavformat/avformat.h>
#include <libavutil/hwcontext.h>
#include <libavutil/hwcontext_drm.h>
#include <libavutil/opt.h>

// ─── dlopen: every libav symbol used, resolved once ─────────────────────────
// X(library, symbol). __typeof__ against the real headers keeps the pointer
// signatures exact; the soname majors come from the same headers, so a
// library that loads is one whose structs match what we compiled against.

#define VE_SYMS(X)                                   \
  X(avutil, av_strdup)                               \
  X(avutil, av_free)                                 \
  X(avutil, av_mallocz)                              \
  X(avutil, av_strerror)                             \
  X(avutil, av_log_set_level)                        \
  X(avutil, av_dict_set)                             \
  X(avutil, av_dict_free)                            \
  X(avutil, av_opt_set_int)                          \
  X(avutil, av_frame_alloc)                          \
  X(avutil, av_frame_free)                           \
  X(avutil, av_frame_unref)                          \
  X(avutil, av_buffer_create)                        \
  X(avutil, av_buffer_ref)                           \
  X(avutil, av_buffer_unref)                         \
  X(avutil, av_hwdevice_ctx_create)                  \
  X(avutil, av_hwframe_ctx_alloc)                    \
  X(avutil, av_hwframe_ctx_init)                     \
  X(avcodec, avcodec_find_encoder_by_name)           \
  X(avcodec, avcodec_alloc_context3)                 \
  X(avcodec, avcodec_free_context)                   \
  X(avcodec, avcodec_open2)                          \
  X(avcodec, avcodec_send_frame)                     \
  X(avcodec, avcodec_receive_packet)                 \
  X(avcodec, avcodec_parameters_from_context)        \
  X(avcodec, av_packet_alloc)                        \
  X(avcodec, av_packet_free)                         \
  X(avcodec, av_packet_unref)                        \
  X(avcodec, av_packet_rescale_ts)                   \
  X(avformat, avformat_alloc_output_context2)        \
  X(avformat, avformat_new_stream)                   \
  X(avformat, avformat_free_context)                 \
  X(avformat, avio_open)                             \
  X(avformat, avio_closep)                           \
  X(avformat, avformat_write_header)                 \
  X(avformat, av_interleaved_write_frame)            \
  X(avformat, av_write_trailer)                      \
  X(avfilter, avfilter_graph_alloc)                  \
  X(avfilter, avfilter_graph_free)                   \
  X(avfilter, avfilter_graph_config)                 \
  X(avfilter, avfilter_graph_parse_ptr)              \
  X(avfilter, avfilter_graph_create_filter)          \
  X(avfilter, avfilter_graph_alloc_filter)           \
  X(avfilter, avfilter_init_str)                     \
  X(avfilter, avfilter_get_by_name)                  \
  X(avfilter, avfilter_inout_alloc)                  \
  X(avfilter, avfilter_inout_free)                   \
  X(avfilter, av_buffersrc_parameters_alloc)         \
  X(avfilter, av_buffersrc_parameters_set)           \
  X(avfilter, av_buffersrc_add_frame)                \
  X(avfilter, av_buffersink_get_frame)               \
  X(avfilter, av_buffersink_get_hw_frames_ctx)

#define VE_DECL(lib, sym) static __typeof__(&sym) p_##sym;
VE_SYMS(VE_DECL)
#undef VE_DECL

static int ve_load_ok = 0;

static void* ve_dlopen(const char* base, int major) {
  char name[64];
  snprintf(name, sizeof(name), "lib%s.so.%d", base, major);
  return dlopen(name, RTLD_NOW | RTLD_LOCAL);
}

static void ve_load(void) {
  void* h_avutil = ve_dlopen("avutil", LIBAVUTIL_VERSION_MAJOR);
  void* h_avcodec = ve_dlopen("avcodec", LIBAVCODEC_VERSION_MAJOR);
  void* h_avformat = ve_dlopen("avformat", LIBAVFORMAT_VERSION_MAJOR);
  void* h_avfilter = ve_dlopen("avfilter", LIBAVFILTER_VERSION_MAJOR);
  if (!h_avutil || !h_avcodec || !h_avformat || !h_avfilter) return;
#define VE_LOAD(lib, sym)                              \
  p_##sym = (__typeof__(&sym))dlsym(h_##lib, #sym);    \
  if (!p_##sym) return;
  VE_SYMS(VE_LOAD)
#undef VE_LOAD
  p_av_log_set_level(AV_LOG_ERROR);
  ve_load_ok = 1;
}

static int ensure_loaded(void) {
  static pthread_once_t once = PTHREAD_ONCE_INIT;
  pthread_once(&once, ve_load);
  return ve_load_ok;
}

// ─── Session ────────────────────────────────────────────────────────────────

struct VaapiEncoder {
  AVBufferRef* drm_dev;     // DRM hwdevice on the render node
  AVBufferRef* src_frames;  // DRM_PRIME frames ctx describing input dmabufs
  AVFilterGraph* graph;
  AVFilterContext* src_ctx;
  AVFilterContext* sink_ctx;
  AVCodecContext* enc;
  AVFormatContext* mux;
  AVStream* stream;
  AVFrame* filtered;  // scratch for buffersink output
  AVPacket* pkt;
  int in_w, in_h;
  int64_t frames;
  int have_first_pts;
  uint64_t first_pts;
  char err[256];
  char path[PATH_MAX];
};

static void ve_set_err(VaapiEncoder* e, const char* what, int averr) {
  char detail[128] = "";
  if (averr < 0) p_av_strerror(averr, detail, sizeof(detail));
  snprintf(e->err, sizeof(e->err), "%s%s%s", what, detail[0] ? ": " : "",
           detail);
}

static void ve_free(VaapiEncoder* e) {
  if (!e) return;
  if (e->pkt) p_av_packet_free(&e->pkt);
  if (e->filtered) p_av_frame_free(&e->filtered);
  if (e->graph) p_avfilter_graph_free(&e->graph);  // owns src/sink ctxs
  if (e->enc) p_avcodec_free_context(&e->enc);
  if (e->mux) {
    if (e->mux->pb) p_avio_closep(&e->mux->pb);
    p_avformat_free_context(e->mux);
  }
  if (e->src_frames) p_av_buffer_unref(&e->src_frames);
  if (e->drm_dev) p_av_buffer_unref(&e->drm_dev);
  free(e);
}

int vaapi_encoder_probe(const char* device) {
  if (!device || !ensure_loaded()) return 0;
  AVBufferRef* dev = NULL;
  if (p_av_hwdevice_ctx_create(&dev, AV_HWDEVICE_TYPE_VAAPI, device, NULL,
                               0) < 0) {
    return 0;
  }
  int ok = 0;
  const AVCodec* codec = p_avcodec_find_encoder_by_name("h264_vaapi");
  AVBufferRef* frames = codec ? p_av_hwframe_ctx_alloc(dev) : NULL;
  if (frames) {
    AVHWFramesContext* fc = (AVHWFramesContext*)frames->data;
    fc->format = AV_PIX_FMT_VAAPI;
    fc->sw_format = AV_PIX_FMT_NV12;
    fc->width = 128;
    fc->height = 128;
    fc->initial_pool_size = 4;
    if (p_av_hwframe_ctx_init(frames) >= 0) {
      AVCodecContext* c = p_avcodec_alloc_context3(codec);
      if (c) {
        c->width = 128;
        c->height = 128;
        c->time_base = (AVRational){1, 30};
        c->framerate = (AVRational){30, 1};
        c->pix_fmt = AV_PIX_FMT_VAAPI;
        c->max_b_frames = 0;
        c->hw_frames_ctx = p_av_buffer_ref(frames);
        p_av_opt_set_int(c->priv_data, "qp", 24, 0);
        if (c->hw_frames_ctx && p_avcodec_open2(c, codec, NULL) >= 0) ok = 1;
        p_avcodec_free_context(&c);
      }
    }
    p_av_buffer_unref(&frames);
  }
  p_av_buffer_unref(&dev);
  return ok;
}

VaapiEncoder* vaapi_encoder_open(const char* device,
                                 int in_w, int in_h,
                                 int out_w, int out_h,
                                 int fps, int qp,
                                 const char* out_path) {
  if (!device || !out_path || in_w <= 0 || in_h <= 0 || out_w <= 0 ||
      out_h <= 0 || (out_w & 1) || (out_h & 1) || !ensure_loaded()) {
    return NULL;
  }
  VaapiEncoder* e = calloc(1, sizeof(*e));
  if (!e) return NULL;
  e->in_w = in_w;
  e->in_h = in_h;
  snprintf(e->path, sizeof(e->path), "%s", out_path);
  int ret = 0;

  if ((ret = p_av_hwdevice_ctx_create(&e->drm_dev, AV_HWDEVICE_TYPE_DRM,
                                      device, NULL, 0)) < 0) {
    goto fail;
  }
  e->src_frames = p_av_hwframe_ctx_alloc(e->drm_dev);
  if (!e->src_frames) goto fail;
  {
    AVHWFramesContext* fc = (AVHWFramesContext*)e->src_frames->data;
    fc->format = AV_PIX_FMT_DRM_PRIME;
    fc->sw_format = AV_PIX_FMT_RGBA;  // DRM_FORMAT_ABGR8888: R,G,B,A bytes
    fc->width = in_w;
    fc->height = in_h;
    fc->initial_pool_size = 0;  // frames arrive from outside, never allocated
    if ((ret = p_av_hwframe_ctx_init(e->src_frames)) < 0) goto fail;
  }

  // Filter graph: map the dmabuf into a VAAPI surface on a device derived
  // from the DRM one, then GPU-convert/scale to NV12 for the encoder.
  e->graph = p_avfilter_graph_alloc();
  if (!e->graph) goto fail;
  {
    // A HW pix_fmt needs hw_frames_ctx set BEFORE the filter inits, so the
    // source can't go through graph_create_filter (which inits at once):
    // alloc bare → parameters_set → init.
    e->src_ctx = p_avfilter_graph_alloc_filter(
        e->graph, p_avfilter_get_by_name("buffer"), "in");
    if (!e->src_ctx) goto fail;
    AVBufferSrcParameters* par = p_av_buffersrc_parameters_alloc();
    if (!par) goto fail;
    par->format = AV_PIX_FMT_DRM_PRIME;
    par->width = in_w;
    par->height = in_h;
    par->time_base = (AVRational){1, 1000000};
    par->hw_frames_ctx = e->src_frames;
    ret = p_av_buffersrc_parameters_set(e->src_ctx, par);
    p_av_free(par);
    if (ret < 0) goto fail;
    if ((ret = p_avfilter_init_str(e->src_ctx, NULL)) < 0) goto fail;

    if ((ret = p_avfilter_graph_create_filter(
             &e->sink_ctx, p_avfilter_get_by_name("buffersink"), "out", NULL,
             NULL, e->graph)) < 0) {
      goto fail;
    }
    char desc[160];
    snprintf(desc, sizeof(desc),
             "hwmap=derive_device=vaapi,scale_vaapi=w=%d:h=%d:format=nv12",
             out_w, out_h);
    AVFilterInOut* outputs = p_avfilter_inout_alloc();
    AVFilterInOut* inputs = p_avfilter_inout_alloc();
    if (!outputs || !inputs) {
      p_avfilter_inout_free(&outputs);
      p_avfilter_inout_free(&inputs);
      goto fail;
    }
    outputs->name = p_av_strdup("in");
    outputs->filter_ctx = e->src_ctx;
    outputs->pad_idx = 0;
    outputs->next = NULL;
    inputs->name = p_av_strdup("out");
    inputs->filter_ctx = e->sink_ctx;
    inputs->pad_idx = 0;
    inputs->next = NULL;
    ret = p_avfilter_graph_parse_ptr(e->graph, desc, &inputs, &outputs, NULL);
    p_avfilter_inout_free(&inputs);
    p_avfilter_inout_free(&outputs);
    if (ret < 0) goto fail;
    if ((ret = p_avfilter_graph_config(e->graph, NULL)) < 0) goto fail;
  }

  // Muxer first (GLOBAL_HEADER must be known before the codec opens).
  if ((ret = p_avformat_alloc_output_context2(&e->mux, NULL, "mp4",
                                              out_path)) < 0) {
    goto fail;
  }

  {
    const AVCodec* codec = p_avcodec_find_encoder_by_name("h264_vaapi");
    if (!codec) goto fail;
    e->enc = p_avcodec_alloc_context3(codec);
    if (!e->enc) goto fail;
    e->enc->width = out_w;
    e->enc->height = out_h;
    e->enc->time_base = (AVRational){1, 1000000};
    e->enc->framerate = (AVRational){fps, 1};
    e->enc->pix_fmt = AV_PIX_FMT_VAAPI;
    e->enc->max_b_frames = 0;
    AVBufferRef* sink_frames = p_av_buffersink_get_hw_frames_ctx(e->sink_ctx);
    if (!sink_frames) goto fail;
    e->enc->hw_frames_ctx = p_av_buffer_ref(sink_frames);
    if (!e->enc->hw_frames_ctx) goto fail;
    if (e->mux->oformat->flags & AVFMT_GLOBALHEADER) {
      e->enc->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }
    // Capped VBR, not fixed QP. Constant QP has no upper bound on rate, and
    // on high-entropy screen content that runs away: a scrolling hex dump
    // captured at 1640x1100/60 produced 278MB for 37 seconds — 60 Mbps, or
    // 0.55 bits per pixel — and every byte of that has to be read back off
    // disk to play it. The target is derived from the picture rate so it
    // scales with what is actually being recorded, and clamped at both ends:
    // a floor so a small window still looks right, a ceiling so a busy 4K
    // capture cannot produce a file nothing wants to handle.
    //
    // `qp` still sets the quality: it is mapped onto the bits-per-pixel
    // budget rather than handed to the encoder, so the caller's existing
    // scale (lower = better) keeps its meaning.
    {
        double bpp = 0.15 * (24.0 / (qp > 0 ? (double)qp : 24.0));
        double target = (double)out_w * (double)out_h * (double)fps * bpp;
        if (target < 4e6) target = 4e6;
        if (target > 30e6) target = 30e6;
        e->enc->bit_rate = (int64_t)target;
        // Headroom for a burst (a window opening, a scene cut) without
        // letting the average drift up, and a buffer of about a second so
        // the rate is held over a sensible window rather than per frame.
        e->enc->rc_max_rate = (int64_t)(target * 1.5);
        e->enc->rc_buffer_size = (int64_t)(target * 1.5);
        // No "qp" option: setting it puts the VAAPI encoder in CQP mode and
        // the rate control above is then ignored entirely.
    }
    if ((ret = p_avcodec_open2(e->enc, codec, NULL)) < 0) goto fail;
  }

  e->stream = p_avformat_new_stream(e->mux, NULL);
  if (!e->stream) goto fail;
  if ((ret = p_avcodec_parameters_from_context(e->stream->codecpar,
                                               e->enc)) < 0) {
    goto fail;
  }
  e->stream->time_base = (AVRational){1, 1000000};
  e->stream->avg_frame_rate = (AVRational){fps, 1};
  if ((ret = p_avio_open(&e->mux->pb, out_path, AVIO_FLAG_WRITE)) < 0) {
    goto fail;
  }
  {
    AVDictionary* opts = NULL;
    p_av_dict_set(&opts, "movflags", "+faststart", 0);
    ret = p_avformat_write_header(e->mux, &opts);
    p_av_dict_free(&opts);
    if (ret < 0) goto fail;
  }

  e->filtered = p_av_frame_alloc();
  e->pkt = p_av_packet_alloc();
  if (!e->filtered || !e->pkt) goto fail;
  return e;

fail:
  // The caller falls back to the pipe encoder silently; leave the reason
  // where the shell's log will carry it.
  {
    char detail[128] = "";
    if (ret < 0) p_av_strerror(ret, detail, sizeof(detail));
    fprintf(stderr, "[VaapiEncoder] open failed%s%s\n",
            detail[0] ? ": " : "", detail);
  }
  ve_free(e);
  return NULL;
}

static void ve_free_desc(void* opaque, uint8_t* data) {
  (void)opaque;
  p_av_free(data);
}

// Pull every packet the encoder has ready and mux it. 0 or negative averror.
static int ve_drain_packets(VaapiEncoder* e) {
  for (;;) {
    int ret = p_avcodec_receive_packet(e->enc, e->pkt);
    if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) return 0;
    if (ret < 0) {
      ve_set_err(e, "receive_packet", ret);
      return ret;
    }
    e->pkt->stream_index = e->stream->index;
    p_av_packet_rescale_ts(e->pkt, e->enc->time_base, e->stream->time_base);
    ret = p_av_interleaved_write_frame(e->mux, e->pkt);
    if (ret < 0) {
      ve_set_err(e, "write_frame", ret);
      return ret;
    }
  }
}

// Run the filter graph dry and feed everything it yields to the encoder.
static int ve_drain_graph(VaapiEncoder* e) {
  for (;;) {
    int ret = p_av_buffersink_get_frame(e->sink_ctx, e->filtered);
    if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) return 0;
    if (ret < 0) {
      ve_set_err(e, "buffersink", ret);
      return ret;
    }
    ret = p_avcodec_send_frame(e->enc, e->filtered);
    p_av_frame_unref(e->filtered);
    if (ret < 0) {
      ve_set_err(e, "send_frame", ret);
      return ret;
    }
    if ((ret = ve_drain_packets(e)) < 0) return ret;
    e->frames++;
  }
}

int vaapi_encoder_encode(VaapiEncoder* e, int fd, uint32_t stride,
                         uint32_t offset, uint32_t fourcc, uint64_t modifier,
                         uint64_t pts_us) {
  if (!e || fd < 0) return -1;
  AVDRMFrameDescriptor* desc = p_av_mallocz(sizeof(*desc));
  if (!desc) return AVERROR(ENOMEM);
  off_t size = lseek(fd, 0, SEEK_END);
  desc->nb_objects = 1;
  desc->objects[0].fd = fd;
  desc->objects[0].size =
      size > 0 ? (size_t)size : (size_t)stride * e->in_h + offset;
  desc->objects[0].format_modifier = modifier;
  desc->nb_layers = 1;
  desc->layers[0].format = fourcc;
  desc->layers[0].nb_planes = 1;
  desc->layers[0].planes[0].object_index = 0;
  desc->layers[0].planes[0].offset = offset;
  desc->layers[0].planes[0].pitch = stride;

  AVFrame* f = p_av_frame_alloc();
  if (!f) {
    p_av_free(desc);
    return AVERROR(ENOMEM);
  }
  f->buf[0] = p_av_buffer_create((uint8_t*)desc, sizeof(*desc), ve_free_desc,
                                 NULL, 0);
  if (!f->buf[0]) {
    p_av_free(desc);
    p_av_frame_free(&f);
    return AVERROR(ENOMEM);
  }
  f->data[0] = (uint8_t*)desc;
  f->format = AV_PIX_FMT_DRM_PRIME;
  f->width = e->in_w;
  f->height = e->in_h;
  f->hw_frames_ctx = p_av_buffer_ref(e->src_frames);
  if (!f->hw_frames_ctx) {
    p_av_frame_free(&f);
    return AVERROR(ENOMEM);
  }
  if (!e->have_first_pts) {
    e->have_first_pts = 1;
    e->first_pts = pts_us;
  }
  f->pts = (int64_t)(pts_us - e->first_pts);

  int ret = p_av_buffersrc_add_frame(e->src_ctx, f);
  p_av_frame_free(&f);
  if (ret < 0) {
    ve_set_err(e, "buffersrc (dmabuf import)", ret);
    return ret;
  }
  return ve_drain_graph(e);
}

int64_t vaapi_encoder_frame_count(const VaapiEncoder* e) {
  return e ? e->frames : 0;
}

const char* vaapi_encoder_error(const VaapiEncoder* e) {
  return e ? e->err : "";
}

int vaapi_encoder_finish(VaapiEncoder* e) {
  if (!e) return -1;
  int ret = p_av_buffersrc_add_frame(e->src_ctx, NULL);  // flush filters
  if (ret >= 0) ret = ve_drain_graph(e);
  if (ret >= 0) {
    ret = p_avcodec_send_frame(e->enc, NULL);  // flush encoder
    if (ret >= 0 || ret == AVERROR_EOF) ret = ve_drain_packets(e);
  }
  int trailer = p_av_write_trailer(e->mux);  // faststart remux happens here
  if (ret >= 0 && trailer < 0) {
    ve_set_err(e, "write_trailer", trailer);
    ret = trailer;
  }
  if (ret >= 0 && e->frames == 0) {
    snprintf(e->err, sizeof(e->err), "no frames were encoded");
    ret = -1;
  }
  if (ret < 0) return -1;  // handle stays live: read error, then abort
  ve_free(e);
  return 0;
}

void vaapi_encoder_abort(VaapiEncoder* e) {
  if (!e) return;
  char path[PATH_MAX];
  snprintf(path, sizeof(path), "%s", e->path);
  ve_free(e);
  unlink(path);
}
