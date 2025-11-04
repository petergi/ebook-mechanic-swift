import os
import shutil
import glob
import datetime

def find_corrupted_ebooks(root_dir, corrupted_folder="CORRUPTED"):
    """
    Searches for potentially corrupted ebooks in a directory and moves them to a designated folder.

    Args:
        root_dir (str): The root directory to search in.
        corrupted_folder (str): The name of the folder to move corrupted ebooks to.
    """

    ebook_extensions = ['.epub', '.mobi', '.pdf', '.azw3']  # Add more if needed
    min_file_size_kb = 50 # Minimum file size in KB.  Adjust as needed
    max_file_size_mb = 100 # Maximum file size in MB. Adjust as needed

    corrupted_files = []
    total_files_checked = 0

    # Create the corrupted folder if it doesn't exist
    if not os.path.exists(corrupted_folder):
        os.makedirs(corrupted_folder)

    for ext in ebook_extensions:
        search_pattern = os.path.join(root_dir, '**/*' + ext)
        for filepath in glob.glob(search_pattern, recursive=True):
            total_files_checked += 1
            try:
                file_size_kb = os.path.getsize(filepath) / 1024
                if file_size_kb < min_file_size_kb or file_size_kb > (max_file_size_mb * 1024):
                    print(f"Moving potentially corrupted file: {filepath}")
                    shutil.move(filepath, os.path.join(corrupted_folder, os.path.basename(filepath)))
                    corrupted_files.append(filepath)
            except Exception as e:
                print(f"Error processing {filepath}: {e}")

    return corrupted_files


def generate_markdown_report(corrupted_files, report_filename="corruption_report.md"):
    """Generates a markdown report listing the corrupted files."""

    with open(report_filename, "w") as f:
        f.write("# Ebook Corruption Report\n\n")
        f.write(f"Report generated on: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        f.write("## Corrupted Files:\n\n")

        if not corrupted_files:
            f.write("No corrupted files found.\n")
        else:
            for filepath in corrupted_files:
                f.write(f"- `{filepath}`\n")

    print(f"Report generated: {report_filename}")


if __name__ == "__main__":
    root_directory = input("Enter the root directory to search: ")  # Get user input
    corrupted_folder_name = "CORRUPTED" # You can change this if desired

    corrupted_files_list = find_corrupted_ebooks(root_directory, corrupted_folder_name)
    generate_markdown_report(corrupted_files_list)
