# RIFTLINE: LAST TRAIN

Steampunk train-defense roguelite (Godot 4.7). Hold the rails through the Rustlands, manage reactor power, mount weapons, and survive.

**Package:** `com.riftline.lasttrain` · **Version:** see `project.godot` / `export_presets.cfg`

## Run (desktop / mobile preview)

1. Install [Godot 4.7.2](https://godotengine.org/download).
2. Open this folder in Godot, or double-click `open_in_godot_editor.bat`.
3. Play: `run_game.bat` or **F5**.
4. Phone-shaped preview: `run_mobile_preview.bat`.

## Project layout

| Path | Purpose |
|------|---------|
| `scripts/` | Game logic (`GodotMain.gd`, HUD, combat systems) |
| `scenes/` | Godot scenes |
| `assets/` | Runtime art, audio, UI |
| `android/` | Android Gradle template (local; not committed) |
| `export_presets.cfg.example` | Android export presets template (copy → `export_presets.cfg`, add keystore password locally) |
| `export_play_aab.bat` | Build Play Store `.aab` |

## Android / Play Store

1. Copy `export_presets.cfg.example` → `export_presets.cfg` and set your release keystore path + password (file is gitignored).
2. Install Android Build Template once: **Project → Install Android Build Template**.
3. Sideload APK: export preset **Android Release**.
4. Play Store AAB: `export_play_aab.bat` or preset **Android Play Store AAB**.
5. Details: `build/android/PLAY_STORE.md` (after you export once).

## Requirements

- Godot **4.7.2**
- For Android: JDK 17, Android SDK, export templates matching the editor version
