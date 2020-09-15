
# Iterative peak filtering


## Implementation of iterative peak filtering

This repository implements the iterative peak filtering method described in the following paper:

[The chromatin accessibility landscape of primary human cancers.
 M. Ryan Corces, Jeffrey M. Granja, Shadi Shams, Bryan H. Louie, Jose A. Seoane, Wanding Zhou,
 Tiago C. Silva, Clarice Groeneveld, Christopher K. Wong, Seung Woo Cho, Ansuman T. Satpathy,
 Maxwell R. Mumbach, Katherine A. Hoadley, A. Gordon Robertson, Nathan C. Sheffield, Ina Felau,
 Mauro A. A. Castro, Benjamin P. Berman, Louis M. Staudt, Jean C. Zenklusen, Peter W. Laird,
 Christina Curtis, The Cancer Genome Atlas Analysis Network, William J. Greenleaf, Howard Y. Chang.
 Science  26 Oct 2018
](http://science.sciencemag.org/content/362/6413/eaav1898)

[**Peak calling section** in **Material and Methods**](http://science.sciencemag.org/content/sci/suppl/2018/10/24/362.6413.eaav1898.DC1/aav1898_Corces_SM.pdf) 


## Requirements

  - Recent version of [bedtools2](https://github.com/arq5x/bedtools2)
  - [gawk](https://www.gnu.org/software/gawk/) with support for *looping over array by element values in descending order*.


## Installation


Clone this git repository:

```bash
git clone https://github.com/aertslab/iterative_peak_filtering

cd iterative_peak_filtering
```


## Usage

Each of the following steps works independently of each other, so steps can be replaced, skipped or repeated.

Example:

   - For each sample, run the following steps:
     - *Call peaks*
     - *Extend peak summits*
     - *Remove peaks overlapping blacklisted regions*
     - *Iteratively filter out less significant peaks that overlap with a more significant one*
     - *Normalize peaks*
   - Then combine final output file for all samples (normalized peaks output) and
     run *"Iteratively filter out less significant peaks that overlap with a more significant one"*
     step on the combined peaks of multiple samples.


### 1. Call peaks

Call peaks on your data with for example [MACS](https://github.com/taoliu/MACS/) and use the summit files in the next step.

Parameters as used in the paper:

```bash
# Extend reads 5'->3' direction to fix-sized fragments.
declare -i extsize_value=150;

# Calculate shift value (-75 in this case).
declare -i shift_value='extsize_value / 2 * -1';


# Call peaks with MACS.
MACS \
    callpeak \
        --nomodel \
        --shift "${shift_value}" \
        --extsize "${extsize_value}" \
        --call-summits \
        --nolambda \
        --keep-dup 'all' \
        -p 0.01 \
        -t "${treatment_bam_file}" \
        -n "${sample_name}"
```

### 2. Extend peak summits to X bp

Calculate center of each peak region and extend X bp in both directions.
Peaks whose center is to close to the start or end of the chromosome are removed,
so all extended peaks have the same size (= X bp * 2 + 1).

```bash
$ ./calculate_center_peaks_and_extend.sh 

Usage:     calculate_center_peaks_and_extend \
                 input_peak_bed_file \
                 output_peak_bed_file \
                 chrom_sizes_file \
                 peak_half_width

Arguments:
           - input_peak_bed_file:
               Input peak BED file.
               Use "-" or "stdin" if you want to use standard input.
           - output_peak_bed_file:
               Output peak BED file.
               Use "-" or "stdout" if you want to use standard output.
           - chrom_sizes_file:
               File with chromosome names in the first column and
               chromosome size in the second.
           - peak_half_width:
               Number of base pairs to extend a peak in each direction
               from its center.

Purpose:   Calculate center of each peak region and extend X bp in both directions.

```

Parameters as used in the paper:

```bash
peak_half_width='250';
```


### 3. Remove peaks overlapping blacklisted regions

Remove all extended peaks (created with the previous step) that (partially) overlap with blacklisted regions.

A list of blacklisted regions for different species can be found in the **lists** directory of the
[Boyle-Lab/Blacklists](https://github.com/Boyle-Lab/Blacklist) repo:

```bash
$ ./remove_peaks_overlapping_blacklisted_regions.sh 

Usage:     remove_peaks_overlapping_blacklisted_regions \
                 input_peak_bed_file \
                 output_peak_bed_file \
                 chrom_sizes_file \
                 blacklist_file

Arguments:
           - input_peak_bed_file:
               Input peak BED file.
               Use "-" or "stdin" if you want to use standard input.
           - output_peak_bed_file:
               Output peak BED file.
               Use "-" or "stdout" if you want to use standard output.
           - chrom_sizes_file:
               File with chromosome names in the first column and
               chromosome size in the second.
           - blacklist_file:
               File with blacklisted regions.
               Files for different species can be found at:
                 https://github.com/Boyle-Lab/Blacklist/tree/master/lists

Purpose:   Remove all peaks that (partially) overlap with blacklisted regions.

```


### 4. Iteratively filter out less significant peaks that overlap with a more significant one

Iteratively filter out less significant peaks that overlap with a more significant one:
  - Take the most significant peaks and remove any peak
    that overlaps directly with this significant peak.
  - Repeat this process for the next most significant
    peak (that is not removed already) and so on until
    there are no peaks to process anymore.


```bash
$ ./iterative_peak_filtering.sh 

Usage:     iterative_peak_filtering \
                 input_peak_bed_file \
                 output_peak_bed_file \
                 chrom_sizes_file

Arguments:
           - input_peak_bed_file:
               Input peak BED file.
               Use "-" or "stdin" if you want to use standard input.
           - output_peak_bed_file:
               Output peak BED file.
               Use "-" or "stdout" if you want to use standard output.
           - chrom_sizes_file:
               File with chromosome names in the first column and
               chromosome size in the second.

Purpose:    Filter peaks iteratively:
              - Take the most significant peaks and remove any peak
                that overlaps directly with this significant peak.
              - Repeat this process for the next most significant
                peak (that is not removed already) and so on until
                there are no peaks to process anymore.

```


### 5. Normalize peaks

Normalize MACS2 peak scores ("-log10(pvalue)") by creating a "score per million":
  - Divide each individual peak score by the sum of all of the peak scores in the
    given sample multiplied by 1 million.


```bash
$ ./normalize_macs2_peak_scores.sh

Usage:     normalize_macs2_peak_scores \
                 input_peak_bed_file \
                 output_peak_bed_file

Arguments:
           - input_peak_bed_file:
               Input peak BED file.
               Use "-" or "stdin" if you want to use standard input.
           - output_peak_bed_file:
               Output peak BED file.
               Use "-" or "stdout" if you want to use standard output.

Purpose:   Normalize MACS2 peak scores ("-log10(pvalue)") by creating
           a "score per million": divide each individual peak score
           by the sum of all of the peak scores in the given sample
           multiplied by 1 million.

```
