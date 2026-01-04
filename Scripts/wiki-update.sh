#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$ROOT_DIR/Scripts"
STAGING_DIR="${WIKI_STAGING_DIR:-$ROOT_DIR/.wiki-staging}"
WIKI_DIR="${WIKI_DIR:-$ROOT_DIR/.wiki}"
WIKI_REMOTE="${WIKI_REMOTE:-}"

if [ -z "$WIKI_REMOTE" ]; then
  if ! command -v git >/dev/null 2>&1; then
    echo "git is required to update the wiki." >&2
    exit 1
  fi
  origin_url="$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null || true)"
  if [ -z "$origin_url" ]; then
    echo "Could not determine origin URL. Set WIKI_REMOTE to the wiki repository URL." >&2
    exit 1
  fi
  if [[ "$origin_url" == *.git ]]; then
    WIKI_REMOTE="${origin_url%.git}.wiki.git"
  else
    WIKI_REMOTE="${origin_url}.wiki.git"
  fi
fi

"$SCRIPTS_DIR/wiki-generate.sh"

if [ ! -d "$WIKI_DIR/.git" ]; then
  git clone "$WIKI_REMOTE" "$WIKI_DIR"
else
  git -C "$WIKI_DIR" pull --ff-only
fi

if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete --exclude '.git' "$STAGING_DIR/" "$WIKI_DIR/"
else
  rm -rf "$WIKI_DIR"/*
  cp -R "$STAGING_DIR/." "$WIKI_DIR/"
fi

if [ -n "$(git -C "$WIKI_DIR" status --porcelain)" ]; then
  git -C "$WIKI_DIR" add -A
  git -C "$WIKI_DIR" commit -m "docs: update wiki"
  git -C "$WIKI_DIR" push
else
  echo "No wiki changes to commit."
fi
