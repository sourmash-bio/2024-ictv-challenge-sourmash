######################################################
# Snakefile for the ICTV Taxonomy Challenge #

# This is a workflow that uses sourmash to classify
# viral sequences to the ICTV VMR MSL39 (v4) database.
# It downloads the ICTV Taxonomy Challenge dataset,
# sketches the sequences, then uses `sourmash gather`
# to find the closest reference genome. Finally, it
# uses `sourmash tax` to assign taxonomy to the sequences
# based on the reference genome and then converts the
# results to the challenge output format.

# To run:
# First, make sure you've cloned the sourmash-ictv-challenge repo
# and created/activated the conda environment as specified in the README.
# Then run:
#
#           snakemake
#
# You can modify the number of cores used by changing the -c parameter.
#
# Requirements:
# This workflow requires XX GB of disk space and XX GB of RAM, and
# takes about XX minutes to run on a 8-core machine.
######################################################
out_dir = "output.ictv-challenge"
logs_dir = f"{out_dir}/logs"

THRESHOLD_BP = 300
LGC_THRESHOLD = 0.75

rule all:
    input:
        f"{out_dir}/ictv-challenge.sourmash.csv",
        f"{logs_dir}/summary.csv",

rule download_database:
    output:
        rocksdb_current = "vmr_MSL39_v4.skipm2n3-k24-sc100.rocksdb/CURRENT"
    params:
        #download_link = "https://farm.cse.ucdavis.edu/~ctbrown/sourmash-db/ictv-vmr-msl39/vmr_MSL39_v4.skipm2n3-k24-sc100.rocksdb.tar.gz",
        download_link = "https://osf.io/download/f246c/",
        download_file = "vmr_MSL39_v4.skipm2n3-k24-sc100.rocksdb.tar.gz",
    benchmark: f"{logs_dir}/download_database.benchmark"
    shell:
        """
        curl -JLO {params.download_link}
        tar -xzf {params.download_file}
        """

rule download_and_prep_ictv_challenge:
    output:
        challenge_fromfile=f"{out_dir}/ictv-challenge.fromfile.csv",
    params:
        challenge_link = "https://github.com/ICTV-VBEG/ICTV-TaxonomyChallenge/raw/refs/heads/main/dataset/dataset_challenge.tar.gz?download=",
        challenge_file = "dataset_challenge.tar.gz",
        challenge_dir =  "dataset_challenge",
    benchmark: f"{logs_dir}/prep_challenge_dataset.benchmark"
    shell: 
        """
        curl -JL {params.challenge_link} -o {params.challenge_file}
        tar -xzf {params.challenge_file}
        python scripts/challengedir-to-csvinput.py {params.challenge_dir} {output.challenge_fromfile}
        """

rule sketch_challenge_dataset:
    input:
        ancient(f"{out_dir}/ictv-challenge.fromfile.csv")
    output:
        challenge_zip=f"{out_dir}/ictv-challenge.zip"
    params:
        param_str = "-p skipm2n3,k=24,scaled=100,abund",
    log: f"{logs_dir}/manysketch.log"
    benchmark: f"{logs_dir}/manysketch.benchmark"
    shell:
        """
        sourmash scripts manysketch {input} {params.param_str} -o {output} 2> {log}
        """

rule sourmash_fastmultigather:
    input:
        challenge_zip=f"{out_dir}/ictv-challenge.zip",
        vmr_rdb_current = ancient("vmr_MSL39_v4.skipm2n3-k24-sc100.rocksdb/CURRENT")
    output:
        fmg= f"{out_dir}/ictv-challenge.fmg.csv"
    log: f"{logs_dir}/fmg.log"
    benchmark: f"{logs_dir}/fmg.benchmark"
    params:
        db_dir = lambda w: f"vmr_MSL39_v4.skipm2n3-k24-sc100.rocksdb",
        threshold_bp = THRESHOLD_BP,
    shell:
        """
        sourmash scripts fastmultigather {input.challenge_zip} {params.db_dir} \
                                         -m skipm2n3 -k 24 --scaled 100 \
                                         --threshold-bp {params.threshold_bp} \
                                         -o {output.fmg} 2> {log}
        """

rule sourmash_tax_genome:
    input:
        fmg= f"{out_dir}/ictv-challenge.fmg.csv",
        vmr_lineages = "vmr_MSL39_v4.lineages.csv.gz",
    output:
        tax=f"{out_dir}/ictv-challenge.classifications.csv"
    log: f"{logs_dir}/tax-genome.log"
    benchmark: f"{logs_dir}/tax-genome.benchmark"
    params:
        out_base= lambda w: f"ictv-challenge",
        out_dir= out_dir,
        lgc_threshold = LGC_THRESHOLD,
    shell:
        """
        sourmash tax genome -t {input.vmr_lineages} -g {input.fmg} --ictv -F csv_summary \
                            --ani-threshold {params.lgc_threshold} --output-base {params.out_base} \
                            --output-dir {params.out_dir} 2> {log}
        """

rule sourmash_tg_to_challenge_format:
    input: 
        tax=f"{out_dir}/ictv-challenge.classifications.csv"
    output:
        ch= f"{out_dir}/ictv-challenge.sourmash.csv"
    log: f"{logs_dir}/convert.log"
    benchmark: f"{logs_dir}/convert.benchmark"
    shell:
        """
        python scripts/tg-to-challengeformat.py {input.tax} {output.ch} 2> {log}
        """

rule summarize_resource_utilization:
    input:
        benches = expand(f"{logs_dir}/{{log}}.benchmark", log=["download_database", "prep_challenge_dataset", "manysketch", "fmg", "tax-genome", "convert"]),
    output:
        benchmarks=f"{logs_dir}/benchmarks.csv",
        summary=f"{logs_dir}/summary.csv"
    shell:
        """
        python scripts/benchmarks.py {input.benches} --benchmarks-csv {output.benchmarks} --summary-csv {output.summary}
        """