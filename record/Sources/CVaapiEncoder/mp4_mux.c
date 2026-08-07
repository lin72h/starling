// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// See mp4_mux.h. Box layout follows ISO/IEC 14496-12 (the base format) and
// 14496-15 (AVC in it). Only the boxes a player actually needs to decode a
// single video track are written; everything optional is left out rather than
// filled with defaults, so nothing here is decorative.

#include "mp4_mux.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MP4_SPS_MAX 256
#define MP4_PPS_MAX 256

typedef struct {
    uint64_t offset;    // in the file
    uint32_t size;      // bytes of length-prefixed NALs
    uint64_t dts;
    int keyframe;
} Mp4Sample;

struct Mp4Mux {
    FILE* f;
    int width, height;
    uint32_t timescale;
    uint8_t sps[MP4_SPS_MAX]; size_t sps_len;
    uint8_t pps[MP4_PPS_MAX]; size_t pps_len;

    Mp4Sample* samples;
    size_t sample_count, sample_cap;

    uint64_t mdat_start;      // offset of the mdat box header
    uint64_t mdat_payload;    // offset of the first sample byte
    uint8_t* scratch;         // Annex-B -> length-prefix rewriting
    size_t scratch_cap;
    char err[192];
};

// ─── byte helpers ───────────────────────────────────────────────────────────

static void put_u8(FILE* f, uint8_t v) { fputc(v, f); }
static void put_u16(FILE* f, uint16_t v) { put_u8(f, v >> 8); put_u8(f, v & 0xff); }
static void put_u32(FILE* f, uint32_t v) { put_u16(f, v >> 16); put_u16(f, v & 0xffff); }
static void put_u64(FILE* f, uint64_t v) { put_u32(f, (uint32_t)(v >> 32)); put_u32(f, (uint32_t)v); }
static void put_tag(FILE* f, const char* t) { fwrite(t, 1, 4, f); }

/// Open a box, returning its start offset so `end_box` can patch the size.
static long begin_box(FILE* f, const char* tag) {
    long at = ftell(f);
    put_u32(f, 0);          // size, patched by end_box
    put_tag(f, tag);
    return at;
}

static void end_box(FILE* f, long at) {
    long now = ftell(f);
    fseek(f, at, SEEK_SET);
    put_u32(f, (uint32_t)(now - at));
    fseek(f, now, SEEK_SET);
}

static void put_full_box_header(FILE* f, uint8_t version, uint32_t flags) {
    put_u8(f, version);
    put_u8(f, (uint8_t)(flags >> 16));
    put_u8(f, (uint8_t)(flags >> 8));
    put_u8(f, (uint8_t)flags);
}

static void mux_err(Mp4Mux* m, const char* what) {
    snprintf(m->err, sizeof m->err, "%s", what);
}

// ─── open ───────────────────────────────────────────────────────────────────

Mp4Mux* mp4_mux_open(const char* path, int width, int height,
                     uint32_t timescale,
                     const uint8_t* sps, size_t sps_len,
                     const uint8_t* pps, size_t pps_len) {
    if (!path || !sps || !pps || sps_len == 0 || pps_len == 0) return NULL;
    if (sps_len > MP4_SPS_MAX || pps_len > MP4_PPS_MAX) return NULL;
    Mp4Mux* m = calloc(1, sizeof *m);
    if (!m) return NULL;
    m->f = fopen(path, "wb");
    if (!m->f) { free(m); return NULL; }
    m->width = width;
    m->height = height;
    m->timescale = timescale ? timescale : 1000000;
    memcpy(m->sps, sps, sps_len); m->sps_len = sps_len;
    memcpy(m->pps, pps, pps_len); m->pps_len = pps_len;

    // ftyp
    long b = begin_box(m->f, "ftyp");
    put_tag(m->f, "isom");
    put_u32(m->f, 512);              // minor_version
    put_tag(m->f, "isom");
    put_tag(m->f, "iso2");
    put_tag(m->f, "avc1");
    put_tag(m->f, "mp41");
    end_box(m->f, b);

    // mdat, opened now and sized at finish. A 64-bit `largesize` is always
    // used: a screen recording passes 4 GB in a few minutes at these
    // resolutions, and discovering that at finish, with the payload already
    // written at a 32-bit-header offset, would mean rewriting the file.
    m->mdat_start = (uint64_t)ftell(m->f);
    put_u32(m->f, 1);                // size == 1 -> read largesize
    put_tag(m->f, "mdat");
    put_u64(m->f, 0);                // largesize, patched at finish
    m->mdat_payload = (uint64_t)ftell(m->f);
    return m;
}

// ─── samples ────────────────────────────────────────────────────────────────

static int ensure_scratch(Mp4Mux* m, size_t need) {
    if (m->scratch_cap >= need) return 0;
    size_t cap = m->scratch_cap ? m->scratch_cap : 1 << 16;
    while (cap < need) cap *= 2;
    uint8_t* p = realloc(m->scratch, cap);
    if (!p) { mux_err(m, "out of memory for the sample buffer"); return -1; }
    m->scratch = p;
    m->scratch_cap = cap;
    return 0;
}

static int push_sample(Mp4Mux* m, const Mp4Sample* s) {
    if (m->sample_count == m->sample_cap) {
        size_t cap = m->sample_cap ? m->sample_cap * 2 : 1024;
        Mp4Sample* p = realloc(m->samples, cap * sizeof *p);
        if (!p) { mux_err(m, "out of memory for the sample index"); return -1; }
        m->samples = p;
        m->sample_cap = cap;
    }
    m->samples[m->sample_count++] = *s;
    return 0;
}

/// Find the next Annex-B start code at or after `i`. Returns its offset and
/// the length (3 or 4), or size when there is none left.
static size_t next_start_code(const uint8_t* d, size_t size, size_t i, int* len) {
    for (; i + 3 <= size; i++) {
        if (d[i] == 0 && d[i + 1] == 0) {
            if (d[i + 2] == 1) { *len = 3; return i; }
            if (i + 4 <= size && d[i + 2] == 0 && d[i + 3] == 1) { *len = 4; return i; }
        }
    }
    return size;
}

int mp4_mux_write_sample(Mp4Mux* m, const uint8_t* data, size_t size,
                         uint64_t dts, int is_keyframe) {
    if (!m || !m->f || !data) return -1;
    if (ensure_scratch(m, size + 16) != 0) return -1;

    // Annex-B in, length-prefixed out. SPS and PPS are dropped: in MP4 they
    // live in avcC, and a decoder that meets them again inline is entitled to
    // be confused about which is authoritative.
    size_t out = 0;
    int sc_len = 0;
    size_t pos = next_start_code(data, size, 0, &sc_len);
    while (pos < size) {
        size_t nal_start = pos + (size_t)sc_len;
        int next_len = 0;
        size_t next = next_start_code(data, size, nal_start, &next_len);
        size_t nal_len = next - nal_start;
        if (nal_len > 0) {
            uint8_t type = data[nal_start] & 0x1f;
            if (type != 7 && type != 8) {     // not SPS, not PPS
                if (ensure_scratch(m, out + 4 + nal_len) != 0) return -1;
                m->scratch[out++] = (uint8_t)(nal_len >> 24);
                m->scratch[out++] = (uint8_t)(nal_len >> 16);
                m->scratch[out++] = (uint8_t)(nal_len >> 8);
                m->scratch[out++] = (uint8_t)nal_len;
                memcpy(m->scratch + out, data + nal_start, nal_len);
                out += nal_len;
            }
        }
        pos = next;
        sc_len = next_len;
    }
    if (out == 0) { mux_err(m, "access unit had no codable NAL"); return -1; }

    Mp4Sample s = {
        .offset = (uint64_t)ftell(m->f),
        .size = (uint32_t)out,
        .dts = dts,
        .keyframe = is_keyframe != 0,
    };
    if (fwrite(m->scratch, 1, out, m->f) != out) {
        mux_err(m, "short write to the recording");
        return -1;
    }
    return push_sample(m, &s);
}

int64_t mp4_mux_sample_count(const Mp4Mux* m) {
    return m ? (int64_t)m->sample_count : 0;
}

// ─── index ──────────────────────────────────────────────────────────────────

static void write_avcc(Mp4Mux* m) {
    FILE* f = m->f;
    long b = begin_box(f, "avcC");
    put_u8(f, 1);                       // configurationVersion
    put_u8(f, m->sps[1]);               // AVCProfileIndication  (from the SPS)
    put_u8(f, m->sps[2]);               // profile_compatibility
    put_u8(f, m->sps[3]);               // AVCLevelIndication
    put_u8(f, 0xff);                    // 6 bits reserved + lengthSizeMinusOne=3
    put_u8(f, 0xe1);                    // 3 bits reserved + numOfSPS=1
    put_u16(f, (uint16_t)m->sps_len);
    fwrite(m->sps, 1, m->sps_len, f);
    put_u8(f, 1);                       // numOfPPS
    put_u16(f, (uint16_t)m->pps_len);
    fwrite(m->pps, 1, m->pps_len, f);
    end_box(f, b);
}

/// stts: run-length coded sample durations. The last sample has no successor
/// to measure against, so it repeats the previous duration — the alternative
/// is a zero-length final frame, which players show as a glitch.
static void write_stts(Mp4Mux* m) {
    FILE* f = m->f;
    long b = begin_box(f, "stts");
    put_full_box_header(f, 0, 0);
    long count_at = ftell(f);
    put_u32(f, 0);
    uint32_t entries = 0;
    size_t n = m->sample_count;
    uint32_t run_count = 0, run_delta = 0;
    for (size_t i = 0; i < n; i++) {
        uint32_t delta;
        if (i + 1 < n) {
            uint64_t d = m->samples[i + 1].dts - m->samples[i].dts;
            delta = (uint32_t)d;
        } else {
            delta = run_delta ? run_delta : (m->timescale / 30);
        }
        if (run_count && delta == run_delta) {
            run_count++;
        } else {
            if (run_count) { put_u32(f, run_count); put_u32(f, run_delta); entries++; }
            run_count = 1;
            run_delta = delta;
        }
    }
    if (run_count) { put_u32(f, run_count); put_u32(f, run_delta); entries++; }
    long now = ftell(f);
    fseek(f, count_at, SEEK_SET);
    put_u32(f, entries);
    fseek(f, now, SEEK_SET);
    end_box(f, b);
}

static void write_stbl(Mp4Mux* m) {
    FILE* f = m->f;
    long b = begin_box(f, "stbl");

    // stsd -> avc1 -> avcC
    long sd = begin_box(f, "stsd");
    put_full_box_header(f, 0, 0);
    put_u32(f, 1);                      // entry_count
    long avc1 = begin_box(f, "avc1");
    for (int i = 0; i < 6; i++) put_u8(f, 0);   // reserved
    put_u16(f, 1);                      // data_reference_index
    put_u16(f, 0); put_u16(f, 0);       // pre_defined, reserved
    for (int i = 0; i < 3; i++) put_u32(f, 0);  // pre_defined[3]
    put_u16(f, (uint16_t)m->width);
    put_u16(f, (uint16_t)m->height);
    put_u32(f, 0x00480000);             // horizresolution 72dpi
    put_u32(f, 0x00480000);             // vertresolution
    put_u32(f, 0);                      // reserved
    put_u16(f, 1);                      // frame_count
    for (int i = 0; i < 32; i++) put_u8(f, 0);  // compressorname
    put_u16(f, 0x0018);                 // depth
    put_u16(f, 0xffff);                 // pre_defined = -1
    write_avcc(m);
    end_box(f, avc1);
    end_box(f, sd);

    write_stts(m);

    // stss — sync samples. Omitted entirely when every sample is a keyframe,
    // which is what the spec says it means.
    size_t sync = 0;
    for (size_t i = 0; i < m->sample_count; i++) sync += m->samples[i].keyframe != 0;
    if (sync != m->sample_count) {
        long ss = begin_box(f, "stss");
        put_full_box_header(f, 0, 0);
        put_u32(f, (uint32_t)sync);
        for (size_t i = 0; i < m->sample_count; i++) {
            if (m->samples[i].keyframe) put_u32(f, (uint32_t)(i + 1));  // 1-based
        }
        end_box(f, ss);
    }

    // stsc — one sample per chunk, so a single entry describes the lot.
    long sc = begin_box(f, "stsc");
    put_full_box_header(f, 0, 0);
    put_u32(f, 1);                      // entry_count
    put_u32(f, 1);                      // first_chunk
    put_u32(f, 1);                      // samples_per_chunk
    put_u32(f, 1);                      // sample_description_index
    end_box(f, sc);

    // stsz
    long sz = begin_box(f, "stsz");
    put_full_box_header(f, 0, 0);
    put_u32(f, 0);                      // sample_size 0 -> table follows
    put_u32(f, (uint32_t)m->sample_count);
    for (size_t i = 0; i < m->sample_count; i++) put_u32(f, m->samples[i].size);
    end_box(f, sz);

    // co64 rather than stco: sample offsets pass 4 GB in a long recording,
    // and a truncated offset points at nothing.
    long co = begin_box(f, "co64");
    put_full_box_header(f, 0, 0);
    put_u32(f, (uint32_t)m->sample_count);
    for (size_t i = 0; i < m->sample_count; i++) put_u64(f, m->samples[i].offset);
    end_box(f, co);

    end_box(f, b);
}

static void write_moov(Mp4Mux* m, uint64_t duration) {
    FILE* f = m->f;
    long mo = begin_box(f, "moov");

    long mvhd = begin_box(f, "mvhd");
    put_full_box_header(f, 0, 0);
    put_u32(f, 0);                      // creation_time
    put_u32(f, 0);                      // modification_time
    put_u32(f, m->timescale);
    put_u32(f, (uint32_t)duration);
    put_u32(f, 0x00010000);             // rate 1.0
    put_u16(f, 0x0100);                 // volume 1.0
    put_u16(f, 0);                      // reserved
    put_u32(f, 0); put_u32(f, 0);       // reserved[2]
    // unity matrix
    put_u32(f, 0x00010000); put_u32(f, 0); put_u32(f, 0);
    put_u32(f, 0); put_u32(f, 0x00010000); put_u32(f, 0);
    put_u32(f, 0); put_u32(f, 0); put_u32(f, 0x40000000);
    for (int i = 0; i < 6; i++) put_u32(f, 0);  // pre_defined
    put_u32(f, 2);                      // next_track_ID
    end_box(f, mvhd);

    long trak = begin_box(f, "trak");
    long tkhd = begin_box(f, "tkhd");
    put_full_box_header(f, 0, 7);       // enabled | in movie | in preview
    put_u32(f, 0); put_u32(f, 0);       // times
    put_u32(f, 1);                      // track_ID
    put_u32(f, 0);                      // reserved
    put_u32(f, (uint32_t)duration);
    put_u32(f, 0); put_u32(f, 0);       // reserved[2]
    put_u16(f, 0);                      // layer
    put_u16(f, 0);                      // alternate_group
    put_u16(f, 0);                      // volume (video: 0)
    put_u16(f, 0);                      // reserved
    put_u32(f, 0x00010000); put_u32(f, 0); put_u32(f, 0);
    put_u32(f, 0); put_u32(f, 0x00010000); put_u32(f, 0);
    put_u32(f, 0); put_u32(f, 0); put_u32(f, 0x40000000);
    put_u32(f, (uint32_t)m->width << 16);   // 16.16 fixed point
    put_u32(f, (uint32_t)m->height << 16);
    end_box(f, tkhd);

    long mdia = begin_box(f, "mdia");
    long mdhd = begin_box(f, "mdhd");
    put_full_box_header(f, 0, 0);
    put_u32(f, 0); put_u32(f, 0);
    put_u32(f, m->timescale);
    put_u32(f, (uint32_t)duration);
    put_u16(f, 0x55c4);                 // language "und"
    put_u16(f, 0);                      // pre_defined
    end_box(f, mdhd);

    long hdlr = begin_box(f, "hdlr");
    put_full_box_header(f, 0, 0);
    put_u32(f, 0);                      // pre_defined
    put_tag(f, "vide");
    put_u32(f, 0); put_u32(f, 0); put_u32(f, 0);   // reserved[3]
    fwrite("VideoHandler", 1, 13, f);   // name, NUL terminated
    end_box(f, hdlr);

    long minf = begin_box(f, "minf");
    long vmhd = begin_box(f, "vmhd");
    put_full_box_header(f, 0, 1);
    put_u16(f, 0);                      // graphicsmode
    put_u16(f, 0); put_u16(f, 0); put_u16(f, 0);   // opcolor
    end_box(f, vmhd);

    long dinf = begin_box(f, "dinf");
    long dref = begin_box(f, "dref");
    put_full_box_header(f, 0, 0);
    put_u32(f, 1);                      // entry_count
    long url = begin_box(f, "url ");
    put_full_box_header(f, 0, 1);       // self-contained
    end_box(f, url);
    end_box(f, dref);
    end_box(f, dinf);

    write_stbl(m);
    end_box(f, minf);
    end_box(f, mdia);
    end_box(f, trak);
    end_box(f, mo);
}

int mp4_mux_finish(Mp4Mux* m) {
    if (!m) return -1;
    int rc = -1;
    if (!m->f) { mux_err(m, "already closed"); goto done; }
    if (m->sample_count == 0) { mux_err(m, "no frames were encoded"); goto done; }

    // Patch the mdat largesize now that the payload is complete.
    uint64_t end = (uint64_t)ftell(m->f);
    if (fseek(m->f, (long)(m->mdat_start + 8), SEEK_SET) != 0) {
        mux_err(m, "seek to the mdat header failed"); goto done;
    }
    put_u64(m->f, end - m->mdat_start);
    if (fseek(m->f, (long)end, SEEK_SET) != 0) {
        mux_err(m, "seek back to the end failed"); goto done;
    }

    uint64_t first = m->samples[0].dts;
    uint64_t last = m->samples[m->sample_count - 1].dts;
    uint64_t per_frame = m->sample_count > 1
        ? (last - first) / (m->sample_count - 1)
        : m->timescale / 30;
    write_moov(m, last - first + per_frame);

    if (ferror(m->f)) { mux_err(m, "write error while closing the recording"); goto done; }
    rc = 0;

done:
    if (m->f) { fclose(m->f); m->f = NULL; }
    if (rc == 0) {
        free(m->samples);
        free(m->scratch);
        free(m);
    }
    return rc;
}

void mp4_mux_abort(Mp4Mux* m) {
    if (!m) return;
    if (m->f) fclose(m->f);
    free(m->samples);
    free(m->scratch);
    free(m);
}

const char* mp4_mux_error(const Mp4Mux* m) {
    return m ? m->err : "";
}
