// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#include "mp4_demux.h"

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// MP4 is a tree of boxes: 4-byte big-endian size, 4-byte type, payload. The
// tables we need all live under moov/trak/mdia/minf/stbl:
//
//   stsd  sample description  → avcC → SPS/PPS, and the NAL length prefix width
//   stts  time-to-sample      → decode timestamps
//   stss  sync samples        → which samples are keyframes (absent ⇒ all are)
//   stsz  sample sizes
//   stsc  sample-to-chunk     → how samples group into chunks
//   stco  chunk offsets       (co64 for files over 4GB)
//
// Sample byte offsets are not stored directly: stsc + stco together say where
// each chunk starts and how many samples it holds, and sizes accumulate from
// there. That reconstruction is most of this file.

#define BOX_MAX_DEPTH 8

static uint32_t rd32(const uint8_t* p) {
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) |
           ((uint32_t)p[2] << 8) | p[3];
}
static uint64_t rd64(const uint8_t* p) {
    return ((uint64_t)rd32(p) << 32) | rd32(p + 4);
}
static uint16_t rd16(const uint8_t* p) {
    return (uint16_t)((p[0] << 8) | p[1]);
}

// A whole box, read into memory. Recording sample tables are small (a 40s
// capture is ~300 samples); a guard keeps a hostile file from allocating the
// world.
#define BOX_READ_LIMIT (64u * 1024u * 1024u)

static uint8_t* read_at(int fd, uint64_t off, size_t len) {
    if (len == 0 || len > BOX_READ_LIMIT) return NULL;
    uint8_t* buf = malloc(len);
    if (!buf) return NULL;
    if (pread(fd, buf, len, (off_t)off) != (ssize_t)len) {
        free(buf);
        return NULL;
    }
    return buf;
}

/// Find a direct child box of the given type within [start, start+size).
/// Returns 1 and fills payload offset/size.
static int find_box(int fd, uint64_t start, uint64_t size, const char* type,
                    uint64_t* out_off, uint64_t* out_size) {
    uint64_t pos = start;
    uint64_t end = start + size;
    while (pos + 8 <= end) {
        uint8_t hdr[16];
        if (pread(fd, hdr, 8, (off_t)pos) != 8) return 0;
        uint64_t bsize = rd32(hdr);
        uint64_t hlen = 8;
        if (bsize == 1) {                       // 64-bit extended size
            if (pread(fd, hdr + 8, 8, (off_t)(pos + 8)) != 8) return 0;
            bsize = rd64(hdr + 8);
            hlen = 16;
        } else if (bsize == 0) {
            bsize = end - pos;                  // "to end of file"
        }
        if (bsize < hlen || pos + bsize > end) return 0;
        if (memcmp(hdr + 4, type, 4) == 0) {
            *out_off = pos + hlen;
            *out_size = bsize - hlen;
            return 1;
        }
        pos += bsize;
    }
    return 0;
}

/// Walk a slash-separated path of nested boxes, e.g. "moov/trak/mdia".
static int find_path(int fd, uint64_t start, uint64_t size, const char* path,
                     uint64_t* out_off, uint64_t* out_size) {
    char buf[64];
    snprintf(buf, sizeof buf, "%s", path);
    uint64_t off = start, sz = size;
    char* save = NULL;
    for (char* tok = strtok_r(buf, "/", &save); tok; tok = strtok_r(NULL, "/", &save)) {
        if (!find_box(fd, off, sz, tok, &off, &sz)) return 0;
    }
    *out_off = off;
    *out_size = sz;
    return 1;
}

/// avcC (ISO/IEC 14496-15): NAL length width and the parameter sets.
static int parse_avcc(const uint8_t* p, size_t n, Mp4Reader* r) {
    if (n < 7) return -1;
    r->nal_length_size = (uint8_t)((p[4] & 0x03) + 1);
    size_t i = 5;
    uint32_t num_sps = p[i++] & 0x1f;
    for (uint32_t k = 0; k < num_sps; k++) {
        if (i + 2 > n) return -1;
        uint16_t len = rd16(p + i);
        i += 2;
        if (i + len > n) return -1;
        if (k == 0) {                       // first SPS is the one in use
            r->sps = malloc(len);
            if (!r->sps) return -1;
            memcpy(r->sps, p + i, len);
            r->sps_size = len;
        }
        i += len;
    }
    if (i >= n) return -1;
    uint32_t num_pps = p[i++];
    for (uint32_t k = 0; k < num_pps; k++) {
        if (i + 2 > n) return -1;
        uint16_t len = rd16(p + i);
        i += 2;
        if (i + len > n) return -1;
        if (k == 0) {
            r->pps = malloc(len);
            if (!r->pps) return -1;
            memcpy(r->pps, p + i, len);
            r->pps_size = len;
        }
        i += len;
    }
    return (r->sps && r->pps) ? 0 : -1;
}

/// The video trak, by looking for one whose stsd holds an avc1 entry. A
/// recording has exactly one track, but audio tracks are ordinary and must
/// not be mistaken for it.
static int find_video_trak(int fd, uint64_t moov_off, uint64_t moov_size,
                           uint64_t* trak_off, uint64_t* trak_size) {
    uint64_t pos = moov_off, end = moov_off + moov_size;
    while (pos + 8 <= end) {
        uint8_t hdr[8];
        if (pread(fd, hdr, 8, (off_t)pos) != 8) return 0;
        uint64_t bsize = rd32(hdr);
        if (bsize < 8 || pos + bsize > end) return 0;
        if (memcmp(hdr + 4, "trak", 4) == 0) {
            uint64_t so, ss;
            if (find_path(fd, pos + 8, bsize - 8,
                          "mdia/minf/stbl/stsd", &so, &ss)) {
                uint8_t* stsd = read_at(fd, so, (size_t)(ss < 512 ? ss : 512));
                if (stsd) {
                    int is_avc = ss > 16 && memcmp(stsd + 12, "avc1", 4) == 0;
                    free(stsd);
                    if (is_avc) {
                        *trak_off = pos + 8;
                        *trak_size = bsize - 8;
                        return 1;
                    }
                }
            }
        }
        pos += bsize;
    }
    return 0;
}

int mp4_open(const char* path, Mp4Reader* r) {
    memset(r, 0, sizeof *r);
    r->fd = open(path, O_RDONLY | O_CLOEXEC);
    if (r->fd < 0) return -1;

    off_t fsize = lseek(r->fd, 0, SEEK_END);
    if (fsize <= 0) goto fail;

    uint64_t moov_off, moov_size;
    if (!find_box(r->fd, 0, (uint64_t)fsize, "moov", &moov_off, &moov_size)) {
        goto fail;   // no moov: fragmented, streaming, or not an MP4
    }
    // A fragmented file carries its samples in moof boxes the sample table
    // does not describe. Refuse rather than decode the first fragment only.
    uint64_t mvex_off, mvex_size;
    if (find_box(r->fd, moov_off, moov_size, "mvex", &mvex_off, &mvex_size)) {
        goto fail;
    }

    uint64_t trak_off, trak_size;
    if (!find_video_trak(r->fd, moov_off, moov_size, &trak_off, &trak_size)) {
        goto fail;
    }

    // mdhd: timescale and duration for this track.
    uint64_t off, sz;
    if (!find_path(r->fd, trak_off, trak_size, "mdia/mdhd", &off, &sz)) goto fail;
    uint8_t* mdhd = read_at(r->fd, off, (size_t)(sz < 64 ? sz : 64));
    if (!mdhd || sz < 24) { free(mdhd); goto fail; }
    if (mdhd[0] == 1) {                      // version 1: 64-bit times
        if (sz < 36) { free(mdhd); goto fail; }
        r->timescale = rd32(mdhd + 20);
        r->duration = rd64(mdhd + 24);
    } else {
        r->timescale = rd32(mdhd + 12);
        r->duration = rd32(mdhd + 16);
    }
    free(mdhd);
    if (r->timescale == 0) goto fail;

    uint64_t stbl_off, stbl_size;
    if (!find_path(r->fd, trak_off, trak_size, "mdia/minf/stbl",
                   &stbl_off, &stbl_size)) goto fail;

    // stsd → avc1 → avcC. avc1 is a VisualSampleEntry: 8 bytes of box header
    // already stripped, then 6 reserved + 2 data_reference_index + 16 of
    // predefined/reserved, then width/height at +24.
    if (!find_box(r->fd, stbl_off, stbl_size, "stsd", &off, &sz)) goto fail;
    uint64_t avc1_off, avc1_size;
    if (!find_box(r->fd, off + 8, sz - 8, "avc1", &avc1_off, &avc1_size)) goto fail;
    uint8_t dims[32];
    if (pread(r->fd, dims, sizeof dims, (off_t)avc1_off) != (ssize_t)sizeof dims) {
        goto fail;
    }
    r->width = rd16(dims + 24);
    r->height = rd16(dims + 26);

    uint64_t avcc_off, avcc_size;
    if (!find_box(r->fd, avc1_off + 78, avc1_size - 78, "avcC",
                  &avcc_off, &avcc_size)) goto fail;
    uint8_t* avcc = read_at(r->fd, avcc_off, (size_t)avcc_size);
    if (!avcc) goto fail;
    int rc = parse_avcc(avcc, (size_t)avcc_size, r);
    free(avcc);
    if (rc != 0) goto fail;

    // ── sample tables ───────────────────────────────────────────────────
    uint8_t *stts = NULL, *stsz = NULL, *stsc = NULL, *stco = NULL, *stss = NULL;
    uint64_t stts_n = 0, stsz_n = 0, stsc_n = 0, stco_n = 0, stss_n = 0;
    int co64 = 0;

    if (find_box(r->fd, stbl_off, stbl_size, "stts", &off, &sz)) {
        stts = read_at(r->fd, off, (size_t)sz); stts_n = sz;
    }
    if (find_box(r->fd, stbl_off, stbl_size, "stsz", &off, &sz)) {
        stsz = read_at(r->fd, off, (size_t)sz); stsz_n = sz;
    }
    if (find_box(r->fd, stbl_off, stbl_size, "stsc", &off, &sz)) {
        stsc = read_at(r->fd, off, (size_t)sz); stsc_n = sz;
    }
    if (find_box(r->fd, stbl_off, stbl_size, "stco", &off, &sz)) {
        stco = read_at(r->fd, off, (size_t)sz); stco_n = sz;
    } else if (find_box(r->fd, stbl_off, stbl_size, "co64", &off, &sz)) {
        stco = read_at(r->fd, off, (size_t)sz); stco_n = sz; co64 = 1;
    }
    if (find_box(r->fd, stbl_off, stbl_size, "stss", &off, &sz)) {
        stss = read_at(r->fd, off, (size_t)sz); stss_n = sz;
    }
    if (!stts || !stsz || !stsc || !stco) goto fail_tables;
    if (stsz_n < 12 || stsc_n < 8 || stco_n < 8 || stts_n < 8) goto fail_tables;

    uint32_t sample_size_all = rd32(stsz + 4);
    uint32_t count = rd32(stsz + 8);
    if (count == 0 || count > (1u << 24)) goto fail_tables;
    r->samples = calloc(count, sizeof(Mp4Sample));
    if (!r->samples) goto fail_tables;
    r->sample_count = count;

    // sizes
    for (uint32_t i = 0; i < count; i++) {
        if (sample_size_all) {
            r->samples[i].size = sample_size_all;
        } else {
            if (12 + (uint64_t)i * 4 + 4 > stsz_n) goto fail_tables;
            r->samples[i].size = rd32(stsz + 12 + i * 4);
        }
    }

    // decode timestamps from the run-length time-to-sample table
    {
        uint32_t entries = rd32(stts + 4);
        uint32_t i = 0;
        int64_t t = 0;
        for (uint32_t e = 0; e < entries && i < count; e++) {
            if (8 + (uint64_t)e * 8 + 8 > stts_n) goto fail_tables;
            uint32_t n = rd32(stts + 8 + e * 8);
            uint32_t delta = rd32(stts + 8 + e * 8 + 4);
            for (uint32_t k = 0; k < n && i < count; k++, i++) {
                r->samples[i].dts = t;
                t += delta;
            }
        }
        for (; i < count; i++) r->samples[i].dts = t;   // malformed tail
    }

    // offsets: stsc says how many samples each chunk holds, stco says where
    // each chunk starts, sizes accumulate within a chunk.
    {
        uint32_t chunk_count = rd32(stco + 4);
        uint32_t stsc_entries = rd32(stsc + 4);
        uint32_t sample = 0;
        for (uint32_t c = 0; c < chunk_count && sample < count; c++) {
            // samples-per-chunk for this chunk = the last stsc entry whose
            // first_chunk is <= c+1
            uint32_t per = 0;
            for (uint32_t e = 0; e < stsc_entries; e++) {
                if (8 + (uint64_t)e * 12 + 12 > stsc_n) goto fail_tables;
                uint32_t first = rd32(stsc + 8 + e * 12);
                if (first <= c + 1) per = rd32(stsc + 8 + e * 12 + 4);
                else break;
            }
            if (per == 0) goto fail_tables;

            uint64_t base;
            if (co64) {
                if (8 + (uint64_t)c * 8 + 8 > stco_n) goto fail_tables;
                base = rd64(stco + 8 + c * 8);
            } else {
                if (8 + (uint64_t)c * 4 + 4 > stco_n) goto fail_tables;
                base = rd32(stco + 8 + c * 4);
            }
            for (uint32_t k = 0; k < per && sample < count; k++, sample++) {
                r->samples[sample].offset = base;
                base += r->samples[sample].size;
            }
        }
        if (sample < count) goto fail_tables;
    }

    // keyframes: stss lists them, and its absence means every sample is one
    if (stss) {
        uint32_t n = rd32(stss + 4);
        for (uint32_t i = 0; i < n; i++) {
            if (8 + (uint64_t)i * 4 + 4 > stss_n) goto fail_tables;
            uint32_t s = rd32(stss + 8 + i * 4);
            if (s >= 1 && s <= count) r->samples[s - 1].keyframe = 1;
        }
    } else {
        for (uint32_t i = 0; i < count; i++) r->samples[i].keyframe = 1;
    }

    free(stts); free(stsz); free(stsc); free(stco); free(stss);
    return 0;

fail_tables:
    free(stts); free(stsz); free(stsc); free(stco); free(stss);
fail:
    mp4_close(r);
    return -1;
}

int mp4_read_sample(Mp4Reader* r, uint32_t index, uint8_t* buf) {
    if (index >= r->sample_count) return -1;
    const Mp4Sample* s = &r->samples[index];
    if (pread(r->fd, buf, s->size, (off_t)s->offset) != (ssize_t)s->size) {
        return -1;
    }
    return 0;
}

double mp4_sample_time(const Mp4Reader* r, uint32_t index) {
    if (index >= r->sample_count || r->timescale == 0) return 0;
    return (double)r->samples[index].dts / (double)r->timescale;
}

uint32_t mp4_seek_keyframe(const Mp4Reader* r, double seconds) {
    if (r->sample_count == 0) return 0;
    int64_t target = (int64_t)(seconds * (double)r->timescale);
    uint32_t best = 0;
    for (uint32_t i = 0; i < r->sample_count; i++) {
        if (!r->samples[i].keyframe) continue;
        if (r->samples[i].dts <= target) best = i;
        else break;
    }
    return best;
}

void mp4_close(Mp4Reader* r) {
    if (!r) return;
    if (r->fd >= 0) close(r->fd);
    r->fd = -1;
    free(r->sps); r->sps = NULL;
    free(r->pps); r->pps = NULL;
    free(r->samples); r->samples = NULL;
    r->sample_count = 0;
}
