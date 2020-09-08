#!/bin/bash
#
# Copyright (C) 2020 - Gert Hulselmans
#
# Purpose: Normalize MACS2 peak scores ("-log10(pvalue)") by creating a "score per million":
#          divide each individual peak score by the sum of all of the peak scores in the
#          given sample multiplied by 1 million.



normalize_macs2_peak_scores () {
    local input_peak_bed_file="${1}";
    local output_peak_bed_file="${2}";

    if [ ${#@} -ne 2 ] ; then
        printf '\nUsage:     normalize_macs2_peak_scores \\\n';
        printf '                 input_peak_bed_file \\\n';
        printf '                 output_peak_bed_file\n\n';
        printf 'Arguments:\n';
        printf '           - input_peak_bed_file:\n';
        printf '               Input peak BED file.\n';
        printf '               Use "-" or "stdin" if you want to use standard input.\n';
        printf '           - output_peak_bed_file:\n';
        printf '               Output peak BED file.\n';
        printf '               Use "-" or "stdout" if you want to use standard output.\n\n';
        printf 'Purpose:   Normalize MACS2 peak scores ("-log10(pvalue)") by creating\n';
        printf '           a "score per million": divide each individual peak score\n';
        printf '           by the sum of all of the peak scores in the given sample\n';
        printf '           multiplied by 1 million.\n\n';
        return 1;
    fi

    if ( [ "${input_peak_bed_file}" = 'stdin' ] || [ "${input_peak_bed_file}" = '-' ] ) ; then
        input_peak_bed_file='/dev/stdin';
    fi

    if ( [ "${output_peak_bed_file}" = 'stdout' ] || [ "${output_peak_bed_file}" = '-' ] ) ; then
        output_peak_bed_file='/dev/stdout';
    fi

    # Normalize MACS2 peak scores ("-log10(pvalue)") by creating a "score per million":
    #   - Divide each individual peak score by the sum of all of the peak scores in the
    #     given sample multiplied by 1 million.
    gawk -F '\t' -v 'OFS=\t' '
        {
            # Store columns 1-4.
            columns_1_to_4[NR] = $1 "\t" $2 "\t" $3 "\t" $4;

            # Store MACS2 peak score.
            macs_peak_score = $5;
            macs_peak_scores[NR] = macs_peak_score;

            # Calcuate total MACS2 peak scores value.
            total_macs_peak_scores += macs_peak_score
        } END {
            for (i = 1; i <= NR; i++) {
                # Print each peak with the normalized score.
                print columns_1_to_4[i] "\t" (macs_peak_scores[i] / total_macs_peak_scores * 1000000);
            }            
        }
        ' \
        "${input_peak_bed_file}" \
      > "${output_peak_bed_file}";

    # Check if any of the piped commands failed.
    for exit_code in "${PIPESTATUS[@]}" ; do
        if [ ${exit_code} -ne 0 ] ; then
            return ${exit_code};
        fi
    done

    return 0;
}



normalize_macs2_peak_scores "${@}";
