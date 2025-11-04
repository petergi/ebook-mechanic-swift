#!/usr/bin/env python3
"""Generate a sample ebook library with mixed valid and corrupt files."""

import argparse
import shutil
from pathlib import Path
from typing import List
from zipfile import ZipFile, ZIP_DEFLATED, ZIP_STORED


def ensure_parent(path: Path) -> None:
    """Make sure the parent directory exists before writing a file."""
    path.parent.mkdir(parents=True, exist_ok=True)


def create_valid_pdf(path: Path, title: str) -> None:
    ensure_parent(path)
    body_lines = [
        "1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj",
        "2 0 obj << /Type /Pages /Count 1 /Kids [3 0 R] >> endobj",
        "3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >> endobj",
        "4 0 obj << /Length 44 >> stream",
        f"BT /F1 24 Tf 72 700 Td ({title}) Tj ET",
        "endstream endobj",
        "5 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj",
        "xref",
        "0 6",
        "0000000000 65535 f ",
        "0000000010 00000 n ",
        "0000000079 00000 n ",
        "0000000174 00000 n ",
        "0000000285 00000 n ",
        "0000000376 00000 n ",
        "trailer << /Root 1 0 R /Size 6 >>",
        "startxref",
        "467",
        "%%EOF",
    ]
    content = "%PDF-1.4\n" + "\n".join(body_lines) + "\n"
    if len(content) < 200:
        content = content + "%" * (200 - len(content))
    path.write_text(content, encoding="ascii")


def create_corrupt_pdf(path: Path, title: str) -> None:
    ensure_parent(path)
    path.write_text(f"This is not a real PDF for {title}", encoding="ascii")


def create_valid_epub(path: Path, title: str) -> None:
    ensure_parent(path)
    with ZipFile(path, "w") as archive:
        archive.writestr("mimetype", "application/epub+zip", compress_type=ZIP_STORED)
        archive.writestr(
            "META-INF/container.xml",
            """<?xml version='1.0' encoding='utf-8'?>
<container version='1.0' xmlns='urn:oasis:names:tc:opendocument:xmlns:container'>
  <rootfiles>
    <rootfile full-path='OEBPS/content.opf' media-type='application/oebps-package+xml'/>
  </rootfiles>
</container>""",
        )
        archive.writestr(
            "OEBPS/content.opf",
            f"""<?xml version='1.0' encoding='utf-8'?>
<package version='2.0' unique-identifier='BookId' xmlns='http://www.idpf.org/2007/opf'>
  <metadata xmlns:dc='http://purl.org/dc/elements/1.1/'>
    <dc:title>{title}</dc:title>
  </metadata>
  <manifest>
    <item id='content' href='content.xhtml' media-type='application/xhtml+xml'/>
  </manifest>
  <spine>
    <itemref idref='content'/>
  </spine>
</package>""",
        )
        archive.writestr(
            "OEBPS/content.xhtml",
            f"""<?xml version='1.0' encoding='utf-8'?>
<html xmlns='http://www.w3.org/1999/xhtml'>
  <head><title>{title}</title></head>
  <body><p>{title}</p></body>
</html>""",
        )


def create_corrupt_epub(path: Path, title: str) -> None:
    ensure_parent(path)
    with ZipFile(path, "w", compression=ZIP_DEFLATED) as archive:
        archive.writestr("content.txt", f"Broken EPUB for {title}")


def create_valid_mobi_like(path: Path, title: str) -> None:
    ensure_parent(path)
    data = bytearray(128)
    title_bytes = title.encode("ascii", errors="ignore")[:20]
    data[: len(title_bytes)] = title_bytes
    data[60:68] = b"BOOKMOBI"
    path.write_bytes(data)


def create_corrupt_mobi(path: Path, title: str) -> None:
    ensure_parent(path)
    path.write_bytes(b"\x00" * 128)


def create_valid_azw3(path: Path, title: str) -> None:
    create_valid_mobi_like(path, title)


def create_corrupt_azw3(path: Path, title: str) -> None:
    create_corrupt_mobi(path, title)


def create_valid_azw4(path: Path, title: str) -> None:
    create_valid_pdf(path, title)


def create_corrupt_azw4(path: Path, title: str) -> None:
    create_corrupt_pdf(path, title)


VALID_CREATORS = {
    "pdf": create_valid_pdf,
    "epub": create_valid_epub,
    "mobi": create_valid_mobi_like,
    "azw3": create_valid_azw3,
    "azw4": create_valid_azw4,
}

CORRUPT_CREATORS = {
    "pdf": create_corrupt_pdf,
    "epub": create_corrupt_epub,
    "mobi": create_corrupt_mobi,
    "azw3": create_corrupt_azw3,
    "azw4": create_corrupt_azw4,
}


def generate_library(output_dir: Path, author_count: int, formats: List[str]) -> int:
    total_files = 0
    for idx in range(1, author_count + 1):
        author_name = f"Author_{idx:02d}"
        for ext in formats:
            series_dir = output_dir / author_name / f"Series_{ext.upper()}"
            title = f"Sample {ext.upper()} Title {idx:02d}"
            VALID_CREATORS[ext](series_dir / f"book_{idx:02d}_valid.{ext}", title)
            CORRUPT_CREATORS[ext](series_dir / f"book_{idx:02d}_corrupt.{ext}", title)
            total_files += 2
    return total_files


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        default="test-library",
        help="Destination directory for the generated library (default: test-library)",
    )
    parser.add_argument(
        "--authors",
        type=int,
        default=10,
        help="Number of author directories to create (default: 10)",
    )
    parser.add_argument(
        "--formats",
        default="pdf,epub,mobi,azw3,azw4",
        help="Comma-separated list of formats to generate (default: pdf,epub,mobi,azw3,azw4)",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite the output directory if it already exists",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    output_dir = Path(args.output).resolve()
    formats = [fmt.strip().lower() for fmt in args.formats.split(",") if fmt.strip()]

    unknown_formats = [fmt for fmt in formats if fmt not in VALID_CREATORS]
    if unknown_formats:
        raise ValueError(f"Unsupported formats requested: {', '.join(unknown_formats)}")

    if output_dir.exists():
        if args.force:
            shutil.rmtree(output_dir)
        else:
            raise FileExistsError(
                f"Output directory '{output_dir}' already exists. Use --force to overwrite."
            )

    total_files = generate_library(output_dir, args.authors, formats)
    print(f"Created {total_files} ebook files under {output_dir}")


if __name__ == "__main__":
    main()
