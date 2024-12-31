import argparse
import csv
from sourmash.tax.tax_utils import ICTVRankLineageInfo

def csv_to_lineages(file_path):
    """
    Read the CSV file and ignore *_score columns while parsing lineage data.
    """
    data = {}
    empty_lin = ICTVRankLineageInfo(lineage_str="")
    with open(file_path, 'r') as f:
        reader = csv.DictReader(f)
        # Preprocess fieldnames: lowercase and split by space so we can match sourmash ictv ranks
        reader.fieldnames = [field.split(" ")[0].lower() for field in reader.fieldnames]
        for row in reader:
            sequence_id = row["sequenceid"]
            # read in columns as a lineage
            lineage_info = ICTVRankLineageInfo(lineage_dict=row)
            if lineage_info == empty_lin:
                continue
            data[sequence_id] = lineage_info
    return data

def compare_files(args):
    """
    Compare two CSV files with lineages and write differences to an output file.
    """
    empty_lin = ICTVRankLineageInfo(lineage_str="")
    file1_data = csv_to_lineages(args.f1)
    file2_data = csv_to_lineages(args.f2)

    # Find differences
    differences = []
    all_keys = set(file1_data.keys()).union(file2_data.keys())

    for key in all_keys:
        lin1 = file1_data.get(key, empty_lin)
        lin2 = file2_data.get(key, empty_lin)
        if lin1 == empty_lin and lin2 == empty_lin:
            continue
        if lin1 != lin2:
            differences.append((key, lin1, lin2))

    # Write differences to the output file
    with open(args.output, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(["SequenceID", "filetype", "lineage"])
        for seq_id, lin1, lin2 in differences:
            writer.writerow([seq_id, args.f1_name, lin1.display_lineage()])
            writer.writerow([seq_id, args.f2_name, lin2.display_lineage()])

    print(f"Differences written to {args.output}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Compare two TSV files ignoring *_score columns.")
    parser.add_argument("--f1", help="Path to the first CSV file.")
    parser.add_argument("--f1-name", help="Short name for first CSV file.")
    parser.add_argument("--f2", help="Path to the second CSV file.")
    parser.add_argument("--f2-name", help="Short name for second CSV file.")
    parser.add_argument("-o", "--output", help="Path to the output CSV file for differences.")
    args = parser.parse_args()

    compare_files(args)