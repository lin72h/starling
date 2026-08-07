// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// See h264_bitwriter.h.

#include "h264_bitwriter.h"

#include <string.h>

void h264_bw_init(H264BitWriter* w) {
    memset(w, 0, sizeof(*w));
}

void h264_bw_u(H264BitWriter* w, int n, uint32_t v) {
    for (int i = n - 1; i >= 0; i--) {
        if (w->byte >= H264_BW_CAP) { w->overflow = 1; return; }
        uint32_t b = (v >> i) & 1u;
        w->buf[w->byte] |= (uint8_t)(b << (7 - w->bit));
        if (++w->bit == 8) { w->bit = 0; w->byte++; }
    }
}

// ue(v): write (v+1) in binary, preceded by one fewer zeros than it has bits.
// v+1 is computed in 64 bits so that v = UINT32_MAX does not wrap to zero and
// silently encode as a single 1 bit.
void h264_bw_ue(H264BitWriter* w, uint32_t v) {
    uint64_t code = (uint64_t)v + 1;
    int bits = 0;
    while ((code >> bits) > 1) bits++;
    h264_bw_u(w, bits, 0);                       // the leading zeros
    for (int i = bits; i >= 0; i--) {            // then code, MSB first
        h264_bw_u(w, 1, (uint32_t)((code >> i) & 1));
    }
}

// se(v): the usual zig-zag onto ue(v) — 0,1,-1,2,-2 → 0,1,2,3,4.
void h264_bw_se(H264BitWriter* w, int32_t v) {
    uint32_t mapped;
    if (v <= 0) {
        mapped = (uint32_t)(-(int64_t)v) * 2u;
    } else {
        mapped = (uint32_t)((int64_t)v * 2 - 1);
    }
    h264_bw_ue(w, mapped);
}

void h264_bw_trailing(H264BitWriter* w) {
    h264_bw_u(w, 1, 1);
    while (w->bit != 0) h264_bw_u(w, 1, 0);
}

size_t h264_bw_bit_length(const H264BitWriter* w) {
    return w->byte * 8 + (size_t)w->bit;
}

size_t h264_bw_emit_nal(const H264BitWriter* w, int nal_ref_idc,
                        int nal_unit_type, int flags,
                        uint8_t* out, size_t out_cap) {
    if (w->overflow || !out) return 0;
    // Any partial byte is payload too: callers that stop mid-byte (a slice
    // header, which the hardware continues writing into) still need it.
    size_t payload = w->byte + (w->bit ? 1 : 0);
    size_t n = 0;

    if (flags & H264_NAL_START_CODE) {
        if (out_cap < 4) return 0;
        out[n++] = 0; out[n++] = 0; out[n++] = 0; out[n++] = 1;
    }
    if (n + 1 > out_cap) return 0;
    out[n++] = (uint8_t)(((nal_ref_idc & 3) << 5) | (nal_unit_type & 0x1f));

    // Emulation prevention: the decoder scans for 00 00 00/01/02/03 and would
    // mistake it for a start code, so a 03 is stuffed in. `zeros` counts the
    // run, and is reset by the inserted byte as well — 00 00 03 03 is how a
    // literal 00 00 03 is carried. The NAL header byte is part of the scan.
    int emulate = (flags & H264_NAL_EMULATION) != 0;
    int zeros = 0;
    for (size_t i = 0; i < payload; i++) {
        uint8_t b = w->buf[i];
        if (emulate && zeros == 2 && b <= 0x03) {
            if (n + 1 > out_cap) return 0;
            out[n++] = 0x03;
            zeros = 0;
        }
        if (n + 1 > out_cap) return 0;
        out[n++] = b;
        zeros = (b == 0) ? zeros + 1 : 0;
    }
    return n;
}
