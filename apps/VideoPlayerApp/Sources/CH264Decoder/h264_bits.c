// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// RBSP bit reader plus the SPS / PPS / slice-header parsing the VA-API decode
// buffers need. Nothing here decodes picture data — the hardware does that.
// What it must produce is exact: every field feeds a VA buffer, and a wrong
// one shows up as corrupt output rather than an error.

#include "h264_bits.h"

#include <string.h>

// ─── bit reader ─────────────────────────────────────────────────────────────
//
// Reads over the RBSP, i.e. with emulation-prevention bytes removed. H.264
// escapes any 00 00 00/01/02/03 in the payload as 00 00 03 xx; the 03 is not
// part of the syntax and must be skipped, but it DOES occupy space in the
// bytes handed to the hardware. Hence `bits_consumed_in_nal`, which reports a
// position in the original NAL — VA-API's slice_data_bit_offset is defined
// against the escaped bitstream.

void h264_bits_init(H264Bits* b, const uint8_t* data, size_t size) {
    b->data = data;
    b->size = size;
    b->byte = 0;
    b->bit = 0;
    b->zeros = 0;
    b->overrun = 0;
    b->skipped = 0;
}

static int bits_at_end(const H264Bits* b) { return b->byte >= b->size; }

uint32_t h264_u(H264Bits* b, int n) {
    uint32_t v = 0;
    for (int i = 0; i < n; i++) {
        if (bits_at_end(b)) { b->overrun = 1; return v; }
        uint8_t cur = b->data[b->byte];
        v = (v << 1) | ((cur >> (7 - b->bit)) & 1);
        if (++b->bit == 8) {
            b->bit = 0;
            // Track the 00 00 03 pattern so the next byte's 03 is skipped.
            if (cur == 0) {
                b->zeros++;
            } else {
                b->zeros = 0;
            }
            b->byte++;
            if (b->zeros >= 2 && b->byte < b->size && b->data[b->byte] == 3) {
                b->byte++;      // emulation prevention byte
                b->skipped++;
                b->zeros = 0;
            }
        }
    }
    return v;
}

uint32_t h264_ue(H264Bits* b) {
    int lead = 0;
    while (!bits_at_end(b) && h264_u(b, 1) == 0 && lead < 32) lead++;
    if (lead == 0) return 0;
    if (lead >= 32) { b->overrun = 1; return 0; }
    return (1u << lead) - 1 + h264_u(b, lead);
}

int32_t h264_se(H264Bits* b) {
    uint32_t k = h264_ue(b);
    if (k == 0) return 0;
    int32_t mag = (int32_t)((k + 1) / 2);
    return (k & 1) ? mag : -mag;
}

size_t h264_bits_consumed_in_nal(const H264Bits* b) {
    // RBSP bits, i.e. NOT counting the emulation-prevention bytes stepped
    // over. va.h is explicit: slice_data_bit_offset is "the number of bits
    // parsed in the slice_header() after the removal of any emulation
    // prevention bytes", even though the buffer handed to the hardware still
    // contains them. Counting the escaped position instead puts the offset
    // past the start of slice_data() on exactly those frames that happen to
    // contain a 00 00 03 in their header — rare, so it would decode fine
    // until it suddenly did not.
    return ((b->byte - b->skipped) * 8) + b->bit;
}

// ─── scaling lists ──────────────────────────────────────────────────────────
// Parsed only to step over them correctly. The recorder never enables them,
// and a stream that does is refused rather than decoded with defaults.

static void skip_scaling_list(H264Bits* b, int size) {
    int last = 8, next = 8;
    for (int i = 0; i < size; i++) {
        if (next != 0) {
            int32_t delta = h264_se(b);
            next = (last + delta + 256) % 256;
        }
        last = (next == 0) ? last : next;
    }
}

// ─── SPS ────────────────────────────────────────────────────────────────────

int h264_parse_sps(const uint8_t* nal, size_t size, H264Sps* s) {
    if (size < 4) return -1;
    memset(s, 0, sizeof *s);

    H264Bits b;
    // Skip the 1-byte NAL header; the reader works over the payload.
    h264_bits_init(&b, nal + 1, size - 1);

    s->profile_idc = h264_u(&b, 8);
    h264_u(&b, 8);                 // constraint flags + reserved
    s->level_idc = h264_u(&b, 8);
    s->sps_id = h264_ue(&b);
    if (s->sps_id > 31) return -1;

    s->chroma_format_idc = 1;      // 4:2:0 unless said otherwise
    if (s->profile_idc == 100 || s->profile_idc == 110 ||
        s->profile_idc == 122 || s->profile_idc == 244 ||
        s->profile_idc == 44  || s->profile_idc == 83  ||
        s->profile_idc == 86  || s->profile_idc == 118 ||
        s->profile_idc == 128 || s->profile_idc == 138 ||
        s->profile_idc == 139 || s->profile_idc == 134) {
        s->chroma_format_idc = h264_ue(&b);
        if (s->chroma_format_idc == 3) s->separate_colour_plane_flag = h264_u(&b, 1);
        s->bit_depth_luma_minus8 = h264_ue(&b);
        s->bit_depth_chroma_minus8 = h264_ue(&b);
        s->qpprime_y_zero_transform_bypass_flag = h264_u(&b, 1);
        s->seq_scaling_matrix_present_flag = h264_u(&b, 1);
        if (s->seq_scaling_matrix_present_flag) {
            int lists = (s->chroma_format_idc != 3) ? 8 : 12;
            for (int i = 0; i < lists; i++) {
                if (h264_u(&b, 1)) skip_scaling_list(&b, i < 6 ? 16 : 64);
            }
        }
    }

    s->log2_max_frame_num_minus4 = h264_ue(&b);
    s->pic_order_cnt_type = h264_ue(&b);
    if (s->pic_order_cnt_type == 0) {
        s->log2_max_pic_order_cnt_lsb_minus4 = h264_ue(&b);
    } else if (s->pic_order_cnt_type == 1) {
        s->delta_pic_order_always_zero_flag = h264_u(&b, 1);
        h264_se(&b);                                  // offset_for_non_ref_pic
        h264_se(&b);                                  // offset_for_top_to_bottom_field
        uint32_t n = h264_ue(&b);
        if (n > 255) return -1;
        for (uint32_t i = 0; i < n; i++) h264_se(&b);
    }

    s->max_num_ref_frames = h264_ue(&b);
    s->gaps_in_frame_num_value_allowed_flag = h264_u(&b, 1);
    s->pic_width_in_mbs_minus1 = h264_ue(&b);
    s->pic_height_in_map_units_minus1 = h264_ue(&b);
    s->frame_mbs_only_flag = h264_u(&b, 1);
    if (!s->frame_mbs_only_flag) s->mb_adaptive_frame_field_flag = h264_u(&b, 1);
    s->direct_8x8_inference_flag = h264_u(&b, 1);

    s->frame_cropping_flag = h264_u(&b, 1);
    if (s->frame_cropping_flag) {
        s->crop_left = h264_ue(&b);
        s->crop_right = h264_ue(&b);
        s->crop_top = h264_ue(&b);
        s->crop_bottom = h264_ue(&b);
    }
    // VUI is not read: nothing in it feeds a VA buffer, and the container
    // already told us the frame rate.

    if (b.overrun) return -1;

    // Visible size. Cropping units depend on chroma format and field coding
    // (7-18..7-21); 4:2:0 frame coding is 2 horizontal, 2 vertical.
    int cw = (s->chroma_format_idc == 1) ? 2 : (s->chroma_format_idc == 2 ? 2 : 1);
    int ch = ((s->chroma_format_idc == 1) ? 2 : 1) * (2 - s->frame_mbs_only_flag);
    s->width = (int)(s->pic_width_in_mbs_minus1 + 1) * 16
               - (int)(s->crop_left + s->crop_right) * cw;
    s->height = (int)(s->pic_height_in_map_units_minus1 + 1) * 16
                    * (2 - s->frame_mbs_only_flag)
                - (int)(s->crop_top + s->crop_bottom) * ch;
    return 0;
}

// Whether any syntax remains before the rbsp_stop_one_bit. The trailing bits
// are a single 1 followed by zero padding, so the stop bit is the LAST set bit
// in the payload; anything at or past it is padding, not data. Testing "are
// there bytes left" instead reads the padding as syntax — which is how the
// optional PPS extension appeared to be present in a PPS that has none.
static int more_rbsp_data(const H264Bits* b) {
    size_t last = b->size;
    while (last > 0 && b->data[last - 1] == 0) last--;
    if (last == 0) return 0;
    uint8_t v = b->data[last - 1];
    int lowest = 0;
    while (((v >> lowest) & 1) == 0) lowest++;
    size_t stop_bit = (last - 1) * 8 + (size_t)(7 - lowest);
    return (b->byte * 8 + (size_t)b->bit) < stop_bit;
}

// ─── PPS ────────────────────────────────────────────────────────────────────

int h264_parse_pps(const uint8_t* nal, size_t size, const H264Sps* sps,
                   H264Pps* p) {
    if (size < 2) return -1;
    memset(p, 0, sizeof *p);

    H264Bits b;
    h264_bits_init(&b, nal + 1, size - 1);

    p->pps_id = h264_ue(&b);
    p->sps_id = h264_ue(&b);
    if (p->pps_id > 255 || p->sps_id > 31) return -1;
    p->entropy_coding_mode_flag = h264_u(&b, 1);
    p->bottom_field_pic_order_in_frame_present_flag = h264_u(&b, 1);
    p->num_slice_groups_minus1 = h264_ue(&b);
    if (p->num_slice_groups_minus1 > 0) return -1;   // FMO: refused, not parsed

    p->num_ref_idx_l0_default_active_minus1 = h264_ue(&b);
    p->num_ref_idx_l1_default_active_minus1 = h264_ue(&b);
    p->weighted_pred_flag = h264_u(&b, 1);
    p->weighted_bipred_idc = h264_u(&b, 2);
    p->pic_init_qp_minus26 = h264_se(&b);
    p->pic_init_qs_minus26 = h264_se(&b);
    p->chroma_qp_index_offset = h264_se(&b);
    p->deblocking_filter_control_present_flag = h264_u(&b, 1);
    p->constrained_intra_pred_flag = h264_u(&b, 1);
    p->redundant_pic_cnt_present_flag = h264_u(&b, 1);

    // The trailing extension is optional; its absence is signalled by running
    // out of RBSP, so peek rather than assume.
    p->second_chroma_qp_index_offset = p->chroma_qp_index_offset;
    if (more_rbsp_data(&b)) {
        p->transform_8x8_mode_flag = h264_u(&b, 1);
        if (h264_u(&b, 1)) {   // pic_scaling_matrix_present_flag
            int lists = 6 + (p->transform_8x8_mode_flag
                                 ? ((sps && sps->chroma_format_idc != 3) ? 2 : 6)
                                 : 0);
            for (int i = 0; i < lists; i++) {
                if (h264_u(&b, 1)) skip_scaling_list(&b, i < 6 ? 16 : 64);
            }
            p->pic_scaling_matrix_present_flag = 1;
        }
        p->second_chroma_qp_index_offset = h264_se(&b);
    }
    if (b.overrun) return -1;
    return 0;
}

// ─── slice header ───────────────────────────────────────────────────────────

int h264_parse_slice_header(const uint8_t* nal, size_t size,
                            const H264Sps* sps, const H264Pps* pps,
                            H264SliceHeader* sh) {
    if (size < 2) return -1;
    memset(sh, 0, sizeof *sh);
    sh->reject = NULL;

    sh->nal_ref_idc = (nal[0] >> 5) & 0x3;
    sh->nal_unit_type = nal[0] & 0x1f;
    sh->is_idr = (sh->nal_unit_type == 5);

    H264Bits b;
    h264_bits_init(&b, nal + 1, size - 1);

    sh->first_mb_in_slice = h264_ue(&b);
    uint32_t st = h264_ue(&b);
    if (st > 9) { sh->reject = "slice_type out of range"; return -1; }
    sh->slice_type = st % 5;          // 5..9 mean "all slices of this type"
    sh->pps_id = h264_ue(&b);

    if (sps->separate_colour_plane_flag) h264_u(&b, 2);
    sh->frame_num = h264_u(&b, (int)sps->log2_max_frame_num_minus4 + 4);

    if (!sps->frame_mbs_only_flag) {
        sh->field_pic_flag = h264_u(&b, 1);
        if (sh->field_pic_flag) sh->bottom_field_flag = h264_u(&b, 1);
    }
    if (sh->is_idr) sh->idr_pic_id = h264_ue(&b);

    if (sps->pic_order_cnt_type == 0) {
        sh->pic_order_cnt_lsb =
            h264_u(&b, (int)sps->log2_max_pic_order_cnt_lsb_minus4 + 4);
        if (pps->bottom_field_pic_order_in_frame_present_flag && !sh->field_pic_flag) {
            h264_se(&b);              // delta_pic_order_cnt_bottom
        }
    } else if (sps->pic_order_cnt_type == 1 && !sps->delta_pic_order_always_zero_flag) {
        h264_se(&b);
        if (pps->bottom_field_pic_order_in_frame_present_flag && !sh->field_pic_flag) {
            h264_se(&b);
        }
    }
    if (pps->redundant_pic_cnt_present_flag) h264_ue(&b);

    // B slices would need direct_spatial_mv_pred_flag here — and a second
    // reference list, and reordering. Refused upstream; assert it.
    if (sh->slice_type == H264_SLICE_B) { sh->reject = "B slice"; return -1; }

    sh->num_ref_idx_l0_active_minus1 = pps->num_ref_idx_l0_default_active_minus1;
    if (sh->slice_type == H264_SLICE_P || sh->slice_type == H264_SLICE_SP) {
        if (h264_u(&b, 1)) {          // num_ref_idx_active_override_flag
            sh->num_ref_idx_l0_active_minus1 = h264_ue(&b);
        }
    }

    // ref_pic_list_modification: present for P, and any modification means a
    // reference order we do not model.
    if (sh->slice_type != H264_SLICE_I && sh->slice_type != H264_SLICE_SI) {
        if (h264_u(&b, 1)) {          // ref_pic_list_modification_flag_l0
            for (;;) {
                uint32_t op = h264_ue(&b);
                if (op == 3 || b.overrun) break;
                h264_ue(&b);
                sh->has_list_modification = 1;
            }
        }
    }

    if ((pps->weighted_pred_flag &&
         (sh->slice_type == H264_SLICE_P || sh->slice_type == H264_SLICE_SP))) {
        sh->has_pred_weights = 1;
        sh->reject = "weighted prediction";
        return -1;
    }

    if (sh->nal_ref_idc != 0) {
        if (sh->is_idr) {
            h264_u(&b, 1);            // no_output_of_prior_pics_flag
            sh->long_term_reference_flag = h264_u(&b, 1);
        } else {
            if (h264_u(&b, 1)) {      // adaptive_ref_pic_marking_mode_flag
                // Stepped over, not executed. The AMD encoder marks its one
                // reference explicitly rather than leaning on the sliding
                // window, so refusing here would refuse every P frame we
                // produce. Not executing them is sound only because the DPB
                // is one picture deep and pic_order_cnt_type is 2 (output
                // order == decode order): ops 1 and 5 retire pictures we were
                // going to drop anyway, and the reference stays "the frame
                // before this one". Long-term references are a different
                // model and ARE refused.
                sh->has_mmco = 1;
                for (;;) {
                    uint32_t op = h264_ue(&b);
                    if (b.overrun) break;
                    if (op == 0) break;
                    if (op == 1 || op == 3) h264_ue(&b);  // difference_of_pic_nums_minus1
                    if (op == 2) h264_ue(&b);             // long_term_pic_num
                    if (op == 3 || op == 6) h264_ue(&b);  // long_term_frame_idx
                    if (op == 4) h264_ue(&b);             // max_long_term_frame_idx_plus1
                    if (op == 2 || op == 3 || op == 4 || op == 6) {
                        sh->reject = "long-term reference";
                        return -1;
                    }
                    if (op > 6) { sh->reject = "unknown MMCO op"; return -1; }
                }
            }
        }
    }

    if (pps->entropy_coding_mode_flag &&
        sh->slice_type != H264_SLICE_I && sh->slice_type != H264_SLICE_SI) {
        sh->cabac_init_idc = h264_ue(&b);
    }
    sh->slice_qp_delta = h264_se(&b);

    if (sh->slice_type == H264_SLICE_SP || sh->slice_type == H264_SLICE_SI) {
        sh->reject = "SP/SI slice";
        return -1;
    }

    if (pps->deblocking_filter_control_present_flag) {
        sh->disable_deblocking_filter_idc = h264_ue(&b);
        if (sh->disable_deblocking_filter_idc != 1) {
            sh->slice_alpha_c0_offset_div2 = h264_se(&b);
            sh->slice_beta_offset_div2 = h264_se(&b);
        }
    }

    if (b.overrun) { sh->reject = "bitstream overrun"; return -1; }

    // What VA-API wants: bits from the start of the NAL (header byte
    // included) to the first bit of slice_data(), counted over the ESCAPED
    // bitstream, because that is what the hardware is handed.
    sh->slice_data_bit_offset = (uint32_t)(8 + h264_bits_consumed_in_nal(&b));
    return 0;
}
