import os
import csv
import argparse

def generate_sourmash_sketch_csv(directory, output_csv):
    """
    Generate a CSV file with rows containing filename information.

    Args:
        directory (str): Path to the directory containing .fasta files.
        output_csv (str): Path to the output CSV file.
    """
    with open(output_csv, mode='w', newline='') as csvfile:
        csvwriter = csv.writer(csvfile)
        # Write the header row
        csvwriter.writerow(["name", "genome_filename", "protein_filename"])

        for filename in os.listdir(directory):
            if filename.endswith(".fasta"):
                name = filename.split(".")[0]
                genome_filename = os.path.join(directory, filename)
                # Challenge files are all DNA; leave protein_filename empty for now
                csvwriter.writerow([name, genome_filename, ""])

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate a CSV file from a directory of .fasta files.")
    parser.add_argument("directory", help="Path to the directory containing .fasta files.")
    parser.add_argument("output_csv", help="Path to the output CSV file.")
    
    args = parser.parse_args()

    generate_sourmash_sketch_csv(args.directory, args.output_csv)
