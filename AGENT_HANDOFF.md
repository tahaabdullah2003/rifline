# RIFTLINE — Agent handoff pack (≤15 MB diagnostic slice)

**Full repo:** `mts755Dev/RiftLine` (Godot 4.7.2, package `com.riftline.lasttrain`)  
**This zip:** code + downsized HUD PNGs + fonts + screenshot — enough to diagnose and patch logic. **Not** a runnable full game (bulk art / audio / animations stripped).

## What this game is

Steampunk train-defense roguelite. Mobile “dev mode” = Godot phone window `1230×540` + `--mobile-ui` (Infinix X680B landscape preview), not iOS Simulator export.

```bash
# Full repo (when you have it):
godot --path . --resolution 1230x540 --windowed -- --mobile-ui
```

## What’s IN this pack

| Path | Why |
|------|-----|
| `scripts/*.gd` | All game logic (esp. `GodotMain.gd`, `Mobile*.gd`) |
| `scenes/` | Main + Mobile*Hud Control scenes |
| `project.godot` | Display / mobile_preview settings |
| `assets/ui/hud/*.png` | **Downscaled to max 1024px** — layout reference only |
| `assets/ui/fonts/` | ShareTechMono |
| `assets/icon_*.png` | Tiny placeholder icons (P1 issue) |
| `captures/mobile_preview_before.jpg` | Screenshot of combat HUD (readability baseline) |
| `README.md` | Upstream run notes |

## What’s OUT (get from full repo if needed)

- `assets/animations/` (~95 MB), `assets/audio/` (~17 MB), `assets/mobile_bg/`, bosses, regions
- Fat HUD **SVGs** (~30 MB) — runtime uses PNGs; originals in full repo
- `.godot/` import cache
- Missing folder referenced in code: `art/ui/mobile_generated/` (**does not exist**)

---

## Problems to fix (priority)

### P0 — wiring / “broken options” feel

1. **Dead `hud_gen_*` keys** — `GodotMain.gd` ~745–806  
   Paths: `res://art/ui/mobile_generated/hud_gen_*.png` → folder missing → 9 warnings every mobile boot.  
   Production UI is the **compact HUD** (`assets/ui/hud/` + `MobileStatusHud` / `MobileEconomyHud` / `MobileEncounterHud` + `_draw_mobile_compact_*`).  
   **Fix:** remove gen asset keys + dead `_mobile_gen_hud_active()` branches (prefer delete, don’t regenerate).

2. **SFX gated on Particles** — `GodotMain.gd` `sfx()` (~610–612)  
   Checks `settings.particles` instead of SFX enable/volume. Particles off → silent combat.

3. **Mycelarch fallback JPEG** — path under `assets/boss_flow_refs/` missing. Sheets exist in full repo under `assets/animations/`. Point fallback at idle sheet or drop key.

4. **Haptics setting is a no-op** — options UI has toggle; no vibrate call site. Wire it or remove.

### P1 — polish / assets (need full repo for final art)

5. Tiny `assets/icon_*.png` placeholders vs polished brass HUD.  
6. Mobile XP fill disabled in `MobileEconomyHud.gd` (`_xp_clip` hidden).  
7. No mobile 1×/2× speed control (desktop has it).  
8. Only menu + travel music — no combat bed.  
9. Desktop `assets/ui/final/` vs mobile `assets/ui/hud/` visual split.  
10. Asset dump clutter (`final/`, `final_clean/`, FLOW_PROMPTS, refs).

### P2

11. Misnamed `riftline_reactor_status_panel` = abilities bar.  
12. One HUD architecture only (kill gen path).  
13. Recent font bumps already in `MobileHudLayout.gd` / Control HUDs — verify nothing regressed.

---

## Recent work already in these scripts

Mobile HUD **readability pass** (keep unless wrong):

- `MobileHudLayout.gd`: `HUD_SIZE_BOOST` 1.32, `READABLE_LABEL_MIN_PX` 14, slightly larger panel refs, taller ability label band  
- `MobileStatusHud.gd` / `MobileEncounterHud.gd` / `MobileEconomyHud.gd`: higher font floors/ceilings (Retina was clamping XP ~14px)  
- `GodotMain.gd`: larger reactor / weapons / ability label draw sizes  

Screenshot `captures/mobile_preview_before.jpg` is **before** that pass (or early preview) — use for “what was wrong,” not current state.

---

## Key files to read first

1. `scripts/MobileAdapt.gd` — mobile preview detection, phone geometry  
2. `scripts/MobileHudLayout.gd` — panel geometry  
3. `scripts/MobileStatusHud.gd`, `MobileEconomyHud.gd`, `MobileEncounterHud.gd`  
4. `scripts/GodotMain.gd` — asset map (~700+), `sfx()`, combat HUD draw, compact reactor/weapons/abilities  
5. `project.godot` — `[riftline] mobile_preview`, display overrides  

Search tips:

```
rg "hud_gen_|mobile_generated|settings.particles|vibrate|haptic|boss_mycelarch|_xp_clip" scripts/
```

---

## Suggested first PR (P0 only)

1. Delete `hud_gen_*` from asset dict + simplify `_hud_frame_key` / gen branches.  
2. Fix `sfx()` to respect SFX settings, not particles.  
3. Fix or remove mycelarch dead path.  
4. Haptics: implement or remove option.  

Then re-test with full assets + `--mobile-ui`.

---

## Size note

HUD PNGs here are **downscaled** for transfer. Do not ship these as production art — restore from full `RiftLine` repo when exporting.
