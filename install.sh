#!/usr/bin/env bash
# Symlink the ticket-flow skill into your Claude Code skills dir.
# Symlinked on purpose: `git pull` then updates the installed skill with no reinstall.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/skills/ticket-flow"
DEST_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
DEST="$DEST_DIR/ticket-flow"
CONFIG="$HOME/.claude/ticket-flow.json"

[ -d "$SRC" ] || { echo "error: $SRC not found — run this from the repo root" >&2; exit 1; }

mkdir -p "$DEST_DIR"

if [ -e "$DEST" ] && [ ! -L "$DEST" ]; then
  echo "error: $DEST exists and is not a symlink — move it aside first" >&2
  exit 1
fi

ln -sfn "$SRC" "$DEST"
echo "✓ linked $DEST -> $SRC"

if [ -f "$CONFIG" ]; then
  echo "✓ config already present at $CONFIG"
  echo "  re-run setup any time to change it: ask Claude \"set up ticket-flow\""
else
  echo
  echo "Next: ask Claude \"set up ticket-flow\" — it detects your tracker, proves the"
  echo "connection, reads your real status names, and writes $CONFIG."
fi
