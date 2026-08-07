// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#ifndef STARLING_H264_BITWRITER_H
#define STARLING_H264_BITWRITER_H

#include <stddef.h>
#include <stdint.h>

// RBSP bit writer — the mirror of the reader in VideoPlayerApp's h264_bits.c,
// and used for the same reason in reverse: VA-API asks the caller to hand it
// the SPS, PPS and slice header as *packed headers*, i.e. real bitstream, and
// they must agree exactly with the VAEnc*ParameterBufferH264 structs
// submitted alongside. A mismatch is not an error anywhere — it produces a
// file that some decoders play and others reject.
//
// Fixed capacity, no allocation: the headers this writes are tens of bytes,
// and a parameter set that would overflow the buffer is a bug, not an input.
// `overflow` latches so the caller checks once at the end.

#define H264_BW_CAP 512

typedef struct {
    uint8_t buf[H264_BW_CAP];
    size_t byte;      // next byte to write
    int bit;          // next bit within buf[byte], 0 = MSB
    int overflow;
} H264BitWriter;

void h264_bw_init(H264BitWriter* w);

/// Write the low `n` bits of `v`, MSB first. n <= 32.
void h264_bw_u(H264BitWriter* w, int n, uint32_t v);

/// Unsigned Exp-Golomb.
void h264_bw_ue(H264BitWriter* w, uint32_t v);

/// Signed Exp-Golomb.
void h264_bw_se(H264BitWriter* w, int32_t v);

/// rbsp_trailing_bits(): a 1 then zeros to the byte boundary.
void h264_bw_trailing(H264BitWriter* w);

/// Bits written so far — the slice header's length in bits, which VA-API
/// wants as `bit_length` on the packed-header parameter buffer.
size_t h264_bw_bit_length(const H264BitWriter* w);

/// Emit `nal_unit_type`/`nal_ref_idc` plus the RBSP written so far into `out`
/// as a NAL. Returns bytes written, or 0 if it would not fit.
///
/// `flags` is a mask:
///  - H264_NAL_START_CODE: prefix the 4-byte Annex-B start code. VA-API's
///    packed headers want it; MP4's avcC stores bare NALs.
///  - H264_NAL_EMULATION: insert emulation-prevention bytes (00 00 00/01/02/03
///    becomes 00 00 03 xx).
///
/// **Packed headers must be written WITHOUT emulation.** VA-API takes
/// `bit_length` as the size of the buffer handed to it, and the slice header
/// ends mid-byte with the hardware continuing from that exact bit — an
/// inserted 0x03 shifts everything after it and the picture decodes as
/// garbage. Pass has_emulation_bytes=0 and let the driver escape, which is
/// what it is written to do.
#define H264_NAL_START_CODE 1
#define H264_NAL_EMULATION  2
size_t h264_bw_emit_nal(const H264BitWriter* w, int nal_ref_idc,
                        int nal_unit_type, int flags,
                        uint8_t* out, size_t out_cap);

#endif  // STARLING_H264_BITWRITER_H
