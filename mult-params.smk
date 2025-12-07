############################################################################
# Workflow: sourmash classification of the ICTV Taxonomy Challenge Dataset #

# This is a workflow that uses sourmash to classify viral sequences to
# the ICTV VMR MSL39 (v4) database. It downloads the ICTV Taxonomy
# Challenge dataset, sketches the sequences, then uses `sourmash gather`
# to find the closest reference genome. Finally, it uses `sourmash tax`
# to assign taxonomy to the sequences based on the reference genome
# and then converts the results to the challenge output format.

# This particular workflow runs four different parameter sets: DNA with ksizes
# 21 and 31, and skipm2n3 with ksizes 24 and 27, all with scaled=50 and
# abund. All four are sketched together in one step to save time, and then
# each parameter set is classified separately.

# To run:
# First, make sure you've cloned the ictv-challenge-sourmash repo
# and created/activated the conda environment as specified in the README.
# Then run:
#
#           snakemake -j 4
#
# You can modify the number of cores used by changing the -c parameter, but
# it does not significantly speed up this workflow. Here we use 4 to allow
# classification with all four parameter sets at once. Larger datasets may
# benefit from more cores.
#
# Requirements:
# The challenge dataset is ~1.5 GB and the database is <0.5 GB; classification
# requires ~1 GB of RAM. To be safe, we recommend running on a machine with
# at least 5 GB disk space, 5G RAM. The full workflow (including data download)
# takes 5-15 minutes to run.
############################################################################


out_dir = "output.ictv-challenge.multiparam"
logs_dir = f"{out_dir}/logs"

THRESHOLD_BP = 200
TAX_THRESHOLD = 0.75

submission_types = ["DNA-k21-sc50", "DNA-k31-sc50", "skipm2n3-k24-sc50", "skipm2n3-k27-sc50"]

database_links = {
    "DNA-k21-sc50": "https://osf.io/download/8qxa2/",
    "DNA-k31-sc50": "https://osf.io/download/n8dgy/",
    "skipm2n3-k24-sc50": "https://osf.io/download/u3ftq/",
    "skipm2n3-k27-sc50": "https://osf.io/download/mjqdg/",
}

param_strings = {
    "DNA-k21-sc50": "-p dna,k=21,scaled=50,abund",
    "DNA-k31-sc50": "-p dna,k=31,scaled=50,abund",
    "skipm2n3-k24-sc50": "-p skipm2n3,k=24,scaled=50,abund",
    "skipm2n3-k27-sc50": "-p skipm2n3,k=27,scaled=50,abund",
}


rule all:
    input:
        expand(f"{out_dir}/ictv-challenge.{{stype}}.sourmash.csv", stype=submission_types),
        f"{logs_dir}/summary.csv",
        f"{out_dir}/results-diff.csv",

rule download_database:
    output:
        rocksdb_tar = "vmr_MSL39_v4.{stype}.rocksdb.tar.gz"
    params:
        download_link = lambda w: database_links[w.stype]
    benchmark: f"{logs_dir}/download_database.{{stype}}.benchmark"
    shell:
        """
        curl -JLO {params.download_link}
        """

rule untar_database:
    input:
        rocksdb_tar = ancient("vmr_MSL39_v4.{stype}.rocksdb.tar.gz")
    output:
        rocksdb_current = "vmr_MSL39_v4.{stype}.rocksdb/CURRENT"
    benchmark: f"{logs_dir}/untar_database.{{stype}}.benchmark"
    shell:
        """
        tar -xzf {input.rocksdb_tar}
        """

rule download_ictv_challenge:
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
        param_str=' '.join(param_strings[stype] for stype in submission_types)
    log: f"{logs_dir}/manysketch_multi.log"
    benchmark: f"{logs_dir}/manysketch_multi.benchmark"
    shell:
        """
        sourmash scripts manysketch {input} {params.param_str} -o {output} 2> {log}
        """

rule sourmash_fastmultigather:
    input:
        challenge_zip=f"{out_dir}/ictv-challenge.zip",
        vmr_rdb_current = ancient("vmr_MSL39_v4.{stype}.rocksdb/CURRENT")
    output:
        fmg=f"{out_dir}/ictv-challenge.{{stype}}.fmg.csv"
    log: f"{logs_dir}/fmg_{{stype}}.log"
    benchmark: f"{logs_dir}/fmg_{{stype}}.benchmark"
    params:
        db_dir=lambda w: f"vmr_MSL39_v4.{w.stype}.rocksdb",
        threshold_bp=THRESHOLD_BP,
        ksize = lambda w: w.stype.split("-")[1][1:],
        moltype = lambda w: w.stype.split("-")[0],
    shell:
        """
        sourmash scripts fastmultigather {input.challenge_zip} {params.db_dir} \
                                         --threshold-bp {params.threshold_bp} \
                                         -o {output.fmg} -k {params.ksize} \
                                         -m {params.moltype} 2> {log}
        """

rule sourmash_tax_genome:
    input:
        fmg=f"{out_dir}/ictv-challenge.{{stype}}.fmg.csv",
        vmr_lineages="vmr_MSL39_v4.lineages.csv.gz",
    output:
        tax=f"{out_dir}/ictv-challenge.{{stype}}.classifications.csv"
    log: f"{logs_dir}/tax-genome_{{stype}}.log"
    benchmark: f"{logs_dir}/tax-genome_{{stype}}.benchmark"
    params:
        out_base=lambda w: f"ictv-challenge.{w.stype}",
        out_dir=out_dir,
        tax_threshold=TAX_THRESHOLD
    shell:
        """
        sourmash tax genome -t {input.vmr_lineages} -g {input.fmg} --ictv -F csv_summary \
                            --ani-threshold {params.tax_threshold} --output-base {params.out_base} \
                            --output-dir {params.out_dir} 2> {log}
        """

rule sourmash_tg_to_challenge_format:
    input:
        tax=f"{out_dir}/ictv-challenge.{{stype}}.classifications.csv",
        dataset_csv=ancient("dataset-challenge.fromfile.csv"),
    output:
        ch=f"{out_dir}/ictv-challenge.{{stype}}.sourmash.csv"
    log: f"{logs_dir}/convert_{{stype}}.log"
    benchmark: f"{logs_dir}/convert_{{stype}}.benchmark"
    shell:
        """
        python scripts/tg-to-challengeformat.py {input.tax} {output.ch} 2> {log}
        """


rule summarize_resource_utilization:
    input:
        # benches = expand(f"{logs_dir}/{{log}}.benchmark", log=["download_database", "download_challenge_dataset", "manysketch", "fmg", "tax-genome", "convert"]),
        benches=expand(f"{logs_dir}/download_database.{{stype}}.benchmark", stype = submission_types) +
                expand(f"{logs_dir}/download_challenge_dataset.benchmark", ) +
                expand(f"{logs_dir}/manysketch_multi.benchmark", ) +
                expand(f"{logs_dir}/fmg_{{stype}}.benchmark", stype=submission_types) +
                expand(f"{logs_dir}/tax-genome_{{stype}}.benchmark", stype=submission_types) +
                expand(f"{logs_dir}/convert_{{stype}}.benchmark", stype=submission_types),
    output:
        benchmarks=f"{logs_dir}/benchmarks.csv",
        summary=f"{logs_dir}/summary.csv"
    shell:
        """
        python scripts/benchmarks.py {input.benches} --benchmarks-csv {output.benchmarks} --summary-csv {output.summary}
        """

rule compare_vs_saved_results:
    input:
        saved_results="results/ictv-challenge.sourmash.csv",
        workflow_results=f"{out_dir}/ictv-challenge.skipm2n3-k24-sc50.sourmash.csv",
    output:
        diff=f"{out_dir}/results-diff.csv"
    shell:
        """
        python scripts/compare-results.py --f1 {input.saved_results} \
                                          --f1-name "saved" \
                                          --f2 {input.workflow_results} \
                                          --f2-name "workflow" \
                                          --output {output}
        """