# ICTV Challenge: Taxonomic classification of viruses with sourmash
For the [ICTV Computational Virus Taxonomy Challenge](https://ictv-vbeg.github.io/ICTV-TaxonomyChallenge/), we used [sourmash](https://github.com/sourmash-bio) as a taxonomic classifier for viral sequences. This method has previously been shown to work well for metagenomic profiling of microbial sequences [(Portik, Brown, and Pierce-Ward, 2022)](https://bmcbioinformatics.biomedcentral.com/articles/10.1186/s12859-022-05103-0).

## Resource Requirements
With the challenge dataset (1.3 GB), the workflow requires ~3GB of disk space and ~1G of RAM. The full workflow (including data download) takes 5-15 minutes to run, depending on your machine.

## Running the workflow

We provide an automated workflow via [snakemake](https://snakemake.readthedocs.io/en/stable/) and provide conda-based installation of software and dependencies. [Sourmash]([https:/](https://github.com/sourmash-bio/sourmash)/) and [sourmash-branchwater](https://github.com/sourmash-bio/sourmash_plugin_branchwater) run under Python 3.10 or later.

Clone the repository
```
git clone https://github.com/sourmash-bio/2024-ictv-challenge-sourmash.git
```
Install sourmash and dependencies using conda/mamba
```
cd 2024-ictv-challenge-sourmash
mamba env create -f environment.yml
```
activate the environment
```
mamba activate 2024-ictv-challenge-sourmash
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
Results will appear in the `output.ictv-challenge` folder (filename: `ictv-challenge.sourmash.csv`) and should be identical to the pre-calculated results. We include a workflow step that compares the new results with the saved results and writes any differences to `output.ictv-challenge.results-diff.csv`.

Pre-calculated results are available at: `results/ictv-challenge.sourmash.csv`


## Workflow Details

### Data Preparation
The pipeline first downloads an indexed version of [VMR MSL 39 (v4)](https://ictv.global/vmr) database. Then, it downloads the challenge dataset and builds sourmash sketches for search (parameters: `k=24, scaled=50, skipm2n3`). Sourmash processes each sequence individually and stores one sketch per sequence in a sourmash zipfile.

### Search and Taxonomic Classification
To conduct classification, we use the [sourmash gather](https://sourmash.readthedocs.io/en/latest/classifying-signatures.html#analyzing-metagenomic-samples-with-gather) approach for identifying the most similar reference genome. Here, 'gather' finds a collection of genomes that best explains all of the observed k-mers. Finally, we use `sourmash taxonomy` to apply the taxonomic information from the best reference genome(s) to the query sequence, if it meets a match threshold.


### Notes on parameter selection and tuning

Sourmash is a flexible toolkit for k-mer based analyses. The parameters in this workflow were selected to balance the sensitivity required for diverse viral sequences with speed and resource utilization, especially as the challenge dataset sequences range in size from <100bp to >1Mb. The default sourmash parameters (DNA k-mer length 31, scaled=1000) function well for microbial queries, but viruses are commonly smaller and more diverse. For viruses, we increased the resolution (scaled=50), and implemented an alternative k-mer type, [skip-mers](https://www.biorxiv.org/content/10.1101/179960), in the [sourmash branchwater plugin](https://github.com/sourmash-bio/sourmash_plugin_branchwater). Skip-mers are k-mers built with gaps at regular intervals -- here, every third base position. The idea behind skip-mers is that allowing mismatches at the gapped locations provides increased sensitivity, particularly in conserved genic regions.

#### Parameter tuning for `sourmash gather`
To identify a reference genome match, we require a minimum of at least 200 nucleotides/bp in common. In general, we recommend requiring `threshold_bp` >= `3*scaled`, but this can be increased for greater specificity. *This parameter can be modified in the `Snakefile` provided here (THRESHOLD_BP).*

Changing the k-mer size and scaling also have an impact upon sensitivity, specificity, and resource utilization. For example, running this workflow with `scaled=100` would reduce the runtime at the expense of classification capacity for shorter sequences. Longer k-mer sizes are more specific, shorter are more sensitive. Skip-mers have increased sensitivity relative to standard DNA k-mers. Further details on parameter tuning are available on the [sourmash FAQ](https://sourmash.readthedocs.io/en/latest/faq.html).


#### Parameter tuning for `sourmash taxonomy`
We have set a classification threshold of 75% estimated log containment ("containment ANI" [Rahman Hera, Pierce-Ward, and Koslicki](https://pubmed.ncbi.nlm.nih.gov/37344105/)) to accept classification at a given rank. If this threshold is not met, we move use an LCA approach on the gather results until we have sufficient % match. *This parameter can be modified in the `Snakefile` provided here (TAX_THRESHOLD).*

## References

[1] [sourmash v4: A multitool to quickly search, compare, and analyze genomic and metagenomic data sets](https://joss.theoj.org/papers/10.21105/joss.06830)

[2] [Lightweight compositional analysis of metagenomes with FracMinHash and minimum metagenome covers](https://www.biorxiv.org/content/10.1101/2022.01.11.475838v2)

[3] [Evaluation of taxonomic classification and profiling methods for long-read shotgun metagenomic sequencing datasets](https://bmcbioinformatics.biomedcentral.com/articles/10.1186/s12859-022-05103-0)

[4] [Deriving confidence intervals for mutation rates across a wide range of evolutionary distances using FracMinHash](https://pubmed.ncbi.nlm.nih.gov/37344105/)

[5] [Skip-mers: increasing entropy and sensitivity to detect conserved genic regions with simple cyclic q-grams](https://www.biorxiv.org/content/10.1101/179960v2)
