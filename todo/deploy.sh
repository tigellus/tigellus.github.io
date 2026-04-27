#!/usr/bin/env bash
# Deploy this folder to tigellus.github.io/todo/
# Source-of-truth: this folder. JSON data files are NEVER pushed.
#
# Mirrors everything in this folder to <clone>/todo/, with these rules:
#   - todo.html  → todo/index.html  (the published page)
#   - *.json     → never copied     (your personal data stays local)
#   - everything else → todo/<filename>  (CLAUDE.md, deploy.sh, future files)
#   - files removed here are also removed in todo/ (--delete)
#
# Usage:
#   ./deploy.sh                  # commit with auto message
#   ./deploy.sh "fix dark mode"  # commit with custom message
#
# Published at https://tigellus.github.io/todo/

set -euo pipefail

# --- config -----------------------------------------------------------------
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLONE="/Users/valentinopacifici/Documents/webpage/tigellus.github.io"
DEST_DIR="$CLONE/todo"
# ----------------------------------------------------------------------------

# Sanity: source file exists
if [ ! -f "$SRC_DIR/todo.html" ]; then
  echo "❌ Source not found: $SRC_DIR/todo.html" >&2
  exit 1
fi

# Sanity: clone exists and is a git repo
if [ ! -d "$CLONE/.git" ]; then
  echo "❌ Not a git repo: $CLONE" >&2
  echo "   (Edit CLONE in $0 if your local clone path changed.)" >&2
  exit 1
fi

mkdir -p "$DEST_DIR"

# 1) Copy todo.html → todo/index.html (renamed for GitHub Pages)
cp "$SRC_DIR/todo.html" "$DEST_DIR/index.html"

# 2) Mirror everything else (CLAUDE.md, deploy.sh, future files…) into todo/.
#    Excludes:
#      *.json      — personal data, never leaves this folder
#      todo.html   — already copied as index.html above
#      index.html  — protect what we just wrote from --delete
#      .DS_Store   — macOS noise
rsync -a --delete \
  --exclude='*.json' \
  --exclude='todo.html' \
  --exclude='index.html' \
  --exclude='.DS_Store' \
  "$SRC_DIR/" "$DEST_DIR/"

cd "$CLONE"

# Stage all changes under todo/ (additions, modifications, deletions)
git add -A -- todo/

# Bail cleanly if nothing changed
if git diff --cached --quiet -- todo/; then
  echo "✓ No changes — todo/ is already up to date."
  exit 0
fi

MSG="${1:-Update todo app · $(date '+%Y-%m-%d %H:%M')}"
git commit -m "$MSG" -- todo/
git push

echo ""
echo "✓ Deployed. Visit: https://tigellus.github.io/todo/"
echo "  (GitHub Pages usually rebuilds within ~30s.)"
