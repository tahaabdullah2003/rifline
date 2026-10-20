# RIFTLINE — Fixes applied (agent pass 1)

Base: `Riftline_agent_pack_15mb.zip` as received. Every change below is a local git
commit (`git log` for the sequence). All `.gd` files verified with `gdparse`
(GDScript grammar) — full game re-test still needs Godot 4.7.2 + the full asset repo:

```bash
godot --path . --resolution 1230x540 --windowed -- --mobile-ui
```

## P0 — wiring / “broken options” feel

### 1. Dead `hud_gen_*` keys — DONE (`P0.1/P2.12` commit)
- Removed all 9 `hud_gen_*` entries from the asset map (they pointed at
  `res://art/ui/mobile_generated/`, which exists nowhere) → kills the 9 boot warnings.
- Removed `_hud_frame_key()`, `_mobile_gen_hud_active()` and **every** branch that
  used them: status frame, mission banner, economy strip, shop tab, reactor,
  weapons, abilities, encounter-layout fallback, status-overlap report,
  `gen_hud=` debug line, `mlayout` plumbing.
- Collapses keep the exact else/desktop path (the gen folder never existed, so
  those branches were already dead at runtime).
- **One HUD architecture remains**: `assets/ui/hud/` compact shells +
  `MobileStatusHud` / `MobileEconomyHud` / `MobileEncounterHud` +
  `_draw_mobile_compact_*` (also closes P2.12).

### 2. SFX gated on Particles — DONE (`P0.2` commit)
```gdscript
# before
if audio != null and settings.get("particles", true):
# after
if audio == null or float(settings.get("sfx_volume", 10)) <= 0.0:
```
SFX now follows **SFX VOLUME** (0 = muted). Particles toggle no longer silences combat.

### 3. Mycelarch fallback JPEG — DONE (`P0.3` commit)
- Dropped the `boss_mycelarch` key → `res://assets/boss_flow_refs/boss_mycelarch_idle.jpeg`
  (folder never existed; also removed the last missing-asset boot warning on mobile).
- `draw_iron_colossus()`: if Mycelarch sheets are missing the boss draws nothing
  (same as today) — it will **never** fall back to the wrong boss art.
  Colossus / Breach keep their static full-body fallbacks.

### 4. Haptics no-op — DONE (`P0.4` commit)
- New `_haptic(duration_ms, amplitude, cooldown_ms, force)` helper: honors
  `settings.haptics`, throttled at 160 ms (barrages don’t spam the motor).
- `Input.vibrate_handheld()` → real vibration on Android/iOS, silent no-op on desktop.
- Call sites: convoy damage tick (28 ms), car **DISABLED** (90 ms, forced),
  ability activation (45 ms, forced).
- Option stays in the Options menu (now actually does something).

## P1 — logic-only items

### 6. Mobile XP fill — DONE (`P1.6` commit)
`MobileEconomyHud.apply()` re-enables `XpClip/BarTrack/BarFill`: clipped bar in the
XP well (12 % inset), fill width from the already-plumbed `data.xp_pct`,
label stamped above (z_index 20 > 10).

### 7. Mobile 1×/2× speed — DONE (`P1.7` commit)
- New `_draw_speed_toggle(x, y, s)` helper: uses `btn_hud_speed` art when present,
  otherwise a brass text pill (`2×`/`1×`) so stripped/preview builds still get it.
- Mobile economy HUD: speed button stacks under pause in the right strip that
  `MobileHudLayout.economy_panel()` was already reserving for “pause + speed”.
- Fallback HUD branch: speed no longer gated behind `not is_mobile_ui`.

### 8. Combat music bed — DONE (wiring) (`P1.8` commit)
- `AudioBus` loads `assets/audio/music/riftline_combat.{ogg,wav}` when present and
  exposes `play_combat_music()`; **until the track ships it falls back to travel**,
  so behavior matches the old build.
- Combat routed to the bed in `set_state`, `back_from_options`, `back_from_help`,
  `reset_run`, `load_run` (resumed combat).
- `_process` state-edge watcher switches tracks on combat entry/exit — catches the
  ~30 direct `state = "combat"` assignments that bypass `set_state()`.
- **TODO (art/audio):** drop in `riftline_combat.ogg` (looped, ~90–120 s bed).

## P2

### 11. `riftline_reactor_status_panel` misname — DONE (`P2.11` commit)
Renamed to `assets/ui/hud/riftline_abilities_bar.png` (code + report strings +
layout comment updated). Original SVG upstream is still named
`riftline_reactor_status_panel.svg` — rename it in the full repo when convenient.

### 12. One HUD architecture — DONE (see P0.1).

### 13. Font/readability pass audit — VERIFIED, no regressions
- `MobileHudLayout.gd`: `HUD_SIZE_BOOST = 1.32` ✓, `READABLE_LABEL_MIN_PX = 14` ✓,
  `STATUS_MIN_LABEL_PX = 15` ✓, `text_size_for_panel()` floors at `max(min_px, 14)` ✓.
- Control HUDs: StatusHud value/unit floors 15/11, Encounter title/meta/prog
  15/12/12, Economy scrap/level/xp 13/13/11 with ceilings 30/30/24 — all still in
  place; `scale_f = max(1.0, win_to_vp)` grows type on HiDPI instead of clamping.
- Note: Economy `xp_px` floor (11) is below `READABLE_LABEL_MIN_PX` (14) by design —
  it sits in a measured well where 14 px overflows; keep unless complaints persist.

## NOT done here (needs assets / full repo — see `ASSET_AND_POLISH_TODO.md`)

- P1.5 tiny `assets/icon_*.png` (the full repo has the **same** placeholders — new art required)
- P1.8 combat track file (wiring done)
- P1.9 desktop `ui/final` vs mobile `ui/hud` visual split (art unification)
- P1.10 asset-dump cleanup (safe-target audit done; script provided)
