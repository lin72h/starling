// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// See h264_headers.h. Field order and conditionals follow ITU-T H.264
// §7.3.2.1.1 (SPS), §7.3.2.2 (PPS) and §7.3.3 (slice header). Anything the
// configuration fixes is written as its constant rather than plumbed through,
// with the constant named in a comment — a parameter that can only take one
// value is a place for a bug to hide.

#include "h264_headers.h"

#include "h264_bitwriter.h"

#define NAL_SLICE      1
#define NAL_IDR_SLICE  5
#define NAL_SPS        7
#define NAL_PPS        8

void h264_config_init(H264Config* cfg, int width, int height, int fps) {
    cfg->width = width;
    cfg->height = height;
    cfg->mb_width = (width + 15) / 16;
    cfg->mb_height = (height + 15) / 16;
    cfg->fps = fps > 0 ? fps : 30;
    cfg->pic_init_qp = H264_PIC_INIT_QP;
    cfg->log2_max_frame_num_minus4 = 4;
    cfg->log2_max_poc_lsb_minus4 = 4;

    // Level by macroblock count and rate, from Table A-1. Only the rungs a
    // desktop recording can reach are listed; anything bigger takes 5.2, the
    // highest level defined for the profile, rather than a made-up number.
    int mbs = cfg->mb_width * cfg->mb_height;
    int mbs_per_sec = mbs * cfg->fps;
    if (mbs <= 1620 && mbs_per_sec <= 40500) cfg->level_idc = 31;       // 720x576@25
    else if (mbs <= 3600 && mbs_per_sec <= 108000) cfg->level_idc = 32; // 1280x720@30
    else if (mbs <= 8192 && mbs_per_sec <= 245760) cfg->level_idc = 41; // 1920x1080@30
    else if (mbs <= 22080 && mbs_per_sec <= 522240) cfg->level_idc = 50; // 2560x1600@30
    else if (mbs <= 36864 && mbs_per_sec <= 589824) cfg->level_idc = 51; // 4096x2160@30
    else cfg->level_idc = 52;
}

size_t h264_write_sps(const H264Config* cfg, int flags, uint8_t* out, size_t cap) {
    H264BitWriter w;
    h264_bw_init(&w);

    h264_bw_u(&w, 8, 77);                  // profile_idc — Main
    h264_bw_u(&w, 1, 0);                   // constraint_set0_flag
    h264_bw_u(&w, 1, 1);                   // constraint_set1_flag — is Main
    h264_bw_u(&w, 1, 0);                   // constraint_set2_flag
    h264_bw_u(&w, 1, 0);                   // constraint_set3_flag
    h264_bw_u(&w, 1, 0);                   // constraint_set4_flag
    h264_bw_u(&w, 1, 0);                   // constraint_set5_flag
    h264_bw_u(&w, 2, 0);                   // reserved_zero_2bits
    h264_bw_u(&w, 8, (uint32_t)cfg->level_idc);
    h264_bw_ue(&w, 0);                     // seq_parameter_set_id
    // Main profile: no chroma_format_idc / bit-depth / scaling-list block.
    h264_bw_ue(&w, (uint32_t)cfg->log2_max_frame_num_minus4);
    h264_bw_ue(&w, 0);                     // pic_order_cnt_type
    h264_bw_ue(&w, (uint32_t)cfg->log2_max_poc_lsb_minus4);
    h264_bw_ue(&w, 1);                     // max_num_ref_frames
    h264_bw_u(&w, 1, 0);                   // gaps_in_frame_num_value_allowed_flag
    h264_bw_ue(&w, (uint32_t)(cfg->mb_width - 1));
    h264_bw_ue(&w, (uint32_t)(cfg->mb_height - 1));
    h264_bw_u(&w, 1, 1);                   // frame_mbs_only_flag
    h264_bw_u(&w, 1, 1);                   // direct_8x8_inference_flag

    // Crop the macroblock padding away. Units are 2 luma samples horizontally
    // and, with frame_mbs_only_flag=1, 1 sample vertically (§7.4.2.1.1).
    int crop_right = (cfg->mb_width * 16 - cfg->width) / 2;
    int crop_bottom = (cfg->mb_height * 16 - cfg->height) / 2;
    int cropping = (crop_right | crop_bottom) != 0;
    h264_bw_u(&w, 1, (uint32_t)cropping);
    if (cropping) {
        h264_bw_ue(&w, 0);                 // crop_left
        h264_bw_ue(&w, (uint32_t)crop_right);
        h264_bw_ue(&w, 0);                 // crop_top
        h264_bw_ue(&w, (uint32_t)crop_bottom);
    }

    // VUI, for the frame rate. Without it players fall back to the container's
    // timing, which is right here, but a raw .h264 dump would have none at all
    // and the timing_info also pins the aspect ratio as square.
    h264_bw_u(&w, 1, 1);                   // vui_parameters_present_flag
    h264_bw_u(&w, 1, 0);                   // aspect_ratio_info_present_flag
    h264_bw_u(&w, 1, 0);                   // overscan_info_present_flag

    // Colour, stated rather than left to the player to guess. The desktop is
    // full-range sRGB and the VPP converts it to limited-range BT.709, so
    // that is what this must say. Getting it wrong is not subtle once you
    // look for it: a player that assumes limited range on full-range samples
    // applies (v-16)*255/219 and the recording comes back visibly
    // over-contrasted, blacks crushed and highlights clipped. Measured
    // exactly that way while bringing this up — the "encoder is lossy"
    // numbers turned out to fit the range-expansion formula to the integer.
    // The libav path this replaces signalled nothing at all, so players were
    // guessing (correctly, as it happens, since the guess for HD is
    // BT.709 limited).
    h264_bw_u(&w, 1, 1);                   // video_signal_type_present_flag
    h264_bw_u(&w, 3, 5);                   //   video_format = unspecified
    h264_bw_u(&w, 1, 0);                   //   video_full_range_flag = limited
    h264_bw_u(&w, 1, 1);                   //   colour_description_present_flag
    h264_bw_u(&w, 8, 1);                   //     colour_primaries = BT.709
    h264_bw_u(&w, 8, 1);                   //     transfer_characteristics = BT.709
    h264_bw_u(&w, 8, 1);                   //     matrix_coefficients = BT.709

    h264_bw_u(&w, 1, 0);                   // chroma_loc_info_present_flag
    h264_bw_u(&w, 1, 1);                   // timing_info_present_flag
    h264_bw_u(&w, 32, 1);                  // num_units_in_tick
    h264_bw_u(&w, 32, (uint32_t)(cfg->fps * 2));  // time_scale (field rate)
    // NOT fixed: a screen capture is genuinely variable-rate. The engine's
    // pacer works to an absolute schedule, so a present missed to client
    // jitter is repaid by the next one and two frames can arrive within a
    // third of the nominal interval. Claiming CFR here makes players and
    // remuxers adopt a 1/fps timebase and then reject the real sample times
    // as non-monotonic, because two of them round into one slot.
    h264_bw_u(&w, 1, 0);                   // fixed_frame_rate_flag
    h264_bw_u(&w, 1, 0);                   // nal_hrd_parameters_present_flag
    h264_bw_u(&w, 1, 0);                   // vcl_hrd_parameters_present_flag
    h264_bw_u(&w, 1, 0);                   // pic_struct_present_flag
    h264_bw_u(&w, 1, 0);                   // bitstream_restriction_flag

    h264_bw_trailing(&w);
    return h264_bw_emit_nal(&w, 3, NAL_SPS, flags, out, cap);
}

size_t h264_write_pps(const H264Config* cfg, int flags, uint8_t* out, size_t cap) {
    H264BitWriter w;
    h264_bw_init(&w);

    h264_bw_ue(&w, 0);                     // pic_parameter_set_id
    h264_bw_ue(&w, 0);                     // seq_parameter_set_id
    h264_bw_u(&w, 1, 1);                   // entropy_coding_mode_flag — CABAC
    h264_bw_u(&w, 1, 0);                   // bottom_field_pic_order_in_frame_present
    h264_bw_ue(&w, 0);                     // num_slice_groups_minus1
    h264_bw_ue(&w, 0);                     // num_ref_idx_l0_default_active_minus1
    h264_bw_ue(&w, 0);                     // num_ref_idx_l1_default_active_minus1
    h264_bw_u(&w, 1, 0);                   // weighted_pred_flag
    h264_bw_u(&w, 2, 0);                   // weighted_bipred_idc
    h264_bw_se(&w, cfg->pic_init_qp - 26);  // pic_init_qp_minus26 — always 0
    h264_bw_se(&w, 0);                     // pic_init_qs_minus26
    h264_bw_se(&w, 0);                     // chroma_qp_index_offset
    h264_bw_u(&w, 1, 1);                   // deblocking_filter_control_present
    h264_bw_u(&w, 1, 0);                   // constrained_intra_pred_flag
    h264_bw_u(&w, 1, 0);                   // redundant_pic_cnt_present_flag
    // Main profile with no 8x8 transform: the optional trailing
    // transform_8x8_mode_flag block is omitted entirely.

    h264_bw_trailing(&w);
    return h264_bw_emit_nal(&w, 3, NAL_PPS, flags, out, cap);
}

size_t h264_write_slice_header(const H264Config* cfg, int is_idr,
                               uint32_t frame_num, uint32_t idr_pic_id,
                               uint32_t poc_lsb, int slice_qp_delta,
                               uint8_t* out, size_t cap,
                               unsigned int* bit_length) {
    H264BitWriter w;
    h264_bw_init(&w);

    // slice_type 7 = "I, and every slice in this picture is I"; 5 likewise for
    // P. The +5 forms are what single-slice encoders emit, and they let a
    // decoder know the picture needs no further slices.
    h264_bw_ue(&w, 0);                     // first_mb_in_slice
    h264_bw_ue(&w, is_idr ? 7u : 5u);      // slice_type
    h264_bw_ue(&w, 0);                     // pic_parameter_set_id
    h264_bw_u(&w, cfg->log2_max_frame_num_minus4 + 4, frame_num);
    // frame_mbs_only_flag=1, so no field_pic_flag.
    if (is_idr) h264_bw_ue(&w, idr_pic_id);
    // pic_order_cnt_type=0, bottom_field_pic_order..=0.
    h264_bw_u(&w, cfg->log2_max_poc_lsb_minus4 + 4, poc_lsb);

    if (!is_idr) {
        // P slice: ref_pic_list_modification. One reference, in default
        // order, so nothing to modify.
        h264_bw_u(&w, 1, 0);               // num_ref_idx_active_override_flag
        h264_bw_u(&w, 1, 0);               // ref_pic_list_modification_flag_l0
    }

    // Every picture we emit is a reference (nal_ref_idc != 0), so
    // dec_ref_pic_marking is always present.
    if (is_idr) {
        h264_bw_u(&w, 1, 0);               // no_output_of_prior_pics_flag
        h264_bw_u(&w, 1, 0);               // long_term_reference_flag
    } else {
        h264_bw_u(&w, 1, 0);               // adaptive_ref_pic_marking_mode_flag
    }

    // CABAC, and cabac_init_idc exists for P/B slices only.
    if (!is_idr) h264_bw_ue(&w, 0);        // cabac_init_idc

    h264_bw_se(&w, slice_qp_delta);
    // deblocking_filter_control_present_flag=1 in the PPS:
    h264_bw_ue(&w, 0);                     // disable_deblocking_filter_idc — on
    h264_bw_se(&w, 0);                     // slice_alpha_c0_offset_div2
    h264_bw_se(&w, 0);                     // slice_beta_offset_div2

    // NO rbsp_trailing_bits: the hardware writes the slice data on from here,
    // continuing inside the final partial byte.
    // The reported length covers the start code and NAL header byte too —
    // bit_length is the size of the buffer VA-API is handed, not of the RBSP.
    if (bit_length) {
        *bit_length = (unsigned int)(5 * 8 + h264_bw_bit_length(&w));
    }
    return h264_bw_emit_nal(&w, 3, is_idr ? NAL_IDR_SLICE : NAL_SLICE,
                            H264_NAL_START_CODE, out, cap);
}
