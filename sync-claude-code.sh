#!/usr/bin/env bash
# Symlinks every skill in this directory into Claude Code's user skills dir
# (~/.claude/skills) so they're discoverable there. Safe to re-run: creates
# missing links, leaves correct ones alone, and removes links that point
# back into this directory for skills that no longer exist here.
set -euo pipefail

SKILLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.claude/skills"

mkdir -p "$TARGET_DIR"

for dir in "$SKILLS_DIR"/*/; do
  name="$(basename "$dir")"
  [ -f "$dir/SKILL.md" ] || continue

  link="$TARGET_DIR/$name"
  if [ -L "$link" ] && [ "$(readlink "$link")" = "$dir" -o "$(readlink "$link")" = "${dir%/}" ]; then
    continue
  fi
  if [ -e "$link" ] || [ -L "$link" ]; then
    echo "skip $name: $link already exists and isn't a link to this skill" >&2
    continue
  fi
  ln -s "$dir" "$link"
  echo "linked $name"
done

# Remove links in TARGET_DIR that point back into this dir but whose
# source skill was removed or renamed.
for link in "$TARGET_DIR"/*; do
  [ -L "$link" ] || continue
  dest="$(readlink "$link")"
  case "$dest" in
    "$SKILLS_DIR"/*)
      [ -d "$dest" ] || { rm "$link"; echo "removed stale link $(basename "$link")"; }
      ;;
  esac
done
