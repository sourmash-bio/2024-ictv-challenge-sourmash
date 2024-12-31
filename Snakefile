############################################################################
# Workflow: sourmash classification of the ICTV Taxonomy Challenge Dataset #

# This is a workflow that uses sourmash to classify viral sequences to
# the ICTV VMR MSL39 (v4) database. It downloads the ICTV Taxonomy
# Challenge dataset, sketches the sequences, then uses `sourmash gather`
# to find the closest reference genome. Finally, it uses `sourmash tax`
# to assign taxonomy to the sequences based on the reference genome
# and then converts the results to the challenge output format.

# To run:
# First, make sure you've cloned the ictv-challenge-sourmash repo
# and created/activated the conda environment as specified in the README.
# Then run:
#
#           snakemake -j 1
#
# You can modify the number of cores used by changing the -c parameter, but
# it does not significantly speed up this workflow. Larger datasets would
# benefit more from parallelization.
#
# Requirements:
# The challenge dataset is ~1.5 GB and the database is <0.5 GB; classification
# requires ~1 GB of RAM. To be safe, we recommend running on a machine with
# at least 5 GB disk space, 5G RAM. The full workflow (including data download)
# takes ~15 minutes to run.
############################################################################
out_dir = "output.ictv-challenge"
logs_dir = f"{out_dir}/logs"

THRESHOLD_BP = 200
LGC_THRESHOLD = 0.75

rule all:
    input:
        f"{out_dir}/ictv-challenge.sourmash.csv",
        f"{logs_dir}/summary.csv",

rule download_database:
    output:
        rocksdb_tar = "vmr_MSL39_v4.skipm2n3-k24-sc50.rocksdb.tar.gz"
    params:
        download_link = "https://osf.io/download/u3ftq/",
    benchmark: f"{logs_dir}/download_database.benchmark"
    shell:
        """
        curl -JLO {params.download_link}
        """

rule untar_database:
    input:
        rocksdb_tar = ancient("vmr_MSL39_v4.skipm2n3-k24-sc50.rocksdb.tar.gz"),
    output:
        rocksdb_current = "vmr_MSL39_v4.skipm2n3-k24-sc50.rocksdb/CURRENT"
    benchmark: f"{logs_dir}/untar_database.benchmark"
    shell:
        """
        tar -xzf {input.rocksdb_tar}
        """

rule download_and_prep_ictv_challenge:
    output:
        challenge_fromfile="dataset-challenge.fromfile.csv",
    params:
        challenge_link = "https://github.com/ICTV-VBEG/ICTV-TaxonomyChallenge/raw/refs/heads/main/dataset/dataset_challenge.tar.gz?download=",
        challenge_file = "dataset_challenge.tar.gz",
        challenge_dir =  "dataset_challenge",
    benchmark: f"{logs_dir}/download_challenge_dataset.benchmark"
    shell: 
        """
        curl -JL {params.challenge_link} -o {params.challenge_file}
        tar -xzf {params.challenge_file}
        python scripts/challengedir-to-csvinput.py {params.challenge_dir} {output.challenge_fromfile}
        """

rule sketch_challenge_dataset:
    input:
        ancient("dataset-challenge.fromfile.csv")
    output:
        challenge_zip=f"{out_dir}/ictv-challenge.zip"
    params:
        param_str = "-p skipm2n3,k=24,scaled=50,abund",
    log: f"{logs_dir}/manysketch.log"
    benchmark: f"{logs_dir}/manysketch.benchmark"
    shell:
        """
        sourmash scripts manysketch {input} {params.param_str} -o {output} 2> {log}
        """

rule sourmash_fastmultigather:
    input:
        challenge_zip=f"{out_dir}/ictv-challenge.zip",
        vmr_rdb_current = ancient("vmr_MSL39_v4.skipm2n3-k24-sc50.rocksdb/CURRENT")
    output:
        fmg= f"{out_dir}/ictv-challenge.fmg.csv"
    log: f"{logs_dir}/fmg.log"
    benchmark: f"{logs_dir}/fmg.benchmark"
    params:
        db_dir = lambda w: f"vmr_MSL39_v4.skipm2n3-k24-sc50.rocksdb",
        threshold_bp = THRESHOLD_BP,
    shell:
        """
        sourmash scripts fastmultigather {input.challenge_zip} {params.db_dir} \
                                         -m skipm2n3 -k 24 --scaled 50 \
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
        benches = expand(f"{logs_dir}/{{log}}.benchmark", log=["download_database", "download_challenge_dataset", "manysketch", "fmg", "tax-genome", "convert"]),
    output:
        benchmarks=f"{logs_dir}/benchmarks.csv",
        summary=f"{logs_dir}/summary.csv"
    shell:
        """
        python scripts/benchmarks.py {input.benches} --benchmarks-csv {output.benchmarks} --summary-csv {output.summary}
        """
