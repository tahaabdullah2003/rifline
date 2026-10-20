#!/usr/bin/env bash
# RIFTLINE — shelve asset-dump clutter (P1.10).
#
# Audit (agent pass 1): nothing in scripts/, scenes/, or project.godot
# references assets/final, assets/final_clean, FLOW_PROMPTS*, or stray refs/
# folders — safe to shelve. Run from the FULL REPO ROOT (the folder that
# contains project.godot), not from the agent pack.
#
# Default mode is a DRY RUN that only prints what would move into _attic/.
#   ./tools/cleanup_asset_dump.sh            # preview
#   ./tools/cleanup_asset_dump.sh --apply    # move into _attic/<original path>
#   ./tools/cleanup_asset_dump.sh --delete   # delete irreversibly (review first!)
#   ./tools/cleanup_asset_dump.sh --restore  # move everything back out of _attic/
set -euo pipefail

MODE="preview"
case "${1:-}" in
  "") ;;
  --apply) MODE="apply" ;;
  --delete) MODE="delete" ;;
  --restore) MODE="restore" ;;
  *) echo "usage: $0 [--apply|--delete|--restore]" >&2; exit 2 ;;
esac

if [[ ! -f project.godot && ! -f ./project.godot ]]; then
  echo "ERROR: run me from the RiftLine repo root (project.godot not found)." >&2
  exit 1
fi

# Candidates from the handoff pack. Extend carefully; each path is checked.
TARGETS=(
  "assets/final"
  "assets/final_clean"
  "assets/ui/final_clean"
  "FLOW_PROMPTS.md"
  "FLOW_PROMPTS.txt"
  "art/refs"
  "docs/refs"
  "refs"
)

# Never touch paths the runtime loads (see docs/ASSET_AND_POLISH_TODO.md audit).
PROTECT=("assets/ui/final" "assets/ui/hud" "assets/ui/mobile" "assets/audio" "assets/animations")

is_protected() {
  local p="$1"
  for safe in "${PROTECT[@]}"; do
    [[ "$p" == "$safe" || "$p" == "$safe"/* ]] && return 0
  done
  return 1
}

found_any=0

if [[ "$MODE" == "restore" ]]; then
  echo "== Restore: moving everything back out of _attic/ =="
  if [[ ! -d _attic ]]; then echo "(no _attic/ — nothing to restore)"; exit 0; fi
  (cd _attic && find . -type d -empty -delete 2>/dev/null || true)
  while IFS= read -r -d '' f; do
    rel="${f#./}"
    echo "RESTORE  $rel"
    mkdir -p "$(dirname "$rel")"
    mv "_attic/$rel" "$rel"
  done < <(find _attic -type f -print0 2>/dev/null)
  find _attic -type d -empty -delete 2>/dev/null || true
  echo "Done."
  exit 0
fi

echo "== RIFTLINE asset-dump cleanup (mode: $MODE) =="
for t in "${TARGETS[@]}"; do
  if [[ ! -e "$t" ]]; then continue; fi
  if is_protected "$t"; then echo "SKIP (protected): $t"; continue; fi
  # Guard: if it's a dir referenced by any .gd/.tscn, refuse.
  if [[ -d "$t" ]] && grep -Rqs --include='*.gd' --include='*.tscn' --include='*.godot' "res://$t/" .; then
    echo "SKIP (referenced by code): $t"
    continue
  fi
  found_any=1
  case "$MODE" in
    preview) echo "WOULD MOVE  $t  ->  _attic/$t" ;;
    apply)
      echo "MOVE        $t  ->  _attic/$t"
      mkdir -p "_attic/$(dirname "$t")"
      rm -rf "_attic/$t"
      mv "$t" "_attic/$t"
      ;;
    delete)
      echo "DELETE      $t"
      rm -rf "$t"
      ;;
  esac
done

if [[ "$found_any" -eq 0 ]]; then
  echo "(no candidate clutter found — repo already clean)"
elif [[ "$MODE" == "preview" ]]; then
  echo
  echo "Dry run only. Re-run with --apply (shelve) or --delete (remove)."
fi
