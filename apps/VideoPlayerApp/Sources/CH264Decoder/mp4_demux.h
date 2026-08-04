// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#ifndef STARLING_MP4_DEMUX_H
#define STARLING_MP4_DEMUX_H

#include <stddef.h>
#include <stdint.h>

// Just enough MP4 to walk our own recordings: one H.264 video track, sample
// table read up front, samples read on demand. Progressive files only —
// fragmented MP4 (moof/mfra) is refused, since the recorder does not make it.

typedef struct {
    uint64_t offset;    // byte offset in the file
    uint32_t size;
    int64_t dts;        // in track timescale units
    int keyframe;
} Mp4Sample;

typedef struct {
    int fd;
    uint32_t timescale;         // ticks per second, track media timescale
    uint64_t duration;          // in timescale units
    int width, height;          // from the sample description
    uint8_t nal_length_size;    // 1, 2 or 4 — avcC length prefix width

    uint8_t* sps;               // raw NAL, no start code
    size_t sps_size;
    uint8_t* pps;
    size_t pps_size;

    Mp4Sample* samples;
    uint32_t sample_count;
} Mp4Reader;

/// Open and index. 0 on success. Refuses anything that is not a progressive
/// MP4 with a single avc1 video track.
int mp4_open(const char* path, Mp4Reader* r);

/// Read one sample's bytes into `buf` (must be at least sample size).
int mp4_read_sample(Mp4Reader* r, uint32_t index, uint8_t* buf);

/// Index of the last keyframe at or before `seconds`.
uint32_t mp4_seek_keyframe(const Mp4Reader* r, double seconds);

double mp4_sample_time(const Mp4Reader* r, uint32_t index);

void mp4_close(Mp4Reader* r);

#endif  // STARLING_MP4_DEMUX_H
