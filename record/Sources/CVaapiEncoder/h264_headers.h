// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#ifndef STARLING_H264_HEADERS_H
#define STARLING_H264_HEADERS_H

#include <stddef.h>
#include <stdint.h>

// The parameter sets and slice headers for the one H.264 configuration this
// encoder produces. radeonsi does NOT synthesise these — asked to encode with
// no packed headers supplied, it returns the slice payload behind a NAL header
// byte of 0x00 (type "unspecified"), which no decoder will touch. So we write
// them, and they must agree exactly with the VAEnc*ParameterBufferH264 structs
// submitted alongside.
//
// The configuration is deliberately the narrowest thing that is still good
// quality, and it is chosen to match what VideoPlayerApp's CH264Decoder can
// decode zero-copy — recording and playback are two ends of one feature:
//
//   Main profile (77), CABAC, no 8x8 transform, no B-frames (ip_period 1),
//   one reference frame, one slice per picture, progressive frames only.
//
// Main rather than High because High's SPS carries the chroma_format_idc and
// scaling-list block that we would only ever fill with defaults, and nothing
// in the extra syntax buys quality at these settings.

/// The QP the PPS declares, and the only value that may appear there.
///
/// **This is not a quality knob and must not be derived from one.** radeonsi
/// ignores `VAEncPictureParameterBufferH264.pic_init_qp` and writes each
/// slice's `slice_qp_delta` relative to a hard-wired 26. Declare anything else
/// and SliceQPY comes out wrong by exactly that difference — which changes the
/// CABAC context initialisation, so the entropy decode diverges and every
/// P-frame decodes as garbage from macroblock 0. Measured: with this at 26
/// a recording decodes clean, and at 20/24/28/30 it does not.
///
/// Quality is set by the rate-control budget instead, which is where the
/// caller's `qp` argument has always gone.
#define H264_PIC_INIT_QP 26

typedef struct {
    int width, height;        // visible pixels
    int mb_width, mb_height;  // macroblocks (16px), >= visible
    int fps;
    int pic_init_qp;          // always H264_PIC_INIT_QP — see above
    int level_idc;
    // Wrap points, as log2(x) - 4. Both 4 here, i.e. 256 — comfortably more
    // than one IDR period, which is all that matters with no reordering.
    int log2_max_frame_num_minus4;
    int log2_max_poc_lsb_minus4;
} H264Config;

/// Fill `cfg` for these output dimensions. Picks a level that covers the
/// frame size and rate. There is no qp argument by design — see
/// H264_PIC_INIT_QP.
void h264_config_init(H264Config* cfg, int width, int height, int fps);

/// Write the SPS into `out`. `flags` is the H264_NAL_* mask from
/// h264_bitwriter.h: packed headers want START_CODE and no EMULATION (the
/// driver escapes); MP4's avcC wants neither start code nor... no, avcC
/// stores the NAL escaped and without a start code, so EMULATION alone.
/// Returns bytes written.
size_t h264_write_sps(const H264Config* cfg, int flags, uint8_t* out, size_t cap);

/// Write the PPS. Same `flags` contract as the SPS.
size_t h264_write_pps(const H264Config* cfg, int flags, uint8_t* out, size_t cap);

/// Write a slice header as an Annex-B NAL with no emulation prevention and
/// WITHOUT rbsp trailing bits — the hardware continues writing slice data
/// into the final partial byte, so terminating it here would corrupt the
/// picture.
///
/// `*bit_length` receives the length in bits of everything written, start
/// code and NAL header byte included, which is what
/// VAEncPackedHeaderParameterBuffer.bit_length must carry.
size_t h264_write_slice_header(const H264Config* cfg, int is_idr,
                               uint32_t frame_num, uint32_t idr_pic_id,
                               uint32_t poc_lsb, int slice_qp_delta,
                               uint8_t* out, size_t cap,
                               unsigned int* bit_length);

#endif  // STARLING_H264_HEADERS_H
