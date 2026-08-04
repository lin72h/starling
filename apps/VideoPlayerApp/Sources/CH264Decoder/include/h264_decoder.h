// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#ifndef STARLING_H264_DECODER_H
#define STARLING_H264_DECODER_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Hardware H.264 decode with no libav anywhere: our own MP4 demuxer, our own
// SPS/PPS and slice-header parsing, straight into VA-API, out as a DMA-BUF
// the compositor samples. Deliberately narrow.
//
// WHY THIS CAN BE SMALL. Decoding arbitrary H.264 is a large job because the
// bitstream may reorder pictures, keep up to 16 references, and rewrite the
// reference lists per slice. The desktop's own recorder emits none of that —
// `max_b_frames = 0` and one reference, confirmed in its output
// (has_b_frames=0, refs=1) — so output order is decode order, the DPB is one
// picture deep, and the reference list is "the previous frame". That is the
// bulk of the difficulty, gone by construction.
//
// So this is NOT a general H.264 decoder and must never pretend to be. Every
// entry point validates its assumptions and refuses the file rather than
// guessing: B-slices, more than one reference, several slices per picture,
// interlaced coding, CABAC-with-8x8-transform combinations we do not model,
// anything unexpected. A refusal is not a failure — the player falls back to
// PipeDecoder, which spawns ffmpeg and plays anything. The narrow path exists
// to make the COMMON case (reviewing your own screen recording) zero-copy,
// not to replace a real decoder.

/// One decoded frame, valid until `release`. Identical in shape to what the
/// libav-backed path produced, so the Swift side is unchanged: NV12, both
/// planes usually inside one DMA-BUF at different offsets.
typedef struct {
    int fd;                   // NOT owned — valid until h264_decoder_release
    int width;
    int height;
    uint64_t modifier;
    uint32_t offset0, pitch0; // luma
    uint32_t offset1, pitch1; // chroma
    double position;          // presentation time, seconds
    void* token;              // hand back to h264_decoder_release
} H264Frame;

typedef struct {
    int width;
    int height;
    double fps;
    double duration;
} H264Info;

typedef struct H264Decoder H264Decoder;

/// Read dimensions, frame rate and duration from the MP4 index. Negative if
/// the file is not an MP4 we understand — the caller then uses ffprobe.
int h264_decoder_probe_info(const char* path, H264Info* out);

/// Whether this file is one the narrow path can take: an MP4 whose video
/// track is H.264 with a single reference, no B-frames, and a profile the
/// parser models. Cheap — index and parameter sets only, no decoding.
int h264_decoder_supported(const char* path);

/// Open for decode on `render_node`, positioned at the last keyframe at or
/// before `start` seconds. NULL if unsupported or VA-API refuses.
H264Decoder* h264_decoder_open(const char* path, const char* render_node,
                               double start);

/// Block until the next frame is decoded; 1 on success, 0 at end of stream
/// or after abort. The surface stays out of the pool until `release`.
int h264_decoder_next(H264Decoder* d, H264Frame* out);

/// Return a frame's surface to the pool. Only once the GPU is done with it.
void h264_decoder_release(H264Decoder* d, void* token);

/// Unblock a thread inside h264_decoder_next. Safe from any thread.
void h264_decoder_abort(H264Decoder* d);

void h264_decoder_close(H264Decoder* d);

/// Last error, or "" — for logging only.
const char* h264_decoder_error(const H264Decoder* d);

#ifdef __cplusplus
}
#endif

#endif  // STARLING_H264_DECODER_H
