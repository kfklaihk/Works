import argparse
import os
import tempfile

from parse_mappings_colab_10 import extract_zip, run_analysis


def parse_args():
    parser = argparse.ArgumentParser(
        description="Run SQL mapping analysis on desktop."
    )
    parser.add_argument(
        "--mappings",
        required=True,
        help="Path to mappings.json"
    )
    parser.add_argument(
        "--zip",
        required=True,
        help="Path to SQL zip file"
    )
    parser.add_argument(
        "--output",
        default="mapping_results.csv",
        help="Output CSV path (default: mapping_results.csv)"
    )
    parser.add_argument(
        "--max-passes",
        type=int,
        default=6,
        help="Per-file parse passes (default: 6)"
    )
    parser.add_argument(
        "--extract-dir",
        default="",
        help="Optional extract directory (default: temp dir)"
    )
    return parser.parse_args()


def main():
    args = parse_args()
    mappings_path = os.path.abspath(args.mappings)
    zip_path = os.path.abspath(args.zip)
    output_path = os.path.abspath(args.output)

    if not os.path.isfile(mappings_path):
        raise FileNotFoundError(f"Mappings not found: {mappings_path}")
    if not os.path.isfile(zip_path):
        raise FileNotFoundError(f"ZIP not found: {zip_path}")

    if args.extract_dir:
        extract_path = os.path.abspath(args.extract_dir)
    else:
        extract_path = os.path.join(
            tempfile.mkdtemp(prefix="sql_run_"), "sql_files"
        )

    extract_zip(zip_path, extract_path)
    run_analysis(
        mappings_path,
        extract_path,
        output_path,
        max_passes=args.max_passes,
    )

    print(f"✅ Results: {output_path}")


if __name__ == "__main__":
    main()
