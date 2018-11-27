#!/bin/bash
#
# Copyright (C) 2018 - Gert Hulselmans
#
# Purpose: Remove all peaks that (partially) overlap with blacklisted regions.



remove_peaks_overlapping_blacklisted_regions () {
    local input_peak_bed_file="${1}";
    local output_peak_bed_file="${2}";
    local chrom_sizes_file="${3}";
    local blacklist_file="${4}";

    if [ ${#@} -ne 4 ] ; then
        printf '\nUsage:     remove_peaks_overlapping_blacklisted_regions \\\n';
        printf '                 input_peak_bed_file \\\n';
        printf '                 output_peak_bed_file \\\n';
        printf '                 chrom_sizes_file \\\n';
        printf '                 blacklist_file\n\n';
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
        printf '           - blacklist_file:\n';
        printf '               File with blacklisted regions.\n';
        printf '               Files for different species can be found at:\n';
        printf '                 https://github.com/Boyle-Lab/Blacklist/tree/master/lists\n\n';
        printf 'Purpose:   Remove all peaks that (partially) overlap with blacklisted regions.\n\n';
        return 1;
    fi

    if ( [ "${input_peak_bed_file}" = 'stdin' ] || [ "${input_peak_bed_file}" = '-' ] ) ; then
        input_peak_bed_file='/dev/stdin';
    fi

    if ( [ "${output_peak_bed_file}" = 'stdout' ] || [ "${output_peak_bed_file}" = '-' ] ) ; then
        output_peak_bed_file='/dev/stdout';
    fi

    # Remove all peaks that (partially) overlap with blacklisted regions.
    #   - Remove all peaks that (partially) overlap with blacklisted regions
    #     completely (instead of only removing the overlapping part).
    #   - Sort peak regions.
    bedtools subtract \
        -A \
        -wa \
        -g "${chrom_sizes_file}" \
        -a "${input_peak_bed_file}" \
        -b "${blacklist_file}" \
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



remove_peaks_overlapping_blacklisted_regions "${@}";
