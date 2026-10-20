# RIFTLINE — Asset / polish TODOs (need art, audio, or full-repo cleanup)

Logic-only items are done — see `FIXES_APPLIED.md`. This file covers what still
needs assets or destructive repo cleanup.

## P1.5 — Tiny `assets/icon_*.png` placeholders (13 files)

Facts established this pass:
- Pack icons are **128×128, 1.4–6.4 KB** flat glyphs.
- The **full repo on Drive has byte-identical copies** — there is no polished set
  hiding anywhere (`assets/ui/final/` has no `icon_*` for these; only
  `icon_scrap_gear/permanent_alloy/best_score/victories` which are already wired
  to their own keys).

Options (pick one):
1. **Commission / AI-generate a brass set** — target 256×256, transparent PNG,
   steampunk brass-on-navy to match the HUD. Drop in as
   `assets/icon_{engine,gatling,cannon,shield,heat,scrap,xp,rift,utility,drone,arc,cryo,mortar}.png`
   — no code changes needed (keys already point there).
2. **Reuse `hud_slot_*` art** — `assets/ui/final/hud_slot_{gatling,cannon,drone,arc,cryo,mortar,missile}.png`
   are polished multi-MB tiles already used by the combat weapon slots. They have
   backgrounds, so they suit slot wells, not the flat shop-card icon slots.
3. Keep placeholders (they render at 40–58 px, so resolution is fine; it’s style, not size).

Watch-out: `project.godot` sets `default_texture_filter=0` (nearest). Downscaled
128 px icons under nearest filtering look crunchy on phones. If new art is
smooth, consider per-import filter = Linear for `assets/icon_*` (don’t flip the
project-wide filter without visual review — sheets/backgrounds rely on it).

## P1.8 — Combat music bed (file)

Wiring is in (`AudioBus.play_combat_music` + state watcher). Add:
```
assets/audio/music/riftline_combat.ogg   (or .wav)   looped, ~90–120 s
```
Auto-detected at boot; until then combat keeps the travel loop (old behavior).

## P1.9 — Desktop `ui/final` vs mobile `ui/hud` split

`load_assets()` already remaps `assets/ui/final/* → assets/ui/mobile/*` when the
mobile variant exists (fallback to desktop art). The remaining gap is *style*:
desktop uses large 0.7–2.8 MB `ui/final` frames, mobile uses the compact
`ui/hud` brass set. Unify by exporting mobile-sized versions of the desktop
frames (or accept the compact set as canonical on both) — art task, no code debt.

## P1.10 — Asset dump clutter

Audit result: **no script, scene, or project.godot reference** to
`assets/final/`, `assets/final_clean/`, `FLOW_PROMPTS*`, or stray `refs/` dirs —
they are safe to shelve. Use the provided tool (dry-run first):

```bash
tools/cleanup_asset_dump.sh              # preview (default: move into _attic/)
tools/cleanup_asset_dump.sh --delete     # actually delete instead of moving
tools/cleanup_asset_dump.sh --restore    # move everything back
```

Run it at the **full repo root** (`Rifline/`), not in this pack.

## Suggested follow-up order

1. Drop in `riftline_combat.ogg` (instant, wiring already done)
2. Icon set (biggest visual win on the brass HUD)
3. `tools/cleanup_asset_dump.sh --delete` on the full repo
4. Rename upstream `riftline_reactor_status_panel.svg` → `riftline_abilities_bar.svg`
5. Re-test full build: `godot --path . --resolution 1230x540 --windowed -- --mobile-ui`
