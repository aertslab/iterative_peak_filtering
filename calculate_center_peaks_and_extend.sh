#!/bin/bash
#
# Copyright (C) 2018 - Gert Hulselmans
#
# Purpose: Calculate center of each peak region and extend X bp in both directions.



calculate_center_peaks_and_extend () {
    local input_peak_bed_file="${1}";
    local output_peak_bed_file="${2}";
    local chrom_sizes_file="${3}";
    local -i peak_half_width="${4}";

    if [ ${#@} -ne 4 ] ; then
        printf '\nUsage:     calculate_center_peaks_and_extend \\\n';
        printf '                 input_peak_bed_file \\\n';
        printf '                 output_peak_bed_file \\\n';
        printf '                 chrom_sizes_file \\\n';
        printf '                 peak_half_width\n\n';
        printf 'Arguments:\n';
        printf '           - input_peak_bed_file:\n';
        printf '               Input peak BED file.\n';
        printf '               Use "-" or "stdin" if you want to use standard input.\n';
        printf '           - output_peak_bed_file:\n';
        printf '               Output peak BED file.\n';
        printf '               Use "-" or "stdout" if you want to use standard output.\n';
        printf '           - chrom_sizes_file:\n';
        printf '               File with chromosome names in the first column and\n';
        printf '               chromosome size in the second.\n';
        printf '           - peak_half_width:\n';
        printf '               Number of base pairs to extend a peak in each direction\n';
        printf '               from its center.\n\n';
        printf 'Purpose:   Calculate center of each peak region and extend X bp in both directions.\n\n';
        return 1;
    fi

    if ( [ "${input_peak_bed_file}" = 'stdin' ] || [ "${input_peak_bed_file}" = '-' ] ) ; then
        input_peak_bed_file='/dev/stdin';
    fi

    if ( [ "${output_peak_bed_file}" = 'stdout' ] || [ "${output_peak_bed_file}" = '-' ] ) ; then
        output_peak_bed_file='/dev/stdout';
    fi

    # Get center of each peak region and extend X bp in both directions:
    #   - Calculate the center of each peak region
    #   - Extend each peak X bp in both directions from its calculated center.
    #   - Remove extended peaks which are too short (to close to start or end of chromosome).
    #   - Sort the extended peak regions.
    gawk -F '\t' -v 'OFS=\t' '
        {
            # Calculate the center for each peak region:
            #  - If the peak length is uneven, the center will be exaclty in the middle.
            #  - If the peak length is even, the center will be slightly more to the left.
            start_centered = $2 + int( ($3 - $2) / 2);
            end_centered = start_centered + 1;

            # Assign centered start and end position.
            $2 = start_centered;
            $3 = end_centered;

            # Print BED line with new centered start and end position.
            print $0;
        }' \
        "${input_peak_bed_file}" \
      | bedtools slop \
            -g "${chrom_sizes_file}" \
            -b ${peak_half_width} \
      | gawk -F '\t' \
            -v "peak_half_width=${peak_half_width}" '
            BEGIN {
                # Calculate full width of the peak.
                peak_full_width = peak_half_width * 2 + 1;
            }
            {
                # Only keep peaks which have the correct size.
                if ( $3 - $2 == peak_full_width ) {
                    print $0;
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



calculate_center_peaks_and_extend "${@}";
