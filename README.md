# ICTV Challenge: Taxonomic classification of viruses with sourmash
For the [ICTV Computational Virus Taxonomy Challenge](https://ictv-vbeg.github.io/ICTV-TaxonomyChallenge/), we used [sourmash](https://github.com/sourmash-bio) as a taxonomic classifier for viral sequences.

## Resource Requirements
With the challenge dataset (1.3 GB), the workflow requires ~3GB of disk space and ~1G of RAM. The full workflow (including data download) takes 5-15 minutes to run, depending on your machine.

## Running the workflow

We provide an automated workflow via [snakemake](https://snakemake.readthedocs.io/en/stable/) and provide conda-based installation of software and dependencies. [Sourmash]([https:/](https://github.com/sourmash-bio/sourmash)/) and [sourmash-branchwater](https://github.com/sourmash-bio/sourmash_plugin_branchwater) run under Python 3.10 or later.

Clone the repository
```
git clone https://github.com/sourmash-bio/ictv-challenge-sourmash.git
```
Install sourmash and dependencies using conda/mamba
```
cd ictv-challenge-sourmash
mamba env create -f environment.yml
```
activate the environment
```
mamba activate ictv-challenge-sourmash
```
Run the snakemake file

```
snakemake -j 1
```
> You can modify the number of cores used by changing the -c parameter, but
> it does not significantly speed up this workflow. Larger datasets would
> benefit more from parallelization, which can be leveraged extensively
> during the sketching step.

## Results
Results will appear in the `output.ictv-challenge` folder (filename: `ictv-challenge.sourmash.csv`) and should be identical to the pre-calculated results.

Pre-calculated results are available at: `results/ictv-challenge.sourmash.csv`



## Workflow Details

### Data Preparation
The pipeline first downloads an indexed version of [VMR MSL 39 (v4)](https://ictv.global/vmr) database. Then, it downloads the challenge dataset and builds sourmash sketches for search (parameters: `k=24, scaled=50, skipm2n3`). Sourmash processes each sequence individually and stores one sketch per sequence in a sourmash zipfile. 

### Search and Taxonomic Classification
To conduct classification, we use the [sourmash gather](https://sourmash.readthedocs.io/en/latest/classifying-signatures.html#analyzing-metagenomic-samples-with-gather) approach for identifying the most similar reference genome. Here, 'gather' finds a collection of genomes that best explains all of the observed k-mers. Finally, we use `sourmash taxonomy` to apply the taxonomic information from the best reference genome(s) to the query sequence, if it meets a match threshold.


### Notes on parameter selection and tuning

Sourmash is a flexible toolkit for k-mer based analyses. The parameters in this workflow were selected to balance the sensitivity required for diverse viral sequences with speed and resource utilization, especially as the challenge dataset sequences range in size from <100bp to >1Mb. The default sourmash parameters (DNA k-mer length 31, scaled=1000) function well for microbial queries, but viruses are commonly smaller and more diverse. For viruses, we increased the resolution (scaled=50), and implemented an alternative k-mer type, [skipmers](https://www.biorxiv.org/content/10.1101/179960), in the [sourmash branchwater plugin](https://github.com/sourmash-bio/sourmash_plugin_branchwater). Skipmers are k-mers built with gaps at regular intervals -- here, every third base position. The idea behind skipmers is that allowing mismatches at the gapped locations provides increased sensitivity, particularly in conserved genic regions.

#### Parameter tuning for `gather`
To identify a reference genome match, we require a minimum of at least 200 nucleotides/bp in common. In general, we recommend requiring threshold_bp>=3\*scaled, but this can be increased for greater specificity. *This parameter can be modified in the `Snakefile` provided here (THRESHOLD_BP).*

Changing the k-mer size and scaling also have an impact upon sensitivity, specificity, and resource utilization. For example, running this workflow with `scaled=100` reduces the runtime at the expense of classification capacity for shorter sequences. Longer k-mer sizes are more specific, shorter are more sensitive. Skipmers have increased sensitivity relative to standard DNA k-mers. Further details on parameter tuning are available on the [sourmash FAQ](https://sourmash.readthedocs.io/en/latest/faq.html).


#### Parameter tuning for `sourmash taxonomy`
We have set a classification threshold of 75% cANI (~log containment) to accept classification at a given rank. If this threshold is not met, we move up the lineage tree until we have sufficient % match. *This parameter can be modified in the `Snakefile` provided here (TAX_THRESHOLD).*
