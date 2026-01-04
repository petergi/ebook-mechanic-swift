#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCS_DIR="${WIKI_SOURCE_DIR:-$ROOT_DIR/Docs/Swift}"
STAGING_DIR="${WIKI_STAGING_DIR:-$ROOT_DIR/.wiki-staging}"

if [ ! -d "$DOCS_DIR" ]; then
  echo "Docs directory not found: $DOCS_DIR" >&2
  exit 1
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

if command -v rsync >/dev/null 2>&1; then
  rsync -a --exclude '.DS_Store' --exclude 'README.md' "$DOCS_DIR/" "$STAGING_DIR/"
else
  cp -R "$DOCS_DIR/." "$STAGING_DIR/"
  find "$STAGING_DIR" -name '.DS_Store' -delete
  rm -f "$STAGING_DIR/README.md"
fi

if [ -f "$DOCS_DIR/README.md" ]; then
  cp "$DOCS_DIR/README.md" "$STAGING_DIR/Home.md"
fi

if [ -f "$ROOT_DIR/README.md" ]; then
  cp "$ROOT_DIR/README.md" "$STAGING_DIR/Project-README.md"
fi

sidebar_file="$STAGING_DIR/_Sidebar.md"
{
  echo "- [Home](Home)"
  if [ -f "$STAGING_DIR/Project-README.md" ]; then
    echo "- [Project README](Project-README)"
  fi

  while IFS= read -r file; do
    base_name="$(basename "$file")"
    page_name="${base_name%.md}"
    if [ "$page_name" = "Home" ] || [ "$page_name" = "_Sidebar" ] || [ "$page_name" = "Project-README" ]; then
      continue
    fi
    echo "- [$page_name]($page_name)"
  done < <(find "$STAGING_DIR" -maxdepth 1 -type f -name '*.md' | sort)

  if [ -d "$STAGING_DIR/examples" ]; then
    while IFS= read -r file; do
      rel_path="${file#"$STAGING_DIR"/}"
      page_path="${rel_path%.md}"
      if [ "$page_path" != "$rel_path" ]; then
        echo "- [${page_path#examples/}]($page_path)"
      fi
    done < <(find "$STAGING_DIR/examples" -type f -name '*.md' | sort)
  fi
} > "$sidebar_file"

echo "Wiki content staged in: $STAGING_DIR"
