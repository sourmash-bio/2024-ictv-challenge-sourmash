import argparse
import csv
from sourmash.tax.tax_utils import ICTVRankLineageInfo, ICTV_RANKS

def convert_to_challenge_tsv(input_file, output_file):
    # Define the output columns
    output_columns = [
        "SequenceID",
        "Realm", "Realm_score",
        "Subrealm", "Subrealm_score",
        "Kingdom", "Kingdom_score",
        "Subkingdom", "Subkingdom_score",
        "Phylum", "Phylum_score",
        "Subphylum", "Subphylum_score",
        "Class", "Class_score",
        "Subclass", "Subclass_score",
        "Order", "Order_score",
        "Suborder", "Suborder_score",
        "Family", "Family_score",
        "Subfamily", "Subfamily_score",
        "Genus", "Genus_score",
        "Subgenus", "Subgenus_score",
        "Species", "Species_score",
    ]

    # Actually, use a custom header b/c we need the (-viria) etc. suffixes
    custom_header = [
            "SequenceID",
            "Realm (-viria)", "Realm_score",
            "Subrealm (-vira)", "Subrealm_score",
            "Kingdom (-virae)", "Kingdom_score",
            "Subkingdom (-virites)", "Subkingdom_score",
            "Phylum (-viricota)", "Phylum_score",
            "Subphylum (-viricotina)", "Subphylum_score",
            "Class (-viricetes)", "Class_score",
            "Subclass (-viricetidae)", "Subclass_score",
            "Order (-virales)", "Order_score",
            "Suborder (-virineae)", "Suborder_score",
            "Family (-viridae)", "Family_score",
            "Subfamily (-virinae)", "Subfamily_score",
            "Genus (-virus)", "Genus_score",
            "Subgenus (-virus)", "Subgenus_score",
            "Species (binomial)", "Species_score",
        ]

    with open(input_file, 'r') as infile, open(output_file, 'w', newline='') as outfile:
        # Read input file
        reader = csv.DictReader(infile)
        # Write output file
        writer = csv.DictWriter(outfile, fieldnames=output_columns, delimiter=',')
        #writer.writeheader()
        outfile.write(",".join(custom_header) + "\n") # write custom header instead

        for row in reader:
            lineage_info = ICTVRankLineageInfo(lineage_str=row["lineage"])
            lin_names = lineage_info.zip_lineage()
            capitalized_ranks = [rank.capitalize() for rank in ICTV_RANKS]
            lineage_dict = dict(zip(capitalized_ranks, lin_names))
            # delete unused ranks / info
            del lineage_dict["Name"]
            
            # Prepare output row
            output_row = {col: "" for col in output_columns}
            output_row["SequenceID"] = row["query_name"]
            output_row.update(lineage_dict)

            # Populate lineage information
            writer.writerow(output_row)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert ICTV lineage CSV to TSV with detailed taxonomy columns.")
    parser.add_argument("input_file", help="Path to the input CSV file.")
    parser.add_argument("output_file", help="Path to the output TSV file.")
    args = parser.parse_args()

    convert_to_challenge_tsv(args.input_file, args.output_file)