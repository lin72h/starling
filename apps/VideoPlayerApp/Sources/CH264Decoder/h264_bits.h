// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#ifndef STARLING_H264_BITS_H
#define STARLING_H264_BITS_H

#include <stddef.h>
#include <stdint.h>

// Slice types, after the %5 fold (5..9 are "all slices in the picture are").
#define H264_SLICE_P  0
#define H264_SLICE_B  1
#define H264_SLICE_I  2
#define H264_SLICE_SP 3
#define H264_SLICE_SI 4

typedef struct {
    const uint8_t* data;
    size_t size;
    size_t byte;
    int bit;
    int zeros;      // consecutive 0x00 bytes, for emulation-prevention
    int overrun;    // read past the end — every parse checks this
    size_t skipped; // emulation-prevention bytes stepped over
} H264Bits;

void h264_bits_init(H264Bits* b, const uint8_t* data, size_t size);
uint32_t h264_u(H264Bits* b, int n);
uint32_t h264_ue(H264Bits* b);
int32_t h264_se(H264Bits* b);
size_t h264_bits_consumed_in_nal(const H264Bits* b);

typedef struct {
    uint32_t profile_idc, level_idc, sps_id;
    uint32_t chroma_format_idc;
    uint32_t separate_colour_plane_flag;
    uint32_t bit_depth_luma_minus8, bit_depth_chroma_minus8;
    uint32_t qpprime_y_zero_transform_bypass_flag;
    uint32_t seq_scaling_matrix_present_flag;
    uint32_t log2_max_frame_num_minus4;
    uint32_t pic_order_cnt_type;
    uint32_t log2_max_pic_order_cnt_lsb_minus4;
    uint32_t delta_pic_order_always_zero_flag;
    uint32_t max_num_ref_frames;
    uint32_t gaps_in_frame_num_value_allowed_flag;
    uint32_t pic_width_in_mbs_minus1;
    uint32_t pic_height_in_map_units_minus1;
    uint32_t frame_mbs_only_flag;
    uint32_t mb_adaptive_frame_field_flag;
    uint32_t direct_8x8_inference_flag;
    uint32_t frame_cropping_flag;
    uint32_t crop_left, crop_right, crop_top, crop_bottom;
    int width, height;   // visible, after cropping
} H264Sps;

typedef struct {
    uint32_t pps_id, sps_id;
    uint32_t entropy_coding_mode_flag;
    uint32_t bottom_field_pic_order_in_frame_present_flag;
    uint32_t num_slice_groups_minus1;
    uint32_t num_ref_idx_l0_default_active_minus1;
    uint32_t num_ref_idx_l1_default_active_minus1;
    uint32_t weighted_pred_flag;
    uint32_t weighted_bipred_idc;
    int32_t pic_init_qp_minus26, pic_init_qs_minus26;
    int32_t chroma_qp_index_offset, second_chroma_qp_index_offset;
    uint32_t deblocking_filter_control_present_flag;
    uint32_t constrained_intra_pred_flag;
    uint32_t redundant_pic_cnt_present_flag;
    uint32_t transform_8x8_mode_flag;
    uint32_t pic_scaling_matrix_present_flag;
} H264Pps;

typedef struct {
    uint32_t nal_ref_idc, nal_unit_type;
    int is_idr;
    uint32_t first_mb_in_slice;
    uint32_t slice_type;
    uint32_t pps_id;
    uint32_t frame_num;
    uint32_t field_pic_flag, bottom_field_flag;
    uint32_t idr_pic_id;
    uint32_t pic_order_cnt_lsb;
    uint32_t num_ref_idx_l0_active_minus1;
    uint32_t cabac_init_idc;
    int32_t slice_qp_delta;
    uint32_t disable_deblocking_filter_idc;
    int32_t slice_alpha_c0_offset_div2, slice_beta_offset_div2;
    uint32_t long_term_reference_flag;
    int has_list_modification, has_pred_weights, has_mmco;
    uint32_t slice_data_bit_offset;
    /// Why the header was refused, or NULL. Diagnostics only — the caller
    /// just falls back, but knowing which assumption broke is the difference
    /// between fixing it and guessing.
    const char* reject;
} H264SliceHeader;

int h264_parse_sps(const uint8_t* nal, size_t size, H264Sps* s);
int h264_parse_pps(const uint8_t* nal, size_t size, const H264Sps* sps,
                   H264Pps* p);
int h264_parse_slice_header(const uint8_t* nal, size_t size,
                            const H264Sps* sps, const H264Pps* pps,
                            H264SliceHeader* sh);

#endif  // STARLING_H264_BITS_H
