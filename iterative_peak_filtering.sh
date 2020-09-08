#!/bin/bash
#
# Copyright (C) 2018 - Gert Hulselmans
#
# Purpose: Filter peaks iteratively.



check_gawk_array_looping_order () {
    # Check if gawk support looping over array by element values in descending order:
    #     PROCINFO["sorted_in"] = "@val_num_desc":
    gawk '
        BEGIN {
            # https://www.gnu.org/software/gawk/manual/html_node/Controlling-Scanning.html#Controlling-Scanning
            PROCINFO["sorted_in"] = "@val_num_desc";

            # Create array.
            val_num_desc_sorted_array[1] = 1.5;
            val_num_desc_sorted_array[2] = 0.5;
            val_num_desc_sorted_array[3] = 2.5;
            val_num_desc_sorted_array[4] = 3.0;
            val_num_desc_sorted_array[5] = 2.0;
            val_num_desc_sorted_array[6] = 4.5;
            val_num_desc_sorted_array[7] = 3.5;

            # Loop over the array.
            for (idx in val_num_desc_sorted_array){
                val_num_desc_sorted_array_index_order = val_num_desc_sorted_array_index_order sprintf(" %d", idx);
            }

            # Check if this gawk version supports looping over an array
            # by element values in descending order
            # (PROCINFO["sorted_in"] = "@val_num_desc").
            if (val_num_desc_sorted_array_index_order == " 6 7 4 3 5 1 2") {
                exit(0);
            }

            # This gawk version does not support PROCINFO["sorted_in"] = "@val_num_desc".
            exit(1);
        }
    ';
}




iterative_peak_filtering () {
    local input_peak_bed_file="${1}";
    local output_peak_bed_file="${2}";
    local chrom_sizes_file="${3}";

    if [ ${#@} -ne 3 ] ; then
        printf '\nUsage:     iterative_peak_filtering \\\n';
        printf '                 input_peak_bed_file \\\n';
        printf '                 output_peak_bed_file \\\n';
        printf '                 chrom_sizes_file\n\n';
        printf 'Arguments:\n';
        printf '           - input_peak_bed_file:\n';
        printf '               Input peak BED file.\n';
        printf '               Use "-" or "stdin" if you want to use standard input.\n';
        printf '           - output_peak_bed_file:\n';
        printf '               Output peak BED file.\n';
        printf '               Use "-" or "stdout" if you want to use standard output.\n';
        printf '           - chrom_sizes_file:\n';
        printf '               File with chromosome names in the first column and\n';
        printf '               chromosome size in the second.\n\n';
        printf 'Purpose:    Filter peaks iteratively:\n';
        printf '              - Take the most significant peaks and remove any peak\n';
        printf '                that overlaps directly with this significant peak.\n';
        printf '              - Repeat this process for the next most significant\n';
        printf '                peak (that is not removed already) and so on until\n';
        printf '                there are no peaks to process anymore.\n\n';
        return 1;
    fi

    # Check if gawk supports a feature we need.
    if ! check_gawk_array_looping_order ; then
        printf 'Error: Install gawk with support looping over array by element values in descending order:\n\n';
        printf '           PROCINFO["sorted_in"] = "@val_num_desc"\n';
        printf '           See https://www.gnu.org/software/gawk/manual/html_node/Controlling-Scanning.html#Controlling-Scanning\n\n';
        return 1;
    fi

    if ( [ "${input_peak_bed_file}" = 'stdin' ] || [ "${input_peak_bed_file}" = '-' ] ) ; then
        input_peak_bed_file='/dev/stdin';
    fi

    if ( [ "${output_peak_bed_file}" = 'stdout' ] || [ "${output_peak_bed_file}" = '-' ] ) ; then
        output_peak_bed_file='/dev/stdout';
    fi


    #   - Get chrom, start, end, peak name and peak score from input peak BED file:
    #       - if MACS2 narrowpeak or broadpeak file, use "-log10(pvalue)" column (column 8) as peak scores,
    #       - else use column 5 as peak scores.
    #   - Sort peaks by coordinates.
    #   - Merge overlapping peak regions:
    #       - Count number of peaks merged to one region0
    #       - For each merged peak region keep the values of the original peak regions for:
    #           - start
    #           - end
    #           - peak name
    #           - peak score
    #   - For each merged peak region, if number of merged regions:
    #       - = 1 :  Print the original peak region.
    #       - = 2 :  Check which original peak region has the highest score and print it.
    #       - >=3 :  First take the orignal peak region with the most significant score,
    #                remove all original peak regions in this merged peak region that
    #                overlap with this peak region and print this peak region. Repeat
    #                this process with the next most significant peak (if it was not
    #                removed already) until all peaks are processed.
    gawk \
        -F '\t' -v 'OFS=\t' '
        {
            if (NF == 10) {
                # Assume input is a MACS2 narrowpeak or broadpeak file (use "-log10(pvalue)" column as peak scores).
                print $1, $2 , $3, $4, $8;
            } else {
                # Get first 5 columns.
                print $1, $2 , $3, $4, $5;
            }
        }
        ' \
        "${input_peak_bed_file}" \
      | bedtools sort \
            -g "${chrom_sizes_file}" \
            -i stdin \
      | bedtools merge \
            -i stdin \
            -c 1,2,3,4,5 \
            -o count,collapse,collapse,collapse,collapse \
      | gawk \
            -F '\t' -v 'OFS=\t' '
                BEGIN {
                    # https://www.gnu.org/software/gawk/manual/html_node/Controlling-Scanning.html#Controlling-Scanning
                    PROCINFO["sorted_in"] = "@val_num_desc";
                }
                {
                    # Get number of merged peak regions.
                    nbr_merged_regions = $4;

                    # Split starts, ends, names and peak scores of the original peak regions that were merged.
                    split($5, starts, ",");
                    split($6, ends, ",");
                    split($7, names, ",");
                    split($8, peak_scores, ",");

                    if (nbr_merged_regions == 1) {
                        # This peak region was not merged with any other peak, so just print it.
                        current_peak_idx = 1;

                        print $1, starts[current_peak_idx], ends[current_peak_idx], names[current_peak_idx], peak_scores[current_peak_idx];
                    } else if (nbr_merged_regions == 2) {
                        # This merged peak region contains 2 original peaks. Print the one with the highest score.
                        if (peak_scores[1] >= peak_scores[2]) {
                            current_peak_idx = 1;
                        } else {
                            current_peak_idx = 2;
                        }

                        print $1, starts[current_peak_idx], ends[current_peak_idx], names[current_peak_idx], peak_scores[current_peak_idx];
                    } else {
                        # This merged peak region contains 3 or more original peaks.

                        # Create empty "selected_prev_peak_indexes" array:
                        #   - Keep track of peaks which were printed already.
                        split("", selected_prev_peak_indexes);

                        # Create empty "peak_indexes_to_ignore" array:
                        #   - Keep track of peak indexes that should not be considered anymore.
                        #   - After a new selected peak was found:
                        #       - Index for Selected peak is added.
                        #       - The index for the peak just before or after a selected peak
                        #         index is added as those peaks are overlapping with the
                        #         currently selected peak.
                        split("", peak_indexes_to_ignore);

                        # Loop over all peak scores of the original peaks for this merged region,
                        # from high to low (due to PROCINFO["sorted_in"] = "@val_num_desc").
                        for (current_peak_idx in peak_scores) {
                            # Only continue if this peak is not in list of peaks to ignore, which
                            # contains peaks which are already printed and adjacent peaks
                            # (as those peaks would overlap with the already printed peaks).
                            if ( ! (current_peak_idx in peak_indexes_to_ignore) ) {
                                # Reset "skip_current_peak":
                                #   - 0: Print current peak.
                                #   - 1: Do not print current peak.
                                skip_current_peak = 0;

                                # Loop over all previous selected peaks to see if they overlap
                                # with the current peak.
                                for (selected_prev_peak_index in selected_prev_peak_indexes) {
                                    # Calculate selected previous peak length.
                                    selected_prev_peak_length = ends[selected_prev_peak_index] - starts[selected_prev_peak_index];

                                    # Calculate the distance from the end of the selected previous
                                    # peak to the start of the current peak.
                                    peak_diff_end_prev_min_start_cur = ends[selected_prev_peak_index] - starts[current_peak_idx];

                                    # Calculate the distance from the end of the current peak to
                                    # the start of the selected previous peak.
                                    peak_diff_end_cur_min_start_prev = ends[current_peak_idx] - starts[selected_prev_peak_index];

                                    if (peak_diff_end_prev_min_start_cur >= 0 && peak_diff_end_prev_min_start_cur <= selected_prev_peak_length) {
                                        # If the distance from the end of the selected previous peak
                                        # to the start of the current peak is:
                                        #
                                        #   0 <= peak_diff_end_prev_min_start_cur <= length of the selected previous peak
                                        #
                                        # skip the current peak as those 2 peaks overlap.
                                        skip_current_peak = 1;
                                    }

                                    if (peak_diff_end_cur_min_start_prev >= 0 && peak_diff_end_cur_min_start_prev <= selected_prev_peak_length) {
                                        # If the distance from the end of the current peak to the
                                        # start of the selected previous peak is:
                                        #
                                        #   0 <= peak_diff_end_cur_min_start_prev <= length of the selected previous peak
                                        #
                                        # skip the current peak as those 2 peaks overlap.
                                        skip_current_peak = 1;
                                    }
                                }

                                if (skip_current_peak == 0) {
                                    # Print peak.
                                    print $1, starts[current_peak_idx], ends[current_peak_idx], names[current_peak_idx], peak_scores[current_peak_idx];

                                    # Add current peak index to the list of selected previous peaks.
                                    selected_prev_peak_indexes[current_peak_idx] = current_peak_idx;

                                    # Add current and peaks adjacent to the current peak to the list
                                    # of peaks to ignore in the next iteration.
                                    peak_indexes_to_ignore[current_peak_idx - 1] = current_peak_idx - 1;
                                    peak_indexes_to_ignore[current_peak_idx] = current_peak_idx;
                                    peak_indexes_to_ignore[current_peak_idx + 1] = current_peak_idx + 1;
                                }
                            }
                        }
                    }
                }' \
      | bedtools sort \
            -g "${chrom_sizes_file}" \
            -i stdin \
      > "${output_peak_bed_file}";

    # Check if any of the piped commands failed.
    for exit_code in "${PIPESTATUS[@]}" ; do
        if [ ${exit_code} -ne 0 ] ; then
            return ${exit_code};
        fi
    done

    return 0;
}



iterative_peak_filtering "${@}";
