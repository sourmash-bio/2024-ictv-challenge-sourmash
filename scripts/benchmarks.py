import argparse
import os
import csv
import pandas as pd

def parse_benchmark_file(file_path):
    """Parse a single benchmark file and return its data as a dictionary."""
    with open(file_path, 'r') as file:
        reader = csv.DictReader(file, delimiter='\t')
        for row in reader:
            return row  # Since each file contains a single line of data

def collect_benchmarks(file_list):
    """Collect all benchmark files from a list and return their parsed contents."""
    benchmark_data = []
    for file_path in file_list:
        data = parse_benchmark_file(file_path)
        data['rule'] = os.path.basename(file_path).rsplit('.benchmark')[0]
        benchmark_data.append(data)
    return benchmark_data

def filter_benchmarks(benchmark_data, exclude_keywords):
    """Exclude benchmark files containing specific keywords in their file names."""
    return [data for data in benchmark_data if not any(keyword in data['rule'] for keyword in exclude_keywords)]

def summarize_benchmarks(benchmark_data):
    """Summarize the memory and time usage across all benchmarks."""
    df = pd.DataFrame(benchmark_data)
    for col in ['max_rss', 'mean_load', 'cpu_time', 's']:
        df[col] = pd.to_numeric(df[col], errors='coerce')

    total_time_seconds = df['s'].astype(float).sum()
    minutes = int(total_time_seconds // 60)
    seconds = int(total_time_seconds % 60)

    summary = {
        'total_time': f"{minutes}m {seconds}s",
        'max_memory_rss_gb': round(df['max_rss'].max() / 1024.0, 2),
        'max_cpu_utilization_cores': round(df['mean_load'].max() / 1000.0, 2)
    }
    return summary

def write_benchmark_csv(output_file, benchmark_data):
    """Write benchmark data to a CSV file."""
    # Define the order of columns
    column_order = [
        'rule', 's', 'h:m:s', 'max_rss', 'max_vms', 'max_uss', 'max_pss', 'io_in', 'io_out', 'mean_load', 'cpu_time'
    ]
    all_columns = [key for key in column_order if key in benchmark_data[0]]  # Ensure only valid keys are included

    with open(output_file, 'w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=all_columns)
        writer.writeheader()
        for data in benchmark_data:
            filtered_data = {key: data.get(key, '') for key in all_columns}  # Ensure data matches column order
            writer.writerow(filtered_data)

def write_summary_csv(summary_file, summary):
    """Write summary data to a CSV file."""
    with open(summary_file, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(["Metric", "Value"])
        for key, value in summary.items():
            writer.writerow([key, value])

def main(args):
    # collect benchmark data
    benchmark_data = collect_benchmarks(args.file_list)
    write_benchmark_csv(args.benchmarks_csv, benchmark_data)
    # filter and summarize benchmark data
    filtered_data = filter_benchmarks(benchmark_data, args.exclude)

    filtered_summary = summarize_benchmarks(filtered_data)
    write_summary_csv(args.summary_csv, filtered_summary)

    full_summary = summarize_benchmarks(benchmark_data)
    print("Workflow, including downloads and untar:")
    for key, value in full_summary.items():
        print(f"  {key}: {value}")
    print("\nWorkflow, excluding downloads:")
    for key, value in filtered_summary.items():
        print(f"  {key}: {value}")

if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Collect and summarize benchmark files.")
    p.add_argument("file_list", nargs='+', help="List of .benchmark files")
    p.add_argument("--benchmarks-csv", help="Output CSV file for benchmark data")
    p.add_argument("--summary-csv", help="Output CSV file for summary data")
    p.add_argument("--exclude", nargs='*', default=["download_database", "download_challenge_dataset"], help="Keywords to exclude certain benchmark files from summary")
    args = p.parse_args()
    main(args)
