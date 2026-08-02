// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// In-process VAAPI H.264 encoder for the zero-copy recording path: dmabuf
// RGBA frames in (the engine's capture ring), an MP4 on disk out. Import,
// RGB→NV12 conversion, scaling, and the encode itself all run on the GPU
// through ffmpeg's libraries; the CPU only handles the compressed bitstream.
//
// The ffmpeg libraries are dlopen'd at first use, pinned to the sonames of
// the headers this file was BUILT against (a major-version mismatch between
// header structs and a runtime library corrupts memory — better to refuse
// and let the caller fall back to piping frames to the ffmpeg binary).
// Nothing here is a hard dependency: on a machine without the libraries,
// probe returns 0 and the pipe path still works.
//
// Threading: probe is internally serialized and callable from anywhere.
// A VaapiEncoder session is single-threaded — all calls on one queue.

#ifndef STARLING_VAAPI_ENCODER_H
#define STARLING_VAAPI_ENCODER_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct VaapiEncoder VaapiEncoder;

// 1 when the in-process path is usable on |device| (a render node): the
// libraries load and h264_vaapi actually opens there. A real driver check,
// not a capability query — tens of ms, run it off the main thread once.
int vaapi_encoder_probe(const char* device);

// Open one session: dmabuf frames of in_w x in_h pixels in, H.264 MP4 at
// out_w x out_h (must be even — 4:2:0) written to out_path. qp is the CQP
// quality (the pipe path's -qp). Returns NULL on failure.
VaapiEncoder* vaapi_encoder_open(const char* device,
                                 int in_w, int in_h,
                                 int out_w, int out_h,
                                 int fps, int qp,
                                 const char* out_path);

// Encode one frame. The fd is borrowed only for the duration of the call —
// the GPU work it feeds is fenced against the exporter through the kernel's
// implicit dma-buf synchronization, not through this API. pts_us is any
// monotonic microsecond clock; the first frame anchors t=0. Returns 0 on
// success; negative means the session is dead (abort it).
int vaapi_encoder_encode(VaapiEncoder* e, int fd, uint32_t stride,
                         uint32_t offset, uint32_t fourcc, uint64_t modifier,
                         uint64_t pts_us);

int64_t vaapi_encoder_frame_count(const VaapiEncoder* e);

// Flush the encoder, write the MP4 trailer, close the file. Returns 0 when
// the file is complete and at least one frame was encoded; the handle is
// then freed. On failure the handle stays live so the error can be read —
// follow with abort, which deletes the partial file.
int vaapi_encoder_finish(VaapiEncoder* e);

// Tear down and delete the partial output. Frees the handle.
void vaapi_encoder_abort(VaapiEncoder* e);

// Last error, human-readable. Valid until finish/abort.
const char* vaapi_encoder_error(const VaapiEncoder* e);

#ifdef __cplusplus
}
#endif

#endif  // STARLING_VAAPI_ENCODER_H
