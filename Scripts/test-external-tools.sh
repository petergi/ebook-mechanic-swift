#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "🧪 Running external tools integration test..."

# --- Configuration ---
TEMP_DIR=$(mktemp -d "/tmp/ebook_mechanic_external_tools_test.XXXXXX")
CLI_PATH="./.build/debug/EbookMechanicCLI" # Assuming debug build
VALID_EPUB="${TEMP_DIR}/valid.epub"
INVALID_EPUB="${TEMP_DIR}/invalid.epub"
VALID_PDF="${TEMP_DIR}/valid.pdf"
INVALID_PDF="${TEMP_DIR}/invalid.pdf"

# --- Cleanup ---
cleanup() {
    echo "🧹 Cleaning up temporary directory: ${TEMP_DIR}"
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

# --- Build CLI ---
echo "🔨 Building EbookMechanicCLI..."
# Use swift build directly to ensure the CLI is built
swift build --product EbookMechanicCLI
# Check if the build artifact exists
if [ ! -f "$CLI_PATH" ]; then
    echo "❌ Error: EbookMechanicCLI not found at $CLI_PATH. Ensure 'swift build --product EbookMechanicCLI' built successfully."
    exit 1
fi
echo "✅ CLI built successfully."

# --- Create Dummy Files ---
echo "Creating dummy ebook files in ${TEMP_DIR}..."

# Create dummy valid EPUB (minimal zip structure)
zip -j "${VALID_EPUB}" <(echo "application/epub+zip") -
echo '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>' > "${TEMP_DIR}/container.xml"
zip -j "${VALID_EPUB}" "${TEMP_DIR}/container.xml"
echo '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="pub-id"><metadata><dc:title>Valid EPUB</dc:title><dc:creator>Test</dc:creator><dc:identifier id="pub-id">urn:uuid:test</dc:identifier><dc:language>en</dc:language></metadata><manifest><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/><item id="cover" href="cover.xhtml" media-type="application/xhtml+xml" properties="svg"/></manifest><spine><itemref idref="cover"/><itemref idref="nav"/></spine></package>' > "${TEMP_DIR}/content.opf"
zip -j "${VALID_EPUB}" "${TEMP_DIR}/content.opf"

# Create dummy invalid EPUB (missing mimetype)
echo "dummy content" > "${INVALID_EPUB}" # Not a valid zip, definitely invalid EPUB

# Create dummy valid PDF (minimal structure)
# This is hard to do with just shell, so we'll create a placeholder that should pass basic checks
echo "%PDF-1.4" > "${VALID_PDF}"
echo "1 0 obj <</Type/Catalog /Pages 2 0 R>> endobj" >> "${VALID_PDF}"
echo "2 0 obj <</Type/Pages /Count 0>> endobj" >> "${VALID_PDF}"
echo "xref" >> "${VALID_PDF}"
echo "0 3" >> "${VALID_PDF}"
echo "0000000000 65535 f" >> "${VALID_PDF}"
echo "0000000009 00000 n" >> "${VALID_PDF}"
echo "0000000067 00000 n" >> "${VALID_PDF}"
echo "trailer <</Size 3/Root 1 0 R>>" >> "${VALID_PDF}"
echo "startxref" >> "${VALID_PDF}"
echo "106" >> "${VALID_PDF}"
echo "%%EOF" >> "${VALID_PDF}"

# Create dummy invalid PDF (missing EOF)
echo "%PDF-1.4" > "${INVALID_PDF}"
echo "1 0 obj <</Type/Catalog /Pages 2 0 R>> endobj" >> "${INVALID_PDF}"
echo "2 0 obj <</Type/Pages /Count 0>> endobj" >> "${INVALID_PDF}"
echo "trailer <</Size 3/Root 1 0 R>>" >> "${INVALID_PDF}"
echo "startxref" >> "${INVALID_PDF}"
echo "106" >> "${INVALID_PDF}"
# Missing %%EOF


echo "--- Running without external tools (basic validation) ---"
BASIC_RESULT=$("$CLI_PATH" --dir "${TEMP_DIR}" --report --report-format markdown --no-cache --verbose --dry-run)
echo "${BASIC_RESULT}"
echo ""

echo "--- Running with external tools (comprehensive validation) ---"
COMPREHENSIVE_RESULT=$("$CLI_PATH" --dir "${TEMP_DIR}" --report --report-format markdown --no-cache --verbose --dry-run --use-external-tools)
echo "${COMPREHENSIVE_RESULT}"
echo ""

# --- Basic Comparison (can be enhanced) ---
echo "--- Comparison Summary ---"
if echo "${BASIC_RESULT}" | grep -q "EPUB is valid"; then
    echo "Basic validation: Valid EPUB detected."
else
    echo "Basic validation: Invalid EPUB detected."
fi

if echo "${COMPREHENSIVE_RESULT}" | grep -q "EPUB is valid"; then
    echo "Comprehensive validation: Valid EPUB detected."
else
    echo "Comprehensive validation: Invalid EPUB detected."
fi

if echo "${BASIC_RESULT}" | grep -q "Valid PDF"; then
    echo "Basic validation: Valid PDF detected."
else
    echo "Basic validation: Invalid PDF detected."
fi

if echo "${COMPREHENSIVE_RESULT}" | grep -q "Valid PDF"; then
    echo "Comprehensive validation: Valid PDF detected."
else
    echo "Comprehensive validation: Invalid PDF detected."
fi

echo "✅ External tools integration test finished."
