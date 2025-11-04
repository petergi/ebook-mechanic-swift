#!/usr/bin/env python3
"""
Ebook Library Manager with TUI
Comprehensive tool for managing ebook libraries:
- Detect and move corrupted ebook files (EPUB, MOBI, PDF)
- Delete folders that don't contain any ebooks
- Generate detailed Markdown reports
- Beautiful TUI with progress tracking
"""

import argparse
import os
import shutil
import sys
import zipfile
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Set, Tuple

try:
    from rich.console import Console
    from rich.progress import (
        Progress,
        SpinnerColumn,
        BarColumn,
        TextColumn,
        TimeElapsedColumn,
        MofNCompleteColumn,
    )
    from rich.panel import Panel
    from rich.table import Table
    from rich.live import Live
    from rich.layout import Layout
    from rich.text import Text
    from rich import box
    RICH_AVAILABLE = True
except ImportError:
    RICH_AVAILABLE = False


class EbookManager:
    def __init__(self, root_dir: str, corrupted_dir: str = "CORRUPTED", use_tui: bool = True):
        self.root_dir = Path(root_dir).resolve()
        self.corrupted_dir = self.root_dir / corrupted_dir
        self.ebook_extensions = {".epub", ".mobi", ".pdf"}
        self.use_tui = use_tui and RICH_AVAILABLE

        if self.use_tui:
            self.console = Console()

        # Corruption checker results
        self.corruption_results = {
            "epub": {"total": 0, "corrupted": []},
            "mobi": {"total": 0, "corrupted": []},
            "pdf": {"total": 0, "corrupted": []},
        }

        # Empty folder cleaner results
        self.folders_to_delete = []
        self.folders_with_ebooks = set()
        self.total_folders_scanned = 0

        # Stats for TUI
        self.current_file = ""
        self.current_folder = ""
        self.files_checked = 0
        self.folders_checked = 0

    # ========================================================================
    # TUI HELPER METHODS
    # ========================================================================

    def print_message(self, message: str, style: str = ""):
        """Print message with or without TUI."""
        if self.use_tui:
            self.console.print(message, style=style)
        else:
            print(message)

    def create_stats_table(self) -> Table:
        """Create statistics table for TUI."""
        table = Table(box=box.ROUNDED, show_header=False, border_style="cyan")
        table.add_column("Metric", style="bold cyan")
        table.add_column("Value", style="bold white")

        total_files = sum(self.corruption_results[ft]["total"] for ft in self.corruption_results)
        total_corrupted = sum(len(self.corruption_results[ft]["corrupted"]) for ft in self.corruption_results)

        table.add_row("📚 Files Scanned", str(total_files))
        table.add_row("❌ Corrupted Files", str(total_corrupted))
        table.add_row("📁 Folders Scanned", str(self.total_folders_scanned))
        table.add_row("🗑️  Empty Folders", str(len(self.folders_to_delete)))

        return table

    def create_file_type_table(self) -> Table:
        """Create file type breakdown table."""
        table = Table(title="File Type Breakdown", box=box.ROUNDED, border_style="blue")
        table.add_column("Type", style="bold")
        table.add_column("Total", justify="right")
        table.add_column("Corrupted", justify="right")
        table.add_column("Status", justify="center")

        for file_type in ["epub", "mobi", "pdf"]:
            total = self.corruption_results[file_type]["total"]
            corrupted = len(self.corruption_results[file_type]["corrupted"])
            status = "❌" if corrupted > 0 else "✅"

            table.add_row(
                file_type.upper(),
                str(total),
                str(corrupted),
                status
            )

        return table

    # ========================================================================
    # CORRUPTION DETECTION METHODS
    # ========================================================================

    def check_epub(self, file_path: Path) -> Tuple[bool, str]:
        """Check if an EPUB file is corrupted."""
        try:
            if not zipfile.is_zipfile(file_path):
                return False, "Not a valid ZIP file"

            with zipfile.ZipFile(file_path, "r") as zip_file:
                corrupt = zip_file.testzip()
                if corrupt:
                    return False, f"Corrupted ZIP entry: {corrupt}"

                if "mimetype" not in zip_file.namelist():
                    return False, "Missing mimetype file"

                mimetype = zip_file.read("mimetype").decode("utf-8").strip()
                if mimetype != "application/epub+zip":
                    return False, f"Invalid mimetype: {mimetype}"

                if "META-INF/container.xml" not in zip_file.namelist():
                    return False, "Missing META-INF/container.xml"

            return True, "Valid EPUB"

        except zipfile.BadZipFile:
            return False, "Bad ZIP file"
        except Exception as e:
            return False, f"Error: {str(e)}"

    def check_mobi(self, file_path: Path) -> Tuple[bool, str]:
        """Check if a MOBI file is corrupted."""
        try:
            with open(file_path, "rb") as f:
                header = f.read(68)

                if len(header) < 68:
                    return False, "File too small"

                identifier = header[60:68].decode("latin-1", errors="ignore")

                if not (
                    identifier.startswith("BOOKMOBI")
                    or identifier.startswith("TEXtREAd")
                ):
                    return False, f"Invalid MOBI identifier: {identifier}"

                name = header[0:32]
                if name == b"\x00" * 32:
                    return False, "Invalid PalmDB header"

            return True, "Valid MOBI"

        except Exception as e:
            return False, f"Error: {str(e)}"

    def check_pdf(self, file_path: Path) -> Tuple[bool, str]:
        """Check if a PDF file is corrupted."""
        try:
            with open(file_path, "rb") as f:
                header = f.read(5)
                if not header.startswith(b"%PDF-"):
                    return False, "Missing PDF header"

                f.seek(0, 2)
                size = f.tell()
                if size < 100:
                    return False, "File too small to be valid PDF"

                f.seek(max(0, size - 1024))
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

    def scan_for_corruption(self):
        """Scan the directory tree for corrupted ebook files."""
        if not self.use_tui:
            self._scan_for_corruption_simple()
            return

        # TUI version with progress
        self.console.print("\n")
        self.console.print(Panel.fit(
            "[bold cyan]🔍 Scanning for Corrupted Ebooks[/bold cyan]",
            border_style="cyan"
        ))

        # First, count all files
        all_files = []
        for root, dirs, files in os.walk(self.root_dir):
            if self.corrupted_dir.name in dirs:
                dirs.remove(self.corrupted_dir.name)

            for file in files:
                file_path = Path(root) / file
                if file_path.suffix.lower() in self.ebook_extensions:
                    all_files.append(file_path)

        if not all_files:
            self.console.print("[yellow]No ebook files found![/yellow]")
            return

        # Scan with progress bar
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            MofNCompleteColumn(),
            TextColumn("•"),
            TimeElapsedColumn(),
            console=self.console
        ) as progress:

            task = progress.add_task("[cyan]Checking files...", total=len(all_files))

            for file_path in all_files:
                ext = file_path.suffix.lower()
                file_type = ext[1:]

                self.corruption_results[file_type]["total"] += 1

                # Update progress description
                rel_path = file_path.relative_to(self.root_dir)
                progress.update(task, description=f"[cyan]Checking: {rel_path.name}")

                is_valid, message = self.check_file(file_path)

                if not is_valid:
                    self.corruption_results[file_type]["corrupted"].append({
                        "path": file_path,
                        "reason": message,
                        "size": file_path.stat().st_size,
                    })

                progress.advance(task)

        # Show results
        total_corrupted = sum(
            len(self.corruption_results[ft]["corrupted"])
            for ft in self.corruption_results
        )

        if total_corrupted > 0:
            self.console.print(f"\n[bold red]Found {total_corrupted} corrupted file(s)![/bold red]")
        else:
            self.console.print("\n[bold green]✅ All files are valid![/bold green]")

    def _scan_for_corruption_simple(self):
        """Simple text-based scanning without TUI."""
        print("\n" + "=" * 70)
        print("SCANNING FOR CORRUPTED EBOOKS")
        print("=" * 70)
        print(f"Directory: {self.root_dir}\n")

        for root, dirs, files in os.walk(self.root_dir):
            if self.corrupted_dir.name in dirs:
                dirs.remove(self.corrupted_dir.name)

            for file in files:
                file_path = Path(root) / file
                ext = file_path.suffix.lower()

                if ext in self.ebook_extensions:
                    file_type = ext[1:]
                    self.corruption_results[file_type]["total"] += 1

                    print(f"Checking: {file_path.relative_to(self.root_dir)}")

                    is_valid, message = self.check_file(file_path)

                    if not is_valid:
                        print(f"  ✗ CORRUPTED: {message}")
                        self.corruption_results[file_type]["corrupted"].append({
                            "path": file_path,
                            "reason": message,
                            "size": file_path.stat().st_size,
                        })
                    else:
                        print(f"  ✓ OK")

    def move_corrupted_files(self):
        """Move all corrupted files to the CORRUPTED directory."""
        total_corrupted = sum(
            len(self.corruption_results[ft]["corrupted"])
            for ft in self.corruption_results
        )

        if total_corrupted == 0:
            self.print_message("\n[yellow]No corrupted files to move.[/yellow]" if self.use_tui else "\nNo corrupted files to move.")
            return

        self.corrupted_dir.mkdir(exist_ok=True)

        if self.use_tui:
            self.console.print("\n")
            self.console.print(Panel.fit(
                "[bold yellow]📦 Moving Corrupted Files[/bold yellow]",
                border_style="yellow"
            ))

            all_corrupted = []
            for file_type in self.corruption_results:
                all_corrupted.extend(self.corruption_results[file_type]["corrupted"])

            with Progress(
                SpinnerColumn(),
                TextColumn("[progress.description]{task.description}"),
                BarColumn(),
                MofNCompleteColumn(),
                console=self.console
            ) as progress:

                task = progress.add_task("[yellow]Moving files...", total=len(all_corrupted))

                for item in all_corrupted:
                    src_path = item["path"]
                    rel_path = src_path.relative_to(self.root_dir)
                    dest_path = self.corrupted_dir / rel_path

                    progress.update(task, description=f"[yellow]Moving: {rel_path.name}")

                    dest_path.parent.mkdir(parents=True, exist_ok=True)

                    try:
                        shutil.move(str(src_path), str(dest_path))
                        item["moved_to"] = dest_path
                    except Exception as e:
                        item["move_error"] = str(e)

                    progress.advance(task)

            self.console.print(f"[bold green]✅ Moved {len(all_corrupted)} file(s) to {self.corrupted_dir.name}[/bold green]")

        else:
            print("\n" + "=" * 70)
            print("MOVING CORRUPTED FILES")
            print("=" * 70)
            print(f"Destination: {self.corrupted_dir}\n")

            for file_type in self.corruption_results:
                for item in self.corruption_results[file_type]["corrupted"]:
                    src_path = item["path"]
                    rel_path = src_path.relative_to(self.root_dir)
                    dest_path = self.corrupted_dir / rel_path

                    dest_path.parent.mkdir(parents=True, exist_ok=True)

                    try:
                        shutil.move(str(src_path), str(dest_path))
                        print(f"Moved: {rel_path}")
                        item["moved_to"] = dest_path
                    except Exception as e:
                        print(f"Error moving {src_path}: {e}")
                        item["move_error"] = str(e)

    # ========================================================================
    # EMPTY FOLDER DETECTION METHODS
    # ========================================================================

    def has_ebooks(self, directory: Path) -> bool:
        """Check if a directory or any subdirectories contain ebook files."""
        try:
            for root, dirs, files in os.walk(directory):
                for file in files:
                    if Path(file).suffix.lower() in self.ebook_extensions:
                        return True
            return False
        except PermissionError:
            return True

    def scan_for_empty_folders(self):
        """Scan the directory tree and identify folders without ebooks."""
        if not self.use_tui:
            self._scan_for_empty_folders_simple()
            return

        # TUI version
        self.console.print("\n")
        self.console.print(Panel.fit(
            "[bold magenta]📁 Scanning for Empty Folders[/bold magenta]",
            border_style="magenta"
        ))

        # Get all directories
        all_dirs = []
        for root, dirs, files in os.walk(self.root_dir, topdown=False):
            if self.corrupted_dir.name in dirs:
                dirs.remove(self.corrupted_dir.name)

            for dir_name in dirs:
                dir_path = Path(root) / dir_name
                if dir_path == self.corrupted_dir:
                    continue
                all_dirs.append(dir_path)
                self.total_folders_scanned += 1

        if not all_dirs:
            self.console.print("[yellow]No folders found![/yellow]")
            return

        # Scan with progress
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            MofNCompleteColumn(),
            TextColumn("•"),
            TimeElapsedColumn(),
            console=self.console
        ) as progress:

            task = progress.add_task("[magenta]Checking folders...", total=len(all_dirs))

            for dir_path in all_dirs:
                try:
                    rel_path = dir_path.relative_to(self.root_dir)
                    progress.update(task, description=f"[magenta]Checking: {rel_path.name}")

                    if self.has_ebooks(dir_path):
                        self.folders_with_ebooks.add(dir_path)
                    else:
                        self.folders_to_delete.append(dir_path)

                except Exception:
                    pass

                progress.advance(task)

        if self.folders_to_delete:
            self.console.print(f"\n[bold yellow]Found {len(self.folders_to_delete)} empty folder(s)![/bold yellow]")
        else:
            self.console.print("\n[bold green]✅ No empty folders found![/bold green]")

    def _scan_for_empty_folders_simple(self):
        """Simple text-based folder scanning."""
        print("\n" + "=" * 70)
        print("SCANNING FOR EMPTY FOLDERS")
        print("=" * 70)
        print(f"Directory: {self.root_dir}\n")

        all_dirs = []
        for root, dirs, files in os.walk(self.root_dir, topdown=False):
            if self.corrupted_dir.name in dirs:
                dirs.remove(self.corrupted_dir.name)

            for dir_name in dirs:
                dir_path = Path(root) / dir_name
                if dir_path == self.corrupted_dir:
                    continue
                all_dirs.append(dir_path)
                self.total_folders_scanned += 1

        print(f"Found {self.total_folders_scanned} folders to check\n")

        for dir_path in all_dirs:
            try:
                rel_path = dir_path.relative_to(self.root_dir)
                print(f"Checking: {rel_path}")

                if self.has_ebooks(dir_path):
                    print(f"  ✓ Contains ebooks")
                    self.folders_with_ebooks.add(dir_path)
                else:
                    contents = list(dir_path.iterdir())
                    if len(contents) == 0:
                        print(f"  ✗ Empty folder")
                    else:
                        print(f"  ✗ No ebooks ({len(contents)} non-ebook items)")
                    self.folders_to_delete.append(dir_path)

            except Exception as e:
                print(f"  Error: {e}")

    def delete_empty_folders(self, confirm: bool = True):
        """Delete all folders that don't contain ebooks."""
        if not self.folders_to_delete:
            self.print_message("\n[yellow]No empty folders to delete.[/yellow]" if self.use_tui else "\nNo empty folders to delete.")
            return

        if self.use_tui:
            self.console.print("\n")
            self.console.print(Panel.fit(
                f"[bold red]🗑️  Deleting {len(self.folders_to_delete)} Empty Folder(s)[/bold red]",
                border_style="red"
            ))
        else:
            print("\n" + "=" * 70)
            print(f"DELETING {len(self.folders_to_delete)} EMPTY FOLDERS")
            print("=" * 70)

        if confirm:
            if self.use_tui:
                self.console.print("\n[yellow]Folders to be deleted:[/yellow]")
                for folder in self.folders_to_delete[:10]:
                    rel_path = folder.relative_to(self.root_dir)
                    self.console.print(f"  • {rel_path}")

                if len(self.folders_to_delete) > 10:
                    self.console.print(f"  ... and {len(self.folders_to_delete) - 10} more")
            else:
                print("\nFolders to be deleted:")
                for folder in self.folders_to_delete[:10]:
                    rel_path = folder.relative_to(self.root_dir)
                    print(f"  - {rel_path}")

                if len(self.folders_to_delete) > 10:
                    print(f"  ... and {len(self.folders_to_delete) - 10} more")

            response = input("\nProceed with deletion? (yes/no): ").strip().lower()
            if response not in ["yes", "y"]:
                self.print_message("[yellow]Deletion cancelled.[/yellow]" if self.use_tui else "Deletion cancelled.")
                return

        deleted_count = 0
        error_count = 0

        if self.use_tui:
            with Progress(
                SpinnerColumn(),
                TextColumn("[progress.description]{task.description}"),
                BarColumn(),
                MofNCompleteColumn(),
                console=self.console
            ) as progress:

                task = progress.add_task("[red]Deleting folders...", total=len(self.folders_to_delete))

                for folder in self.folders_to_delete:
                    rel_path = folder.relative_to(self.root_dir)
                    progress.update(task, description=f"[red]Deleting: {rel_path.name}")

                    try:
                        if folder.exists():
                            shutil.rmtree(folder)
                            deleted_count += 1
                    except Exception:
                        error_count += 1

                    progress.advance(task)

            self.console.print(f"\n[bold green]✅ Deleted {deleted_count} folder(s)[/bold green]")
            if error_count > 0:
                self.console.print(f"[bold red]❌ {error_count} error(s)[/bold red]")

        else:
            for folder in self.folders_to_delete:
                rel_path = folder.relative_to(self.root_dir)

                try:
                    if folder.exists():
                        shutil.rmtree(folder)
                        print(f"Deleted: {rel_path}")
                        deleted_count += 1
                except Exception as e:
                    print(f"Error deleting {rel_path}: {e}")
                    error_count += 1

            print(f"\nDeleted: {deleted_count} folders")
            if error_count > 0:
                print(f"Errors: {error_count} folders could not be deleted")

    # ========================================================================
    # REPORTING METHODS
    # ========================================================================

    def generate_report(self):
        """Generate a comprehensive report in Markdown format."""
        timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        report_file = self.root_dir / f"ebook_manager_report_{timestamp}.md"

        total_files = sum(
            self.corruption_results[ft]["total"] for ft in self.corruption_results
        )
        total_corrupted = sum(
            len(self.corruption_results[ft]["corrupted"])
            for ft in self.corruption_results
        )

        with open(report_file, "w", encoding="utf-8") as f:
            f.write("# Ebook Library Manager Report\n\n")
            f.write(f"**Report Date:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}  \n")
            f.write(f"**Root Directory:** `{self.root_dir}`  \n")
            f.write(f"**Corrupted Files Directory:** `{self.corrupted_dir}`\n\n")
            f.write("---\n\n")

            f.write("## Corruption Scan Summary\n\n")
            f.write(f"- **Total files scanned:** {total_files}\n")
            f.write(f"- **Total corrupted files:** {total_corrupted}\n\n")

            f.write("### By File Type\n\n")
            f.write("| File Type | Corrupted | Total | Status |\n")
            f.write("|-----------|-----------|-------|--------|\n")

            for file_type in ["epub", "mobi", "pdf"]:
                total = self.corruption_results[file_type]["total"]
                corrupted = len(self.corruption_results[file_type]["corrupted"])
                status = "❌" if corrupted > 0 else "✅"
                f.write(f"| {file_type.upper()} | {corrupted} | {total} | {status} |\n")

            f.write("\n")

            f.write("## Empty Folders Summary\n\n")
            f.write(f"- **Total folders scanned:** {self.total_folders_scanned}\n")
            f.write(f"- **Folders with ebooks:** {len(self.folders_with_ebooks)}\n")
            f.write(f"- **Folders without ebooks:** {len(self.folders_to_delete)}\n\n")

            if total_corrupted > 0:
                f.write("---\n\n")
                f.write("## Corrupted Files Details\n\n")

                for file_type in ["epub", "mobi", "pdf"]:
                    if self.corruption_results[file_type]["corrupted"]:
                        f.write(f"### {file_type.upper()} Files\n\n")

                        for item in self.corruption_results[file_type]["corrupted"]:
                            file_path = item['path'].relative_to(self.root_dir)
                            f.write(f"#### `{file_path}`\n\n")
                            f.write(f"- **Size:** {item['size']:,} bytes\n")
                            f.write(f"- **Reason:** {item['reason']}\n")
                            if "moved_to" in item:
                                moved_path = item['moved_to'].relative_to(self.root_dir)
                                f.write(f"- **Moved to:** `{moved_path}`\n")
                            if "move_error" in item:
                                f.write(f"- **Move error:** {item['move_error']}\n")
                            f.write("\n")
            else:
                f.write("---\n\n")
                f.write("## ✅ No Corrupted Files Found\n\n")

            if self.folders_to_delete:
                f.write("---\n\n")
                f.write("## Folders Without Ebooks\n\n")

                sorted_folders = sorted(self.folders_to_delete)

                for folder in sorted_folders:
                    rel_path = folder.relative_to(self.root_dir)
                    f.write(f"### `{rel_path}`\n\n")

                    if folder.exists():
                        try:
                            contents = list(folder.iterdir())
                            if contents:
                                f.write(f"**Contents:** {len(contents)} items\n\n")
                                for item in contents[:5]:
                                    item_type = "📁" if item.is_dir() else "📄"
                                    f.write(f"- {item_type} `{item.name}`\n")
                                if len(contents) > 5:
                                    f.write(f"- *... and {len(contents) - 5} more items*\n")
                                f.write("\n")
                            else:
                                f.write("**Status:** Empty folder\n\n")
                        except Exception as e:
                            f.write(f"**Error:** Could not read contents: {e}\n\n")
            else:
                if self.total_folders_scanned > 0:
                    f.write("---\n\n")
                    f.write("## ✅ No Empty Folders Found\n\n")

            f.write("---\n\n")
            f.write("*Report generated by Ebook Library Manager*\n")

        if self.use_tui:
            self.console.print(f"\n[bold cyan]📄 Report saved to:[/bold cyan] {report_file.name}")
        else:
            print(f"\nReport saved to: {report_file}")

        return report_file

    def print_summary(self):
        """Print a summary to console."""
        total_files = sum(
            self.corruption_results[ft]["total"] for ft in self.corruption_results
        )
        total_corrupted = sum(
            len(self.corruption_results[ft]["corrupted"])
            for ft in self.corruption_results
        )

        if self.use_tui:
            self.console.print("\n")

            # Create summary table
            summary_table = Table(title="Final Summary", box=box.DOUBLE, border_style="green", title_style="bold green")
            summary_table.add_column("Category", style="bold cyan")
            summary_table.add_column("Metric", style="bold white")
            summary_table.add_column("Value", justify="right", style="bold yellow")

            summary_table.add_row("Corruption Scan", "Files Scanned", str(total_files))
            summary_table.add_row("", "Corrupted Files", str(total_corrupted))
            summary_table.add_row("Empty Folders", "Folders Scanned", str(self.total_folders_scanned))
            summary_table.add_row("", "Empty Folders Found", str(len(self.folders_to_delete)))

            self.console.print(summary_table)

            # File type breakdown
            self.console.print("\n")
            self.console.print(self.create_file_type_table())

        else:
            print("\n" + "=" * 70)
            print("FINAL SUMMARY")
            print("=" * 70)

            print("\nCorruption Scan:")
            print(f"  Total files scanned: {total_files}")
            print(f"  Total corrupted files: {total_corrupted}")

            for file_type in ["epub", "mobi", "pdf"]:
                total = self.corruption_results[file_type]["total"]
                corrupted = len(self.corruption_results[file_type]["corrupted"])
                print(f"    {file_type.upper()}: {corrupted}/{total} corrupted")

            print("\nEmpty Folders:")
            print(f"  Total folders scanned: {self.total_folders_scanned}")
            print(f"  Folders with ebooks: {len(self.folders_with_ebooks)}")
            print(f"  Folders without ebooks: {len(self.folders_to_delete)}")


def main():
    parser = argparse.ArgumentParser(
        description="Comprehensive ebook library management tool with TUI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Run with TUI (default)
  python ebook_manager.py

  # Run without TUI (simple text output)
  python ebook_manager.py --no-tui

  # Only check for corruption
  python ebook_manager.py --corruption-only

  # Only check for empty folders
  python ebook_manager.py --empty-folders-only

  # Dry run (scan only, don't modify anything)
  python ebook_manager.py --dry-run

  # Scan specific directory
  python ebook_manager.py /path/to/ebooks

Note: TUI requires the 'rich' library. Install with: pip install rich
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
        help="Directory name for corrupted files (default: CORRUPTED)",
    )

    parser.add_argument(
        "--corruption-only",
        action="store_true",
        help="Only check for corrupted files",
    )

    parser.add_argument(
        "--empty-folders-only",
        action="store_true",
        help="Only check for empty folders",
    )

    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Scan only, do not modify anything",
    )

    parser.add_argument(
        "--no-confirm",
        action="store_true",
        help="Skip confirmation prompts",
    )

    parser.add_argument(
        "--no-report",
        action="store_true",
        help="Do not generate a report file",
    )

    parser.add_argument(
        "--no-tui",
        action="store_true",
        help="Disable TUI, use simple text output",
    )

    args = parser.parse_args()

    # Check if rich is available when TUI is requested
    if not args.no_tui and not RICH_AVAILABLE:
        print("Warning: 'rich' library not found. Install with: pip install rich")
        print("Falling back to simple text output.\n")
        args.no_tui = True

    # Validate directory
    root_dir = Path(args.directory).resolve()
    if not root_dir.exists():
        print(f"Error: Directory '{root_dir}' does not exist.")
        sys.exit(1)

    if not root_dir.is_dir():
        print(f"Error: '{root_dir}' is not a directory.")
        sys.exit(1)

    # Create manager instance
    manager = EbookManager(root_dir, args.corrupted_dir, use_tui=not args.no_tui)

    if manager.use_tui:
        manager.console.print(Panel.fit(
            "[bold green]📚 EBOOK LIBRARY MANAGER 📚[/bold green]\n"
            f"[cyan]Directory:[/cyan] {root_dir}\n"
            f"[cyan]Corrupted files destination:[/cyan] {manager.corrupted_dir.name}",
            border_style="green",
            title="Welcome"
        ))
    else:
        print("=" * 70)
        print("EBOOK LIBRARY MANAGER")
        print("=" * 70)
        print(f"Directory: {root_dir}")
        print(f"Corrupted files will be moved to: {manager.corrupted_dir}")
        print()

    # Run corruption scan
    if not args.empty_folders_only:
        manager.scan_for_corruption()

        if not args.dry_run:
            manager.move_corrupted_files()
        else:
            manager.print_message("[yellow]ℹ️  DRY RUN: Skipping file moves[/yellow]" if manager.use_tui else "\n[DRY RUN] Skipping file moves.")

    # Run empty folder scan
    if not args.corruption_only:
        manager.scan_for_empty_folders()

        if not args.dry_run:
            manager.delete_empty_folders(confirm=not args.no_confirm)
        else:
            manager.print_message("[yellow]ℹ️  DRY RUN: Skipping folder deletion[/yellow]" if manager.use_tui else "\n[DRY RUN] Skipping folder deletion.")

    # Generate report
    if not args.no_report:
        manager.generate_report()

    # Print summary
    manager.print_summary()

    if manager.use_tui:
        manager.console.print("\n")
        manager.console.print(Panel.fit("[bold green]✅ ALL OPERATIONS COMPLETED![/bold green]", border_style="green"))
    else:
        print("\n" + "=" * 70)
        print("DONE!")
        print("=" * 70)


if __name__ == "__main__":
    main()
