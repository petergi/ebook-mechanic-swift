#!/usr/bin/env python3
"""
Ebook Corruption Checker
Scans directories for corrupted EPUB, MOBI, and PDF files.
Moves corrupted files to a CORRUPTED directory and generates a report.
"""

import argparse
import os
import shutil
import sys
import zipfile
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple


class EbookCorruptionChecker:
    def __init__(self, root_dir: str, corrupted_dir: str = "CORRUPTED"):
        self.root_dir = Path(root_dir).resolve()
        self.corrupted_dir = self.root_dir / corrupted_dir
        self.results = {
            "epub": {"total": 0, "corrupted": []},
            "mobi": {"total": 0, "corrupted": []},
            "pdf": {"total": 0, "corrupted": []},
        }

    def check_epub(self, file_path: Path) -> Tuple[bool, str]:
        """
        Check if an EPUB file is corrupted.
        EPUBs are ZIP files with specific structure.
        """
        try:
            # EPUBs must be valid ZIP files
            if not zipfile.is_zipfile(file_path):
                return False, "Not a valid ZIP file"

            with zipfile.ZipFile(file_path, "r") as zip_file:
                # Check for corrupt ZIP
                corrupt = zip_file.testzip()
                if corrupt:
                    return False, f"Corrupted ZIP entry: {corrupt}"

                # EPUB must contain mimetype file as first entry
                if "mimetype" not in zip_file.namelist():
                    return False, "Missing mimetype file"

                # Check mimetype content
                mimetype = zip_file.read("mimetype").decode("utf-8").strip()
                if mimetype != "application/epub+zip":
                    return False, f"Invalid mimetype: {mimetype}"

                # Check for META-INF/container.xml
                if "META-INF/container.xml" not in zip_file.namelist():
                    return False, "Missing META-INF/container.xml"

            return True, "Valid EPUB"

        except zipfile.BadZipFile:
            return False, "Bad ZIP file"
        except Exception as e:
            return False, f"Error: {str(e)}"

    def check_mobi(self, file_path: Path) -> Tuple[bool, str]:
        """
        Check if a MOBI file is corrupted.
        MOBI files have specific header structure.
        """
        try:
            with open(file_path, "rb") as f:
                # Read first few bytes
                header = f.read(68)

                if len(header) < 68:
                    return False, "File too small"

                # Check for valid MOBI identifier at offset 60
                # Valid identifiers: BOOKMOBI, TEXtREAd
                identifier = header[60:68].decode("latin-1", errors="ignore")

                if not (
                    identifier.startswith("BOOKMOBI")
                    or identifier.startswith("TEXtREAd")
                ):
                    return False, f"Invalid MOBI identifier: {identifier}"

                # Check PalmDB name (first 32 bytes should not be all zeros)
                name = header[0:32]
                if name == b"\x00" * 32:
                    return False, "Invalid PalmDB header"

            return True, "Valid MOBI"

        except Exception as e:
            return False, f"Error: {str(e)}"

    def check_pdf(self, file_path: Path) -> Tuple[bool, str]:
        """
        Check if a PDF file is corrupted.
        Basic validation of PDF structure.
        """
        try:
            with open(file_path, "rb") as f:
                # Check PDF header
                header = f.read(5)
                if not header.startswith(b"%PDF-"):
                    return False, "Missing PDF header"

                # Check file has content beyond header
                f.seek(0, 2)  # Seek to end
                size = f.tell()
                if size < 100:  # Arbitrary minimum size
                    return False, "File too small to be valid PDF"

                # Try to find EOF marker
                f.seek(max(0, size - 1024))  # Check last 1KB
                tail = f.read()
                if b"%%EOF" not in tail:
                    return False, "Missing %%EOF marker"

            return True, "Valid PDF"

        except Exception as e:
            return False, f"Error: {str(e)}"

    def check_file(self, file_path: Path) -> Tuple[bool, str]:
        """Check if a file is corrupted based on its extension."""
        ext = file_path.suffix.lower()

        if ext == ".epub":
            return self.check_epub(file_path)
        elif ext == ".mobi":
            return self.check_mobi(file_path)
        elif ext == ".pdf":
            return self.check_pdf(file_path)
        else:
            return True, "Unknown file type"

    def scan_directory(self):
        """Scan the directory tree for ebook files."""
        extensions = {".epub", ".mobi", ".pdf"}

        print(f"Scanning directory: {self.root_dir}")
        print("=" * 70)

        for root, dirs, files in os.walk(self.root_dir):
            # Skip the CORRUPTED directory itself
            if self.corrupted_dir.name in dirs:
                dirs.remove(self.corrupted_dir.name)

            for file in files:
                file_path = Path(root) / file
                ext = file_path.suffix.lower()

                if ext in extensions:
                    file_type = ext[1:]  # Remove the dot
                    self.results[file_type]["total"] += 1

                    print(f"Checking: {file_path.relative_to(self.root_dir)}")

                    is_valid, message = self.check_file(file_path)

                    if not is_valid:
                        print(f"  ✗ CORRUPTED: {message}")
                        self.results[file_type]["corrupted"].append(
                            {
                                "path": file_path,
                                "reason": message,
                                "size": file_path.stat().st_size,
                            }
                        )
                    else:
                        print(f"  ✓ OK")

    def move_corrupted_files(self):
        """Move all corrupted files to the CORRUPTED directory."""
        if not any(self.results[ft]["corrupted"] for ft in self.results):
            print("\nNo corrupted files found. Nothing to move.")
            return

        # Create CORRUPTED directory if it doesn't exist
        self.corrupted_dir.mkdir(exist_ok=True)

        print(f"\nMoving corrupted files to: {self.corrupted_dir}")
        print("=" * 70)

        for file_type in self.results:
            for item in self.results[file_type]["corrupted"]:
                src_path = item["path"]

                # Preserve directory structure within CORRUPTED
                rel_path = src_path.relative_to(self.root_dir)
                dest_path = self.corrupted_dir / rel_path

                # Create subdirectories if needed
                dest_path.parent.mkdir(parents=True, exist_ok=True)

                try:
                    shutil.move(str(src_path), str(dest_path))
                    print(f"Moved: {rel_path}")
                    item["moved_to"] = dest_path
                except Exception as e:
                    print(f"Error moving {src_path}: {e}")
                    item["move_error"] = str(e)

    def generate_report(self):
        """Generate a detailed report of the scan."""
        timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        report_file = self.root_dir / f"corruption_report_{timestamp}.txt"

        total_files = sum(self.results[ft]["total"] for ft in self.results)
        total_corrupted = sum(len(self.results[ft]["corrupted"]) for ft in self.results)

        with open(report_file, "w", encoding="utf-8") as f:
            f.write("=" * 70 + "\n")
            f.write("EBOOK CORRUPTION SCAN REPORT\n")
            f.write("=" * 70 + "\n")
            f.write(f"Scan Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Root Directory: {self.root_dir}\n")
            f.write(f"Corrupted Files Directory: {self.corrupted_dir}\n")
            f.write("\n")

            f.write("SUMMARY\n")
            f.write("-" * 70 + "\n")
            f.write(f"Total files scanned: {total_files}\n")
            f.write(f"Total corrupted files: {total_corrupted}\n")
            f.write("\n")

            for file_type in ["epub", "mobi", "pdf"]:
                total = self.results[file_type]["total"]
                corrupted = len(self.results[file_type]["corrupted"])
                f.write(f"{file_type.upper()}: {corrupted}/{total} corrupted\n")

            f.write("\n")

            if total_corrupted > 0:
                f.write("CORRUPTED FILES DETAILS\n")
                f.write("=" * 70 + "\n")

                for file_type in ["epub", "mobi", "pdf"]:
                    if self.results[file_type]["corrupted"]:
                        f.write(f"\n{file_type.upper()} Files:\n")
                        f.write("-" * 70 + "\n")

                        for item in self.results[file_type]["corrupted"]:
                            f.write(
                                f"\nFile: {item['path'].relative_to(self.root_dir)}\n"
                            )
                            f.write(f"  Size: {item['size']:,} bytes\n")
                            f.write(f"  Reason: {item['reason']}\n")
                            if "moved_to" in item:
                                f.write(
                                    f"  Moved to: {item['moved_to'].relative_to(self.root_dir)}\n"
                                )
                            if "move_error" in item:
                                f.write(f"  Move error: {item['move_error']}\n")
            else:
                f.write("\nNo corrupted files found!\n")

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

        total_files = sum(self.results[ft]["total"] for ft in self.results)
        total_corrupted = sum(len(self.results[ft]["corrupted"]) for ft in self.results)

        print(f"Total files scanned: {total_files}")
        print(f"Total corrupted files: {total_corrupted}")
        print()

        for file_type in ["epub", "mobi", "pdf"]:
            total = self.results[file_type]["total"]
            corrupted = len(self.results[file_type]["corrupted"])
            print(f"{file_type.upper()}: {corrupted}/{total} corrupted")


def main():
    parser = argparse.ArgumentParser(
        description="Scan directories for corrupted ebook files (EPUB, MOBI, PDF)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Scan current directory
  python check_corrupted_ebooks.py

  # Scan specific directory
  python check_corrupted_ebooks.py /path/to/ebooks

  # Specify custom corrupted files directory name
  python check_corrupted_ebooks.py --corrupted-dir BAD_FILES

  # Dry run (scan only, don't move files)
  python check_corrupted_ebooks.py --dry-run
        """,
    )

    parser.add_argument(
        "directory",
        nargs="?",
        default=".",
        help="Root directory to scan (default: current directory)",
    )

    parser.add_argument(
        "--corrupted-dir",
        default="CORRUPTED",
        help="Name of directory to move corrupted files to (default: CORRUPTED)",
    )

    parser.add_argument(
        "--dry-run", action="store_true", help="Scan files but do not move them"
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

    # Run the checker
    checker = EbookCorruptionChecker(root_dir, args.corrupted_dir)

    # Scan
    checker.scan_directory()

    # Move files (unless dry run)
    if not args.dry_run:
        checker.move_corrupted_files()
    else:
        print("\n[DRY RUN] Skipping file moves.")

    # Generate report
    checker.generate_report()

    # Print summary
    checker.print_summary()

    print("\nDone!")


if __name__ == "__main__":
    main()
