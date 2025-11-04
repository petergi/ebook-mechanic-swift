#!/usr/bin/env python3
"""
Empty Ebook Folder Cleaner
Scans directories and deletes folders that don't contain any ebook files (EPUB, MOBI, PDF).
"""

import argparse
import os
import shutil
import sys
from datetime import datetime
from pathlib import Path
from typing import List, Set


class EmptyFolderCleaner:
    def __init__(self, root_dir: str, ebook_extensions: Set[str] = None):
        self.root_dir = Path(root_dir).resolve()
        self.ebook_extensions = ebook_extensions or {".epub", ".mobi", ".pdf"}
        self.folders_to_delete = []
        self.folders_with_ebooks = set()
        self.total_folders_scanned = 0

    def has_ebooks(self, directory: Path) -> bool:
        """
        Check if a directory or any of its subdirectories contain ebook files.
        """
        try:
            for root, dirs, files in os.walk(directory):
                for file in files:
                    if Path(file).suffix.lower() in self.ebook_extensions:
                        return True
            return False
        except PermissionError:
            print(f"  Warning: Permission denied accessing {directory}")
            return True  # Don't delete if we can't check

    def scan_directory(self):
        """
        Scan the directory tree and identify folders without ebooks.
        Uses bottom-up traversal to handle nested empty folders correctly.
        """
        print(f"Scanning directory: {self.root_dir}")
        print("=" * 70)

        # Get all directories in a bottom-up order (deepest first)
        all_dirs = []
        for root, dirs, files in os.walk(self.root_dir, topdown=False):
            for dir_name in dirs:
                dir_path = Path(root) / dir_name
                all_dirs.append(dir_path)
                self.total_folders_scanned += 1

        print(f"Found {self.total_folders_scanned} folders to check\n")

        # Check each directory
        for dir_path in all_dirs:
            try:
                # Get relative path for display
                try:
                    rel_path = dir_path.relative_to(self.root_dir)
                except ValueError:
                    rel_path = dir_path

                print(f"Checking: {rel_path}")

                # Check if directory has any ebooks
                if self.has_ebooks(dir_path):
                    print(f"  ✓ Contains ebooks")
                    self.folders_with_ebooks.add(dir_path)
                else:
                    # Check if it's empty or only has non-ebook files
                    contents = list(dir_path.iterdir())
                    if len(contents) == 0:
                        print(f"  ✗ Empty folder")
                    else:
                        print(f"  ✗ No ebooks (has {len(contents)} non-ebook items)")
                    self.folders_to_delete.append(dir_path)

            except PermissionError:
                print(f"  Warning: Permission denied")
            except Exception as e:
                print(f"  Error: {e}")

    def delete_folders(self, confirm: bool = True):
        """Delete all folders that don't contain ebooks."""
        if not self.folders_to_delete:
            print("\nNo empty folders found. Nothing to delete.")
            return

        print(f"\n{'=' * 70}")
        print(f"Found {len(self.folders_to_delete)} folders without ebooks")
        print(f"{'=' * 70}\n")

        if confirm:
            print("Folders to be deleted:")
            for folder in self.folders_to_delete[:10]:  # Show first 10
                try:
                    rel_path = folder.relative_to(self.root_dir)
                except ValueError:
                    rel_path = folder
                print(f"  - {rel_path}")

            if len(self.folders_to_delete) > 10:
                print(f"  ... and {len(self.folders_to_delete) - 10} more")

            print()
            response = input("Proceed with deletion? (yes/no): ").strip().lower()
            if response not in ["yes", "y"]:
                print("Deletion cancelled.")
                return

        print("\nDeleting folders...")
        print("=" * 70)

        deleted_count = 0
        error_count = 0

        for folder in self.folders_to_delete:
            try:
                rel_path = folder.relative_to(self.root_dir)
            except ValueError:
                rel_path = folder

            try:
                if folder.exists():
                    shutil.rmtree(folder)
                    print(f"Deleted: {rel_path}")
                    deleted_count += 1
                else:
                    print(f"Already deleted: {rel_path}")
            except PermissionError:
                print(f"Permission denied: {rel_path}")
                error_count += 1
            except Exception as e:
                print(f"Error deleting {rel_path}: {e}")
                error_count += 1

        print(f"\nDeleted: {deleted_count} folders")
        if error_count > 0:
            print(f"Errors: {error_count} folders could not be deleted")

    def generate_report(self):
        """Generate a detailed report of the scan."""
        timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        report_file = self.root_dir / f"empty_folders_report_{timestamp}.txt"

        with open(report_file, "w", encoding="utf-8") as f:
            f.write("=" * 70 + "\n")
            f.write("EMPTY EBOOK FOLDERS REPORT\n")
            f.write("=" * 70 + "\n")
            f.write(f"Scan Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Root Directory: {self.root_dir}\n")
            f.write("\n")

            f.write("SUMMARY\n")
            f.write("-" * 70 + "\n")
            f.write(f"Total folders scanned: {self.total_folders_scanned}\n")
            f.write(f"Folders with ebooks: {len(self.folders_with_ebooks)}\n")
            f.write(f"Folders without ebooks: {len(self.folders_to_delete)}\n")
            f.write("\n")

            if self.folders_to_delete:
                f.write("FOLDERS WITHOUT EBOOKS\n")
                f.write("=" * 70 + "\n")

                # Sort by path for easier reading
                sorted_folders = sorted(self.folders_to_delete)

                for folder in sorted_folders:
                    try:
                        rel_path = folder.relative_to(self.root_dir)
                    except ValueError:
                        rel_path = folder

                    f.write(f"\n{rel_path}\n")

                    # Show what's in the folder
                    if folder.exists():
                        try:
                            contents = list(folder.iterdir())
                            if contents:
                                f.write(f"  Contents ({len(contents)} items):\n")
                                for item in contents[:5]:  # Show first 5 items
                                    item_type = "DIR" if item.is_dir() else "FILE"
                                    f.write(f"    [{item_type}] {item.name}\n")
                                if len(contents) > 5:
                                    f.write(f"    ... and {len(contents) - 5} more items\n")
                            else:
                                f.write("  (Empty folder)\n")
                        except Exception as e:
                            f.write(f"  Error reading contents: {e}\n")
            else:
                f.write("\nNo folders without ebooks found!\n")

            f.write("\n" + "=" * 70 + "\n")
            f.write("END OF REPORT\n")
            f.write("=" * 70 + "\n")

        print(f"\nReport saved to: {report_file}")
        return report_file

    def print_summary(self):
        """Print a summary to console."""
        print("\n" + "=" * 70)
        print("SCAN SUMMARY")
        print("=" * 70)
        print(f"Total folders scanned: {self.total_folders_scanned}")
        print(f"Folders with ebooks: {len(self.folders_with_ebooks)}")
        print(f"Folders without ebooks: {len(self.folders_to_delete)}")


def main():
    parser = argparse.ArgumentParser(
        description="Delete folders that don't contain any ebook files (EPUB, MOBI, PDF)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Scan current directory with confirmation prompt
  python delete_empty_ebook_folders.py

  # Scan specific directory
  python delete_empty_ebook_folders.py /path/to/ebooks

  # Dry run (scan only, don't delete)
  python delete_empty_ebook_folders.py --dry-run

  # Delete without confirmation
  python delete_empty_ebook_folders.py --no-confirm

  # Custom file extensions
  python delete_empty_ebook_folders.py --extensions .epub .pdf .azw3
        """,
    )

    parser.add_argument(
        "directory",
        nargs="?",
        default=".",
        help="Root directory to scan (default: current directory)",
    )

    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Scan folders but do not delete them",
    )

    parser.add_argument(
        "--no-confirm",
        action="store_true",
        help="Delete without confirmation prompt",
    )

    parser.add_argument(
        "--extensions",
        nargs="+",
        default=[".epub", ".mobi", ".pdf"],
        help="File extensions to consider as ebooks (default: .epub .mobi .pdf)",
    )

    parser.add_argument(
        "--no-report",
        action="store_true",
        help="Do not generate a report file",
    )

    args = parser.parse_args()

    # Validate directory
    root_dir = Path(args.directory).resolve()
    if not root_dir.exists():
        print(f"Error: Directory '{root_dir}' does not exist.")
        sys.exit(1)

    if not root_dir.is_dir():
        print(f"Error: '{root_dir}' is not a directory.")
        sys.exit(1)

    # Normalize extensions
    extensions = {ext if ext.startswith(".") else f".{ext}" for ext in args.extensions}
    extensions = {ext.lower() for ext in extensions}

    print(f"Looking for folders without these file types: {', '.join(sorted(extensions))}\n")

    # Run the cleaner
    cleaner = EmptyFolderCleaner(root_dir, extensions)

    # Scan
    cleaner.scan_directory()

    # Generate report (before deletion)
    if not args.no_report:
        cleaner.generate_report()

    # Delete folders
    if not args.dry_run:
        cleaner.delete_folders(confirm=not args.no_confirm)
    else:
        print("\n[DRY RUN] Skipping folder deletion.")

    # Print summary
    cleaner.print_summary()

    print("\nDone!")


if __name__ == "__main__":
    main()
