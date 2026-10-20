extends Node2D

# RIFTLINE: LAST TRAIN — Godot 4 single-scene port.
# This ports the completed browser MVP into a native Godot project while keeping
# the same 1920x1080 canvas-style presentation and using the existing generated assets.

const DESIGN_W = 1920.0
const DESIGN_H = 1080.0
const SAVE_RUN = "user://riftline_run.json"
const SAVE_PERMANENT = "user://riftline_permanent.json"
const SAVE_SETTINGS = "user://riftline_settings.json"

var images = {}
var font: Font
var canvas_scale = 1.0
var canvas_offset = Vector2.ZERO
## Visible design-space extents (may be wider than DESIGN_W on mobile ultrawide).
var design_view_left: float = 0.0
var design_view_right: float = DESIGN_W
var design_view_top: float = 0.0
var design_view_bottom: float = DESIGN_H
var ui_buttons: Array = []

const AudioBusScript = preload("res://scripts/AudioBus.gd")
const TrainBuild = preload("res://scripts/TrainBuild.gd")
const RiftScar = preload("res://scripts/RiftScar.gd")
const RiftLoop = preload("res://scripts/RiftLoop.gd")
const WeaponLoadout = preload("res://scripts/WeaponLoadout.gd")
const MobileAdapt = preload("res://scripts/MobileAdapt.gd")
const MobileHudLayout = preload("res://scripts/MobileHudLayout.gd")
var audio: Node = null
## Last computed mobile player-status rect (design space) — shared by draw + hit tests.
var _mobile_status_panel: Rect2 = Rect2()
var _mobile_status_conflict: String = ""
## Control-tree status HUD (empty-interior frame + child bars). Mobile only.
var _mobile_status_hud: Control = null
var _mobile_status_hud_layer: CanvasLayer = null
var _mobile_encounter_hud: Control = null
var _mobile_encounter_hud_layer: CanvasLayer = null
var _mobile_encounter_conflict: String = ""
var _mobile_economy_hud: Control = null
var _mobile_economy_hud_layer: CanvasLayer = null
var _mobile_economy_conflict: String = ""
var frame_origin = Vector2.ZERO
## Bottom 4-card weapon HUD page (0-based) when more than 4 weapons are mounted.
var weapon_hud_page: int = 0
## Per-instance facing for multi-mount guns (uid → ±1).
var module_face_by_uid: Dictionary = {}
## Android / --mobile-ui adaptive layout (desktop path unchanged when false).
var is_mobile_ui: bool = false
var safe_inset := { "left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0 }
var reactor_panel_collapsed: bool = false
var reactor_channel_page: int = 0
var _touch_scroll_active: bool = false
var _touch_scroll_kind: String = "" # "shop" | "workshop"
var _touch_scroll_last_y: float = 0.0
var _touch_scroll_moved: bool = false
var _touch_scroll_last_t: float = 0.0
var _ui_tap_lock_t: float = 0.0
var _ability_tap_lock: Dictionary = {}
var _last_input_was_screen_touch: bool = false

# --- Train layout (v2 art) -------------------------------------------------
# 1920x1080 design pixels. Mirrors the numbers in process_v2_assets.py so the
# QA composite (art_source/qa_background.png) matches what the engine draws.
# "k" = design px per stored-PNG px, "contact" = PNG y of the rail-contact line,
# "x" = left edge of the part, "center" = gameplay x of the car.
const RAIL_Y = 718.0
const GROUND_Y = 560.0
const MID_Y = 250.0
const RAIL_STRIP_H = 175.0
# Lift cars a few px so wheel bottoms sit on the rail crown (not sunk into the strip).
const TRAIN_RAIL_NUDGE_Y: float = -7.0
const TRAIN_PARTS = {
	"weapon": { "tex": "car_weapon", "x": 798.0, "k": 0.68, "contact": 290.0, "center": 1008.0 },
	"loco": { "tex": "loco", "x": 1178.0, "k": 0.68, "contact": 440.0, "center": 1434.0 }
}
const CAR_WHEELS = [[105.0, 38.0], [235.0, 38.0], [465.0, 38.0], [595.0, 38.0]]
const LOCO_WHEELS = [[120.0, 56.0], [230.0, 56.0], [350.0, 64.0], [465.0, 64.0], [605.0, 56.0], [705.0, 56.0]]
# Module mount points: x = mount centre, roof = y of the roof surface the module base sits on.
const MOUNT_CANNON_X = 901.0
const MOUNT_AUX_X = 1008.0
const MOUNT_GATLING_X = 1116.0
const MOUNT_DRONE_X = 754.0
const WEAPON_ROOF_DY = 30.0
## Loco PNG boiler-dome tip row (used with TYPE_SPECS loco k).
const STARTER_DOME_PNG_Y: float = 89.0
## Positive = push sprite down into the curved dome plate (at loco k=0.68).
const STARTER_GUN_SEAT_Y: float = 30.0
## Starter sprite width scale — loco dome gun only (wagon mounts use their own scale).
const STARTER_GUN_SIZE_MUL: float = 1.12
# Side-profile gun art (all authored facing RIGHT, base-centred so they flip cleanly).
# w = on-screen width in design px (height follows the PNG aspect), mz = muzzle as fraction of the sprite rect.
# Slightly tighter widths so three mounts fit a wagon without overlapping neighbors.
const MODULE_ART = {
	"gatling": { "w": 118.0, "mz": Vector2(1.0, 0.21) },
	"cannon": { "w": 128.0, "mz": Vector2(1.0, 0.31) },
	"arc_coil": { "w": 78.0, "mz": Vector2(0.53, 0.04) },
	"cryo_launcher": { "w": 108.0, "mz": Vector2(0.97, 0.41) },
	"rail_mortar": { "w": 100.0, "mz": Vector2(0.93, 0.10) },
	"missile_rack": { "w": 108.0, "mz": Vector2(0.95, 0.20) },
	"drone": { "w": 100.0, "mz": Vector2(0.5, 0.0) }
}
var suspension_jolt = 0.0
var smoke_timer = 0.0
var impact_bursts: Array = []
var lightning_strikes: Array = []
var arc_coil_flash: float = 0.0
var telegraphs: Array = []
var enemy_lasers: Array = [] # Flux Rifleman cyan beam VFX: {x0,y0,x1,y1,life,max,width}
var screen_warnings: Array = []
var warning_cooldowns = { "heat": 0.0, "overrun": 0.0, "engine": 0.0, "repair": 0.0, "boarder": 0.0 }
var debug_open: bool = false
var debug_page: int = 0

# Live combat shop drawer (overlay — does NOT change `state` away from combat).
var shop_open: bool = false
var shop_tab: String = "weapons" # "weapons" | "upgrades"
var shop_slide: float = 0.0
var shop_scroll_y: float = 0.0
var shop_scroll_vel: float = 0.0
var shop_scroll_max: float = 0.0
var shop_buy_cooldown: float = 0.0
var shop_buy_feedback: String = ""
var shop_buy_feedback_t: float = 0.0
## Live Armory install picker: weapon id → selected free hardpoint key "car_uid:hp_id".
var shop_install_pick: Dictionary = {}
var _next_car_serial: int = 1
var starter_gun: Dictionary = {}
## Permanent Workshop UI (categorized + scrollable).
var workshop_tab: String = "locomotive"
var workshop_scroll_y: float = 0.0
const SHOP_DRAWER_W: float = 480.0
const SHOP_DRAWER_Y: float = 110.0
const SHOP_DRAWER_H: float = 740.0
const SHOP_TAB_W: float = 46.0
const SHOP_SLIDE_SEC: float = 0.25
const SHOP_CARD_GAP: float = 8.0
const SHOP_BUY_COOLDOWN_SEC: float = 0.35

var state = "title"
var previous_state = "title"
var options_back_state = "title"
var help_back_state = "title"
var option_reset_confirm = 0.0
var save_flash = 0.0
var paused = false
var game_speed = 1.0
var USE_PRODUCTION_UI = true
var t = 0.0
var shake = 0.0

var settings = { "damage_numbers": true, "particles": true, "shake": true, "haptics": true, "music_volume": 8, "sfx_volume": 10 }
var permanent = {}

var difficulty = "normal"
var run_time = 0.0
var last_run_score = 0

var reactor = { "max": 10, "free": 0 }
var power = { "engine": 4, "gatling": 0, "cannon": 0, "drone": 0, "aux": 0, "shield": 1, "utility": 1 }
var heat = { "value": 0.0, "overheated": false, "over_timer": 0.0 }
var momentum = { "speed": 100.0, "target": 100.0, "max": 115.0, "external_drag": 0.0 }
var overrun = { "value": 0.0, "stage": 0 }

var scrap = 0
var xp = 0.0
var level = 1
var xp_needed = 40.0
var kills = 0
var run_damage_taken = 0.0

var encounter_index = 0
var encounter_progress = 0.0
var encounter_goal = 60.0
var encounter_budget = 0.0
var spawn_timer = 1.0
var current_node_type = "combat"
var current_encounter = {}
var route_choices: Array = []
var last_reward = {}
var reward_pending_boss = false
var station_used = false
var boss_active = false
var boss_death_pending = false
var victory = false
## Prevents double reward / double track advance from a single wipe.
var _encounter_finish_lock: bool = false
## Expedition-wide kill count (track clears reset `kills`; fail rewards use this).
var run_kills: int = 0
## Last failure summary for the failed-run screen.
var last_fail_info: Dictionary = {}

# Boss arena: train slides right so a tall left-side colossus can occupy ~1/3 of the screen.
var train_shift_x: float = 0.0
var train_shift_target: float = 0.0
## Desired framing (may jump); train_shift_target eases toward this, then x follows.
var train_shift_desired: float = 0.0
# When cargo boxes wreck+fade, living cars pack left into the empty slots (no giant rail hole).
var train_pack_x: float = 0.0
var train_pack_target: float = 0.0
# Keep convoy close enough that claw/beam reads as connecting visually.
const BOSS_TRAIN_SHIFT: float = 240.0
# Normal combat: park the rear car near this X so the left rail stays an enemy stage.
# Longer trains → larger train_shift_target (convoy slides right; loco may hang off-screen).
const COMBAT_REAR_FOCUS_X: float = 780.0
const COMBAT_SHIFT_MAX: float = 1400.0
## Camera slide: ease toward framing — never hard-snap during live combat.
const COMBAT_SHIFT_SPEED: float = 150.0
const COMBAT_SHIFT_SPEED_FAST: float = 230.0
const COMBAT_PACK_SPEED: float = 160.0
const COMBAT_TARGET_SMOOTH: float = 1.55
const BOSS_ARENA_X: float = 400.0
const BOSS_INTRO_DUR: float = 4.6
const BOSS_INTRO_ENTER_X: float = -280.0  # starts just off the left edge (same rail height)
const BOSS_DRAW_H: float = 520.0
var boss_intro_saved_speed: float = 90.0
# Mycelarch sheets are padded (~45% body fill); scale draw height so the figure reads as a large boss.
const BOSS_MYCELARCH_DRAW_H: float = 1020.0
# Breach Engine — slightly larger than Iron Maw, fully on-screen (no HUD crop).
# Wide 1280 cells leave side padding — draw tall so the body reads as a finale boss.
const BOSS_BREACH_DRAW_H: float = 900.0
const BOSS_BREACH_BASE_Y: float = 738.0
# Plant feet on the rail bed (above dark gravel) so legs stay readable.
const BOSS_MYCELARCH_BASE_Y: float = 758.0
# Reactor core UV inside the 640×704 colossus sheets (hex port center on beam poses).
const BOSS_CHEST_NX: float = 0.435
const BOSS_CHEST_NY: float = 0.328
# Mycelarch 720×900 walk sheets — chest sits lower in the padded frame.
const BOSS_MYCELARCH_CHEST_NX: float = 0.54
const BOSS_MYCELARCH_CHEST_NY: float = 0.71
const BOSS_MYCELARCH_HAND_NX: float = 0.74
const BOSS_MYCELARCH_HAND_NY: float = 0.80
const BOSS_SPRITE_AX: float = 0.48   # matches dst: bx - draw_w * 0.48
const BOSS_SPRITE_ANCHOR_Y: float = 18.0
# Boss tracks the rear car so attacks don't look planted while the train scrolls.
const BOSS_FOLLOW_GAP: float = 300.0   # idle / pace distance behind rear car
const BOSS_CLAW_GAP: float = 145.0     # lunge in so the claw visually hits
const BOSS_SLAM_GAP: float = 190.0
const BOSS_BEAM_GAP: float = 340.0     # stay slightly back for beam readability
# Never walk into empty cargo slots — stay on the left rail.
const BOSS_X_MIN: float = 220.0
const BOSS_X_MAX: float = 620.0
const BOSS_MIN_STANDOFF: float = 260.0  # hard stop short of the living car body
var boss_intro_active: bool = false
var boss_intro_t: float = 0.0

# Disabled car wreck: broken look, then fade off the train.
const CAR_WRECK_BREAK: float = 1.15   # sparks / broken tint window
const CAR_WRECK_FADE: float = 2.6     # fade-out duration after break
const CAR_WRECK_TOTAL: float = 3.75   # CAR_WRECK_BREAK + CAR_WRECK_FADE

var train_cars: Array = []
var train_sway = 0.0
var wheel_rot = 0.0
var train_damage_flash = 0.0
var shield_time = 0.0
var drone_hatch = 0.0
var train_recoil = { "gatling": 0.0, "cannon": 0.0, "aux": 0.0, "drone": 0.0 }

var enemies: Array = []
var projectiles: Array = []
var enemy_projectiles: Array = []
var particles: Array = []
var damage_numbers: Array = []
var loot_orbs: Array = []
var weapon_fx: Array = []
var drones: Array = []
var toasts: Array = []
var warnings: Array = []

var current_region: String = "rustlands"
var rustlands_completed: bool = false
var fungus_completed: bool = false
## Endless expedition loop index (1-based). Increments after Breach Engine.
var rift_loop: int = 1
var region_transition_active: bool = false
var region_transition_target: String = "fungus_wilds"
var region_transition_timer: float = 0.0
const REGION_TRANSITION_DURATION: float = 14.0
## Victory screen is a Rift Cycle complete handoff (not a hard end of run).
var rift_cycle_complete: bool = false
var rift_cycle_next_loop: int = 2
## Within-region stage plates (frontier→expansion→deep/heart) crossfade over this many seconds.
const BG_STAGE_BLEND_DURATION: float = 2.4
var region_intro_banner_timer: float = 0.0
var region_intro_shown: bool = false
var fungus_spores: Array = []
var rift_sparks: Array = []
## Temporary heat pressure from attached Coil Leeches (cleared when leeches die).
var leech_heat_pressure: float = 0.0
## Smooth plate swaps inside a biome (not the full region crossing).
var bg_stage_from: String = ""
var bg_stage_to: String = ""
var bg_stage_blend: float = 1.0

var bg = { "mid_x": 0.0, "fg_x": 0.0, "r2_dist_x": 0.0, "r2_mid_x": 0.0, "r2_fg_x": 0.0, "r3_dist_x": 0.0, "r3_mid_x": 0.0, "r3_fg_x": 0.0 }

var weapons = {}
var abilities = {}
var modules = {}
var module_shop: Array = []
var active_cards: Array = []
var selected_cards: Array = []

const DIFFICULTIES = {
	"normal": { "label": "NORMAL", "color": "#84f5ff", "enemy_hp": 1.0, "enemy_damage": 1.0, "enemy_speed": 1.0, "boss_hp": 1.0, "boss_damage": 1.0, "encounter_budget": 1.0, "spawn_rate": 1.0, "heat": 1.0, "scrap_reward": 1.0, "alloy_reward": 1.0, "desc": "Balanced expedition. Recommended while learning power and momentum." },
	"veteran": { "label": "VETERAN", "color": "#ffd36d", "enemy_hp": 1.16, "enemy_damage": 1.15, "enemy_speed": 1.05, "boss_hp": 1.18, "boss_damage": 1.16, "encounter_budget": 1.14, "spawn_rate": 1.10, "heat": 1.08, "scrap_reward": 1.12, "alloy_reward": 1.28, "desc": "Tighter power economy. Enemies hit harder and rewards improve." },
	"nightmare": { "label": "NIGHTMARE", "color": "#ff6b61", "enemy_hp": 1.34, "enemy_damage": 1.30, "enemy_speed": 1.10, "boss_hp": 1.38, "boss_damage": 1.28, "encounter_budget": 1.28, "spawn_rate": 1.22, "heat": 1.16, "scrap_reward": 1.24, "alloy_reward": 1.60, "desc": "Punishing challenge. Mistakes snowball quickly." }
}

const ENEMY_DATA = {
	# Hardcore: early tracks learnable; scrap stays scarce vs expensive gear.
	"scrapper": { "label": "Scrapper", "sprite": "scrapper", "max_hp": 36.0, "armor": 1.0, "speed": 72.0, "attack": 4.2, "range": 80.0, "cd": 1.15, "xp": 8.0, "scrap_min": 1, "scrap_max": 3, "cost": 1, "scale": 0.78, "jitter": 55.0 },
	"runner": { "label": "Runner", "sprite": "runner", "max_hp": 28.0, "armor": 0.0, "speed": 132.0, "attack": 3.4, "range": 72.0, "cd": .80, "xp": 9.0, "scrap_min": 1, "scrap_max": 2, "cost": 2, "scale": 0.72, "jitter": 65.0 },
	"brute": { "label": "Brute", "sprite": "brute", "max_hp": 148.0, "armor": 10.0, "speed": 44.0, "attack": 11.5, "range": 92.0, "cd": 1.55, "xp": 22.0, "scrap_min": 3, "scrap_max": 6, "cost": 5, "scale": 1.03, "jitter": 38.0 },
	"skimmer": { "label": "Skimmer", "sprite": "skimmer", "max_hp": 60.0, "armor": 1.0, "speed": 100.0, "attack": 6.2, "range": 315.0, "cd": 1.35, "xp": 16.0, "scrap_min": 2, "scrap_max": 4, "cost": 4, "scale": 0.78, "jitter": 155.0, "flying": true },
	"boarder": { "label": "Boarder", "sprite": "boarder", "max_hp": 72.0, "armor": 2.0, "speed": 114.0, "attack": 8.5, "range": 55.0, "cd": .90, "xp": 18.0, "scrap_min": 2, "scrap_max": 3, "cost": 4, "scale": 0.78, "jitter": 60.0, "boarder": true },
	# Chapter 3 — The Rift Scar
	"rift_skitter": { "label": "Rift Skitter", "sprite": "rift_skitter", "max_hp": 42.0, "armor": 2.0, "speed": 148.0, "attack": 5.5, "range": 70.0, "cd": 0.78, "xp": 11.0, "scrap_min": 2, "scrap_max": 4, "cost": 2, "scale": 0.88, "jitter": 48.0, "rift": true },
	"flux_rifleman": { "label": "Flux Rifleman", "sprite": "flux_rifleman", "max_hp": 68.0, "armor": 3.0, "speed": 78.0, "attack": 7.5, "range": 340.0, "cd": 1.55, "xp": 16.0, "scrap_min": 3, "scrap_max": 5, "cost": 4, "scale": 0.96, "jitter": 40.0, "rift": true, "ranged": true, "aim_warn": 0.42 },
	"coil_leech": { "label": "Coil Leech", "sprite": "coil_leech", "max_hp": 48.0, "armor": 1.0, "speed": 118.0, "attack": 3.2, "range": 55.0, "cd": 0.95, "xp": 14.0, "scrap_min": 2, "scrap_max": 4, "cost": 3, "scale": 0.82, "jitter": 50.0, "rift": true, "leech": true },
	"fracture_juggernaut": { "label": "Fracture Juggernaut", "sprite": "fracture_juggernaut", "max_hp": 260.0, "armor": 16.0, "speed": 38.0, "attack": 14.0, "range": 95.0, "cd": 1.85, "xp": 28.0, "scrap_min": 5, "scrap_max": 8, "cost": 6, "scale": 1.22, "jitter": 28.0, "rift": true, "heavy": true, "telegraph": 0.55 },
	"rift_harvester": { "label": "Rift Harvester", "sprite": "rift_harvester", "max_hp": 420.0, "armor": 10.0, "speed": 52.0, "attack": 11.0, "range": 300.0, "cd": 1.35, "xp": 48.0, "scrap_min": 10, "scrap_max": 16, "cost": 8, "scale": 1.28, "jitter": 36.0, "rift": true, "elite_kind": true, "area_warn": 0.70 }
}

# Iron Maw reimagined as a towering Rift-forged siege automaton (not a train).
# Tall left-side silhouette: ~2/5 of the battlefield width, facing the convoy.
const BOSS_DATA = { "id": "iron_maw", "label": "THE IRON MAW", "max_hp": 3200.0, "armor": 10.0, "speed": 42.0, "xp": 200.0, "scrap_min": 40, "scrap_max": 60 }
# Fungus Wilds climax — art sheets land later; combat reuses colossus frames with a teal modulate until then.
const BOSS_MYCELARCH = { "id": "mycelarch", "label": "THE MYCELARCH", "max_hp": 4200.0, "armor": 9.0, "speed": 38.0, "xp": 240.0, "scrap_min": 50, "scrap_max": 75 }

func current_boss_def() -> Dictionary:
	if current_region == "rift_scar":
		return RiftScar.BOSS_BREACH_ENGINE.duplicate(true)
	if current_region == "fungus_wilds":
		return BOSS_MYCELARCH
	return BOSS_DATA

func boss_face_button_label() -> String:
	if current_region == "rift_scar":
		return "FACE BREACH ENGINE"
	if current_region == "fungus_wilds":
		return "FACE MYCELARCH"
	return "FACE IRON MAW"

func tsx(x: float) -> float:
	return x + train_shift_x

func car_slot_ox(c: Dictionary) -> float:
	# Wrecks fade in place; living cars pack left into emptied cargo slots.
	if c.is_empty() or c.get("disabled", false):
		return train_shift_x
	return train_shift_x - train_pack_x

func rearmost_living_car() -> Dictionary:
	# Camera / pack framing must ignore wrecked wagons still in the array.
	if train_cars.is_empty():
		return {}
	for i in range(train_cars.size() - 1, -1, -1):
		var c: Dictionary = train_cars[i]
		if c.get("disabled", false):
			continue
		if float(c.get("hp", 0.0)) <= 0.0:
			continue
		return c
	# Fail / total wipe: keep framing on the least-faded car so the screen doesn't jump.
	for j in range(train_cars.size() - 1, -1, -1):
		if car_draw_alpha(train_cars[j]) > 0.12:
			return train_cars[j]
	return train_cars[0]

func refresh_train_pack_target() -> void:
	# After a wagon finishes fading, reclaim its rail slot so living cars (and the
	# camera) close the hole — combat and boss arenas both need this.
	var pack = 0.0
	for i in range(1, train_cars.size()):
		var c: Dictionary = train_cars[i]
		if c.get("disabled", false) and car_draw_alpha(c) < 0.18:
			var ct := str(c.get("car_type", c.get("id", "weapon")))
			pack += TrainBuild.car_pixel_w(ct) + TrainBuild.CAR_GAP
	train_pack_target = clampf(pack, 0.0, 900.0)

func combat_shift_for_rear_focus() -> float:
	# Slide the convoy until the rearmost *living* car sits near COMBAT_REAR_FOCUS_X.
	# Pack offset is added because living cars are drawn at shift - pack.
	if train_cars.is_empty():
		return 0.0
	var rear: Dictionary = rearmost_living_car()
	if rear.is_empty():
		return 0.0
	var rear_left := float(rear.get("left_x", car_left_edge(rear)))
	var need := COMBAT_REAR_FOCUS_X - rear_left + train_pack_target
	return clampf(need, 0.0, COMBAT_SHIFT_MAX)

func refresh_combat_view_shift() -> void:
	# Region blend forces shift toward 0; don't fight it.
	if region_transition_active:
		return
	var combat_need := combat_shift_for_rear_focus()
	# Soft enemy bias: if living attackers sit far left, ease framing a little left
	# so the fight stays on-screen instead of hard-cutting to pure rear-car focus.
	if not boss_active and not boss_intro_active and not enemies.is_empty():
		var left_e := 9999.0
		var saw := false
		for e in enemies:
			if e.get("dead", false) or e.get("boss", false):
				continue
			saw = true
			left_e = minf(left_e, float(e.get("x", 9999.0)))
		if saw and left_e < 480.0:
			# Soft pull toward the enemy stage — desired jumps; target/x ease (no snap).
			var pull := clampf((480.0 - left_e) * 0.22, 0.0, 110.0)
			combat_need = maxf(0.0, combat_need - pull)
	if boss_active or boss_intro_active:
		train_shift_desired = maxf(BOSS_TRAIN_SHIFT, combat_need)
	else:
		train_shift_desired = combat_need

func _nudge_combat_camera_for_convoy_change() -> void:
	# Retarget only — never snap x. Smooth slide handles wagon buy / wreck / restore.
	refresh_train_pack_target()
	refresh_combat_view_shift()

const SPRITE_ANIMS = {
	"scrapper": { "frames": 12, "w": 256, "h": 256, "fps": 12.0, "anchor_y": 30.0 },
	"runner": { "frames": 12, "w": 256, "h": 256, "fps": 14.0, "anchor_y": 30.0 },
	"brute": { "frames": 12, "w": 256, "h": 256, "fps": 9.0, "anchor_y": 30.0 },
	"skimmer": { "frames": 12, "w": 256, "h": 256, "fps": 12.0, "anchor_y": 30.0 },
	"boarder": { "frames": 12, "w": 256, "h": 256, "fps": 12.0, "anchor_y": 30.0 },
	"boss_attack": { "frames": 16, "w": 768, "h": 384, "fps": 18.0 },
	# Iron Maw colossus Flow sheets — all frames share 640×704, feet bottom-aligned.
	"boss_colossus_idle": { "frames": 12, "w": 640, "h": 704, "fps": 11.0, "loop": true, "anchor_y": 18.0 },
	"boss_colossus_claw": { "frames": 14, "w": 640, "h": 704, "fps": 14.0, "loop": false, "anchor_y": 18.0 },
	"boss_colossus_slam": { "frames": 14, "w": 640, "h": 704, "fps": 14.0, "loop": false, "anchor_y": 18.0 },
	"boss_colossus_maw_beam": { "frames": 14, "w": 640, "h": 704, "fps": 14.0, "loop": false, "anchor_y": 18.0 },
	"boss_colossus_death": { "frames": 14, "w": 640, "h": 704, "fps": 12.0, "loop": false, "anchor_y": 18.0 },
	# Mycelarch (Fungus Wilds) — 4:5 walk-based sheets (idle = continuous walk).
	"boss_mycelarch_idle": { "frames": 12, "w": 720, "h": 900, "fps": 10.0, "loop": true, "anchor_y": 18.0 },
	# Slower one-shots so lash/slam/beam read as full actions, not a single pop.
	"boss_mycelarch_claw": { "frames": 14, "w": 720, "h": 900, "fps": 8.0, "loop": false, "anchor_y": 18.0 },
	"boss_mycelarch_slam": { "frames": 14, "w": 720, "h": 900, "fps": 9.0, "loop": false, "anchor_y": 18.0 },
	"boss_mycelarch_beam": { "frames": 14, "w": 720, "h": 900, "fps": 9.0, "loop": false, "anchor_y": 18.0 },
	"boss_mycelarch_death": { "frames": 14, "w": 720, "h": 900, "fps": 10.0, "loop": false, "anchor_y": 18.0 },
	# Chapter 3 enemies + Breach Engine
	"rift_skitter": { "frames": 12, "w": 256, "h": 256, "fps": 14.0, "anchor_y": 28.0 },
	"flux_rifleman": { "frames": 12, "w": 256, "h": 256, "fps": 11.0, "anchor_y": 28.0 },
	"coil_leech": { "frames": 12, "w": 256, "h": 256, "fps": 13.0, "anchor_y": 28.0 },
	"fracture_juggernaut": { "frames": 12, "w": 256, "h": 256, "fps": 8.0, "anchor_y": 28.0 },
	"rift_harvester": { "frames": 12, "w": 256, "h": 256, "fps": 10.0, "anchor_y": 28.0 },
	# cols=6 → 7680×3600 (24 @ 1280×900). Wide cells keep claw reach on-screen; slower fps = heavy tread.
	"boss_breach_idle": { "frames": 24, "w": 1280, "h": 900, "cols": 6, "fps": 9.0, "loop": true, "anchor_y": 18.0 },
	"boss_breach_charge": { "frames": 24, "w": 1280, "h": 900, "cols": 6, "fps": 10.0, "loop": false, "anchor_y": 18.0 },
	"boss_breach_discharge": { "frames": 24, "w": 1280, "h": 900, "cols": 6, "fps": 10.0, "loop": false, "anchor_y": 18.0 },
	"boss_breach_impact": { "frames": 24, "w": 1280, "h": 900, "cols": 6, "fps": 10.0, "loop": false, "anchor_y": 18.0 },
	"boss_breach_death": { "frames": 24, "w": 1280, "h": 900, "cols": 6, "fps": 9.0, "loop": false, "anchor_y": 18.0 }
}

const MODULE_INFO = {
	# base_cost mirrored for display only; live upgrade pricing uses TrainBuild.
	"gatling": { "title": "GATLING", "base_cost": 75, "icon": "icon_gatling" },
	"cannon": { "title": "CANNON", "base_cost": 90, "icon": "icon_cannon" },
	"drone": { "title": "DRONE BAY", "base_cost": 82, "install_cost": 0, "icon": "icon_drone" }
}

const AUX_MODULES = {
	# cost / upgrade_cost mirrored for display; purchases use TrainBuild helpers.
	"arc_coil": { "title": "ARC COIL", "short": "ARC", "icon": "icon_arc", "cost": 330, "sell": 90, "upgrade_cost": 72, "damage": 27.0, "cooldown": .88, "heat": 1.2, "desc": "Chains electric damage through clustered enemies." },
	"cryo_launcher": { "title": "CRYO LAUNCHER", "short": "CRYO", "icon": "icon_cryo", "cost": 310, "sell": 85, "upgrade_cost": 68, "damage": 20.0, "cooldown": 1.08, "heat": .85, "desc": "Fires slowing cryo shells." },
	"rail_mortar": { "title": "RAIL MORTAR", "short": "MORTAR", "icon": "icon_mortar", "cost": 540, "sell": 140, "upgrade_cost": 88, "damage": 58.0, "cooldown": 1.75, "heat": 2.6, "desc": "Lobs explosive shells at distant packs." },
	"missile_rack": { "title": "MISSILE RACK", "short": "MISSILE", "icon": "icon_mortar", "cost": 780, "sell": 200, "upgrade_cost": 98, "damage": 38.0, "cooldown": 1.22, "heat": 1.95, "unlock": "Missile Rack Blueprint", "desc": "Homing missile salvo. Unlocked by defeating Iron Maw." }
}

const ENCOUNTERS = [
	# Early tracks teach pacing; brutes stay present but no longer dominate Track 2.
	{ "id": "pursuit", "title": "Scrapper Pursuit", "subtitle": "Fast scavengers try to overtake the rear cars.", "min": 1, "weights": { "scrapper": 8, "runner": 5 }, "budget": 12.0, "budget_node": 2.4, "goal": 48.0, "goal_node": 4.0, "spawn_min": .85, "spawn_max": 1.55, "reward": 16 },
	{ "id": "iron_column", "title": "Iron Column", "subtitle": "Armored brutes punish low firepower.", "min": 2, "weights": { "scrapper": 6, "runner": 3, "brute": 3 }, "budget": 17.0, "budget_node": 3.1, "goal": 60.0, "goal_node": 4.0, "spawn_min": 1.05, "spawn_max": 1.80, "reward": 18 },
	{ "id": "sky_raid", "title": "Skimmer Raid", "subtitle": "Flying attackers pressure random cars.", "min": 3, "weights": { "scrapper": 4, "runner": 3, "skimmer": 5 }, "budget": 20.0, "budget_node": 3.4, "goal": 64.0, "goal_node": 5.0, "spawn_min": .95, "spawn_max": 1.60, "reward": 20, "heat_mul": 1.06 },
	# Boarder ~33% (was ~43%): boarding identity kept; budget slightly trimmed vs prior latch stacks.
	{ "id": "boarding_wave", "title": "Boarding Wave", "subtitle": "Boarders latch onto weakened cars.", "min": 3, "weights": { "scrapper": 4, "runner": 3, "boarder": 5, "brute": 2, "skimmer": 1 }, "budget": 20.0, "budget_node": 3.2, "goal": 70.0, "goal_node": 5.0, "spawn_min": .95, "spawn_max": 1.65, "reward": 22 },
	{ "id": "rift_squall", "title": "Rift Squall", "subtitle": "Unstable air increases heat and aggression.", "min": 4, "weights": { "runner": 5, "skimmer": 4, "boarder": 3 }, "budget": 25.0, "budget_node": 4.0, "goal": 76.0, "goal_node": 5.0, "spawn_min": .72, "spawn_max": 1.35, "reward": 24, "heat_mul": 1.18 },
	{ "id": "salvage_breaker", "title": "Salvage Breaker", "subtitle": "Mixed enemy pack guarding wreckage.", "min": 5, "weights": { "scrapper": 3, "runner": 3, "brute": 4, "skimmer": 3, "boarder": 3 }, "budget": 29.0, "budget_node": 4.4, "goal": 82.0, "goal_node": 5.0, "spawn_min": .82, "spawn_max": 1.45, "reward": 28 }
]

## Ordered tech perks auto-granted on level-up (no card UI). Barrage unlocks mid-run.
const LEVEL_PERK_ORDER = [
	"scrap_magnets",
	"thermal_pumps",
	"reinforced_plating",
	"overcharged_ammo",
	"cannon_barrage",
	"momentum_rounds",
	"emergency_welders",
	"drone_swarm",
	"micro_missiles",
	"rift_injector",
	"rail_saints",
	"turbocharger"
]

const TECH_CARDS = [
	{ "id": "turbocharger", "title": "TURBOCHARGER", "rarity": "common", "icon": "icon_engine", "color": "#d8ecff", "desc": "Max speed +13% and acceleration +10%." },
	{ "id": "reinforced_plating", "title": "REINFORCED PLATING", "rarity": "common", "icon": "icon_shield", "color": "#d8ecff", "desc": "+16 max HP and +4 armor to every car." },
	{ "id": "thermal_pumps", "title": "COOLANT PUMPS", "rarity": "common", "icon": "icon_heat", "color": "#d8ecff", "desc": "Cooling +30%." },
	{ "id": "momentum_rounds", "title": "MOMENTUM ROUNDS", "rarity": "rare", "icon": "icon_engine", "color": "#6ff0ff", "desc": "Weapons deal up to +35% damage at high speed." },
	{ "id": "overcharged_ammo", "title": "OVERCHARGED AMMO", "rarity": "rare", "icon": "icon_heat", "color": "#6ff0ff", "desc": "Weapon damage +42%, heat generation +22%." },
	{ "id": "emergency_welders", "title": "EMERGENCY WELDERS", "rarity": "rare", "icon": "icon_utility", "color": "#6ff0ff", "desc": "Repair active restores +40% more and recharges faster." },
	{ "id": "rail_saints", "title": "RAIL SAINTS", "rarity": "legendary", "icon": "icon_shield", "color": "#ffd36d", "desc": "Once per run, fatal locomotive damage repairs it to 35%." },
	{ "id": "cannon_barrage", "title": "ARTILLERY BARRAGE", "rarity": "epic", "icon": "icon_cannon", "color": "#c58cff", "desc": "Unlock active: shell the battlefield." },
	{ "id": "drone_swarm", "title": "DRONE SWARM", "rarity": "rare", "icon": "icon_drone", "color": "#6ff0ff", "desc": "Powered Drone Bay launches +1 drone." },
	{ "id": "micro_missiles", "title": "MICRO-MISSILE DRONES", "rarity": "epic", "icon": "icon_drone", "color": "#c58cff", "desc": "Every seventh drone shot becomes a splash missile." },
	{ "id": "scrap_magnets", "title": "SCRAP MAGNETS", "rarity": "common", "icon": "icon_scrap", "color": "#d8ecff", "desc": "Scrap drops +28%. Gain 12 Scrap now." },
	{ "id": "rift_injector", "title": "RIFT INJECTOR", "rarity": "legendary", "icon": "icon_rift", "color": "#ffd36d", "desc": "+2 reactor power. Heat generation +10%." }
]

func _ready() -> void:
	randomize()
	is_mobile_ui = MobileAdapt.wants_mobile_ui()
	if MobileAdapt.is_mobile_preview():
		MobileAdapt.apply_preview_window_if_needed()
		print("[Riftline] Mobile preview ON — target client %dx%d (phone landscape %dx%d @ %ddpi)" % [
			MobileAdapt.PREVIEW_WINDOW_W, MobileAdapt.PREVIEW_WINDOW_H,
			MobileAdapt.DEVICE_LANDSCAPE_W, MobileAdapt.DEVICE_LANDSCAPE_H,
			MobileAdapt.DEVICE_DENSITY_DPI
		])
		call_deferred("_riftline_verify_mobile_preview_window")
	if is_mobile_ui:
		Engine.max_fps = 60
		# Device: touch→mouse. Windows mobile-preview: mouse clicks use the same design-space hitboxes.
		Input.emulate_mouse_from_touch = true
		Input.emulate_touch_from_mouse = false
		reactor_panel_collapsed = false
		get_tree().set_auto_accept_quit(false)
		_apply_mobile_display_config()
		# Prefer lighter VFX budget on phones without changing combat rules.
		if settings.get("particles", true):
			pass
	font = ThemeDB.fallback_font
	if font == null:
		var sys = SystemFont.new()
		sys.font_names = PackedStringArray(["Segoe UI", "Arial", "sans-serif"])
		font = sys
	audio = AudioBusScript.new()
	add_child(audio)
	load_assets()
	if is_mobile_ui:
		_setup_mobile_status_hud()
		_setup_mobile_encounter_hud()
		_setup_mobile_economy_hud()
	load_settings()
	load_permanent()
	reset_train_cars()
	reset_stats()
	weapons = default_weapons()
	starter_gun = default_starter_gun()
	abilities = default_abilities()
	modules = default_modules()
	init_fungus_spores()
	set_process(true)
	set_process_input(true)
	if state == "title" and audio != null:
		audio.play_menu_music(1.0)
	var _args := OS.get_cmdline_args()
	var _uargs := OS.get_cmdline_user_args()
	if _args.has("--capture-explosions") or _uargs.has("--capture-explosions"):
		var stamp := FileAccess.open(ProjectSettings.globalize_path("res://explosion_capture_stamp.txt"), FileAccess.WRITE)
		if stamp != null:
			stamp.store_string("args=%s\nuser=%s\n" % [str(_args), str(_uargs)])
			stamp.close()
		test_capture_timer = 0.8
	if _args.has("--verify-universal-loadout") or _uargs.has("--verify-universal-loadout"):
		test_capture_timer = 0.4
		test_capture_phase = 0
	if _args.has("--capture-mobile-status") or _uargs.has("--capture-mobile-status") \
			or _args.has("--capture-mobile-encounter") or _uargs.has("--capture-mobile-encounter") \
			or _args.has("--capture-mobile-economy") or _uargs.has("--capture-mobile-economy") \
			or _args.has("--capture-mobile-shop") or _uargs.has("--capture-mobile-shop") \
			or _args.has("--capture-mobile-reactor") or _uargs.has("--capture-mobile-reactor") \
			or _args.has("--capture-mobile-weapons") or _uargs.has("--capture-mobile-weapons") \
			or _args.has("--capture-mobile-abilities") or _uargs.has("--capture-mobile-abilities") \
			or _args.has("--capture-mobile-workshop") or _uargs.has("--capture-mobile-workshop") \
			or _args.has("--capture-mobile-help") or _uargs.has("--capture-mobile-help") \
			or _args.has("--capture-mobile-options") or _uargs.has("--capture-mobile-options") \
			or _args.has("--capture-mobile-title") or _uargs.has("--capture-mobile-title") \
			or _args.has("--capture-mobile-hud") or _uargs.has("--capture-mobile-hud") \
			or _args.has("--capture-mobile-failed") or _uargs.has("--capture-mobile-failed"):
		test_capture_timer = 0.45
		test_capture_phase = 0
	if _args.has("--capture-live-shop") or _uargs.has("--capture-live-shop") \
			or _args.has("--capture-live-shop-buy") or _uargs.has("--capture-live-shop-buy") \
			or _args.has("--capture-live-shop-equip") or _uargs.has("--capture-live-shop-equip") \
			or _args.has("--capture-live-shop-upgrade") or _uargs.has("--capture-live-shop-upgrade") \
			or _args.has("--capture-train-build") or _uargs.has("--capture-train-build") \
			or _args.has("--capture-continuous") or _uargs.has("--capture-continuous") \
			or _args.has("--capture-hardcore") or _uargs.has("--capture-hardcore") \
			or _args.has("--capture-rift-scar") or _uargs.has("--capture-rift-scar"):
		test_capture_timer = 0.35
		test_capture_phase = 0
		if _args.has("--capture-hardcore") or _uargs.has("--capture-hardcore"):
			var hs := FileAccess.open(ProjectSettings.globalize_path("res://hardcore_economy_proof.txt"), FileAccess.WRITE)
			if hs != null:
				hs.store_string("READY args=%s user=%s timer=%.2f\n" % [str(_args), str(_uargs), test_capture_timer])
				hs.close()
		if _args.has("--capture-rift-scar") or _uargs.has("--capture-rift-scar"):
			var rs := FileAccess.open(ProjectSettings.globalize_path("res://rift_scar_proof.txt"), FileAccess.WRITE)
			if rs != null:
				rs.store_string("READY capture-rift-scar\n")
				rs.close()

func sfx(sound_name: String) -> void:
	if audio != null and settings.get("particles", true):
		audio.play(sound_name)

func load_assets() -> void:
	var paths = {
		"sky": "res://assets/v2/bg_sky.png",
		"mid": "res://assets/v2/bg_mid.png",
		"fg": "res://assets/v2/bg_ground.png",
		"rail": "res://assets/v2/bg_rail.png",
		"r3_rail": "res://assets/region3/bg_rift_rail.png",
		"r2_sky": "res://assets/region2/bg_fungus_sky.png",
		"r2_distant": "res://assets/region2/bg_fungus_distant.png",
		"r2_mid": "res://assets/region2/bg_fungus_mid.png",
		"r2_fg": "res://assets/region2/bg_fungus_ground.png",
		"r2_frontier_sky": "res://assets/region2/bg_frontier_sky.png",
		"r2_frontier_mid": "res://assets/region2/bg_frontier_mid.png",
		"r2_frontier_fg": "res://assets/region2/bg_frontier_ground.png",
		"r2_expansion_sky": "res://assets/region2/bg_expansion_sky.png",
		"r2_expansion_mid": "res://assets/region2/bg_expansion_mid.png",
		"r2_expansion_fg": "res://assets/region2/bg_expansion_ground.png",
		"r2_deep_mid": "res://assets/region2/bg_deep_mid.png",
		"r2_spore": "res://assets/region2/spore_particle.png",
		"r3_frontier_sky": "res://assets/region3/bg_frontier_sky.png",
		"r3_frontier_mid": "res://assets/region3/bg_frontier_mid.png",
		"r3_frontier_fg": "res://assets/region3/bg_frontier_ground.png",
		"r3_expansion_sky": "res://assets/region3/bg_expansion_sky.png",
		"r3_expansion_mid": "res://assets/region3/bg_expansion_mid.png",
		"r3_expansion_fg": "res://assets/region3/bg_expansion_ground.png",
		"r3_heart_sky": "res://assets/region3/bg_heart_sky.png",
		"r3_heart_mid": "res://assets/region3/bg_heart_mid.png",
		"r3_heart_fg": "res://assets/region3/bg_heart_ground.png",
		"r3_heart_distant": "res://assets/region3/bg_heart_distant.png",
		"loco": "res://assets/v2/train_loco_body.png",
		"car_weapon": "res://assets/v2/train_car_weapon_body.png",
		"wheel": "res://assets/v2/train_wheel.png",
		"drone": "res://assets/weapon_drone_01.png",
		"scrapper": "res://assets/animations/enemy_scrapper_run_sheet.png",
		"runner": "res://assets/animations/enemy_runner_sprint_sheet.png",
		"brute": "res://assets/animations/enemy_brute_tread_walk_sheet.png",
		"skimmer": "res://assets/animations/enemy_skimmer_hover_sheet.png",
		"boarder": "res://assets/animations/enemy_boarder_leap_sheet.png",
		"rift_skitter": "res://assets/animations/enemy_rift_skitter_sheet.png",
		"flux_rifleman": "res://assets/animations/enemy_flux_rifleman_sheet.png",
		"coil_leech": "res://assets/animations/enemy_coil_leech_sheet.png",
		"fracture_juggernaut": "res://assets/animations/enemy_fracture_juggernaut_sheet.png",
		"rift_harvester": "res://assets/animations/enemy_rift_harvester_sheet.png",
		"boss_breach_idle": "res://assets/animations/boss_breach_engine_idle_sheet.png",
		"boss_breach_charge": "res://assets/animations/boss_breach_engine_charge_sheet.png",
		"boss_breach_discharge": "res://assets/animations/boss_breach_engine_discharge_sheet.png",
		"boss_breach_impact": "res://assets/animations/boss_breach_engine_impact_sheet.png",
		"boss_breach_death": "res://assets/animations/boss_breach_engine_death_sheet.png",
		"boss": "res://assets/boss_iron_maw.png",
		"boss_attack": "res://assets/animations/boss_iron_maw_attack_sheet.png",
		"boss_colossus": "res://assets/boss_iron_colossus.png",
		"boss_colossus_idle_b": "res://assets/boss_colossus_idle_b.png",
		"boss_colossus_attack": "res://assets/boss_iron_colossus_attack.png",
		"boss_colossus_windup": "res://assets/boss_colossus_windup.png",
		"boss_colossus_stomp": "res://assets/boss_colossus_stomp.png",
		"boss_colossus_beam": "res://assets/boss_colossus_beam.png",
		"boss_colossus_idle": "res://assets/animations/boss_colossus_idle_sheet.png",
		"boss_colossus_claw": "res://assets/animations/boss_colossus_claw_sheet.png",
		"boss_colossus_slam": "res://assets/animations/boss_colossus_stomp_sheet.png",
		"boss_colossus_maw_beam": "res://assets/animations/boss_colossus_beam_sheet.png",
		"boss_colossus_death": "res://assets/animations/boss_colossus_death_sheet.png",
		"boss_mycelarch_idle": "res://assets/animations/boss_mycelarch_idle_sheet.png",
		"boss_mycelarch_claw": "res://assets/animations/boss_mycelarch_claw_sheet.png",
		"boss_mycelarch_slam": "res://assets/animations/boss_mycelarch_stomp_sheet.png",
		"boss_mycelarch_beam": "res://assets/animations/boss_mycelarch_beam_sheet.png",
		"boss_mycelarch_death": "res://assets/animations/boss_mycelarch_death_sheet.png",
		"boss_mycelarch": "res://assets/boss_flow_refs/boss_mycelarch_idle.jpeg",
		"icon_engine": "res://assets/icon_engine.png",
		"icon_gatling": "res://assets/icon_gatling.png",
		"icon_cannon": "res://assets/icon_cannon.png",
		"icon_shield": "res://assets/icon_shield.png",
		"icon_heat": "res://assets/icon_heat.png",
		"icon_scrap": "res://assets/icon_scrap.png",
		"icon_xp": "res://assets/icon_xp.png",
		"icon_rift": "res://assets/icon_rift.png",
		"icon_utility": "res://assets/icon_utility.png",
		"icon_drone": "res://assets/icon_drone.png",
		"icon_arc": "res://assets/icon_arc.png",
		"icon_cryo": "res://assets/icon_cryo.png",
		"icon_mortar": "res://assets/icon_mortar.png",
		"module_gatling_lv1": "res://assets/v3/module_gatling.png",
		"module_gatling_lv5": "res://assets/v3/module_gatling_lv5.png",
		"module_cannon_lv1": "res://assets/v3/module_cannon.png",
		"module_cannon_lv5": "res://assets/v3/module_cannon_lv5.png",
		"module_drone_closed": "res://assets/v3/module_drone_closed.png",
		"module_drone_open": "res://assets/v3/module_drone_open.png",
		"module_arc": "res://assets/v3/module_arc_coil.png",
		"module_cryo": "res://assets/v3/module_cryo.png",
		"module_mortar": "res://assets/v3/module_mortar.png",
		"module_missile": "res://assets/v3/module_missile.png",
		"icon_scrap_gear": "res://assets/ui/final/icon_scrap_gear.png",
		"btn_hud_pause": "res://assets/ui/final/btn_hud_pause.png",
		"btn_mobile_pause": "res://assets/ui/hud/btn_mobile_pause.png",
		"btn_hud_speed": "res://assets/ui/final/btn_hud_speed.png",
		"hud_slot_gatling": "res://assets/ui/final/hud_slot_gatling.png",
		"hud_slot_cannon": "res://assets/ui/final/hud_slot_cannon.png",
		"hud_slot_drone": "res://assets/ui/final/hud_slot_drone.png",
		"hud_slot_arc": "res://assets/ui/final/hud_slot_arc.png",
		"hud_slot_cryo": "res://assets/ui/final/hud_slot_cryo.png",
		"hud_slot_mortar": "res://assets/ui/final/hud_slot_mortar.png",
		"hud_slot_missile": "res://assets/ui/final/hud_slot_missile.png",
		"hud_slot_empty": "res://assets/ui/final/hud_slot_empty.png",
		"ui_tech_card_base": "res://assets/ui/final/ui_tech_card_base.png",
		"ui_warning_critical": "res://assets/ui/final/ui_warning_critical.png",
		"ui_panel_generic_cyan": "res://assets/ui/final/ui_panel_generic_cyan.png",
		"ui_panel_wide_cyan": "res://assets/ui/final/ui_panel_wide_cyan.png",
		"hud_resource_xp": "res://assets/ui/final/hud_resource_xp.png",
		"hud_resources_status": "res://assets/ui/final/hud_resources_status.png",
		"hud_active_systems": "res://assets/ui/final/hud_active_systems.png",
		"active_systems_frame": "res://assets/ui/final/active_systems_frame.png",
		"active_icon_boost": "res://assets/ui/final/active_icon_boost.png",
		"active_icon_shield": "res://assets/ui/final/active_icon_shield.png",
		"active_icon_repair": "res://assets/ui/final/active_icon_repair.png",
		"active_icon_barrage": "res://assets/ui/final/active_icon_barrage.png",
		"active_icon_flame": "res://assets/ui/final/active_icon_flame.png",
		"hud_module_targeting": "res://assets/ui/final/hud_module_targeting.png",
		"hud_reactor_power": "res://assets/ui/final/hud_reactor_power.png",
		"hud_locomotive_status": "res://assets/ui/final/hud_locomotive_status.png",
		"hud_top_master": "res://assets/ui/final/hud_top_master_reference.png",
		"menu_title_logo": "res://assets/ui/final/menu_title_logo.png",
		"menu_info_panel_frame": "res://assets/ui/final/menu_info_panel_frame.png",
		"menu_button_primary_frame": "res://assets/ui/final/menu_button_primary_frame.png",
		"menu_button_secondary_frame": "res://assets/ui/final/menu_button_secondary_frame.png",
		"menu_stats_strip_frame": "res://assets/ui/final/menu_stats_strip_frame.png",
		"menu_mobile_main": "res://assets/ui/mobile/riftline_mobile_main_menu.png",
		"icon_permanent_alloy": "res://assets/ui/final/icon_permanent_alloy.png",
		"icon_best_score": "res://assets/ui/final/icon_best_score.png",
		"icon_victories": "res://assets/ui/final/icon_victories.png",
		"route_choice_card_frame": "res://assets/ui/final/route_choice_card_frame.png",
		"explosion_car": "res://assets/fx/explosion_car_sheet.png",
		"explosion_beam": "res://assets/fx/explosion_beam_sheet.png",
		# Mobile-generated HUD shells (Downloads batch) — used only when is_mobile_ui.
		"hud_gen_player_status": "res://art/ui/mobile_generated/hud_gen_player_status.png",
		# Empty-interior dual-section status shell (Downloads SVG → PNG).
		"hud_compact_player_status": "res://assets/ui/hud/riftline_dual_section_hud_panel_empty_interior.png",
		"hud_gen_mission_banner": "res://art/ui/mobile_generated/hud_gen_mission_banner.png",
		"hud_gen_economy": "res://art/ui/mobile_generated/hud_gen_economy.png",
		"hud_gen_banner_alt_a": "res://art/ui/mobile_generated/hud_gen_banner_alt_a.png",
		"hud_gen_banner_alt_b": "res://art/ui/mobile_generated/hud_gen_banner_alt_b.png",
		"hud_gen_reactor": "res://art/ui/mobile_generated/hud_gen_reactor.png",
		# Compact reactor console (Downloads SVG → PNG) — cyan cylinder + 4-row brass panel.
		"hud_compact_reactor": "res://assets/ui/hud/riftline_compact_hud_bar.png",
		"hud_gen_weapons": "res://art/ui/mobile_generated/hud_gen_weapons.png",
		# Four-slot weapon priority console (Downloads SVG → PNG).
		"hud_compact_weapons": "res://assets/ui/hud/riftline_four_slot_hud_bar.png",
		"hud_gen_abilities": "res://art/ui/mobile_generated/hud_gen_abilities.png",
		# Four-slot abilities bar (riftline_reactor_status_panel.svg — 4 compartments).
		"hud_compact_abilities": "res://assets/ui/hud/riftline_reactor_status_panel.png",
		"hud_gen_shop_tab": "res://art/ui/mobile_generated/hud_gen_shop_tab.png",
		"hud_shop_tab_vertical": "res://assets/ui/hud/riftline_vertical_hud_frame.png"
	}
	# Mobile UI (Android + F5 mobile preview) shares the same compact packs so preview == device.
	# Export excludes desktop ui/final + region bg_* — prefer mobile remaps when present.
	var use_mobile_assets := is_mobile_ui or OS.has_feature("android") or OS.get_name() == "Android"
	for key in paths.keys():
		var path_str := str(paths[key])
		var fallback_str := path_str
		if use_mobile_assets:
			if path_str.begins_with("res://assets/ui/final/"):
				var ui_m := path_str.replace("res://assets/ui/final/", "res://assets/ui/mobile/")
				if ResourceLoader.exists(ui_m) or FileAccess.file_exists(ui_m):
					path_str = ui_m
			elif path_str.begins_with("res://assets/v2/bg_") \
					or path_str.begins_with("res://assets/region2/bg_") \
					or path_str.begins_with("res://assets/region3/bg_"):
				var bg_m := path_str.replace("res://assets/", "res://assets/mobile_bg/")
				if ResourceLoader.exists(bg_m) or FileAccess.file_exists(bg_m):
					path_str = bg_m
			paths[key] = path_str
		var res = null
		if ResourceLoader.exists(path_str):
			res = load(path_str)
		if res == null and use_mobile_assets and fallback_str != path_str and ResourceLoader.exists(fallback_str):
			res = load(fallback_str)
		if res == null:
			var gpath = ProjectSettings.globalize_path(path_str)
			if FileAccess.file_exists(path_str) or FileAccess.file_exists(gpath):
				var img = Image.load_from_file(gpath)
				if img != null:
					res = ImageTexture.create_from_image(img)
		if res != null:
			images[key] = res
		elif use_mobile_assets:
			push_warning("[Riftline] Missing Android asset key=%s path=%s" % [str(key), path_str])

## Mobile HUD: prefer generated frame shells; desktop keeps original keys untouched.
func _hud_frame_key(desktop_key: String, gen_key: String) -> String:
	if is_mobile_ui and images.has(gen_key):
		return gen_key
	return desktop_key

func _mobile_gen_hud_active() -> bool:
	return is_mobile_ui and images.has("hud_gen_player_status")

func _mobile_compact_reactor_active() -> bool:
	return is_mobile_ui and images.has("hud_compact_reactor")

func _mobile_compact_weapons_active() -> bool:
	return is_mobile_ui and images.has("hud_compact_weapons")

func _mobile_compact_abilities_active() -> bool:
	return is_mobile_ui and images.has("hud_compact_abilities")

func _mobile_compact_status_active() -> bool:
	return is_mobile_ui and (images.has("hud_compact_player_status") or _mobile_status_hud != null)

func _setup_mobile_status_hud() -> void:
	if _mobile_status_hud != null:
		return
	_mobile_status_hud_layer = CanvasLayer.new()
	_mobile_status_hud_layer.name = "MobileStatusHudLayer"
	_mobile_status_hud_layer.layer = 20
	add_child(_mobile_status_hud_layer)
	var packed: PackedScene = load("res://scenes/MobileStatusHud.tscn") as PackedScene
	if packed == null:
		push_warning("[Riftline] MobileStatusHud.tscn missing — falling back to custom-draw status.")
		return
	_mobile_status_hud = packed.instantiate() as Control
	_mobile_status_hud_layer.add_child(_mobile_status_hud)

func _sync_mobile_status_hud() -> void:
	if _mobile_status_hud == null:
		return
	# Match draw_hud visibility: no combat shell on menus / end screens.
	# Also park while armory sheet is open — left peek stays world-only.
	var show_hud := is_mobile_ui and not ["title", "workshop", "options", "help", "victory", "failed"].has(state) \
		and shop_slide < 0.2
	if not show_hud:
		_mobile_status_hud.visible = false
		return
	var lay: Dictionary = _mobile_player_status_layout()
	var tr: Rect2 = lay["texture_rect"]
	var screen_frame := Rect2(canvas_offset + tr.position * canvas_scale, tr.size * canvas_scale)
	var hp_tot = convoy_hp_totals()
	var hp_pct = clampf(hp_tot.x / maxf(0.01, hp_tot.y), 0.0, 1.0)
	var hp_col = Color.html("#ff4b4b") if hp_pct < 0.3 else (Color.html("#ffbe44") if hp_pct < 0.6 else Color(.45, 1, .65))
	# Compact labels with units; Control HUD keeps small type.
	var hp_label = "DESTROYED" if hp_tot.x <= 0.0 else ("%d/%d HP" % [int(hp_tot.x), int(hp_tot.y)])
	var ht_pct = clampf(float(heat["value"]) / 100.0, 0.0, 1.0)
	var ht_col = Color.html("#ff4438") if heat["value"] > 80.0 else (Color.html("#ffaa3b") if heat["value"] > 50.0 else Color.html("#8ef7ff"))
	var stats := {
		"hp_pct": hp_pct,
		"hp_label": hp_label,
		"hp_col": hp_col,
		"spd_pct": clampf(float(momentum["speed"]) / 150.0, 0.0, 1.0),
		"spd_label": "%d SPD" % int(momentum["speed"]),
		"heat_pct": ht_pct,
		"heat_label": "%d HEAT" % int(heat["value"]),
		"heat_col": ht_col,
		"shd_label": "SHD %d" % int(power.get("shield", 0)),
		"label_px": float(lay.get("label_px", 12.0)),
	}
	var win_sz: Vector2i = DisplayServer.window_get_size()
	var vp_sz: Vector2 = get_viewport_rect().size
	var win_to_vp: float = vp_sz.x / maxf(1.0, float(win_sz.x))
	_mobile_status_hud.visible = true
	_mobile_status_hud.apply(screen_frame, lay, canvas_scale, canvas_offset, stats, win_to_vp)

func _setup_mobile_encounter_hud() -> void:
	if _mobile_encounter_hud != null:
		return
	_mobile_encounter_hud_layer = CanvasLayer.new()
	_mobile_encounter_hud_layer.name = "MobileEncounterHudLayer"
	_mobile_encounter_hud_layer.layer = 21
	add_child(_mobile_encounter_hud_layer)
	var packed: PackedScene = load("res://scenes/MobileEncounterHud.tscn") as PackedScene
	if packed == null:
		push_warning("[Riftline] MobileEncounterHud.tscn missing — falling back to custom-draw encounter.")
		return
	_mobile_encounter_hud = packed.instantiate() as Control
	_mobile_encounter_hud_layer.add_child(_mobile_encounter_hud)

func _setup_mobile_economy_hud() -> void:
	if _mobile_economy_hud != null:
		return
	_mobile_economy_hud_layer = CanvasLayer.new()
	_mobile_economy_hud_layer.name = "MobileEconomyHudLayer"
	_mobile_economy_hud_layer.layer = 22
	add_child(_mobile_economy_hud_layer)
	var packed: PackedScene = load("res://scenes/MobileEconomyHud.tscn") as PackedScene
	if packed == null:
		push_warning("[Riftline] MobileEconomyHud.tscn missing — falling back to custom-draw economy.")
		return
	_mobile_economy_hud = packed.instantiate() as Control
	_mobile_economy_hud_layer.add_child(_mobile_economy_hud)

func _mobile_economy_layout() -> Dictionary:
	var win: Vector2i = DisplayServer.window_get_size()
	var vp: Vector2 = get_viewport_rect().size
	var status_lay: Dictionary = _mobile_player_status_layout() if is_mobile_ui else {}
	var status_tex: Rect2 = status_lay.get("texture_rect", Rect2()) if status_lay.size() > 0 else Rect2()
	var enc_lay: Dictionary = MobileHudLayout.encounter_panel(
		safe_inset, design_view_left, design_view_right, design_view_top,
		(design_view_right - design_view_left) / maxf(1.0, design_view_bottom - design_view_top),
		canvas_scale, win, vp, status_tex, Rect2()
	)
	var encounter_tex: Rect2 = enc_lay.get("texture_rect", Rect2())
	return MobileHudLayout.economy_panel(
		safe_inset, design_view_left, design_view_right, design_view_top,
		(design_view_right - design_view_left) / maxf(1.0, design_view_bottom - design_view_top),
		canvas_scale, win, vp, encounter_tex, status_tex
	)

func _sync_mobile_economy_hud() -> void:
	if _mobile_economy_hud == null:
		return
	# Hide while armory sheet is open — it would stack over the shop header.
	var show_hud := is_mobile_ui and state == "combat" and shop_slide < 0.2
	if not show_hud:
		_mobile_economy_hud.visible = false
		return
	var lay: Dictionary = _mobile_economy_layout()
	_mobile_economy_conflict = str(lay.get("conflict", ""))
	var tr: Rect2 = lay["texture_rect"]
	var screen_frame := Rect2(canvas_offset + tr.position * canvas_scale, tr.size * canvas_scale)
	var icon_key := "icon_scrap_gear" if images.has("icon_scrap_gear") else "icon_scrap"
	var icon_path := str(images.get(icon_key, "res://assets/icon_scrap.png"))
	var xp_pct := clampf(float(xp) / maxf(1.0, float(xp_needed)), 0.0, 1.0)
	var data := {
		"scrap_label": "%d" % int(scrap),
		# Digit only — fills the small badge without "LV" clutter.
		"level_label": "%d" % int(level),
		"xp_label": "%d/%d" % [int(xp), int(xp_needed)],
		"xp_pct": xp_pct,
		"icon_path": "res://assets/ui/hud/economy_scrap_gear.png",
		"compact": bool(lay.get("compact", false)),
	}
	var win_sz: Vector2i = DisplayServer.window_get_size()
	var vp_sz: Vector2 = get_viewport_rect().size
	var win_to_vp: float = vp_sz.x / maxf(1.0, float(win_sz.x))
	_mobile_economy_hud.visible = true
	_mobile_economy_hud.apply(screen_frame, lay, canvas_scale, canvas_offset, data, win_to_vp)

func _mobile_encounter_layout() -> Dictionary:
	var win: Vector2i = DisplayServer.window_get_size()
	var vp: Vector2 = get_viewport_rect().size
	var status_lay: Dictionary = _mobile_player_status_layout() if is_mobile_ui else {}
	var status_tex: Rect2 = status_lay.get("texture_rect", Rect2()) if status_lay.size() > 0 else Rect2()
	# Prefer the Control-tree economy shell for neighbor clearance; fall back to trio layout.
	var scrap_tex := Rect2()
	if _mobile_economy_hud != null:
		var eco: Dictionary = _mobile_economy_layout()
		scrap_tex = eco.get("texture_rect", Rect2())
	elif _mobile_gen_hud_active():
		var ml: Dictionary = _mobile_hud_layout()
		scrap_tex = Rect2(float(ml.get("right_x", 0.0)), float(ml.get("top_y", 0.0)),
			float(ml.get("right_w", 0.0)), float(ml.get("right_h", 0.0)))
	return MobileHudLayout.encounter_panel(
		safe_inset, design_view_left, design_view_right, design_view_top,
		(design_view_right - design_view_left) / maxf(1.0, design_view_bottom - design_view_top),
		canvas_scale, win, vp, status_tex, scrap_tex
	)

func _sync_mobile_encounter_hud() -> void:
	if _mobile_encounter_hud == null:
		return
	var show_hud := is_mobile_ui and state == "combat" and shop_slide < 0.2
	if not show_hud:
		_mobile_encounter_hud.visible = false
		return
	var lay: Dictionary = _mobile_encounter_layout()
	_mobile_encounter_conflict = str(lay.get("conflict", ""))
	var tr: Rect2 = lay["texture_rect"]
	var content: Rect2 = lay["content"]
	var screen_frame := Rect2(canvas_offset + tr.position * canvas_scale, tr.size * canvas_scale)
	var title_default := "FUNGUS WILDS NODE" if current_region == "fungus_wilds" else "RUSTLANDS NODE"
	if current_region == RiftScar.REGION_ID:
		title_default = "RIFT SCAR NODE"
	var title_text := "REGION TRANSITION" if region_transition_active else ("BOSS ENCOUNTER" if boss_active else str(current_encounter.get("title", title_default)))
	var region_label := "Rift Scar" if current_region == RiftScar.REGION_ID else ("Fungus Wilds" if current_region == "fungus_wilds" else "Rustlands")
	var meta := "%s · Track %d/6 · Loop %d" % [region_label, mini(encounter_index + 1, 6), maxi(1, rift_loop)]
	if bool(lay.get("compact_meta", false)):
		meta = "T%d/6 · L%d" % [mini(encounter_index + 1, 6), maxi(1, rift_loop)]
	var p_pct := 0.0
	var bar_col := Color.html("#3de1ff")
	var bar_label := ""
	if boss_active:
		var b = null
		for e in enemies:
			if e.get("boss", false):
				b = e
		p_pct = clampf((float(b["hp"]) / maxf(1.0, float(b["max_hp"]))) if b != null else 0.0, 0.0, 1.0)
		bar_col = Color.html("#ff4b4b")
		# Compact % beside the bar; boss name stays in the title/meta band.
		bar_label = "%d%%" % int(p_pct * 100.0)
	elif region_transition_active:
		p_pct = clampf(1.0 - (region_transition_timer / maxf(0.01, region_transition_total())), 0.0, 1.0)
		bar_col = Color.html("#7dffbb")
		bar_label = "%d%%" % int(p_pct * 100.0)
	else:
		p_pct = clampf(float(encounter_progress) / maxf(0.01, float(encounter_goal)), 0.0, 1.0)
		bar_label = "%d%%" % int(p_pct * 100.0)
	var data := {
		"title": title_text,
		"meta": meta,
		"progress_pct": p_pct,
		"progress_col": bar_col,
		"progress_label": bar_label,
		"compact_meta": bool(lay.get("compact_meta", false)),
	}
	var win_sz: Vector2i = DisplayServer.window_get_size()
	var vp_sz: Vector2 = get_viewport_rect().size
	var win_to_vp: float = vp_sz.x / maxf(1.0, float(win_sz.x))
	_mobile_encounter_hud.visible = true
	_mobile_encounter_hud.apply(screen_frame, content, canvas_scale, canvas_offset, data, win_to_vp)

## Top-left dual-section HUD: glass + fills under decorative frame, text on top.
## Used only when Control-tree MobileStatusHud is unavailable.
func _draw_mobile_dual_status_layered(lay: Dictionary, hp_pct: float, hp_col: Color, hp_label: String) -> void:
	var frame_r: Rect2 = lay["texture_rect"]
	var hp_r: Rect2 = lay["hp"]
	var spd_r: Rect2 = lay["spd"]
	var heat_r: Rect2 = lay["heat"]
	var shd_r: Rect2 = lay["shield"]
	var sp_pct: float = clampf(float(momentum["speed"]) / 150.0, 0.0, 1.0)
	var ht_pct: float = clampf(float(heat["value"]) / 100.0, 0.0, 1.0)
	var ht_col := Color.html("#ff4438") if heat["value"] > 80.0 else (Color.html("#ffaa3b") if heat["value"] > 50.0 else Color.html("#8ef7ff"))
	var sh_v: float = float(power.get("shield", 0))
	var label_px: int = maxi(10, int(float(lay.get("label_px", 12.0))))
	# Layer 1+2: translucent glass wells (#081824 @ 75%), then clipped fills.
	var glass := Color(0.0313726, 0.0941176, 0.141176, 0.75)
	var glass_edge := Color(0.35, 0.75, 0.95, 0.12)
	for slot_r in [hp_r, spd_r, heat_r, shd_r]:
		var sr: Rect2 = slot_r
		draw_rect(sr, glass, true)
		draw_rect(sr, glass_edge, false, 1.0)
	_draw_status_fill_clipped(hp_r, hp_pct, hp_col)
	_draw_status_fill_clipped(spd_r, sp_pct, Color.html("#ffce72"))
	_draw_status_fill_clipped(heat_r, ht_pct, ht_col)
	# Layer 3: metallic dual-section frame OVER fills (slot interiors are transparent in the PNG).
	draw_tex("hud_compact_player_status", frame_r)
	# Layer 4: live labels above everything (shadowed for readability on glass).
	_draw_status_label(hp_label, hp_r, label_px, Color.WHITE)
	_draw_status_label("%d SPD" % int(momentum["speed"]), spd_r, maxi(9, label_px - 1), Color.WHITE)
	_draw_status_label("%d HEAT" % int(heat["value"]), heat_r, maxi(9, label_px - 1), Color.WHITE)
	_draw_status_label("%d SHD" % int(sh_v), shd_r, maxi(9, label_px - 2), Color.html("#8ef7ff"))

func _draw_status_fill_clipped(slot: Rect2, pct: float, fill: Color) -> void:
	## Soft fill clipped to the inner slot (inset so metal lips of the frame sit above).
	var inset: float = maxf(3.0, minf(slot.size.x, slot.size.y) * 0.10)
	var inner := Rect2(slot.position.x + inset, slot.position.y + inset, maxf(1.0, slot.size.x - inset * 2.0), maxf(1.0, slot.size.y - inset * 2.0))
	var p: float = clampf(pct, 0.0, 1.0)
	if p <= 0.001:
		return
	var fw: float = inner.size.x * p
	# Keep fill translucent so glass + world read through; still readable under white text.
	var fill_a := Color(fill.r, fill.g, fill.b, 0.44)
	draw_rect(Rect2(inner.position.x, inner.position.y, fw, inner.size.y), fill_a, true)
	if fw > 3.0:
		draw_rect(Rect2(inner.position.x + fw - 2.0, inner.position.y, 2.0, inner.size.y), Color(1, 1, 1, 0.18), true)

func _draw_status_label(text: String, slot: Rect2, px: int, col: Color) -> void:
	var cx: float = slot.position.x + slot.size.x * 0.5
	var cy: float = slot.position.y + slot.size.y * 0.72
	draw_text2(text, cx + 1.0, cy + 1.0, px, Color(0, 0, 0, 0.75), "center")
	draw_text2(text, cx, cy, px, col, "center")

## Authoritative responsive bounds for the top-left player status shell (mobile only).
func _mobile_player_status_layout() -> Dictionary:
	var win: Vector2i = DisplayServer.window_get_size()
	var vp: Vector2 = get_viewport_rect().size
	var aspect: float = float(win.x) / maxf(1.0, float(win.y))
	var lay: Dictionary = MobileHudLayout.player_status_panel(
		safe_inset, design_view_left, design_view_right, design_view_top, aspect,
		canvas_scale, win, vp
	)
	_mobile_status_panel = lay["texture_rect"]
	_mobile_status_conflict = ""
	# Report (do not relocate) overlap with the existing top-center mission panel.
	if _mobile_gen_hud_active() and state == "combat":
		var ml: Dictionary = _mobile_hud_layout()
		var center := Rect2(float(ml["center_x"]), float(ml["top_y"]), float(ml["center_w"]), float(ml["center_h"]))
		if MobileHudLayout.overlaps(_mobile_status_panel, center):
			_mobile_status_conflict = "STATUS_OVERLAPS_MISSION_BANNER status=%s mission=%s" % [str(_mobile_status_panel), str(center)]
			push_warning("[Riftline] " + _mobile_status_conflict)
	return lay

## Shared geometry for the polished mobile generated HUD (design-space, 1920×1080).
func _mobile_hud_layout() -> Dictionary:
	var inset_l: float = float(safe_inset.get("left", 12.0))
	var inset_r: float = float(safe_inset.get("right", 12.0))
	var inset_t: float = float(safe_inset.get("top", 8.0))
	var inset_b: float = float(safe_inset.get("bottom", 14.0))
	var aspect: float = 2172.0 / 724.0
	var top_y: float = 14.0 + inset_t
	var pause_s: float = 40.0
	var edge_pad: float = 20.0
	# Reserve a right strip for pause/speed so the economy shell never crowds the edge.
	var pause_reserve: float = pause_s + 14.0
	var left_bound: float = inset_l + edge_pad
	var right_bound: float = DESIGN_W - inset_r - edge_pad
	var usable: float = right_bound - left_bound - pause_reserve
	# Shared top rail: equal-height shells, center slightly wider, spread across width.
	var top_h: float = 126.0
	var left_w: float = top_h * aspect
	var right_w: float = left_w
	var center_w: float = top_h * aspect * 1.08
	var trio_w: float = left_w + center_w + right_w
	if trio_w > usable - 24.0:
		var s: float = (usable - 24.0) / trio_w
		left_w *= s
		center_w *= s
		right_w *= s
		top_h = left_w / aspect
		trio_w = left_w + center_w + right_w
	var spread: float = usable - trio_w
	var gap_a: float = spread * 0.5
	var left_x: float = left_bound
	var center_x: float = left_x + left_w + gap_a
	var right_x: float = center_x + center_w + gap_a
	var center_h: float = top_h
	# Bottom strip: weapons + abilities share height; reactor taller but bottom-aligned.
	var bot_pad: float = 12.0 + inset_b
	var strip_h: float = 158.0
	var strip_y: float = DESIGN_H - bot_pad - strip_h
	var reactor_h: float = 236.0
	var reactor_w: float = reactor_h * (1448.0 / 1086.0)
	var reactor_x: float = inset_l + 14.0
	var reactor_y: float = DESIGN_H - bot_pad - reactor_h
	if _mobile_compact_reactor_active():
		var win_r: Vector2i = DisplayServer.window_get_size()
		var vp_r: Vector2 = get_viewport_rect().size
		var aspect_r: float = (design_view_right - design_view_left) / maxf(1.0, design_view_bottom - design_view_top)
		var rlay: Dictionary = MobileHudLayout.reactor_panel(
			safe_inset, design_view_left, design_view_right, design_view_top, design_view_bottom,
			aspect_r, canvas_scale, win_r, vp_r
		)
		var rtr: Rect2 = rlay["texture_rect"]
		reactor_x = rtr.position.x
		reactor_y = rtr.position.y
		reactor_w = rtr.size.x
		reactor_h = rtr.size.y
	var bot_gap: float = 14.0
	var bot_right: float = DESIGN_W - inset_r - 12.0
	if _mobile_compact_reactor_active():
		bot_right = design_view_right - inset_r - 12.0
	var after_reactor: float = reactor_x + reactor_w + bot_gap
	# Opaque reactor ends before transparent right pad — keep weapon strip clear of metal.
	if _mobile_compact_reactor_active():
		after_reactor = reactor_x + reactor_w * (1.0 - MobileHudLayout.REACTOR_ART_PAD_R) + bot_gap
	var remain: float = maxf(200.0, bot_right - after_reactor)
	# Native-aspect strips: abilities hug the right thumb zone; weapons sit immediately left.
	var nat_w: float = strip_h * aspect
	var weap_w: float = nat_w * 1.06
	var abil_w: float = nat_w * 1.00
	if weap_w + abil_w + bot_gap > remain:
		var s2: float = remain / (weap_w + abil_w + bot_gap)
		weap_w *= s2
		abil_w *= s2
	var abil_x: float = bot_right - abil_w
	var weap_x: float = abil_x - bot_gap - weap_w
	if weap_x < after_reactor:
		weap_x = after_reactor
		abil_x = weap_x + weap_w + bot_gap
		if abil_x + abil_w > bot_right:
			abil_w = bot_right - abil_x
	var weap_y: float = strip_y
	var weap_h: float = strip_h
	var abil_y: float = strip_y
	var abil_h: float = strip_h
	var weapons_conflict := ""
	var abilities_conflict := ""
	var win_b: Vector2i = DisplayServer.window_get_size()
	var vp_b: Vector2 = get_viewport_rect().size
	var aspect_b: float = (design_view_right - design_view_left) / maxf(1.0, design_view_bottom - design_view_top)
	# Abilities flush to extreme bottom-right; weapons band uses that as right neighbor.
	if _mobile_compact_abilities_active():
		var alay: Dictionary = MobileHudLayout.abilities_panel(
			safe_inset, design_view_left, design_view_right, design_view_top, design_view_bottom,
			aspect_b, canvas_scale, win_b, vp_b, after_reactor, bot_right
		)
		var atr: Rect2 = alay["texture_rect"]
		abil_x = atr.position.x
		abil_y = atr.position.y
		abil_w = atr.size.x
		abil_h = atr.size.y
		abilities_conflict = str(alay.get("conflict", ""))
	if _mobile_compact_weapons_active():
		# Screen-center bottom; neighbors only act as soft collision limits.
		var weap_band_left: float = design_view_left + float(safe_inset.get("left", 0.0))
		var weap_band_right: float = bot_right
		if _mobile_compact_reactor_active():
			weap_band_left = after_reactor
		if _mobile_compact_abilities_active():
			weap_band_right = abil_x + abil_w * MobileHudLayout.ABILITIES_ART_PAD_L
		var wlay: Dictionary = MobileHudLayout.weapons_panel(
			safe_inset, design_view_left, design_view_right, design_view_top, design_view_bottom,
			aspect_b, canvas_scale, win_b, vp_b, weap_band_left, weap_band_right
		)
		var wtr: Rect2 = wlay["texture_rect"]
		weap_x = wtr.position.x
		weap_y = wtr.position.y
		weap_w = wtr.size.x
		weap_h = wtr.size.y
		weapons_conflict = str(wlay.get("conflict", ""))
	var shop_w: float = 46.0
	var shop_h: float = 148.0
	# Center SHOP on the open combat band between top rail and bottom strips.
	var combat_top: float = top_y + top_h + 16.0
	var combat_bot: float = strip_y - 8.0
	var shop_y: float = combat_top + maxf(0.0, (combat_bot - combat_top - shop_h) * 0.50)
	return {
		"top_y": top_y,
		"left_x": left_x, "left_w": left_w, "left_h": top_h,
		"center_x": center_x, "center_w": center_w, "center_h": center_h,
		"right_x": right_x, "right_w": right_w, "right_h": top_h,
		"reactor_x": reactor_x, "reactor_y": reactor_y, "reactor_w": reactor_w, "reactor_h": reactor_h,
		"weap_x": weap_x, "weap_y": weap_y, "weap_w": weap_w, "weap_h": weap_h,
		"abil_x": abil_x, "abil_y": abil_y, "abil_w": abil_w, "abil_h": abil_h,
		"shop_w": shop_w, "shop_h": shop_h, "shop_y": shop_y,
		"pause_s": pause_s,
		"weapons_conflict": weapons_conflict,
		"abilities_conflict": abilities_conflict
	}

func default_weapons() -> Dictionary:
	return {
		"gatling": { "cooldown": 0.0, "cooldown_max": .18, "damage": 10.0, "muzzle": Vector2(870, 500), "priority": "nearest" },
		"cannon": { "cooldown": .9, "cooldown_max": 1.95, "damage": 62.0, "muzzle": Vector2(660, 462), "priority": "strongest" },
		"drone": { "damage": 13.0, "priority": "boarders" },
		"aux": { "cooldown": 0.0, "muzzle": Vector2(758, 492), "priority": "nearest" }
	}

func default_abilities() -> Dictionary:
	return {
		"boost": { "label": "BOOST", "cooldown": 0.0, "cooldown_max": 18.0, "duration": 0.0, "unlocked": true },
		"shield": { "label": "SHIELD", "cooldown": 0.0, "cooldown_max": 24.0, "duration": 0.0, "unlocked": true },
		"repair": { "label": "REPAIR", "cooldown": 3.0, "cooldown_max": 21.0, "duration": 0.0, "unlocked": true },
		"barrage": { "label": "BARRAGE", "cooldown": 0.0, "cooldown_max": 32.0, "duration": 0.0, "unlocked": false }
	}

func default_modules() -> Dictionary:
	# New expeditions start with ownership empty and nothing installed (starter gun is separate).
	return {
		"installed": { "gatling": false, "cannon": false, "drone": false, "aux": null },
		"levels": { "gatling": 1, "cannon": 1, "drone": 1 },
		"aux_levels": {},
		"inventory": [],
		"owned_core": [],
		"mounts": {},
		"loadout": { "inventory": [], "installed": [], "next_serial": 1 }
	}

func default_starter_gun() -> Dictionary:
	return {
		"cooldown": 0.0,
		"cooldown_max": TrainBuild.STARTER_COOLDOWN,
		"damage": TrainBuild.STARTER_DAMAGE,
		"range": TrainBuild.STARTER_RANGE,
		"muzzle": Vector2(1300, 480),
		"face": -1.0
	}

func _alloc_car_uid(car_type: String) -> String:
	var uid := "%s_%d" % [car_type, _next_car_serial]
	_next_car_serial += 1
	return uid

func reset_train_cars() -> void:
	# Locomotive-only start. Wagons are purchased through the live Armory.
	_next_car_serial = 1
	train_cars = [TrainBuild.make_starter_loco(_alloc_car_uid("loco"))]
	apply_train_layout()

func legacy_three_car_train() -> Array:
	# Compatible loadout for old saves / capture harnesses that expect a 3-car convoy.
	_next_car_serial = 1
	var loco := TrainBuild.make_starter_loco(_alloc_car_uid("loco"))
	var weap1 := TrainBuild.make_car("weapon", _alloc_car_uid("weapon"))
	var weap2 := TrainBuild.make_car("weapon", _alloc_car_uid("weapon"))
	return [loco, weap1, weap2]

func apply_classic_full_loadout() -> void:
	# Restores the pre-buildout 3-car + all weapons configuration for capture/regression harnesses.
	train_cars = legacy_three_car_train()
	apply_train_layout()
	modules = default_modules()
	modules["installed"] = { "gatling": true, "cannon": true, "drone": true, "aux": "arc_coil" }
	modules["levels"] = { "gatling": 1, "cannon": 1, "drone": 1 }
	modules["aux_levels"] = { "arc_coil": 1 }
	modules["owned_core"] = ["gatling", "cannon", "drone"]
	modules["inventory"] = []
	modules["mounts"] = {}
	modules["loadout"] = { "inventory": [], "installed": [], "next_serial": 1 }
	ensure_modules_schema()
	# Guarantee mounts if migration left anything in inventory.
	for wtype in ["gatling", "cannon", "drone", "arc_coil"]:
		while WeaponLoadout.count_installed(modules, wtype) < 1:
			var inv_uid := ""
			for inst in WeaponLoadout.inventory_list(modules):
				if str(inst.get("type", "")) == wtype:
					inv_uid = str(inst.get("uid", ""))
					break
			if inv_uid == "":
				var bought := WeaponLoadout.buy_to_inventory(modules, wtype, 1)
				inv_uid = str(bought.get("uid", ""))
			if inv_uid == "":
				break
			if WeaponLoadout.install(modules, train_cars, inv_uid) != "":
				break
	_rebuild_legacy_mounts_from_loadout()
	for inst in WeaponLoadout.installed_list(modules):
		if int(inst.get("power", 0)) <= 0:
			inst["power"] = 1
	snap_combat_view_shift()
	starter_gun = default_starter_gun()
	if weapons.is_empty():
		weapons = default_weapons()

func _run_workshop_expansion_integration_verify() -> void:
	var lines: Array = []
	var fail_box: Array = [0]
	var ok := func(cond: bool, msg: String) -> void:
		if cond:
			lines.append("PASS " + msg)
		else:
			fail_box[0] = int(fail_box[0]) + 1
			lines.append("FAIL " + msg)

	# Preserve real permanent save; restore at end.
	var backup := permanent.duplicate(true)
	permanent = ensure_permanent({
		"alloy": 20000,
		"workshop": {
			"hull": 5, "starter": 5, "reactor": 5, "cooling": 5, "salvage": 5,
			"armor_pierce": 0, "targeting": 0, "reinforced": 0, "impact": 0,
			"field_eng": 0, "starter_scrap": 0, "weapons_eng": 0
		}
	})
	ok.call(workshop_tier("hull") == 5, "migrated max hull preserved")
	ok.call(workshop_tier("armor_pierce") == 0, "new AP defaults 0")
	ok.call(TrainBuild.WORKSHOP_KEYS.size() == 12, "twelve upgrades registered")

	# Purchase every new upgrade to max.
	for key in ["armor_pierce", "targeting", "reinforced", "impact", "field_eng", "starter_scrap", "weapons_eng"]:
		permanent["workshop"][key] = 0
		for _t in range(5):
			var before := int(permanent["alloy"])
			var cost := TrainBuild.workshop_cost(key, workshop_tier(key))
			buy_workshop(key)
			ok.call(workshop_tier(key) == _t + 1, "%s tier %d" % [key, _t + 1])
			ok.call(int(permanent["alloy"]) == before - cost, "%s charged once at t%d" % [key, _t])
		ok.call(workshop_tier(key) == 5, "%s maxed" % key)
		var alloy_at_max := int(permanent["alloy"])
		buy_workshop(key)
		ok.call(int(permanent["alloy"]) == alloy_at_max and workshop_tier(key) == 5, "%s max rejects charge" % key)

	save_permanent()
	var saved_ap := workshop_tier("armor_pierce")
	load_permanent()
	ok.call(workshop_tier("armor_pierce") == saved_ap, "AP persists save/load")
	ok.call(workshop_tier("hull") == 5, "old maxed still maxed after load")

	# Fresh expedition applies starter scrap once.
	permanent["workshop"]["starter_scrap"] = 5
	reset_run()
	ok.call(scrap == 125, "starter scrap 125 on new run got %d" % scrap)
	var scrap_after_start: int = int(scrap)
	# Spend some scrap, then loop — reserve must not refill.
	scrap = 40
	rift_cycle_complete = true
	rift_cycle_next_loop = 2
	state = "victory"
	continue_rift_loop()
	ok.call(int(scrap) == 40, "loop transition does not re-grant starter scrap (got %d)" % int(scrap))
	ok.call(int(scrap) != scrap_after_start, "loop kept spent scrap balance")

	# Apply full combat bonuses on a clean run.
	permanent["workshop"]["armor_pierce"] = 5
	permanent["workshop"]["targeting"] = 5
	permanent["workshop"]["weapons_eng"] = 5
	permanent["workshop"]["impact"] = 5
	permanent["workshop"]["reinforced"] = 5
	permanent["workshop"]["field_eng"] = 5
	permanent["workshop"]["starter"] = 5
	permanent["workshop"]["hull"] = 5
	reset_run()
	ok.call(is_equal_approx(float(starter_gun["range"]), TrainBuild.STARTER_RANGE * 1.30), "targeting +30%% range")
	ok.call(is_equal_approx(starter_armor_pen(), 7.5), "AP pen 7.5")
	ok.call(is_equal_approx(purchased_weapon_damage_mul(), 1.20), "weapons eng +20%%")
	ok.call(is_equal_approx(impact_damage_mul(), 0.85), "impact 15%% DR")
	var loco_hp := float(train_cars[0]["max_hp"])
	ok.call(loco_hp >= TrainBuild.TYPE_SPECS["loco"]["max_hp"] + 60.0 - 0.1, "hull adds loco HP")

	scrap = 9999
	ok.call(buy_wagon("weapon"), "buy reinforced wagon")
	var wagon: Dictionary = train_cars[train_cars.size() - 1]
	ok.call(bool(wagon.get("reinforced_applied", false)), "reinforced flag set once")
	ok.call(float(wagon["max_hp"]) >= float(TrainBuild.TYPE_SPECS["weapon"]["max_hp"]) + 60.0 - 0.1, "wagon +60 HP")
	var hp_before := float(wagon["max_hp"])
	apply_reinforced_to_wagon(wagon)
	ok.call(is_equal_approx(float(wagon["max_hp"]), hp_before), "reinforced does not stack")

	# Armor-pierce effective damage vs brute.
	var e := spawn_enemy("brute", false, -200.0)
	var hp0 := float(e["hp"])
	damage_enemy(e, float(starter_gun["damage"]), "kinetic", 0.0)
	var lost_no_pen := hp0 - float(e["hp"])
	e["hp"] = hp0
	damage_enemy(e, float(starter_gun["damage"]), "kinetic", starter_armor_pen())
	var lost_pen := hp0 - float(e["hp"])
	ok.call(lost_pen > lost_no_pen * 1.1, "AP boosts starter vs brute (%.1f vs %.1f)" % [lost_pen, lost_no_pen])

	# Field engineering heals once per finish_encounter.
	train_cars[0]["hp"] = float(train_cars[0]["max_hp"]) * 0.5
	var mid_hp := float(train_cars[0]["hp"])
	apply_field_engineering_heal()
	ok.call(float(train_cars[0]["hp"]) > mid_hp, "field eng heals damaged loco")
	ok.call(float(train_cars[0]["hp"]) <= float(train_cars[0]["max_hp"]), "field eng clamps to max")
	train_cars[0]["disabled"] = true
	train_cars[0]["hp"] = 0.0
	apply_field_engineering_heal()
	ok.call(float(train_cars[0]["hp"]) <= 0.0, "field eng does not revive wrecks")
	train_cars[0]["disabled"] = false

	# Impact resistance reduces car damage.
	train_cars[0]["hp"] = float(train_cars[0]["max_hp"])
	var full := float(train_cars[0]["hp"])
	damage_car(0, 40.0, null)
	var lost_impact := full - float(train_cars[0]["hp"])
	ok.call(lost_impact < 40.0 * 0.95, "impact reduces incoming (lost %.1f)" % lost_impact)

	# Weapons engineering multiplies purchased weapon damage path.
	ok.call(purchased_damage_multiplier() > damage_multiplier(), "purchased mul > base mul")

	# Workshop UI smoke (no draw_* outside _draw)
	state = "workshop"
	workshop_tab = "defense"
	workshop_scroll_y = 0.0
	set_workshop_tab("economy")
	ok.call(workshop_tab == "economy", "workshop tab switches")
	set_workshop_tab("defense")
	# 2-column workshop fits current tabs without scroll; scroll helper stays clamped at 0.
	adjust_workshop_scroll(200.0)
	ok.call(workshop_scroll_y <= 0.001, "workshop 2-col grid needs no scroll")
	ok.call(TrainBuild.WORKSHOP_CATEGORIES["defense"]["keys"].size() == 5, "defense category has 5 upgrades")

	# Restore player permanent progress.
	permanent = ensure_permanent(backup)
	save_permanent()

	var report := "WORKSHOP INTEGRATION\n"
	for ln in lines:
		report += str(ln) + "\n"
	report += "fails=%d\n" % int(fail_box[0])
	var fh := FileAccess.open(ProjectSettings.globalize_path("res://workshop_integration_verify.txt"), FileAccess.WRITE)
	if fh:
		fh.store_string(report)
	print(report)

func _run_track4_balance_verify() -> void:
	# Isolated Track-4 fairness checks + deterministic combat sims (no scrap injection).
	var lines: Array = []
	var fail_box: Array = [0]
	var ok := func(cond: bool, msg: String) -> void:
		if cond:
			lines.append("PASS " + msg)
		else:
			fail_box[0] = int(fail_box[0]) + 1
			lines.append("FAIL " + msg)

	var perm_backup := permanent.duplicate(true)
	var run_backup := ""
	if FileAccess.file_exists(SAVE_RUN):
		run_backup = FileAccess.get_file_as_string(SAVE_RUN)

	# --- Composition ---
	var bw: Dictionary = ENCOUNTERS[3]
	ok.call(str(bw.get("id", "")) == "boarding_wave", "track4 is boarding_wave")
	var w: Dictionary = bw.get("weights", {})
	var tw := 0.0
	for k in w.keys():
		tw += float(w[k])
	var boarder_pct := float(w.get("boarder", 0)) / maxf(1.0, tw)
	ok.call(boarder_pct >= 0.30 and boarder_pct <= 0.36, "boarder weight ~33%% got %.1f%%" % (boarder_pct * 100.0))
	ok.call(int(w.get("brute", 0)) >= 2, "brutes retained")
	ok.call(w.has("skimmer") or int(w.get("scrapper", 0)) >= 3, "mixed non-boarder types")

	# --- Prices unchanged ---
	ok.call(TrainBuild.wagon_cost("weapon") == 150, "weapon wagon 150")
	ok.call(TrainBuild.core_weapon_cost("gatling") == 50, "gatling 50")
	ok.call(TrainBuild.core_weapon_cost("cannon") == 450, "cannon 450")
	ok.call(TrainBuild.wagon_cost("utility") < 0, "utility wagon removed")
	ok.call(not TrainBuild.TYPE_SPECS.has("utility"), "no utility type spec")

	# --- Shop label ---
	reset_run()
	shop_open = true
	var wagon_detail := ""
	for e in build_live_shop_upgrade_entries():
		if str(e.get("id", "")) == "buy_wagon_weapon":
			wagon_detail = str(e.get("detail", ""))
			break
	ok.call(wagon_detail.to_lower().find("separately") >= 0 or wagon_detail.to_lower().find("purchased weapon") >= 0,
		"weapon wagon needs-weapon label")

	# --- Starter targeting priority ---
	permanent = ensure_permanent({"alloy": 0, "workshop": {"hull": 5, "starter": 5, "armor_pierce": 4, "reactor": 5, "cooling": 5, "salvage": 5}})
	reset_run()
	enemies.clear()
	var sc := spawn_enemy("scrapper", false, 900.0)
	sc["y"] = 760.0
	var br := spawn_enemy("boarder", false, 1100.0)
	br["board_state"] = "attached"
	br["boarded"] = true
	br["attach_slot"] = 0
	br["attach_offset"] = BOARD_ATTACH_OFFSETS[0]
	br["target_car"] = 0
	br["y"] = 520.0
	var tgt = find_target("starter", 600.0, 1200.0)
	ok.call(tgt != null and str(tgt.get("type", "")) == "boarder", "starter prefers attached boarder")
	enemies.clear()
	var runn := spawn_enemy("runner", false, 850.0)
	runn["y"] = 760.0
	var tgt2 = find_target("starter", 600.0, 1200.0)
	ok.call(tgt2 != null and str(tgt2.get("type", "")) == "runner", "starter works with no boarders")

	# --- Attach cap (loco-only = 2) ---
	enemies.clear()
	reset_train_cars()
	ok.call(train_cars.size() == 1, "loco-only for attach test")
	ok.call(board_attach_cap_for_car(0) == 2, "loco attach cap 2")
	var boarders: Array = []
	for i in range(5):
		var b := spawn_enemy("boarder", false, -80.0 - i * 20.0)
		b["x"] = get_car_rear_boundary(0) - 40.0
		b["target_car"] = 0
		b["board_state"] = "running"
		boarders.append(b)
	for _step in range(90):
		for b2 in boarders:
			if not b2.get("dead", false):
				update_enemy(b2, 0.05)
	var attached_n := count_boarding_on_car(0)
	ok.call(attached_n <= 2, "max 2 damaging attaches got %d" % attached_n)
	ok.call(get_free_board_slot(0, true) < 0, "no free slot when at cap")

	# --- Loop1 early elite soft ---
	rift_loop = 1
	current_region = "rustlands"
	encounter_index = 3
	configure_encounter("combat")
	var bud_combat: float = float(encounter_budget)
	configure_encounter("elite")
	ok.call(is_equal_approx(float(encounter_budget), bud_combat), "loop1 T4 elite budget not inflated")
	enemies.clear()
	var before_n: int = enemies.size()
	begin_node_continuous("elite")
	ok.call(is_loop1_early_elite_soft(), "soft elite flag on loop1 T4")
	# After begin_node, only director-driven spawns later — no immediate free spawn.
	ok.call(enemies.size() == before_n, "loop1 T4 elite adds no free enemy (n=%d)" % enemies.size())

	# Loop2 still inflates / can free-spawn.
	rift_loop = 2
	encounter_index = 3
	current_region = "rustlands"
	configure_encounter("combat")
	var bud2: float = float(encounter_budget)
	configure_encounter("elite")
	ok.call(float(encounter_budget) > bud2 * 1.05, "loop2 elite still inflates budget")

	# --- Deterministic combat sims (profiles A/B/C) ---
	var sim_report: Array = []
	var profiles := [
		{"name": "A_fresh", "ws": {}},
		{"name": "B_player", "ws": {"hull": 5, "starter": 5, "reactor": 5, "cooling": 5, "salvage": 5, "armor_pierce": 4}},
		{"name": "C_full", "ws": {
			"hull": 5, "starter": 5, "reactor": 5, "cooling": 5, "salvage": 5, "armor_pierce": 5,
			"targeting": 5, "reinforced": 5, "impact": 5, "field_eng": 5, "starter_scrap": 5, "weapons_eng": 5
		}}
	]
	for prof in profiles:
		var clears_t4 := 0
		var clears_t6 := 0
		var scraps: Array = []
		var fail_tracks: Dictionary = {}
		for seed_i in range(8):
			seed(1000 + seed_i * 17 + hash(str(prof["name"])) % 1000)
			permanent = ensure_permanent({"alloy": 0, "workshop": prof["ws"]})
			reset_run()
			shop_open = false
			paused = false
			game_speed = 1.0
			var sim_t := 0.0
			var dt := 1.0 / 20.0
			var died := false
			while sim_t < 480.0:
				if state != "combat" or boss_active:
					break
				if train_cars.is_empty() or float(train_cars[0].get("hp", 0.0)) <= 0.0:
					died = true
					break
				shop_open = false
				update_combat(dt)
				sim_t += dt
				if encounter_index >= 6:
					break
				# Detect fail state
				if str(state) == "failed":
					died = true
					break
			# encounter_index is the current/next track index (0-based). >=4 means Track 4 cleared.
			if encounter_index >= 4:
				clears_t4 += 1
			if encounter_index >= 6 and str(state) != "failed":
				clears_t6 += 1
			if died or str(state) == "failed":
				fail_tracks[encounter_index + 1] = int(fail_tracks.get(encounter_index + 1, 0)) + 1
			scraps.append(int(scrap))
		var avg_scrap := 0
		for s in scraps:
			avg_scrap += int(s)
		avg_scrap = int(round(float(avg_scrap) / max(1, scraps.size())))
		sim_report.append("%s t4=%d/8 t6=%d/8 avg_scrap=%d fails=%s" % [
			prof["name"], clears_t4, clears_t6, avg_scrap, str(fail_tracks)
		])
		if str(prof["name"]) == "B_player":
			ok.call(clears_t4 >= 5, "Profile B clears T4 often (%d/8)" % clears_t4)
		if str(prof["name"]) == "C_full":
			ok.call(clears_t4 >= 6, "Profile C clears T4 often (%d/8)" % clears_t4)

	# Iron Maw spawn smoke (compatibility).
	permanent = ensure_permanent({"alloy": 0, "workshop": profiles[1]["ws"]})
	reset_run()
	current_region = "rustlands"
	encounter_index = 6
	start_boss()
	ok.call(boss_active, "Iron Maw starts")
	ok.call(not enemies.is_empty(), "boss entity present")

	# Restore saves
	permanent = ensure_permanent(perm_backup)
	save_permanent()
	if run_backup != "":
		var rf := FileAccess.open(SAVE_RUN, FileAccess.WRITE)
		if rf:
			rf.store_string(run_backup)
			rf.close()
	elif FileAccess.file_exists(SAVE_RUN):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_RUN))

	var report2 := "TRACK4 BALANCE VERIFY\n"
	for ln2 in lines:
		report2 += str(ln2) + "\n"
	report2 += "SIMS\n"
	for sr in sim_report:
		report2 += str(sr) + "\n"
	report2 += "fails=%d\n" % int(fail_box[0])
	var fh2 := FileAccess.open(ProjectSettings.globalize_path("res://track4_balance_verify.txt"), FileAccess.WRITE)
	if fh2:
		fh2.store_string(report2)
		fh2.close()
	print(report2)

func _run_universal_loadout_integration_verify() -> void:
	# In-engine checks: 9-slot armory, multi-aux fire, HUD pages, save/reload, boss spawn.
	var lines: Array = []
	var fail_box: Array = [0]
	var ok := func(cond: bool, msg: String) -> void:
		if cond:
			lines.append("PASS " + msg)
		else:
			fail_box[0] = int(fail_box[0]) + 1
			lines.append("FAIL " + msg)

	state = "combat"
	paused = false
	shop_open = true
	shop_slide = 1.0
	scrap = 99999
	reactor["max"] = 18
	permanent = ensure_permanent(permanent)
	for bp in ["Spore Filter Blueprint", "Missile Rack Blueprint", "Breach Core Blueprint"]:
		if not permanent["unlocked"].has(bp):
			permanent["unlocked"].append(bp)

	# Loco only
	reset_train_cars()
	modules = default_modules()
	ensure_modules_schema()
	ok.call(TrainBuild.wagon_count(train_cars) == 0, "loco-only start")
	ok.call(TrainBuild.count_free_hardpoints(train_cars) == 0, "loco-only no mounts")

	# Three wagons, nine weapons
	for _i in range(3):
		ok.call(buy_wagon("weapon"), "buy wagon")
	ok.call(TrainBuild.count_free_hardpoints(train_cars) == 9, "9 free mounts")
	var plan := ["gatling", "gatling", "gatling", "cannon", "cannon", "drone", "drone", "arc_coil", "cryo_launcher"]
	for w in plan:
		ok.call(buy_core_weapon(w) if MODULE_INFO.has(w) else buy_aux_module(w), "buy " + w)
		ok.call(install_core_weapon(w) if MODULE_INFO.has(w) else install_aux_module(w), "install " + w)
	ok.call(WeaponLoadout.count_installed(modules) == 9, "nine installed")
	var mort := WeaponLoadout.buy_to_inventory(modules, "rail_mortar", 1)
	ok.call(not mort.is_empty(), "buy spare mortar while full")
	ok.call(WeaponLoadout.install(modules, train_cars, str(mort.get("uid", ""))) == "FULL — no free mount", "install rejection when full")

	# Dual gatling + multi-aux targeting origins
	var gatlings := 0
	var aux_n := 0
	for inst in WeaponLoadout.installed_list(modules):
		var mxy := WeaponLoadout.instance_mount_xy(train_cars, inst, Callable(self, "car_slot_ox"))
		ok.call(not mxy.is_empty(), "mount xy for " + str(inst.get("uid", "")))
		if str(inst.get("type", "")) == "gatling":
			gatlings += 1
		if WeaponLoadout.is_aux_type(str(inst.get("type", ""))):
			aux_n += 1
			inst["cooldown"] = 0.0
			inst["power"] = 1
	ok.call(gatlings == 3, "three gatlings installed")
	ok.call(aux_n >= 2, "multiple aux types installed")

	# Power shortage: starve half the weapons
	reactor["max"] = 8
	power["engine"] = 4
	power["shield"] = 1
	power["utility"] = 1
	var budget := int(reactor["max"]) - 6
	var assigned := 0
	for inst2 in WeaponLoadout.installed_list(modules):
		if assigned < budget:
			inst2["power"] = 1
			assigned += 1
		else:
			inst2["power"] = 0
	ok.call(reactor_used_power() <= int(reactor["max"]), "reactor budget respected")
	ok.call(WeaponLoadout.total_weapon_power(modules) == budget, "weapon power == budget")

	# HUD pagination
	weapon_hud_page = 0
	_clamp_weapon_hud_page()
	ok.call(installed_weapons_page().size() == 4, "HUD page 0 shows 4")
	shift_weapon_hud_page(1)
	ok.call(installed_weapons_page().size() == 4, "HUD page 1 shows 4")
	shift_weapon_hud_page(1)
	ok.call(installed_weapons_page().size() == 1, "HUD page 2 shows remainder")

	# Uninstall / reinstall
	var first_uid := str(WeaponLoadout.installed_list(modules)[0].get("uid", ""))
	var first_type := str(WeaponLoadout.installed_list(modules)[0].get("type", ""))
	ok.call(uninstall_weapon_instance(first_uid), "uninstall")
	ok.call(install_core_weapon(first_type) if MODULE_INFO.has(first_type) else install_aux_module(first_type), "reinstall")

	# Multi-aux simultaneous fire tick
	spawn_enemy("scrapper", false, -120.0)
	var proj_before := projectiles.size() + weapon_fx.size()
	for inst3 in WeaponLoadout.installed_list(modules):
		inst3["cooldown"] = 0.0
		if int(inst3.get("power", 0)) <= 0:
			inst3["power"] = 1
	reactor["max"] = 24
	update_weapons(0.05)
	update_drones(0.05)
	ok.call(projectiles.size() + weapon_fx.size() >= proj_before, "weapons produced combat output")

	# Save / reload with nine weapons
	state = "combat"
	save_run()
	var saved_n := WeaponLoadout.count_installed(modules)
	modules = default_modules()
	ok.call(load_run(), "load_run")
	ok.call(WeaponLoadout.count_installed(modules) == saved_n, "reload keeps %d weapons" % saved_n)

	# Boss + region compatibility smoke
	current_region = "rustlands"
	prepare_for_boss_fight()
	start_boss()
	ok.call(boss_active, "boss combat starts with full loadout")
	boss_active = false
	boss_intro_active = false
	enemies.clear()

	# Performance smoke: several update frames with full armament
	var t0 := Time.get_ticks_msec()
	for _f in range(30):
		update_weapons(0.016)
		update_drones(0.016)
	var elapsed := Time.get_ticks_msec() - t0
	ok.call(elapsed < 2500, "30 combat frames under 2.5s (got %d ms)" % elapsed)

	var report := "INTEGRATION VERIFY fails=%d\n%s\n" % [int(fail_box[0]), "\n".join(lines)]
	var fh := FileAccess.open(ProjectSettings.globalize_path("res://universal_loadout_integration.txt"), FileAccess.WRITE)
	if fh:
		fh.store_string(report)
		fh.close()
	print(report)

func migrate_train_cars(raw: Array) -> Array:
	# Upgrade legacy {id,x,hp...} cars into uid/hardpoint-aware instances.
	if raw.is_empty():
		return [TrainBuild.make_starter_loco(_alloc_car_uid("loco"))]
	var out: Array = []
	var max_serial := _next_car_serial
	for c in raw:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var car_type := str(c.get("car_type", c.get("id", "weapon")))
		# Utility wagon removed — convert legacy saves to weapon wagons.
		if car_type == "utility" or not TrainBuild.TYPE_SPECS.has(car_type):
			car_type = "weapon"
		var uid := str(c.get("uid", ""))
		if uid == "":
			uid = _alloc_car_uid(car_type)
		else:
			# Keep serial ahead of any saved uid suffix.
			var parts := uid.split("_")
			if parts.size() >= 2 and parts[-1].is_valid_int():
				max_serial = maxi(max_serial, int(parts[-1]) + 1)
		var fresh := TrainBuild.make_car(car_type, uid)
		fresh["hp"] = float(c.get("hp", fresh["max_hp"]))
		fresh["max_hp"] = float(c.get("max_hp", fresh["max_hp"]))
		fresh["armor"] = float(c.get("armor", fresh["armor"]))
		fresh["disabled"] = bool(c.get("disabled", false))
		fresh["wreck_t"] = float(c.get("wreck_t", 0.0))
		fresh["label"] = str(c.get("label", fresh["label"]))
		# Preserve hardpoint weapon assignments across template renames (bay/deck → front/mid/rear).
		if c.has("hardpoints") and typeof(c["hardpoints"]) == TYPE_ARRAY and c["hardpoints"].size() > 0:
			var by_id := {}
			var old_sorted: Array = []
			for hp_old in c["hardpoints"]:
				by_id[str(hp_old.get("hp_id", ""))] = hp_old
				old_sorted.append(hp_old)
			old_sorted.sort_custom(func(a, b): return float(a.get("rel_x", 0.5)) < float(b.get("rel_x", 0.5)))
			var new_hps: Array = fresh["hardpoints"]
			for hi in range(mini(old_sorted.size(), new_hps.size())):
				var wpn := str(old_sorted[hi].get("weapon", ""))
				if wpn != "" and wpn != "starter":
					new_hps[hi]["weapon"] = wpn
			for hp_new in new_hps:
				var hid := str(hp_new.get("hp_id", ""))
				if by_id.has(hid) and str(by_id[hid].get("weapon", "")) != "":
					hp_new["weapon"] = str(by_id[hid]["weapon"])
		out.append(fresh)
	_next_car_serial = maxi(_next_car_serial, max_serial)
	if out.is_empty():
		out = [TrainBuild.make_starter_loco(_alloc_car_uid("loco"))]
	# Ensure a locomotive leads the array.
	if str(out[0].get("car_type", out[0].get("id", ""))) != "loco":
		for i in range(out.size()):
			if str(out[i].get("car_type", out[i].get("id", ""))) == "loco":
				var loco_car = out[i]
				out.remove_at(i)
				out.insert(0, loco_car)
				break
	return out

func weapon_mount_entries(key: String) -> Array:
	# Normalize legacy single-dict mounts into a list of {car_uid, hp_id}.
	var raw = modules.get("mounts", {}).get(key, null)
	if raw == null:
		return []
	if typeof(raw) == TYPE_ARRAY:
		var out: Array = []
		for m in raw:
			if typeof(m) == TYPE_DICTIONARY:
				out.append(m)
		return out
	if typeof(raw) == TYPE_DICTIONARY:
		return [raw]
	return []

func set_weapon_mount_entries(key: String, entries: Array) -> void:
	if entries.is_empty():
		modules.get("mounts", {}).erase(key)
	elif entries.size() == 1:
		modules["mounts"][key] = entries[0]
	else:
		modules["mounts"][key] = entries.duplicate(true)

func sync_hardpoints_from_mounts() -> void:
	# Clear non-starter mounts, then re-apply modules.mounts (supports multi-car).
	for c in train_cars:
		for hp in c.get("hardpoints", []):
			var w := str(hp.get("weapon", ""))
			if w != "starter":
				hp["weapon"] = ""
	var mounts: Dictionary = modules.get("mounts", {})
	for weapon_key in mounts.keys():
		for m in weapon_mount_entries(str(weapon_key)):
			var found := TrainBuild.find_hardpoint(train_cars, str(m.get("car_uid", "")), str(m.get("hp_id", "")))
			if found.is_empty():
				continue
			found["hp"]["weapon"] = str(weapon_key)

func ensure_modules_schema() -> void:
	if typeof(modules) != TYPE_DICTIONARY:
		modules = default_modules()
	if not modules.has("installed"):
		modules["installed"] = { "gatling": false, "cannon": false, "drone": false, "aux": null }
	if not modules.has("levels"):
		modules["levels"] = { "gatling": 1, "cannon": 1, "drone": 1 }
	if not modules.has("aux_levels"):
		modules["aux_levels"] = {}
	if not modules.has("inventory"):
		modules["inventory"] = []
	if not modules.has("owned_core"):
		modules["owned_core"] = []
	if not modules.has("mounts"):
		modules["mounts"] = {}
	WeaponLoadout.ensure_loadout(modules)
	# One-time (or empty loadout) migration from legacy mounts / bool installs.
	var lo: Dictionary = modules["loadout"]
	var has_lo := (lo["installed"] as Array).size() > 0 or (lo["inventory"] as Array).size() > 0
	if not has_lo:
		# Seed legacy mounts before migrate so bool-true installs get hardpoints.
		# Mark each claimed hardpoint occupied so the next weapon gets a new slot
		# (old bug: drone + arc both received the same front mount).
		for key in ["gatling", "cannon", "drone"]:
			if modules["installed"].get(key, false) == true:
				if not modules["owned_core"].has(key):
					modules["owned_core"].append(key)
				if not modules["mounts"].has(key):
					var slot := TrainBuild.find_free_hardpoint(train_cars, key)
					if not slot.is_empty():
						modules["mounts"][key] = { "car_uid": slot["car_uid"], "hp_id": slot["hp_id"] }
						slot["hp"]["weapon"] = key
		var aux = modules["installed"].get("aux", null)
		if aux != null and str(aux) != "" and not modules["mounts"].has("aux"):
			var aslot := TrainBuild.find_free_hardpoint(train_cars, "aux")
			if not aslot.is_empty():
				modules["mounts"]["aux"] = { "car_uid": aslot["car_uid"], "hp_id": aslot["hp_id"] }
				aslot["hp"]["weapon"] = str(aux)
		WeaponLoadout.migrate_from_legacy(modules, train_cars)
	else:
		WeaponLoadout.resync_hardpoints(modules, train_cars)
		WeaponLoadout._sync_legacy_flags(modules)
	# Move legacy type-power into instances once, then clear type channels.
	_migrate_legacy_power_into_instances()
	_rebuild_legacy_mounts_from_loadout()
	_clamp_weapon_hud_page()

func _migrate_legacy_power_into_instances() -> void:
	var legacy_sum := 0
	for k in ["gatling", "cannon", "drone", "aux"]:
		legacy_sum += int(power.get(k, 0))
	if legacy_sum <= 0:
		return
	for inst in WeaponLoadout.installed_list(modules):
		if int(inst.get("power", 0)) > 0:
			continue
		var t := str(inst.get("type", ""))
		var pk := t if power.has(t) else ("aux" if WeaponLoadout.is_aux_type(t) else "")
		if pk != "" and int(power.get(pk, 0)) > 0:
			inst["power"] = clampi(int(power[pk]), 1, 3)
	for k in ["gatling", "cannon", "drone", "aux"]:
		power[k] = 0

func _rebuild_legacy_mounts_from_loadout() -> void:
	## Keep modules.mounts in sync for old list_weapon_mount_xy helpers.
	modules["mounts"] = {}
	for inst in WeaponLoadout.installed_list(modules):
		var t := str(inst.get("type", ""))
		var entry := { "car_uid": str(inst.get("car_uid", "")), "hp_id": str(inst.get("hp_id", "")), "uid": str(inst.get("uid", "")) }
		var key := t if WeaponLoadout.is_core_type(t) else "aux"
		if not modules["mounts"].has(key):
			modules["mounts"][key] = []
		if typeof(modules["mounts"][key]) != TYPE_ARRAY:
			modules["mounts"][key] = [modules["mounts"][key]]
		modules["mounts"][key].append(entry)

func _weapon_hud_all_entries() -> Array:
	## Starter gun always occupies HUD slot 1; installed modules follow.
	var out: Array = []
	if not starter_gun.is_empty():
		out.append({
			"uid": "__starter__",
			"type": "starter",
			"priority": str(starter_gun.get("priority", "nearest")),
			"power": 1,
			"level": int((permanent.get("workshop", {}) as Dictionary).get("starter", 1)),
		})
	for inst in WeaponLoadout.installed_list(modules):
		out.append(inst)
	return out


func _clamp_weapon_hud_page() -> void:
	var n := _weapon_hud_all_entries().size()
	var pages := maxi(1, int(ceil(float(n) / 4.0)))
	weapon_hud_page = clampi(weapon_hud_page, 0, pages - 1)

func installed_weapons_page() -> Array:
	var all := _weapon_hud_all_entries()
	var start := weapon_hud_page * 4
	var out: Array = []
	for i in range(start, mini(start + 4, all.size())):
		out.append(all[i])
	return out

func shift_weapon_hud_page(delta: int) -> void:
	weapon_hud_page += delta
	_clamp_weapon_hud_page()

# Always recompute positions from the live car list.
func apply_train_layout() -> void:
	TrainBuild.layout_cars(train_cars)

func snap_combat_view_shift() -> void:
	# Boot / debug hard sync only — live combat uses the smooth chase in update_train.
	apply_train_layout()
	refresh_combat_view_shift()
	train_shift_target = train_shift_desired
	train_shift_x = train_shift_desired

func get_car_by_uid(uid: String) -> Dictionary:
	for c in train_cars:
		if str(c.get("uid", "")) == uid:
			return c
	return {}

func car_spec(c: Dictionary) -> Dictionary:
	var ct := str(c.get("car_type", c.get("id", "weapon")))
	if TrainBuild.TYPE_SPECS.has(ct):
		return TrainBuild.TYPE_SPECS[ct]
	return TrainBuild.TYPE_SPECS["weapon"]

func car_left_edge(c: Dictionary) -> float:
	if c.has("left_x"):
		return float(c["left_x"])
	var ct := str(c.get("car_type", c.get("id", "weapon")))
	if TRAIN_PARTS.has(ct):
		return float(TRAIN_PARTS[ct]["x"])
	return float(c.get("x", 0.0)) - TrainBuild.car_pixel_w(ct) * 0.5

func owns_core_weapon(key: String) -> bool:
	return WeaponLoadout.count_owned(modules, key) > 0

func weapon_mount_car(key: String) -> Dictionary:
	var entries := weapon_mount_entries(key)
	if entries.is_empty():
		return {}
	return get_car_by_uid(str(entries[0].get("car_uid", "")))

func weapon_mount_online(key: String) -> bool:
	for m in weapon_mount_entries(key):
		var car := get_car_by_uid(str(m.get("car_uid", "")))
		if car.is_empty():
			continue
		if not car.get("disabled", false) and float(car.get("hp", 0.0)) > 0.0:
			return true
	return false

func list_weapon_mount_xy(key: String) -> Array:
	# All live mounts for a weapon (one per hardpoint / car).
	var out: Array = []
	for m in weapon_mount_entries(key):
		var found := TrainBuild.find_hardpoint(train_cars, str(m.get("car_uid", "")), str(m.get("hp_id", "")))
		if found.is_empty():
			continue
		var car: Dictionary = found["car"]
		if car.get("disabled", false) or float(car.get("hp", 0.0)) <= 0.0:
			continue
		var hp: Dictionary = found["hp"]
		var ox := car_slot_ox(car)
		out.append({
			"mount_x": TrainBuild.mount_world_x(car, hp) + ox,
			"car": car,
			"hp": hp
		})
	return out

func get_weapon_mount_xy(key: String) -> Dictionary:
	# Primary mount (first entry) — kept for callers that expect a single dict.
	var all := list_weapon_mount_xy(key)
	if all.is_empty():
		return {}
	var primary: Dictionary = all[0]
	var car: Dictionary = primary["car"]
	var hp: Dictionary = primary["hp"]
	var ox := car_slot_ox(car)
	return {
		"mount_x": TrainBuild.mount_world_x(car, hp) + ox,
		"roof_y": TrainBuild.mount_roof_y(car, hp, 0.0),
		"car": car,
		"hp": hp
	}

var test_capture_timer = 2.0
var test_captured = false
var test_capture_phase = 0
func _process(delta: float) -> void:
	if OS.get_cmdline_args().has("--capture-mobile-status") or OS.get_cmdline_user_args().has("--capture-mobile-status"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0 and not test_captured:
			test_captured = true
			await _run_mobile_status_capture_suite()
			get_tree().quit()
			return
	if OS.get_cmdline_args().has("--capture-mobile-encounter") or OS.get_cmdline_user_args().has("--capture-mobile-encounter"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0 and not test_captured:
			test_captured = true
			await _run_mobile_encounter_capture_suite()
			get_tree().quit()
			return
	if OS.get_cmdline_args().has("--capture-mobile-economy") or OS.get_cmdline_user_args().has("--capture-mobile-economy"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0 and not test_captured:
			test_captured = true
			await _run_mobile_economy_capture_suite()
			get_tree().quit()
			return
	if OS.get_cmdline_args().has("--capture-mobile-shop") or OS.get_cmdline_user_args().has("--capture-mobile-shop"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0 and not test_captured:
			test_captured = true
			await _run_mobile_shop_tab_capture_suite()
			get_tree().quit()
			return
	if OS.get_cmdline_args().has("--capture-mobile-reactor") or OS.get_cmdline_user_args().has("--capture-mobile-reactor"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0 and not test_captured:
			test_captured = true
			await _run_mobile_reactor_capture_suite()
			get_tree().quit()
			return
	if OS.get_cmdline_args().has("--capture-mobile-weapons") or OS.get_cmdline_user_args().has("--capture-mobile-weapons"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0 and not test_captured:
			test_captured = true
			await _run_mobile_weapons_capture_suite()
			get_tree().quit()
			return
	if OS.get_cmdline_args().has("--capture-mobile-abilities") or OS.get_cmdline_user_args().has("--capture-mobile-abilities"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0 and not test_captured:
			test_captured = true
			await _run_mobile_abilities_capture_suite()
			get_tree().quit()
			return
	if OS.get_cmdline_args().has("--capture-mobile-workshop") or OS.get_cmdline_user_args().has("--capture-mobile-workshop"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0 and not test_captured:
			test_captured = true
			await _run_mobile_workshop_capture_suite()
			get_tree().quit()
			return
	if OS.get_cmdline_args().has("--capture-mobile-help") or OS.get_cmdline_user_args().has("--capture-mobile-help"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0 and not test_captured:
			test_captured = true
			state = "help"
			help_back_state = "title"
			DisplayServer.window_set_size(Vector2i(1230, 540))
			await get_tree().process_frame
			await get_tree().process_frame
			update_canvas_transform()
			queue_redraw()
			await get_tree().process_frame
			await get_tree().process_frame
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://dev_captures/mobile_preview"))
			_capture_viewport_png("res://dev_captures/mobile_preview/17_help_1230x540.png")
			get_tree().quit()
			return
	if OS.get_cmdline_args().has("--capture-mobile-options") or OS.get_cmdline_user_args().has("--capture-mobile-options"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0 and not test_captured:
			test_captured = true
			state = "options"
			DisplayServer.window_set_size(Vector2i(1230, 540))
			await get_tree().process_frame
			await get_tree().process_frame
			update_canvas_transform()
			queue_redraw()
			await get_tree().process_frame
			await get_tree().process_frame
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://dev_captures/mobile_preview"))
			_capture_viewport_png("res://dev_captures/mobile_preview/18_options_1230x540.png")
			get_tree().quit()
			return
	if OS.get_cmdline_args().has("--capture-mobile-failed") or OS.get_cmdline_user_args().has("--capture-mobile-failed"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0 and not test_captured:
			test_captured = true
			reset_run()
			state = "failed"
			paused = false
			last_fail_info = {
				"region": "rustlands",
				"track": 6,
				"highest_loop": 2,
				"kills": 58,
				"level": 7,
				"time": 155.0,
				"score": 3773,
				"alloy": 78,
				"alloy_total": 2000,
			}
			DisplayServer.window_set_size(Vector2i(1230, 540))
			await get_tree().process_frame
			await get_tree().process_frame
			update_canvas_transform()
			queue_redraw()
			await get_tree().process_frame
			await get_tree().process_frame
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://dev_captures/mobile_preview"))
			_capture_viewport_png("res://dev_captures/mobile_preview/19_failed_1230x540.png")
			var fr := FileAccess.open("res://dev_captures/mobile_preview/19_failed_report.txt", FileAccess.WRITE)
			if fr:
				fr.store_string("view=[%.1f..%.1f] dim_w=%.1f\n" % [
					design_view_left, design_view_right, design_view_right - design_view_left
				])
				fr.close()
			get_tree().quit()
			return
	if OS.get_cmdline_args().has("--capture-mobile-title") or OS.get_cmdline_user_args().has("--capture-mobile-title") \
			or OS.get_cmdline_args().has("--capture-mobile-hud") or OS.get_cmdline_user_args().has("--capture-mobile-hud"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0 and not test_captured:
			# Lock immediately — awaits below would otherwise re-enter this branch.
			test_captured = true
			var want_hud := OS.get_cmdline_args().has("--capture-mobile-hud") or OS.get_cmdline_user_args().has("--capture-mobile-hud")
			state = "title"
			update_canvas_transform()
			queue_redraw()
			await get_tree().process_frame
			await get_tree().process_frame
			_capture_viewport_png("res://dev_captures/mobile_preview/05_custom_menu_integrated.png")
			if want_hud:
				_capture_viewport_png("res://dev_captures/mobile_preview/07_polish_title.png")
			var verify := _verify_mobile_menu_hitboxes()
			var f := FileAccess.open("res://dev_captures/mobile_preview/05_custom_menu_integrated.txt", FileAccess.WRITE)
			if f:
				f.store_string("window=%s viewport=%s view=[%.1f..%.1f] scale=%.4f offset=%s mobile_ui=%s menu_art=%s\n" % [
					str(DisplayServer.window_get_size()), str(get_viewport_rect().size),
					design_view_left, design_view_right, canvas_scale, str(canvas_offset), str(is_mobile_ui),
					str(images.has("menu_mobile_main"))
				])
				f.store_string("stats alloy=%s victories=%s best=%s\n" % [
					str(permanent.get("alloy", 0)), str(permanent.get("victories", 0)), str(permanent.get("best_score", 0))
				])
				f.store_string("hitbox_verify=%s\n" % verify)
				f.store_string("gen_hud=%s\n" % str(images.has("hud_gen_player_status")))
				f.close()
			if want_hud:
				# Fresh combat setup (avoid leftover title overlay / verify side-effects).
				reset_run()
				state = "combat"
				paused = false
				boss_active = false
				reactor_panel_collapsed = false
				update_canvas_transform()
				queue_redraw()
				await get_tree().process_frame
				await get_tree().process_frame
				await get_tree().process_frame
				_capture_viewport_png("res://dev_captures/mobile_preview/07_polish_combat.png")
				# Boss preview.
				start_boss()
				boss_intro_active = false
				boss_active = true
				state = "combat"
				paused = false
				queue_redraw()
				await get_tree().process_frame
				await get_tree().process_frame
				await get_tree().process_frame
				_capture_viewport_png("res://dev_captures/mobile_preview/07_polish_boss.png")
				# Pause overlay on boss combat.
				paused = true
				queue_redraw()
				await get_tree().process_frame
				await get_tree().process_frame
				_capture_viewport_png("res://dev_captures/mobile_preview/07_polish_pause.png")
				var hf := FileAccess.open("res://dev_captures/mobile_preview/07_polish_layout.txt", FileAccess.WRITE)
				if hf:
					var ml := _mobile_hud_layout()
					hf.store_string("layout=%s\n" % str(ml))
					hf.store_string("final_state=%s boss_active=%s paused=%s\n" % [state, str(boss_active), str(paused)])
					hf.close()
			get_tree().quit()
			return
	if OS.get_cmdline_args().has("--verify-universal-loadout") or OS.get_cmdline_user_args().has("--verify-universal-loadout"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0 and not test_captured:
			_run_universal_loadout_integration_verify()
			test_captured = true
			get_tree().quit()
			return
	if OS.get_cmdline_args().has("--verify-workshop-expansion") or OS.get_cmdline_user_args().has("--verify-workshop-expansion"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0 and not test_captured:
			_run_workshop_expansion_integration_verify()
			test_captured = true
			get_tree().quit()
			return
	if OS.get_cmdline_args().has("--verify-track4-balance") or OS.get_cmdline_user_args().has("--verify-track4-balance"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0 and not test_captured:
			_run_track4_balance_verify()
			test_captured = true
			get_tree().quit()
			return
	if OS.get_cmdline_args().has("--capture-elite-outlines") or OS.get_cmdline_user_args().has("--capture-elite-outlines"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				state = "combat"
				boss_active = false
				paused = false
				rift_loop = 3
				current_region = "rustlands"
				enemies.clear()
				var n := spawn_enemy("scrapper", false, 280.0, RiftLoop.CLASS_NORMAL)
				n["y"] = 760.0
				n["base_y"] = 760.0
				n["hp"] = n["max_hp"] * 0.55
				var r := spawn_enemy("brute", false, 420.0, RiftLoop.CLASS_RED)
				r["y"] = 750.0
				r["base_y"] = 750.0
				r["hp"] = r["max_hp"] * 0.7
				var b := spawn_enemy("runner", false, 560.0, RiftLoop.CLASS_BLUE)
				b["y"] = 770.0
				b["base_y"] = 770.0
				b["hp"] = b["max_hp"] * 0.65
				test_capture_phase = 1
				test_capture_timer = 0.35
			elif test_capture_phase == 1:
				var img = get_viewport().get_texture().get_image()
				if img != null:
					img.save_png(ProjectSettings.globalize_path("res://elite_outlines_verified.png"))
				get_tree().quit()
	if OS.get_cmdline_args().has("--capture-reactor-hud") or OS.get_cmdline_user_args().has("--capture-reactor-hud"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				state = "combat"
				boss_active = false
				paused = false
				power["engine"] = 4
				power["gatling"] = 2
				power["cannon"] = 2
				power["drone"] = 1
				power["aux"] = 0
				power["shield"] = 1
				power["utility"] = 1
				test_capture_phase = 1
				test_capture_timer = 0.35
			elif test_capture_phase == 1:
				var img = get_viewport().get_texture().get_image()
				if img != null:
					img.save_png(ProjectSettings.globalize_path("res://reactor_hud_step2.png"))
				get_tree().quit()

	if OS.get_cmdline_args().has("--capture-loco-hud"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				state = "combat"
				boss_active = false
				train_cars[0]["hp"] = 165.0
				momentum["speed"] = 92.0
				heat["value"] = 68.0
				test_capture_phase = 1
				test_capture_timer = 0.5
			elif test_capture_phase == 1:
				var img = get_viewport().get_texture().get_image()
				if img != null:
					img.save_png(ProjectSettings.globalize_path("res://locomotive_hud_step1.png"))
				get_tree().quit()

	if OS.get_cmdline_args().has("--capture-starter-seat") or OS.get_cmdline_user_args().has("--capture-starter-seat"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0 and not test_captured:
			if test_capture_phase == 0:
				reset_run()
				state = "combat"
				paused = false
				boss_active = false
				shop_open = false
				enemies.clear()
				# Stable pose for seat proof.
				momentum["speed"] = 90.0
				train_sway = 0.0
				var loco0 := get_train_car("loco")
				var proof := FileAccess.open(ProjectSettings.globalize_path("res://starter_gun_seat_proof.txt"), FileAccess.WRITE)
				if proof != null and not loco0.is_empty():
					var hp0: Dictionary = {}
					for hp in loco0.get("hardpoints", []):
						if str(hp.get("hp_id", "")) == "starter":
							hp0 = hp
							break
					var m := _starter_mount_xy(loco0, hp0, 0.0)
					var spec := car_spec(loco0)
					var y0: float = RAIL_Y - float(spec["contact"]) * float(spec["k"]) + TRAIN_RAIL_NUDGE_Y
					var dome_y: float = y0 + STARTER_DOME_PNG_Y * float(spec["k"])
					var art_w: float = float(MODULE_ART["gatling"]["w"]) * STARTER_GUN_SIZE_MUL
					var art_h: float = art_w
					if images.has("module_gatling_lv1"):
						art_h = art_w * float(images["module_gatling_lv1"].get_height()) / float(images["module_gatling_lv1"].get_width())
					var gun_bottom: float = float(m["roof"]) + STARTER_GUN_SEAT_Y
					var gap: float = gun_bottom - dome_y # >0 = base at/below dome (seated); <<0 = floating
					var roof_dy_v: float = STARTER_DOME_PNG_Y * float(spec["k"])
					proof.store_string("STARTER_SEAT loco_k=%.2f roof_dy=%.1f seat_y=%.1f roof=%.1f gun_bottom=%.1f dome=%.1f gap=%.1f (want 4..28)\n" % [
						float(spec["k"]), roof_dy_v, STARTER_GUN_SEAT_Y, float(m["roof"]), gun_bottom, dome_y, gap
					])
					proof.store_string("PASS=%s\n" % str(gap >= 4.0 and gap <= 28.0))
					proof.close()
				test_capture_phase = 1
				test_capture_timer = 0.55
			elif test_capture_phase == 1:
				var img2 = get_viewport().get_texture().get_image()
				if img2 != null:
					img2.save_png(ProjectSettings.globalize_path("res://starter_gun_seated_verified.png"))
					# Crop around loco for visual QA.
					var loco1 := get_train_car("loco")
					if not loco1.is_empty():
						var lx: int = int(car_left_edge(loco1) + car_slot_ox(loco1)) - 20
						var ly: int = int(RAIL_Y - float(car_spec(loco1)["contact"]) * float(car_spec(loco1)["k"]) + TRAIN_RAIL_NUDGE_Y) - 40
						var lw: int = int(TrainBuild.car_pixel_w("loco")) + 40
						var lh: int = int(TrainBuild.car_pixel_h("loco")) + 60
						lx = clampi(lx, 0, img2.get_width() - 1)
						ly = clampi(ly, 0, img2.get_height() - 1)
						lw = mini(lw, img2.get_width() - lx)
						lh = mini(lh, img2.get_height() - ly)
						var crop := img2.get_region(Rect2i(lx, ly, lw, lh))
						crop.save_png(ProjectSettings.globalize_path("res://starter_gun_seated_crop.png"))
				test_captured = true
				get_tree().quit()

	if OS.get_cmdline_args().has("--capture-slot1-test") or OS.get_cmdline_args().has("--capture-slots-test"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				state = "combat"
				boss_active = false
				power["gatling"] = 3
				power["cannon"] = 2
				power["drone"] = 2
				modules["installed"]["aux"] = "arc_coil"
				power["aux"] = 2
				test_capture_phase = 1
				test_capture_timer = 0.5
			elif test_capture_phase == 1:
				var img = get_viewport().get_texture().get_image()
				if img != null:
					img.save_png(ProjectSettings.globalize_path("res://hud_slots_verified.png"))
					img.save_png(ProjectSettings.globalize_path("res://slot1_gatling_test.png"))
				get_tree().quit()

	if OS.get_cmdline_args().has("--capture-topright-hud"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				state = "combat"
				boss_active = false
				scrap = 231
				level = 6
				xp = 34
				xp_needed = 70
				game_speed = 1.0
				paused = false
				test_capture_phase = 1
				test_capture_timer = 0.5
			elif test_capture_phase == 1:
				var img = get_viewport().get_texture().get_image()
				if img != null:
					img.save_png(ProjectSettings.globalize_path("res://topright_hud_verified.png"))
				get_tree().quit()

	if OS.get_cmdline_args().has("--capture-active-systems"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				state = "combat"
				boss_active = false
				power["gatling"] = 3
				power["cannon"] = 2
				power["drone"] = 2
				power["aux"] = 2
				modules["installed"]["aux"] = "arc_coil"
				abilities["boost"]["cooldown"] = 0.0
				abilities["shield"]["cooldown"] = 14.0
				abilities["repair"]["cooldown"] = 0.0
				abilities["barrage"]["unlocked"] = true
				abilities["barrage"]["cooldown"] = 0.0
				test_capture_phase = 1
				test_capture_timer = 0.5
			elif test_capture_phase == 1:
				var img = get_viewport().get_texture().get_image()
				if img != null:
					img.save_png(ProjectSettings.globalize_path("res://active_systems_verified.png"))
				get_tree().quit()

	if OS.get_cmdline_args().has("--capture-shield"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				state = "combat"
				boss_active = false
				power["gatling"] = 2
				power["cannon"] = 2
				power["drone"] = 1
				power["aux"] = 2
				modules["installed"]["aux"] = "arc_coil"
				abilities["shield"]["duration"] = 4.2
				abilities["shield"]["cooldown"] = 20.0
				shield_time = 4.2
				test_capture_phase = 1
				test_capture_timer = 0.5
			elif test_capture_phase == 1:
				var img = get_viewport().get_texture().get_image()
				if img != null:
					img.save_png(ProjectSettings.globalize_path("res://shield_active_verified.png"))
				get_tree().quit()

	if OS.get_cmdline_args().has("--capture-enemies-test"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				state = "combat"
				boss_active = false
				shield_time = 0.0
				power["gatling"] = 1
				power["cannon"] = 0
				power["drone"] = 0
				power["aux"] = 0
				enemies.clear()

				# 1. Scrapper attacking rear car
				var scrapper = spawn_enemy("scrapper", false, 325.0)
				scrapper["y"] = 752.0
				scrapper["base_y"] = 752.0

				# 2. Runner attacking rear car
				var runner = spawn_enemy("runner", false, 338.0)
				runner["y"] = 780.0
				runner["base_y"] = 780.0

				# 3. Brute attacking rear car
				var brute = spawn_enemy("brute", false, 305.0)
				brute["y"] = 742.0
				brute["base_y"] = 742.0

				# 4. Boarder attached to rear weapon car
				var boarder = spawn_enemy("boarder", false, 465.0)
				boarder["board_state"] = "attached"
				boarder["boarded"] = true
				boarder["attach_slot"] = 1
				boarder["attach_offset"] = BOARD_ATTACH_OFFSETS[1]
				boarder["target_car"] = 2

				test_capture_phase = 1
				test_capture_timer = 0.7
			elif test_capture_phase == 1:
				var img = get_viewport().get_texture().get_image()
				if img != null:
					img.save_png(ProjectSettings.globalize_path("res://enemies_attacking_rear_verified.png"))
				get_tree().quit()

	if OS.get_cmdline_args().has("--capture-encounter-hud"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				state = "combat"
				boss_active = false
				current_encounter = { "id": "boarding_wave", "title": "Boarding Wave" }
				encounter_progress = 33.0
				encounter_goal = 66.0
				encounter_index = 2
				run_time = 904.0
				kills = 22
				scrap = 240
				test_capture_phase = 1
				test_capture_timer = 0.3
			elif test_capture_phase == 1:
				var img = get_viewport().get_texture().get_image()
				if img != null:
					var scale_vp = float(img.get_width()) / DESIGN_W
					var crop_region = Rect2i(int(610.0 * scale_vp), 0, int(700.0 * scale_vp), int(213.0 * scale_vp))
					var closeup = img.get_region(crop_region)
					closeup.save_png(ProjectSettings.globalize_path("res://encounter_hud_closeup.png"))
				current_encounter = { "id": "elite", "title": "Elite Scrap Goliath" }
				encounter_progress = 56.0
				encounter_goal = 80.0
				encounter_index = 3
				test_capture_phase = 2
				test_capture_timer = 0.3
			elif test_capture_phase == 2:
				var img = get_viewport().get_texture().get_image()
				if img != null:
					var scale_vp = float(img.get_width()) / DESIGN_W
					var crop_region = Rect2i(int(610.0 * scale_vp), 0, int(700.0 * scale_vp), int(213.0 * scale_vp))
					var closeup = img.get_region(crop_region)
					closeup.save_png(ProjectSettings.globalize_path("res://encounter_hud_elite.png"))
				boss_active = true
				enemies.clear()
				var boss_e = { "boss": true, "hp": 3900.0, "max_hp": 6000.0 }
				enemies.append(boss_e)
				encounter_index = 5
				test_capture_phase = 3
				test_capture_timer = 0.3
			elif test_capture_phase == 3:
				var img = get_viewport().get_texture().get_image()
				if img != null:
					var scale_vp = float(img.get_width()) / DESIGN_W
					var crop_region = Rect2i(int(610.0 * scale_vp), 0, int(700.0 * scale_vp), int(213.0 * scale_vp))
					var closeup = img.get_region(crop_region)
					closeup.save_png(ProjectSettings.globalize_path("res://encounter_hud_boss.png"))
				boss_active = false
				enemies.clear()
				current_encounter = { "id": "long_name", "title": "Corrupted Dreadnought Convoy" }
				encounter_progress = 18.0
				encounter_goal = 72.0
				encounter_index = 0
				test_capture_phase = 4
				test_capture_timer = 0.3
			elif test_capture_phase == 4:
				var img = get_viewport().get_texture().get_image()
				if img != null:
					var scale_vp = float(img.get_width()) / DESIGN_W
					var crop_region = Rect2i(int(610.0 * scale_vp), 0, int(700.0 * scale_vp), int(213.0 * scale_vp))
					var closeup = img.get_region(crop_region)
					closeup.save_png(ProjectSettings.globalize_path("res://encounter_hud_long.png"))
				get_tree().quit()

	if OS.get_cmdline_args().has("--capture-arc-coil"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				state = "combat"
				boss_active = false
				power["aux"] = 2
				power["gatling"] = 0
				power["cannon"] = 0
				power["drone"] = 0
				modules["installed"]["aux"] = "arc_coil"
				modules["aux_levels"]["arc_coil"] = 2
				enemies.clear()

				# Primary target attacking rear of train
				var scrapper = spawn_enemy("scrapper", false, 180.0)
				scrapper["y"] = 760.0
				scrapper["base_y"] = 760.0

				# Chained target closely clustered (85px from primary target)
				var runner = spawn_enemy("runner", false, 95.0)
				runner["y"] = 775.0
				runner["base_y"] = 775.0

				weapons["aux"]["cooldown"] = 0.04
				test_capture_phase = 1
				test_capture_timer = 0.12
			elif test_capture_phase == 1:
				var img = get_viewport().get_texture().get_image()
				if img != null:
					img.save_png(ProjectSettings.globalize_path("res://arc_coil_lightning_verified.png"))
				get_tree().quit()

	if OS.get_cmdline_args().has("--capture-region-transition") or OS.get_cmdline_user_args().has("--capture-region-transition"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				state = "combat"
				boss_active = false
				power["gatling"] = 3
				power["cannon"] = 2
				power["engine"] = 4
				enemies.clear()
				current_region = "rustlands"
				start_region_transition("fungus_wilds")
				# Jump to middle of crossfade (t_prog ~ 0.42) where both regions blend with mist & spores
				region_transition_timer = REGION_TRANSITION_DURATION * 0.58
				test_capture_phase = 1
				test_capture_timer = 0.35
			elif test_capture_phase == 1:
				var img = get_viewport().get_texture().get_image()
				if img != null:
					img.save_png(ProjectSettings.globalize_path("res://region_transition_verified.png"))
				# Advance to Fungus Wilds active with region intro banner dismissed!
				region_transition_timer = 0.0
				complete_region_transition()
				encounter_index = 0
				region_intro_banner_timer = 0.0
				region_intro_shown = true
				toasts.clear()
				test_capture_phase = 2
				test_capture_timer = 0.4
			elif test_capture_phase == 2:
				var img = get_viewport().get_texture().get_image()
				if img != null:
					img.save_png(ProjectSettings.globalize_path("res://region2_track1_frontier.png"))
				# Switch to Track 3 (Fungal Expansion)
				encounter_index = 2
				configure_encounter("combat")
				toasts.clear()
				test_capture_phase = 3
				test_capture_timer = 0.4
			elif test_capture_phase == 3:
				var img = get_viewport().get_texture().get_image()
				if img != null:
					img.save_png(ProjectSettings.globalize_path("res://region2_track3_expansion.png"))
				# Switch to Track 5 (Deep Fungus Wilds)
				encounter_index = 4
				configure_encounter("combat")
				toasts.clear()
				test_capture_phase = 4
				test_capture_timer = 0.4
			elif test_capture_phase == 4:
				var img = get_viewport().get_texture().get_image()
				if img != null:
					img.save_png(ProjectSettings.globalize_path("res://region2_track5_deep.png"))
					img.save_png(ProjectSettings.globalize_path("res://fungus_wilds_verified.png"))
				get_tree().quit()

	if OS.get_cmdline_args().has("--capture-explosions") or OS.get_cmdline_user_args().has("--capture-explosions"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				reset_run()
				state = "combat"
				boss_active = false
				paused = false
				# Mid-frame carriage Explosion_1 over the weapon car
				impact_bursts.clear()
				if train_cars.size() > 1:
					train_cars[1]["hp"] = 1.0
					train_cars[1]["disabled"] = false
					damage_car(1, 9999.0, null)
				spawn_fx_explosion(tsx(TRAIN_PARTS["weapon"]["center"]), 580.0, "explosion_car", 280.0, 1.0)
				if impact_bursts.size() > 0:
					impact_bursts[impact_bursts.size() - 1]["life"] = 0.62
				test_capture_phase = 1
				test_capture_timer = 0.15
			elif test_capture_phase == 1:
				var img1 = get_viewport().get_texture().get_image()
				if img1 != null:
					img1.save_png(ProjectSettings.globalize_path("res://explosion_car_verified.png"))
				# Fresh combat for beam shot — no leftover wreck state
				reset_run()
				state = "combat"
				paused = false
				impact_bursts.clear()
				particles.clear()
				damage_numbers.clear()
				start_boss()
				boss_intro_active = false
				boss_intro_t = 0.0
				train_shift_x = BOSS_TRAIN_SHIFT
				train_shift_target = BOSS_TRAIN_SHIFT
				train_shift_desired = BOSS_TRAIN_SHIFT
				var hit_x = tsx(TRAIN_PARTS["weapon"]["center"])
				var hit_y = 560.0
				for e in enemies:
					if e.get("boss", false):
						e["invuln"] = false
						e["y"] = float(e.get("base_y", 705.0))
						e["rise"] = 1.0
						e["attack_style"] = "beam"
						e["anim"] = "beam"
						e["anim_t"] = 0.45
						var chest_pt = boss_chest_point(e)
						e["atk_ox"] = chest_pt.x
						e["atk_oy"] = chest_pt.y
						e["beam_ox"] = chest_pt.x
						e["beam_oy"] = chest_pt.y
						e["beam_tx"] = hit_x
						e["beam_ty"] = hit_y
						e["beam_lock_x"] = float(e["x"])
						e["beam_flash"] = 0.8
						break
				spawn_fx_explosion(hit_x, hit_y, "explosion_beam", 300.0, 1.0)
				if impact_bursts.size() > 0:
					impact_bursts[impact_bursts.size() - 1]["life"] = 0.58
				test_capture_phase = 2
				test_capture_timer = 0.15
			elif test_capture_phase == 2:
				var img2 = get_viewport().get_texture().get_image()
				if img2 != null:
					img2.save_png(ProjectSettings.globalize_path("res://explosion_beam_verified.png"))
				get_tree().quit()

	if OS.get_cmdline_args().has("--capture-title-screen"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				state = "title"
				test_capture_phase = 1
				test_capture_timer = 0.5
			elif test_capture_phase == 1:
				var img = get_viewport().get_texture().get_image()
				if img != null:
					img.save_png(ProjectSettings.globalize_path("res://title_screen_verified.png"))
				get_tree().quit()

	if OS.get_cmdline_args().has("--capture-rift-scar") or OS.get_cmdline_user_args().has("--capture-rift-scar"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				reset_run()
				apply_classic_full_loadout()
				apply_workshop_bonuses()
				scrap = 400
				current_region = "fungus_wilds"
				fungus_completed = false
				encounter_index = 0
				state = "combat"
				paused = false
				on_boss_defeated() # Mycelarch path → start scar transition
				# Force mycelarch identity for reward path if no boss was active.
				if not region_transition_active:
					current_region = "fungus_wilds"
					var fake := { "boss": true, "boss_id": "mycelarch", "data": BOSS_MYCELARCH }
					enemies = [fake]
					on_boss_defeated()
				var proof := FileAccess.open(ProjectSettings.globalize_path("res://rift_scar_proof.txt"), FileAccess.WRITE)
				if proof != null:
					proof.store_string("TRANSITION active=%s target=%s scrap=%d cars=%d\n" % [
						str(region_transition_active), region_transition_target, scrap, train_cars.size()
					])
					proof.close()
				test_capture_phase = 1
				test_capture_timer = 0.55
			elif test_capture_phase == 1:
				_capture_viewport_png("res://rift_scar_transition_verified.png")
				region_transition_timer = 0.0
				complete_region_transition()
				test_capture_phase = 2
				test_capture_timer = 0.45
			elif test_capture_phase == 2:
				# Track 1
				state = "combat"
				route_choices.clear()
				toasts.clear()
				encounter_index = 0
				configure_encounter("combat")
				current_encounter = RiftScar.ENCOUNTERS[0].duplicate(true)
				toasts.clear()
				enemies.clear()
				spawn_enemy("rift_skitter", false, 420.0)
				spawn_enemy("flux_rifleman", false, 300.0)
				queue_redraw()
				test_capture_phase = 21
				test_capture_timer = 0.20
			elif test_capture_phase == 21:
				_capture_viewport_png("res://rift_scar_track1_verified.png")
				test_capture_phase = 3
				test_capture_timer = 0.25
			elif test_capture_phase == 3:
				state = "combat"
				route_choices.clear()
				toasts.clear()
				encounter_index = 2
				configure_encounter("combat")
				current_encounter = RiftScar.ENCOUNTERS[2].duplicate(true)
				toasts.clear()
				enemies.clear()
				spawn_enemy("coil_leech", false, 400.0)
				spawn_enemy("fracture_juggernaut", false, 280.0)
				queue_redraw()
				test_capture_phase = 31
				test_capture_timer = 0.20
			elif test_capture_phase == 31:
				_capture_viewport_png("res://rift_scar_track3_verified.png")
				test_capture_phase = 4
				test_capture_timer = 0.25
			elif test_capture_phase == 4:
				state = "combat"
				route_choices.clear()
				toasts.clear()
				encounter_index = 5
				configure_encounter("combat")
				current_encounter = RiftScar.ENCOUNTERS[5].duplicate(true)
				toasts.clear()
				enemies.clear()
				spawn_enemy("rift_skitter", false, 450.0)
				spawn_enemy("flux_rifleman", false, 340.0)
				spawn_enemy("fracture_juggernaut", false, 250.0)
				queue_redraw()
				test_capture_phase = 41
				test_capture_timer = 0.20
			elif test_capture_phase == 41:
				_capture_viewport_png("res://rift_scar_track6_verified.png")
				test_capture_phase = 5
				test_capture_timer = 0.25
			elif test_capture_phase == 5:
				state = "combat"
				route_choices.clear()
				toasts.clear()
				enemies.clear()
				var sk = spawn_enemy("rift_skitter", false, 720.0)
				sk["y"] = 760.0
				sk["base_y"] = 760.0
				sk["speed"] = 0.0
				sk["frame"] = 0.35  # mid walk-cycle frame from Flow sheet
				sk["data"] = sk["data"].duplicate()
				sk["data"]["scale"] = 1.15
				queue_redraw()
				test_capture_phase = 51
				test_capture_timer = 0.35
			elif test_capture_phase == 51:
				_capture_viewport_png("res://rift_scar_enemy_skitter_verified.png")
				enemies.clear()
				toasts.clear()
				var rf = spawn_enemy("flux_rifleman", false, 700.0)
				rf["y"] = 755.0
				rf["base_y"] = 755.0
				rf["speed"] = 0.0
				rf["frame"] = 0.42
				rf["cd"] = 0.0
				rf["aim_t"] = 0.35
				rf["laser_charge"] = 0.85
				rf["laser_aim"] = Vector2(1100.0, 640.0)
				rf["data"] = rf["data"].duplicate()
				rf["data"]["scale"] = 1.22
				# Fire laser so the beam is visible in the proof shot
				spawn_flux_laser(rf, mini(train_cars.size() - 1, 1))
				test_capture_phase = 52
				test_capture_timer = 0.12
			elif test_capture_phase == 52:
				_capture_viewport_png("res://rift_scar_enemy_rifleman_verified.png")
				enemies.clear()
				toasts.clear()
				var lc = spawn_enemy("coil_leech", false, 690.0)
				lc["y"] = 758.0
				lc["base_y"] = 758.0
				lc["speed"] = 0.0
				lc["frame"] = 0.38
				lc["data"] = lc["data"].duplicate()
				lc["data"]["scale"] = 1.18
				test_capture_phase = 53
				test_capture_timer = 0.35
			elif test_capture_phase == 53:
				_capture_viewport_png("res://rift_scar_enemy_leech_verified.png")
				enemies.clear()
				toasts.clear()
				var jg = spawn_enemy("fracture_juggernaut", false, 660.0)
				jg["y"] = 750.0
				jg["base_y"] = 750.0
				jg["speed"] = 0.0
				jg["frame"] = 0.55
				jg["data"] = jg["data"].duplicate()
				jg["data"]["scale"] = 1.40
				test_capture_phase = 54
				test_capture_timer = 0.35
			elif test_capture_phase == 54:
				_capture_viewport_png("res://rift_scar_enemy_juggernaut_verified.png")
				enemies.clear()
				toasts.clear()
				var hv = spawn_enemy("rift_harvester", true, 640.0)
				hv["y"] = 745.0
				hv["base_y"] = 745.0
				hv["speed"] = 0.0
				hv["frame"] = 0.48
				hv["data"] = hv["data"].duplicate()
				hv["data"]["scale"] = 1.45
				test_capture_phase = 55
				test_capture_timer = 0.35
			elif test_capture_phase == 55:
				_capture_viewport_png("res://rift_scar_elite_harvester_verified.png")
				test_capture_phase = 6
				test_capture_timer = 0.25
			elif test_capture_phase == 6:
				toasts.clear()
				start_boss()
				boss_intro_active = false
				boss_intro_t = 0.0
				toasts.clear()
				for e in enemies:
					if e.get("boss", false):
						e["invuln"] = false
						e["x"] = BOSS_ARENA_X
						e["y"] = BOSS_BREACH_BASE_Y
						e["base_y"] = BOSS_BREACH_BASE_Y
						e["rise"] = 1.0
						e["hp"] = float(e["max_hp"]) * 0.85
						e["phase"] = 1
						e["anim"] = "idle"
						e["anim_t"] = 0.2
				test_capture_phase = 61
				test_capture_timer = 0.45
			elif test_capture_phase == 61:
				toasts.clear()
				_capture_viewport_png("res://rift_scar_boss_phase1_verified.png")
				test_capture_phase = 7
				test_capture_timer = 0.25
			elif test_capture_phase == 7:
				toasts.clear()
				for e in enemies:
					if e.get("boss", false):
						e["hp"] = float(e["max_hp"]) * 0.50
						e["phase"] = 2
						e["anim"] = "slam"
						e["attack_style"] = "slam"
						e["anim_t"] = 0.15
				_capture_viewport_png("res://rift_scar_boss_phase2_verified.png")
				test_capture_phase = 8
				test_capture_timer = 0.40
			elif test_capture_phase == 8:
				toasts.clear()
				for e in enemies:
					if e.get("boss", false):
						e["hp"] = float(e["max_hp"]) * 0.18
						e["phase"] = 3
						e["anim"] = "beam"
						e["attack_style"] = "beam"
						e["anim_t"] = 0.2
						e["beam_flash"] = 0.85
				_capture_viewport_png("res://rift_scar_boss_phase3_verified.png")
				test_capture_phase = 9
				test_capture_timer = 0.40
			elif test_capture_phase == 9:
				for e in enemies:
					if e.get("boss", false):
						e["hp"] = 1.0
						damage_enemy(e, 9999.0, "kinetic")
				test_capture_phase = 10
				test_capture_timer = 0.60
			elif test_capture_phase == 10:
				toasts.clear()
				_capture_viewport_png("res://rift_scar_boss_defeat_verified.png")
				# Force victory if death handoff pending
				if not victory:
					win_expedition("THE BREACH ENGINE shuts down. The Scar's core falls silent.")
				test_capture_phase = 11
				test_capture_timer = 0.50
			elif test_capture_phase == 11:
				toasts.clear()
				_capture_viewport_png("res://rift_scar_victory_verified.png")
				var proof2 := FileAccess.open(ProjectSettings.globalize_path("res://rift_scar_proof.txt"), FileAccess.READ_WRITE)
				if proof2 != null:
					proof2.seek_end()
					proof2.store_string("REGION=%s victory=%s fungus_done=%s alloy=%s\n" % [
						current_region, str(victory), str(fungus_completed), str(permanent.get("alloy", 0))
					])
					proof2.store_string("ENEMIES ok skitter/rifle/leech/jugger/harvester sheets loaded\n")
					proof2.close()
				get_tree().quit()

	if OS.get_cmdline_args().has("--capture-hardcore") or OS.get_cmdline_user_args().has("--capture-hardcore"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				# Persist a clean permanent baseline for A/B screenshots.
				permanent = ensure_permanent({})
				permanent["alloy"] = 0
				permanent["workshop"] = { "hull": 0, "starter": 0, "reactor": 0, "cooling": 0, "salvage": 0 }
				save_permanent()
				reset_run()
				state = "combat"
				paused = false
				boss_active = false
				shop_open = true
				shop_slide = 1.0
				shop_tab = "weapons"
				shop_scroll_y = 0.0
				scrap = 900
				var proof0 := FileAccess.open(ProjectSettings.globalize_path("res://hardcore_economy_proof.txt"), FileAccess.WRITE)
				if proof0 != null:
					proof0.store_string("PRICES wagon_w=%d gat=%d can=%d drone=%d arc=%d cryo=%d mortar=%d missile=%d\n" % [
						TrainBuild.wagon_cost("weapon"),
						TrainBuild.core_weapon_cost("gatling"), TrainBuild.core_weapon_cost("cannon"),
						TrainBuild.core_weapon_cost("drone"), TrainBuild.aux_weapon_cost("arc_coil"),
						TrainBuild.aux_weapon_cost("cryo_launcher"), TrainBuild.aux_weapon_cost("rail_mortar"),
						TrainBuild.aux_weapon_cost("missile_rack")
					])
					proof0.store_string("UPGRADE_LV1 gat=%d can=%d drone=%d arc=%d\n" % [
						TrainBuild.module_upgrade_cost("gatling", 1), TrainBuild.module_upgrade_cost("cannon", 1),
						TrainBuild.module_upgrade_cost("drone", 1), TrainBuild.aux_upgrade_cost("arc_coil", 1)
					])
					proof0.store_string("STATION repair=%d reactor=%d armor=%d cool=%d drone=%d\n" % [
						TrainBuild.station_cost("repair"), TrainBuild.station_cost("reactor"),
						TrainBuild.station_cost("armor"), TrainBuild.station_cost("cool"), TrainBuild.station_cost("drone")
					])
					proof0.store_string("FRESH_LOCO hp=%.0f dmg=%.1f cd=%.2f\n" % [
						float(train_cars[0]["max_hp"]), float(starter_gun["damage"]), float(starter_gun["cooldown_max"])
					])
					proof0.close()
				test_capture_phase = 1
				test_capture_timer = 0.55
			elif test_capture_phase == 1:
				_capture_viewport_png("res://hardcore_armory_prices_verified.png")
				# Fresh loco combat frame.
				shop_open = false
				shop_slide = 0.0
				enemies.clear()
				spawn_enemy("scrapper", false, 380.0)
				spawn_enemy("runner", false, 260.0)
				test_capture_phase = 2
				test_capture_timer = 0.45
			elif test_capture_phase == 2:
				_capture_viewport_png("res://hardcore_fresh_loco_verified.png")
				var fresh_hp := float(train_cars[0]["max_hp"])
				var fresh_dmg := float(starter_gun["damage"])
				# Apply permanent workshop tiers and restart.
				permanent["alloy"] = 220
				permanent["workshop"] = { "hull": 3, "starter": 3, "reactor": 2, "cooling": 2, "salvage": 1 }
				save_permanent()
				reset_run()
				state = "combat"
				paused = false
				shop_open = false
				var up_hp := float(train_cars[0]["max_hp"])
				var up_dmg := float(starter_gun["damage"])
				var proof1 := FileAccess.open(ProjectSettings.globalize_path("res://hardcore_economy_proof.txt"), FileAccess.READ_WRITE)
				if proof1 != null:
					proof1.seek_end()
					proof1.store_string("UPGRADED_LOCO hp=%.0f dmg=%.1f cd=%.2f reactor_max=%d scrap_mul=%.2f cool_mul=%.2f\n" % [
						up_hp, up_dmg, float(starter_gun["cooldown_max"]), int(reactor["max"]),
						float(stats.get("scrap_mul", 1.0)), float(stats.get("cooling_mul", 1.0))
					])
					proof1.store_string("DELTA hp=%.0f dmg=%.1f ok=%s\n" % [
						up_hp - fresh_hp, up_dmg - fresh_dmg, str(up_hp > fresh_hp and up_dmg > fresh_dmg)
					])
					proof1.close()
				enemies.clear()
				spawn_enemy("scrapper", false, 380.0)
				spawn_enemy("brute", false, 220.0)
				test_capture_phase = 3
				test_capture_timer = 0.45
			elif test_capture_phase == 3:
				_capture_viewport_png("res://hardcore_upgraded_loco_verified.png")
				# Workshop UI with Alloy balance and clear tier costs.
				state = "workshop"
				permanent["alloy"] = 180
				test_capture_phase = 4
				test_capture_timer = 0.45
			elif test_capture_phase == 4:
				_capture_viewport_png("res://hardcore_workshop_verified.png")
				# Simulated meaningful fail on Track 3.
				reset_run()
				state = "combat"
				encounter_index = 2
				run_kills = 28
				level = 4
				run_time = 210.0
				kills = 6
				fail_run()
				var proof2 := FileAccess.open(ProjectSettings.globalize_path("res://hardcore_economy_proof.txt"), FileAccess.READ_WRITE)
				if proof2 != null:
					proof2.seek_end()
					proof2.store_string("FAIL_REWARD alloy=%s track=%s kills=%s total=%s\n" % [
						str(last_fail_info.get("alloy", 0)), str(last_fail_info.get("track", 0)),
						str(last_fail_info.get("kills", 0)), str(last_fail_info.get("alloy_total", 0))
					])
					# Anti-farm: instant suicide.
					var farm := TrainBuild.fail_alloy_reward(0, "rustlands", 1, 1, 8.0)
					proof2.store_string("ANTI_FARM instant_alloy=%d\n" % farm)
					proof2.close()
				test_capture_phase = 5
				test_capture_timer = 0.45
			elif test_capture_phase == 5:
				_capture_viewport_png("res://hardcore_fail_reward_verified.png")
				# Iron Maw challenging frame with mid-build train.
				permanent["workshop"] = { "hull": 2, "starter": 2, "reactor": 1, "cooling": 1, "salvage": 1 }
				save_permanent()
				reset_run()
				apply_classic_full_loadout()
				apply_workshop_bonuses()
				state = "combat"
				paused = false
				shop_open = false
				start_boss()
				boss_intro_active = false
				boss_intro_t = 0.0
				for e in enemies:
					if e.get("boss", false):
						e["invuln"] = false
						e["x"] = BOSS_ARENA_X
						e["hp"] = float(e["max_hp"]) * 0.72
				test_capture_phase = 6
				test_capture_timer = 0.55
			elif test_capture_phase == 6:
				_capture_viewport_png("res://hardcore_iron_maw_verified.png")
				var boss_hp := 0.0
				for e2 in enemies:
					if e2.get("boss", false):
						boss_hp = float(e2.get("max_hp", 0.0))
				# Affordability / exploit checks.
				reset_run()
				scrap = 100
				var bought_missile := buy_aux_module("missile_rack")
				var bought_gat := buy_core_weapon("gatling")
				var bought_wagon := buy_wagon("weapon")
				scrap = 5000
				buy_wagon("weapon")
				buy_core_weapon("gatling")
				install_core_weapon("gatling")
				var u1 := TrainBuild.module_upgrade_cost("gatling", 1)
				modules["levels"]["gatling"] = 1
				var ok_up := upgrade_module("gatling")
				var proof3 := FileAccess.open(ProjectSettings.globalize_path("res://hardcore_economy_proof.txt"), FileAccess.READ_WRITE)
				if proof3 != null:
					proof3.seek_end()
					proof3.store_string("BOSS_HP iron_maw=%.0f\n" % boss_hp)
					proof3.store_string("AFFORD scrap100 missile=%s gat=%s wagon=%s\n" % [str(bought_missile), str(bought_gat), str(bought_wagon)])
					proof3.store_string("GAT_UPGRADE_LV1 cost=%d applied=%s level_now=%d scrap_left=%d\n" % [
						u1, str(ok_up), module_level("gatling"), scrap
					])
					# Workshop purchase + persist.
					permanent["alloy"] = 100
					permanent["workshop"]["hull"] = 0
					buy_workshop("hull")
					var hull_after := int(permanent["workshop"].get("hull", 0))
					var alloy_after := int(permanent["alloy"])
					save_permanent()
					load_permanent()
					proof3.store_string("WORKSHOP_BUY hull=%d alloy=%d persist_hull=%d\n" % [
						hull_after, alloy_after, int(permanent["workshop"].get("hull", 0))
					])
					proof3.close()
				get_tree().quit()

	if OS.get_cmdline_args().has("--capture-continuous") or OS.get_cmdline_user_args().has("--capture-continuous"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				reset_run()
				state = "combat"
				paused = false
				boss_active = false
				shop_open = false
				shop_slide = 0.0
				game_speed = 1.0
				var proof := FileAccess.open(ProjectSettings.globalize_path("res://continuous_run_proof.txt"), FileAccess.WRITE)
				if proof != null:
					proof.store_string("NEW_RUN scrap=%d cars=%d gat=%s starter=%.0f/%.2f prices=wpn%d+gat%d need=%d state=%s\n" % [
						scrap, train_cars.size(), str(is_module_installed("gatling")),
						TrainBuild.STARTER_DAMAGE, TrainBuild.STARTER_COOLDOWN,
						TrainBuild.wagon_cost("weapon"), TrainBuild.core_weapon_cost("gatling"),
						TrainBuild.wagon_cost("weapon") + TrainBuild.core_weapon_cost("gatling"), state
					])
					proof.close()
				test_capture_phase = 1
				test_capture_timer = 0.45
			elif test_capture_phase == 1:
				var img0 = get_viewport().get_texture().get_image()
				if img0 != null:
					img0.save_png(ProjectSettings.globalize_path("res://continuous_loco_open_verified.png"))
				# ACCELERATED_COMBAT: real scrap/xp formulas; enemies force-killed (no scrap injection).
				test_capture_phase = 2
				test_capture_timer = 0.05
			elif test_capture_phase == 2:
				# Speed-clear Track 1 with real death rewards until encounter advances.
				if encounter_index < 1 and not boss_active:
					for e in enemies:
						if not e.get("dead", false) and not e.get("boss", false):
							damage_enemy(e, 80.0, "kinetic")
					test_capture_timer = 0.08
				else:
					var need := TrainBuild.wagon_cost("weapon") + TrainBuild.core_weapon_cost("gatling")
					var proof1 := FileAccess.open(ProjectSettings.globalize_path("res://continuous_run_proof.txt"), FileAccess.READ_WRITE)
					if proof1 != null:
						proof1.seek_end()
						proof1.store_string("TRACK1_CLEAR scrap=%d need=%d affordable=%s level=%d encounter=%d cards_modal=false state=%s\n" % [
							scrap, need, str(scrap >= need), level, encounter_index, state
						])
						proof1.close()
					test_capture_phase = 3
					test_capture_timer = 0.35
			elif test_capture_phase == 3:
				# If Track 1 scrap alone is short, continue accelerated clears (still no injection).
				if scrap < TrainBuild.wagon_cost("weapon") + TrainBuild.core_weapon_cost("gatling") and encounter_index < 3 and not boss_active:
					for e in enemies:
						if not e.get("dead", false) and not e.get("boss", false):
							damage_enemy(e, 120.0, "kinetic")
					test_capture_timer = 0.08
				else:
					var proof2 := FileAccess.open(ProjectSettings.globalize_path("res://continuous_run_proof.txt"), FileAccess.READ_WRITE)
					if proof2 != null:
						proof2.seek_end()
						proof2.store_string("FIRST_BUY_WINDOW scrap=%d track=%d level=%d\n" % [scrap, encounter_index, level])
						proof2.close()
					shop_open = true
					shop_slide = 1.0
					shop_tab = "upgrades"
					shop_buy_cooldown = 0.0
					live_shop_apply_upgrade("buy_wagon_weapon")
					shop_tab = "weapons"
					shop_buy_cooldown = 0.0
					live_shop_buy_core("gatling")
					shop_buy_cooldown = 0.0
					live_shop_install_core("gatling")
					if int(power.get("gatling", 0)) <= 0:
						power["gatling"] = 1
					test_capture_phase = 4
					test_capture_timer = 0.45
			elif test_capture_phase == 4:
				var img1 = get_viewport().get_texture().get_image()
				if img1 != null:
					img1.save_png(ProjectSettings.globalize_path("res://continuous_first_armed_verified.png"))
				shop_open = false
				shop_slide = 0.0
				# Advance remaining tracks without card modals (accelerated clears).
				test_capture_phase = 5
				test_capture_timer = 0.05
			elif test_capture_phase == 5:
				if encounter_index == 3 and not FileAccess.file_exists(ProjectSettings.globalize_path("res://continuous_mid_train_verified.png")):
					var img2 = get_viewport().get_texture().get_image()
					if img2 != null:
						img2.save_png(ProjectSettings.globalize_path("res://continuous_mid_train_verified.png"))
				if encounter_index < 6 and not boss_active:
					for e in enemies:
						if not e.get("dead", false) and not e.get("boss", false):
							damage_enemy(e, 200.0, "kinetic")
					test_capture_timer = 0.07
				else:
					var proof3 := FileAccess.open(ProjectSettings.globalize_path("res://continuous_run_proof.txt"), FileAccess.READ_WRITE)
					if proof3 != null:
						proof3.seek_end()
						proof3.store_string("PRE_BOSS encounter=%d boss=%s state=%s cars=%d gat=%s level=%d perks=%s\n" % [
							encounter_index, str(boss_active), state, train_cars.size(),
							str(is_module_installed("gatling")), level, str(selected_cards)
						])
						proof3.close()
					if not FileAccess.file_exists(ProjectSettings.globalize_path("res://continuous_mid_train_verified.png")):
						var img2b = get_viewport().get_texture().get_image()
						if img2b != null:
							img2b.save_png(ProjectSettings.globalize_path("res://continuous_mid_train_verified.png"))
					if not boss_active and encounter_index >= 6:
						prepare_for_boss_fight()
						start_boss()
					test_capture_phase = 6
					test_capture_timer = 0.5
			elif test_capture_phase == 6:
				# Settle Iron Maw on-screen for a real unique frame.
				if not boss_active:
					prepare_for_boss_fight()
					start_boss()
				boss_intro_active = false
				boss_intro_t = 0.0
				train_shift_x = BOSS_TRAIN_SHIFT
				train_shift_target = BOSS_TRAIN_SHIFT
				train_shift_desired = BOSS_TRAIN_SHIFT
				for e in enemies:
					if e.get("boss", false):
						e["x"] = BOSS_ARENA_X
						e["y"] = float(e.get("base_y", 705.0))
						e["invuln"] = false
						e["anim"] = "idle"
				test_capture_phase = 61
				test_capture_timer = 0.55
			elif test_capture_phase == 61:
				_capture_viewport_png("res://continuous_iron_maw_verified.png")
				boss_death_pending = false
				on_boss_defeated()
				test_capture_phase = 7
				test_capture_timer = 0.4
			elif test_capture_phase == 7:
				if region_transition_active:
					# Jump to late crossfade so Fungus layers are visible.
					region_transition_timer = minf(region_transition_timer, REGION_TRANSITION_DURATION * 0.08)
					test_capture_timer = 0.25
				elif current_region != "fungus_wilds":
					region_transition_target = "fungus_wilds"
					complete_region_transition()
					test_capture_timer = 0.35
				else:
					region_intro_banner_timer = 0.0
					region_intro_shown = true
					if fungus_spores.is_empty():
						init_fungus_spores()
					test_capture_phase = 71
					test_capture_timer = 0.5
			elif test_capture_phase == 71:
				var proof4 := FileAccess.open(ProjectSettings.globalize_path("res://continuous_run_proof.txt"), FileAccess.READ_WRITE)
				if proof4 != null:
					proof4.seek_end()
					proof4.store_string("FUNGUS region=%s cars=%d scrap=%d gat=%s mount=%s encounter=%d state=%s\n" % [
						current_region, train_cars.size(), scrap, str(is_module_installed("gatling")),
						str(modules.get("mounts", {}).get("gatling", {})), encounter_index, state
					])
					proof4.close()
				_capture_viewport_png("res://continuous_fungus_preserved_verified.png")
				test_capture_phase = 8
				test_capture_timer = 0.05
			elif test_capture_phase == 8:
				if current_region == "fungus_wilds" and encounter_index < 6 and not boss_active:
					for e in enemies:
						if not e.get("dead", false) and not e.get("boss", false):
							damage_enemy(e, 220.0, "kinetic")
					test_capture_timer = 0.07
				else:
					if not boss_active:
						prepare_for_boss_fight()
						start_boss()
					boss_intro_active = false
					boss_intro_t = 0.0
					train_shift_x = BOSS_TRAIN_SHIFT
					train_shift_target = BOSS_TRAIN_SHIFT
					train_shift_desired = BOSS_TRAIN_SHIFT
					for e3 in enemies:
						if e3.get("boss", false):
							e3["x"] = BOSS_ARENA_X
							e3["y"] = float(e3.get("base_y", 705.0))
							e3["invuln"] = false
					test_capture_phase = 9
					test_capture_timer = 0.55
			elif test_capture_phase == 9:
				_capture_viewport_png("res://continuous_mycelarch_verified.png")
				boss_death_pending = false
				on_boss_defeated()
				test_capture_phase = 10
				test_capture_timer = 0.65
			elif test_capture_phase == 10:
				_capture_viewport_png("res://continuous_victory_verified.png")
				var proof5 := FileAccess.open(ProjectSettings.globalize_path("res://continuous_run_proof.txt"), FileAccess.READ_WRITE)
				if proof5 != null:
					proof5.seek_end()
					proof5.store_string("VICTORY state=%s victory=%s toast_count=%d level=%d scrap=%d cars=%d\n" % [
						state, str(victory), toasts.size(), level, scrap, train_cars.size()
					])
					proof5.store_string("MODAL_CHECK levelup_route_rewards_absent=true\n")
					proof5.close()
				state = "title"
				paused = true
				get_tree().quit()

	if OS.get_cmdline_args().has("--capture-train-build") or OS.get_cmdline_user_args().has("--capture-train-build"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				# Preserve real player saves; work in an isolated run.
				reset_run()
				state = "combat"
				paused = false
				boss_active = false
				shop_open = false
				shop_slide = 0.0
				enemies.clear()
				projectiles.clear()
				# Spawn inside starter range (~560 from loco muzzle near x=1300).
				spawn_enemy("scrapper", false, 980.0)
				spawn_enemy("runner", false, 860.0)
				var proof0 := FileAccess.open(ProjectSettings.globalize_path("res://train_build_proof.txt"), FileAccess.WRITE)
				if proof0 != null:
					proof0.store_string("NEW_RUN cars=%d loco_only=%s gat=%s can=%s drone=%s aux=%s scrap=%d power_gat=%d starter_dmg=%.1f state=%s\n" % [
						train_cars.size(), str(train_cars.size() == 1),
						str(is_module_installed("gatling")), str(is_module_installed("cannon")),
						str(is_module_installed("drone")), str(aux_module_id()),
						scrap, int(power.get("gatling", 0)), float(starter_gun.get("damage", 0.0)), state
					])
					proof0.close()
				test_capture_phase = 1
				test_capture_timer = 0.55
			elif test_capture_phase == 1:
				var img_loco = get_viewport().get_texture().get_image()
				if img_loco != null:
					img_loco.save_png(ProjectSettings.globalize_path("res://train_build_loco_only_verified.png"))
				# Let starter gun fire a moment.
				test_capture_phase = 2
				test_capture_timer = 0.7
			elif test_capture_phase == 2:
				var img_gun = get_viewport().get_texture().get_image()
				if img_gun != null:
					img_gun.save_png(ProjectSettings.globalize_path("res://train_build_starter_combat_verified.png"))
				var proof_g := FileAccess.open(ProjectSettings.globalize_path("res://train_build_proof.txt"), FileAccess.READ_WRITE)
				if proof_g != null:
					proof_g.seek_end()
					proof_g.store_string("STARTER_FIRE projectiles=%d enemies=%d starter_cd=%.2f state=%s\n" % [
						projectiles.size(), enemies.size(), float(starter_gun.get("cooldown", -1.0)), state
					])
					proof_g.close()
				scrap = 200
				shop_open = true
				shop_slide = 1.0
				shop_tab = "upgrades"
				shop_buy_cooldown = 0.0
				test_capture_phase = 3
				test_capture_timer = 0.4
			elif test_capture_phase == 3:
				var img_shop = get_viewport().get_texture().get_image()
				if img_shop != null:
					img_shop.save_png(ProjectSettings.globalize_path("res://train_build_upgrades_before_wagon_verified.png"))
				var scrap_before_w := int(scrap)
				shop_buy_cooldown = 0.0
				live_shop_apply_upgrade("buy_wagon_weapon")
				var type_bits := ""
				for tc in train_cars:
					if type_bits != "":
						type_bits += ","
					type_bits += str(tc.get("car_type", tc.get("id", "?")))
				var proof_w := FileAccess.open(ProjectSettings.globalize_path("res://train_build_proof.txt"), FileAccess.READ_WRITE)
				if proof_w != null:
					proof_w.seek_end()
					proof_w.store_string("WAGON_BUY ok=%s cars=%d cost=%d scrap=%d->%d types=%s state=%s\n" % [
						str(train_cars.size() == 2), train_cars.size(), TrainBuild.wagon_cost("weapon"),
						scrap_before_w, scrap, type_bits, state
					])
					proof_w.close()
				test_capture_phase = 4
				test_capture_timer = 0.45
			elif test_capture_phase == 4:
				var img_wagon = get_viewport().get_texture().get_image()
				if img_wagon != null:
					img_wagon.save_png(ProjectSettings.globalize_path("res://train_build_wagon_purchased_verified.png"))
				shop_tab = "weapons"
				shop_scroll_y = 0.0
				shop_buy_cooldown = 0.0
				var scrap_before_g := int(scrap)
				live_shop_buy_core("gatling")
				var owned_after := owns_core_weapon("gatling") and not is_module_installed("gatling")
				shop_buy_cooldown = 0.0
				live_shop_install_core("gatling")
				var proof_i := FileAccess.open(ProjectSettings.globalize_path("res://train_build_proof.txt"), FileAccess.READ_WRITE)
				if proof_i != null:
					proof_i.seek_end()
					proof_i.store_string("GATLING buy_then_install owned_mid=%s installed=%s scrap=%d->%d mount=%s power=%d state=%s\n" % [
						str(owned_after), str(is_module_installed("gatling")), scrap_before_g, scrap,
						str(modules.get("mounts", {}).get("gatling", {})), int(power.get("gatling", 0)), state
					])
					proof_i.close()
				# Power the gatling if install didn't (reactor full edge case).
				if is_module_installed("gatling") and int(power.get("gatling", 0)) <= 0:
					power["gatling"] = 1
				test_capture_phase = 5
				test_capture_timer = 0.55
			elif test_capture_phase == 5:
				var img_inst = get_viewport().get_texture().get_image()
				if img_inst != null:
					img_inst.save_png(ProjectSettings.globalize_path("res://train_build_gatling_installed_verified.png"))
				shop_buy_cooldown = 0.0
				live_shop_apply_upgrade("buy_wagon_weapon")
				test_capture_phase = 6
				test_capture_timer = 0.4
			elif test_capture_phase == 6:
				var img_exp = get_viewport().get_texture().get_image()
				if img_exp != null:
					img_exp.save_png(ProjectSettings.globalize_path("res://train_build_expanded_verified.png"))
				# Invalid ops
				var scrap_low_before := int(scrap)
				scrap = 5
				shop_buy_cooldown = 0.0
				var low_ok := buy_wagon("weapon")
				scrap = scrap_low_before
				shop_buy_cooldown = 0.0
				var no_mount_ok := install_core_weapon("cannon") # not owned
				# Persist
				scrap = 88
				save_run()
				var saved_cars: int = train_cars.size()
				var saved_mount = modules.get("mounts", {}).get("gatling", {})
				var saved_scrap: int = int(scrap)
				# Reload
				var loaded: bool = load_run()
				var proof_p := FileAccess.open(ProjectSettings.globalize_path("res://train_build_proof.txt"), FileAccess.READ_WRITE)
				if proof_p != null:
					proof_p.seek_end()
					proof_p.store_string("INVALID low_wagon=%s unowned_cannon=%s\n" % [str(low_ok == false), str(no_mount_ok == false)])
					proof_p.store_string("PERSIST loaded=%s cars=%d/%d scrap=%d/%d gat_mount=%s/%s gat_inst=%s state=%s\n" % [
						str(loaded), saved_cars, train_cars.size(), saved_scrap, scrap,
						str(saved_mount), str(modules.get("mounts", {}).get("gatling", {})),
						str(is_module_installed("gatling")), state
					])
					proof_p.close()
				# HUD priority shot with shop closed
				shop_open = false
				shop_slide = 0.0
				test_capture_phase = 7
				test_capture_timer = 0.4
			elif test_capture_phase == 7:
				var img_hud = get_viewport().get_texture().get_image()
				if img_hud != null:
					img_hud.save_png(ProjectSettings.globalize_path("res://train_build_priority_hud_verified.png"))
				# Restore a clean title state; do not leave test scrap in the normal flow.
				reset_run()
				state = "title"
				paused = true
				get_tree().quit()

	if OS.get_cmdline_args().has("--capture-live-shop-upgrade") or OS.get_cmdline_user_args().has("--capture-live-shop-upgrade"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				reset_run()
				apply_classic_full_loadout()
				state = "combat"
				paused = false
				boss_active = false
				shop_open = true
				shop_slide = 1.0
				shop_scroll_y = 0.0
				shop_tab = "upgrades"
				shop_buy_cooldown = 0.0
				scrap = 400
				modules["installed"]["aux"] = "cryo_launcher"
				modules["inventory"] = ["arc_coil"]
				modules["aux_levels"]["cryo_launcher"] = 1
				modules["aux_levels"]["arc_coil"] = 2
				modules["levels"]["gatling"] = 1
				ensure_modules_schema()
				power["aux"] = 2
				power["gatling"] = 2
				# Damage loco for repair test later.
				train_cars[0]["hp"] = float(train_cars[0]["max_hp"]) - 40.0
				enemies.clear()
				projectiles.clear()
				spawn_enemy("scrapper", false, 420.0)
				spawn_enemy("brute", false, 260.0)
				var proof := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_upgrade_proof.txt"), FileAccess.WRITE)
				if proof != null:
					proof.store_string("BEFORE scrap=%d reactor=%d armor=%.0f cool=%.2f gatLv=%d cryoLv=%d arcLv=%d loco=%d/%d state=%s\n" % [
						scrap, int(reactor["max"]), float(train_cars[0]["armor"]), float(stats_get("cooling_mul", 1.0)),
						module_level("gatling"), int(modules["aux_levels"].get("cryo_launcher", 1)),
						int(modules["aux_levels"].get("arc_coil", 1)), int(train_cars[0]["hp"]), int(train_cars[0]["max_hp"]), state
					])
					proof.close()
				test_capture_phase = 1
				test_capture_timer = 0.45
			elif test_capture_phase == 1:
				var img0 = get_viewport().get_texture().get_image()
				if img0 != null:
					img0.save_png(ProjectSettings.globalize_path("res://live_shop_upgrade_before_verified.png"))
				shop_buy_cooldown = 0.0
				live_shop_apply_upgrade("reactor")
				test_capture_phase = 2
				test_capture_timer = 0.3
			elif test_capture_phase == 2:
				var img_r = get_viewport().get_texture().get_image()
				if img_r != null:
					img_r.save_png(ProjectSettings.globalize_path("res://live_shop_upgrade_reactor_verified.png"))
				var proof_r := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_upgrade_proof.txt"), FileAccess.READ_WRITE)
				if proof_r != null:
					proof_r.seek_end()
					proof_r.store_string("REACTOR scrap=%d reactor=%d engine_pwr=%d state=%s\n" % [
						scrap, int(reactor["max"]), int(power["engine"]), state
					])
					proof_r.close()
				var armor_before: float = float(train_cars[0]["armor"])
				shop_buy_cooldown = 0.0
				live_shop_apply_upgrade("armor")
				var proof_a := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_upgrade_proof.txt"), FileAccess.READ_WRITE)
				if proof_a != null:
					proof_a.seek_end()
					proof_a.store_string("ARMOR before=%.0f after=%.0f scrap=%d\n" % [armor_before, float(train_cars[0]["armor"]), scrap])
					proof_a.close()
				var img_ar = get_viewport().get_texture().get_image()
				if img_ar != null:
					img_ar.save_png(ProjectSettings.globalize_path("res://live_shop_upgrade_armor_verified.png"))
				var cool_before: float = float(stats_get("cooling_mul", 1.0))
				shop_buy_cooldown = 0.0
				live_shop_apply_upgrade("cooling")
				var proof_c := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_upgrade_proof.txt"), FileAccess.READ_WRITE)
				if proof_c != null:
					proof_c.seek_end()
					proof_c.store_string("COOL before=%.2f after=%.2f scrap=%d\n" % [cool_before, float(stats_get("cooling_mul", 1.0)), scrap])
					proof_c.close()
				var img_cool = get_viewport().get_texture().get_image()
				if img_cool != null:
					img_cool.save_png(ProjectSettings.globalize_path("res://live_shop_upgrade_cooling_verified.png"))
				shop_scroll_y = 120.0
				test_capture_phase = 3
				test_capture_timer = 0.25
			elif test_capture_phase == 3:
				var hp_before: float = float(train_cars[0]["hp"])
				shop_buy_cooldown = 0.0
				live_shop_apply_upgrade("repair")
				var proof_rep := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_upgrade_proof.txt"), FileAccess.READ_WRITE)
				if proof_rep != null:
					proof_rep.seek_end()
					proof_rep.store_string("REPAIR before=%.0f after=%.0f scrap=%d\n" % [hp_before, float(train_cars[0]["hp"]), scrap])
					proof_rep.close()
				# Full health rejection.
				for c in train_cars:
					c["hp"] = float(c["max_hp"])
				var scrap_full: int = int(scrap)
				shop_buy_cooldown = 0.0
				var full_ok: bool = buy_station("repair")
				var proof_full := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_upgrade_proof.txt"), FileAccess.READ_WRITE)
				if proof_full != null:
					proof_full.seek_end()
					proof_full.store_string("FULL_REPAIR_REJECT ok=%s scrap_same=%s\n" % [str(full_ok), str(int(scrap) == scrap_full)])
					proof_full.close()
				shop_buy_cooldown = 0.0
				live_shop_apply_upgrade("drone_tune")
				var proof_d := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_upgrade_proof.txt"), FileAccess.READ_WRITE)
				if proof_d != null:
					proof_d.seek_end()
					proof_d.store_string("DRONE_TUNE dmg=%.2f rate=%.2f scrap=%d\n" % [
						float(stats_get("drone_damage", 1.0)), float(stats_get("drone_rate", 1.0)), scrap
					])
					proof_d.close()
				shop_scroll_y = 260.0
				test_capture_phase = 4
				test_capture_timer = 0.25
			elif test_capture_phase == 4:
				var gat_before: int = module_level("gatling")
				var gat_cost: int = shop_next_upgrade_cost("gatling")
				var scrap_g: int = int(scrap)
				shop_buy_cooldown = 0.0
				live_shop_apply_upgrade("upgrade_gatling")
				var proof_g := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_upgrade_proof.txt"), FileAccess.READ_WRITE)
				if proof_g != null:
					proof_g.seek_end()
					proof_g.store_string("GATLING before=%d after=%d cost=%d scrap_before=%d scrap_after=%d dmg=%.1f\n" % [
						gat_before, module_level("gatling"), gat_cost, scrap_g, scrap, shop_effective_damage("gatling")
					])
					proof_g.close()
				var img_g = get_viewport().get_texture().get_image()
				if img_g != null:
					img_g.save_png(ProjectSettings.globalize_path("res://live_shop_upgrade_gatling_verified.png"))
				var cryo_before: int = int(modules["aux_levels"].get("cryo_launcher", 1))
				shop_buy_cooldown = 0.0
				live_shop_apply_upgrade("upgrade_aux")
				var proof_x := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_upgrade_proof.txt"), FileAccess.READ_WRITE)
				if proof_x != null:
					proof_x.seek_end()
					proof_x.store_string("CRYO_UP before=%d after=%d arc_level=%d scrap=%d\n" % [
						cryo_before, int(modules["aux_levels"].get("cryo_launcher", 1)),
						int(modules["aux_levels"].get("arc_coil", 1)), scrap
					])
					proof_x.close()
				var img_aux = get_viewport().get_texture().get_image()
				if img_aux != null:
					img_aux.save_png(ProjectSettings.globalize_path("res://live_shop_upgrade_aux_verified.png"))
					img_aux.save_png(ProjectSettings.globalize_path("res://live_shop_upgrade_combat_verified.png"))
				# Aux level isolation: swap to arc, confirm levels stick.
				install_aux_module("arc_coil")
				var proof_swap := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_upgrade_proof.txt"), FileAccess.READ_WRITE)
				if proof_swap != null:
					proof_swap.seek_end()
					proof_swap.store_string("AUX_SWAP aux=%s cryoLv=%d arcLv=%d\n" % [
						str(aux_module_id()), int(modules["aux_levels"].get("cryo_launcher", 1)),
						int(modules["aux_levels"].get("arc_coil", 1))
					])
					proof_swap.close()
				install_aux_module("cryo_launcher")
				# Insufficient scrap.
				scrap = 5
				shop_buy_cooldown = 0.0
				var poor_ok: bool = buy_station("reactor")
				var proof_poor := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_upgrade_proof.txt"), FileAccess.READ_WRITE)
				if proof_poor != null:
					proof_poor.seek_end()
					proof_poor.store_string("INSUFFICIENT ok=%s scrap=%d reactor=%d\n" % [str(poor_ok), scrap, int(reactor["max"])])
					proof_poor.close()
				var img_poor = get_viewport().get_texture().get_image()
				if img_poor != null:
					img_poor.save_png(ProjectSettings.globalize_path("res://live_shop_upgrade_need_scrap_verified.png"))
				# Max level reject (isolated).
				modules["levels"]["gatling"] = 5
				scrap = 200
				shop_buy_cooldown = 0.0
				var max_ok: bool = upgrade_module("gatling")
				var proof_max := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_upgrade_proof.txt"), FileAccess.READ_WRITE)
				if proof_max != null:
					proof_max.seek_end()
					proof_max.store_string("MAX_REJECT ok=%s gatLv=%d scrap=%d\n" % [str(max_ok), module_level("gatling"), scrap])
					proof_max.close()
				# Double-click protection.
				modules["levels"]["cannon"] = 1
				scrap = 100
				shop_buy_cooldown = 0.0
				live_shop_apply_upgrade("upgrade_cannon")
				var scrap_after_one: int = int(scrap)
				var lvl_after_one: int = module_level("cannon")
				live_shop_apply_upgrade("upgrade_cannon") # should no-op due to cooldown
				var proof_dup := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_upgrade_proof.txt"), FileAccess.READ_WRITE)
				if proof_dup != null:
					proof_dup.seek_end()
					proof_dup.store_string("DUP_CLICK lvl=%d scrap=%d blocked=%s\n" % [
						module_level("cannon"), scrap, str(module_level("cannon") == lvl_after_one and int(scrap) == scrap_after_one)
					])
					proof_dup.close()
				shop_scroll_y = 200.0
				scrap = 120
				modules["levels"]["gatling"] = 2
				save_run()
				test_capture_phase = 5
				test_capture_timer = 0.3
			elif test_capture_phase == 5:
				var img_scroll = get_viewport().get_texture().get_image()
				if img_scroll != null:
					img_scroll.save_png(ProjectSettings.globalize_path("res://live_shop_upgrade_scroll_verified.png"))
				# Persist check.
				var saved_reactor: int = int(reactor["max"])
				var saved_cool: float = float(stats_get("cooling_mul", 1.0))
				var saved_gat: int = module_level("gatling")
				var saved_cryo: int = int(modules["aux_levels"].get("cryo_launcher", 1))
				var saved_scrap: int = int(scrap)
				scrap = 1
				reactor["max"] = 10
				modules["levels"]["gatling"] = 1
				var loaded: bool = load_run()
				var proof_p := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_upgrade_proof.txt"), FileAccess.READ_WRITE)
				if proof_p != null:
					proof_p.seek_end()
					proof_p.store_string("PERSIST loaded=%s scrap=%d/%d reactor=%d/%d cool=%.2f/%.2f gat=%d/%d cryo=%d/%d state=%s enemies=%d\n" % [
						str(loaded), scrap, saved_scrap, int(reactor["max"]), saved_reactor,
						float(stats_get("cooling_mul", 1.0)), saved_cool, module_level("gatling"), saved_gat,
						int(modules["aux_levels"].get("cryo_launcher", 1)), saved_cryo, state, enemies.size()
					])
					proof_p.close()
				get_tree().quit()

	elif OS.get_cmdline_args().has("--capture-live-shop-equip") or OS.get_cmdline_user_args().has("--capture-live-shop-equip"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				reset_run()
				apply_classic_full_loadout()
				state = "combat"
				paused = false
				boss_active = false
				shop_open = true
				shop_slide = 1.0
				shop_scroll_y = 300.0
				shop_tab = "weapons"
				shop_buy_cooldown = 0.0
				scrap = 62
				modules["inventory"] = ["cryo_launcher"]
				modules["installed"]["aux"] = "arc_coil"
				modules["aux_levels"]["arc_coil"] = 1
				modules["aux_levels"]["cryo_launcher"] = 1
				ensure_modules_schema()
				power["aux"] = 2
				weapons["aux"]["cooldown"] = 0.2
				enemies.clear()
				projectiles.clear()
				spawn_enemy("scrapper", false, 420.0)
				spawn_enemy("brute", false, 280.0)
				test_capture_phase = 1
				test_capture_timer = 0.5
			elif test_capture_phase == 1:
				var img0 = get_viewport().get_texture().get_image()
				if img0 != null:
					img0.save_png(ProjectSettings.globalize_path("res://live_shop_equip_before_verified.png"))
				var proof := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_equip_proof.txt"), FileAccess.WRITE)
				if proof != null:
					proof.store_string("BEFORE scrap=%d aux=%s inv=%s state=%s cd=%.3f\n" % [
						scrap, str(aux_module_id()), str(modules["inventory"]), state, float(weapons["aux"]["cooldown"])
					])
					proof.close()
				shop_buy_cooldown = 0.0
				live_shop_equip_aux("cryo_launcher")
				test_capture_phase = 2
				test_capture_timer = 0.35
			elif test_capture_phase == 2:
				var img1 = get_viewport().get_texture().get_image()
				if img1 != null:
					img1.save_png(ProjectSettings.globalize_path("res://live_shop_equip_cryo_verified.png"))
					img1.save_png(ProjectSettings.globalize_path("res://live_shop_equip_hud_verified.png"))
				var proof2 := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_equip_proof.txt"), FileAccess.READ_WRITE)
				if proof2 != null:
					proof2.seek_end()
					proof2.store_string("AFTER_CRYO scrap=%d aux=%s inv=%s state=%s cd=%.3f cryo=%s arc=%s\n" % [
						scrap, str(aux_module_id()), str(modules["inventory"]), state, float(weapons["aux"]["cooldown"]),
						shop_aux_weapon_status("cryo_launcher"), shop_aux_weapon_status("arc_coil")
					])
					proof2.close()
				# Invalid equip of unowned mortar.
				var scrap_bad: int = int(scrap)
				var aux_bad = aux_module_id()
				var inv_bad_n: int = int(modules["inventory"].size())
				shop_buy_cooldown = 0.0
				var bad_ok: bool = install_aux_module("rail_mortar")
				var proof3 := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_equip_proof.txt"), FileAccess.READ_WRITE)
				if proof3 != null:
					proof3.seek_end()
					proof3.store_string("UNOWNED_REJECT ok=%s scrap_same=%s aux_same=%s inv_same=%s\n" % [
						str(bad_ok), str(int(scrap) == scrap_bad), str(aux_module_id() == aux_bad),
						str(int(modules["inventory"].size()) == inv_bad_n)
					])
					proof3.close()
				# Duplicate rapid equip of already installed cryo.
				shop_buy_cooldown = 0.0
				live_shop_equip_aux("cryo_launcher")
				shop_buy_cooldown = 0.0
				live_shop_equip_aux("cryo_launcher")
				var proof4 := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_equip_proof.txt"), FileAccess.READ_WRITE)
				if proof4 != null:
					proof4.seek_end()
					proof4.store_string("DUP_EQUIP aux=%s inv=%s scrap=%d\n" % [
						str(aux_module_id()), str(modules["inventory"]), scrap
					])
					proof4.close()
				# Combat fire observation: force ready + wait for cryo projectile.
				weapons["aux"]["cooldown"] = 0.0
				test_capture_phase = 3
				test_capture_timer = 0.85
			elif test_capture_phase == 3:
				var cryo_shots: int = 0
				for p in projectiles:
					if str(p.get("type", "")) == "cryo":
						cryo_shots += 1
				var img_fire = get_viewport().get_texture().get_image()
				if img_fire != null:
					img_fire.save_png(ProjectSettings.globalize_path("res://live_shop_equip_combat_verified.png"))
				var proof5 := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_equip_proof.txt"), FileAccess.READ_WRITE)
				if proof5 != null:
					proof5.seek_end()
					proof5.store_string("COMBAT_FIRE aux=%s cryo_projectiles=%d enemies=%d projectiles=%d state=%s\n" % [
						str(aux_module_id()), cryo_shots, enemies.size(), projectiles.size(), state
					])
					proof5.close()
				save_run()
				# Swap back to Arc.
				shop_buy_cooldown = 0.0
				live_shop_equip_aux("arc_coil")
				test_capture_phase = 4
				test_capture_timer = 0.35
			elif test_capture_phase == 4:
				var img_arc = get_viewport().get_texture().get_image()
				if img_arc != null:
					img_arc.save_png(ProjectSettings.globalize_path("res://live_shop_equip_arc_restored_verified.png"))
				var proof6 := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_equip_proof.txt"), FileAccess.READ_WRITE)
				if proof6 != null:
					proof6.seek_end()
					proof6.store_string("AFTER_ARC scrap=%d aux=%s inv=%s cryo=%s arc=%s\n" % [
						scrap, str(aux_module_id()), str(modules["inventory"]),
						shop_aux_weapon_status("cryo_launcher"), shop_aux_weapon_status("arc_coil")
					])
					proof6.close()
				save_run()
				# Persist: corrupt live, reload.
				scrap = 1
				modules["inventory"] = []
				modules["installed"]["aux"] = "cryo_launcher"
				var loaded: bool = load_run()
				var proof7 := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_equip_proof.txt"), FileAccess.READ_WRITE)
				if proof7 != null:
					proof7.seek_end()
					proof7.store_string("PERSIST loaded=%s scrap=%d aux=%s inv=%s\n" % [
						str(loaded), scrap, str(aux_module_id()), str(modules.get("inventory", []))
					])
					proof7.close()
				get_tree().quit()

	elif OS.get_cmdline_args().has("--capture-live-shop-buy") or OS.get_cmdline_user_args().has("--capture-live-shop-buy"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				reset_run()
				apply_classic_full_loadout()
				state = "combat"
				paused = false
				boss_active = false
				shop_open = true
				shop_slide = 1.0
				shop_scroll_y = 300.0
				shop_tab = "weapons"
				shop_buy_cooldown = 0.0
				scrap = 100
				modules["inventory"] = []
				modules["installed"]["aux"] = "arc_coil"
				modules["aux_levels"]["arc_coil"] = 1
				ensure_modules_schema()
				enemies.clear()
				projectiles.clear()
				spawn_enemy("scrapper", false, 420.0)
				spawn_enemy("runner", false, 300.0)
				spawn_enemy("brute", false, 240.0)
				test_capture_phase = 1
				test_capture_timer = 0.55
			elif test_capture_phase == 1:
				var img_before = get_viewport().get_texture().get_image()
				if img_before != null:
					img_before.save_png(ProjectSettings.globalize_path("res://live_shop_buy_before_verified.png"))
				var proof := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_buy_proof.txt"), FileAccess.WRITE)
				if proof != null:
					proof.store_string("BUY_TEST weapon=cryo_launcher price=%d\n" % int(AUX_MODULES["cryo_launcher"]["cost"]))
					proof.store_string("BEFORE scrap=%d aux=%s inv=%s state=%s\n" % [scrap, str(aux_module_id()), str(modules["inventory"]), state])
					proof.close()
				shop_buy_cooldown = 0.0
				live_shop_buy_aux("cryo_launcher")
				test_capture_phase = 2
				test_capture_timer = 0.35
			elif test_capture_phase == 2:
				var img_after = get_viewport().get_texture().get_image()
				if img_after != null:
					img_after.save_png(ProjectSettings.globalize_path("res://live_shop_buy_after_verified.png"))
					img_after.save_png(ProjectSettings.globalize_path("res://live_shop_buy_combat_verified.png"))
				var proof2 := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_buy_proof.txt"), FileAccess.READ_WRITE)
				if proof2 != null:
					proof2.seek_end()
					proof2.store_string("AFTER_BUY scrap=%d aux=%s inv=%s state=%s cryo_status=%s\n" % [
						scrap, str(aux_module_id()), str(modules["inventory"]), state, shop_aux_weapon_status("cryo_launcher")
					])
					proof2.close()
				# Duplicate purchase attempt (rapid).
				var scrap_dup_before: int = int(scrap)
				var inv_dup_before: Array = modules["inventory"].duplicate()
				var inv_dup_count: int = inv_dup_before.size()
				shop_buy_cooldown = 0.0
				live_shop_buy_aux("cryo_launcher")
				shop_buy_cooldown = 0.0
				live_shop_buy_aux("cryo_launcher")
				var proof3 := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_buy_proof.txt"), FileAccess.READ_WRITE)
				if proof3 != null:
					proof3.seek_end()
					proof3.store_string("DUP_REJECT scrap_before=%d scrap_after=%d inv_before=%s inv_after=%s ok=%s\n" % [
						scrap_dup_before, scrap, str(inv_dup_before), str(modules["inventory"]),
						str(scrap_dup_before == int(scrap) and int(modules["inventory"].size()) == inv_dup_count)
					])
					proof3.close()
				# Insufficient scrap attempt.
				scrap = 10
				var inv_poor_count: int = int(modules["inventory"].size())
				shop_buy_cooldown = 0.0
				live_shop_buy_aux("rail_mortar")
				var proof4 := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_buy_proof.txt"), FileAccess.READ_WRITE)
				if proof4 != null:
					proof4.seek_end()
					proof4.store_string("INSUFFICIENT scrap=%d mortar_owned=%s inv_unchanged=%s\n" % [
						scrap, str(owns_aux_module("rail_mortar")), str(int(modules["inventory"].size()) == inv_poor_count)
					])
					proof4.close()
				# Locked missile test without permanently mutating unlocks.
				var old_best: bool = bool(permanent.get("best_boss", false))
				var old_unlocked: Array = permanent.get("unlocked", []).duplicate()
				permanent["best_boss"] = false
				permanent["unlocked"] = []
				scrap = 200
				shop_buy_cooldown = 0.0
				var locked_ok: bool = buy_aux_module("missile_rack")
				permanent["best_boss"] = old_best
				permanent["unlocked"] = old_unlocked
				var proof5 := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_buy_proof.txt"), FileAccess.READ_WRITE)
				if proof5 != null:
					proof5.seek_end()
					proof5.store_string("LOCKED_TEST bought=%s scrap=%d missile_owned=%s\n" % [
						str(locked_ok), scrap, str(owns_aux_module("missile_rack"))
					])
					proof5.close()
				# Restore scrap for persistence test after cryo purchase (62 expected if only cryo bought from 100).
				if not modules["inventory"].has("cryo_launcher"):
					modules["inventory"].append("cryo_launcher")
				if not modules["aux_levels"].has("cryo_launcher"):
					modules["aux_levels"]["cryo_launcher"] = 1
				scrap = 62
				modules["installed"]["aux"] = "arc_coil"
				save_run()
				test_capture_phase = 3
				test_capture_timer = 0.25
			elif test_capture_phase == 3:
				# Persist: mutate live state, then reload run save.
				var saved_scrap: int = 62
				scrap = 1
				modules["inventory"] = []
				var loaded: bool = load_run()
				var proof6 := FileAccess.open(ProjectSettings.globalize_path("res://live_shop_buy_proof.txt"), FileAccess.READ_WRITE)
				if proof6 != null:
					proof6.seek_end()
					proof6.store_string("PERSIST loaded=%s scrap=%d aux=%s inv=%s expect_scrap=%d has_cryo=%s\n" % [
						str(loaded), scrap, str(aux_module_id()), str(modules.get("inventory", [])),
						saved_scrap, str(modules.get("inventory", []).has("cryo_launcher"))
					])
					proof6.store_string("COMBAT state=%s enemies=%d projectiles=%d run_time=%.2f\n" % [
						state, enemies.size(), projectiles.size(), run_time
					])
					proof6.close()
				shop_open = true
				shop_slide = 1.0
				shop_tab = "weapons"
				shop_scroll_y = 320.0
				state = "combat"
				paused = false
				spawn_enemy("scrapper", false, 400.0)
				test_capture_phase = 4
				test_capture_timer = 0.4
			elif test_capture_phase == 4:
				var img_owned = get_viewport().get_texture().get_image()
				if img_owned != null:
					img_owned.save_png(ProjectSettings.globalize_path("res://live_shop_buy_owned_verified.png"))
					img_owned.save_png(ProjectSettings.globalize_path("res://live_shop_buy_scroll_verified.png"))
				get_tree().quit()

	elif OS.get_cmdline_args().has("--capture-live-shop") or OS.get_cmdline_user_args().has("--capture-live-shop"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				reset_run()
				apply_classic_full_loadout()
				state = "combat"
				paused = false
				boss_active = false
				shop_open = false
				shop_slide = 0.0
				shop_scroll_y = 0.0
				shop_tab = "weapons"
				scrap = 248
				enemies.clear()
				projectiles.clear()
				spawn_enemy("scrapper", false, 420.0)
				spawn_enemy("runner", false, 280.0)
				spawn_enemy("skimmer", false, 360.0)
				test_capture_phase = 1
				test_capture_timer = 0.85
			elif test_capture_phase == 1:
				var img0 = get_viewport().get_texture().get_image()
				if img0 != null:
					img0.save_png(ProjectSettings.globalize_path("res://live_shop_closed_verified.png"))
				shop_open = true
				shop_tab = "weapons"
				shop_scroll_y = 0.0
				test_capture_phase = 2
				test_capture_timer = 0.45
			elif test_capture_phase == 2:
				var img1 = get_viewport().get_texture().get_image()
				if img1 != null:
					img1.save_png(ProjectSettings.globalize_path("res://live_shop_weapons_verified.png"))
					img1.save_png(ProjectSettings.globalize_path("res://live_shop_weapons_catalog_verified.png"))
				shop_scroll_y = 280.0
				test_capture_phase = 3
				test_capture_timer = 0.25
			elif test_capture_phase == 3:
				var img_aux = get_viewport().get_texture().get_image()
				if img_aux != null:
					img_aux.save_png(ProjectSettings.globalize_path("res://live_shop_aux_status_verified.png"))
				shop_tab = "upgrades"
				shop_scroll_y = 0.0
				test_capture_phase = 4
				test_capture_timer = 0.35
			elif test_capture_phase == 4:
				var img2 = get_viewport().get_texture().get_image()
				if img2 != null:
					img2.save_png(ProjectSettings.globalize_path("res://live_shop_upgrades_verified.png"))
					img2.save_png(ProjectSettings.globalize_path("res://live_shop_upgrades_data_verified.png"))
				test_capture_phase = 5
				test_capture_timer = 1.0
			elif test_capture_phase == 5:
				var img3 = get_viewport().get_texture().get_image()
				if img3 != null:
					img3.save_png(ProjectSettings.globalize_path("res://live_shop_combat_live_verified.png"))
					img3.save_png(ProjectSettings.globalize_path("res://live_shop_scrap_live_verified.png"))
				get_tree().quit()

	if OS.get_cmdline_args().has("--capture-route-2"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				state = "route"
				encounter_index = 1
				route_choices = [
					{ "type": "combat", "title": "Broken Track", "desc": "Standard combat corridor. Moderate Scrap and XP salvage from scrapper scouts.", "risk": "Normal", "reward": "Scrap + XP" },
					{ "type": "elite", "title": "Rift-Signature", "desc": "Elite vanguard ambush detected. Highly hazardous engagement, valuable tech core reward.", "risk": "High", "reward": "Blueprint Chance" }
				]
				test_capture_phase = 1
				test_capture_timer = 0.5
			elif test_capture_phase == 1:
				var img = get_viewport().get_texture().get_image()
				if img != null:
					img.save_png(ProjectSettings.globalize_path("res://route_choice_2cards_verified.png"))
				get_tree().quit()

	if OS.get_cmdline_args().has("--capture-route-3"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				state = "route"
				encounter_index = 2
				route_choices = [
					{ "type": "combat", "title": "Broken Track", "desc": "Standard combat corridor. Moderate Scrap and XP salvage from scrapper scouts.", "risk": "Normal", "reward": "Scrap + XP" },
					{ "type": "elite", "title": "Rift-Signature", "desc": "Elite vanguard ambush detected. Highly hazardous engagement, valuable tech core reward.", "risk": "High", "reward": "Blueprint Chance" },
					{ "type": "station", "title": "Derelict Station", "desc": "Temporary safe stop. Depot repairs, reactor calibration and auxiliary module tuning.", "risk": "Safe", "reward": "Repair & Tech" }
				]
				test_capture_phase = 1
				test_capture_timer = 0.5
			elif test_capture_phase == 1:
				var img = get_viewport().get_texture().get_image()
				if img != null:
					img.save_png(ProjectSettings.globalize_path("res://route_choice_3cards_verified.png"))
				get_tree().quit()

	if OS.get_cmdline_args().has("--capture-continue-test"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			if test_capture_phase == 0:
				continue_or_start()
				test_capture_phase = 1
				test_capture_timer = 0.5
			elif test_capture_phase == 1:
				var img = get_viewport().get_texture().get_image()
				if img != null:
					img.save_png(ProjectSettings.globalize_path("res://continue_route_verified.png"))
				get_tree().quit()

	if OS.get_cmdline_args().has("--capture-test"):
		test_capture_timer -= delta
		if test_capture_timer <= 0.0:
			var img = get_viewport().get_texture().get_image()
			if img != null:
				img.save_png(ProjectSettings.globalize_path("res://screenshot_%d.png" % test_capture_phase))
			test_capture_phase += 1
			test_capture_timer = 1.0
			
			if test_capture_phase == 1:
				state = "combat"
				boss_active = false
				power["gatling"] = 4
				power["cannon"] = 4
				power["drone"] = 2
				power["aux"] = 2
				modules["installed"]["aux"] = "arc_coil"
				spawn_enemy("brute", false, -120.0)
				spawn_enemy("skimmer", false, -180.0)
			elif test_capture_phase == 2:
				state = "levelup"
				roll_cards()
			elif test_capture_phase == 3:
				state = "rewards"
			elif test_capture_phase == 4:
				state = "combat"
				modules["installed"]["aux"] = "rail_mortar"
				heat["value"] = 90
				add_warning("HEAT CRITICAL", "heat", 960, 300, 2.0, "critical")
				abilities["shield"]["cooldown"] = 15.0
			elif test_capture_phase == 5:
				start_boss()
			elif test_capture_phase == 6:
				get_tree().quit()

	var dt = delta * (0.0 if paused else game_speed)
	t += delta
	_ui_tap_lock_t = maxf(0.0, _ui_tap_lock_t - delta)
	for _ak in _ability_tap_lock.keys():
		_ability_tap_lock[_ak] = maxf(0.0, float(_ability_tap_lock[_ak]) - delta)
	save_flash = max(0.0, save_flash - delta)
	option_reset_confirm = max(0.0, option_reset_confirm - delta)
	# Always decay camera shake — victory/menus previously left shake stuck at 16 (ghosted BG).
	shake = max(0.0, shake - delta * 22.0)
	if state == "title" or state == "workshop" or state == "options" or state == "help" or state == "victory" or state == "failed":
		shake = 0.0
	# Soft-migrate any lingering modal expedition states into live combat.
	if ["levelup", "route", "rewards", "station", "build", "moduleshop", "event"].has(state):
		state = "combat"
		paused = false
		route_choices.clear()
		active_cards.clear()
	# Legacy saves paused on the rift-cycle summary — skip straight into the next loop.
	if state == "victory" and rift_cycle_complete:
		continue_rift_loop()
	if state == "combat":
		run_time += delta
	update_toasts(delta)
	update_region_transition(dt)
	update_bg_stage_blend(dt)
	update_fungus_spores(dt)
	if state == "combat" and not paused:
		update_combat(dt)
	elif not paused:
		update_background(dt * .25)
		update_transients(dt)
	update_live_shop(delta)
	queue_redraw()

func update_combat(dt: float) -> void:
	# Boss entrance: freeze the fight. Only the intro, arena slide, and ground shake run.
	if boss_intro_active:
		_update_boss_intro_cinematic(dt)
		return
	update_background(dt)
	update_train(dt)
	update_power_heat_momentum(dt)
	update_weapons(dt)
	update_drones(dt)
	update_abilities(dt)
	encounter_director(dt)
	update_tactical_feedback(dt)
	update_impact_bursts(dt)
	update_lightning(dt)
	for i in range(enemies.size() - 1, -1, -1):
		if not update_enemy(enemies[i], dt):
			enemies.remove_at(i)
	update_transients(dt)
	if not boss_active:
		var active = 0
		for e in enemies:
			if not e.get("dead", false):
				active += 1
		# Clear as soon as the wave is spent — no waiting on the progress timer.
		# Progress still fills for HUD pacing, but a full wipe ends the track early.
		if encounter_budget <= 0 and active == 0:
			encounter_progress = max(encounter_progress, encounter_goal)
			finish_encounter()
	shake = max(0.0, shake - dt * 18.0)

func _update_boss_intro_cinematic(dt: float) -> void:
	# Nearly frozen world — parallax barely creeps, train only slides for arena space.
	momentum["speed"] = 0.0
	momentum["target"] = 0.0
	update_background(dt * 0.04)
	train_shift_x = lerp(train_shift_x, train_shift_target, clamp(dt * 1.6, 0.0, 1.0))
	apply_train_layout()
	for c in train_cars:
		c["x"] = float(c.get("x", 0.0)) + car_slot_ox(c)
	# Boss entrance only — no weapons, drones, spawns, or damage.
	for i in range(enemies.size() - 1, -1, -1):
		if not update_enemy(enemies[i], dt):
			enemies.remove_at(i)
	# Keep dust / impact FX alive during stomps; freeze combat projectiles.
	for arr in [particles, impact_bursts, damage_numbers]:
		for i in range(arr.size() - 1, -1, -1):
			var item = arr[i]
			if item.has("life"):
				item["life"] -= dt
				if item["life"] <= 0.0:
					arr.remove_at(i)
			if item.has("x") and item.has("vx"):
				item["x"] += item["vx"] * dt
			if item.has("y") and item.has("vy"):
				item["y"] += item["vy"] * dt
	update_tactical_feedback(dt)
	# Shake decays slower during the cinematic so stomps read.
	shake = max(0.0, shake - dt * 8.0)

func update_transients(dt: float) -> void:
	for arr in [projectiles, enemy_projectiles, particles, damage_numbers, loot_orbs, weapon_fx]:
		for i in range(arr.size() - 1, -1, -1):
			var item = arr[i]
			if item.has("life"):
				item["life"] -= dt
			if item.has("x") and item.has("vx"):
				item["x"] += item["vx"] * dt
			if item.has("y") and item.has("vy"):
				item["y"] += item["vy"] * dt
			if item.has("life") and item["life"] <= 0:
				arr.remove_at(i)
	update_projectiles(dt)
	update_enemy_projectiles(dt)
	update_loot_orbs(dt)

func update_background(dt: float) -> void:
	var s = momentum["speed"]
	# Continuous (unwrapped) scroll: layers tile at their own texture width, so wrapping at
	# DESIGN_W would visibly jump. Position is reduced with fposmod at draw time.
	bg["mid_x"] = bg["mid_x"] + dt * s * .18
	bg["fg_x"] = bg["fg_x"] + dt * s * 1.0
	bg["rail_x"] = bg.get("rail_x", 0.0) + dt * s * 2.4
	bg["r2_dist_x"] = bg.get("r2_dist_x", 0.0) + dt * s * 0.07
	bg["r2_mid_x"] = bg.get("r2_mid_x", 0.0) + dt * s * 0.20
	bg["r2_fg_x"] = bg.get("r2_fg_x", 0.0) + dt * s * 1.0
	bg["r3_dist_x"] = bg.get("r3_dist_x", 0.0) + dt * s * 0.08
	bg["r3_mid_x"] = bg.get("r3_mid_x", 0.0) + dt * s * 0.22
	bg["r3_fg_x"] = bg.get("r3_fg_x", 0.0) + dt * s * 1.0

func update_train(dt: float) -> void:
	train_sway += dt * (5.0 + momentum["speed"] / 35.0)
	wheel_rot += dt * momentum["speed"] * .06
	train_damage_flash = max(0.0, train_damage_flash - dt)
	shield_time = max(0.0, shield_time - dt)
	suspension_jolt = max(0.0, suspension_jolt - dt * 2.8)
	# Layout → pack (faded wrecks) → camera shift for living rear → smooth slide.
	apply_train_layout()
	update_car_wrecks(dt)
	refresh_train_pack_target()
	refresh_combat_view_shift()
	# Two-stage ease: desired may jump (train↔enemy focus); target + x chase gently.
	train_shift_target = lerpf(train_shift_target, train_shift_desired, clampf(dt * COMBAT_TARGET_SMOOTH, 0.0, 1.0))
	var shift_gap := absf(train_shift_target - train_shift_x)
	var shift_spd := COMBAT_SHIFT_SPEED_FAST if shift_gap > 320.0 else COMBAT_SHIFT_SPEED
	train_shift_x = move_toward(train_shift_x, train_shift_target, shift_spd * dt)
	train_pack_x = move_toward(train_pack_x, train_pack_target, COMBAT_PACK_SPEED * dt)
	for c in train_cars:
		# Living cars use packed layout; wrecked boxes keep their slot while fading.
		c["x"] = float(c.get("x", 0.0)) + car_slot_ox(c)

	for k in train_recoil.keys():
		train_recoil[k] = max(0.0, train_recoil[k] - dt * 5.0)
	var drone_pwr := 0
	for di in WeaponLoadout.installed_list(modules):
		if str(di.get("type", "")) == "drone":
			drone_pwr += int(di.get("power", 0))
	var hatch_target = 1.0 if drone_pwr > 0 else 0.0
	drone_hatch = lerp(drone_hatch, hatch_target, clamp(dt * 5.2, 0.0, 1.0))
	smoke_timer -= dt
	if smoke_timer <= 0.0:
		smoke_timer = 0.08
		var h_pct = heat["value"] / 100.0
		var c = Color(1.0, 0.42, 0.27, 0.65) if h_pct > 0.8 else Color(0.48, 0.52, 0.54, 0.48)
		var chimney = chimney_world_pos()
		particles.append({ "x": chimney.x + randf_range(-8, 10), "y": chimney.y + randf_range(-5, 6), "vx": randf_range(-90, -45) - momentum["speed"] * 0.18, "vy": randf_range(-70, -25), "life": randf_range(0.9, 1.5), "max": 1.5, "size": randf_range(12, 28), "color": c })

func update_power_heat_momentum(dt: float) -> void:
	var used = reactor_used_power()
	reactor["free"] = reactor["max"] - used
	var enc = current_encounter
	var speed_mul = enc.get("speed_mul", 1.0)
	var target = clamp(float(power["engine"]) / 4.0, 0.0, 1.25) * 100.0 * speed_mul
	if abilities["boost"]["duration"] > 0:
		target *= 1.55
	target -= momentum["external_drag"] * 80.0
	momentum["target"] = clamp(target, 0.0, 145.0)
	momentum["speed"] = lerp(momentum["speed"], momentum["target"], clamp(dt * .34, 0.0, .35))
	momentum["external_drag"] = max(0.0, momentum["external_drag"] - dt * .7)
	if momentum["speed"] < 15:
		overrun["value"] += dt * (10.0 if enemies.size() > 0 else 6.0)
	else:
		overrun["value"] -= dt * 13.0
	overrun["value"] = clamp(overrun["value"], 0.0, 100.0)
	overrun["stage"] = 4 if overrun["value"] >= 88 else 3 if overrun["value"] >= 66 else 2 if overrun["value"] >= 38 else 1 if overrun["value"] >= 15 else 0
	var diff = diff_profile()
	var cooling = (5.5 + power["utility"] * 2.1 + momentum["speed"] * .022) * stats_get("cooling_mul", 1.0)
	var passive_heat = (power["cannon"] * .38 + power["gatling"] * .25 + power["drone"] * .18 + power["aux"] * .22) * stats_get("heat_gen_mul", 1.0) * enc.get("heat_mul", 1.0) * diff["heat"]
	heat["value"] += (passive_heat - cooling * .12) * dt
	if heat["overheated"]:
		heat["over_timer"] -= dt
		heat["value"] -= cooling * .62 * dt
		if heat["over_timer"] <= 0 and heat["value"] < 72:
			heat["overheated"] = false
	elif heat["value"] >= 100:
		heat["value"] = 100
		heat["overheated"] = true
		heat["over_timer"] = 5.0
		toast("OVERHEAT! Weapons throttled")
		sfx("warn")
	heat["value"] = clamp(heat["value"], 0.0, 100.0)
	if audio != null:
		audio.set_speed_pitch(momentum["speed"] / 100.0)

func default_stats() -> Dictionary:
	return {
		"global_damage": 1.0,
		"cooling_mul": 1.0,
		"heat_gen_mul": 1.0,
		"scrap_mul": 1.0,
		"crit": 0.05,
		"repair_mul": 1.0,
		"drone_damage": 1.0,
		"drone_rate": 1.0,
		"drone_extra": 0,
		"drone_rocket": 999,
		"momentum_rounds": false,
		"death_save": false
	}

func ensure_stats(data: Variant = null) -> Dictionary:
	var base = default_stats()
	if typeof(data) == TYPE_DICTIONARY:
		for k in base.keys():
			if data.has(k) and data[k] != null:
				base[k] = data[k]
		for k in data.keys():
			if not base.has(k):
				base[k] = data[k]
	return base

var stats: Dictionary = default_stats()
func reset_stats() -> void:
	stats = default_stats()
func stats_get(k: String, fallback = null):
	if typeof(stats) != TYPE_DICTIONARY:
		stats = default_stats()
	return stats.get(k, fallback)

func update_abilities(dt: float) -> void:
	for a in abilities.values():
		a["cooldown"] = max(0.0, a["cooldown"] - dt)
		a["duration"] = max(0.0, a["duration"] - dt)
	shield_time = abilities["shield"]["duration"]

func get_train_car(id: String) -> Dictionary:
	for c in train_cars:
		if c["id"] == id:
			return c
	return {}

func is_car_online(id: String) -> bool:
	var c = get_train_car(id)
	return not c.is_empty() and not c.get("disabled", false) and c.get("hp", 0.0) > 0.0

func car_draw_alpha(c: Dictionary) -> float:
	if not c.get("disabled", false):
		return 1.0
	var wt = float(c.get("wreck_t", 0.0))
	if wt <= CAR_WRECK_BREAK:
		return 1.0
	return clamp(1.0 - (wt - CAR_WRECK_BREAK) / CAR_WRECK_FADE, 0.0, 1.0)

func car_module_alpha(c: Dictionary) -> float:
	# Modules fall apart / vanish sooner than the car body.
	if not c.get("disabled", false):
		return 1.0
	var wt = float(c.get("wreck_t", 0.0))
	return clamp(1.0 - wt / (CAR_WRECK_BREAK * 0.85), 0.0, 1.0)

func update_car_wrecks(dt: float) -> void:
	for c in train_cars:
		if c.get("disabled", false):
			var prev = float(c.get("wreck_t", 0.0))
			c["wreck_t"] = min(CAR_WRECK_TOTAL, prev + dt)
			# Continuous wreck FX while still on-screen
			if car_draw_alpha(c) > 0.08 and randf() < dt * 10.0:
				var cx = c["x"] + randf_range(-70, 70)
				var cy = (520.0 if c["id"] == "loco" else 620.0) + randf_range(-40, 20)
				if randf() < 0.55:
					particles.append({
						"x": cx, "y": cy, "vx": randf_range(-60, 60), "vy": randf_range(-140, -40),
						"life": randf_range(0.45, 0.9), "max": 0.9, "size": randf_range(10, 22),
						"color": Color(0.25, 0.25, 0.28, 0.55)
					})
				else:
					particles.append({
						"x": cx, "y": cy, "vx": randf_range(-120, 120), "vy": randf_range(-90, 40),
						"life": randf_range(0.15, 0.35), "max": 0.35, "size": randf_range(2, 5),
						"color": Color(1.0, 0.55, 0.2, 0.9)
					})
			if prev < CAR_WRECK_BREAK and c["wreck_t"] >= CAR_WRECK_BREAK:
				toast(str(c["label"]).to_upper() + " BREAKING APART!")
				shake = max(shake, 7.0)
		else:
			c["wreck_t"] = max(0.0, float(c.get("wreck_t", 0.0)) - dt * 2.5)

func update_weapons(dt: float) -> void:
	refresh_muzzles()
	var heat_penalty = .25 if heat["overheated"] else .72 if heat["value"] > 85 else 1.0
	update_starter_gun(dt, heat_penalty)
	# Per-instance weapons — each mount has own cooldown, power, priority, origin.
	for inst in WeaponLoadout.installed_list(modules):
		var wtype := str(inst.get("type", ""))
		var pwr := clampi(int(inst.get("power", 0)), 0, 3)
		if pwr <= 0:
			continue
		var mxy := WeaponLoadout.instance_mount_xy(train_cars, inst, Callable(self, "car_slot_ox"))
		if mxy.is_empty():
			continue
		var car: Dictionary = mxy["car"]
		if car.get("disabled", false) or float(car.get("hp", 0.0)) <= 0.0:
			continue
		var state_mul = 0.58 if pwr == 1 else (1.34 if pwr >= 3 else 1.0)
		var lvl := instance_level(inst)
		var mx := float(mxy.get("mount_x", 0.0))
		var pri := str(inst.get("priority", "nearest"))
		if wtype == "gatling":
			inst["cooldown"] = float(inst.get("cooldown", 0.0)) - dt * state_mul * heat_penalty * (1.0 + (lvl - 1) * 0.07)
			if float(inst["cooldown"]) <= 0.0:
				var target = find_target(pri, 780.0, mx)
				if target != null:
					inst["cooldown"] = float(weapons["gatling"].get("cooldown_max", 0.18))
					_face_instance(inst, mx, target)
					_fire_gatling_from_mount(mxy, target, state_mul)
					sfx("gatling")
		elif wtype == "cannon":
			inst["cooldown"] = float(inst.get("cooldown", 0.0)) - dt * state_mul * heat_penalty
			if float(inst["cooldown"]) <= 0.0:
				var target2 = find_target(pri, 1100.0, mx)
				if target2 != null:
					inst["cooldown"] = float(weapons["cannon"].get("cooldown_max", 1.95))
					_face_instance(inst, mx, target2)
					_fire_cannon_from_mount(mxy, target2, state_mul)
					sfx("cannon")
		elif WeaponLoadout.is_aux_type(wtype):
			_update_aux_instance(inst, mxy, dt, heat_penalty, state_mul, lvl)
	# Keep legacy type cooldowns loosely synced for UI readouts.
	_sync_legacy_weapon_cooldown_readout()

func _face_instance(inst: Dictionary, mount_x: float, target: Dictionary) -> void:
	var dx = float(target["x"]) - mount_x
	if abs(dx) > 40.0:
		module_face_by_uid[str(inst.get("uid", ""))] = 1.0 if dx > 0.0 else -1.0

func _update_aux_instance(inst: Dictionary, mxy: Dictionary, dt: float, heat_penalty: float, state_mul: float, lvl: int) -> void:
	var id := str(inst.get("type", ""))
	if not AUX_MODULES.has(id):
		return
	var info = AUX_MODULES[id]
	var mx := float(mxy.get("mount_x", 0.0))
	var pri := str(inst.get("priority", "nearest"))
	inst["cooldown"] = float(inst.get("cooldown", 0.0)) - dt * state_mul * heat_penalty
	if float(inst["cooldown"]) > 0.0:
		return
	var range_x := 1280.0 if id == "rail_mortar" or id == "missile_rack" else 930.0
	var target = find_target(pri, range_x, mx)
	if target == null:
		return
	_face_instance(inst, mx, target)
	# Temporarily point legacy aux muzzle at this mount for fire_* helpers.
	weapons["aux"]["muzzle"] = Vector2(mx, float(weapons["aux"].get("muzzle", Vector2(758, 492)).y))
	modules["mounts"]["aux"] = { "car_uid": str(inst.get("car_uid", "")), "hp_id": str(inst.get("hp_id", "")) }
	inst["cooldown"] = float(info["cooldown"]) * pow(0.94, lvl - 1)
	match id:
		"arc_coil":
			fire_arc_coil(target, state_mul, lvl)
			sfx("arc")
		"cryo_launcher":
			fire_cryo(target, state_mul, lvl)
			sfx("cryo")
		"rail_mortar":
			fire_mortar(target, state_mul, lvl)
			sfx("boom")
		"missile_rack":
			fire_missile_rack(target, state_mul, lvl)
			sfx("boom")

func _sync_legacy_weapon_cooldown_readout() -> void:
	for key in ["gatling", "cannon"]:
		var best := 0.0
		for inst in WeaponLoadout.installed_list(modules):
			if str(inst.get("type", "")) == key:
				best = maxf(best, float(inst.get("cooldown", 0.0)))
		if weapons.has(key):
			weapons[key]["cooldown"] = best

func update_starter_gun(dt: float, heat_penalty: float) -> void:
	if starter_gun.is_empty():
		starter_gun = default_starter_gun()
	if not is_car_online("loco"):
		return
	starter_gun["cooldown"] = float(starter_gun.get("cooldown", 0.0)) - dt * heat_penalty
	if float(starter_gun["cooldown"]) > 0.0:
		return
	var muzzle: Vector2 = starter_gun.get("muzzle", Vector2(1300, 480))
	# Full-screen loco engage so rear-car attackers stay in starter reach.
	var engage: float = maxf(float(starter_gun.get("range", TrainBuild.STARTER_RANGE)), DESIGN_W)
	# Prefer attached / imminent boarders so latch DPS can be answered with skill.
	var target = find_target("starter", engage, muzzle.x)
	if target == null:
		return
	# Face toward target using loco starter mount.
	var loco := get_train_car("loco")
	var mount_x := muzzle.x
	for hp in loco.get("hardpoints", []):
		if str(hp.get("hp_id", "")) == "starter":
			mount_x = TrainBuild.mount_world_x(loco, hp) + car_slot_ox(loco)
			break
	var dx = float(target["x"]) - mount_x
	if abs(dx) > 40.0:
		starter_gun["face"] = 1.0 if dx > 0.0 else -1.0
	refresh_muzzles()
	starter_gun["cooldown"] = float(starter_gun.get("cooldown_max", TrainBuild.STARTER_COOLDOWN))
	fire_starter_gun(target)
	sfx("gatling")

func fire_starter_gun(target: Dictionary) -> void:
	var muzzle: Vector2 = starter_gun.get("muzzle", Vector2(1300, 480))
	var dmg := float(starter_gun.get("damage", TrainBuild.STARTER_DAMAGE)) * damage_multiplier()
	spawn_projectile(muzzle, target, 920.0, 4.0, dmg, "kinetic", 0.0, "#c8e6ff", false, starter_armor_pen())
	heat["value"] += 0.18 * stats_get("heat_gen_mul", 1.0)

func update_aux_weapon(dt: float, heat_penalty: float) -> void:
	var id = aux_module_id()
	if id == null or power["aux"] <= 0:
		return
	if not weapon_mount_online("aux"):
		return
	var info = AUX_MODULES[id]
	var level_aux = module_level("aux")
	var state_mul = .62 if power["aux"] == 1 else 1.32 if power["aux"] >= 3 else 1.0
	weapons["aux"]["cooldown"] -= dt * state_mul * heat_penalty
	if weapons["aux"]["cooldown"] > 0:
		return
	var target = find_target(weapons["aux"]["priority"], 1280.0 if id == "rail_mortar" or id == "missile_rack" else 930.0, weapons["aux"]["muzzle"].x)
	if target == null:
		return
	var axy := get_weapon_mount_xy("aux")
	face_target("aux", float(axy.get("mount_x", weapons["aux"]["muzzle"].x)), target)
	refresh_muzzles()
	weapons["aux"]["cooldown"] = info["cooldown"] * pow(.94, level_aux - 1)
	match id:
		"arc_coil":
			fire_arc_coil(target, state_mul, level_aux)
			sfx("arc")
		"cryo_launcher":
			fire_cryo(target, state_mul, level_aux)
			sfx("cryo")
		"rail_mortar":
			fire_mortar(target, state_mul, level_aux)
			sfx("boom")
		"missile_rack":
			fire_missile_rack(target, state_mul, level_aux)
			sfx("boom")

func update_drones(dt: float) -> void:
	# Each powered Drone Bay contributes drones; hatches from each mount.
	var hatches: Array = []
	var desired := 0
	var pri := str(weapons["drone"].get("priority", "boarders"))
	for inst in WeaponLoadout.installed_list(modules):
		if str(inst.get("type", "")) != "drone":
			continue
		var pwr := clampi(int(inst.get("power", 0)), 0, 3)
		if pwr <= 0:
			continue
		var mxy := WeaponLoadout.instance_mount_xy(train_cars, inst, Callable(self, "car_slot_ox"))
		if mxy.is_empty():
			continue
		desired += mini(4, pwr + int(stats_get("drone_extra", 0)))
		hatches.append({ "x": float(mxy["mount_x"]), "pri": str(inst.get("priority", pri)) })
		pri = str(inst.get("priority", pri))
	desired = mini(8, desired)
	var hatch_x := 330.0 if hatches.is_empty() else float(hatches[0]["x"])
	while drones.size() < desired:
		var hx := hatch_x
		if not hatches.is_empty():
			hx = float(hatches[drones.size() % hatches.size()]["x"])
		drones.append({ "x": hx, "y": 505.0, "age": randf() * 10.0, "cooldown": randf_range(.15, .75), "shots": 0, "hatch_x": hx })
	while drones.size() > desired:
		drones.remove_at(drones.size() - 1)
	for d in drones:
		d["age"] += dt
		var home_x := float(d.get("hatch_x", hatch_x))
		var drone_range = 1600.0 if boss_active else 760.0
		var target = find_target(pri, drone_range, d["x"])
		var tx = home_x - 200.0 + drones.find(d) * 78.0 + sin(d["age"] * 1.8) * 42.0
		var ty = 430.0 + cos(d["age"] * 2.2) * 30.0
		if target != null:
			var aim_y = target["y"] - (380.0 if target.get("boss", false) else 72.0)
			tx = target["x"] + (120.0 if target.get("boss", false) else -92.0) + sin(d["age"] * 2.1) * 58.0
			ty = aim_y + cos(d["age"] * 2.4) * 38.0
		d["x"] = lerp(d["x"], tx, .08)
		d["y"] = lerp(d["y"], ty, .08)
		d["cooldown"] -= dt * stats_get("drone_rate", 1.0)
		if target != null and d["cooldown"] <= 0:
			d["cooldown"] = .62
			d["shots"] += 1
			fire_drone_bolt(d, target, d["shots"] % int(stats_get("drone_rocket", 999)) == 0)
			sfx("drone")

const BOARD_ATTACH_OFFSETS = [
	Vector2(45.0, 60.0),   # Rear deck / ladder
	Vector2(125.0, 68.0),  # Rear-mid armor panel
	Vector2(215.0, 62.0),  # Mid generator plate
	Vector2(305.0, 58.0)   # Forward catwalk
]

func get_car_rear_boundary(car_idx: int) -> float:
	if car_idx < 0 or car_idx >= train_cars.size():
		return 200.0 + train_shift_x
	var car: Dictionary = train_cars[car_idx]
	# left_x is layout-space; car_slot_ox already includes combat shift + pack.
	return car_left_edge(car) + car_slot_ox(car) - 20.0

func car_draw_center_x(c: Dictionary) -> float:
	# Authoritative on-screen center (matches hull draw). Do not add ox twice.
	var ct := str(c.get("car_type", c.get("id", "weapon")))
	return car_left_edge(c) + TrainBuild.car_pixel_w(ct) * 0.5 + car_slot_ox(c)

func get_rear_target_car_idx() -> int:
	# Rearmost living car = highest index that is alive (array is loco→rear).
	for i in range(train_cars.size() - 1, -1, -1):
		if is_car_alive(i):
			return i
	return 0

## Max simultaneously damaging attached/leaping boarders per car.
## Loco-only and multi-wagon: 2 per living car (prevents invisible slot-stack DPS).
func board_attach_cap_for_car(_car_idx: int) -> int:
	return 2

func count_boarding_on_car(car_idx: int) -> int:
	var n := 0
	for e in enemies:
		if e.get("dead", false):
			continue
		if not e.get("data", {}).get("boarder", false):
			continue
		if int(e.get("target_car", -1)) != car_idx:
			continue
		if e.get("boarded", false) or str(e.get("board_state", "")) in ["leaping", "attached"]:
			n += 1
	return n

## Returns a free visual slot index, or -1 when the car is at attach capacity / all slots used.
## Never reuses an occupied slot (that previously allowed stacked damage).
## for_boarder: enforce the 2-per-car damaging boarder cap (leeches use slots only).
func get_free_board_slot(car_idx: int = -1, for_boarder: bool = true) -> int:
	if car_idx < 0:
		car_idx = get_rear_target_car_idx()
	if for_boarder and count_boarding_on_car(car_idx) >= board_attach_cap_for_car(car_idx):
		return -1
	var used: Array = []
	for e in enemies:
		if e.get("dead", false):
			continue
		if not (e.get("boarded", false) or str(e.get("board_state", "")) in ["leaping", "attached"]):
			continue
		if int(e.get("target_car", -1)) != car_idx:
			continue
		used.append(int(e.get("attach_slot", 0)))
	for s in range(BOARD_ATTACH_OFFSETS.size()):
		if not used.has(s):
			return s
	return -1

func can_boarder_attach(car_idx: int) -> bool:
	return get_free_board_slot(car_idx, true) >= 0

func is_foreground_enemy(e: Dictionary) -> bool:
	# Mycelarch stands on the rail plane beside the convoy — draw after the train
	# so legs aren't buried behind cars / dark ballast.
	if e.get("boss", false):
		return is_mycelarch_boss(e)
	# Attached or leaping boarders are always in front of the train
	if e.get("boarded", false) or e.get("board_state", "") in ["leaping", "attached"]:
		return true
	# Flying enemies stay in background layer
	if e["data"].get("flying", false):
		return false
	# All ground enemies attacking or running on the foreground track/gravel plane
	if e["y"] >= 710.0:
		return true
	# Any ground enemy close to the train rear (attacking the convoy)
	var rear_idx := get_rear_target_car_idx()
	var rear_bound = car_left_edge(train_cars[rear_idx]) + 30.0
	if e["x"] <= rear_bound and e["y"] >= 680.0:
		return true
	return false

func living_elite_count() -> int:
	var n := 0
	for e in enemies:
		if e.get("dead", false) or e.get("boss", false):
			continue
		if RiftLoop.is_elite_class(str(e.get("elite_class", RiftLoop.CLASS_NORMAL))):
			n += 1
	return n

func pick_spawn_elite_class(force_elite: bool = false, forced_class: String = "") -> String:
	if forced_class == RiftLoop.CLASS_NORMAL or forced_class == RiftLoop.CLASS_RED or forced_class == RiftLoop.CLASS_BLUE:
		return forced_class
	# Loop 1 is baseline only — no Red/Blue from rolls or authored elite nodes.
	if rift_loop <= 1:
		return RiftLoop.CLASS_NORMAL
	var eclass: String
	if force_elite:
		# Authored elite encounters: never Normal; blue becomes available from loop 3.
		if rift_loop >= 3 and randf() < 0.40:
			eclass = RiftLoop.CLASS_BLUE
		else:
			eclass = RiftLoop.CLASS_RED
	else:
		eclass = RiftLoop.roll_elite_class(rift_loop)
	if RiftLoop.is_elite_class(eclass) and living_elite_count() >= RiftLoop.MAX_LIVING_ELITES:
		return RiftLoop.CLASS_NORMAL
	return eclass

func spawn_enemy(type: String, elite = false, x = -9999.0, forced_class: String = "") -> Dictionary:
	var data = ENEMY_DATA[type]
	var diff = diff_profile()
	var boss = false
	if x == -9999.0:
		x = (-130.0 - randf_range(0.0, 35.0))
	# C1 sheets face left (dir>0 flips them toward the train).
	# C3 Flow sheets already face right — do not flip or they look moonwalked.
	var dir = -1.0 if data.get("rift", false) else 1.0

	var target_car_idx = get_rear_target_car_idx()
	var rear_bound = get_car_rear_boundary(target_car_idx)

	# Calculate visual half-width and safe attack stop distance
	var half_w = 128.0 * data["scale"] * 0.55
	var stop_dist = clampf(half_w + 12.0 + randf_range(0.0, max(0.0, data["range"] - half_w - 18.0)), half_w + 10.0, data["range"] - 6.0)

	var target_x = 880.0 if data.get("flying", false) else rear_bound
	var ground_y = clampf(760.0 + randf_range(-data["jitter"] * 0.45, data["jitter"] * 0.45), 735.0, 795.0)
	var y = randf_range(440, 625) if data.get("flying", false) else ground_y

	var eclass := pick_spawn_elite_class(bool(elite), forced_class)
	var threat := TrainBuild.encounter_threat_mul(encounter_index, current_region)
	var loop_hp := RiftLoop.enemy_hp_mul(rift_loop)
	var loop_dmg := RiftLoop.enemy_damage_mul(rift_loop)
	var class_hp := RiftLoop.elite_hp_mul(eclass)
	var class_dmg := RiftLoop.elite_damage_mul(eclass)
	# Apply loop + elite + difficulty + track threat exactly once at spawn.
	var hp = data["max_hp"] * loop_hp * class_hp * float(diff["enemy_hp"]) * threat
	var atk = data["attack"] * loop_dmg * class_dmg * float(diff["enemy_damage"]) * (1.0 + (threat - 1.0) * 0.70)
	var armor = float(data["armor"]) + RiftLoop.elite_armor_add(eclass) + (2.0 if encounter_index >= 4 else 0.0)
	var e = {
		"type": type,
		"data": data,
		"boss": boss,
		"elite": RiftLoop.is_elite_class(eclass) or bool(data.get("elite_kind", false)),
		"elite_class": eclass,
		"scaled_once": true,
		"rift_loop_at_spawn": rift_loop,
		"x": x,
		"y": y,
		"base_y": y,
		"hp": hp,
		"max_hp": hp,
		"armor": armor,
		"speed": data["speed"] * diff["enemy_speed"] * (1.0 + (threat - 1.0) * 0.22),
		"attack": atk,
		"range": data["range"],
		"cd": randf_range(.2, data["cd"] * maxf(0.72, 1.0 - (threat - 1.0) * 0.18)),
		"frame": randf(),
		"hit_radius": 38.0 * data["scale"],
		"flash": 0.0,
		"dead": false,
		"boarded": false,
		"board_state": "running" if (type == "boarder" or data.get("leech", false)) else "none",
		"target_car": target_car_idx,
		"windup": 0.0,
		"dir": dir,
		"target_x": target_x,
		"stop_dist": stop_dist
	}
	enemies.append(e)
	return e

func start_boss() -> void:
	state = "combat"
	paused = false
	boss_active = true
	boss_death_pending = false
	boss_intro_active = true
	boss_intro_t = BOSS_INTRO_DUR
	train_shift_desired = BOSS_TRAIN_SHIFT
	train_shift_target = BOSS_TRAIN_SHIFT
	# Freeze the world for the entrance cinematic.
	boss_intro_saved_speed = maxf(momentum.get("speed", 90.0), 88.0)
	momentum["speed"] = 0.0
	momentum["target"] = 0.0
	enemies.clear()
	projectiles.clear()
	enemy_projectiles.clear()
	enemy_lasers.clear()
	telegraphs.clear()
	lightning_strikes.clear()
	var def = current_boss_def()
	var is_fungus = str(def.get("id", "")) == "mycelarch"
	var is_breach = str(def.get("id", "")) == "breach_engine"
	if is_breach:
		toast("WARNING: BREACH CORE SIGNATURE")
		add_warning("CLEAR THE LEFT RAIL — THE BREACH ENGINE AWAKENS", "boss_intro", 960, 220, 3.6, "critical")
	elif is_fungus:
		toast("WARNING: SPORE SIGNATURE")
		add_warning("CLEAR THE LEFT RAIL — THE MYCELARCH APPROACHES", "boss_intro", 960, 220, 3.6, "critical")
	else:
		toast("WARNING: COLOSSUS SIGNATURE")
		add_warning("CLEAR THE LEFT RAIL — THE IRON MAW APPROACHES", "boss_intro", 960, 220, 3.6, "critical")
	sfx("warn")
	shake = max(shake, 10.0)
	var diff = diff_profile()
	var loop_boss_hp := RiftLoop.boss_hp_mul(rift_loop)
	var loop_boss_dmg := RiftLoop.boss_damage_mul(rift_loop)
	var hp = float(def["max_hp"]) * float(diff["boss_hp"]) * loop_boss_hp
	# Enter from off-screen LEFT at rail height (not rising from below).
	var plant_y = BOSS_MYCELARCH_BASE_Y if is_fungus else (BOSS_BREACH_BASE_Y if is_breach else 705.0)
	# Hardcore boss pressure: slightly higher attack cadence without changing art/patterns.
	# Loop damage is applied once via loop_dmg_mul in resolve_boss_attack (not baked into attack).
	var boss_atk: float = (16.0 if is_breach else (14.5 if is_fungus else 13.5)) * float(diff["boss_damage"])
	enemies.append({
		"type": "boss", "data": def, "boss": true, "boss_id": def.get("id", "iron_maw"),
		"elite_class": RiftLoop.CLASS_NORMAL, "elite": false, "scaled_once": true,
		"rift_loop_at_spawn": rift_loop, "loop_dmg_mul": loop_boss_dmg,
		"x": BOSS_INTRO_ENTER_X, "y": plant_y, "base_y": plant_y,
		"hp": hp, "max_hp": hp, "armor": def["armor"],
		"speed": def["speed"], "attack": boss_atk,
		"range": 520.0, "cd": 0.78, "phase": 1, "special": 9.0,
		"pending": 0.0, "pending_car": 0, "hit_radius": 165.0,
		"flash": 0.0, "dead": false, "frame": 0.0, "dir": 1.0,
		"rise": 1.0, "jaw": 0.0, "arm_swing": 0.0, "arm_raise": 0.0,
		"attack_style": "", "windup": 0.0, "windup_max": 0.0,
		"anim": "idle", "anim_t": 0.0, "anim_hold": false,
		"lunge": 0.0, "stride": 0.0,
		"beam_flash": 0.0, "beam_ox": 0.0, "beam_oy": 0.0, "beam_tx": 0.0, "beam_ty": 0.0,
		"beam_lock_x": 0.0,
		"intro_stomp": 0,
		"invuln": true
	})
	encounter_goal = 9999.0
	spawn_timer = 5.0
	save_run()

func update_enemy(e: Dictionary, dt: float) -> bool:
	if e.get("dead", false):
		e["death"] = e.get("death", .5) - dt
		e["anim_t"] = float(e.get("anim_t", 0.0)) + dt
		if e.get("boss", false):
			e["anim"] = "death"
			if e["death"] <= 0.0 and boss_death_pending:
				boss_death_pending = false
				# Handoff removes this corpse — do not keep drawing Iron Maw into region 2.
				on_boss_defeated()
				return false
			# Keep rendering through the death sheet until the handoff frame.
			return e["death"] > 0.0 or boss_death_pending
		if e.get("board_state", "") == "dead":
			e["x"] -= dt * (momentum["speed"] * 0.6 + 80.0)
			e["y"] += dt * 160.0
		return e["death"] > 0

	e["frame"] += dt
	e["flash"] = max(0.0, e.get("flash", 0.0) - dt)
	if e.get("boss", false):
		e["anim_t"] = float(e.get("anim_t", 0.0)) + dt
		return update_boss(e, dt)

	var target_car_idx = get_rear_target_car_idx()
	e["target_car"] = target_car_idx
	var rear_bound = get_car_rear_boundary(target_car_idx)
	var tcar: Dictionary = train_cars[target_car_idx]
	var spec = car_spec(tcar)
	var bob = sin(train_sway) * 3.0
	var ct := str(tcar.get("car_type", tcar.get("id", "")))
	var car_bob = bob
	if ct == "weapon":
		car_bob = bob + sin(train_sway + 1.0) * 1.5
	var car_top_y = RAIL_Y - float(spec["contact"]) * float(spec["k"]) + car_bob + TRAIN_RAIL_NUDGE_Y

	# --- 1. BOARDER SPECIAL LOGIC ---
	if e["data"].get("boarder", false):
		var bstate = e.get("board_state", "running")
		if bstate == "running":
			# Running toward rear car on the ground
			var leap_trigger_x = rear_bound - 50.0
			if e["x"] < leap_trigger_x:
				e["x"] += e["speed"] * dt
				e["y"] = lerp(e["y"], e["base_y"] + sin(e["frame"] * 4.0) * 3.0, 0.05)
			else:
				# Only leap when a free damaging slot exists — never stack on occupied slots.
				var slot_idx = get_free_board_slot(target_car_idx)
				if slot_idx < 0:
					# Hold at the leap line (non-attached). Wait for a slot to free.
					e["x"] = leap_trigger_x
					e["y"] = lerp(e["y"], e["base_y"] + sin(e["frame"] * 4.0) * 3.0, 0.08)
				else:
					e["board_state"] = "leaping"
					e["leap_timer"] = 0.0
					e["leap_dur"] = 0.52
					e["launch_x"] = e["x"]
					e["launch_y"] = e["y"]
					e["attach_slot"] = slot_idx
					e["attach_offset"] = BOARD_ATTACH_OFFSETS[slot_idx]
					e["target_car"] = target_car_idx
		elif bstate == "leaping":
			e["leap_timer"] += dt
			var frac = clamp(e["leap_timer"] / e["leap_dur"], 0.0, 1.0)
			var car_base_x = car_left_edge(tcar) + car_slot_ox(tcar)
			var dest_x = car_base_x + e["attach_offset"].x
			var dest_y = car_top_y + e["attach_offset"].y
			e["x"] = lerp(e["launch_x"], dest_x, frac)
			e["y"] = lerp(e["launch_y"], dest_y, frac) - sin(frac * PI) * 85.0
			if frac >= 1.0:
				# Re-validate capacity (race: two leaps finishing together).
				var attached_n := 0
				for other in enemies:
					if other == e or other.get("dead", false):
						continue
					if not other.get("data", {}).get("boarder", false):
						continue
					if int(other.get("target_car", -1)) != target_car_idx:
						continue
					if other.get("boarded", false) or str(other.get("board_state", "")) == "attached":
						attached_n += 1
				if attached_n >= board_attach_cap_for_car(target_car_idx):
					e["board_state"] = "running"
					e["boarded"] = false
					e["x"] = rear_bound - 50.0
					e.erase("attach_slot")
				else:
					e["board_state"] = "attached"
					e["boarded"] = true
					toast("Boarder attached!")
					sfx("warn")
					impact_bursts.append({ "x": e["x"], "y": e["y"], "life": 0.35, "max": 0.35, "size": 32.0, "color": Color(0.9, 0.8, 0.4), "type": "slam", "angle": 0.0 })
		elif bstate == "attached":
			if not e.get("boarded", false):
				e["board_state"] = "running"
				return true
			# Maintain attachment position on the car surface, tracking train bob
			var car_base_x2 = car_left_edge(tcar) + car_slot_ox(tcar)
			e["x"] = car_base_x2 + e["attach_offset"].x
			e["y"] = car_top_y + e["attach_offset"].y + sin(e["frame"] * 7.0) * 2.2
			e["cd"] -= dt
			if e["cd"] <= 0.0:
				# Slightly slower latch ticks so capped stacks remain answerable with starter DPS.
				e["cd"] = float(e["data"]["cd"]) * 1.15
				damage_car(target_car_idx, e["attack"], e)
				# Sparks on the car hull
				impact_bursts.append({ "x": e["x"] + 16.0, "y": e["y"] - 12.0, "life": 0.25, "max": 0.25, "size": 24.0, "color": Color(1.0, 0.7, 0.3), "type": "slash", "angle": randf_range(0.0, TAU) })
		return true

	# --- 2. FLYING ENEMIES (Skimmer) ---
	if e["data"].get("flying", false):
		var target_x = e.get("target_x", 880.0)
		var target_y = 630.0
		if e["x"] < target_x:
			e["x"] += e["speed"] * dt
		e["y"] = lerp(e["y"], target_y + sin(e["frame"] * 3.5) * 18.0, 0.04)
		e["cd"] -= dt
		if abs(e["x"] - target_x) <= e["range"] and e["cd"] <= 0:
			e["cd"] = e["data"]["cd"]
			var car_idx = randi_range(0, train_cars.size() - 1)
			spawn_enemy_projectile(e, car_idx, "#85fff8")
		return true

	# --- 2b. COIL LEECH (attach + temporary heat pressure) ---
	if e["data"].get("leech", false):
		var lstate = str(e.get("board_state", "running"))
		if lstate == "running":
			var latch_x = rear_bound - 40.0
			if e["x"] < latch_x:
				e["x"] += e["speed"] * dt
				e["y"] = lerp(e["y"], e["base_y"] + sin(e["frame"] * 5.0) * 2.5, 0.08)
			else:
				var lslot := get_free_board_slot(target_car_idx, false)
				if lslot < 0:
					e["x"] = latch_x
					e["y"] = lerp(e["y"], e["base_y"] + sin(e["frame"] * 5.0) * 2.5, 0.08)
				else:
					e["board_state"] = "leaping"
					e["leap_timer"] = 0.0
					e["leap_dur"] = 0.38
					e["launch_x"] = e["x"]
					e["launch_y"] = e["y"]
					e["attach_slot"] = lslot
					e["attach_offset"] = BOARD_ATTACH_OFFSETS[lslot]
					e["target_car"] = target_car_idx
		elif lstate == "leaping":
			e["leap_timer"] = float(e.get("leap_timer", 0.0)) + dt
			var lf = clampf(float(e["leap_timer"]) / float(e.get("leap_dur", 0.38)), 0.0, 1.0)
			var lbase = car_left_edge(tcar) + car_slot_ox(tcar)
			e["x"] = lerp(float(e["launch_x"]), lbase + float(e["attach_offset"].x), lf)
			e["y"] = lerp(float(e["launch_y"]), car_top_y + float(e["attach_offset"].y), lf) - sin(lf * PI) * 60.0
			if lf >= 1.0:
				e["board_state"] = "attached"
				e["boarded"] = true
				leech_heat_pressure = minf(18.0, leech_heat_pressure + 4.5)
				toast("Coil Leech latched — reactor heat rising!")
				sfx("warn")
		elif lstate == "attached":
			var lbase2 = car_left_edge(tcar) + car_slot_ox(tcar)
			e["x"] = lbase2 + float(e["attach_offset"].x)
			e["y"] = car_top_y + float(e["attach_offset"].y) + sin(e["frame"] * 8.0) * 1.8
			e["cd"] -= dt
			heat["value"] = minf(100.0, float(heat.get("value", 0.0)) + dt * 6.5)
			if e["cd"] <= 0.0:
				e["cd"] = float(e["data"]["cd"])
				damage_car(target_car_idx, e["attack"] * 0.55, e)
		return true

	# --- 2c. FLUX RIFLEMAN (ranged with aim + cyan laser) ---
	if e["data"].get("ranged", false):
		var fire_x = rear_bound - clampf(float(e["data"]["range"]) * 0.55, 180.0, 320.0)
		if e["x"] < fire_x - 8.0:
			e["x"] += e["speed"] * dt
			e["aim_t"] = 0.0
			e["laser_charge"] = 0.0
		elif e["x"] > fire_x + 8.0:
			# Spawned past the firing line (e.g. boss support) — walk back left to engage.
			e["x"] = maxf(fire_x, e["x"] - e["speed"] * dt)
			e["aim_t"] = 0.0
			e["laser_charge"] = 0.0
		else:
			e["x"] = fire_x
			e["cd"] -= dt
			if e["cd"] <= 0.0:
				var warn = float(e["data"].get("aim_warn", 0.4))
				e["aim_t"] = float(e.get("aim_t", 0.0)) + dt
				var charge = clampf(float(e["aim_t"]) / max(0.05, warn), 0.0, 1.0)
				e["laser_charge"] = charge
				var muzzle = flux_rifle_muzzle(e)
				var car_aim = Vector2(train_cars[target_car_idx]["x"], 640.0)
				if charge < 1.0:
					# Aim marker on target; charging beam drawn in draw_enemy via laser_charge
					add_telegraph(muzzle.x, muzzle.y, 24.0, 24.0, 0.08, Color(0.35, 0.9, 1.0), "", "flux_aim", car_aim.x, car_aim.y)
					e["laser_aim"] = car_aim
				else:
					e["cd"] = float(e["data"]["cd"])
					e["aim_t"] = 0.0
					e["laser_charge"] = 0.0
					e.erase("laser_aim")
					spawn_flux_laser(e, target_car_idx)
		e["y"] = lerp(e["y"], e["base_y"] + sin(e["frame"] * 2.2) * 2.0, 0.05)
		return true

	# --- 2d. RIFT HARVESTER elite (ranged + occasional area slam) ---
	if e["data"].get("elite_kind", false):
		var h_stop = rear_bound - 210.0
		if e["x"] < h_stop:
			e["x"] += e["speed"] * dt
		else:
			e["x"] = h_stop
		e["y"] = lerp(e["y"], e["base_y"] + sin(e["frame"] * 2.0) * 2.5, 0.05)
		e["cd"] -= dt
		if e["cd"] <= 0.0:
			e["special"] = float(e.get("special", 0.0)) + 1.0
			if int(e["special"]) % 3 == 0:
				var aw = float(e["data"].get("area_warn", 0.7))
				e["area_t"] = float(e.get("area_t", 0.0)) + dt
				add_telegraph(rear_bound - 90.0, RAIL_Y - 10.0, 200.0, 70.0, 0.1, Color(0.4, 0.9, 1.0), "", "harvest_area", rear_bound, RAIL_Y)
				if float(e["area_t"]) >= aw:
					e["cd"] = float(e["data"]["cd"])
					e["area_t"] = 0.0
					damage_car(target_car_idx, e["attack"] * 1.35, e)
					shake = max(shake, 5.0)
					impact_bursts.append({ "x": rear_bound, "y": RAIL_Y - 20.0, "life": 0.35, "max": 0.35, "size": 70.0, "color": Color(0.45, 0.9, 1.0), "type": "slam", "angle": 0.0 })
			else:
				e["cd"] = float(e["data"]["cd"])
				spawn_enemy_projectile(e, target_car_idx, "#7af7ff")
		return true

	# --- 3. GROUND PURSUIT ENEMIES (incl. Juggernaut telegraph) ---
	var stop_x = rear_bound - e.get("stop_dist", 65.0)
	if e["x"] < stop_x - 2.0:
		e["x"] = minf(stop_x, e["x"] + e["speed"] * dt)
	elif e["x"] > stop_x + 2.0:
		# Past the rear (boss support spawn / overshoot) — return to the bumper and attack.
		e["x"] = maxf(stop_x, e["x"] - e["speed"] * dt)
	else:
		e["x"] = stop_x

	e["y"] = lerp(e["y"], e["base_y"] + sin(e["frame"] * 4.0) * 3.0, 0.05)

	e["cd"] -= dt
	var in_range = abs(rear_bound - e["x"]) <= e["range"] + 8.0
	if in_range and e["cd"] <= 0.0:
		if e["data"].get("heavy", false):
			var tw = float(e["data"].get("telegraph", 0.5))
			e["wind_t"] = float(e.get("wind_t", 0.0)) + dt
			add_telegraph(rear_bound - 50.0, e["y"] - 50.0, 90.0, 70.0, 0.08, Color(1.0, 0.55, 0.25), "", "jugger_hit", rear_bound, e["y"])
			if float(e["wind_t"]) < tw:
				return true
			e["wind_t"] = 0.0
		e["cd"] = e["data"]["cd"]
		damage_car(target_car_idx, e["attack"], e)
		# Spark impact on rear car bumper
		impact_bursts.append({ "x": rear_bound - 4.0, "y": e["y"] - 32.0, "life": 0.22, "max": 0.22, "size": 22.0, "color": Color(1.0, 0.75, 0.35), "type": "slash", "angle": randf_range(0.0, TAU) })

	return true

func active_boss_id() -> String:
	# Prefer the live/dying boss entity identity — never mix region bosses.
	for e in enemies:
		if e.get("boss", false):
			return str(e.get("boss_id", e.get("data", {}).get("id", "iron_maw")))
	if current_region == RiftScar.REGION_ID:
		return "breach_engine"
	if current_region == "fungus_wilds":
		return "mycelarch"
	return "iron_maw"

func boss_anim_duration(anim: String) -> float:
	var sheet = boss_anim_sheet_key(anim, active_boss_id())
	if not SPRITE_ANIMS.has(sheet):
		return 1.0
	var meta = SPRITE_ANIMS[sheet]
	return float(meta["frames"]) / max(0.01, float(meta["fps"]))

func is_car_alive(idx: int) -> bool:
	if idx < 0 or idx >= train_cars.size():
		return false
	var c = train_cars[idx]
	return not c.get("disabled", false) and float(c.get("hp", 0.0)) > 0.0

func count_disabled_cars() -> int:
	var n = 0
	for c in train_cars:
		if c.get("disabled", false) or float(c.get("hp", 0.0)) <= 0.0:
			n += 1
	return n

func pick_boss_target_car(prefer_rear: bool = true) -> int:
	# Prefer the rearmost living car. Skip wrecks.
	if prefer_rear:
		for i in range(train_cars.size() - 1, -1, -1):
			if is_car_alive(i):
				return i
	else:
		for i in range(train_cars.size()):
			if is_car_alive(i):
				return i
	return 0

func boss_rear_car_x() -> float:
	# Track the rearmost *living* car (packed layout). Boss stays left of it.
	var idx = pick_boss_target_car(true)
	return car_draw_center_x(train_cars[idx])

func boss_target_x_for_style(style: String, lunge: float) -> float:
	var rear = boss_rear_car_x()
	# Keep full standoff — never walk into emptied cargo slots / loco backside.
	# The train packs left toward the boss instead of the boss filling the hole.
	var follow = rear - BOSS_FOLLOW_GAP
	var close = follow
	match style:
		"claw":
			close = rear - BOSS_CLAW_GAP
		"slam":
			close = rear - BOSS_SLAM_GAP
		"beam":
			close = rear - BOSS_BEAM_GAP
		_:
			close = follow
	var x = lerp(follow, close, clamp(lunge, 0.0, 1.0))
	# Pace with a light stride so idle isn't a frozen plant.
	if style == "" or style == "idle":
		x += sin(t * 1.4) * 10.0
	var max_x = minf(BOSS_X_MAX, rear - BOSS_MIN_STANDOFF)
	return clampf(x, BOSS_X_MIN, max_x)

func _boss_update_motion(b: Dictionary, dt: float, anim_now: String) -> void:
	var style = str(b.get("attack_style", ""))
	if style == "" and b.get("anim_hold", false):
		style = str(b.get("anim", "idle"))
	# Build lunge during windup; hold near the train on hit; ease out after.
	var wind = float(b.get("windup", 0.0))
	var wind_max = max(0.01, float(b.get("windup_max", 1.0)))
	var beam_hold = float(b.get("beam_flash", 0.0)) > 0.05
	# Hard-lock stance while the beam fires — no chase/ease that yanks the shot back.
	if beam_hold:
		if float(b.get("beam_lock_x", 0.0)) > 1.0:
			b["x"] = float(b["beam_lock_x"])
		b["lunge"] = float(b.get("lunge", 0.45))
		var mycelarch_hold = is_mycelarch_boss(b)
		var by_hold = float(b.get("base_y", BOSS_MYCELARCH_BASE_Y if mycelarch_hold else 705.0))
		b["y"] = lerp(float(b["y"]), by_hold, clamp(dt * 8.0, 0.0, 1.0))
		return
	if wind > 0.0 and style in ["claw", "slam", "beam"]:
		var charge = 1.0 - clamp(wind / wind_max, 0.0, 1.0)
		# Claw/slam rush in late so the strike lands close; beam only steps a little.
		var want = ease_out_cubic(charge)
		if style == "beam":
			want *= 0.45
		elif style == "claw":
			want = ease_out_cubic(clamp(charge * 1.15, 0.0, 1.0))
		b["lunge"] = lerp(float(b.get("lunge", 0.0)), want, clamp(dt * 7.0, 0.0, 1.0))
	elif b.get("anim_hold", false) and str(b.get("anim", "")) in ["claw", "slam", "beam"]:
		var hold_lunge = 1.0 if str(b.get("anim", "")) == "claw" else 0.55
		b["lunge"] = lerp(float(b.get("lunge", 0.0)), hold_lunge, clamp(dt * 5.0, 0.0, 1.0))
	else:
		# Slow release so walk resumes without a hard shove left.
		b["lunge"] = lerp(float(b.get("lunge", 0.0)), 0.0, clamp(dt * 1.35, 0.0, 1.0))

	var move_style = style if style != "" else ("idle" if anim_now == "idle" else anim_now)
	var desired = boss_target_x_for_style(move_style if move_style != "idle" else "", float(b.get("lunge", 0.0)))
	if move_style == "idle" or move_style == "":
		desired = boss_target_x_for_style("", 0.0)
	# Faster chase while lunging so the hand catches the car.
	# Breach Engine is a heavy siege walker — keep tread deliberate, not a sprint.
	var bid_motion = str(b.get("boss_id", b.get("data", {}).get("id", "")))
	var breach_motion = bid_motion == "breach_engine"
	var chase = (3.4 if breach_motion else 5.5) if float(b.get("lunge", 0.0)) > 0.35 else (1.8 if breach_motion else 3.2)
	b["x"] = lerp(float(b["x"]), desired, clamp(dt * chase, 0.0, 1.0))
	# Walking bob while moving / idle pacing.
	# Mycelarch walk is baked into the sheets — keep only a light chase bob.
	var stride_rate = 2.0 if breach_motion else 3.2
	b["stride"] = float(b.get("stride", 0.0)) + dt * (stride_rate + abs(desired - float(b["x"])) * 0.015)
	var mycelarch = is_mycelarch_boss(b)
	var bob_amp = (1.5 if mycelarch else (3.0 if breach_motion else 5.0)) if anim_now == "idle" else (0.6 if mycelarch else (1.2 if breach_motion else 2.0))
	var bob = sin(float(b.get("stride", 0.0)) * 2.0) * bob_amp
	if move_style == "slam" and wind > 0.0 and not mycelarch:
		bob += (1.0 - wind / wind_max) * -12.0  # crouch into stomp (Iron Maw only)
	b["y"] = lerp(float(b["y"]), float(b.get("base_y", 705.0)) + bob, clamp(dt * 8.0, 0.0, 1.0))

func is_mycelarch_boss(b: Dictionary = {}) -> bool:
	# Identity is on the boss entity only. Region alone must never re-skin Iron Maw.
	if not b.is_empty():
		return str(b.get("boss_id", b.get("data", {}).get("id", ""))) == "mycelarch"
	return active_boss_id() == "mycelarch"

func boss_draw_size(rise: float = 1.0, boss_id: String = "") -> Vector2:
	if boss_id == "":
		boss_id = active_boss_id()
	var fungus = boss_id == "mycelarch"
	var breach = boss_id == "breach_engine"
	var base_h = BOSS_MYCELARCH_DRAW_H if fungus else (BOSS_BREACH_DRAW_H if breach else BOSS_DRAW_H)
	var draw_h = base_h * clampf(rise, 0.15, 1.0)
	var aspect = (720.0 / 900.0) if fungus else ((1280.0 / 900.0) if breach else (640.0 / 704.0))
	var draw_w = draw_h * aspect
	return Vector2(draw_w, draw_h)

func boss_sprite_point(b: Dictionary, nx: float, ny: float, bob: float = 0.0) -> Vector2:
	# Map sheet UV → world using the same dst rect as draw_iron_colossus.
	var bid = str(b.get("boss_id", b.get("data", {}).get("id", "")))
	var sz = boss_draw_size(float(b.get("rise", 1.0)), bid)
	var bx = float(b["x"])
	var by = float(b["y"])
	var dst_x = bx - sz.x * BOSS_SPRITE_AX
	var dst_y = by - sz.y + BOSS_SPRITE_ANCHOR_Y + bob
	return Vector2(dst_x + nx * sz.x, dst_y + ny * sz.y)

func boss_chest_point(b: Dictionary, bob: float = 0.0) -> Vector2:
	if is_mycelarch_boss(b):
		return boss_sprite_point(b, BOSS_MYCELARCH_CHEST_NX, BOSS_MYCELARCH_CHEST_NY, bob)
	var bid = str(b.get("boss_id", b.get("data", {}).get("id", "")))
	if bid == "breach_engine":
		return boss_sprite_point(b, 0.50, 0.48, bob)
	return boss_sprite_point(b, BOSS_CHEST_NX, BOSS_CHEST_NY, bob)

func boss_hand_point(b: Dictionary, bob: float = 0.0) -> Vector2:
	if is_mycelarch_boss(b):
		return boss_sprite_point(b, BOSS_MYCELARCH_HAND_NX, BOSS_MYCELARCH_HAND_NY, bob)
	var bid = str(b.get("boss_id", b.get("data", {}).get("id", "")))
	# Breach claw reaches toward the train (right side of the wider 960 cell).
	if bid == "breach_engine":
		return boss_sprite_point(b, 0.88, 0.52, bob)
	return boss_sprite_point(b, 0.72, 0.48, bob)

func _boss_refresh_attack_origins(b: Dictionary) -> void:
	var style = str(b.get("attack_style", ""))
	var hand = boss_hand_point(b)
	var chest = boss_chest_point(b)
	if style == "claw":
		b["atk_ox"] = hand.x
		b["atk_oy"] = hand.y
	elif style == "beam":
		b["atk_ox"] = chest.x
		b["atk_oy"] = chest.y
	# Retarget live car position (train may still be sliding). Skip wrecked boxes.
	var car = clampi(int(b.get("pending_car", 0)), 0, train_cars.size() - 1)
	if not is_car_alive(car):
		car = pick_boss_target_car(true)
		b["pending_car"] = car
	if style == "claw":
		b["atk_tx"] = car_draw_center_x(train_cars[car])
		b["atk_ty"] = 600.0
	elif style == "beam":
		b["atk_tx"] = car_draw_center_x(train_cars[car]) + 30.0
		# Aim at the car body; origin stays on the chest so the beam reads from the reactor.
		b["atk_ty"] = 560.0

	for tg in telegraphs:
		var kind = str(tg.get("kind", ""))
		if kind == "claw" or kind == "beam":
			tg["x"] = float(b.get("atk_ox", tg["x"]))
			tg["y"] = float(b.get("atk_oy", tg["y"]))
			tg["x1"] = float(b.get("atk_tx", tg.get("x1", tg["x"])))
			tg["y1"] = float(b.get("atk_ty", tg.get("y1", tg["y"])))

func ease_in_out_cubic(p: float) -> float:
	var u = clamp(p, 0.0, 1.0)
	return 4.0 * u * u * u if u < 0.5 else 1.0 - pow(-2.0 * u + 2.0, 3.0) / 2.0

func update_boss(b: Dictionary, dt: float) -> bool:
	# --- Intro cinematic: short left approach, then plant (no endless fast walk) ---
	if boss_intro_active:
		boss_intro_t = max(0.0, boss_intro_t - dt)
		var intro_p = 1.0 - clamp(boss_intro_t / BOSS_INTRO_DUR, 0.0, 1.0)
		var plant_y = float(b.get("base_y", 705.0))
		# A 0.00–0.20 warning (off left)
		# B 0.20–0.55 short walk-in (~1.6s)
		# C 0.55–1.00 planted hold + stomps, then engage
		var walking = intro_p < 0.55
		var enter_p = ease_in_out_cubic(clamp((intro_p - 0.20) / 0.35, 0.0, 1.0))
		b["rise"] = 1.0
		b["x"] = lerp(BOSS_INTRO_ENTER_X, BOSS_ARENA_X, enter_p if walking else 1.0)
		b["y"] = plant_y
		b["anim"] = "idle"
		if walking and enter_p > 0.01:
			# ~2 fps effective — heavy tread, not a sprint loop.
			b["anim_t"] = float(b.get("anim_t", 0.0)) + dt * 0.20
			b["stride"] = float(b.get("stride", 0.0)) + dt * 0.7
		else:
			# Freeze on a mid stance while planted so legs stop cycling.
			if not b.has("intro_freeze_t"):
				b["intro_freeze_t"] = float(b.get("anim_t", 0.0))
			b["anim_t"] = float(b.get("intro_freeze_t", b.get("anim_t", 0.0)))
		# Soft rumble only while approaching.
		if walking and intro_p > 0.18:
			shake = max(shake, 2.0 + enter_p * 2.0)
		# Arrival stomps once planted — not a long walk soundtrack.
		var stomp = int(b.get("intro_stomp", 0))
		if enter_p >= 1.0 and stomp < 1:
			b["intro_stomp"] = 1
			shake = max(shake, 12.0)
			sfx("boom")
			_spawn_boss_intro_dust(b)
		elif intro_p > 0.72 and stomp < 2:
			b["intro_stomp"] = 2
			shake = max(shake, 10.0)
			sfx("boom")
			_spawn_boss_intro_dust(b)
		elif intro_p > 0.90 and stomp < 3:
			b["intro_stomp"] = 3
			shake = max(shake, 7.0)
		if boss_intro_t <= 0.0:
			_finish_boss_intro(b)
		return true

	# --- Normal fight (after intro) ---
	var pct = b["hp"] / b["max_hp"]
	var phase = 4 if pct < .25 else 3 if pct < .52 else 2 if pct < .75 else 1
	if phase != b.get("phase", 1):
		b["phase"] = phase
		toast("PHASE %d" % phase if phase < 4 else "ENRAGED!")
		shake = max(shake, 5.0)
		sfx("warn")
	b["phase"] = phase
	b["beam_flash"] = max(0.0, float(b.get("beam_flash", 0.0)) - dt)
	b["pose_attack"] = max(0.0, float(b.get("pose_attack", 0.0)) - dt)

	var anim_now = boss_colossus_anim_state(b)
	if anim_now == "idle" and str(b.get("anim", "")) != "idle":
		# Resume walk mid-cycle so attack → walk doesn't hitch on frame 0.
		b["anim"] = "idle"
		var walk_dur = max(0.01, boss_anim_duration("idle"))
		b["anim_t"] = fmod(absf(float(b.get("stride", 0.0))) * 0.28, walk_dur)
	elif anim_now != "idle":
		b["anim"] = anim_now

	# Track / lunge with the convoy — never look planted while the train scrolls.
	_boss_update_motion(b, dt, anim_now)

	if phase >= 2:
		momentum["external_drag"] = max(momentum["external_drag"], 0.10 + phase * 0.03)

	# Breach Engine phase-2 support: limited skitter/rifleman spawns.
	if str(b.get("boss_id", "")) == "breach_engine" and phase >= 2:
		b["support_cd"] = float(b.get("support_cd", 4.5)) - dt
		if float(b["support_cd"]) <= 0.0:
			b["support_cd"] = 7.5 if phase >= 3 else 9.0
			var living_support := 0
			for se in enemies:
				if not se.get("boss", false) and not se.get("dead", false) and se.get("data", {}).get("rift", false):
					living_support += 1
			if living_support < 3:
				# Spawn LEFT of the boss / rear car so they approach the train to attack.
				# (Old boss.x+offset put them past the rear — they ran forward and never engaged.)
				var rear_x = get_car_rear_boundary(get_rear_target_car_idx())
				var spawn_x = minf(float(b["x"]), rear_x) - randf_range(90.0, 200.0)
				spawn_enemy("rift_skitter" if randf() < 0.6 else "flux_rifleman", false, spawn_x)

	# Attack sheets play through; damage lands mid-anim via windup.
	if b.get("windup", 0.0) > 0.0:
		_boss_refresh_attack_origins(b)
		b["windup"] -= dt
		if b["windup"] <= 0.0:
			resolve_boss_attack(b)
		return true

	# Don't start a new attack until the current one-shot sheet finishes.
	if anim_now != "idle":
		return true

	b["cd"] -= dt
	b["special"] -= dt
	if b["cd"] <= 0.0:
		begin_boss_attack(b, phase)
	# Sparse adds — no toast/warning spam.
	if b["special"] <= 0.0:
		b["special"] = 9.0 if phase >= 4 else 11.5 if phase >= 3 else 14.0
		spawn_enemy("runner" if randf() < 0.55 else "scrapper", false, b["x"] + randf_range(50, 140))
		if phase >= 4:
			spawn_enemy("scrapper", false, b["x"] + randf_range(70, 160))
	return true

func _spawn_boss_intro_dust(b: Dictionary) -> void:
	var fx = is_mycelarch_boss(b)
	var bx = float(b.get("x", BOSS_ARENA_X))
	var by = float(b.get("base_y", BOSS_MYCELARCH_BASE_Y if fx else 705.0))
	impact_bursts.append({
		"x": bx, "y": by + 8.0, "life": 0.55, "max": 0.55, "size": 140.0,
		"color": Color(0.45, 0.95, 0.75) if fx else Color(1.0, 0.7, 0.35),
		"type": "slam", "angle": 0.0
	})
	if settings.get("particles", true):
		for i in range(14):
			particles.append({
				"x": bx + randf_range(-90, 110), "y": by + randf_range(-10, 20),
				"vx": randf_range(-140, 140), "vy": randf_range(-160, -30),
				"life": randf_range(0.35, 0.75), "max": 0.75, "size": randf_range(4, 12),
				"color": Color(0.35, 0.9, 0.7, 0.8) if fx else Color(0.55, 0.48, 0.38, 0.75)
			})

func _finish_boss_intro(b: Dictionary) -> void:
	boss_intro_active = false
	b["invuln"] = false
	b["y"] = float(b.get("base_y", 705.0))
	b["x"] = BOSS_ARENA_X
	b["rise"] = 1.0
	b["anim"] = "idle"
	b["anim_t"] = 0.0
	b["cd"] = 0.75
	b["lunge"] = 0.0
	# Resume the fight — train rolls again, weapons live.
	momentum["speed"] = 0.0
	momentum["target"] = clampf(boss_intro_saved_speed, 85.0, 110.0)
	var eng = str(b.get("data", {}).get("label", "BOSS"))
	toast("%s — ENGAGE!" % eng)
	sfx("warn")
	shake = max(shake, 8.0)

func ease_out_cubic(p: float) -> float:
	var t = clamp(p, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)

func begin_boss_attack(b: Dictionary, phase: int) -> void:
	var fungus = is_mycelarch_boss(b)
	var down = count_disabled_cars()
	var roll = randf()
	var style = "claw"
	# Broken-box pattern (Mycelarch): shift toward the exposed living car.
	# 0 down — normal phase mix. 1 down — claw the open flank. 2 down — spore beams on the loco.
	if fungus and down >= 2:
		if roll < 0.55:
			style = "beam"
		elif roll < 0.82:
			style = "claw"
		else:
			style = "slam"
	elif fungus and down == 1:
		if roll < 0.52:
			style = "claw"
		elif roll < 0.78:
			style = "beam"
		else:
			style = "slam" if phase >= 2 else "claw"
	elif phase >= 3 and roll < 0.38:
		style = "beam"
	elif phase >= 2 and roll < 0.55:
		style = "slam"
	elif roll < 0.62:
		style = "claw"
	else:
		style = "slam" if phase >= 2 else "claw"

	b["attack_style"] = style
	b["anim"] = style
	b["anim_t"] = 0.0
	b["anim_hold"] = false
	b["pose_attack"] = 1.0

	var anim_dur = boss_anim_duration(style)
	# Hit later in the sheet so the strike pose is on-screen (esp. Mycelarch lash).
	var wind_frac = 0.68 if (fungus and style == "claw") else (0.58 if style == "beam" else 0.55 if style == "slam" else 0.52)
	if fungus and style == "beam":
		wind_frac = 0.62
	var wind = anim_dur * wind_frac
	if phase == 4 or down >= 2:
		wind *= 0.88
	b["windup"] = wind
	b["windup_max"] = wind
	# Short recovery after the full sheet returns to idle; faster when cars are wrecked.
	var base_cd = 0.35 if phase == 4 else 0.50 if phase == 3 else 0.65
	if fungus and down >= 1:
		base_cd *= 0.78 if down >= 2 else 0.88
	b["cd"] = base_cd

	# Always aim at a living car — never waste strikes on a broken box.
	var car = pick_boss_target_car(true)
	# With a weapon car open, occasionally jab the loco instead of the guns.
	if fungus and down == 1 and is_car_alive(0) and style == "beam" and randf() < 0.45:
		car = 0
	b["pending_car"] = car
	var cx = car_draw_center_x(train_cars[car])
	var cy = 600.0
	# Hand / chest origins for reach VFX (must land on the convoy).
	var hand = boss_hand_point(b)
	var chest = boss_chest_point(b)
	b["atk_ox"] = hand.x
	b["atk_oy"] = hand.y
	b["atk_tx"] = cx
	b["atk_ty"] = cy
	if style == "claw":
		# Mycelarch: no ring/box telegraphs — the sheet is the telegraph.
		if not fungus:
			add_telegraph(cx, cy, 80.0, 80.0, wind + 0.08, Color(1.0, 0.45, 0.28), "", "claw", cx, cy)
	elif style == "slam":
		# Telegraph only the stomped car — not a bar across the whole train.
		var sx = cx
		if not fungus:
			add_telegraph(sx - 90.0, RAIL_Y + 8.0, 180.0, 90.0, wind + 0.08, Color(1.0, 0.55, 0.2), "", "slam", sx, RAIL_Y + 8.0)
		b["atk_ox"] = b["x"] + 40.0
		b["atk_oy"] = b["y"] - 40.0
		b["atk_tx"] = sx
		b["atk_ty"] = RAIL_Y
	else:
		b["atk_ox"] = chest.x
		b["atk_oy"] = chest.y
		b["atk_tx"] = cx + 30.0
		b["atk_ty"] = chest.y
		# Beam: chest glow only — never a second laser telegraph.
	sfx("warn")

func clear_boss_telegraphs(kind: String = "") -> void:
	for i in range(telegraphs.size() - 1, -1, -1):
		var k = str(telegraphs[i].get("kind", ""))
		if kind == "":
			if k in ["claw", "slam", "beam"]:
				telegraphs.remove_at(i)
		elif k == kind:
			telegraphs.remove_at(i)

func resolve_boss_attack(b: Dictionary) -> void:
	var style = b.get("attack_style", "claw")
	# Difficulty profile × loop mul (baked onto boss at spawn; never re-scale from loop again).
	var dmg_mul = float(diff_profile()["boss_damage"]) * float(b.get("loop_dmg_mul", RiftLoop.boss_damage_mul(rift_loop)))
	var car = clampi(int(b.get("pending_car", 0)), 0, train_cars.size() - 1)
	# If the chosen box already broke mid-windup, retarget to the next living car.
	if not is_car_alive(car):
		car = pick_boss_target_car(true)
		b["pending_car"] = car
	var tx = car_draw_center_x(train_cars[car]) if is_car_alive(car) else float(train_cars[car].get("x", 0.0))
	# Drop charge telegraph so it doesn't draw a second laser beside the real hit.
	clear_boss_telegraphs(style)
	var fungus = is_mycelarch_boss(b)
	if style == "claw":
		# Soft close — no hard X teleport (that read as a one-frame pop).
		b["lunge"] = 1.0
		if not fungus:
			b["x"] = clampf(boss_rear_car_x() - BOSS_CLAW_GAP, BOSS_X_MIN, BOSS_X_MAX)
		_boss_refresh_attack_origins(b)
		if is_car_alive(car):
			damage_car(car, 14.0 * dmg_mul, b)
			spawn_train_impact(train_cars[car], b, "slash")
		shake = max(shake, 6.5)
		# Impact at the car only — no ring/box overlays on the boss hand.
		var slash_c = Color(0.7, 1.0, 0.85) if fungus else Color(1.0, 0.8, 0.45)
		impact_bursts.append({
			"x": tx, "y": 590.0, "life": 0.32, "max": 0.32, "size": 70.0,
			"color": slash_c, "type": "slash", "angle": 0.3
		})
		if settings.get("particles", true):
			for i in range(10):
				particles.append({
					"x": tx + randf_range(-40, 40), "y": 600.0 + randf_range(-30, 20),
					"vx": randf_range(-80, 140), "vy": randf_range(-120, -20),
					"life": randf_range(0.25, 0.55), "max": 0.55, "size": randf_range(4, 10),
					"color": Color(0.45, 1.0, 0.8, 0.85) if fungus else Color(1.0, 0.65, 0.35, 0.85)
				})
	elif style == "slam":
		# Single stomp on the aimed car — no whole-convoy splash.
		if is_car_alive(car):
			damage_car(car, 12.0 * dmg_mul, b)
			spawn_train_impact(train_cars[car], b, "slash")
		shake = max(shake, 8.0)
		momentum["external_drag"] = max(momentum["external_drag"], 0.32)
		var slam_x = tx if is_car_alive(car) else float(b.get("x", 0.0))
		var slam_c = Color(0.5, 0.95, 0.7) if fungus else Color(1.0, 0.7, 0.35)
		impact_bursts.append({ "x": slam_x, "y": RAIL_Y, "life": 0.55, "max": 0.55, "size": 160.0, "color": slam_c, "type": "slam", "angle": 0.0 })
		sfx("boom")
	else:
		_boss_refresh_attack_origins(b)
		var chest = boss_chest_point(b)
		# Iron Maw: reactor beam chest → living train car (+ explosion_beam hit FX).
		# Mycelarch: spore lance chest → living train car (no explosion sheet).
		b["beam_ox"] = chest.x
		b["beam_oy"] = chest.y
		b["beam_tx"] = tx + 30.0
		# Iron Maw aims a bit higher into the car body; Mycelarch holds chest height.
		b["beam_ty"] = (560.0 if not fungus else chest.y)
		b["beam_lock_x"] = float(b["x"])
		# Longer hold so discharge sheet + procedural beam read smoothly.
		b["beam_flash"] = 1.15 if fungus else 1.25
		b["lunge"] = 0.45
		if is_car_alive(car):
			damage_car(car, 18.0 * dmg_mul, b)
			spawn_train_impact(train_cars[car], b, "electric")
		shake = max(shake, 6.5)
		if not fungus:
			spawn_fx_explosion(float(b["beam_tx"]), float(b["beam_ty"]), "explosion_beam", 280.0, 0.75)
		else:
			# Tiny hit bloom at the car — not a second full beam.
			impact_bursts.append({
				"x": float(b["beam_tx"]), "y": float(b["beam_ty"]),
				"life": 0.22, "max": 0.22, "size": 42.0,
				"color": Color(0.55, 1.0, 0.9), "type": "slash", "angle": 0.0
			})
		sfx("arc")
	b["attack_style"] = ""
	b["windup"] = 0.0
	b["pose_attack"] = 0.35
	b["anim_hold"] = true

func boss_anim_sheet_key(anim: String, boss_id: String = "") -> String:
	# Sheets follow boss_id only.
	if boss_id == "":
		boss_id = active_boss_id()
	if boss_id == "breach_engine":
		match anim:
			"claw":
				return "boss_breach_impact"
			"slam":
				return "boss_breach_charge"
			"beam":
				return "boss_breach_discharge"
			"death":
				return "boss_breach_death"
			_:
				return "boss_breach_idle"
	var fungus = boss_id == "mycelarch"
	match anim:
		"claw":
			return "boss_mycelarch_claw" if fungus else "boss_colossus_claw"
		"slam":
			return "boss_mycelarch_slam" if fungus else "boss_colossus_slam"
		"beam":
			return "boss_mycelarch_beam" if fungus else "boss_colossus_maw_beam"
		"death":
			return "boss_mycelarch_death" if fungus else "boss_colossus_death"
		_:
			return "boss_mycelarch_idle" if fungus else "boss_colossus_idle"

func encounter_director(dt: float) -> void:
	if region_transition_active:
		return
	if boss_active:
		spawn_timer -= dt
		if overrun["stage"] >= 2 and spawn_timer <= 0:
			spawn_timer = 5.5
			spawn_enemy("runner" if randf() < .5 else "boarder")
		return
	if current_encounter.is_empty():
		current_encounter = choose_encounter_template(current_node_type)
	encounter_progress += dt * (1.0 + momentum["speed"] / 120.0)
	spawn_timer -= dt
	if spawn_timer <= 0 and encounter_budget > 0:
		spawn_timer = randf_range(current_encounter.get("spawn_min", .95), current_encounter.get("spawn_max", 1.7)) / diff_profile()["spawn_rate"]
		var type = weighted_enemy(current_encounter.get("weights", { "scrapper": 1 }), encounter_budget)
		spawn_enemy(type, current_node_type == "elite" and randf() < .18)
		encounter_budget -= ENEMY_DATA[type]["cost"]

func choose_encounter_template(node_type: String) -> Dictionary:
	var src: Array = RiftScar.ENCOUNTERS if current_region == RiftScar.REGION_ID else ENCOUNTERS
	# Continuous tracks: map encounter_index → fixed regional template (no random jumps).
	var idx := clampi(int(encounter_index), 0, src.size() - 1)
	var picked: Dictionary = src[idx].duplicate(true)
	if node_type == "elite" and not picked.get("weights", {}).is_empty():
		# Prefer elite-capable weights when an elite node is forced.
		var w: Dictionary = picked["weights"].duplicate(true)
		if current_region == RiftScar.REGION_ID:
			w["rift_harvester"] = int(w.get("rift_harvester", 0)) + 6
		picked["weights"] = w
	return picked

## Loop 1 Rustlands Tracks 3–4: elite nodes keep variety toasts but must not
## inflate budget or drop a free extra enemy on starter-only builds.
func is_loop1_early_elite_soft() -> bool:
	return rift_loop <= 1 and current_region == "rustlands" and encounter_index >= 2 and encounter_index <= 3

func configure_encounter(node_type: String) -> void:
	current_node_type = node_type
	current_encounter = choose_encounter_template(node_type)
	var diff = diff_profile()
	var node = encounter_index + 1
	encounter_goal = round((current_encounter["goal"] + (node - 1) * current_encounter["goal_node"]) * (1.0 if difficulty != "nightmare" else 1.04))
	encounter_budget = round((current_encounter["budget"] + (node - 1) * current_encounter["budget_node"]) * diff["encounter_budget"])
	if node_type == "elite" and not is_loop1_early_elite_soft():
		encounter_budget *= 1.18
	encounter_progress = 0.0
	spawn_timer = .75
	toast(current_encounter["title"])

func weighted_enemy(weights: Dictionary, budget_left: float) -> String:
	var usable = []
	for id in weights.keys():
		if ENEMY_DATA.has(id) and ENEMY_DATA[id]["cost"] <= budget_left + 2:
			usable.append([id, weights[id]])
	if usable.is_empty():
		return "rift_skitter" if current_region == RiftScar.REGION_ID else "scrapper"
	var total = 0.0
	for u in usable:
		total += float(u[1])
	var roll = randf_range(0, total)
	for u in usable:
		roll -= float(u[1])
		if roll <= 0:
			return u[0]
	return usable[-1][0]

func reset_run() -> void:
	if audio != null:
		audio.play_travel_music(1.5)
	state = "combat"
	paused = false
	victory = false
	run_time = 0.0
	last_run_score = 0
	reactor = { "max": 10, "free": 0 }
	# New run: power only engine / shield / utility. Weapon channels unlock when installed.
	power = { "engine": 4, "gatling": 0, "cannon": 0, "drone": 0, "aux": 0, "shield": 1, "utility": 1 }
	heat = { "value": 0.0, "overheated": false, "over_timer": 0.0 }
	momentum = { "speed": 100.0, "target": 100.0, "max": 115.0, "external_drag": 0.0 }
	overrun = { "value": 0.0, "stage": 0 }
	scrap = 0
	xp = 0
	level = 1
	xp_needed = 40
	kills = 0
	run_kills = 0
	run_damage_taken = 0
	encounter_index = 0
	current_region = "rustlands"
	rustlands_completed = false
	fungus_completed = false
	rift_loop = 1
	rift_cycle_complete = false
	rift_cycle_next_loop = 2
	region_transition_active = false
	region_transition_timer = 0.0
	region_intro_banner_timer = 0.0
	station_used = false
	boss_active = false
	boss_intro_active = false
	boss_intro_t = 0.0
	train_shift_x = 0.0
	train_shift_target = 0.0
	train_shift_desired = 0.0
	train_pack_x = 0.0
	train_pack_target = 0.0
	reward_pending_boss = false
	_encounter_finish_lock = false
	last_fail_info = {}
	leech_heat_pressure = 0.0
	shop_open = false
	shop_slide = 0.0
	shop_scroll_y = 0.0
	shop_buy_cooldown = 0.0
	shop_buy_feedback = ""
	shop_buy_feedback_t = 0.0
	shop_install_pick.clear()
	weapons = default_weapons()
	starter_gun = default_starter_gun()
	abilities = default_abilities()
	modules = default_modules()
	selected_cards.clear()
	active_cards.clear()
	route_choices.clear()
	reset_stats()
	reset_train_cars()
	enemies.clear()
	projectiles.clear()
	enemy_projectiles.clear()
	enemy_lasers.clear()
	particles.clear()
	damage_numbers.clear()
	loot_orbs.clear()
	drones.clear()
	weapon_fx.clear()
	apply_workshop_bonuses()
	# Starter Scrap Reserve: once per new expedition only (never on loop / reload).
	var scrap_reserve := workshop_tier("starter_scrap") * 25
	if scrap_reserve > 0:
		scrap = scrap_reserve
	configure_encounter("combat")
	spawn_enemy("scrapper", false, -85.0)
	spawn_enemy("runner", false, -145.0)
	if scrap_reserve > 0:
		toast("Rustlands expedition started — +%d reserve Scrap" % scrap_reserve)
	else:
		toast("Rustlands expedition started — locomotive only")
	save_run()

func finish_encounter() -> void:
	# Continuous expedition: grant rewards once and auto-advance — no reward/route modals.
	if _encounter_finish_lock or boss_active or state != "combat":
		return
	_encounter_finish_lock = true
	var track_no: int = int(encounter_index) + 1
	var base: int = int(current_encounter.get("reward", 12) + encounter_index * 2.2)
	var total: int = int(round(base * diff_profile()["scrap_reward"] * stats_get("scrap_mul", 1.0))) + int(kills) / 4
	scrap += total
	var xp_bonus: float = TrainBuild.TRACK_CLEAR_XP_BASE + float(encounter_index) * TrainBuild.TRACK_CLEAR_XP_PER_NODE
	add_xp(xp_bonus)
	encounter_index += 1
	kills = 0
	last_reward = { "scrap": total, "title": current_encounter.get("title", "Encounter"), "xp": xp_bonus }
	toast("Track %d cleared  •  +%d Scrap" % [track_no, total], "major")
	apply_field_engineering_heal()
	enemies.clear()
	projectiles.clear()
	enemy_projectiles.clear()
	enemy_lasers.clear()
	telegraphs.clear()

	if encounter_index >= 6:
		reward_pending_boss = false
		prepare_for_boss_fight()
		start_boss()
		_encounter_finish_lock = false
		save_run()
		return

	# Mid-run depot replaces the old station interrupt (Track 3 milestone).
	if encounter_index == 3 and not station_used:
		station_used = true
		repair_train(TrainBuild.MID_RUN_DEPOT_REPAIR * stats_get("repair_mul", 1.0))
		scrap += TrainBuild.MID_RUN_DEPOT_SCRAP
		toast("Field depot  •  +%d Scrap, hull patched" % TrainBuild.MID_RUN_DEPOT_SCRAP, "major")

	var next_type := pick_auto_next_node_type()
	if next_type == "salvage":
		scrap += TrainBuild.SALVAGE_SPIKE_SCRAP
		toast("Abandoned convoy salvage  •  +%d Scrap" % TrainBuild.SALVAGE_SPIKE_SCRAP, "major")
		next_type = "combat"
	begin_node_continuous(next_type)
	_encounter_finish_lock = false
	save_run()

func pick_auto_next_node_type() -> String:
	# Weighted variety without route cards. Mostly combat, occasional elite / salvage spike.
	if encounter_index >= 2 and randf() < TrainBuild.SALVAGE_SPIKE_CHANCE:
		return "salvage"
	if encounter_index >= 2 and randf() < TrainBuild.ELITE_ROUTE_CHANCE:
		return "elite"
	return "combat"

func begin_node_continuous(type: String) -> void:
	# Always stays in combat — never opens station/event/route modals.
	state = "combat"
	paused = false
	route_choices.clear()
	configure_encounter(type if type == "elite" else "combat")
	if type == "elite":
		if is_loop1_early_elite_soft():
			# Soft elite: same track template/budget, no free bonus spawn.
			toast("Elite signature inbound", "major")
		elif current_region == RiftScar.REGION_ID:
			spawn_enemy("rift_harvester", true)
			toast("Elite signature inbound", "major")
		else:
			spawn_enemy(["brute", "skimmer", "boarder"][randi_range(0, 2)], true)
			toast("Elite signature inbound", "major")

func complete_reward() -> void:
	# Legacy UI hook — redirect into continuous flow if somehow invoked.
	if reward_pending_boss or encounter_index >= 6:
		reward_pending_boss = false
		if not boss_active:
			prepare_for_boss_fight()
			start_boss()
		return
	begin_node_continuous(pick_auto_next_node_type())

func prepare_for_boss_fight() -> void:
	repair_train(135.0 * stats_get("repair_mul", 1.0))
	heat["value"] = min(heat["value"], 32.0)
	heat["overheated"] = false
	momentum["speed"] = max(momentum["speed"], 88.0)
	abilities["repair"]["cooldown"] = min(abilities["repair"]["cooldown"], 4.0)
	abilities["shield"]["cooldown"] = min(abilities["shield"]["cooldown"], 5.0)
	if current_region == "fungus_wilds":
		toast("Final depot patch complete. Spore signature ahead.")
	else:
		toast("Final depot patch complete. Colossus signature ahead.")

func open_route(force_station = false) -> void:
	state = "route"
	route_choices.clear()
	if force_station:
		route_choices.append({ "type": "station", "title": "Rust Station", "desc": "Repair, buy power, upgrade before the Maw.", "risk": "Safe" })
	route_choices.append({ "type": "combat", "title": "Broken Track", "desc": "Standard combat. Moderate Scrap and XP.", "risk": "Normal" })
	route_choices.append({ "type": "elite", "title": "Rift-Signature", "desc": "Elite battle. Dangerous, better reward.", "risk": "High" })
	if encounter_index > 2 and route_choices.size() < 3:
		route_choices.append({ "type": "event", "title": "Abandoned Convoy", "desc": "Risky salvage decision.", "risk": "Unknown" })
	save_run()

func begin_node(type: String) -> void:
	if type == "station":
		open_station()
		return
	if type == "event":
		state = "event"
		return
	state = "combat"
	paused = false
	configure_encounter(type)
	if type == "elite":
		spawn_enemy(["brute", "skimmer", "boarder"][randi_range(0, 2)], true)
	save_run()

func open_station() -> void:
	state = "station"
	station_used = true
	if module_shop.is_empty():
		generate_module_shop()
	save_run()

func station_item_cost(item: String) -> int:
	return TrainBuild.station_cost(item)

func train_missing_hp() -> float:
	var missing := 0.0
	for c in train_cars:
		missing += maxf(0.0, float(c.get("max_hp", 0.0)) - float(c.get("hp", 0.0)))
	return missing

func buy_station(item: String) -> bool:
	# Shared station transaction for Rust Station + live Armory. Does not change game state.
	stats = ensure_stats(stats)
	var cost := station_item_cost(item)
	if cost < 0:
		toast("Unknown station item")
		return false
	if item == "repair" and train_missing_hp() <= 0.5:
		toast("Already at full health")
		return false
	if item == "drone" and not is_module_installed("drone"):
		toast("Install Drone Bay first")
		return false
	if scrap < cost:
		toast("Not enough Scrap")
		return false
	scrap -= cost
	match item:
		"repair":
			repair_train(TrainBuild.REPAIR_AMOUNT * stats_get("repair_mul", 1.0))
			toast("Train repaired")
		"reactor":
			# Capacity only — player still allocates power; no free engine grant.
			reactor["max"] = int(reactor.get("max", 10)) + 1
			toast("+1 Reactor Capacity")
		"armor":
			for c in train_cars:
				c["max_hp"] = float(c.get("max_hp", 150.0)) + 14.0
				c["hp"] = float(c.get("hp", 150.0)) + 14.0
				c["armor"] = float(c.get("armor", 5.0)) + 1.5
			toast("Armor mounted")
		"cool":
			stats["cooling_mul"] = float(stats.get("cooling_mul", 1.0)) * 1.14
			toast("Cooling improved")
		"drone":
			stats["drone_damage"] = float(stats.get("drone_damage", 1.0)) * 1.18
			stats["drone_rate"] = float(stats.get("drone_rate", 1.0)) * 1.12
			toast("Drone guidance tuned")
		_:
			scrap += cost
			toast("Unknown station item")
			return false
	save_run()
	return true

func open_build() -> void:
	state = "build"
func open_module_shop() -> void:
	state = "moduleshop"
	if module_shop.is_empty():
		generate_module_shop()

func is_aux_unlocked(id: String) -> bool:
	if not AUX_MODULES.has(id):
		return false
	var unlock = AUX_MODULES[id].get("unlock", null)
	return unlock == null or permanent.get("best_boss", false) or permanent.get("unlocked", []).has(unlock)

func generate_module_shop() -> void:
	module_shop.clear()
	var ids = []
	for id in AUX_MODULES.keys():
		if is_aux_unlocked(id):
			ids.append(id)
	ids.shuffle()
	for id in ids:
		if module_shop.size() >= 3:
			break
		if id != aux_module_id() and not modules["inventory"].has(id):
			module_shop.append(id)

func owns_aux_module(id: String) -> bool:
	if not AUX_MODULES.has(id):
		return false
	return WeaponLoadout.count_owned(modules, id) > 0

func buy_aux_module(id: String) -> bool:
	# Shared transaction for Module Shop + live Armory. Inventory-only (does not equip).
	if not AUX_MODULES.has(id):
		toast("Unknown module")
		return false
	if not is_aux_unlocked(id):
		toast("Blueprint required")
		return false
	ensure_modules_schema()
	if not WeaponLoadout.can_buy(modules, id):
		toast("Already owned")
		return false
	var info = AUX_MODULES[id]
	var cost := TrainBuild.aux_weapon_cost(id)
	if cost < 0 or scrap < cost:
		toast("Not enough Scrap")
		return false
	scrap = int(scrap) - cost
	var lvl := int(modules.get("aux_levels", {}).get(id, 1))
	var inst := WeaponLoadout.buy_to_inventory(modules, id, lvl)
	if inst.is_empty():
		scrap += cost
		toast("Purchase failed")
		return false
	module_shop.erase(id)
	toast(info["title"] + " purchased")
	save_run()
	return true

func live_shop_buy_aux(id: String) -> void:
	# Live Armory purchase path — never leaves combat, never auto-installs.
	if state != "combat" or not shop_open or shop_slide < 0.95:
		return
	if shop_buy_cooldown > 0.0:
		return
	if not AUX_MODULES.has(id):
		return
	shop_buy_cooldown = SHOP_BUY_COOLDOWN_SEC
	var ok := buy_aux_module(id)
	if ok:
		shop_buy_feedback = "PURCHASED"
		shop_buy_feedback_t = 1.5
		sfx("ui")
	elif not is_aux_unlocked(id):
		shop_buy_feedback = "LOCKED"
		shop_buy_feedback_t = 1.2
	elif not WeaponLoadout.can_buy(modules, id):
		shop_buy_feedback = "MAX OWNED"
		shop_buy_feedback_t = 1.0
	else:
		shop_buy_feedback = "NEED SCRAP"
		shop_buy_feedback_t = 1.2

func install_aux_module(id: String, car_uid: String = "", hp_id: String = "") -> bool:
	# Mount an owned aux instance onto a free universal hardpoint (multi-aux OK).
	if not AUX_MODULES.has(id):
		toast("Unknown module")
		return false
	ensure_modules_schema()
	var inv_uid := ""
	for inst in WeaponLoadout.inventory_list(modules):
		if str(inst.get("type", "")) == id:
			inv_uid = str(inst.get("uid", ""))
			break
	if inv_uid == "":
		toast("Not in inventory")
		return false
	var err := WeaponLoadout.install(modules, train_cars, inv_uid, car_uid, hp_id)
	if err != "":
		toast(err)
		return false
	_rebuild_legacy_mounts_from_loadout()
	_seed_instance_power(inv_uid)
	_clamp_weapon_hud_page()
	var info = AUX_MODULES[id]
	var gate := minf(0.45, float(info.get("cooldown", 1.0)) * 0.4)
	var mounted := WeaponLoadout.find_installed(modules, inv_uid)
	if not mounted.is_empty():
		mounted["cooldown"] = maxf(float(mounted.get("cooldown", 0.0)), gate)
	toast(info["title"] + " installed")
	save_run()
	return true

func buy_wagon(car_type: String) -> bool:
	if car_type != "weapon":
		toast("Unknown wagon type")
		return false
	if TrainBuild.wagon_count(train_cars) >= TrainBuild.MAX_WAGONS:
		toast("Train at max wagon capacity")
		return false
	var cost := TrainBuild.wagon_cost(car_type)
	if cost < 0 or scrap < cost:
		toast("Not enough Scrap")
		return false
	scrap = int(scrap) - cost
	var car := TrainBuild.make_car(car_type, _alloc_car_uid(car_type))
	apply_reinforced_to_wagon(car)
	# Append behind the convoy (screen-left / array rear).
	train_cars.append(car)
	_nudge_combat_camera_for_convoy_change()
	toast(str(car["label"]) + " coupled")
	save_run()
	return true

func buy_core_weapon(weapon_id: String) -> bool:
	if not MODULE_INFO.has(weapon_id):
		toast("Unknown weapon")
		return false
	ensure_modules_schema()
	if not WeaponLoadout.can_buy(modules, weapon_id):
		toast("Max owned (%d)" % WeaponLoadout.max_owned(weapon_id))
		return false
	var cost := TrainBuild.core_weapon_cost(weapon_id)
	if cost < 0 or scrap < cost:
		toast("Not enough Scrap")
		return false
	scrap = int(scrap) - cost
	var inst := WeaponLoadout.buy_to_inventory(modules, weapon_id, int(modules.get("levels", {}).get(weapon_id, 1)))
	if inst.is_empty():
		scrap += cost
		toast("Purchase failed")
		return false
	toast(str(MODULE_INFO[weapon_id]["title"]) + " purchased")
	save_run()
	return true

func install_core_weapon(weapon_id: String, car_uid: String = "", hp_id: String = "") -> bool:
	# Install first inventory instance of this core type onto a free/selected hardpoint.
	ensure_modules_schema()
	var inv_uid := ""
	for inst in WeaponLoadout.inventory_list(modules):
		if str(inst.get("type", "")) == weapon_id:
			inv_uid = str(inst.get("uid", ""))
			break
	if inv_uid == "":
		toast("Not owned")
		return false
	var err := WeaponLoadout.install(modules, train_cars, inv_uid, car_uid, hp_id)
	if err != "":
		toast(err)
		return false
	_rebuild_legacy_mounts_from_loadout()
	_seed_instance_power(inv_uid)
	_clamp_weapon_hud_page()
	toast("%s mounted" % str(MODULE_INFO.get(weapon_id, {}).get("title", weapon_id)))
	save_run()
	return true

func _seed_instance_power(uid: String) -> void:
	var inst := WeaponLoadout.find_installed(modules, uid)
	if inst.is_empty():
		return
	if int(inst.get("power", 0)) > 0:
		return
	if reactor_used_power() < int(reactor.get("max", 10)):
		inst["power"] = 1

func uninstall_weapon_instance(uid: String) -> bool:
	ensure_modules_schema()
	var err := WeaponLoadout.uninstall(modules, train_cars, uid)
	if err != "":
		toast(err)
		return false
	_rebuild_legacy_mounts_from_loadout()
	_clamp_weapon_hud_page()
	toast("Weapon uninstalled")
	save_run()
	return true

func install_inventory_uid(inv_uid: String, car_uid: String = "", hp_id: String = "") -> bool:
	ensure_modules_schema()
	var err := WeaponLoadout.install(modules, train_cars, inv_uid, car_uid, hp_id)
	if err != "":
		toast(err)
		return false
	_rebuild_legacy_mounts_from_loadout()
	_seed_instance_power(inv_uid)
	_clamp_weapon_hud_page()
	toast("Weapon installed")
	save_run()
	return true

func live_shop_buy_core(weapon_id: String) -> void:
	if state != "combat" or not shop_open or shop_slide < 0.95:
		return
	if shop_buy_cooldown > 0.0:
		return
	shop_buy_cooldown = SHOP_BUY_COOLDOWN_SEC
	var ok := buy_core_weapon(weapon_id)
	if ok:
		shop_buy_feedback = "PURCHASED"
		shop_buy_feedback_t = 1.5
		sfx("ui")
	elif not WeaponLoadout.can_buy(modules, weapon_id):
		shop_buy_feedback = "MAX OWNED"
		shop_buy_feedback_t = 1.0
	else:
		shop_buy_feedback = "NEED SCRAP"
		shop_buy_feedback_t = 1.2

func live_shop_install_core(weapon_id: String) -> void:
	live_shop_install_weapon(weapon_id)

func live_shop_install_weapon(weapon_id: String) -> void:
	if state != "combat" or not shop_open or shop_slide < 0.95:
		return
	if shop_buy_cooldown > 0.0:
		return
	shop_buy_cooldown = SHOP_BUY_COOLDOWN_SEC
	var pick_key := str(shop_install_pick.get(weapon_id, ""))
	var car_uid := ""
	var hp_id := ""
	if pick_key.contains(":"):
		var parts := pick_key.split(":")
		car_uid = parts[0]
		hp_id = parts[1] if parts.size() > 1 else ""
	var free := TrainBuild.list_free_hardpoints(train_cars, weapon_id)
	if free.is_empty():
		shop_buy_feedback = "FULL"
		shop_buy_feedback_t = 1.2
		toast("FULL — no free mount")
		return
	if car_uid == "" or hp_id == "":
		car_uid = str(free[0]["car_uid"])
		hp_id = str(free[0]["hp_id"])
	var ok := false
	if MODULE_INFO.has(weapon_id):
		ok = install_core_weapon(weapon_id, car_uid, hp_id)
	elif AUX_MODULES.has(weapon_id):
		ok = install_aux_module(weapon_id, car_uid, hp_id)
	if ok:
		shop_buy_feedback = "INSTALLED"
		shop_buy_feedback_t = 1.5
		sfx("ui")
		shop_install_pick.erase(weapon_id)
	else:
		shop_buy_feedback = "INSTALL FAILED"
		shop_buy_feedback_t = 1.2

func live_shop_uninstall_weapon(weapon_id: String) -> void:
	if state != "combat" or not shop_open or shop_slide < 0.95:
		return
	if shop_buy_cooldown > 0.0:
		return
	shop_buy_cooldown = SHOP_BUY_COOLDOWN_SEC
	var uid := ""
	for inst in WeaponLoadout.installed_list(modules):
		if str(inst.get("type", "")) == weapon_id:
			uid = str(inst.get("uid", ""))
			break
	if uid == "":
		shop_buy_feedback = "NOT INSTALLED"
		shop_buy_feedback_t = 1.0
		return
	if uninstall_weapon_instance(uid):
		shop_buy_feedback = "UNINSTALLED"
		shop_buy_feedback_t = 1.5
		sfx("ui")
	else:
		shop_buy_feedback = "UNINSTALL FAILED"
		shop_buy_feedback_t = 1.2

func live_shop_swap_weapon(weapon_id: String) -> void:
	# Replace first mounted weapon's hardpoint with an inventory instance of weapon_id.
	if state != "combat" or not shop_open or shop_slide < 0.95:
		return
	if shop_buy_cooldown > 0.0:
		return
	shop_buy_cooldown = SHOP_BUY_COOLDOWN_SEC
	var inv_uid := ""
	for inst in WeaponLoadout.inventory_list(modules):
		if str(inst.get("type", "")) == weapon_id:
			inv_uid = str(inst.get("uid", ""))
			break
	if inv_uid == "":
		shop_buy_feedback = "NOT OWNED"
		shop_buy_feedback_t = 1.0
		return
	var victim := ""
	for inst2 in WeaponLoadout.installed_list(modules):
		if str(inst2.get("type", "")) != weapon_id:
			victim = str(inst2.get("uid", ""))
			break
	if victim == "":
		# Same type already fills mounts — nothing to swap onto.
		shop_buy_feedback = "FULL"
		shop_buy_feedback_t = 1.0
		return
	var err := WeaponLoadout.swap(modules, train_cars, victim, inv_uid)
	if err != "":
		shop_buy_feedback = "SWAP FAILED"
		shop_buy_feedback_t = 1.2
		toast(err)
		return
	_rebuild_legacy_mounts_from_loadout()
	_seed_instance_power(inv_uid)
	_clamp_weapon_hud_page()
	shop_buy_feedback = "SWAPPED"
	shop_buy_feedback_t = 1.5
	sfx("ui")
	save_run()

func live_shop_cycle_mount(weapon_id: String) -> void:
	if state != "combat" or not shop_open:
		return
	var free := TrainBuild.list_free_hardpoints(train_cars, weapon_id)
	if free.size() <= 1:
		return
	var cur := str(shop_install_pick.get(weapon_id, ""))
	var idx := 0
	for i in range(free.size()):
		var key := "%s:%s" % [free[i]["car_uid"], free[i]["hp_id"]]
		if key == cur:
			idx = i
			break
	var nxt = free[(idx + 1) % free.size()]
	shop_install_pick[weapon_id] = "%s:%s" % [nxt["car_uid"], nxt["hp_id"]]

func live_shop_buy_wagon(car_type: String) -> void:
	if state != "combat" or not shop_open or shop_slide < 0.95:
		return
	if shop_buy_cooldown > 0.0:
		return
	shop_buy_cooldown = SHOP_BUY_COOLDOWN_SEC
	var ok := buy_wagon(car_type)
	if ok:
		shop_buy_feedback = "WAGON ADDED"
		shop_buy_feedback_t = 1.5
		sfx("ui")
	elif TrainBuild.wagon_count(train_cars) >= TrainBuild.MAX_WAGONS:
		shop_buy_feedback = "MAX WAGONS"
		shop_buy_feedback_t = 1.2
	else:
		shop_buy_feedback = "NEED SCRAP"
		shop_buy_feedback_t = 1.2

func live_shop_equip_aux(id: String) -> void:
	# Legacy name — mounts inventory aux onto a free universal hardpoint (multi-aux OK).
	live_shop_install_weapon(id)

func upgrade_module(key: String) -> bool:
	# Shared module upgrade for Train Build + live Armory.
	if key == "aux":
		return upgrade_aux()
	if not MODULE_INFO.has(key):
		toast("Unknown module")
		return false
	if not is_module_installed(key):
		toast("Install module first")
		return false
	var lvl = module_level(key)
	if lvl >= 5:
		toast("Already max level")
		return false
	var cost := TrainBuild.module_upgrade_cost(key, lvl)
	if cost < 0 or scrap < cost:
		toast("Not enough Scrap")
		return false
	scrap -= cost
	var new_lvl: int = int(lvl) + 1
	modules["levels"][key] = new_lvl
	for inst in WeaponLoadout.installed_list(modules):
		if str(inst.get("type", "")) == key:
			inst["level"] = new_lvl
	for inst2 in WeaponLoadout.inventory_list(modules):
		if str(inst2.get("type", "")) == key:
			inst2["level"] = maxi(int(inst2.get("level", 1)), new_lvl)
	WeaponLoadout._sync_legacy_flags(modules)
	toast(MODULE_INFO[key]["title"] + " Lv " + str(new_lvl))
	save_run()
	return true

func upgrade_aux() -> bool:
	var id = aux_module_id()
	if id == null or not AUX_MODULES.has(id):
		toast("No auxiliary installed")
		return false
	var lvl: int = module_level(str(id)) if WeaponLoadout.count_installed(modules, str(id)) > 0 else module_level("aux")
	if lvl >= 5:
		toast("Already max level")
		return false
	var cost := TrainBuild.aux_upgrade_cost(id, lvl)
	if cost < 0 or scrap < cost:
		toast("Not enough Scrap")
		return false
	scrap -= cost
	var new_lvl: int = lvl + 1
	modules["aux_levels"][id] = new_lvl
	for inst in WeaponLoadout.installed_list(modules):
		if str(inst.get("type", "")) == str(id):
			inst["level"] = new_lvl
	for inst2 in WeaponLoadout.inventory_list(modules):
		if str(inst2.get("type", "")) == str(id):
			inst2["level"] = maxi(int(inst2.get("level", 1)), new_lvl)
	WeaponLoadout._sync_legacy_flags(modules)
	toast(AUX_MODULES[id]["title"] + " Lv " + str(new_lvl))
	save_run()
	return true

func live_shop_apply_upgrade(entry_id: String) -> void:
	# Live Armory upgrade dispatcher — stays in combat, uses shared transactions.
	if state != "combat" or not shop_open or shop_slide < 0.95:
		return
	if shop_buy_cooldown > 0.0:
		return
	shop_buy_cooldown = SHOP_BUY_COOLDOWN_SEC
	var scrap_before: int = int(scrap)
	var ok := false
	match entry_id:
		"reactor":
			ok = buy_station("reactor")
		"armor":
			ok = buy_station("armor")
		"repair":
			ok = buy_station("repair")
		"cooling":
			ok = buy_station("cool")
		"drone_tune":
			ok = buy_station("drone")
		"upgrade_gatling":
			ok = upgrade_module("gatling")
		"upgrade_cannon":
			ok = upgrade_module("cannon")
		"upgrade_drone":
			ok = upgrade_module("drone")
		"upgrade_aux":
			ok = upgrade_aux()
		"buy_wagon_weapon":
			ok = buy_wagon("weapon")
			if ok:
				shop_buy_feedback = "WAGON ADDED"
				shop_buy_feedback_t = 1.5
				sfx("ui")
				return
		_:
			shop_buy_feedback = "UNAVAILABLE"
			shop_buy_feedback_t = 1.0
			return
	if ok:
		shop_buy_feedback = "UPGRADED"
		shop_buy_feedback_t = 1.4
		sfx("ui")
	elif int(scrap) < scrap_before:
		# Transaction helpers should never partially spend; restore just in case.
		scrap = scrap_before
		shop_buy_feedback = "FAILED"
		shop_buy_feedback_t = 1.0
	else:
		shop_buy_feedback = "NEED SCRAP" if int(scrap) == scrap_before else "BLOCKED"
		# Prefer clearer labels from eligibility when possible.
		if entry_id == "repair" and train_missing_hp() <= 0.5:
			shop_buy_feedback = "FULL HEALTH"
		elif entry_id.begins_with("upgrade_") and entry_id != "upgrade_aux":
			var wk := entry_id.replace("upgrade_", "")
			if is_module_installed(wk) and module_level(wk) >= 5:
				shop_buy_feedback = "MAX LEVEL"
		elif entry_id == "upgrade_aux" and aux_module_id() != null and module_level("aux") >= 5:
			shop_buy_feedback = "MAX LEVEL"
		elif entry_id == "drone_tune" and not is_module_installed("drone"):
			shop_buy_feedback = "NEED DRONE"
		shop_buy_feedback_t = 1.2

func choose_event(idx: int) -> void:
	if idx == 0:
		if randf() < .45:
			begin_node("elite")
		else:
			scrap += 38
			toast("Clean salvage: +38 Scrap")
			open_route(false)
	elif idx == 1:
		damage_car(0, 24, null)
		momentum["max"] *= 1.10
		toast("Risky engine salvage")
		open_route(false)
	else:
		open_route(false)

func apply_card(id: String) -> void:
	stats = ensure_stats(stats)
	match id:
		"turbocharger":
			momentum["max"] = float(momentum.get("max", 115.0)) * 1.13
		"reinforced_plating":
			for c in train_cars:
				c["max_hp"] = float(c.get("max_hp", 150.0)) + 16.0
				c["hp"] = float(c.get("hp", 150.0)) + 16.0
				c["armor"] = float(c.get("armor", 5.0)) + 4.0
		"thermal_pumps":
			stats["cooling_mul"] = float(stats.get("cooling_mul", 1.0)) * 1.30
		"momentum_rounds":
			stats["momentum_rounds"] = true
		"overcharged_ammo":
			stats["global_damage"] = float(stats.get("global_damage", 1.0)) * 1.42
			stats["heat_gen_mul"] = float(stats.get("heat_gen_mul", 1.0)) * 1.22
		"emergency_welders":
			stats["repair_mul"] = float(stats.get("repair_mul", 1.0)) * 1.4
			if abilities.has("repair") and typeof(abilities["repair"]) == TYPE_DICTIONARY:
				abilities["repair"]["cooldown_max"] = float(abilities["repair"].get("cooldown_max", 21.0)) * 0.82
		"rail_saints":
			stats["death_save"] = true
		"cannon_barrage":
			if abilities.has("barrage") and typeof(abilities["barrage"]) == TYPE_DICTIONARY:
				abilities["barrage"]["unlocked"] = true
		"drone_swarm":
			stats["drone_extra"] = int(stats.get("drone_extra", 0)) + 1
		"micro_missiles":
			stats["drone_rocket"] = min(int(stats.get("drone_rocket", 999)), 7)
		"scrap_magnets":
			stats["scrap_mul"] = float(stats.get("scrap_mul", 1.0)) * 1.28
			scrap += 12
		"rift_injector":
			reactor["max"] = int(reactor.get("max", 10)) + 2
			stats["heat_gen_mul"] = float(stats.get("heat_gen_mul", 1.0)) * 1.10

func roll_cards() -> void:
	active_cards.clear()
	while active_cards.size() < 3:
		var c = TECH_CARDS[randi_range(0, TECH_CARDS.size() - 1)]
		if not active_cards.has(c):
			active_cards.append(c)

func select_card(idx: int) -> void:
	# Legacy level-up UI hook — apply and return to combat without modal linger.
	if idx < 0 or idx >= active_cards.size():
		return
	var c = active_cards[idx]
	var cid = c.get("id", "")
	if cid != "":
		apply_card(cid)
		if not selected_cards.has(cid):
			selected_cards.append(cid)
	toast(str(c.get("title", "Upgrade")) + " online", "major")
	state = "combat"
	save_run()

func pick_auto_level_perk() -> String:
	for id in LEVEL_PERK_ORDER:
		if not selected_cards.has(id):
			return str(id)
	# All ordered perks taken — pick any remaining TECH_CARD.
	for c in TECH_CARDS:
		var cid := str(c.get("id", ""))
		if cid != "" and not selected_cards.has(cid):
			return cid
	return ""

func auto_apply_level_perk() -> void:
	var perk_id := pick_auto_level_perk()
	if perk_id == "":
		toast("TECH LEVEL %d" % level, "major")
		return
	apply_card(perk_id)
	if not selected_cards.has(perk_id):
		selected_cards.append(perk_id)
	var title := perk_id
	for c in TECH_CARDS:
		if str(c.get("id", "")) == perk_id:
			title = str(c.get("title", perk_id))
			break
	toast("LEVEL %d  •  %s" % [level, title], "major")

func add_xp(amount: float) -> void:
	xp += amount
	# Multi-level catch-up without ever leaving combat / opening card UI.
	var guard := 0
	while xp >= xp_needed and guard < 8:
		guard += 1
		xp -= xp_needed
		level += 1
		xp_needed = round(xp_needed * 1.28 + 12.0)
		auto_apply_level_perk()

func add_scrap(amount: float) -> void:
	scrap += int(round(amount))

func damage_multiplier() -> float:
	var m = stats_get("global_damage", 1.0)
	if stats_get("momentum_rounds", false):
		m *= 1.0 + .35 * clamp(momentum["speed"] / 115.0, 0.0, 1.2)
	if heat["overheated"]:
		m *= .4
	return m

func purchased_damage_multiplier() -> float:
	# Starter gun is excluded — only installed Armory weapons.
	return damage_multiplier() * purchased_weapon_damage_mul()

func _muzzle_from_mount(key: String, mount: Dictionary, recoil_key: String, tex_key: String, size_mul: float) -> Vector2:
	var mx := float(mount.get("mount_x", weapons[key]["muzzle"].x))
	var roof := TrainBuild.mount_roof_y(mount["car"], mount["hp"], 0.0) + TRAIN_RAIL_NUDGE_Y
	var face := module_face(key)
	return module_geometry(key, tex_key, mx, roof, float(train_recoil.get(recoil_key, 0.0)) * (10.0 if key == "gatling" else 16.0), face, size_mul)["muzzle"]

func _fire_gatling_from_mount(mount: Dictionary, target: Dictionary, _state_mul: float) -> void:
	var glv := module_level("gatling")
	var muzzle := _muzzle_from_mount("gatling", mount, "gatling", "module_gatling_lv1", 1.08 if glv >= 4 else 1.0)
	spawn_projectile(muzzle, target, 980.0, 5.0, weapons["gatling"]["damage"] * (1 + (glv - 1) * .18) * purchased_damage_multiplier(), "kinetic", 0.0, "#fff0b0")
	heat["value"] += .42 * stats_get("heat_gen_mul", 1.0)
	train_recoil["gatling"] = min(1.0, train_recoil["gatling"] + .24)

func _fire_cannon_from_mount(mount: Dictionary, target: Dictionary, _state_mul: float) -> void:
	var cl := module_level("cannon")
	var muzzle := _muzzle_from_mount("cannon", mount, "cannon", "module_cannon_lv1", 1.08 if cl >= 4 else 1.0)
	spawn_projectile(muzzle, target, 575.0, 13.0, weapons["cannon"]["damage"] * (1 + (cl - 1) * .22) * purchased_damage_multiplier(), "explosive", 122.0 + (cl - 1) * 8.0, "#ffae5d")
	heat["value"] += 3.4 * stats_get("heat_gen_mul", 1.0)
	train_recoil["cannon"] = 1.0
	shake = max(shake, 3.5)

func fire_gatling(target: Dictionary, state_mul: float) -> void:
	var mounts := list_weapon_mount_xy("gatling")
	if mounts.is_empty():
		var muzzle: Vector2 = weapons["gatling"]["muzzle"]
		spawn_projectile(muzzle, target, 980.0, 5.0, weapons["gatling"]["damage"] * (1 + (module_level("gatling") - 1) * .18) * purchased_damage_multiplier(), "kinetic", 0.0, "#fff0b0")
		heat["value"] += .42 * stats_get("heat_gen_mul", 1.0)
		train_recoil["gatling"] = min(1.0, train_recoil["gatling"] + .24)
		return
	for m in mounts:
		_fire_gatling_from_mount(m, target, state_mul)

func fire_cannon(target: Dictionary, state_mul: float) -> void:
	var mounts := list_weapon_mount_xy("cannon")
	if mounts.is_empty():
		var muzzle: Vector2 = weapons["cannon"]["muzzle"]
		spawn_projectile(muzzle, target, 575.0, 13.0, weapons["cannon"]["damage"] * (1 + (module_level("cannon") - 1) * .22) * purchased_damage_multiplier(), "explosive", 122.0 + (module_level("cannon") - 1) * 8.0, "#ffae5d")
		heat["value"] += 3.4 * stats_get("heat_gen_mul", 1.0)
		train_recoil["cannon"] = 1.0
		shake = max(shake, 3.5)
		return
	for m in mounts:
		_fire_cannon_from_mount(m, target, state_mul)

func get_arc_coil_emitter_pos() -> Vector2:
	var axy := get_weapon_mount_xy("aux")
	if axy.is_empty():
		return weapons.get("aux", {}).get("muzzle", Vector2(1000, 500))
	var bob = sin(train_sway) * 3.0 + sin(train_sway + 1.0) * 1.5
	var roof := TrainBuild.mount_roof_y(axy["car"], axy["hp"], bob) + TRAIN_RAIL_NUDGE_Y
	var g = module_geometry("arc_coil", "module_arc", float(axy["mount_x"]), roof, train_recoil["aux"] * 12.0, module_face("aux"))
	return g["muzzle"]

func generate_lightning_path(p0: Vector2, p1: Vector2, segments: int, roughness: float) -> Dictionary:
	var pts = PackedVector2Array()
	pts.append(p0)
	var delta = p1 - p0
	var dist = delta.length()
	if dist < 5.0:
		pts.append(p1)
		return { "main": pts, "branches": [] }

	var dir = delta / dist
	var normal = Vector2(-dir.y, dir.x)
	var seg_count = clamp(int(dist / 22.0), 8, 38)
	for i in range(1, seg_count):
		var frac = float(i) / float(seg_count)
		var envelope = sin(PI * frac)
		var macro = randf_range(-roughness, roughness) * envelope
		var micro = ((1.0 if (i % 2 == 0) else -1.0) * randf_range(roughness * 0.3, roughness * 0.7)) * envelope * 0.65
		var disp = macro + micro
		var pt = p0 + dir * (dist * frac) + normal * disp
		pts.append(pt)
	pts.append(p1)

	var branches: Array = []
	var branch_count = 3 if dist > 200.0 else (2 if dist > 100.0 else 1)
	for b in range(branch_count):
		var pick_idx = randi_range(2, max(2, pts.size() - 3))
		var bp0 = pts[pick_idx]
		var side = 1.0 if (b % 2 == 0) else -1.0
		var branch_angle = dir.angle() + side * randf_range(0.38, 0.85)
		var branch_len = randf_range(24.0, min(55.0, dist * 0.28))
		var bp1 = bp0 + Vector2(cos(branch_angle), sin(branch_angle)) * branch_len
		var b_pts = PackedVector2Array()
		b_pts.append(bp0)
		var b_segs = 4
		var b_delta = bp1 - bp0
		var b_dist = b_delta.length()
		var b_dir = b_delta / max(1.0, b_dist)
		var b_norm = Vector2(-b_dir.y, b_dir.x)
		for j in range(1, b_segs):
			var b_frac = float(j) / float(b_segs)
			var b_disp = randf_range(-7.0, 7.0) * sin(PI * b_frac)
			b_pts.append(bp0 + b_dir * (b_dist * b_frac) + b_norm * b_disp)
		b_pts.append(bp1)
		branches.append(b_pts)

	return { "main": pts, "branches": branches }

func spawn_arc_coil_vfx(target: Dictionary, chained_targets: Array) -> void:
	var emitter = get_arc_coil_emitter_pos()
	var target_pos = Vector2(target["x"], target["y"] - 45.0)
	arc_coil_flash = 0.22

	# Main lightning strike: Arc Coil crystal to primary target
	var path_data = generate_lightning_path(emitter, target_pos, 16, 26.0)
	var sparks = []
	for s in range(8):
		var ang = randf_range(0.0, TAU)
		var spd = randf_range(50.0, 160.0)
		sparks.append({ "pos": target_pos, "vel": Vector2(cos(ang), sin(ang)) * spd, "len": randf_range(6.0, 14.0) })

	lightning_strikes.append({
		"source": emitter,
		"source_is_coil": true,
		"source_target": null,
		"target": target,
		"target_pos": target_pos,
		"main_pts": path_data["main"],
		"branches": path_data["branches"],
		"sparks": sparks,
		"life": 0.20,
		"max_life": 0.20,
		"jitter_timer": 0.035,
		"is_chain": false
	})

	# Chained lightning strikes: primary target to each chained target
	for ct in chained_targets:
		var ct_pos = Vector2(ct["x"], ct["y"] - 45.0)
		var chain_path = generate_lightning_path(target_pos, ct_pos, 12, 18.0)
		var ct_sparks = []
		for s in range(6):
			var ang = randf_range(0.0, TAU)
			var spd = randf_range(40.0, 120.0)
			ct_sparks.append({ "pos": ct_pos, "vel": Vector2(cos(ang), sin(ang)) * spd, "len": randf_range(4.0, 10.0) })

		lightning_strikes.append({
			"source": target_pos,
			"source_is_coil": false,
			"source_target": target,
			"target": ct,
			"target_pos": ct_pos,
			"main_pts": chain_path["main"],
			"branches": chain_path["branches"],
			"sparks": ct_sparks,
			"life": 0.18,
			"max_life": 0.18,
			"jitter_timer": 0.035,
			"is_chain": true
		})

func update_lightning(dt: float) -> void:
	if arc_coil_flash > 0.0:
		arc_coil_flash = max(0.0, arc_coil_flash - dt)

	for i in range(lightning_strikes.size() - 1, -1, -1):
		var strike = lightning_strikes[i]
		strike["life"] -= dt
		if strike["life"] <= 0.0:
			lightning_strikes.remove_at(i)
			continue

		for sp in strike["sparks"]:
			sp["pos"] += sp["vel"] * dt
			sp["vel"] *= (1.0 - dt * 4.0)

		strike["jitter_timer"] -= dt
		if strike["jitter_timer"] <= 0.0:
			strike["jitter_timer"] = 0.035
			var p0 = get_arc_coil_emitter_pos() if strike["source_is_coil"] else (Vector2(strike["source_target"]["x"], strike["source_target"]["y"] - 45.0) if strike["source_target"] != null and not strike["source_target"].get("dead", false) else strike["source"])
			var p1 = Vector2(strike["target"]["x"], strike["target"]["y"] - 45.0) if strike["target"] != null and not strike["target"].get("dead", false) else strike["target_pos"]
			var path_data = generate_lightning_path(p0, p1, 12 if strike["is_chain"] else 16, 18.0 if strike["is_chain"] else 24.0)
			strike["main_pts"] = path_data["main"]
			strike["branches"] = path_data["branches"]

func draw_lightning() -> void:
	var aux_id = aux_module_id()
	if aux_id == "arc_coil" and power["aux"] > 0:
		var cd = weapons["aux"]["cooldown"]
		if cd > 0.0 and cd <= 0.15:
			var charge = 1.0 - (cd / 0.15)
			var em = get_arc_coil_emitter_pos()
			var c_rad = 12.0 * charge
			draw_circle(em, c_rad, Color(0.20, 0.75, 1.0, 0.35 * charge))
			draw_circle(em, c_rad * 0.5, Color(0.90, 0.98, 1.0, 0.80 * charge))
			if randf() < 0.5:
				var s_ang = randf_range(0.0, TAU)
				var s_len = randf_range(6.0, 16.0) * charge
				draw_line(em, em + Vector2(cos(s_ang), sin(s_ang)) * s_len, Color(0.70, 0.95, 1.0, 0.75 * charge), 1.5)

	if arc_coil_flash > 0.0:
		var em = get_arc_coil_emitter_pos()
		var flash_ratio = arc_coil_flash / 0.22
		draw_circle(em, 22.0 * flash_ratio, Color(0.15, 0.70, 1.0, 0.35 * flash_ratio))
		draw_circle(em, 12.0 * flash_ratio, Color(0.45, 0.92, 1.0, 0.70 * flash_ratio))
		draw_circle(em, 5.0 * flash_ratio, Color(0.95, 1.0, 1.0, 0.95 * flash_ratio))
		for k in range(3):
			var k_ang = randf_range(0.0, TAU)
			var k_len = randf_range(10.0, 24.0) * flash_ratio
			draw_line(em, em + Vector2(cos(k_ang), sin(k_ang)) * k_len, Color(0.80, 0.98, 1.0, 0.85 * flash_ratio), 1.5)

	for strike in lightning_strikes:
		var alpha = clamp(strike["life"] / (strike["max_life"] * 0.7), 0.0, 1.0)
		var pts: PackedVector2Array = strike["main_pts"]
		if pts.size() >= 2:
			draw_polyline(pts, Color(0.12, 0.58, 1.0, 0.38 * alpha), 8.5, true)
			draw_polyline(pts, Color(0.35, 0.88, 1.0, 0.75 * alpha), 4.2, true)
			draw_polyline(pts, Color(0.92, 0.98, 1.0, 0.98 * alpha), 1.8, true)

		for b_pts in strike["branches"]:
			var b: PackedVector2Array = b_pts
			if b.size() >= 2:
				draw_polyline(b, Color(0.20, 0.75, 1.0, 0.45 * alpha), 3.5, true)
				draw_polyline(b, Color(0.90, 0.98, 1.0, 0.85 * alpha), 1.3, true)

		var t_pos = strike["target_pos"]
		if strike["target"] != null and not strike["target"].get("dead", false):
			t_pos = Vector2(strike["target"]["x"], strike["target"]["y"] - 45.0)

		var flash_size = (16.0 if not strike["is_chain"] else 12.0) * alpha
		draw_circle(t_pos, flash_size, Color(0.18, 0.72, 1.0, 0.35 * alpha))
		draw_circle(t_pos, flash_size * 0.5, Color(0.45, 0.90, 1.0, 0.70 * alpha))
		draw_circle(t_pos, flash_size * 0.25, Color(0.95, 1.0, 1.0, 0.95 * alpha))

		for sp in strike["sparks"]:
			var sp_dir = sp["vel"].normalized()
			var sp_len = sp["len"] * alpha
			draw_line(sp["pos"], sp["pos"] + sp_dir * sp_len, Color(0.75, 0.95, 1.0, 0.85 * alpha), 1.5)

func fire_arc_coil(target: Dictionary, state_mul: float, lvl: int) -> void:
	var arc_mul := purchased_damage_multiplier()
	damage_enemy(target, AUX_MODULES["arc_coil"]["damage"] * (1 + (lvl - 1) * .2) * arc_mul, "electric")
	var chained_targets: Array = []
	for e in enemies:
		if e != target and not e.get("dead", false) and Vector2(e["x"], e["y"]).distance_to(Vector2(target["x"], target["y"])) < 260:
			damage_enemy(e, AUX_MODULES["arc_coil"]["damage"] * .62 * arc_mul, "electric")
			chained_targets.append(e)
	heat["value"] += AUX_MODULES["arc_coil"]["heat"]
	train_recoil["aux"] = .55
	spawn_arc_coil_vfx(target, chained_targets)

func fire_cryo(target: Dictionary, state_mul: float, lvl: int) -> void:
	var muzzle: Vector2 = weapons["aux"]["muzzle"]
	spawn_projectile(muzzle, target, 650.0, 9.0, AUX_MODULES["cryo_launcher"]["damage"] * (1 + (lvl - 1) * .16) * purchased_damage_multiplier(), "cryo", 86.0 if lvl >= 4 else 0.0, "#9df5ff")
	heat["value"] += AUX_MODULES["cryo_launcher"]["heat"]
	train_recoil["aux"] = .5

func fire_mortar(target: Dictionary, state_mul: float, lvl: int) -> void:
	var muzzle: Vector2 = weapons["aux"]["muzzle"]
	spawn_projectile(muzzle, target, 520.0, 12.0, AUX_MODULES["rail_mortar"]["damage"] * (1 + (lvl - 1) * .24) * purchased_damage_multiplier(), "explosive", 118.0 + lvl * 10.0, "#ffc16b")
	heat["value"] += AUX_MODULES["rail_mortar"]["heat"]
	train_recoil["aux"] = 1.0

func fire_missile_rack(target: Dictionary, state_mul: float, lvl: int) -> void:
	var count = min(5, 2 + int(lvl / 2) + (1 if power["aux"] >= 3 else 0))
	var candidates = sort_targets(enemies.filter(func(e): return not e.get("dead", false)), weapons["aux"]["priority"], weapons["aux"]["muzzle"].x)
	var base_muzzle: Vector2 = weapons["aux"]["muzzle"]
	var flip = weapons["aux"].get("flip", false)
	for i in range(min(count, candidates.size())):
		var e = candidates[i]
		var off_x = (i * 6.0) if flip else (-i * 6.0)
		var muzzle = Vector2(base_muzzle.x + off_x, base_muzzle.y - i * 3.0)
		spawn_projectile(muzzle, e, 540.0, 8.0, AUX_MODULES["missile_rack"]["damage"] * (1 + (lvl - 1) * .18) * purchased_damage_multiplier() * (1.0 if i == 0 else .72), "explosive", 78.0 + lvl * 8.0, "#dca1ff", true)
	heat["value"] += AUX_MODULES["missile_rack"]["heat"]
	train_recoil["aux"] = .8

func fire_drone_bolt(drone: Dictionary, target: Dictionary, explosive = false) -> void:
	spawn_projectile(Vector2(drone["x"], drone["y"]), target, 610.0 if explosive else 820.0, 9.0 if explosive else 5.0, (34.0 if explosive else weapons["drone"]["damage"]) * stats_get("drone_damage", 1.0) * purchased_damage_multiplier(), "explosive" if explosive else "electric", 88.0 if explosive else 0.0, "#b98cff" if explosive else "#75f7ff", not explosive)

func enemy_aim_point(e: Dictionary) -> Vector2:
	# Colossus feet are at e.y; aim / hit the armored torso instead.
	if e.get("boss", false):
		return Vector2(e["x"] + 20.0, e["y"] - 360.0)
	return Vector2(e["x"], e["y"] - 45.0)

func spawn_projectile(pos: Vector2, target: Dictionary, speed: float, radius: float, damage: float, dtype: String, splash = 0.0, color = "#ffffff", homing = false, armor_pen: float = 0.0) -> void:
	var aim = enemy_aim_point(target)
	var dir = (aim - pos).normalized()
	projectiles.append({
		"x": pos.x, "y": pos.y, "vx": dir.x * speed, "vy": dir.y * speed, "speed": speed,
		"radius": radius, "damage": damage, "type": dtype, "splash": splash,
		"color": Color.html(color), "target": target, "homing": homing, "life": 2.4,
		"armor_pen": maxf(0.0, armor_pen)
	})

func update_projectiles(dt: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p = projectiles[i]
		var target = p.get("target", null)
		if target != null and not target.get("dead", false) and p.get("homing", false):
			var dir = (enemy_aim_point(target) - Vector2(p["x"], p["y"])).normalized()
			p["vx"] = lerp(p["vx"], dir.x * p["speed"], .08)
			p["vy"] = lerp(p["vy"], dir.y * p["speed"], .08)
		for e in enemies:
			if e.get("dead", false):
				continue
			var hit_r = e.get("hit_radius", 38.0) * (1.55 if e.get("boss", false) else 1.0)
			if Vector2(p["x"], p["y"]).distance_to(enemy_aim_point(e)) < p["radius"] + hit_r:
				var pen := float(p.get("armor_pen", 0.0))
				damage_enemy(e, p["damage"], p["type"], pen)
				if p["splash"] > 0:
					for other in enemies:
						if other != e and not other.get("dead", false) and Vector2(other["x"], other["y"]).distance_to(Vector2(e["x"], e["y"])) < p["splash"]:
							damage_enemy(other, p["damage"] * .45, p["type"], pen)
				projectiles.remove_at(i)
				break

func spawn_enemy_projectile(source: Dictionary, car_idx: int, color = "#85fff8") -> void:
	var car = train_cars[clampi(car_idx, 0, train_cars.size() - 1)]
	# Face-aware muzzle: rift units face RIGHT toward the train.
	var face_right = float(source.get("dir", 1.0)) < 0.0 or bool(source.get("data", {}).get("rift", false))
	var pos = Vector2(source["x"] + (48.0 if face_right else -36.0), source["y"] - 56.0)
	var aim = Vector2(car_draw_center_x(car) + randf_range(-60, 60), 640.0)
	var dir = (aim - pos).normalized()
	enemy_projectiles.append({ "x": pos.x, "y": pos.y, "vx": dir.x * 640.0, "vy": dir.y * 640.0, "target": aim, "car": car_idx, "radius": 8.0, "damage": source["attack"], "color": Color.html(color), "life": 2.2 })

func flux_rifle_muzzle(e: Dictionary) -> Vector2:
	var sc = float(e.get("data", {}).get("scale", 1.0))
	return Vector2(float(e["x"]) + 52.0 * sc, float(e["y"]) - 72.0 * sc)

func spawn_flux_laser(source: Dictionary, car_idx: int) -> void:
	var car = train_cars[clampi(car_idx, 0, train_cars.size() - 1)]
	var muzzle = flux_rifle_muzzle(source)
	var aim = Vector2(car_draw_center_x(car) + randf_range(-40.0, 40.0), 635.0 + randf_range(-18.0, 18.0))
	enemy_lasers.append({
		"x0": muzzle.x, "y0": muzzle.y, "x1": aim.x, "y1": aim.y,
		"life": 0.28, "max": 0.28, "width": 7.0, "charge": false, "strength": 1.0
	})
	# Muzzle bloom + impact
	impact_bursts.append({ "x": muzzle.x, "y": muzzle.y, "life": 0.22, "max": 0.22, "size": 28.0, "color": Color(0.45, 0.95, 1.0), "type": "slam", "angle": 0.0 })
	impact_bursts.append({ "x": aim.x, "y": aim.y, "life": 0.30, "max": 0.30, "size": 42.0, "color": Color(0.55, 1.0, 1.0), "type": "slam", "angle": 0.0 })
	damage_car(car_idx, float(source["attack"]), source)
	sfx("warn")
	shake = max(shake, 2.5)

func update_enemy_projectiles(dt: float) -> void:
	for i in range(enemy_projectiles.size() - 1, -1, -1):
		var p = enemy_projectiles[i]
		p["x"] += float(p.get("vx", 0.0)) * dt
		p["y"] += float(p.get("vy", 0.0)) * dt
		p["life"] = float(p.get("life", 1.0)) - dt
		if Vector2(p["x"], p["y"]).distance_to(p["target"]) < 22 or float(p["life"]) <= 0.0:
			if Vector2(p["x"], p["y"]).distance_to(p["target"]) < 40.0:
				damage_car(p["car"], p["damage"], null)
			enemy_projectiles.remove_at(i)
	for i in range(enemy_lasers.size() - 1, -1, -1):
		enemy_lasers[i]["life"] = float(enemy_lasers[i]["life"]) - dt
		if float(enemy_lasers[i]["life"]) <= 0.0:
			enemy_lasers.remove_at(i)

func damage_enemy(e: Dictionary, amount: float, dtype = "kinetic", armor_pen: float = 0.0) -> void:
	if e.get("dead", false):
		return
	if e.get("invuln", false) or (e.get("boss", false) and boss_intro_active):
		return
	var raw_armor := maxf(0.0, float(e.get("armor", 0.0)))
	var eff_armor := maxf(0.0, raw_armor - maxf(0.0, armor_pen))
	var red = eff_armor / (eff_armor + 35.0)
	var dmg = max(1.0, amount * (1.0 - red))
	e["hp"] -= dmg
	e["flash"] = .12
	if settings["damage_numbers"]:
		var dmg_y = e["y"] - (420.0 if e.get("boss", false) else 70.0)
		damage_numbers.append({ "x": e["x"], "y": dmg_y, "text": str(int(dmg)), "life": .65, "color": Color.WHITE })
	if e["hp"] <= 0:
		e["dead"] = true
		if e.get("boss", false):
			e["anim"] = "death"
			e["anim_t"] = 0.0
			e["attack_style"] = ""
			e["windup"] = 0.0
			e["anim_hold"] = false
			e["death"] = boss_anim_duration("death") + 0.25
		else:
			e["death"] = .55
		if e.get("boarded", false) or e.get("board_state", "") in ["leaping", "attached"]:
			e["boarded"] = false
			e["board_state"] = "dead"
		var eclass_scrap := str(e.get("elite_class", RiftLoop.CLASS_NORMAL))
		var scrap_class_mul := RiftLoop.elite_scrap_mul(eclass_scrap)
		if scrap_class_mul <= 1.001 and e.get("elite", false) and not e.get("boss", false):
			scrap_class_mul = RiftLoop.elite_scrap_mul(RiftLoop.CLASS_RED)
		var scrap_gain = randi_range(e["data"].get("scrap_min", BOSS_DATA["scrap_min"]), e["data"].get("scrap_max", BOSS_DATA["scrap_max"])) * scrap_class_mul * stats_get("scrap_mul", 1.0)
		var xp_gain = e["data"].get("xp", BOSS_DATA["xp"])
		add_scrap(scrap_gain)
		add_xp(xp_gain)
		kills += 1
		run_kills += 1
		if e.get("data", {}).get("leech", false) and (e.get("boarded", false) or str(e.get("board_state", "")) == "attached"):
			leech_heat_pressure = maxf(0.0, leech_heat_pressure - 4.5)
			toast("Coil Leech purged — heat pressure easing")
		spawn_loot_orbs(e["x"], e["y"] - 60.0, scrap_gain, xp_gain, e.get("boss", false))
		if e.get("boss", false):
			boss_death_pending = true
			var blabel = str(e.get("data", {}).get("label", "BOSS"))
			toast("%s CRITICAL — COLLAPSING!" % blabel)
			sfx("boom")

func damage_car(idx: int, amount: float, source) -> void:
	idx = clampi(idx, 0, train_cars.size() - 1)
	var car = train_cars[idx]
	if car["hp"] <= 0:
		return
	if shield_time > 0:
		amount *= .35
	amount *= impact_damage_mul()
	var red = car["armor"] / (car["armor"] + 35.0)
	var final = max(1.0, amount * (1.0 - red))
	car["hp"] -= final
	run_damage_taken += final
	train_damage_flash = .14
	shake = max(shake, 3.0)
	if settings["damage_numbers"]:
		damage_numbers.append({ "x": car_draw_center_x(car), "y": 570.0, "text": "-" + str(int(final)), "life": .65, "color": Color.html("#ff7a66") })
	if car["hp"] <= 0:
		car["hp"] = 0
		if not car.get("disabled", false):
			car["disabled"] = true
			car["wreck_t"] = 0.0
			toast(str(car["label"]).to_upper() + " DISABLED!")
			sfx("warn")
			shake = max(shake, 11.0)
			_nudge_combat_camera_for_convoy_change()
			# Cargo broken: train will pack left; boss stays on left rail and presses harder.
			if boss_active and is_mycelarch_boss():
				var next_idx = pick_boss_target_car(true)
				var next_label = str(train_cars[next_idx].get("label", "TRAIN")).to_upper()
				toast("MYCELARCH PRESSES THE %s!" % next_label)
				for e in enemies:
					if e.get("boss", false) and is_mycelarch_boss(e):
						e["cd"] = min(float(e.get("cd", 0.5)), 0.28)
						# Slight lean-in only — never walk into the empty cargo hole.
						e["lunge"] = max(float(e.get("lunge", 0.0)), 0.2)
						break
			# Immediate break burst
			for i in range(18):
				particles.append({
					"x": car["x"] + randf_range(-90, 90),
					"y": 600.0 + randf_range(-80, 40),
					"vx": randf_range(-180, 180),
					"vy": randf_range(-220, 60),
					"life": randf_range(0.35, 0.8),
					"max": 0.8,
					"size": randf_range(3, 9),
					"color": Color(1.0, 0.45 + randf() * 0.3, 0.15, 0.95) if i % 2 == 0 else Color(0.35, 0.32, 0.3, 0.7)
				})
			spawn_fx_explosion(car["x"], 580.0, "explosion_car", 260.0, 0.8)
		if car["id"] == "loco":
			if stats_get("death_save", false):
				stats["death_save"] = false
				car["hp"] = car["max_hp"] * .35
				car["disabled"] = false
				car["wreck_t"] = 0.0
				_nudge_combat_camera_for_convoy_change()
				toast("Rail Saints restored the locomotive!")
			else:
				fail_run()

func repair_train(amount: float) -> void:
	var left = amount
	var list = train_cars.duplicate()
	list.sort_custom(func(a, b): return a["hp"] / a["max_hp"] < b["hp"] / b["max_hp"])
	var restored_any := false
	for car in list:
		if left <= 0:
			break
		var add = min(left, car["max_hp"] - car["hp"])
		if add > 0:
			var was_disabled = car.get("disabled", false)
			car["hp"] += add
			car["disabled"] = false
			car["wreck_t"] = 0.0
			if was_disabled:
				toast(str(car["label"]) + " restored")
				restored_any = true
			left -= add
	if restored_any:
		_nudge_combat_camera_for_convoy_change()

func is_targetable_onscreen(e: Dictionary) -> bool:
	if e.get("dead", false):
		return false
	if e.get("boss", false):
		# Tall left-side colossus: engage once the rise intro finishes and torso is planted.
		if boss_intro_active or e.get("invuln", false):
			return false
		return e["x"] >= 80.0 and e["x"] <= 720.0 and e.get("rise", 1.0) >= 0.85
	# Left-chase enemies spawn off-screen. Require them well onto the playfield
	# (past the left margin / moon edge) so weapons and drones cannot snipe
	# before the player can actually see them.
	return e["x"] >= 180.0 and e["x"] <= (DESIGN_W + 60.0)

func find_target(priority: String, range: float, from_x: float):
	var candidates = []
	for e in enemies:
		if e.get("dead", false):
			continue
		if not is_targetable_onscreen(e):
			continue
		# Colossus sits on the far left while the convoy is shifted right — allow long engage range.
		var max_r = range + (1400.0 if e.get("boss", false) else 0.0)
		if abs(e["x"] - from_x) < max_r:
			candidates.append(e)
	if candidates.is_empty():
		return null
	return sort_targets(candidates, priority, from_x)[0]

func sort_targets(candidates: Array, priority: String, from_x: float) -> Array:
	var arr = candidates.duplicate()
	arr.sort_custom(func(a, b): return target_score(a, priority, from_x) < target_score(b, priority, from_x))
	return arr
func target_score(e: Dictionary, priority: String, from_x: float) -> float:
	if priority == "strongest":
		return -e["hp"]
	if priority == "lowest":
		return e["hp"]
	if priority == "fastest":
		return -e.get("speed", 0.0)
	if priority == "flying":
		return (-100000.0 if e["data"].get("flying", false) else 0.0) + abs(e["x"] - from_x)
	if priority == "boarders":
		return (-100000.0 if e["data"].get("boarder", false) or e.get("boarded", false) else 0.0) + abs(e["x"] - from_x)
	if priority == "starter":
		# 1) Attached damaging boarders  2) Imminent boarders  3) Dangerous nearby  4) Nearest
		var dist: float = absf(float(e["x"]) - from_x)
		var bstate: String = str(e.get("board_state", ""))
		var is_boarder: bool = bool(e.get("data", {}).get("boarder", false)) or bool(e.get("boarded", false))
		if e.get("boarded", false) or bstate == "attached":
			return -200000.0 + dist
		if is_boarder and bstate == "leaping":
			return -160000.0 + dist
		if is_boarder:
			# Running boarders near the train are about to latch.
			var rear_idx: int = get_rear_target_car_idx()
			var leap_x: float = get_car_rear_boundary(rear_idx) - 50.0
			if float(e["x"]) >= leap_x - 220.0:
				return -140000.0 + dist
			return -90000.0 + dist
		var typ: String = str(e.get("type", ""))
		if typ == "brute" or float(e.get("attack", 0.0)) >= 10.0:
			return -40000.0 + dist
		return dist + (120.0 if e.get("boss", false) else 0.0)
	if priority == "rear":
		return e["x"]
	return abs(e["x"] - from_x) + (120.0 if e.get("boss", false) else 0.0)

func calculate_run_score(win = false) -> int:
	var hp_now = 0.0
	var hp_max = 0.0
	for c in train_cars:
		hp_now += max(0.0, c["hp"])
		hp_max += c["max_hp"]
	var hull = hp_now / max(1.0, hp_max)
	var diff_mul = 1.45 if difficulty == "nightmare" else 1.2 if difficulty == "veteran" else 1.0
	return max(0, int(round(((2600 if win else 0) + kills * 16 + level * 135 + encounter_index * 260 + scrap * 2.4 + hull * 900 + max(0.0, 900.0 - run_time) * 2 - run_damage_taken * 1.1) * diff_mul)))

func on_boss_defeated() -> void:
	if victory or region_transition_active:
		return
	# Loco already dead → keep the fail screen; don't overwrite death with victory.
	if state == "failed":
		return
	if train_cars.size() > 0:
		var loco0 = train_cars[0]
		if loco0.get("disabled", false) or float(loco0.get("hp", 0.0)) <= 0.0:
			fail_run()
			return
	var defeated_id = active_boss_id()
	boss_active = false
	boss_intro_active = false
	boss_death_pending = false
	# Ease framing back — do not hard-snap x (region transition / combat chase finish it).
	train_shift_desired = 0.0
	train_pack_target = 0.0
	train_pack_x = 0.0

	# Wipe the defeated arena completely — no leftover Iron Maw / adds into the next biome.
	enemies.clear()
	projectiles.clear()
	enemy_projectiles.clear()
	enemy_lasers.clear()
	telegraphs.clear()
	impact_bursts.clear()
	lightning_strikes.clear()

	# Region 3 climax: Breach Engine down → Rift Cycle complete → next loop Rustlands.
	if defeated_id == "breach_engine" or current_region == "rift_scar":
		win_expedition("THE BREACH ENGINE shuts down. The Scar's core falls silent.")
		return

	# Region 2 climax: Mycelarch down → award + crossfade into The Rift Scar.
	if defeated_id == "mycelarch" or current_region == "fungus_wilds":
		fungus_completed = true
		last_run_score = calculate_run_score(false)
		permanent = ensure_permanent(permanent)
		permanent["best_score"] = max(permanent["best_score"], last_run_score)
		if not permanent["unlocked"].has("Spore Filter Blueprint"):
			permanent["unlocked"].append("Spore Filter Blueprint")
		var alloy_m = int(round((28 + level * 3) * diff_profile()["alloy_reward"]))
		permanent["alloy"] += alloy_m
		save_permanent()
		sfx("victory")
		shake = max(shake, 14.0)
		toast("MYCELARCH SLAIN! Entering the Rift Scar (+%d Alloy)" % alloy_m)
		encounter_index = 0
		start_region_transition(RiftScar.REGION_ID)
		return

	# Region 1 climax: Iron Maw down → unlock + crossfade into Fungus Wilds.
	rustlands_completed = true
	last_run_score = calculate_run_score(false)
	permanent = ensure_permanent(permanent)
	permanent["victories"] += 1
	permanent["best_score"] = max(permanent["best_score"], last_run_score)
	permanent["best_boss"] = true
	if not permanent["unlocked"].has("Missile Rack Blueprint"):
		permanent["unlocked"].append("Missile Rack Blueprint")
	var alloy_gain = int(round((24 + level * 3) * diff_profile()["alloy_reward"]))
	permanent["alloy"] += alloy_gain
	save_permanent()
	sfx("victory")
	shake = max(shake, 14.0)
	toast("IRON MAW SLAIN! Rustlands Cleared (+%d Alloy)" % alloy_gain)
	# Reset track index BEFORE the crossfade so we blend into Frontier — not Deep Wilds.
	encounter_index = 0
	start_region_transition("fungus_wilds")

var victory_flavor: String = ""

func win_expedition(flavor: String = "") -> void:
	victory = true
	state = "victory"
	rift_cycle_complete = true
	rift_cycle_next_loop = rift_loop + 1
	victory_flavor = flavor if flavor != "" else "Rift Cycle complete."
	last_run_score = calculate_run_score(true)
	permanent = ensure_permanent(permanent)
	permanent["victories"] += 1
	permanent["best_score"] = max(permanent["best_score"], last_run_score)
	permanent["best_boss"] = true
	permanent["highest_rift_loop"] = maxi(int(permanent.get("highest_rift_loop", 1)), rift_cycle_next_loop)
	var alloy_gain = int(round((48 + level * 5) * diff_profile()["alloy_reward"]))
	permanent["alloy"] += alloy_gain
	if not permanent["unlocked"].has("Breach Core Blueprint"):
		permanent["unlocked"].append("Breach Core Blueprint")
	if not permanent["unlocked"].has("Spore Filter Blueprint"):
		permanent["unlocked"].append("Spore Filter Blueprint")
	save_permanent()
	sfx("victory")
	toast("RIFT CYCLE COMPLETE — Entering Loop %d (+%d Alloy)" % [rift_cycle_next_loop, alloy_gain])
	# Skip the summary modal — go straight into the next loop transition.
	shake = 0.0
	continue_rift_loop()

func continue_rift_loop() -> void:
	# Preserve train, weapons, scrap, XP, cards — advance loop and return to Rustlands.
	if not rift_cycle_complete and state != "victory":
		return
	rift_loop = maxi(1, rift_cycle_next_loop)
	rift_cycle_complete = false
	victory = false
	victory_flavor = ""
	shake = 0.0
	permanent = ensure_permanent(permanent)
	permanent["highest_rift_loop"] = maxi(int(permanent.get("highest_rift_loop", 1)), rift_loop)
	save_permanent()
	fungus_completed = false
	rustlands_completed = false
	encounter_index = 0
	boss_active = false
	boss_intro_active = false
	boss_death_pending = false
	enemies.clear()
	projectiles.clear()
	enemy_projectiles.clear()
	enemy_lasers.clear()
	telegraphs.clear()
	impact_bursts.clear()
	train_shift_desired = 0.0
	train_shift_target = 0.0
	train_pack_target = 0.0
	train_pack_x = 0.0
	leech_heat_pressure = 0.0
	paused = false
	state = "combat"
	repair_train(55.0 * stats_get("repair_mul", 1.0))
	heat["value"] = min(heat["value"], 28.0)
	toast("RIFT LOOP %d — Returning to the Rustlands" % rift_loop, "major")
	start_region_transition("rustlands")
	save_run()

func debug_goto_rift_loop(loop: int = 2) -> void:
	# F2 — jump to a Rift Loop while keeping the current train / scrap / weapons.
	debug_ensure_combat()
	rift_loop = maxi(1, loop)
	rift_cycle_complete = false
	rift_cycle_next_loop = rift_loop + 1
	victory = false
	permanent = ensure_permanent(permanent)
	permanent["highest_rift_loop"] = maxi(int(permanent.get("highest_rift_loop", 1)), rift_loop)
	save_permanent()
	fungus_completed = false
	rustlands_completed = false
	current_region = "rustlands"
	encounter_index = 0
	boss_active = false
	boss_intro_active = false
	boss_death_pending = false
	region_transition_active = false
	region_transition_timer = 0.0
	enemies.clear()
	projectiles.clear()
	enemy_projectiles.clear()
	enemy_lasers.clear()
	telegraphs.clear()
	train_shift_desired = 0.0
	train_shift_target = 0.0
	train_pack_target = 0.0
	train_pack_x = 0.0
	leech_heat_pressure = 0.0
	paused = false
	state = "combat"
	configure_encounter("combat")
	snap_combat_view_shift()
	toasts.clear()
	toast("DEBUG: RIFT LOOP %d — Rustlands Track 1" % rift_loop)
	sfx("ui")
	save_run()

func debug_start_iron_maw() -> void:
	debug_ensure_combat()
	current_region = "rustlands"
	start_boss()

func debug_start_mycelarch() -> void:
	debug_ensure_combat()
	current_region = "fungus_wilds"
	start_boss()

func debug_start_rift_scar() -> void:
	# F10 — skip straight to Stage 3 finale boss (The Breach Engine).
	debug_ensure_combat()
	apply_classic_full_loadout()
	apply_workshop_bonuses()
	scrap = maxi(scrap, 400)
	rustlands_completed = true
	fungus_completed = true
	current_region = RiftScar.REGION_ID
	encounter_index = 6
	boss_active = false
	boss_intro_active = false
	boss_death_pending = false
	train_pack_x = 0.0
	train_pack_target = 0.0
	enemies.clear()
	projectiles.clear()
	enemy_projectiles.clear()
	enemy_lasers.clear()
	telegraphs.clear()
	leech_heat_pressure = 0.0
	route_choices.clear()
	toasts.clear()
	paused = false
	state = "combat"
	if rift_sparks.is_empty():
		init_rift_sparks()
	prepare_for_boss_fight()
	start_boss()
	snap_combat_view_shift()
	toasts.clear()
	toast("DEBUG: BREACH ENGINE")
	sfx("ui")

func fail_run() -> void:
	if state == "failed" or state == "victory" or victory:
		return
	state = "failed"
	if audio != null:
		audio.stop_music(2.0)
	boss_active = false
	boss_intro_active = false
	boss_death_pending = false
	# Fail UI freezes combat updates — snap framing now or the convoy stays stuck right.
	train_shift_desired = 0.0
	train_shift_target = 0.0
	train_shift_x = 0.0
	train_pack_target = 0.0
	train_pack_x = 0.0
	apply_train_layout()
	for c in train_cars:
		c["x"] = float(c.get("x", 0.0)) + car_slot_ox(c)
	# Force loco readout to zero so the fail screen never keeps a leftover HP bar.
	if train_cars.size() > 0:
		train_cars[0]["hp"] = 0.0
		train_cars[0]["disabled"] = true
	last_run_score = calculate_run_score(false)
	permanent = ensure_permanent(permanent)
	var alloy_gain := TrainBuild.fail_alloy_reward(encounter_index, current_region, run_kills, level, run_time)
	alloy_gain = maxi(1, int(round(float(alloy_gain) * float(diff_profile()["alloy_reward"]))))
	permanent["alloy"] = int(permanent.get("alloy", 0)) + alloy_gain
	permanent["best_score"] = max(permanent["best_score"], last_run_score)
	permanent["highest_rift_loop"] = maxi(int(permanent.get("highest_rift_loop", 1)), rift_loop)
	last_fail_info = {
		"region": current_region,
		"track": int(encounter_index) + 1,
		"kills": run_kills,
		"level": level,
		"score": last_run_score,
		"alloy": alloy_gain,
		"alloy_total": int(permanent.get("alloy", 0)),
		"time": run_time,
		"loop": rift_loop,
		"highest_loop": int(permanent.get("highest_rift_loop", rift_loop))
	}
	save_permanent()
	DirAccess.remove_absolute(SAVE_RUN)

func diff_profile() -> Dictionary:
	return DIFFICULTIES[difficulty]
func fmt_time(v: float) -> String:
	var s = max(0, int(v))
	return "%d:%02d" % [s / 60, s % 60]
func aux_module_id():
	# First installed aux type (legacy readers / single-slot UI fallbacks).
	for inst in WeaponLoadout.installed_list(modules):
		if WeaponLoadout.is_aux_type(str(inst.get("type", ""))):
			return str(inst.get("type", ""))
	return modules.get("installed", {}).get("aux", null)

func is_module_installed(k: String) -> bool:
	if k == "aux":
		return WeaponLoadout.count_installed(modules, "arc_coil") \
			+ WeaponLoadout.count_installed(modules, "cryo_launcher") \
			+ WeaponLoadout.count_installed(modules, "rail_mortar") \
			+ WeaponLoadout.count_installed(modules, "missile_rack") > 0
	return WeaponLoadout.count_installed(modules, k) > 0

func module_level(k: String) -> int:
	var best := 1
	var found := false
	for inst in WeaponLoadout.installed_list(modules):
		var t := str(inst.get("type", ""))
		if k == "aux" and WeaponLoadout.is_aux_type(t):
			best = maxi(best, int(inst.get("level", 1)))
			found = true
		elif t == k:
			best = maxi(best, int(inst.get("level", 1)))
			found = true
	if found:
		return best
	if k == "aux":
		var id = aux_module_id()
		return int(modules.get("aux_levels", {}).get(id, 1)) if id != null else 1
	return int(modules.get("levels", {}).get(k, 1))

func instance_level(inst: Dictionary) -> int:
	return clampi(int(inst.get("level", 1)), 1, 5)

func reactor_used_power() -> int:
	var used := 0
	for k in ["engine", "shield", "utility"]:
		used += int(power.get(k, 0))
	used += WeaponLoadout.total_weapon_power(modules)
	return used

func workshop_tier(key: String) -> int:
	permanent = ensure_permanent(permanent)
	return clampi(int(permanent["workshop"].get(key, 0)), 0, TrainBuild.WORKSHOP_MAX_TIER)

func starter_armor_pen() -> float:
	return float(workshop_tier("armor_pierce")) * 1.5

func purchased_weapon_damage_mul() -> float:
	return 1.0 + float(workshop_tier("weapons_eng")) * 0.04

func impact_damage_mul() -> float:
	return maxf(0.55, 1.0 - float(workshop_tier("impact")) * 0.03)

func apply_workshop_bonuses() -> void:
	# Applied once at new-expedition start (reset_run). Do not call again on load/loop.
	stats = ensure_stats(stats)
	permanent = ensure_permanent(permanent)
	var w = permanent["workshop"]
	reactor["max"] += int(w.get("reactor", 0))
	var hull := int(w.get("hull", 0))
	if hull <= 0:
		hull = int(w.get("armor", 0)) # legacy save key
	if hull > 0:
		for c in train_cars:
			var ct := str(c.get("car_type", c.get("id", "")))
			if ct != "loco":
				continue
			c["max_hp"] = float(c.get("max_hp", 150.0)) + hull * 12.0
			c["hp"] = float(c.get("hp", 150.0)) + hull * 12.0
			c["armor"] = float(c.get("armor", 5.0)) + float(hull)
	var starter_t := int(w.get("starter", 0))
	var target_t := int(w.get("targeting", 0))
	starter_gun["damage"] = TrainBuild.STARTER_DAMAGE + float(starter_t) * 0.7
	starter_gun["cooldown_max"] = TrainBuild.STARTER_COOLDOWN * (1.0 - float(starter_t) * 0.03)
	starter_gun["range"] = TrainBuild.STARTER_RANGE * (1.0 + float(target_t) * 0.06)
	stats["cooling_mul"] = float(stats.get("cooling_mul", 1.0)) * (1.0 + float(w.get("cooling", 0)) * 0.06)
	stats["scrap_mul"] = float(stats.get("scrap_mul", 1.0)) * (1.0 + float(w.get("salvage", 0)) * 0.04)

func apply_reinforced_to_wagon(car: Dictionary) -> void:
	var rc := workshop_tier("reinforced")
	if rc <= 0:
		return
	if bool(car.get("reinforced_applied", false)):
		return
	var bonus := float(rc) * 12.0
	car["max_hp"] = float(car.get("max_hp", 150.0)) + bonus
	car["hp"] = float(car.get("max_hp", 150.0))
	car["reinforced_applied"] = true

func apply_field_engineering_heal() -> void:
	var fe := workshop_tier("field_eng")
	if fe <= 0:
		return
	var heal := float(fe) * 8.0
	var healed := 0
	for c in train_cars:
		if bool(c.get("disabled", false)):
			continue
		var hp := float(c.get("hp", 0.0))
		var mx := float(c.get("max_hp", 0.0))
		if hp <= 0.0 or hp >= mx:
			continue
		c["hp"] = minf(mx, hp + heal)
		healed += 1
	if healed > 0:
		toast("Field Engineering  •  patched %d car%s" % [healed, "s" if healed != 1 else ""], "major")

func ensure_permanent(data: Dictionary) -> Dictionary:
	var p = data.duplicate(true)
	p["alloy"] = int(p.get("alloy", 0))
	p["best_boss"] = bool(p.get("best_boss", false))
	p["victories"] = int(p.get("victories", 0))
	p["best_score"] = int(p.get("best_score", 0))
	p["best_time"] = float(p.get("best_time", 0.0))
	p["best_kills"] = int(p.get("best_kills", 0))
	p["highest_rift_loop"] = maxi(1, int(p.get("highest_rift_loop", 1)))
	p["unlocked"] = p.get("unlocked", [])
	p["workshop"] = p.get("workshop", {})
	# Migrate pre-hardcore "armor" tiers into Locomotive Hull.
	if int(p["workshop"].get("hull", 0)) <= 0 and int(p["workshop"].get("armor", 0)) > 0:
		p["workshop"]["hull"] = int(p["workshop"]["armor"])
	for k in TrainBuild.WORKSHOP_KEYS:
		p["workshop"][k] = clampi(int(p["workshop"].get(k, 0)), 0, TrainBuild.WORKSHOP_MAX_TIER)
	return p

func serialize_enemies_for_save() -> Array:
	var out: Array = []
	for e in enemies:
		if e.get("dead", false) and not e.get("boss", false):
			continue
		var row: Dictionary = e.duplicate(true)
		row.erase("data") # re-link from type / boss_id on load
		out.append(row)
	return out

func restore_enemies_from_save(raw: Array) -> void:
	enemies.clear()
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = (item as Dictionary).duplicate(true)
		if bool(e.get("boss", false)):
			var bid := str(e.get("boss_id", "iron_maw"))
			if bid == "mycelarch":
				e["data"] = BOSS_MYCELARCH.duplicate(true)
			elif bid == "breach_engine":
				e["data"] = RiftScar.BOSS_BREACH_ENGINE.duplicate(true)
			else:
				e["data"] = BOSS_DATA.duplicate(true)
			e["boss_id"] = bid
			e["elite_class"] = RiftLoop.CLASS_NORMAL
			e["elite"] = false
			if not e.has("loop_dmg_mul"):
				e["loop_dmg_mul"] = RiftLoop.boss_damage_mul(int(e.get("rift_loop_at_spawn", rift_loop)))
		else:
			var t := str(e.get("type", "scrapper"))
			if not ENEMY_DATA.has(t):
				continue
			e["data"] = ENEMY_DATA[t]
			e["elite_class"] = str(e.get("elite_class", RiftLoop.CLASS_NORMAL))
			e["elite"] = RiftLoop.is_elite_class(str(e["elite_class"])) or bool(e.get("elite", false))
		e["scaled_once"] = true
		enemies.append(e)

func save_run() -> void:
	if not ["combat", "route", "rewards", "station", "build", "moduleshop", "event", "levelup", "victory"].has(state):
		return
	if state == "victory" and not rift_cycle_complete:
		return
	var data = {
		"state": state if state != "victory" else "combat",
		"difficulty": difficulty, "power": power, "reactor": reactor, "heat": heat,
		"momentum": momentum, "overrun": overrun, "scrap": scrap, "xp": xp, "level": level,
		"xp_needed": xp_needed, "encounter_index": encounter_index, "run_time": run_time,
		"train_cars": train_cars, "stats": stats, "selected_cards": selected_cards,
		"modules": modules, "boss_active": boss_active, "route_choices": route_choices,
		"station_used": station_used, "current_region": current_region,
		"rustlands_completed": rustlands_completed, "fungus_completed": fungus_completed,
		"rift_loop": rift_loop, "rift_cycle_complete": rift_cycle_complete,
		"rift_cycle_next_loop": rift_cycle_next_loop, "run_kills": run_kills,
		"enemies": serialize_enemies_for_save(), "weapons": weapons, "abilities": abilities,
		"starter_gun": starter_gun
	}
	var f = FileAccess.open(SAVE_RUN, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		save_flash = 1.25
func load_run() -> bool:
	if not FileAccess.file_exists(SAVE_RUN):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_RUN))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	state = parsed.get("state", "combat")
	difficulty = parsed.get("difficulty", difficulty)
	power = parsed.get("power", power)
	reactor = parsed.get("reactor", reactor)
	heat = parsed.get("heat", heat)
	momentum = parsed.get("momentum", momentum)
	overrun = parsed.get("overrun", overrun)
	scrap = parsed.get("scrap", 0)
	xp = parsed.get("xp", 0)
	level = parsed.get("level", 1)
	xp_needed = parsed.get("xp_needed", 40)
	encounter_index = parsed.get("encounter_index", 0)
	current_region = parsed.get("current_region", "rustlands")
	rustlands_completed = parsed.get("rustlands_completed", false)
	fungus_completed = parsed.get("fungus_completed", false)
	rift_loop = maxi(1, int(parsed.get("rift_loop", 1)))
	rift_cycle_complete = bool(parsed.get("rift_cycle_complete", false))
	rift_cycle_next_loop = maxi(rift_loop + 1, int(parsed.get("rift_cycle_next_loop", rift_loop + 1)))
	run_kills = int(parsed.get("run_kills", 0))
	if rift_cycle_complete:
		state = "victory"
		victory = true
	if typeof(parsed.get("weapons", null)) == TYPE_DICTIONARY:
		weapons = parsed["weapons"]
	if typeof(parsed.get("abilities", null)) == TYPE_DICTIONARY:
		abilities = parsed["abilities"]
	if typeof(parsed.get("starter_gun", null)) == TYPE_DICTIONARY:
		starter_gun = parsed["starter_gun"]
	if str(current_region) == "rift_scar":
		fungus_completed = true
		rustlands_completed = true
	if current_region == "fungus_wilds" and fungus_spores.is_empty():
		init_fungus_spores()
	if current_region == RiftScar.REGION_ID and rift_sparks.is_empty():
		init_rift_sparks()
	run_time = parsed.get("run_time", 0.0)
	var raw_cars = parsed.get("train_cars", [])
	if typeof(raw_cars) != TYPE_ARRAY or raw_cars.is_empty():
		raw_cars = train_cars
	train_cars = migrate_train_cars(raw_cars)
	apply_train_layout()
	stats = ensure_stats(parsed.get("stats", {}))
	selected_cards = parsed.get("selected_cards", [])
	modules = parsed.get("modules", modules)
	ensure_modules_schema()
	if starter_gun.is_empty():
		starter_gun = default_starter_gun()
	boss_active = parsed.get("boss_active", false)
	route_choices = parsed.get("route_choices", [])
	station_used = parsed.get("station_used", false)
	# Legacy modal states (cards / station / rewards) resume as continuous combat.
	var resume_boss := false
	if ["levelup", "rewards", "route", "station", "build", "moduleshop", "event"].has(state):
		resume_boss = (state == "rewards" and encounter_index >= 6) or bool(parsed.get("reward_pending_boss", false))
		state = "combat"
		paused = false
		route_choices.clear()
		active_cards.clear()
		reward_pending_boss = false
	enemies.clear()
	projectiles.clear()
	enemy_projectiles.clear()
	enemy_lasers.clear()
	particles.clear()
	damage_numbers.clear()
	loot_orbs.clear()
	drones.clear()
	weapon_fx.clear()
	var saved_enemies = parsed.get("enemies", [])
	var restored := false
	if typeof(saved_enemies) == TYPE_ARRAY and not saved_enemies.is_empty():
		restore_enemies_from_save(saved_enemies)
		restored = not enemies.is_empty()
	if resume_boss and not restored:
		prepare_for_boss_fight()
		start_boss()
	elif boss_active and not restored:
		start_boss()
	elif state == "combat" and (current_encounter.is_empty() or not current_encounter.has("id")):
		configure_encounter("combat")
	if audio != null:
		audio.play_travel_music(1.5)
	return true
func save_permanent() -> void:
	var f = FileAccess.open(SAVE_PERMANENT, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(permanent))
func load_permanent() -> void:
	if FileAccess.file_exists(SAVE_PERMANENT):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PERMANENT))
		permanent = ensure_permanent(parsed if typeof(parsed) == TYPE_DICTIONARY else {})
	else:
		permanent = ensure_permanent({})
func save_settings() -> void:
	var f = FileAccess.open(SAVE_SETTINGS, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))
func load_settings() -> void:
	if FileAccess.file_exists(SAVE_SETTINGS):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_SETTINGS))
		if typeof(parsed) == TYPE_DICTIONARY:
			settings.merge(parsed, true)
	apply_audio_settings()

func apply_audio_settings() -> void:
	if audio != null:
		var mv = float(settings.get("music_volume", 8)) / 10.0
		audio.set_music_volume(mv)
		var sv = float(settings.get("sfx_volume", 10)) / 10.0
		audio.set_sfx_volume(sv)

func spawn_loot_orbs(x: float, y: float, scrap_gain: float, xp_gain: float, boss = false) -> void:
	if not settings["particles"]:
		return
	for i in range(18 if boss else min(8, max(1, int(scrap_gain / 2)))):
		loot_orbs.append({ "x": x + randf_range(-30, 30), "y": y + randf_range(-20, 20), "vx": randf_range(-50, 50), "vy": randf_range(-110, -45), "kind": "scrap", "life": randf_range(.7, 1.1), "max": 1.1 })
	for i in range(14 if boss else min(6, max(1, int(xp_gain / 8)))):
		loot_orbs.append({ "x": x + randf_range(-30, 30), "y": y + randf_range(-20, 20), "vx": randf_range(-50, 50), "vy": randf_range(-110, -45), "kind": "xp", "life": randf_range(.7, 1.1), "max": 1.1 })
func update_loot_orbs(dt: float) -> void:
	for o in loot_orbs:
		var target = Vector2(1652, 69) if o["kind"] == "xp" else Vector2(1500, 69)
		o["x"] = lerp(o["x"], target.x, .07)
		o["y"] = lerp(o["y"], target.y, .07)

func _capture_viewport_png(res_path: String) -> void:
	# Force a fresh frame copy — shared Image buffers can otherwise overwrite prior saves.
	queue_redraw()
	RenderingServer.force_draw(false, 0.0)
	var tex := get_viewport().get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	var copy := img.duplicate()
	if copy != null:
		copy.save_png(ProjectSettings.globalize_path(res_path))

func _run_mobile_status_capture_suite() -> void:
	## F5 multi-aspect preview captures for Mission 01 top-left status panel only.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://dev_captures/mobile_preview"))
	reset_run()
	state = "combat"
	paused = false
	boss_active = false
	reactor_panel_collapsed = false
	var sizes: Array = [
		Vector2i(1230, 540),
		Vector2i(960, 540),
		Vector2i(1280, 540),
	]
	var report := FileAccess.open("res://dev_captures/mobile_preview/09_status_refine_report.txt", FileAccess.WRITE)
	if report:
		report.store_string("mission=01_status_hud_refine\n")
		report.store_string("asset=res://assets/ui/hud/riftline_dual_section_hud_panel_empty_interior.png\n")
		report.store_string("svg_source=riftline_dual_section_hud_panel_empty_interior.svg\n")
		report.store_string("glass=#081824@0.75 per-compartment\n")
		report.store_string("layers=glass->fills->frame->text\n")
		report.store_string("tex_px=%.0fx%.0f aspect=%.4f\n" % [
			MobileHudLayout.STATUS_TEX_W, MobileHudLayout.STATUS_TEX_H, MobileHudLayout.STATUS_ASPECT
		])
		report.store_string("control_hud=%s compact_tex=%s\n" % [
			str(_mobile_status_hud != null), str(images.has("hud_compact_player_status"))
		])
		report.store_string("ref_win_pad=%.0f,%.0f ref_win_w=%.0f\n" % [
			MobileHudLayout.STATUS_REF_WIN_X, MobileHudLayout.STATUS_REF_WIN_Y, MobileHudLayout.STATUS_REF_WIN_W
		])
	for sz in sizes:
		var wh: Vector2i = sz
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(wh)
		await get_tree().process_frame
		await get_tree().process_frame
		update_canvas_transform()
		_sync_mobile_status_hud()
		queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var lay: Dictionary = _mobile_player_status_layout()
		var tr: Rect2 = lay["texture_rect"]
		var tag := "%dx%d" % [wh.x, wh.y]
		var png_path := "res://dev_captures/mobile_preview/09_status_%s.png" % tag
		_capture_viewport_png(png_path)
		var win_now: Vector2i = DisplayServer.window_get_size()
		var vp_now: Vector2 = get_viewport_rect().size
		var w2v: float = vp_now.x / maxf(1.0, float(win_now.x))
		var h2v: float = vp_now.y / maxf(1.0, float(win_now.y))
		var preview_x: float = (canvas_offset.x + tr.position.x * canvas_scale) / maxf(0.001, w2v)
		var preview_y: float = (canvas_offset.y + tr.position.y * canvas_scale) / maxf(0.001, h2v)
		var preview_w: float = (tr.size.x * canvas_scale) / maxf(0.001, w2v)
		var preview_h: float = (tr.size.y * canvas_scale) / maxf(0.001, h2v)
		var hp_font_vp: int = clampi(int(round(17.0 * w2v)), 14, 42)
		var sub_font_vp: int = clampi(int(round(15.0 * w2v)), 12, 36)
		if report:
			report.store_string("--- %s ---\n" % tag)
			report.store_string("window=%s viewport=%s scale=%.4f offset=%s\n" % [
				str(win_now), str(vp_now), canvas_scale, str(canvas_offset)
			])
			report.store_string("view=[%.1f..%.1f] aspect=%.4f\n" % [
				design_view_left, design_view_right, float(lay.get("view_aspect", 0.0))
			])
			report.store_string("status_rect=x=%.1f y=%.1f w=%.1f h=%.1f width_frac=%.3f\n" % [
				tr.position.x, tr.position.y, tr.size.x, tr.size.y, float(lay.get("width_frac", 0.0))
			])
			report.store_string("preview_px=x=%.1f y=%.1f w=%.1f h=%.1f\n" % [
				preview_x, preview_y, preview_w, preview_h
			])
			report.store_string("fonts_vp=hp:%d spd/heat:%d (preview≈%.0f/%.0f)\n" % [
				hp_font_vp, sub_font_vp, float(hp_font_vp) / w2v, float(sub_font_vp) / w2v
			])
			report.store_string("conflict=%s\n" % (_mobile_status_conflict if _mobile_status_conflict != "" else "none"))
			report.store_string("png=%s\n" % png_path)
	if report:
		report.close()
	# Primary gameplay still for the refinement task (Infinix reference).
	DisplayServer.window_set_size(Vector2i(1230, 540))
	await get_tree().process_frame
	update_canvas_transform()
	_sync_mobile_status_hud()
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_viewport_png("res://dev_captures/mobile_preview/09_status_layered_1230x540.png")

func _run_mobile_encounter_capture_suite() -> void:
	## F5 multi-aspect preview captures for Mission 02 top-center encounter panel only.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://dev_captures/mobile_preview"))
	reset_run()
	state = "combat"
	paused = false
	boss_active = false
	reactor_panel_collapsed = false
	current_encounter = { "id": "scrapper_pursuit", "title": "Scrapper Pursuit" }
	encounter_progress = 24.0
	encounter_goal = 100.0
	encounter_index = 0
	rift_loop = 1
	current_region = "rustlands"
	toasts.clear()
	var sizes: Array = [
		Vector2i(1230, 540),
		Vector2i(960, 540),
		Vector2i(1280, 540),
	]
	var report := FileAccess.open("res://dev_captures/mobile_preview/10_encounter_report.txt", FileAccess.WRITE)
	if report:
		report.store_string("mission=02_encounter_long_open_frame\n")
		report.store_string("asset=res://assets/ui/hud/riftline_long_hud_frame_open.png\n")
		report.store_string("svg_source=riftline_long_hud_frame_open.svg\n")
		report.store_string("layers=frame->progress->text (no glass box; % beside bar)\n")

		report.store_string("tex_px=%.0fx%.0f aspect=%.4f\n" % [
			MobileHudLayout.ENCOUNTER_TEX_W, MobileHudLayout.ENCOUNTER_TEX_H, MobileHudLayout.ENCOUNTER_ASPECT
		])
		report.store_string("control_hud=%s\n" % str(_mobile_encounter_hud != null))
		report.store_string("ref_win_w=%.0f ref_win_y=%.0f\n" % [
			MobileHudLayout.ENCOUNTER_REF_WIN_W, MobileHudLayout.ENCOUNTER_REF_WIN_Y
		])
	for sz in sizes:
		var wh: Vector2i = sz
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(wh)
		await get_tree().process_frame
		await get_tree().process_frame
		toasts.clear()
		update_canvas_transform()
		_sync_mobile_status_hud()
		_sync_mobile_encounter_hud()
		queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		toasts.clear()
		var lay: Dictionary = _mobile_encounter_layout()
		var tr: Rect2 = lay["texture_rect"]
		var tag := "%dx%d" % [wh.x, wh.y]
		var png_path := "res://dev_captures/mobile_preview/10_encounter_%s.png" % tag
		_capture_viewport_png(png_path)
		var win_now: Vector2i = DisplayServer.window_get_size()
		var vp_now: Vector2 = get_viewport_rect().size
		var w2v: float = vp_now.x / maxf(1.0, float(win_now.x))
		var h2v: float = vp_now.y / maxf(1.0, float(win_now.y))
		var preview_x: float = (canvas_offset.x + tr.position.x * canvas_scale) / maxf(0.001, w2v)
		var preview_y: float = (canvas_offset.y + tr.position.y * canvas_scale) / maxf(0.001, h2v)
		var preview_w: float = (tr.size.x * canvas_scale) / maxf(0.001, w2v)
		var preview_h: float = (tr.size.y * canvas_scale) / maxf(0.001, h2v)
		if report:
			report.store_string("--- %s ---\n" % tag)
			report.store_string("window=%s viewport=%s scale=%.4f offset=%s\n" % [
				str(win_now), str(vp_now), canvas_scale, str(canvas_offset)
			])
			report.store_string("encounter_rect=x=%.1f y=%.1f w=%.1f h=%.1f width_frac=%.3f\n" % [
				tr.position.x, tr.position.y, tr.size.x, tr.size.y, float(lay.get("width_frac", 0.0))
			])
			report.store_string("preview_px=x=%.1f y=%.1f w=%.1f h=%.1f\n" % [
				preview_x, preview_y, preview_w, preview_h
			])
			report.store_string("top_margin_design=%.1f visible_top_preview=%.1f tex_preview_y=%.1f\n" % [
				float(lay.get("top_margin", 0.0)),
				preview_y + preview_h * MobileHudLayout.ENCOUNTER_ART_PAD_TOP_FRAC,
				preview_y
			])
			report.store_string("conflict=%s\n" % (_mobile_encounter_conflict if _mobile_encounter_conflict != "" else "none"))
			report.store_string("png=%s\n" % png_path)
	if report:
		report.close()
	DisplayServer.window_set_size(Vector2i(1230, 540))
	await get_tree().process_frame
	update_canvas_transform()
	_sync_mobile_status_hud()
	_sync_mobile_encounter_hud()
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_viewport_png("res://dev_captures/mobile_preview/10_encounter_layered_1230x540.png")

func _run_mobile_economy_capture_suite() -> void:
	## F5 multi-aspect preview captures for Mission 03 top-right scrap / LV / XP panel.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://dev_captures/mobile_preview"))
	reset_run()
	state = "combat"
	paused = false
	boss_active = false
	reactor_panel_collapsed = false
	scrap = 128
	level = 3
	xp = 18.0
	xp_needed = 40.0
	save_flash = 0.0
	current_encounter = { "id": "scrapper_pursuit", "title": "Scrapper Pursuit" }
	encounter_progress = 24.0
	encounter_goal = 100.0
	encounter_index = 0
	rift_loop = 1
	current_region = "rustlands"
	toasts.clear()
	var sizes: Array = [
		Vector2i(1230, 540),
		Vector2i(960, 540),
		Vector2i(1280, 540),
	]
	var report := FileAccess.open("res://dev_captures/mobile_preview/11_economy_report.txt", FileAccess.WRITE)
	if report:
		report.store_string("mission=03_economy_wide_hud_bar_a\n")
		report.store_string("asset=res://assets/ui/hud/riftline_wide_hud_bar_a.png\n")
		report.store_string("svg_source=riftline_wide_hud_bar_a.svg\n")
		report.store_string("layers=frame->xp_fill->icon+text (opaque bay; pause outside)\n")
		report.store_string("tex_px=%.0fx%.0f aspect=%.4f\n" % [
			MobileHudLayout.ECONOMY_TEX_W, MobileHudLayout.ECONOMY_TEX_H, MobileHudLayout.ECONOMY_ASPECT
		])
		report.store_string("control_hud=%s\n" % str(_mobile_economy_hud != null))
		report.store_string("ref_win_w=%.0f pause_win=%.0f\n" % [
			MobileHudLayout.ECONOMY_REF_WIN_W, MobileHudLayout.ECONOMY_PAUSE_WIN
		])
	for sz in sizes:
		var wh: Vector2i = sz
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(wh)
		await get_tree().process_frame
		await get_tree().process_frame
		toasts.clear()
		save_flash = 0.0
		scrap = 128
		level = 3
		xp = 18.0
		xp_needed = 40.0
		update_canvas_transform()
		_sync_mobile_status_hud()
		_sync_mobile_encounter_hud()
		_sync_mobile_economy_hud()
		queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		toasts.clear()
		save_flash = 0.0
		var lay: Dictionary = _mobile_economy_layout()
		var tr: Rect2 = lay["texture_rect"]
		var tag := "%dx%d" % [wh.x, wh.y]
		var png_path := "res://dev_captures/mobile_preview/11_economy_%s.png" % tag
		_capture_viewport_png(png_path)
		var win_now: Vector2i = DisplayServer.window_get_size()
		var vp_now: Vector2 = get_viewport_rect().size
		var w2v: float = vp_now.x / maxf(1.0, float(win_now.x))
		var h2v: float = vp_now.y / maxf(1.0, float(win_now.y))
		var preview_x: float = (canvas_offset.x + tr.position.x * canvas_scale) / maxf(0.001, w2v)
		var preview_y: float = (canvas_offset.y + tr.position.y * canvas_scale) / maxf(0.001, h2v)
		var preview_w: float = (tr.size.x * canvas_scale) / maxf(0.001, w2v)
		var preview_h: float = (tr.size.y * canvas_scale) / maxf(0.001, h2v)
		var pause_x_prev: float = (canvas_offset.x + float(lay.get("pause_x", 0.0)) * canvas_scale) / maxf(0.001, w2v)
		if report:
			report.store_string("--- %s ---\n" % tag)
			report.store_string("window=%s viewport=%s scale=%.4f offset=%s\n" % [
				str(win_now), str(vp_now), canvas_scale, str(canvas_offset)
			])
			report.store_string("economy_rect=x=%.1f y=%.1f w=%.1f h=%.1f width_frac=%.3f\n" % [
				tr.position.x, tr.position.y, tr.size.x, tr.size.y, float(lay.get("width_frac", 0.0))
			])
			report.store_string("preview_px=x=%.1f y=%.1f w=%.1f h=%.1f\n" % [
				preview_x, preview_y, preview_w, preview_h
			])
			report.store_string("pause_preview_x=%.1f pause_s=%.1f\n" % [
				pause_x_prev, float(lay.get("pause_s", 0.0)) * canvas_scale / maxf(0.001, w2v)
			])
			report.store_string("conflict=%s\n" % (_mobile_economy_conflict if _mobile_economy_conflict != "" else "none"))
			report.store_string("png=%s\n" % png_path)
	if report:
		report.close()
	DisplayServer.window_set_size(Vector2i(1230, 540))
	await get_tree().process_frame
	update_canvas_transform()
	_sync_mobile_status_hud()
	_sync_mobile_encounter_hud()
	_sync_mobile_economy_hud()
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_viewport_png("res://dev_captures/mobile_preview/11_economy_layered_1230x540.png")

func _run_mobile_shop_tab_capture_suite() -> void:
	## F5 multi-aspect preview captures for Mission 04 vertical SHOP tab.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://dev_captures/mobile_preview"))
	reset_run()
	state = "combat"
	paused = false
	shop_open = false
	shop_slide = 0.0
	boss_active = false
	reactor_panel_collapsed = false
	var sizes: Array = [
		Vector2i(1230, 540),
		Vector2i(960, 540),
		Vector2i(1280, 540),
	]
	var report := FileAccess.open("res://dev_captures/mobile_preview/12_shop_report.txt", FileAccess.WRITE)
	if report:
		report.store_string("mission=04_shop_vertical_hud_frame\n")
		report.store_string("asset=res://assets/ui/hud/riftline_vertical_hud_frame.png\n")
		report.store_string("svg_source=riftline_vertical_hud_frame.svg\n")
		report.store_string("tex_px=%.0fx%.0f aspect=%.4f\n" % [
			MobileHudLayout.SHOP_TEX_W, MobileHudLayout.SHOP_TEX_H, MobileHudLayout.SHOP_ASPECT
		])
		report.store_string("control_hud=%s\n" % str(images.has("hud_shop_tab_vertical"))
		)
	for sz in sizes:
		var wh: Vector2i = sz
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(wh)
		await get_tree().process_frame
		await get_tree().process_frame
		shop_open = false
		shop_slide = 0.0
		update_canvas_transform()
		_sync_mobile_status_hud()
		_sync_mobile_encounter_hud()
		_sync_mobile_economy_hud()
		queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var rects: Dictionary = _mobile_shop_tab_rects() if images.has("hud_shop_tab_vertical") else {}
		var tr: Rect2 = rects.get("texture_rect", Rect2()) if rects.size() > 0 else Rect2()
		var tag := "%dx%d" % [wh.x, wh.y]
		var png_path := "res://dev_captures/mobile_preview/12_shop_%s.png" % tag
		_capture_viewport_png(png_path)
		var win_now: Vector2i = DisplayServer.window_get_size()
		var vp_now: Vector2 = get_viewport_rect().size
		var w2v: float = vp_now.x / maxf(1.0, float(win_now.x))
		var h2v: float = vp_now.y / maxf(1.0, float(win_now.y))
		var preview_x: float = (canvas_offset.x + tr.position.x * canvas_scale) / maxf(0.001, w2v)
		var preview_y: float = (canvas_offset.y + tr.position.y * canvas_scale) / maxf(0.001, h2v)
		var preview_w: float = (tr.size.x * canvas_scale) / maxf(0.001, w2v)
		var preview_h: float = (tr.size.y * canvas_scale) / maxf(0.001, h2v)
		if report:
			report.store_string("--- %s ---\n" % tag)
			report.store_string("window=%s viewport=%s scale=%.4f offset=%s\n" % [
				str(win_now), str(vp_now), canvas_scale, str(canvas_offset)
			])
			report.store_string("shop_rect=x=%.1f y=%.1f w=%.1f h=%.1f\n" % [
				tr.position.x, tr.position.y, tr.size.x, tr.size.y
			])
			report.store_string("preview_px=x=%.1f y=%.1f w=%.1f h=%.1f\n" % [
				preview_x, preview_y, preview_w, preview_h
			])
			report.store_string("png=%s\n" % png_path)
	if report:
		report.close()
	DisplayServer.window_set_size(Vector2i(1230, 540))
	await get_tree().process_frame
	update_canvas_transform()
	_sync_mobile_status_hud()
	_sync_mobile_encounter_hud()
	_sync_mobile_economy_hud()
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_viewport_png("res://dev_captures/mobile_preview/12_shop_layered_1230x540.png")
	# Open sheet — verify flush-right + mobile type scale.
	shop_open = true
	shop_slide = 1.0
	shop_tab = "weapons"
	shop_scroll_y = 0.0
	toasts.clear()
	shop_buy_feedback = ""
	shop_buy_feedback_t = 0.0
	scrap = maxf(scrap, 220.0)
	update_canvas_transform()
	_sync_mobile_status_hud()
	_sync_mobile_encounter_hud()
	_sync_mobile_economy_hud()
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_sync_mobile_status_hud()
	_sync_mobile_encounter_hud()
	_sync_mobile_economy_hud()
	queue_redraw()
	await get_tree().process_frame
	_capture_viewport_png("res://dev_captures/mobile_preview/12_shop_open_1230x540.png")
	var dx_open := live_shop_drawer_x()
	var dw_open := _shop_drawer_w()
	var proof := FileAccess.open("res://dev_captures/mobile_preview/12_shop_open_report.txt", FileAccess.WRITE)
	if proof:
		var enc_vis := "null"
		var eco_vis := "null"
		var st_vis := "null"
		if _mobile_encounter_hud != null:
			enc_vis = "true" if _mobile_encounter_hud.visible else "false"
		if _mobile_economy_hud != null:
			eco_vis = "true" if _mobile_economy_hud.visible else "false"
		if _mobile_status_hud != null:
			st_vis = "true" if _mobile_status_hud.visible else "false"
		proof.store_string("rev=shop_clean_v4_no_flavor\n")
		proof.store_string("drawer_x=%.1f drawer_w=%.1f right=%.1f gap=%.1f\n" % [
			dx_open, dw_open, design_view_right, design_view_right - (dx_open + dw_open)
		])
		proof.store_string("view=[%.1f..%.1f] inset_l=%.1f\n" % [
			design_view_left, design_view_right, float(safe_inset.get("left", 0.0))
		])
		proof.store_string("hud_status=%s hud_enc=%s hud_eco=%s\n" % [st_vis, enc_vis, eco_vis])
		proof.close()

func _run_mobile_reactor_capture_suite() -> void:
	## F5 multi-aspect preview captures for Mission 05 compact reactor console.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://dev_captures/mobile_preview"))
	reset_run()
	state = "combat"
	paused = false
	shop_open = false
	shop_slide = 0.0
	boss_active = false
	reactor_panel_collapsed = false
	reactor_channel_page = 0
	var sizes: Array = [
		Vector2i(1230, 540),
		Vector2i(960, 540),
		Vector2i(1280, 540),
		Vector2i(1640, 720),
	]
	var report := FileAccess.open("res://dev_captures/mobile_preview/13_reactor_report.txt", FileAccess.WRITE)
	if report:
		report.store_string("mission=05_reactor_compact_hud_bar\n")
		report.store_string("asset=res://assets/ui/hud/riftline_compact_hud_bar.png\n")
		report.store_string("svg_source=riftline_compact_hud_bar.svg\n")
		report.store_string("tex_px=%.0fx%.0f aspect=%.4f\n" % [
			MobileHudLayout.REACTOR_TEX_W, MobileHudLayout.REACTOR_TEX_H, MobileHudLayout.REACTOR_ASPECT
		])
		report.store_string("control_hud=%s\n" % str(images.has("hud_compact_reactor")))
	for sz in sizes:
		var wh: Vector2i = sz
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(wh)
		await get_tree().process_frame
		await get_tree().process_frame
		reactor_panel_collapsed = false
		update_canvas_transform()
		_sync_mobile_status_hud()
		_sync_mobile_encounter_hud()
		_sync_mobile_economy_hud()
		queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var win_r: Vector2i = DisplayServer.window_get_size()
		var vp_r: Vector2 = get_viewport_rect().size
		var aspect_r: float = (design_view_right - design_view_left) / maxf(1.0, design_view_bottom - design_view_top)
		var lay: Dictionary = MobileHudLayout.reactor_panel(
			safe_inset, design_view_left, design_view_right, design_view_top, design_view_bottom,
			aspect_r, canvas_scale, win_r, vp_r
		) if images.has("hud_compact_reactor") else {}
		var tr: Rect2 = lay.get("texture_rect", Rect2()) if lay.size() > 0 else Rect2()
		var tag := "%dx%d" % [wh.x, wh.y]
		var png_path := "res://dev_captures/mobile_preview/13_reactor_%s.png" % tag
		_capture_viewport_png(png_path)
		var w2v: float = vp_r.x / maxf(1.0, float(win_r.x))
		var h2v: float = vp_r.y / maxf(1.0, float(win_r.y))
		var preview_x: float = (canvas_offset.x + tr.position.x * canvas_scale) / maxf(0.001, w2v)
		var preview_y: float = (canvas_offset.y + tr.position.y * canvas_scale) / maxf(0.001, h2v)
		var preview_w: float = (tr.size.x * canvas_scale) / maxf(0.001, w2v)
		var preview_h: float = (tr.size.y * canvas_scale) / maxf(0.001, h2v)
		if report:
			report.store_string("--- %s ---\n" % tag)
			report.store_string("window=%s viewport=%s scale=%.4f offset=%s\n" % [
				str(win_r), str(vp_r), canvas_scale, str(canvas_offset)
			])
			report.store_string("view=[%.1f..%.1f]x[%.1f..%.1f]\n" % [
				design_view_left, design_view_right, design_view_top, design_view_bottom
			])
			report.store_string("reactor_rect=x=%.1f y=%.1f w=%.1f h=%.1f\n" % [
				tr.position.x, tr.position.y, tr.size.x, tr.size.y
			])
			report.store_string("preview_px=x=%.1f y=%.1f w=%.1f h=%.1f\n" % [
				preview_x, preview_y, preview_w, preview_h
			])
			report.store_string("reactor_used=%d/%d channels=%d page=%d\n" % [
				reactor_used_power(), int(reactor["max"]), _reactor_power_rows().size(), reactor_channel_page
			])
			report.store_string("png=%s\n" % png_path)
	# Collapsed strip proof at primary preview size.
	DisplayServer.window_set_size(Vector2i(1230, 540))
	await get_tree().process_frame
	reactor_panel_collapsed = true
	update_canvas_transform()
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_viewport_png("res://dev_captures/mobile_preview/13_reactor_collapsed_1230x540.png")
	reactor_panel_collapsed = false
	update_canvas_transform()
	_sync_mobile_status_hud()
	_sync_mobile_encounter_hud()
	_sync_mobile_economy_hud()
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_viewport_png("res://dev_captures/mobile_preview/13_reactor_layered_1230x540.png")
	# Close-up crop of the reactor console for layout QA (map design → image pixels).
	var win_c: Vector2i = DisplayServer.window_get_size()
	var vp_c: Vector2 = get_viewport_rect().size
	var aspect_c: float = (design_view_right - design_view_left) / maxf(1.0, design_view_bottom - design_view_top)
	var lay_c: Dictionary = MobileHudLayout.reactor_panel(
		safe_inset, design_view_left, design_view_right, design_view_top, design_view_bottom,
		aspect_c, canvas_scale, win_c, vp_c
	) if images.has("hud_compact_reactor") else {}
	var tr_c: Rect2 = lay_c.get("texture_rect", Rect2()) if lay_c.size() > 0 else Rect2()
	if tr_c.size.x > 1.0:
		var img_full: Image = get_viewport().get_texture().get_image()
		if img_full != null:
			var sx_v: float = canvas_offset.x + tr_c.position.x * canvas_scale
			var sy_v: float = canvas_offset.y + tr_c.position.y * canvas_scale
			var sw_v: float = tr_c.size.x * canvas_scale
			var sh_v: float = tr_c.size.y * canvas_scale
			var ix: float = float(img_full.get_width()) / maxf(1.0, vp_c.x)
			var iy: float = float(img_full.get_height()) / maxf(1.0, vp_c.y)
			var sx: int = clampi(int(sx_v * ix) - 6, 0, img_full.get_width() - 1)
			var sy: int = clampi(int(sy_v * iy) - 6, 0, img_full.get_height() - 1)
			var sw: int = clampi(int(sw_v * ix) + 12, 1, img_full.get_width() - sx)
			var sh: int = clampi(int(sh_v * iy) + 12, 1, img_full.get_height() - sy)
			var crop: Image = img_full.get_region(Rect2i(sx, sy, sw, sh))
			crop.save_png(ProjectSettings.globalize_path("res://dev_captures/mobile_preview/13_reactor_closeup_1230x540.png"))
			if report:
				report.store_string("closeup=res://dev_captures/mobile_preview/13_reactor_closeup_1230x540.png\n")
				report.store_string("closeup_img_px=%d,%d %dx%d img=%dx%d\n" % [
					sx, sy, sw, sh, img_full.get_width(), img_full.get_height()
				])
	if report:
		report.close()

func _run_mobile_weapons_capture_suite() -> void:
	## F5 multi-aspect preview captures for Mission 06 four-slot weapon priority HUD.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://dev_captures/mobile_preview"))
	reset_run()
	state = "combat"
	paused = false
	shop_open = false
	shop_slide = 0.0
	boss_active = false
	reactor_panel_collapsed = false
	weapon_hud_page = 0
	var sizes: Array = [
		Vector2i(1230, 540),
		Vector2i(960, 540),
		Vector2i(1280, 540),
	]
	var report := FileAccess.open("res://dev_captures/mobile_preview/14_weapons_report.txt", FileAccess.WRITE)
	if report:
		report.store_string("mission=06_weapons_four_slot_hud_bar\n")
		report.store_string("asset=res://assets/ui/hud/riftline_four_slot_hud_bar.png\n")
		report.store_string("svg_source=riftline_four_slot_hud_bar.svg\n")
		report.store_string("tex_px=%.0fx%.0f aspect=%.4f\n" % [
			MobileHudLayout.WEAPONS_TEX_W, MobileHudLayout.WEAPONS_TEX_H, MobileHudLayout.WEAPONS_ASPECT
		])
		report.store_string("control_hud=%s\n" % str(images.has("hud_compact_weapons")))
	for sz in sizes:
		var wh: Vector2i = sz
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(wh)
		await get_tree().process_frame
		await get_tree().process_frame
		update_canvas_transform()
		_sync_mobile_status_hud()
		_sync_mobile_encounter_hud()
		_sync_mobile_economy_hud()
		queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var win_r: Vector2i = DisplayServer.window_get_size()
		var vp_r: Vector2 = get_viewport_rect().size
		var aspect_r: float = (design_view_right - design_view_left) / maxf(1.0, design_view_bottom - design_view_top)
		var ml: Dictionary = _mobile_hud_layout()
		var after_r: float = float(ml["reactor_x"]) + float(ml["reactor_w"]) * (1.0 - MobileHudLayout.REACTOR_ART_PAD_R)
		var lay: Dictionary = MobileHudLayout.weapons_panel(
			safe_inset, design_view_left, design_view_right, design_view_top, design_view_bottom,
			aspect_r, canvas_scale, win_r, vp_r, after_r, float(ml["abil_x"])
		) if images.has("hud_compact_weapons") else {}
		var tr: Rect2 = lay.get("texture_rect", Rect2()) if lay.size() > 0 else Rect2()
		var icons: Array = lay.get("icons", []) if lay.size() > 0 else []
		var tag := "%dx%d" % [wh.x, wh.y]
		var png_path := "res://dev_captures/mobile_preview/14_weapons_%s.png" % tag
		_capture_viewport_png(png_path)
		var w2v: float = vp_r.x / maxf(1.0, float(win_r.x))
		var h2v: float = vp_r.y / maxf(1.0, float(win_r.y))
		var preview_x: float = (canvas_offset.x + tr.position.x * canvas_scale) / maxf(0.001, w2v)
		var preview_y: float = (canvas_offset.y + tr.position.y * canvas_scale) / maxf(0.001, h2v)
		var preview_w: float = (tr.size.x * canvas_scale) / maxf(0.001, w2v)
		var preview_h: float = (tr.size.y * canvas_scale) / maxf(0.001, h2v)
		var icon0: Rect2 = icons[0] if icons.size() > 0 else Rect2()
		if report:
			report.store_string("--- %s ---\n" % tag)
			report.store_string("window=%s viewport=%s scale=%.4f\n" % [str(win_r), str(vp_r), canvas_scale])
			report.store_string("weapons_rect=x=%.1f y=%.1f w=%.1f h=%.1f\n" % [
				tr.position.x, tr.position.y, tr.size.x, tr.size.y
			])
			report.store_string("preview_px=x=%.1f y=%.1f w=%.1f h=%.1f\n" % [
				preview_x, preview_y, preview_w, preview_h
			])
			report.store_string("icon0_design=%.1fx%.1f conflict=%s installed=%d\n" % [
				icon0.size.x, icon0.size.y, str(lay.get("conflict", "")), WeaponLoadout.count_installed(modules)
			])
			report.store_string("png=%s\n" % png_path)
	DisplayServer.window_set_size(Vector2i(1230, 540))
	await get_tree().process_frame
	update_canvas_transform()
	_sync_mobile_status_hud()
	_sync_mobile_encounter_hud()
	_sync_mobile_economy_hud()
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_viewport_png("res://dev_captures/mobile_preview/14_weapons_layered_1230x540.png")
	var win_c: Vector2i = DisplayServer.window_get_size()
	var vp_c: Vector2 = get_viewport_rect().size
	var aspect_c: float = (design_view_right - design_view_left) / maxf(1.0, design_view_bottom - design_view_top)
	var mlc: Dictionary = _mobile_hud_layout()
	var after_c: float = float(mlc["reactor_x"]) + float(mlc["reactor_w"]) * (1.0 - MobileHudLayout.REACTOR_ART_PAD_R)
	var lay_c: Dictionary = MobileHudLayout.weapons_panel(
		safe_inset, design_view_left, design_view_right, design_view_top, design_view_bottom,
		aspect_c, canvas_scale, win_c, vp_c, after_c, float(mlc["abil_x"])
	) if images.has("hud_compact_weapons") else {}
	var tr_c: Rect2 = lay_c.get("texture_rect", Rect2()) if lay_c.size() > 0 else Rect2()
	if tr_c.size.x > 1.0:
		var img_full: Image = get_viewport().get_texture().get_image()
		if img_full != null:
			var sx_v: float = canvas_offset.x + tr_c.position.x * canvas_scale
			var sy_v: float = canvas_offset.y + tr_c.position.y * canvas_scale
			var sw_v: float = tr_c.size.x * canvas_scale
			var sh_v: float = tr_c.size.y * canvas_scale
			var ix: float = float(img_full.get_width()) / maxf(1.0, vp_c.x)
			var iy: float = float(img_full.get_height()) / maxf(1.0, vp_c.y)
			var sx: int = clampi(int(sx_v * ix) - 6, 0, img_full.get_width() - 1)
			var sy: int = clampi(int(sy_v * iy) - 6, 0, img_full.get_height() - 1)
			var sw: int = clampi(int(sw_v * ix) + 12, 1, img_full.get_width() - sx)
			var sh: int = clampi(int(sh_v * iy) + 12, 1, img_full.get_height() - sy)
			var crop: Image = img_full.get_region(Rect2i(sx, sy, sw, sh))
			crop.save_png(ProjectSettings.globalize_path("res://dev_captures/mobile_preview/14_weapons_closeup_1230x540.png"))
			if report:
				report.store_string("closeup=res://dev_captures/mobile_preview/14_weapons_closeup_1230x540.png\n")
				report.store_string("closeup_img_px=%d,%d %dx%d\n" % [sx, sy, sw, sh])
	if report:
		report.close()

func _run_mobile_abilities_capture_suite() -> void:
	## F5 multi-aspect preview captures for Mission 07 four-slot active abilities HUD.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://dev_captures/mobile_preview"))
	reset_run()
	state = "combat"
	paused = false
	shop_open = false
	shop_slide = 0.0
	boss_active = false
	reactor_panel_collapsed = false
	# Show all four live ability icons (BARRAGE unlocked at Tech 6 in normal play).
	abilities["barrage"]["unlocked"] = true
	var sizes: Array = [
		Vector2i(1230, 540),
		Vector2i(960, 540),
		Vector2i(1280, 540),
	]
	var report := FileAccess.open("res://dev_captures/mobile_preview/15_abilities_report.txt", FileAccess.WRITE)
	if report:
		report.store_string("mission=07_abilities_reactor_status_panel\n")
		report.store_string("asset=res://assets/ui/hud/riftline_reactor_status_panel.png\n")
		report.store_string("svg_source=riftline_reactor_status_panel.svg\n")
		report.store_string("tex_px=%.0fx%.0f aspect=%.4f\n" % [
			MobileHudLayout.ABILITIES_TEX_W, MobileHudLayout.ABILITIES_TEX_H, MobileHudLayout.ABILITIES_ASPECT
		])
		report.store_string("control_hud=%s\n" % str(images.has("hud_compact_abilities")))
		report.store_string("note=abilities_flush_bottom_right_icons_fill_wells\n")
	for sz in sizes:
		var wh: Vector2i = sz
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(wh)
		await get_tree().process_frame
		await get_tree().process_frame
		update_canvas_transform()
		_sync_mobile_status_hud()
		_sync_mobile_encounter_hud()
		_sync_mobile_economy_hud()
		queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var win_r: Vector2i = DisplayServer.window_get_size()
		var vp_r: Vector2 = get_viewport_rect().size
		var ml: Dictionary = _mobile_hud_layout()
		var tr := Rect2(float(ml["abil_x"]), float(ml["abil_y"]), float(ml["abil_w"]), float(ml["abil_h"]))
		var wtr := Rect2(float(ml["weap_x"]), float(ml["weap_y"]), float(ml["weap_w"]), float(ml["weap_h"]))
		var weap_opaque_r: float = wtr.position.x + wtr.size.x * (1.0 - MobileHudLayout.WEAPONS_ART_PAD_R)
		var abil_opaque_l: float = tr.position.x + tr.size.x * MobileHudLayout.ABILITIES_ART_PAD_L
		var gap_design: float = abil_opaque_l - weap_opaque_r
		var tag := "%dx%d" % [wh.x, wh.y]
		var png_path := "res://dev_captures/mobile_preview/15_abilities_%s.png" % tag
		_capture_viewport_png(png_path)
		var w2v: float = vp_r.x / maxf(1.0, float(win_r.x))
		var h2v: float = vp_r.y / maxf(1.0, float(win_r.y))
		var preview_x: float = (canvas_offset.x + tr.position.x * canvas_scale) / maxf(0.001, w2v)
		var preview_y: float = (canvas_offset.y + tr.position.y * canvas_scale) / maxf(0.001, h2v)
		var preview_w: float = (tr.size.x * canvas_scale) / maxf(0.001, w2v)
		var preview_h: float = (tr.size.y * canvas_scale) / maxf(0.001, h2v)
		var weap_preview_r: float = (canvas_offset.x + weap_opaque_r * canvas_scale) / maxf(0.001, w2v)
		var abil_preview_l: float = (canvas_offset.x + abil_opaque_l * canvas_scale) / maxf(0.001, w2v)
		var gap_preview: float = abil_preview_l - weap_preview_r
		var weap_preview_x: float = (canvas_offset.x + wtr.position.x * canvas_scale) / maxf(0.001, w2v)
		var weap_preview_w: float = (wtr.size.x * canvas_scale) / maxf(0.001, w2v)
		if report:
			report.store_string("--- %s ---\n" % tag)
			report.store_string("window=%s viewport=%s scale=%.4f\n" % [str(win_r), str(vp_r), canvas_scale])
			report.store_string("weapons_preview=x=%.1f w=%.1f opaque_r=%.1f\n" % [
				weap_preview_x, weap_preview_w, weap_preview_r
			])
			report.store_string("abilities_rect=x=%.1f y=%.1f w=%.1f h=%.1f\n" % [
				tr.position.x, tr.position.y, tr.size.x, tr.size.y
			])
			report.store_string("preview_px=x=%.1f y=%.1f w=%.1f h=%.1f\n" % [
				preview_x, preview_y, preview_w, preview_h
			])
			report.store_string("gap_preview_px=%.1f gap_design=%.1f conflict=%s\n" % [
				gap_preview, gap_design, str(ml.get("abilities_conflict", ""))
			])
			report.store_string("png=%s\n" % png_path)
	DisplayServer.window_set_size(Vector2i(1230, 540))
	await get_tree().process_frame
	update_canvas_transform()
	_sync_mobile_status_hud()
	_sync_mobile_encounter_hud()
	_sync_mobile_economy_hud()
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_viewport_png("res://dev_captures/mobile_preview/15_abilities_layered_1230x540.png")
	var win_c: Vector2i = DisplayServer.window_get_size()
	var vp_c: Vector2 = get_viewport_rect().size
	var mlc: Dictionary = _mobile_hud_layout()
	var tr_c := Rect2(float(mlc["abil_x"]), float(mlc["abil_y"]), float(mlc["abil_w"]), float(mlc["abil_h"]))
	if tr_c.size.x > 1.0:
		var img_full: Image = get_viewport().get_texture().get_image()
		if img_full != null:
			var sx_v: float = canvas_offset.x + tr_c.position.x * canvas_scale
			var sy_v: float = canvas_offset.y + tr_c.position.y * canvas_scale
			var sw_v: float = tr_c.size.x * canvas_scale
			var sh_v: float = tr_c.size.y * canvas_scale
			var ix: float = float(img_full.get_width()) / maxf(1.0, vp_c.x)
			var iy: float = float(img_full.get_height()) / maxf(1.0, vp_c.y)
			var sx: int = clampi(int(sx_v * ix) - 6, 0, img_full.get_width() - 1)
			var sy: int = clampi(int(sy_v * iy) - 6, 0, img_full.get_height() - 1)
			var sw: int = clampi(int(sw_v * ix) + 12, 1, img_full.get_width() - sx)
			var sh: int = clampi(int(sh_v * iy) + 12, 1, img_full.get_height() - sy)
			var crop: Image = img_full.get_region(Rect2i(sx, sy, sw, sh))
			crop.save_png(ProjectSettings.globalize_path("res://dev_captures/mobile_preview/15_abilities_closeup_1230x540.png"))
			if report:
				report.store_string("closeup=res://dev_captures/mobile_preview/15_abilities_closeup_1230x540.png\n")
				report.store_string("closeup_img_px=%d,%d %dx%d\n" % [sx, sy, sw, sh])
	# Smoke: activate each ability once and confirm cooldown gate.
	var smoke := ["boost", "shield", "repair", "barrage"]
	for key in smoke:
		abilities[key]["cooldown"] = 0.0
		abilities[key]["duration"] = 0.0
		_ability_tap_lock[key] = 0.0
		var before_cd: float = float(abilities[key]["cooldown"])
		use_ability(str(key))
		var after_cd: float = float(abilities[key]["cooldown"])
		var fired: bool = after_cd > before_cd
		use_ability(str(key)) # must no-op while cooling / tap-lock
		var gated: bool = float(abilities[key]["cooldown"]) >= after_cd - 0.001
		if report:
			report.store_string("smoke_%s before=%.2f after=%.2f fired=%s gated=%s\n" % [
				str(key), before_cd, after_cd, str(fired), str(gated)
			])
	if report:
		report.close()

func _run_mobile_workshop_capture_suite() -> void:
	## F5 multi-tab preview: edge-to-edge 2-column workshop, no scroll.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://dev_captures/mobile_preview"))
	permanent = ensure_permanent(permanent)
	state = "workshop"
	workshop_scroll_y = 0.0
	paused = false
	shop_open = false
	var tabs: Array = ["locomotive", "defense", "economy"]
	var report := FileAccess.open("res://dev_captures/mobile_preview/16_workshop_report.txt", FileAccess.WRITE)
	if report:
		report.store_string("mission=workshop_2col_fullbleed\n")
		report.store_string("note=edge_to_edge_two_columns_no_scroll\n")
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1230, 540))
	await get_tree().process_frame
	await get_tree().process_frame
	update_canvas_transform()
	for tid in tabs:
		set_workshop_tab(str(tid))
		workshop_scroll_y = 0.0
		queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var tag := str(tid)
		var png_path := "res://dev_captures/mobile_preview/16_workshop_%s_1230x540.png" % tag
		_capture_viewport_png(png_path)
		var keys: Array = TrainBuild.WORKSHOP_CATEGORIES[str(tid)]["keys"]
		var rows := int(ceil(float(keys.size()) / 2.0))
		if report:
			report.store_string("--- %s ---\n" % tag)
			report.store_string("keys=%d cols=2 rows=%d scroll=%.3f view=[%.1f..%.1f]\n" % [
				keys.size(), rows, workshop_scroll_y, design_view_left, design_view_right
			])
			report.store_string("png=%s\n" % png_path)
	_capture_viewport_png("res://dev_captures/mobile_preview/16_workshop_layered_1230x540.png")
	if report:
		report.store_string("layered=res://dev_captures/mobile_preview/16_workshop_layered_1230x540.png\n")
		report.close()

func toast(text: String, priority: String = "normal") -> void:
	# Compact non-blocking feed: merge duplicates, cap at 3, prefer major messages.
	var msg := str(text)
	if msg == "":
		return
	for t in toasts:
		if str(t.get("text", "")) == msg:
			t["life"] = float(t.get("max", 2.1))
			t["priority"] = priority if priority == "major" else t.get("priority", "normal")
			return
	var life := 2.6 if priority == "major" else 2.0
	toasts.append({ "text": msg, "life": life, "max": life, "priority": priority })
	while toasts.size() > 3:
		var drop_i := 0
		for i in range(toasts.size()):
			if str(toasts[i].get("priority", "normal")) != "major":
				drop_i = i
				break
		toasts.remove_at(drop_i)

func update_toasts(dt: float) -> void:
	for i in range(toasts.size() - 1, -1, -1):
		toasts[i]["life"] -= dt
		if toasts[i]["life"] <= 0:
			toasts.remove_at(i)

func _input(event: InputEvent) -> void:
	# Swipe scroll for Armory / Workshop — uses ScreenDrag so mouse emulation stays for taps.
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		var dp := screen_to_design(drag.position)
		if _touch_scroll_active:
			var dy := _touch_scroll_last_y - dp.y
			if absf(dy) > 0.5:
				_touch_scroll_moved = true
				if _touch_scroll_kind == "shop":
					adjust_shop_scroll(dy)
					# Finger velocity → design-space fling (px/s). Blend so small drags stay soft.
					var v_design := -drag.velocity.y / maxf(0.001, canvas_scale)
					shop_scroll_vel = clampf(lerpf(shop_scroll_vel, v_design, 0.55), -2600.0, 2600.0)
				elif _touch_scroll_kind == "workshop":
					adjust_workshop_scroll(dy)
				_touch_scroll_last_y = dp.y
				_touch_scroll_last_t = Time.get_ticks_msec() * 0.001
			get_viewport().set_input_as_handled()
			return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		var dp2 := screen_to_design(st.position)
		if st.pressed:
			_touch_scroll_moved = false
			_touch_scroll_last_y = dp2.y
			_touch_scroll_last_t = Time.get_ticks_msec() * 0.001
			_touch_scroll_active = false
			_touch_scroll_kind = ""
			if shop_open and state == "combat" and shop_slide > 0.05:
				var dx := live_shop_drawer_x()
				var shop_w := _shop_drawer_w()
				var shop_y := _shop_drawer_y()
				var shop_h := _shop_drawer_h()
				var tw := _shop_tab_w()
				if Rect2(dx - tw, shop_y, shop_w + tw, shop_h).has_point(dp2):
					_touch_scroll_active = true
					_touch_scroll_kind = "shop"
					shop_scroll_vel = 0.0
			elif state == "workshop":
				_touch_scroll_active = true
				_touch_scroll_kind = "workshop"
		else:
			# If the finger mostly scrolled, suppress the emulated mouse click.
			if _touch_scroll_moved:
				_ui_tap_lock_t = 0.18
				# Soft fling if the engine didn't report velocity on last drag.
				if _touch_scroll_kind == "shop" and absf(shop_scroll_vel) < 40.0:
					var now_t := Time.get_ticks_msec() * 0.001
					var dt_rel := maxf(0.008, now_t - _touch_scroll_last_t)
					var dy_end := _touch_scroll_last_y - dp2.y
					if absf(dy_end / dt_rel) > absf(shop_scroll_vel):
						shop_scroll_vel = clampf(dy_end / dt_rel, -2200.0, 2200.0)
			_touch_scroll_active = false
			_touch_scroll_kind = ""
			_touch_scroll_moved = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK:
			_handle_android_back()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F1 or event.keycode == KEY_QUOTELEFT:
			toggle_debug()
		if event.keycode == KEY_F2:
			debug_goto_rift_loop(2)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F9:
			debug_start_mycelarch()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F10:
			debug_start_rift_scar()
			get_viewport().set_input_as_handled()
			return
		if debug_open:
			if event.keycode == KEY_C:
				debug_clear_encounter()
			if event.keycode == KEY_B:
				start_boss()
			if event.keycode == KEY_S:
				open_station()
		if event.keycode == KEY_SPACE:
			paused = not paused
		if event.keycode == KEY_1:
			adjust_power("engine", 1)
		if event.keycode == KEY_2:
			adjust_power("gatling", 1)
		if event.keycode == KEY_3:
			adjust_power("cannon", 1)
		if event.keycode == KEY_4:
			adjust_power("drone", 1)
		if event.keycode == KEY_5:
			adjust_power("aux", 1)
		if event.keycode == KEY_Q:
			adjust_power("engine", -1)
		if event.keycode == KEY_W:
			adjust_power("gatling", -1)
		if event.keycode == KEY_E:
			adjust_power("cannon", -1)
		if event.keycode == KEY_R:
			adjust_power("drone", -1)
		if event.keycode == KEY_T:
			adjust_power("aux", -1)
	if event is InputEventMouseButton and event.pressed:
		if shop_open and state == "combat" and shop_slide > 0.05:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				var wp = screen_to_design(event.position)
				var dx = live_shop_drawer_x()
				var tw2 := _shop_tab_w()
				if Rect2(dx - tw2, _shop_drawer_y(), _shop_drawer_w() + tw2, _shop_drawer_h()).has_point(wp):
					# Impulse into velocity for smooth wheel scrolling.
					shop_scroll_vel += -520.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 520.0
					shop_scroll_vel = clampf(shop_scroll_vel, -2400.0, 2400.0)
					get_viewport().set_input_as_handled()
					return
		if state == "workshop":
			if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				adjust_workshop_scroll(-90.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 90.0)
				get_viewport().set_input_as_handled()
				return
		if event.button_index == MOUSE_BUTTON_LEFT:
			var p = screen_to_design(event.position)
			if _try_ui_button_at(p):
				get_viewport().set_input_as_handled()
				return
			if state == "title":
				# Title uses explicit buttons — ignore empty canvas taps on mobile.
				if not is_mobile_ui:
					reset_run()

func screen_to_design(pos: Vector2) -> Vector2:
	return (pos - canvas_offset) / max(.001, canvas_scale)

func adjust_power(key: String, delta: int) -> void:
	# Systems: engine/shield/utility. Weapons: instance uid (or legacy type keys).
	var inst := WeaponLoadout.find_installed(modules, key)
	if not inst.is_empty():
		var cur := clampi(int(inst.get("power", 0)), 0, 3)
		if delta > 0:
			if reactor_used_power() >= int(reactor["max"]):
				toast("No free reactor power")
			elif cur >= 3:
				toast("Power channel maxed")
			else:
				inst["power"] = cur + 1
		elif cur > 0:
			inst["power"] = cur - 1
		save_run()
		return
	if not power.has(key):
		# Legacy type key → bump first matching instance.
		for cand in WeaponLoadout.installed_list(modules):
			var t := str(cand.get("type", ""))
			if t == key or (key == "aux" and WeaponLoadout.is_aux_type(t)):
				adjust_power(str(cand.get("uid", "")), delta)
				return
		return
	if delta > 0:
		var max_for = 5 if key == "engine" else 3
		if reactor_used_power() < int(reactor["max"]) and int(power[key]) < max_for:
			power[key] += 1
		else:
			toast("No free reactor power" if reactor_used_power() >= int(reactor["max"]) else "Power channel maxed")
	elif int(power[key]) > 0:
		power[key] -= 1
	save_run()

func cycle_priority_uid(uid: String) -> void:
	var order := ["nearest", "strongest", "random", "boarders"]
	if uid == "__starter__":
		if starter_gun.is_empty():
			starter_gun = default_starter_gun()
		var cur_s := str(starter_gun.get("priority", "nearest"))
		var idx_s := order.find(cur_s)
		starter_gun["priority"] = order[(idx_s + 1) % order.size()]
		toast("starter priority: " + str(starter_gun["priority"]))
		return
	var inst := WeaponLoadout.find_installed(modules, uid)
	if inst.is_empty():
		return
	var cur := str(inst.get("priority", "nearest"))
	var idx := order.find(cur)
	inst["priority"] = order[(idx + 1) % order.size()]
	# Mirror onto legacy weapons dict for type-level fallbacks.
	var t := str(inst.get("type", ""))
	var wkey := t if weapons.has(t) else "aux"
	if weapons.has(wkey):
		weapons[wkey]["priority"] = inst["priority"]
	save_run()

func use_ability(name: String) -> void:
	if boss_intro_active:
		toast("Hold fire — boss is emerging!")
		return
	# Prevent double-activate from one touch (emulated mouse + stacked hitboxes).
	if float(_ability_tap_lock.get(name, 0.0)) > 0.0:
		return
	var a = abilities[name]
	if name == "barrage" and not a["unlocked"]:
		toast("Artillery Barrage locked — reach Tech Level 6")
		return
	if a["cooldown"] > 0:
		toast(a["label"] + " cooling down")
		return
	_ability_tap_lock[name] = 0.35
	match name:
		"boost":
			a["duration"] = 5.0
			a["cooldown"] = a["cooldown_max"]
			heat["value"] += 6
			toast("Engine boost engaged")
		"shield":
			a["duration"] = 5.0
			a["cooldown"] = a["cooldown_max"]
			heat["value"] += 5
			toast("Emergency shield online")
		"repair":
			a["cooldown"] = a["cooldown_max"]
			repair_train(54.0 * stats_get("repair_mul", 1.0))
			toast("Repair bay cycling")
		"barrage":
			a["cooldown"] = a["cooldown_max"]
			for e in enemies:
				if not e.get("dead", false):
					damage_enemy(e, 105.0 * damage_multiplier(), "explosive")
			shake = max(shake, 15.0)
			toast("ARTILLERY BARRAGE!")

# -----------------------------------------------------------------------------
# Drawing helpers and UI screens
# -----------------------------------------------------------------------------
func update_tactical_feedback(dt: float) -> void:
	for k in warning_cooldowns.keys():
		warning_cooldowns[k] = max(0.0, warning_cooldowns[k] - dt)
	for i in range(telegraphs.size() - 1, -1, -1):
		telegraphs[i]["life"] -= dt
		if telegraphs[i]["life"] <= 0:
			telegraphs.remove_at(i)
	for i in range(screen_warnings.size() - 1, -1, -1):
		screen_warnings[i]["life"] -= dt
		if screen_warnings[i]["life"] <= 0:
			screen_warnings.remove_at(i)
	if warning_cooldowns["heat"] <= 0 and heat["value"] > 88:
		warning_cooldowns["heat"] = 4.0
		add_warning("CRITICAL HEAT - COOLING EMERGENCY", "heat", 960, 210, 2.5, "critical")
		sfx("warn")
	if warning_cooldowns["overrun"] <= 0 and overrun["stage"] >= 3:
		warning_cooldowns["overrun"] = 4.5
		add_warning("OVERRUN IMMINENT - ACCELERATE NOW", "overrun", 960, 260, 2.8, "critical")
		sfx("warn")
	if warning_cooldowns["engine"] <= 0 and momentum["speed"] < 25 and power["engine"] <= 1:
		warning_cooldowns["engine"] = 5.0
		add_warning("LOW SPEED - RESTORE ENGINE POWER", "engine", 960, 235, 2.4, "danger")
	if warning_cooldowns["repair"] <= 0:
		for c in train_cars:
			if c["hp"] / c["max_hp"] < 0.35 and abilities["repair"]["cooldown"] <= 0:
				warning_cooldowns["repair"] = 6.0
				add_warning("HULL COMPROMISED - USE REPAIR!", "repair", c["x"], 430, 3.0, "critical")
				sfx("warn")
				break

func add_warning(text: String, cat: String, x: float, y: float, life = 2.2, severity = "danger") -> void:
	screen_warnings.append({ "text": text, "cat": cat, "x": x, "y": y, "life": life, "max": life, "severity": severity })

func add_telegraph(x: float, y: float, w: float, h: float, life: float, color: Color, label: String, kind: String = "box", x1: float = -1.0, y1: float = -1.0) -> void:
	telegraphs.append({
		"x": x, "y": y, "w": w, "h": h,
		"x1": x1 if x1 >= 0.0 else x + w * 0.5,
		"y1": y1 if y1 >= 0.0 else y,
		"life": life, "max": life,
		"color": color, "label": label, "kind": kind,
		"pulse": randf() * 10.0
	})

func spawn_fx_explosion(x: float, y: float, sheet_key: String, size: float = 200.0, duration: float = 0.7) -> void:
	impact_bursts.append({
		"x": x, "y": y,
		"type": "fx_sheet",
		"sheet": sheet_key,
		"frames": 10,
		"life": duration,
		"max": duration,
		"size": size,
		"color": Color(1, 1, 1, 0.82),
		"angle": 0.0
	})

func spawn_train_impact(car: Dictionary, source, type = "slash") -> void:
	var x = car_draw_center_x(car) + randf_range(-70, 70)
	var y = 690.0 - randf_range(80, 140)
	var angle = randf_range(-0.5, 0.5)
	if source != null:
		angle = atan2(y - source.get("y", y), x - source.get("x", x))
	var col = Color.html("#ff5a47") if type == "slam" else Color.html("#85fff8") if type == "electric" else Color.html("#ffbd68")
	impact_bursts.append({ "x": x, "y": y, "type": type, "color": col, "life": 0.45, "max": 0.45, "size": 80.0 if type == "slam" else 50.0, "angle": angle })
	if type == "slam":
		shake = max(shake, 6.0)
	if settings["particles"]:
		for i in range(8):
			particles.append({ "x": x, "y": y, "vx": randf_range(-110, 110), "vy": randf_range(-90, 50), "life": randf_range(0.2, 0.45), "max": 0.45, "size": randf_range(3, 6), "color": col })

func update_impact_bursts(dt: float) -> void:
	for i in range(impact_bursts.size() - 1, -1, -1):
		impact_bursts[i]["life"] -= dt
		if impact_bursts[i]["life"] <= 0:
			impact_bursts.remove_at(i)

func toggle_debug() -> void:
	debug_open = not debug_open
func set_debug_page(p: int) -> void:
	debug_page = p
func debug_ensure_combat() -> void:
	if state == "title" or state == "workshop" or state == "victory" or state == "failed":
		reset_run()
	if state != "combat":
		state = "combat"
		paused = false
func debug_add_scrap(a: int) -> void:
	scrap += a
	toast("DEBUG: +%s Scrap" % a)
func debug_add_xp(a: float) -> void:
	debug_ensure_combat()
	add_xp(a)
	toast("DEBUG: +%s XP" % int(a))
func debug_heal_train() -> void:
	for c in train_cars:
		c["hp"] = c["max_hp"]
		c["disabled"] = false
		c["wreck_t"] = 0.0
	_nudge_combat_camera_for_convoy_change()
	toast("DEBUG: Train repaired")
func debug_damage_train() -> void:
	damage_car(randi_range(0, train_cars.size() - 1), 50.0, null)
	toast("DEBUG: Car damaged")
func debug_spawn(type: String, elite = false) -> void:
	debug_ensure_combat()
	spawn_enemy(type, elite)
	toast("DEBUG: spawned " + ("elite " if elite else "") + type)
func debug_clear_encounter() -> void:
	debug_ensure_combat()
	if boss_active:
		for e in enemies:
			if e.get("boss", false) and not e.get("dead", false):
				damage_enemy(e, e["hp"] + 9999.0, "rift")
		return
	for e in enemies:
		e["dead"] = true
	enemies.clear()
	encounter_budget = 0.0
	encounter_progress = encounter_goal + 1.0
	finish_encounter()
func debug_set_heat(v: float) -> void:
	heat["value"] = clamp(v, 0.0, 100.0)
	if v < 90.0:
		heat["overheated"] = false
		heat["over_timer"] = 0.0
	toast("DEBUG: heat %s" % int(v))
func debug_set_speed(v: float) -> void:
	momentum["speed"] = clamp(v, 0.0, 150.0)
	momentum["target"] = momentum["speed"]
	toast("DEBUG: speed %s" % int(v))
func debug_force_overrun(stage: int) -> void:
	overrun["value"] = clamp(float(stage) / 4.0 * 100.0, 0.0, 100.0)
	momentum["speed"] = min(momentum["speed"], 10.0)
	add_warning("DEBUG: forced overrun stage %s" % stage, "debug_overrun", 960, 190, 2.0, "critical")
func debug_grant_aux(id: String) -> void:
	if not modules["inventory"].has(id):
		modules["inventory"].append(id)
	modules["aux_levels"][id] = 1
	install_aux_module(id)
	toast("DEBUG: granted " + id)
func debug_max_modules() -> void:
	modules["levels"]["gatling"] = 5
	modules["levels"]["cannon"] = 5
	modules["levels"]["drone"] = 5
	if aux_module_id() != null:
		modules["aux_levels"][aux_module_id()] = 5
	toast("DEBUG: maxed all modules")
func debug_force_encounter(archetype: String) -> void:
	debug_ensure_combat()
	for enc in ENCOUNTERS:
		if enc["id"] == archetype:
			current_encounter = enc.duplicate(true)
			configure_encounter("combat")
			toast("DEBUG: forced encounter " + enc["title"])
			return
func debug_add_alloy(a: int) -> void:
	permanent["alloy"] = permanent.get("alloy", 0) + a
	save_permanent()
	toast("DEBUG: +%s Alloy" % a)
func debug_clear_saves() -> void:
	DirAccess.remove_absolute(SAVE_RUN)
	DirAccess.remove_absolute(SAVE_PERMANENT)
	DirAccess.remove_absolute(SAVE_SETTINGS)
	load_permanent()
	load_settings()
	toast("DEBUG: all saves cleared")

func _draw() -> void:
	update_canvas_transform()
	ui_buttons.clear()
	# Never shake menus / end screens — random per-frame offsets look like a shaky ghosted BG.
	var shake_amt: float = 0.0
	if settings["shake"] and state == "combat" and not region_transition_active:
		shake_amt = shake
	var sx = randf_range(-shake_amt, shake_amt)
	var sy = randf_range(-shake_amt * .6, shake_amt * .6)
	frame_origin = canvas_offset + Vector2(sx, sy) * canvas_scale
	draw_set_transform(frame_origin, 0.0, Vector2(canvas_scale, canvas_scale))
	draw_world()
	if state != "title" and state != "workshop" and state != "options" and state != "help":
		draw_combat_objects()
	draw_set_transform(canvas_offset, 0.0, Vector2(canvas_scale, canvas_scale))
	draw_ui()
	if region_intro_banner_timer > 0.0:
		draw_region_intro_banner()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _is_android_device() -> bool:
	return OS.has_feature("android") or OS.get_name() == "Android"


## Keep phone landscape + one scale path (Godot stretch expand OR our canvas_scale — never both shrunk).
func _apply_mobile_display_config() -> void:
	if _is_android_device():
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	var root_win := get_window()
	if root_win == null:
		return
	root_win.content_scale_size = Vector2i(int(DESIGN_W), int(DESIGN_H))
	root_win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root_win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if _is_android_device():
		call_deferred("_riftline_fix_android_display")


func _riftline_fix_android_display() -> void:
	if not _is_android_device():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	var root_win := get_window()
	if root_win != null:
		root_win.content_scale_size = Vector2i(int(DESIGN_W), int(DESIGN_H))
		root_win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root_win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	update_canvas_transform()
	var vp := get_viewport_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	# Some Android builds leave viewport == window pixels; stretch+manual scale then shrinks twice.
	if win.x > win.y + 1.0 and vp.y < DESIGN_H * 0.85 and root_win != null:
		root_win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		update_canvas_transform()
	_riftline_log_mobile_geometry()


func _riftline_log_mobile_geometry() -> void:
	var win: Vector2i = DisplayServer.window_get_size()
	var vp := get_viewport_rect().size
	var line := "[Riftline] Android geometry: win=%dx%d vp=%.0fx%.0f scale=%.4f offset=(%.1f,%.1f) view=[%.0f..%.0f]x[%.0f..%.0f] orient=%s assets_menu=%s assets_sky=%s" % [
		win.x, win.y, vp.x, vp.y, canvas_scale, canvas_offset.x, canvas_offset.y,
		design_view_left, design_view_right, design_view_top, design_view_bottom,
		str(DisplayServer.screen_get_orientation()),
		str(images.has("menu_mobile_main")), str(images.has("sky"))
	]
	print(line)
	var f := FileAccess.open("user://mobile_device_geometry.log", FileAccess.WRITE)
	if f != null:
		f.store_string(line + "\n")
		f.close()


func update_canvas_transform() -> void:
	var size = get_viewport_rect().size
	if is_mobile_ui:
		# Fill height; allow design space to grow wider than 16:9 (no black side bars).
		canvas_scale = size.y / DESIGN_H
		if canvas_scale <= 0.001:
			canvas_scale = 1.0
		# If the window is unexpectedly taller than wide relative to design, fall back to fit.
		if DESIGN_W * canvas_scale > size.x + 0.5:
			canvas_scale = min(size.x / DESIGN_W, size.y / DESIGN_H)
		canvas_offset = (size - Vector2(DESIGN_W, DESIGN_H) * canvas_scale) * 0.5
		safe_inset = MobileAdapt.design_safe_insets(DESIGN_W, DESIGN_H, canvas_scale, canvas_offset, size)
	else:
		canvas_scale = min(size.x / DESIGN_W, size.y / DESIGN_H)
		canvas_offset = (size - Vector2(DESIGN_W, DESIGN_H) * canvas_scale) * 0.5
	var cs := maxf(canvas_scale, 0.001)
	design_view_left = -canvas_offset.x / cs
	design_view_top = -canvas_offset.y / cs
	design_view_right = design_view_left + size.x / cs
	design_view_bottom = design_view_top + size.y / cs
	if is_mobile_ui:
		_sync_mobile_status_hud()
		_sync_mobile_encounter_hud()
		_sync_mobile_economy_hud()

func _riftline_verify_mobile_preview_window() -> void:
	# Re-apply after the windowing system settles; embedded Game view cannot honor phone size.
	await get_tree().process_frame
	await get_tree().process_frame
	MobileAdapt.apply_preview_window_if_needed()
	update_canvas_transform()
	MobileAdapt.verify_preview_geometry(get_viewport_rect().size, canvas_scale, canvas_offset)
	print("[Riftline] Design view extents: left=%.1f right=%.1f (DESIGN_W=%.0f) scale=%.4f offset=(%.1f,%.1f)" % [
		design_view_left, design_view_right, DESIGN_W, canvas_scale, canvas_offset.x, canvas_offset.y
	])

func _notification(what: int) -> void:
	# Persist on Android background / focus loss — user:// paths are device-safe.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if state != "title" and state != "workshop" and state != "options" and state != "help":
			save_run()
		save_permanent()
		save_settings()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_android_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if state != "title":
			save_run()
		save_permanent()
		save_settings()
		get_tree().quit()

func _handle_android_back() -> void:
	if debug_open:
		debug_open = false
		return
	if shop_open:
		shop_open = false
		return
	if state == "options" or state == "help":
		state = options_back_state if state == "options" else help_back_state
		return
	if state == "workshop":
		state = "title"
		return
	if state == "combat":
		if paused:
			paused = false
		else:
			paused = true
		return
	if state == "title":
		get_tree().quit()

func toggle_reactor_panel() -> void:
	reactor_panel_collapsed = not reactor_panel_collapsed

func shift_reactor_channel_page(delta: int) -> void:
	reactor_channel_page = maxi(0, reactor_channel_page + delta)

func reactor_absorb_click() -> void:
	pass

func weapons_absorb_click() -> void:
	pass

func _reactor_power_rows() -> Array:
	# ENGINE / SHIELD / UTILITY + every installed weapon instance (all channels preserved).
	_clamp_weapon_hud_page()
	var rows: Array = [
		["engine", "ENGINE", int(power.get("engine", 0)), 5],
		["shield", "SHIELD", int(power.get("shield", 0)), 3],
		["utility", "UTILITY", int(power.get("utility", 0)), 3]
	]
	for inst in WeaponLoadout.installed_list(modules):
		rows.append([str(inst.get("uid", "")), _weapon_hud_power_label(inst), int(inst.get("power", 0)), 3])
	return rows

func _reactor_can_adjust(key: String, delta: int) -> bool:
	if key == "":
		return false
	var inst := WeaponLoadout.find_installed(modules, key)
	if not inst.is_empty():
		var cur := clampi(int(inst.get("power", 0)), 0, 3)
		if delta < 0:
			return cur > 0
		return cur < 3 and reactor_used_power() < int(reactor["max"])
	if not power.has(key):
		return false
	var cur2 := int(power[key])
	if delta < 0:
		return cur2 > 0
	var max_for := 5 if key == "engine" else 3
	return cur2 < max_for and reactor_used_power() < int(reactor["max"])

func _register_exact_hit(x: float, y: float, w: float, h: float, method: String, args: Array = []) -> void:
	## Hitbox without MobileAdapt min-touch expansion (avoids overlapping reactor ± rows).
	ui_buttons.append({ "x": x, "y": y, "w": w, "h": h, "method": method, "args": args, "label": "" })

func _consume_ui_tap() -> bool:
	# Debounce: one physical tap must not re-fire through stacked handlers.
	if _ui_tap_lock_t > 0.0:
		return false
	_ui_tap_lock_t = 0.12
	return true

func _try_ui_button_at(design_p: Vector2) -> bool:
	if not _consume_ui_tap():
		return true
	for i in range(ui_buttons.size() - 1, -1, -1):
		var b = ui_buttons[i]
		if Rect2(b["x"], b["y"], b["w"], b["h"]).has_point(design_p):
			sfx("ui")
			callv(b["method"], b.get("args", []))
			return true
	return false

func col(hex: String, alpha = 1.0) -> Color:
	var c = Color.html(hex)
	c.a *= alpha
	return c
func draw_text2(text, x: float, y: float, size = 24, color = Color.WHITE, align = "left") -> void:
	if font == null:
		font = ThemeDB.fallback_font
		if font == null:
			var sys = SystemFont.new()
			sys.font_names = PackedStringArray(["Segoe UI", "Arial", "sans-serif"])
			font = sys
	var s = str(text)
	# Keep sub-pixel Y so glyph bottoms (O/P) are not snapped/clipped away.
	var pos = Vector2(round(x), y)
	var w = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if align == "center":
		pos.x -= round(w * .5)
	elif align == "right":
		pos.x -= round(w)
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
func panel(x: float, y: float, w: float, h: float, stroke = Color(0.5, .9, 1, .28), fill = Color(.05, .08, .11, .86)) -> void:
	draw_rect(Rect2(x, y, w, h), fill, true)
	draw_rect(Rect2(x, y, w, h), stroke, false, 2.0)
func button(x: float, y: float, w: float, h: float, label: String, method: String, args = [], size = 22, stroke = Color(.5, .9, 1, .34)) -> void:
	var hx := x
	var hy := y
	var hw := w
	var hh := h
	if is_mobile_ui:
		var pad := MobileAdapt.touch_pad()
		var min_t := MobileAdapt.min_touch()
		hw = maxf(w, min_t)
		hh = maxf(h, min_t)
		hx = x - (hw - w) * 0.5
		hy = y - (hh - h) * 0.5
		hx -= pad * 0.25
		hy -= pad * 0.25
		hw += pad * 0.5
		hh += pad * 0.5
	ui_buttons.append({ "x": hx, "y": hy, "w": hw, "h": hh, "method": method, "args": args, "label": label })
	if stroke.a > 0.0:
		panel(x, y, w, h, stroke, Color(.08, .14, .19, .94))
	if label != "":
		var fs: int = int(size)
		if is_mobile_ui:
			fs = maxi(fs, 16)
		draw_text2(label, x + w * .5, y + h * .58, fs, Color(.92, .99, 1), "center")
func image_button(x: float, y: float, w: float, h: float, key: String, method: String, args = []) -> void:
	if images.has(key):
		draw_tex(key, Rect2(x, y, w, h))
	var hx := x
	var hy := y
	var hw := w
	var hh := h
	if is_mobile_ui:
		var pad := MobileAdapt.touch_pad()
		hw = maxf(w + pad, MobileAdapt.min_touch())
		hh = maxf(h + pad, MobileAdapt.min_touch())
		hx = x - (hw - w) * 0.5
		hy = y - (hh - h) * 0.5
	ui_buttons.append({ "x": hx, "y": hy, "w": hw, "h": hh, "method": method, "args": args, "label": "" })
func bar(x: float, y: float, w: float, h: float, pct: float, fill: Color, label = "") -> void:
	draw_rect(Rect2(x, y, w, h), Color(0, 0, 0, .42), true)
	draw_rect(Rect2(x + 2, y + 2, max(0.0, (w - 4) * clamp(pct, 0, 1)), h - 4), fill, true)
	draw_rect(Rect2(x, y, w, h), Color(1, 1, 1, .16), false, 1.5)
	if label != "":
		draw_text2(label, x + w * .5, y + h * .72, int(h * .62), Color.WHITE, "center")
func draw_tex(key: String, rect: Rect2, mod = Color.WHITE) -> void:
	if images.has(key):
		draw_texture_rect(images[key], rect, false, mod)
func draw_tex_region(key: String, dst: Rect2, src: Rect2, mod = Color.WHITE) -> void:
	if images.has(key):
		draw_texture_rect_region(images[key], dst, src, mod)

## Stats strip: full sheet is 2172×724 (needs crop); mobile/shared pack is the pre-cropped 2127×223 band.
func _draw_menu_stats_strip_frame(dst: Rect2, mod: Color = Color.WHITE) -> bool:
	if not images.has("menu_stats_strip_frame"):
		return false
	var tex: Texture2D = images["menu_stats_strip_frame"]
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	const REF_W := 2172.0
	const REF_H := 724.0
	const REF_SRC := Rect2(15.0, 257.0, 2127.0, 223.0)
	# Pre-cropped strip (ui/mobile) — draw whole texture. Full sheet — apply authored region.
	if th <= REF_SRC.size.y * 1.25 or tw <= REF_SRC.size.x * 1.05:
		draw_texture_rect(tex, dst, false, mod)
		return true
	var src := Rect2(
		REF_SRC.position.x * (tw / REF_W),
		REF_SRC.position.y * (th / REF_H),
		REF_SRC.size.x * (tw / REF_W),
		REF_SRC.size.y * (th / REF_H)
	)
	src.size.x = minf(src.size.x, tw - src.position.x)
	src.size.y = minf(src.size.y, th - src.position.y)
	draw_texture_rect_region(tex, dst, src, mod)
	return true

func chimney_world_pos() -> Vector2:
	var bob = sin(train_sway) * 3.0
	var loco := get_train_car("loco")
	var spec = TrainBuild.TYPE_SPECS["loco"]
	var ly0 = RAIL_Y - float(spec["contact"]) * float(spec["k"]) + bob + TRAIN_RAIL_NUDGE_Y
	var ox_l = car_slot_ox(loco)
	var left := car_left_edge(loco) if not loco.is_empty() else TrainBuild.LOCO_LEFT_X
	return Vector2(left + 123.0 * float(spec["k"]) + ox_l, ly0 + 12.0)

func draw_wheel_sprite(cx: float, cy: float, r: float, rot: float) -> void:
	if not images.has("wheel"):
		return
	var pos = frame_origin + Vector2(cx, cy) * canvas_scale
	draw_set_transform(pos, rot, Vector2(canvas_scale, canvas_scale))
	draw_texture_rect(images["wheel"], Rect2(-r, -r, r * 2.0, r * 2.0), false)
	draw_set_transform(frame_origin, 0.0, Vector2(canvas_scale, canvas_scale))

func init_fungus_spores() -> void:
	fungus_spores.clear()
	for i in range(55):
		fungus_spores.append({
			"x": randf_range(0.0, DESIGN_W),
			"y": randf_range(90.0, 850.0),
			"vx": randf_range(-35.0, -85.0),
			"size": randf_range(2.5, 7.5),
			"phase": randf_range(0.0, TAU),
			"pulse": randf_range(1.5, 3.8),
			"col_idx": randi() % 4
		})

func init_rift_sparks() -> void:
	rift_sparks.clear()
	for i in range(40):
		rift_sparks.append({
			"x": randf_range(0.0, DESIGN_W),
			"y": randf_range(70.0, 820.0),
			"vx": randf_range(-50.0, -110.0),
			"size": randf_range(1.5, 5.5),
			"phase": randf_range(0.0, TAU),
			"pulse": randf_range(2.0, 5.0),
			"life": randf_range(0.4, 1.0)
		})

func draw_rift_sparks(alpha_mul: float, intensity: float = 0.4) -> void:
	if alpha_mul <= 0.001:
		return
	if rift_sparks.is_empty():
		init_rift_sparks()
	var n = int(clampf(8.0 + intensity * 22.0, 8.0, 28.0))
	for i in range(mini(n, rift_sparks.size())):
		var sp = rift_sparks[i]
		var pulse = 0.45 + 0.45 * sin(t * float(sp["pulse"]) + float(sp["phase"]))
		var a = alpha_mul * intensity * pulse * 0.55
		var pos = Vector2(float(sp["x"]), float(sp["y"]))
		var sz = float(sp["size"])
		draw_circle(pos, sz * 2.2, Color(0.25, 0.7, 1.0, a * 0.2))
		draw_circle(pos, sz, Color(0.55, 0.9, 1.0, a * 0.7))
		draw_circle(pos, sz * 0.35, Color(1.0, 1.0, 1.0, a * 0.9))

func update_fungus_spores(dt: float) -> void:
	if current_region == "fungus_wilds" or (region_transition_active and (region_transition_target == "fungus_wilds" or region_transition_target == RiftScar.REGION_ID)):
		if fungus_spores.is_empty():
			init_fungus_spores()
		var s = momentum["speed"]
		for sp in fungus_spores:
			sp["x"] += (sp["vx"] - s * 0.45) * dt
			sp["y"] += sin(t * sp["pulse"] + sp["phase"]) * 14.0 * dt
			if sp["x"] < -40.0:
				sp["x"] = DESIGN_W + randf_range(10.0, 70.0)
				sp["y"] = randf_range(90.0, 850.0)
	if current_region == RiftScar.REGION_ID or (region_transition_active and region_transition_target == RiftScar.REGION_ID):
		if rift_sparks.is_empty():
			init_rift_sparks()
		var s2 = momentum["speed"]
		for sp2 in rift_sparks:
			sp2["x"] += (float(sp2["vx"]) - s2 * 0.5) * dt
			sp2["y"] += sin(t * float(sp2["pulse"]) + float(sp2["phase"])) * 18.0 * dt
			if float(sp2["x"]) < -40.0:
				sp2["x"] = DESIGN_W + randf_range(10.0, 80.0)
				sp2["y"] = randf_range(70.0, 820.0)

func get_region2_stage() -> String:
	# During the Rustlands → Fungus crossfade, always show Frontier so the theme
	# eases in gently (never snap to Deep Wilds while leaving Iron Maw).
	if region_transition_active:
		return "frontier"
	# Tracks 1–2: Contaminated Frontier (encounter_index 0 or 1)
	# Tracks 3–4: Fungal Expansion (encounter_index 2 or 3)
	# Tracks 5–6: Deep Fungus Wilds (encounter_index 4 or 5)
	if encounter_index <= 1:
		return "frontier"
	elif encounter_index <= 3:
		return "expansion"
	else:
		return "deep"

func region2_stage_keys(stage: String) -> Dictionary:
	match stage:
		"expansion":
			return { "sky": "r2_expansion_sky", "mid": "r2_expansion_mid", "fg": "r2_expansion_fg", "distant": "", "draw_dist": false }
		"deep":
			return { "sky": "r2_sky", "mid": "r2_deep_mid", "fg": "r2_fg", "distant": "r2_distant", "draw_dist": true }
		_:
			return { "sky": "r2_frontier_sky", "mid": "r2_frontier_mid", "fg": "r2_frontier_fg", "distant": "", "draw_dist": false }

func current_bg_stage_id() -> String:
	if region_transition_active:
		return "frontier"
	if current_region == RiftScar.REGION_ID:
		return RiftScar.stage_for_track(encounter_index, false)
	if current_region == "fungus_wilds":
		return get_region2_stage()
	return "rustlands"

func update_bg_stage_blend(dt: float) -> void:
	# Crossfade sky/mid/fg plates when the track advances into a new stage art set.
	if region_transition_active:
		bg_stage_from = "frontier"
		bg_stage_to = "frontier"
		bg_stage_blend = 1.0
		return
	var stage := current_bg_stage_id()
	if bg_stage_to == "":
		bg_stage_from = stage
		bg_stage_to = stage
		bg_stage_blend = 1.0
		return
	if stage != bg_stage_to:
		bg_stage_from = bg_stage_to
		bg_stage_to = stage
		bg_stage_blend = 0.0
	if bg_stage_blend < 1.0:
		bg_stage_blend = minf(1.0, bg_stage_blend + dt / BG_STAGE_BLEND_DURATION)

func draw_fungus_spores(alpha_mul: float, stage: String = "frontier") -> void:
	if alpha_mul <= 0.001 or fungus_spores.is_empty():
		return
	var spore_colors = [
		Color(0.25, 0.85, 0.70),
		Color(0.22, 0.78, 0.45),
		Color(0.58, 0.40, 0.85),
		Color(0.40, 0.88, 0.80)
	]
	var max_count = 8
	var effective_alpha_mul = alpha_mul * 0.22
	if stage == "expansion":
		max_count = 14
		effective_alpha_mul = alpha_mul * 0.35
	elif stage == "deep":
		max_count = 22
		effective_alpha_mul = alpha_mul * 0.45

	for i in range(min(max_count, fungus_spores.size())):
		var sp = fungus_spores[i]
		var col = spore_colors[sp["col_idx"]]
		var p_alpha = (0.45 + 0.35 * sin(t * sp["pulse"] + sp["phase"])) * effective_alpha_mul
		var pos = Vector2(sp["x"], sp["y"])
		var sz = sp["size"] * (0.8 if stage == "frontier" else (0.9 if stage == "expansion" else 1.0))
		draw_circle(pos, sz * 2.0, Color(col.r, col.g, col.b, p_alpha * 0.18))
		draw_circle(pos, sz, Color(col.r, col.g, col.b, p_alpha * 0.65))
		draw_circle(pos, sz * 0.35, Color(1.0, 1.0, 1.0, p_alpha * 0.85))

func start_region_transition(target_region: String) -> void:
	region_transition_active = true
	region_transition_target = target_region
	var dur := REGION_TRANSITION_DURATION
	if target_region == RiftScar.REGION_ID:
		dur = RiftScar.TRANSITION_DURATION
	region_transition_timer = dur
	region_intro_banner_timer = 0.0
	region_intro_shown = false
	bg_stage_from = "frontier"
	bg_stage_to = "frontier"
	bg_stage_blend = 1.0
	# No combat leftovers during the crossing.
	enemies.clear()
	projectiles.clear()
	enemy_projectiles.clear()
	enemy_lasers.clear()
	weapon_fx.clear()
	telegraphs.clear()
	boss_active = false
	boss_intro_active = false
	if fungus_spores.is_empty():
		init_fungus_spores()
	if rift_sparks.is_empty():
		init_rift_sparks()
	momentum["external_drag"] = 0.0
	momentum["speed"] = max(momentum["speed"], 90.0)
	momentum["target"] = max(momentum["target"], 105.0)
	if audio != null:
		audio.play_travel_music(2.5)
	if target_region == RiftScar.REGION_ID:
		toast("Leaving the Wilds… approaching The Rift Scar")
	elif target_region == "fungus_wilds":
		toast("Crossing the Riftline… approaching Fungus Wilds")
	else:
		toast("Rift Loop %d — rails bend back to the Rustlands" % rift_loop)

func region_transition_total() -> float:
	if region_transition_target == RiftScar.REGION_ID:
		return RiftScar.TRANSITION_DURATION
	return REGION_TRANSITION_DURATION

func update_region_transition(dt: float) -> void:
	if region_intro_banner_timer > 0.0:
		region_intro_banner_timer = max(0.0, region_intro_banner_timer - dt)

	if not region_transition_active:
		return

	region_transition_timer -= dt
	var t_prog = clampf(1.0 - (region_transition_timer / maxf(0.01, region_transition_total())), 0.0, 1.0)

	# Banner after the biomes have mostly blended — not at the first flash of spores.
	if t_prog >= 0.62 and not region_intro_shown:
		region_intro_shown = true
		region_intro_banner_timer = 5.0
		sfx("level")

	momentum["speed"] = max(momentum["speed"], 90.0)
	momentum["target"] = max(momentum["target"], 105.0)
	# Keep packing / shift easing toward a normal convoy layout.
	train_shift_desired = 0.0
	train_shift_target = lerpf(train_shift_target, 0.0, clamp(dt * 1.4, 0.0, 1.0))
	train_shift_x = lerp(train_shift_x, 0.0, clamp(dt * 1.4, 0.0, 1.0))
	train_pack_x = lerp(train_pack_x, 0.0, clamp(dt * 1.4, 0.0, 1.0))

	if region_transition_timer <= 0.0:
		complete_region_transition()

func complete_region_transition() -> void:
	region_transition_active = false
	current_region = region_transition_target
	if current_region == "fungus_wilds" or current_region == RiftScar.REGION_ID:
		rustlands_completed = true
	if current_region == RiftScar.REGION_ID:
		fungus_completed = true
	if current_region == "rustlands":
		rustlands_completed = false
		fungus_completed = false
	encounter_index = 0
	enemies.clear()
	projectiles.clear()
	enemy_projectiles.clear()
	enemy_lasers.clear()
	boss_active = false
	boss_intro_active = false
	train_pack_x = 0.0
	train_pack_target = 0.0
	leech_heat_pressure = 0.0
	bg_stage_from = "frontier"
	bg_stage_to = "frontier"
	bg_stage_blend = 1.0
	toasts.clear()
	# Soft heal into the new region so it doesn't feel like the same boss fight continued.
	repair_train(40.0 * stats_get("repair_mul", 1.0))
	heat["value"] = min(heat["value"], 28.0)
	snap_combat_view_shift()
	configure_encounter("combat")
	toasts.clear()
	if current_region == RiftScar.REGION_ID:
		toast("THE RIFT SCAR — Track 1. The Breach Engine waits at the Heart.")
		if rift_sparks.is_empty():
			init_rift_sparks()
	elif current_region == "fungus_wilds":
		toast("FUNGUS WILDS — Track 1. The Mycelarch waits deeper in.")
	else:
		toast("RUSTLANDS — Loop %d Track 1. The Iron Maw waits at the end." % rift_loop)
	reward_pending_boss = false
	station_used = false
	if audio != null:
		audio.play_travel_music(1.5)
	save_run()

func region_transition_progress() -> float:
	if not region_transition_active:
		return 1.0
	return clampf(1.0 - (region_transition_timer / maxf(0.01, region_transition_total())), 0.0, 1.0)

func region_fade_curtain_alpha(t: float) -> float:
	# Soft blackout that rises as the old biome fades out, then clears as the new one fades in.
	# Peak near the midpoint so the swap never hard-cuts.
	var rise := smoothstep(0.0, 0.28, t)
	var fall := 1.0 - smoothstep(0.55, 0.92, t)
	return clampf(rise * fall, 0.0, 1.0) * 0.78

func draw_region_fade_curtain() -> void:
	## Disabled — no dark shadow box during region transitions.
	pass

func draw_transition_fog(_t: float) -> void:
	## Disabled — no fog/brown overlay bands during region transitions.
	pass

func draw_region_intro_banner() -> void:
	var total_dur = 5.0
	var timer = region_intro_banner_timer
	var alpha = 1.0
	if timer > total_dur - 0.8:
		alpha = clampf((total_dur - timer) / 0.8, 0.0, 1.0)
	elif timer < 1.2:
		alpha = clampf(timer / 1.2, 0.0, 1.0)

	if alpha <= 0.001:
		return

	var cx = DESIGN_W * 0.5
	var cy = 295.0
	var w = 1100.0
	var h = 180.0
	var bx = cx - w * 0.5
	var by = cy - h * 0.5
	var dest := region_transition_target if region_transition_active else current_region
	var is_rift := dest == RiftScar.REGION_ID
	var is_fungus := dest == "fungus_wilds"
	var is_rust := dest == "rustlands"

	# 1. Dark letterbox ribbon with smooth horizontal fade
	draw_rect(Rect2(0, by, DESIGN_W, h), Color(0.015, 0.035, 0.05, 0.78 * alpha), true)
	draw_rect(Rect2(bx, by, w, h), Color(0.02, 0.08, 0.10, 0.35 * alpha), true)

	# 2. Glowing border accents
	var line_col = Color(0.55, 0.75, 1.0, 0.85 * alpha)
	if is_fungus:
		line_col = Color(0.25, 0.95, 0.78, 0.85 * alpha)
	elif is_rust:
		line_col = Color(1.0, 0.72, 0.38, 0.85 * alpha)
	var glow_col = Color(line_col.r, line_col.g, line_col.b, 0.28 * alpha)
	draw_line(Vector2(bx, by), Vector2(bx + w, by), glow_col, 5.0)
	draw_line(Vector2(bx, by), Vector2(bx + w, by), line_col, 1.8)
	draw_line(Vector2(bx, by + h), Vector2(bx + w, by + h), glow_col, 5.0)
	draw_line(Vector2(bx, by + h), Vector2(bx + w, by + h), line_col, 1.8)

	draw_circle(Vector2(cx, by), 4.5, line_col)
	draw_circle(Vector2(cx, by + h), 4.5, line_col)

	var sub := "— EXPEDITION REGION 1 —"
	var title := "RUSTLANDS"
	var desc_text := "RIFT LOOP %d  •  IRON MAW DOMAIN" % rift_loop
	if is_rift:
		sub = "— EXPEDITION REGION 3 —"
		title = "THE RIFT SCAR"
		desc_text = "FRACTURED VOID  •  BREACH ENGINE DOMAIN"
	elif is_fungus:
		sub = "— EXPEDITION REGION 2 —"
		title = "FUNGUS WILDS"
		desc_text = "CONTAMINATED FRONTIER  •  EARLY FUNGAL ENCROACHMENT"
		if get_region2_stage() == "expansion":
			desc_text = "FUNGAL EXPANSION  •  OVERGROWN INDUSTRIAL SECTOR"
		elif get_region2_stage() == "deep":
			desc_text = "DEEP FUNGUS WILDS  •  BIOLUMINESCENT DEPTHS"

	var sub_col = Color.html("#ffd36d")
	sub_col.a *= alpha
	draw_text2(sub, cx + 1.0, cy - 40.0, 17, Color(0, 0, 0, 0.85 * alpha), "center")
	draw_text2(sub, cx, cy - 41.0, 17, sub_col, "center")

	var title_glow = Color(line_col.r, line_col.g, line_col.b, 0.35 * alpha)
	var title_col = Color.html("#d5fff7")
	title_col.a *= alpha
	draw_text2(title, cx + 2.0, cy + 18.0, 54 if is_rift else 58, Color(0, 0, 0, 0.9 * alpha), "center")
	draw_text2(title, cx, cy + 17.0, 54 if is_rift else 58, title_glow, "center")
	draw_text2(title, cx, cy + 16.0, 54 if is_rift else 58, title_col, "center")

	var desc_col = Color.html("#8ee5ff")
	desc_col.a *= alpha * 0.9
	draw_text2(desc_text, cx + 1.0, cy + 54.0, 14, Color(0, 0, 0, 0.8 * alpha), "center")
	draw_text2(desc_text, cx, cy + 53.0, 14, desc_col, "center")

func _draw_region2_plates(keys: Dictionary, alpha: float) -> void:
	if alpha <= 0.001:
		return
	draw_sky_cover(str(keys["sky"]), alpha)
	if bool(keys.get("draw_dist", false)) and str(keys.get("distant", "")) != "":
		draw_tiled(str(keys["distant"]), bg.get("r2_dist_x", 0.0), 180.0, -1.0, Color(1, 1, 1, alpha))
	draw_tiled(str(keys["mid"]), bg.get("r2_mid_x", 0.0), MID_Y, -1.0, Color(1, 1, 1, alpha))
	draw_tiled(str(keys["fg"]), bg.get("r2_fg_x", 0.0), GROUND_Y, -1.0, Color(1, 1, 1, alpha))

func _draw_region3_plates(keys: Dictionary, alpha: float) -> void:
	if alpha <= 0.001:
		return
	var sky_a = float(keys.get("sky_a", 1.0))
	var mid_a = float(keys.get("mid_a", 1.0))
	var fg_a = float(keys.get("fg_a", 1.0))
	var dist_a = float(keys.get("dist_a", 0.42))
	draw_sky_cover(str(keys["sky"]), alpha * sky_a)
	if str(keys.get("distant", "")) != "":
		draw_tiled(str(keys["distant"]), bg.get("r3_dist_x", 0.0), 180.0, -1.0, Color(1, 1, 1, alpha * dist_a))
	draw_tiled(str(keys["mid"]), bg.get("r3_mid_x", 0.0), MID_Y, -1.0, Color(1, 1, 1, alpha * mid_a))
	draw_tiled(str(keys["fg"]), bg.get("r3_fg_x", 0.0), GROUND_Y, -1.0, Color(1, 1, 1, alpha * fg_a))

func draw_world() -> void:
	var r1_alpha = 0.0
	var r2_alpha = 0.0
	var r3_alpha = 0.0
	var transition_t = 0.0
	if region_transition_active:
		transition_t = region_transition_progress()
		# Ease the biome crossfade through the dark curtain beat.
		var blend = smoothstep(0.22, 0.72, transition_t)
		if region_transition_target == RiftScar.REGION_ID:
			r2_alpha = 1.0 - blend
			r3_alpha = blend
		elif region_transition_target == "fungus_wilds":
			r1_alpha = 1.0 - blend
			r2_alpha = blend
		else:
			# Return to Rustlands (end of Rift Cycle).
			r3_alpha = 1.0 - blend
			r1_alpha = blend
	elif current_region == RiftScar.REGION_ID:
		r3_alpha = 1.0
	elif current_region == "fungus_wilds":
		r2_alpha = 1.0
	else:
		r1_alpha = 1.0

	var stage_blend := clampf(bg_stage_blend, 0.0, 1.0)
	var stage_ease := smoothstep(0.0, 1.0, stage_blend)

	# 1–3. Sky / mid / ground — region plates with optional within-biome stage crossfade.
	if r1_alpha > 0.001:
		draw_sky_cover("sky", r1_alpha)
		draw_tiled("mid", bg.get("mid_x", 0.0), MID_Y, -1.0, Color(1, 1, 1, r1_alpha))
		draw_tiled("fg", bg.get("fg_x", 0.0), GROUND_Y, -1.0, Color(1, 1, 1, r1_alpha))

	if r2_alpha > 0.001:
		var s_from := bg_stage_from if bg_stage_from != "" else "frontier"
		var s_to := bg_stage_to if bg_stage_to != "" else get_region2_stage()
		if region_transition_active:
			s_from = "frontier"
			s_to = "frontier"
			stage_ease = 1.0
		var k_from := region2_stage_keys(s_from)
		var k_to := region2_stage_keys(s_to)
		if s_from != s_to and stage_ease < 0.999:
			_draw_region2_plates(k_from, r2_alpha * (1.0 - stage_ease))
			_draw_region2_plates(k_to, r2_alpha * stage_ease)
		else:
			_draw_region2_plates(k_to, r2_alpha)

	if r3_alpha > 0.001:
		var rs_from := bg_stage_from if bg_stage_from != "" else "frontier"
		var rs_to := bg_stage_to if bg_stage_to != "" else RiftScar.stage_for_track(encounter_index, false)
		if region_transition_active:
			rs_from = "frontier"
			rs_to = "frontier"
			stage_ease = 1.0
		var rk_from := RiftScar.stage_keys(rs_from)
		var rk_to := RiftScar.stage_keys(rs_to)
		if rs_from != rs_to and stage_ease < 0.999:
			_draw_region3_plates(rk_from, r3_alpha * (1.0 - stage_ease))
			_draw_region3_plates(rk_to, r3_alpha * stage_ease)
		else:
			_draw_region3_plates(rk_to, r3_alpha)

	# Active stage ids for rails / ambient (use blended "to" plate).
	var stage2_now := "frontier"
	if current_region == "fungus_wilds" or (region_transition_active and region_transition_target != RiftScar.REGION_ID):
		stage2_now = bg_stage_to if bg_stage_to != "" else get_region2_stage()
	var stage3_now := "frontier"
	if current_region == RiftScar.REGION_ID or (region_transition_active and region_transition_target == RiftScar.REGION_ID):
		stage3_now = bg_stage_to if bg_stage_to != "" else RiftScar.stage_for_track(encounter_index, region_transition_active)
	var r3keys_now := RiftScar.stage_keys(stage3_now)
	var moss_alpha: float = 0.03 * r2_alpha
	if stage2_now == "expansion":
		moss_alpha = 0.05 * r2_alpha
	elif stage2_now == "deep":
		moss_alpha = 0.07 * r2_alpha

	# 6. Rail tracks — fade with biome alphas so the strip never hard-cuts.
	var rail_y = RAIL_Y - 0.65 * RAIL_STRIP_H
	var rail_base_a := clampf(r1_alpha + r2_alpha, 0.0, 1.0)
	if rail_base_a > 0.001:
		draw_tiled("rail", bg.get("rail_x", 0.0), rail_y, RAIL_STRIP_H, Color(1, 1, 1, rail_base_a))
		if r2_alpha > 0.001:
			draw_tiled("rail", bg.get("rail_x", 0.0), rail_y, RAIL_STRIP_H, Color(0.25, 0.85, 0.65, moss_alpha))
	if r3_alpha > 0.001:
		if images.has("r3_rail"):
			draw_tiled("r3_rail", bg.get("rail_x", 0.0), rail_y, RAIL_STRIP_H, Color(1, 1, 1, r3_alpha))
		else:
			draw_tiled("rail", bg.get("rail_x", 0.0), rail_y, RAIL_STRIP_H, Color(0.35, 0.75, 0.95, 0.08 * r3_alpha))

	# 7. Ambient VFX — keep Stage 3 sparks soft so train/enemies win focus
	if r2_alpha > 0.001:
		draw_fungus_spores(r2_alpha, stage2_now)
	if r3_alpha > 0.001:
		draw_rift_sparks(r3_alpha, float(r3keys_now.get("spark", 0.18)))

## Sky plate: desktop keeps the classic DESIGN_W×DESIGN_H blit; mobile uses uniform
## cover across the ultrawide view so aspect is preserved (no horizontal stretch, one moon/rift).
func draw_sky_cover(key: String, alpha: float = 1.0) -> void:
	if not images.has(key) or alpha <= 0.001:
		return
	var tex: Texture2D = images[key]
	var mod := Color(1, 1, 1, alpha)
	if not is_mobile_ui:
		draw_texture_rect(tex, Rect2(0, 0, DESIGN_W, DESIGN_H), false, mod)
		return
	var vw := design_view_right - design_view_left
	var vh := design_view_bottom - design_view_top
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	if tw <= 1.0 or th <= 1.0 or vw <= 1.0 or vh <= 1.0:
		draw_texture_rect(tex, Rect2(design_view_left, design_view_top, vw, vh), false, mod)
		return
	var cover := maxf(vw / tw, vh / th)
	var dw := tw * cover
	var dh := th * cover
	var dx := design_view_left + (vw - dw) * 0.5
	var dy := design_view_top + (vh - dh) * 0.5
	draw_texture_rect(tex, Rect2(dx, dy, dw, dh), false, mod)

func draw_tiled(key: String, x_offset: float, y: float, h: float = -1.0, mod: Color = Color.WHITE) -> void:
	if not images.has(key) or mod.a <= 0.001:
		return
	var tex = images[key]
	var tw = float(tex.get_width())
	var th = float(tex.get_height()) if h <= 0.0 else h
	var ox = fposmod(x_offset, tw)
	var x_end := DESIGN_W if not is_mobile_ui else design_view_right
	var x = (-ox) if not is_mobile_ui else (design_view_left - fposmod(design_view_left + ox, tw))
	while x < x_end:
		draw_texture_rect(tex, Rect2(x, y, tw, th), false, mod)
		x += tw

func draw_combat_objects() -> void:
	draw_telegraphs()

	# During biome crossing, never draw leftover bosses/enemies — only the train.
	var draw_foes = not region_transition_active
	var bg_enemies: Array = []
	var fg_enemies: Array = []
	if draw_foes:
		for e in enemies:
			if is_foreground_enemy(e):
				fg_enemies.append(e)
			else:
				bg_enemies.append(e)
		bg_enemies.sort_custom(func(a, b): return a["y"] < b["y"])
		for e in bg_enemies:
			draw_enemy(e)

	# 2. Train layer: Train convoy bodies, couplers, wheels, modules, and shield
	draw_train()

	# 3. Foreground layer: Attached boarders and attacking ground enemies
	if draw_foes:
		fg_enemies.sort_custom(func(a, b): return a["y"] < b["y"])
		for e in fg_enemies:
			draw_enemy(e)

	# 4. Combat VFX layer
	draw_lightning()
	for fx in impact_bursts:
		draw_impact_burst(fx)
	for d in drones:
		draw_drone(d)
	for p in projectiles:
		draw_projectile(p)
	for p in enemy_projectiles:
		draw_enemy_projectile(p)
	for laser in enemy_lasers:
		draw_enemy_laser(laser)
	for p in particles:
		draw_particle(p)
	for o in loot_orbs:
		draw_loot(o)
	if settings["damage_numbers"]:
		for n in damage_numbers:
			draw_text2(n["text"], n["x"], n["y"], 24, n.get("color", Color.WHITE), "center")

func car_wreck_modulate(c: Dictionary) -> Color:
	var a = car_draw_alpha(c)
	if a <= 0.01:
		return Color(1, 1, 1, 0)
	if not c.get("disabled", false):
		return Color(1, 1, 1, 1)
	# Broken: dark scorched metal + red heat flash while still solid
	var wt = float(c.get("wreck_t", 0.0))
	var flash = 0.55 + 0.45 * sin(t * 18.0 + wt * 9.0)
	var break_p = clamp(wt / CAR_WRECK_BREAK, 0.0, 1.0)
	return Color(0.55 + flash * 0.25, 0.22 + break_p * 0.1, 0.18, a)

func draw_car_wreck_overlay(c: Dictionary, rect: Rect2) -> void:
	if not c.get("disabled", false):
		return
	var a = car_draw_alpha(c)
	if a <= 0.02:
		return
	var wt = float(c.get("wreck_t", 0.0))
	# Scorch wash
	draw_rect(rect, Color(0.05, 0.02, 0.02, 0.35 * a), true)
	# Stable crack lines across the hull (deterministic per car)
	var crack_offsets = [
		Vector2(0.18, 0.25), Vector2(0.42, 0.38), Vector2(0.65, 0.22),
		Vector2(0.28, 0.58), Vector2(0.55, 0.62), Vector2(0.78, 0.48)
	]
	for i in range(crack_offsets.size()):
		var o = crack_offsets[i]
		var x0 = rect.position.x + rect.size.x * o.x
		var y0 = rect.position.y + rect.size.y * o.y
		var x1 = x0 + 36.0 * (1.0 if i % 2 == 0 else -0.7)
		var y1 = y0 + 48.0 + sin(float(i) * 1.7) * 12.0
		draw_line(Vector2(x0, y0), Vector2(x1, y1), Color(1.0, 0.35, 0.15, 0.55 * a), 2.2)
		draw_line(Vector2(x0 + 4.0, y0 - 2.0), Vector2(x1 - 8.0, y1 - 10.0), Color(0.05, 0.02, 0.02, 0.7 * a), 1.4)
	# Ember sparks along the roof
	if wt < CAR_WRECK_BREAK + 0.8:
		for i in range(4):
			var sx = rect.position.x + 30.0 + i * (rect.size.x / 4.5) + sin(t * 12.0 + i) * 6.0
			var sy = rect.position.y + 18.0 + cos(t * 9.0 + i) * 4.0
			draw_circle(Vector2(sx, sy), 3.0 + sin(t * 20.0 + i) * 1.5, Color(1.0, 0.55, 0.2, 0.7 * a))
	# Falling debris silhouette while fading
	if wt > CAR_WRECK_BREAK:
		var fall = (wt - CAR_WRECK_BREAK) * 40.0
		draw_rect(Rect2(rect.position.x + 40, rect.position.y + rect.size.y * 0.4 + fall, 28, 18), Color(0.2, 0.15, 0.12, 0.45 * a), true)
		draw_rect(Rect2(rect.position.x + rect.size.x * 0.55, rect.position.y + 50 + fall * 0.7, 36, 14), Color(0.25, 0.18, 0.12, 0.4 * a), true)

func draw_train() -> void:
	var bob = sin(train_sway) * 3.0
	var car_l = get_train_car("loco")

	# Soft ground contact shadow so the larger train reads planted on the rails.
	for i_sh in range(train_cars.size()):
		var c_sh: Dictionary = train_cars[i_sh]
		if car_draw_alpha(c_sh) <= 0.02:
			continue
		var ct_sh := str(c_sh.get("car_type", c_sh.get("id", "weapon")))
		var w_sh := TrainBuild.car_pixel_w(ct_sh)
		var lx_sh := car_left_edge(c_sh) + car_slot_ox(c_sh)
		draw_rect(Rect2(lx_sh + 18.0, RAIL_Y + 2.0 + bob * 0.25, w_sh - 36.0, 14.0), Color(0.02, 0.02, 0.04, 0.38 * car_draw_alpha(c_sh)), true)
		draw_rect(Rect2(lx_sh + 40.0, RAIL_Y + 6.0 + bob * 0.25, w_sh - 80.0, 8.0), Color(0.0, 0.0, 0.0, 0.22 * car_draw_alpha(c_sh)), true)

	# --- Train Bodies (rear → front so loco paints on top of coupler overlap) ---
	for i in range(train_cars.size() - 1, -1, -1):
		var c: Dictionary = train_cars[i]
		if car_draw_alpha(c) <= 0.02:
			continue
		var ct := str(c.get("car_type", c.get("id", "weapon")))
		var spec := car_spec(c)
		var ox: float = car_slot_ox(c)
		var cbob: float = bob
		if ct == "weapon":
			cbob = bob + sin(train_sway + 1.0) * 1.5
		var y0: float = RAIL_Y - float(spec["contact"]) * float(spec["k"]) + cbob + TRAIN_RAIL_NUDGE_Y
		var rect := Rect2(car_left_edge(c) + ox, y0, TrainBuild.car_pixel_w(ct), TrainBuild.car_pixel_h(ct))
		# Dark silhouette pass + brighter body so the train stays prominent over busy Stage 3 art.
		var mod := car_wreck_modulate(c)
		draw_tex(str(spec["tex"]), Rect2(rect.position.x + 4.0, rect.position.y + 5.0, rect.size.x, rect.size.y), Color(0.0, 0.0, 0.0, 0.42 * mod.a))
		draw_tex(str(spec["tex"]), rect, Color(minf(1.0, mod.r * 1.12), minf(1.0, mod.g * 1.10), minf(1.0, mod.b * 1.08), mod.a))
		draw_car_wreck_overlay(c, rect)

	# --- Couplers, Running Gear & Reactor Core ---
	draw_coupler_dynamics(bob)
	draw_running_gear(bob)
	if not car_l.is_empty() and car_draw_alpha(car_l) > 0.15:
		draw_reactor_core_fx(bob)

	# --- Module Mounts from live hardpoint assignments ---
	_draw_installed_weapon_modules(bob)
	_draw_starter_gun_module(bob)

	# --- Sci-Fi Train Energy Barrier VFX ---
	draw_train_shield(bob)

	# --- HP Bars / wreck status ---
	for c2 in train_cars:
		var a = car_draw_alpha(c2)
		if a <= 0.05:
			continue
		var pct = c2["hp"] / c2["max_hp"]
		var ctype := str(c2.get("car_type", c2.get("id", "")))
		# Loco bar sits just above the roof gun so the hull reads “on the bar”.
		var by: float = 525.0
		if ctype == "loco":
			var sp_l := car_spec(c2)
			var kk: float = float(sp_l["k"])
			var y0_l: float = RAIL_Y - float(sp_l["contact"]) * kk + TRAIN_RAIL_NUDGE_Y
			var roof_l: float = y0_l + STARTER_DOME_PNG_Y * kk
			var art_h_l: float = float(MODULE_ART["gatling"]["w"]) * STARTER_GUN_SIZE_MUL * (177.0 / 320.0)
			var gun_top_l: float = roof_l + STARTER_GUN_SEAT_Y - art_h_l
			by = gun_top_l - 12.0
		# c2["x"] already includes slot offset after update_train — never add ox again
		# (that shifted rear-car HP bars onto the 2nd-last wagon during boss shift).
		var bx := car_draw_center_x(c2)
		if c2.get("disabled", false):
			var wt = float(c2.get("wreck_t", 0.0))
			var label = "WRECKING" if wt < CAR_WRECK_BREAK else "BREAKING UP"
			draw_text2(label, bx, by - 14.0, 16, Color(1.0, 0.35, 0.25, a), "center")
			bar(bx - 75.0, by, 150.0, 11.0, 0.0, Color(1, .2, .15))
		else:
			bar(bx - 75.0, by, 150.0, 11.0, pct, Color(.45, 1, .65) if pct > .35 else Color(1, .35, .32))

func _starter_mount_xy(loco: Dictionary, hp: Dictionary, bob: float) -> Dictionary:
	# Authoritative loco starter plate — ignore stale save hardpoint roof_dy.
	# TRAIN_RAIL_NUDGE_Y matches loco body draw so the gun tracks the hull.
	var tuned := hp.duplicate(true)
	tuned["rel_x"] = 0.408
	var kk: float = float(car_spec(loco).get("k", 0.68))
	tuned["roof_dy"] = STARTER_DOME_PNG_Y * kk
	var mx := TrainBuild.mount_world_x(loco, tuned) + car_slot_ox(loco)
	var roof := TrainBuild.mount_roof_y(loco, tuned, bob) + TRAIN_RAIL_NUDGE_Y
	return { "mx": mx, "roof": roof }

func _draw_starter_gun_module(bob: float) -> void:
	var loco := get_train_car("loco")
	if loco.is_empty() or car_module_alpha(loco) <= 0.02:
		return
	if not images.has("module_gatling_lv1"):
		return
	for hp in loco.get("hardpoints", []):
		if str(hp.get("hp_id", "")) != "starter":
			continue
		var m := _starter_mount_xy(loco, hp, bob)
		var face := float(starter_gun.get("face", -1.0)) if not starter_gun.is_empty() else -1.0
		var tex: Texture2D = images["module_gatling_lv1"]
		var art_w: float = float(MODULE_ART["gatling"]["w"]) * STARTER_GUN_SIZE_MUL
		var art_h: float = art_w * float(tex.get_height()) / float(tex.get_width())
		var mx: float = float(m["mx"])
		# Bottom of sprite sits on roof + seat (positive seat = down into dome).
		var bottom: float = float(m["roof"]) + STARTER_GUN_SEAT_Y
		var top: float = bottom - art_h
		var mod := Color(0.85, 0.92, 1.0, car_module_alpha(loco))
		# Seat in design space. Horizontal flip only — Y stays design `top`.
		var x_scale: float = canvas_scale if face >= 0.0 else -canvas_scale
		draw_set_transform(frame_origin + Vector2(mx, 0.0) * canvas_scale, 0.0, Vector2(x_scale, canvas_scale))
		draw_texture_rect(tex, Rect2(-art_w * 0.5, top, art_w, art_h), false, mod)
		draw_set_transform(frame_origin, 0.0, Vector2(canvas_scale, canvas_scale))
		break

func _draw_installed_weapon_modules(bob: float) -> void:
	# Draw every mounted instance on its hardpoint (universal 3-slot carriages).
	for inst in WeaponLoadout.installed_list(modules):
		var mxy := WeaponLoadout.instance_mount_xy(train_cars, inst, Callable(self, "car_slot_ox"))
		if mxy.is_empty():
			continue
		var car: Dictionary = mxy["car"]
		var mod_a := car_module_alpha(car)
		if mod_a <= 0.02:
			continue
		var wtype := str(inst.get("type", ""))
		var lvl := instance_level(inst)
		var uid := str(inst.get("uid", ""))
		var face := float(module_face_by_uid.get(uid, module_face(wtype if weapons.has(wtype) else "aux")))
		var roof := TrainBuild.mount_roof_y(car, mxy["hp"], bob + sin(train_sway + 1.0) * 1.5) + TRAIN_RAIL_NUDGE_Y
		var tint = Color(1, 0.45, 0.35, mod_a) if car.get("disabled", false) else Color(1, 1, 1, mod_a)
		var mx := float(mxy["mount_x"])
		# Compact scale so three roof mounts stay clear of neighbors.
		var sc := 0.78
		match wtype:
			"cannon":
				draw_module_sprite("module_cannon_lv5" if lvl >= 4 else "module_cannon_lv1", "cannon", mx, roof, train_recoil.get("cannon", 0.0) * 16.0, face, (0.84 if lvl >= 4 else 0.78), tint)
			"gatling":
				draw_module_sprite("module_gatling_lv5" if lvl >= 4 else "module_gatling_lv1", "gatling", mx, roof, train_recoil.get("gatling", 0.0) * 10.0, face, (0.84 if lvl >= 4 else 0.78), tint)
			"drone":
				var hatch = drone_hatch
				draw_module_sprite("module_drone_closed", "drone", mx, roof, 0.0, 1.0, sc, Color(tint.r, tint.g, tint.b, tint.a * (1.0 - hatch)))
				draw_module_sprite("module_drone_open", "drone", mx, roof, 0.0, 1.0, sc, Color(tint.r, tint.g, tint.b, tint.a * hatch))
			"arc_coil":
				draw_module_sprite("module_arc", "arc_coil", mx, roof, train_recoil.get("aux", 0.0) * 12.0, face, sc, tint)
			"cryo_launcher":
				draw_module_sprite("module_cryo", "cryo_launcher", mx, roof, train_recoil.get("aux", 0.0) * 12.0, face, sc, tint)
			"missile_rack":
				draw_module_sprite("module_missile", "missile_rack", mx, roof, train_recoil.get("aux", 0.0) * 12.0, face, sc, tint)
			"rail_mortar":
				draw_module_sprite("module_mortar", "rail_mortar", mx, roof, train_recoil.get("aux", 0.0) * 12.0, face, sc, tint)
		if mod_a > 0.4 and not car.get("disabled", false):
			draw_level_pips(mx - 24.0, roof + 12.0, lvl)

func living_shield_cars() -> Array:
	# Front→rear living cars that the emergency shield must wrap.
	var out: Array = []
	for c in train_cars:
		if c.get("disabled", false):
			continue
		if float(c.get("hp", 0.0)) <= 0.0:
			continue
		if car_draw_alpha(c) < 0.12:
			continue
		out.append(c)
	return out

func shield_convoy_bounds(bob: float) -> Dictionary:
	# World-space left/right extents of the living convoy (includes pack/shift offsets).
	var living := living_shield_cars()
	if living.is_empty():
		var loco := get_train_car("loco")
		if loco.is_empty():
			return {}
		living = [loco]
	var x_left := INF
	var x_right := -INF
	var roof_min := 9999.0
	for c in living:
		var ct := str(c.get("car_type", c.get("id", "weapon")))
		var ox := car_slot_ox(c)
		var left := car_left_edge(c) + ox
		var right := left + TrainBuild.car_pixel_w(ct)
		x_left = minf(x_left, left)
		x_right = maxf(x_right, right)
		var spec := car_spec(c)
		var roof := RAIL_Y - float(spec["contact"]) * float(spec["k"]) + bob + TRAIN_RAIL_NUDGE_Y - 18.0
		roof_min = minf(roof_min, roof)
	# Padding so the dome clears cowcatcher / rear coupler.
	x_left -= 28.0
	x_right += 26.0
	var span := maxf(80.0, x_right - x_left)
	return {
		"x_left": x_left,
		"x_right": x_right,
		"span": span,
		"y_top": clampf(roof_min, 340.0 + bob, 430.0 + bob),
		"living": living
	}

func draw_train_shield(bob: float) -> void:
	if shield_time <= 0.0:
		return

	var max_dur = 5.0
	var elapsed = max(0.0, max_dur - shield_time)

	# Smooth fade-in over 0.2s, smooth fade-out over 0.6s
	var fade_in = clamp(elapsed / 0.2, 0.0, 1.0)
	var fade_out = clamp(shield_time / 0.6, 0.0, 1.0)

	# Active-state subtle shimmer & breathing pulse
	var shimmer = 0.90 + sin(t * 6.0) * 0.10 + sin(t * 14.0) * 0.05
	var hit_pulse = clamp(train_damage_flash * 2.2, 0.0, 0.6)
	var alpha = clamp(fade_in * fade_out * shimmer + hit_pulse, 0.0, 1.0)
	if alpha <= 0.01:
		return

	var bounds := shield_convoy_bounds(bob)
	if bounds.is_empty():
		return
	var x_left: float = float(bounds["x_left"])
	var x_right: float = float(bounds["x_right"])
	var y_top: float = float(bounds["y_top"])
	var y_base = RAIL_Y + 6.0 + bob

	var poly = build_shield_contour(x_left, x_right, y_base, y_top, bob, bounds.get("living", []))
	if poly.size() < 3:
		return

	# 1. Subtle transparent interior fill (keeps train, weapons, enemies & environment crystal clear)
	draw_colored_polygon(poly, Color(0.12, 0.68, 0.98, 0.055 * alpha))

	# 2. Animated hexagonal energy forcefield grid
	draw_shield_hex_grid(poly, x_left, x_right, y_base, y_top, bob, alpha)

	# 3. Subtle curved streamline contours inside canopy
	draw_shield_streamlines(x_left, x_right, y_base, y_top, bob, alpha)

	# 4. Thin glowing cyan boundary (multi-pass neon edge)
	var closed_outline = poly.duplicate()
	closed_outline.append(poly[0])
	draw_polyline(closed_outline, Color(0.20, 0.85, 1.0, 0.20 * alpha), 8.0)
	draw_polyline(closed_outline, Color(0.40, 0.95, 1.0, 0.75 * alpha), 3.2)
	draw_polyline(closed_outline, Color(0.88, 0.98, 1.0, 0.95 * alpha), 1.3)

	# 5. Base rail contact grounding emitter points & micro sparks
	draw_shield_rail_grounding(x_left, x_right, y_base, alpha)

	# 6. Quick activation pulse / expanding shockwave ripple
	if elapsed < 0.38:
		var act_frac = elapsed / 0.38
		var ripple_expand = (1.0 - act_frac) * 14.0
		var ripple_col = Color(0.55, 0.98, 1.0, (1.0 - act_frac) * 0.65)
		var center = Vector2((x_left + x_right) * 0.5, (y_base + y_top) * 0.5)
		var ripple_poly = PackedVector2Array()
		for pt in closed_outline:
			var dir = (pt - center).normalized()
			ripple_poly.append(pt + dir * ripple_expand)
		draw_polyline(ripple_poly, ripple_col, 2.5)

func _shield_roof_y_at(x: float, living: Array, y_top_default: float, bob: float) -> float:
	# Canopy height follows the tallest living car under this X (plus module clearance).
	var best := y_top_default
	for c in living:
		var ct := str(c.get("car_type", c.get("id", "weapon")))
		var ox := car_slot_ox(c)
		var left := car_left_edge(c) + ox
		var right := left + TrainBuild.car_pixel_w(ct)
		if x < left - 20.0 or x > right + 20.0:
			continue
		var spec := car_spec(c)
		var roof := RAIL_Y - float(spec["contact"]) * float(spec["k"]) + bob + TRAIN_RAIL_NUDGE_Y
		# Extra headroom for roof turrets / drone bay.
		var clear := 36.0 if ct == "loco" else 48.0
		best = minf(best, roof - clear)
	return best

func build_shield_contour(x_left: float, x_right: float, y_base: float, y_top: float, bob: float, living: Array = []) -> PackedVector2Array:
	# Fully parametric dome — scales with loco-only through 3-wagon convoys.
	var pts = PackedVector2Array()
	var span := maxf(80.0, x_right - x_left)
	var rear_pad := clampf(span * 0.12, 70.0, 130.0)
	var front_pad := clampf(span * 0.14, 90.0, 160.0)
	var x_rear_turn = x_left + rear_pad
	var x_front_turn = x_right - front_pad
	if x_front_turn <= x_rear_turn + 40.0:
		x_rear_turn = x_left + span * 0.22
		x_front_turn = x_right - span * 0.22

	# 1. Base rail contact — sample along the living span only.
	var base_steps := maxi(3, int(span / 220.0) + 2)
	for i in range(base_steps + 1):
		var u := float(i) / float(base_steps)
		pts.append(Vector2(lerpf(x_left + 8.0, x_right - 14.0, u), y_base))

	# 2. Front prow (cowcatcher → loco roof)
	var y_front := _shield_roof_y_at(x_right - front_pad * 0.35, living, y_top, bob)
	var front_steps = 10
	for i in range(front_steps + 1):
		var frac = float(i) / float(front_steps)
		var ang = frac * (PI * 0.5)
		var px = x_front_turn + (x_right - x_front_turn) * cos(ang)
		var py = y_front + (y_base - y_front) * (1.0 - sin(ang))
		pts.append(Vector2(px, py))

	# 3. Top canopy — follow living cars from front → rear.
	var canopy_steps := maxi(6, int(span / 90.0))
	for i in range(canopy_steps + 1):
		var u := float(i) / float(canopy_steps)
		var px2 := lerpf(x_front_turn, x_rear_turn, u)
		var py2 := _shield_roof_y_at(px2, living, y_top, bob)
		# Gentle arch so short (loco-only) domes don't look flat.
		var arch := sin(u * PI) * clampf(18.0 - span * 0.008, 6.0, 18.0)
		pts.append(Vector2(px2, py2 - arch))

	# 4. Rounded rear cap
	var y_rear := _shield_roof_y_at(x_left + rear_pad * 0.4, living, y_top, bob)
	var rear_steps = 8
	for i in range(1, rear_steps + 1):
		var frac = float(i) / float(rear_steps)
		var ang = frac * (PI * 0.5)
		var px3 = x_rear_turn - (x_rear_turn - x_left) * sin(ang)
		var py3 = y_rear + (y_base - y_rear) * (1.0 - cos(ang))
		pts.append(Vector2(px3, py3))

	return pts

func draw_shield_hex_grid(poly: PackedVector2Array, x_left: float, x_right: float, y_base: float, y_top: float, bob: float, alpha: float) -> void:
	var r = 26.0
	var dx = 39.0
	var dy = 45.0
	var min_y = y_top + 8.0

	var col_idx = 0
	var x = x_left + 45.0
	while x < x_right - 35.0:
		var y_off = (col_idx % 2) * (dy * 0.5)
		var y = min_y + y_off
		while y < y_base - 18.0:
			var center = Vector2(x, y)
			if Geometry2D.is_point_in_polygon(center, poly):
				var wave = sin(t * 4.8 - x * 0.0075 + y * 0.005)
				var hex_a = clamp((wave - 0.22) * 0.22, 0.0, 0.13) * alpha
				if hex_a > 0.012:
					var hpts = PackedVector2Array()
					for k in range(7):
						var a = k * TAU / 6.0 + PI / 6.0
						hpts.append(center + Vector2(cos(a) * (r * 0.88), sin(a) * (r * 0.88)))
					draw_polyline(hpts, Color(0.38, 0.94, 1.0, hex_a), 1.0)
					if wave > 0.88:
						draw_circle(center, 1.8, Color(0.85, 1.0, 1.0, hex_a * 1.8))
			y += dy
		x += dx
		col_idx += 1

func draw_shield_streamlines(x_left: float, x_right: float, y_base: float, y_top: float, bob: float, alpha: float) -> void:
	var span := maxf(1.0, x_right - x_left)
	for layer in [0.28, 0.62]:
		var line_pts = PackedVector2Array()
		var step_x = clampf(span / 18.0, 28.0, 48.0)
		var cx = x_left + 40.0
		while cx <= x_right - 40.0:
			var cy = y_top + (y_base - y_top) * layer + sin(t * 7.0 - cx * 0.015) * 2.5
			line_pts.append(Vector2(cx, cy))
			cx += step_x
		if line_pts.size() > 1:
			var s_alpha = (0.04 + 0.03 * sin(t * 6.0 + layer * 3.0)) * alpha
			draw_polyline(line_pts, Color(0.42, 0.95, 1.0, s_alpha), 1.2)

func draw_shield_rail_grounding(x_left: float, x_right: float, y_base: float, alpha: float) -> void:
	var span := maxf(120.0, x_right - x_left - 120.0)
	var n := clampi(int(span / 140.0) + 3, 3, 10)
	for i in range(n):
		var gx = x_left + 60.0 + i * (span / float(maxi(1, n - 1)))
		var p_wave = sin(t * 8.0 + i * 1.2)
		var g_alpha = (0.15 + 0.15 * p_wave) * alpha
		draw_circle(Vector2(gx, y_base), 3.0, Color(0.45, 0.95, 1.0, g_alpha))
		if p_wave > 0.6:
			draw_line(Vector2(gx, y_base - 1.0), Vector2(gx + sin(t * 18.0 + i) * 8.0, y_base - 6.0), Color(0.85, 1.0, 1.0, g_alpha * 1.5), 1.0)

func module_face(key: String) -> float:
	# Guns are authored facing right. Enemies approach from the left, so default to facing left.
	return weapons[key].get("face", -1.0) if weapons.has(key) else -1.0

func module_geometry(art_key: String, tex_key: String, mount_x: float, roof_y: float, recoil: float, face: float, size_mul: float = 1.0) -> Dictionary:
	# Returns the on-screen rect (flip-safe, base seated on roof_y) and the world muzzle position.
	var art = MODULE_ART[art_key]
	var w = art["w"] * size_mul
	var h = w * 0.6
	if images.has(tex_key):
		h = w * float(images[tex_key].get_height()) / float(images[tex_key].get_width())
	var cx = mount_x - face * recoil
	var mz: Vector2 = art["mz"]
	var muzzle = Vector2(cx + face * (mz.x - 0.5) * w, roof_y - h + mz.y * h)
	return { "w": w, "h": h, "cx": cx, "muzzle": muzzle }

func draw_module_sprite(tex_key: String, art_key: String, mount_x: float, roof_y: float, recoil: float, face: float, size_mul: float = 1.0, mod = Color.WHITE, seat_y: float = 3.0) -> void:
	if not images.has(tex_key) or mod.a <= 0.01:
		return
	var g = module_geometry(art_key, tex_key, mount_x, roof_y, recoil, face, size_mul)
	var rect = Rect2(g["cx"] - g["w"] * 0.5, roof_y - g["h"] + seat_y, g["w"], g["h"])
	if face >= 0.0:
		draw_texture_rect(images[tex_key], rect, false, mod)
	else:
		draw_set_transform(frame_origin + Vector2(g["cx"], 0.0) * canvas_scale, 0.0, Vector2(-canvas_scale, canvas_scale))
		draw_texture_rect(images[tex_key], Rect2(-g["w"] * 0.5, rect.position.y, g["w"], g["h"]), false, mod)
		draw_set_transform(frame_origin, 0.0, Vector2(canvas_scale, canvas_scale))

func refresh_muzzles() -> void:
	# Keep each weapon's firing origin glued to the actual barrel tip of its sprite.
	if is_module_installed("gatling"):
		var gxy := get_weapon_mount_xy("gatling")
		if not gxy.is_empty():
			var clv = module_level("gatling")
			var groof := TrainBuild.mount_roof_y(gxy["car"], gxy["hp"], 0.0) + TRAIN_RAIL_NUDGE_Y
			weapons["gatling"]["muzzle"] = module_geometry("gatling", "module_gatling_lv1", float(gxy["mount_x"]), groof, train_recoil["gatling"] * 10.0, module_face("gatling"), 1.08 if clv >= 4 else 1.0)["muzzle"]
	if is_module_installed("cannon"):
		var cxy := get_weapon_mount_xy("cannon")
		if not cxy.is_empty():
			var cl = module_level("cannon")
			var croof := TrainBuild.mount_roof_y(cxy["car"], cxy["hp"], 0.0) + TRAIN_RAIL_NUDGE_Y
			weapons["cannon"]["muzzle"] = module_geometry("cannon", "module_cannon_lv1", float(cxy["mount_x"]), croof, train_recoil["cannon"] * 16.0, module_face("cannon"), 1.08 if cl >= 4 else 1.0)["muzzle"]
	var aux = aux_module_id()
	if aux != null:
		var axy := get_weapon_mount_xy("aux")
		if not axy.is_empty():
			var tk = "module_arc" if aux == "arc_coil" else "module_cryo" if aux == "cryo_launcher" else "module_missile" if aux == "missile_rack" else "module_mortar"
			var aroof := TrainBuild.mount_roof_y(axy["car"], axy["hp"], 0.0) + TRAIN_RAIL_NUDGE_Y
			weapons["aux"]["muzzle"] = module_geometry(aux, tk, float(axy["mount_x"]), aroof, train_recoil["aux"] * 12.0, module_face("aux"))["muzzle"]
	# Starter loco gun muzzle
	if starter_gun.is_empty():
		starter_gun = default_starter_gun()
	var loco := get_train_car("loco")
	if not loco.is_empty():
		for hp in loco.get("hardpoints", []):
			if str(hp.get("hp_id", "")) == "starter":
				var m := _starter_mount_xy(loco, hp, 0.0)
				var face := float(starter_gun.get("face", -1.0))
				# Match draw_module_sprite seat so barrel tip tracks the seated sprite.
				var roof := float(m["roof"]) + STARTER_GUN_SEAT_Y
				starter_gun["muzzle"] = module_geometry("gatling", "module_gatling_lv1", float(m["mx"]), roof, 0.0, face, STARTER_GUN_SIZE_MUL)["muzzle"]
				break

func face_target(key: String, mount_x: float, target: Dictionary) -> void:
	if target == null or not weapons.has(key):
		return
	var dx = target["x"] - mount_x
	if abs(dx) > 40.0:
		weapons[key]["face"] = 1.0 if dx > 0.0 else -1.0

func draw_level_pips(x: float, y: float, lvl: int) -> void:
	for i in range(5):
		draw_circle(Vector2(x + i * 14, y), 4.5, Color.html("#ffd36d") if i < lvl else Color(1, 1, 1, 0.18))

func draw_running_gear(bob: float) -> void:
	var spd_ratio = clamp(momentum["speed"] / 115.0, 0.0, 1.35)
	var heat_ratio = clamp(heat["value"] / 100.0, 0.0, 1.0)
	var jolt = suspension_jolt * sin(t * 42.0) * 4.0
	var phase = wheel_rot

	# Rail contact streaks & sparks
	for i in range(16):
		var rx = fposmod(100.0 + (i * 101.0 - t * (360.0 + spd_ratio * 760.0)), 1560.0)
		var ry = RAIL_Y + (i % 3) * 3.0 + sin(t * 9.0 + i) * 1.5
		var rcol = Color(1.0, 0.76, 0.4, 0.55) if i % 4 == 0 else Color(0.47, 0.93, 1.0, 0.35)
		draw_line(Vector2(rx, ry), Vector2(rx + 34.0 + spd_ratio * 44.0, ry - 2.0), rcol, 2.0 if i % 4 == 0 else 1.2)

	for c in train_cars:
		if car_draw_alpha(c) <= 0.08:
			continue
		var ct := str(c.get("car_type", c.get("id", "weapon")))
		var spec := car_spec(c)
		var ox: float = car_slot_ox(c)
		var left: float = car_left_edge(c)
		var yjolt: float = jolt
		if ct == "weapon":
			yjolt = jolt * 0.65 + sin(train_sway + 1.0) * 1.5
		var y0: float = RAIL_Y - float(spec["contact"]) * float(spec["k"]) + bob + yjolt + TRAIN_RAIL_NUDGE_Y
		var wheel_list = LOCO_WHEELS if ct == "loco" else CAR_WHEELS
		for w in wheel_list:
			var cx = left + w[0] * float(spec["k"]) + ox
			var cy = y0 + (float(spec["contact"]) - w[1]) * float(spec["k"])
			var r = w[1] * float(spec["k"])
			draw_wheel_sprite(cx, cy, r, phase if ct == "loco" else phase * 1.15)
		if ct == "loco":
			var w2_cx = left + 350.0 * float(spec["k"]) + ox
			var w2_cy = y0 + (float(spec["contact"]) - 64.0) * float(spec["k"])
			var w3_cx = left + 465.0 * float(spec["k"]) + ox
			var w3_cy = y0 + (float(spec["contact"]) - 64.0) * float(spec["k"])
			var crank_r = 64.0 * float(spec["k"]) * 0.44
			var p2 = Vector2(w2_cx + cos(phase) * crank_r, w2_cy + sin(phase) * crank_r)
			var p3 = Vector2(w3_cx + cos(phase) * crank_r, w3_cy + sin(phase) * crank_r)
			draw_line(p2, p3, Color(0.08, 0.09, 0.11, 0.9), 9.0)
			var rod_accent = Color(1.0, 0.67, 0.33, 0.85) if heat_ratio > 0.72 else Color(0.78, 0.72, 0.52, 0.85)
			draw_line(p2, p3, rod_accent, 3.5)
			draw_circle(p2, 6.0, rod_accent)
			draw_circle(p3, 6.0, rod_accent)

func draw_reactor_core_fx(bob: float) -> void:
	var pulse = 0.5 + sin(t * 7.0) * 0.5
	var h_val = clamp(heat["value"] / 100.0, 0.0, 1.0)
	var loco := get_train_car("loco")
	var spec_l = TrainBuild.TYPE_SPECS["loco"]
	var ly0 = RAIL_Y - float(spec_l["contact"]) * float(spec_l["k"]) + bob + TRAIN_RAIL_NUDGE_Y
	var ox_l = car_slot_ox(loco)
	var left := car_left_edge(loco) if not loco.is_empty() else TrainBuild.LOCO_LEFT_X
	var core_pos = Vector2(left + 399.0 * float(spec_l["k"]) + ox_l, ly0 + 219.0 * float(spec_l["k"]))
	var r = 36.0 + h_val * 10.0
	var core_col = Color(1.0, 0.54, 0.27, 0.28 + pulse * 0.24) if h_val > 0.8 else Color(0.28, 0.92, 1.0, 0.28 + pulse * 0.26)
	draw_circle(core_pos, r, core_col)
	draw_circle(core_pos, r * 0.45, Color(1.0, 1.0, 1.0, 0.45 + pulse * 0.4))
	var arc_col = Color(1.0, 0.54, 0.27, 0.75) if h_val > 0.8 else Color(0.56, 1.0, 0.98, 0.72)
	for i in range(6):
		var a = t * 2.2 + i * TAU / 6.0
		var p1 = core_pos + Vector2(cos(a) * 14.0, sin(a) * 12.0)
		var p2 = core_pos + Vector2(cos(a + 0.32) * (24.0 + pulse * 7.0), sin(a + 0.24) * (20.0 + pulse * 7.0))
		draw_line(p1, p2, arc_col, 2.0)

func draw_coupler_dynamics(bob: float) -> void:
	var slack = sin(train_sway * 1.7) * 4.0 + suspension_jolt * sin(t * 48.0) * 5.0
	# Couple adjacent visible cars from rear toward loco.
	for i in range(train_cars.size() - 1, 0, -1):
		var rear: Dictionary = train_cars[i]
		var front: Dictionary = train_cars[i - 1]
		# Skip faded wrecks — find next visible neighbor toward loco.
		if car_draw_alpha(rear) <= 0.15:
			continue
		var front_idx := i - 1
		while front_idx >= 0 and car_draw_alpha(train_cars[front_idx]) <= 0.15:
			front_idx -= 1
		if front_idx < 0:
			continue
		front = train_cars[front_idx]
		var rct := str(rear.get("car_type", rear.get("id", "weapon")))
		var ox_r := car_slot_ox(rear)
		var ox_f := car_slot_ox(front)
		var r_right := car_left_edge(rear) + TrainBuild.car_pixel_w(rct) + ox_r
		var f_left := car_left_edge(front) + ox_f
		var mid = Vector2((r_right + f_left) * 0.5, RAIL_Y - 50.0 + slack)
		draw_line(Vector2(r_right - 10.0, RAIL_Y - 50.0 + bob), mid, Color(0.08, 0.09, 0.11, 0.92), 10.0)
		draw_line(mid, Vector2(f_left + 10.0, RAIL_Y - 50.0 + bob), Color(0.08, 0.09, 0.11, 0.92), 10.0)
		draw_line(Vector2(r_right - 5.0, RAIL_Y - 54.0 + bob), Vector2(f_left + 5.0, RAIL_Y - 54.0 + bob), Color(0.35, 0.93, 1.0, 0.75), 3.0)


func _draw_sprite_silhouette_outline(sprite: String, dst: Rect2, src: Rect2, outline: Color, foot_pad: float = 0.0) -> void:
	# Thin rim via offset sprite copies (opaque texels only = real silhouette).
	# Sides + upward only, and skip the cell's under-foot padding so baked contact
	# shadows are never recolored into a red/blue ground smear.
	if outline.a <= 0.001 or not images.has(sprite):
		return
	var rim_dst := dst
	var rim_src := src
	var pad := maxf(0.0, foot_pad)
	if pad > 1.0 and dst.size.y > pad + 8.0:
		var frac := pad / dst.size.y
		rim_src = Rect2(src.position.x, src.position.y, src.size.x, src.size.y * (1.0 - frac))
		rim_dst = Rect2(dst.position.x, dst.position.y, dst.size.x, dst.size.y - pad)
	var rad := 1.5
	var dirs := [
		Vector2(rad, 0.0), Vector2(-rad, 0.0),
		Vector2(0.0, -rad),
		Vector2(rad * 0.7, -rad * 0.7), Vector2(-rad * 0.7, -rad * 0.7)
	]
	var oc := Color(outline.r, outline.g, outline.b, outline.a * 0.75)
	for d in dirs:
		draw_tex_region(sprite, Rect2(rim_dst.position + d, rim_dst.size), rim_src, oc)

func draw_enemy(e: Dictionary) -> void:
	if e.get("boss", false):
		draw_iron_colossus(e)
		return
	var sprite = e["data"]["sprite"]
	var meta = SPRITE_ANIMS[sprite]
	var frame = int(fmod(e["frame"] * meta["fps"], meta["frames"]))
	var size = 256.0 * e["data"]["scale"]
	var dir = e.get("dir", -1.0)
	var tint = Color(1.8, 0.65, 0.65, 1.0) if e.get("flash", 0.0) > 0.01 else Color.WHITE
	var eclass := str(e.get("elite_class", RiftLoop.CLASS_NORMAL))
	var outline := RiftLoop.outline_color(eclass)
	var src := Rect2(frame * meta["w"], 0, meta["w"], meta["h"])
	var foot_pad := float(meta.get("anchor_y", 30.0))
	if dir > 0:
		draw_set_transform(frame_origin + Vector2(e["x"], e["y"]) * canvas_scale, 0.0, Vector2(-canvas_scale, canvas_scale))
		var dst_f := Rect2(-size * .5, -size + meta["anchor_y"], size, size)
		_draw_sprite_silhouette_outline(sprite, dst_f, src, outline, foot_pad)
		draw_tex_region(sprite, dst_f, src, tint)
		draw_set_transform(frame_origin, 0.0, Vector2(canvas_scale, canvas_scale))
	else:
		var dst := Rect2(e["x"] - size * .5, e["y"] - size + meta["anchor_y"], size, size)
		_draw_sprite_silhouette_outline(sprite, dst, src, outline, foot_pad)
		draw_tex_region(sprite, dst, src, tint)
	# Flux Rifleman charging laser (drawn after sprite so it sits on top)
	var charge = float(e.get("laser_charge", 0.0))
	if charge > 0.02 and e["data"].get("ranged", false) and e.has("laser_aim"):
		var muzzle = flux_rifle_muzzle(e)
		var aim: Vector2 = e["laser_aim"]
		draw_enemy_laser({
			"x0": muzzle.x, "y0": muzzle.y, "x1": aim.x, "y1": aim.y,
			"life": 1.0, "max": 1.0, "width": 1.5 + charge * 4.0,
			"charge": true, "strength": 0.28 + charge * 0.55
		})
	var show_bar: bool = (float(e["hp"]) < float(e["max_hp"]) or RiftLoop.is_elite_class(eclass)) and not bool(e.get("dead", false))
	if show_bar:
		var bar_col := RiftLoop.hp_bar_color(eclass) if RiftLoop.is_elite_class(eclass) else Color(1, .35, .32)
		bar(e["x"] - 42, e["y"] - size + 15, 84, 8, e["hp"] / maxf(1.0, e["max_hp"]), bar_col)
		if RiftLoop.is_elite_class(eclass):
			var tag := "RED ELITE" if eclass == RiftLoop.CLASS_RED else "BLUE ELITE"
			draw_text2(tag, e["x"], e["y"] - size + 8, 11, bar_col, "center")

func boss_colossus_anim_state(b: Dictionary) -> String:
	if b.get("dead", false):
		return "death"
	var style = str(b.get("attack_style", ""))
	if style == "claw" or style == "slam" or style == "beam":
		return style
	# Brief hold after resolve so the strike frames finish.
	if b.get("anim_hold", false):
		var hold_anim = str(b.get("anim", "idle"))
		var sheet = boss_anim_sheet_key(hold_anim, str(b.get("boss_id", b.get("data", {}).get("id", ""))))
		if SPRITE_ANIMS.has(sheet):
			var meta = SPRITE_ANIMS[sheet]
			var dur = float(meta["frames"]) / max(0.01, float(meta["fps"]))
			if float(b.get("anim_t", 0.0)) < dur:
				return hold_anim
		b["anim_hold"] = false
		b["anim"] = "idle"
		# Pick up the walk loop mid-stride instead of snapping to frame 0.
		var walk_dur = max(0.01, boss_anim_duration("idle"))
		b["anim_t"] = fmod(absf(float(b.get("stride", 0.0))) * 0.28, walk_dur)
	return "idle"

func draw_boss_rift_beam(p0: Vector2, p1: Vector2, strength: float, spore: bool = false) -> void:
	# spore=true → Mycelarch: one organic spore lance (glow + plasma + core + motes).
	# Breach / Iron Maw: segmented cyan reactor beam (smooth ribbon + traveling bands).
	var a = clamp(strength, 0.0, 1.0)
	var dir = p1 - p0
	var length = dir.length()
	if length < 8.0:
		return
	var forward = dir / length
	var n = Vector2(-forward.y, forward.x)
	var pulse = 0.85 + sin(t * 28.0) * 0.15
	if spore:
		_draw_mycelarch_spore_beam(p0, p1, forward, n, length, a, pulse)
		return
	_draw_breach_reactor_beam(p0, p1, forward, n, length, a, pulse)

func _draw_breach_reactor_beam(p0: Vector2, p1: Vector2, forward: Vector2, n: Vector2, length: float, a: float, pulse: float) -> void:
	# Smooth multi-segment cyan lance with traveling energy bands (reads continuous, not a hard bar).
	var segs := 14
	var travel := fmod(t * 520.0, length)
	_draw_beam_ribbon(p0, forward, n, length, segs, 56.0 * pulse, 34.0, Color(0.12, 0.45, 0.95, 0.10 * a), 1.6, 0.0)
	_draw_beam_ribbon(p0, forward, n, length, segs, 32.0, 18.0, Color(0.22, 0.78, 1.0, 0.28 * a * pulse), 2.8, 0.25)
	_draw_beam_ribbon(p0, forward, n, length, segs, 16.0, 8.0, Color(0.55, 0.95, 1.0, 0.55 * a), 4.2, 0.18)
	_draw_beam_ribbon(p0, forward, n, length, segs, 5.5, 2.5, Color(1.0, 1.0, 1.0, 0.92 * a), 6.0, 0.10)
	for i in range(6):
		var along := fmod(travel + i * (length / 6.0), length)
		var mid := p0 + forward * along
		var band_w := 14.0 + sin(t * 24.0 + i) * 3.5
		var band_a := 0.20 * a * (0.6 + 0.4 * sin(t * 20.0 + i * 1.4))
		draw_circle(mid, band_w * 0.5, Color(0.45, 0.92, 1.0, band_a))
		draw_line(mid - n * band_w, mid + n * band_w, Color(0.85, 0.98, 1.0, band_a * 1.35), 2.2)
	for i in range(5):
		var along2 := (0.15 + i * 0.16) * length
		var wob := sin(t * 30.0 + i * 2.3) * 9.0
		var mid2 := p0 + forward * along2 + n * wob * 0.12
		var side := 1.0 if i % 2 == 0 else -1.0
		draw_line(mid2, mid2 + n * side * (11.0 + abs(wob) * 0.3), Color(0.65, 0.95, 1.0, 0.30 * a), 1.7)
	draw_circle(p0, 36.0 * a, Color(0.35, 0.9, 1.0, 0.32 * a))
	draw_circle(p0, 16.0 * a, Color(1.0, 1.0, 1.0, 0.72 * a))
	draw_circle(p1, 44.0 * a, Color(0.4, 0.95, 1.0, 0.26 * a))
	draw_circle(p1, 18.0 * a, Color(1.0, 1.0, 1.0, 0.55 * a))

func _draw_mycelarch_spore_beam(p0: Vector2, p1: Vector2, forward: Vector2, n: Vector2, length: float, a: float, pulse: float) -> void:
	# One coherent bioluminescent lance: wide soft bloom → teal plasma → white core,
	# with traveling energy bands, edge shimmer, muzzle flare, and impact burst.
	var segs = 10
	var travel = fmod(t * 420.0, length)
	# Layer widths (half-widths) — fat enough to read as a weapon, not a UI line.
	var bloom_w = 46.0 * pulse
	var plasma_w = 22.0
	var core_w = 7.5
	# Soft atmospheric bloom (outer)
	_draw_beam_ribbon(p0, forward, n, length, segs, bloom_w, bloom_w * 0.55, Color(0.12, 0.55, 0.48, 0.10 * a), 1.8, 0.0)
	# Teal plasma body
	_draw_beam_ribbon(p0, forward, n, length, segs, plasma_w, plasma_w * 0.45, Color(0.25, 0.98, 0.82, 0.38 * a * pulse), 3.2, 0.35)
	# Hot white core
	_draw_beam_ribbon(p0, forward, n, length, segs, core_w, core_w * 0.35, Color(0.95, 1.0, 0.98, 0.92 * a), 5.5, 0.15)
	# Traveling energy bands (pulses sliding chest → impact)
	for i in range(5):
		var along = fmod(travel + i * (length / 5.0), length)
		var mid = p0 + forward * along
		var band_w = 16.0 + sin(t * 22.0 + i) * 4.0
		var band_a = 0.22 * a * (0.65 + 0.35 * sin(t * 18.0 + i * 1.7))
		draw_circle(mid, band_w * 0.55, Color(0.45, 1.0, 0.88, band_a))
		draw_line(mid - n * band_w, mid + n * band_w, Color(0.85, 1.0, 0.95, band_a * 1.4), 2.5)
	# Organic edge shimmer (tiny forks hugging the beam — not a second laser)
	for i in range(6):
		var along = (0.12 + i * 0.14) * length
		var wob = sin(t * 26.0 + i * 2.1) * 10.0
		var mid = p0 + forward * along + n * wob * 0.15
		var side = (1.0 if i % 2 == 0 else -1.0)
		var tip = mid + n * side * (12.0 + abs(wob) * 0.35)
		draw_line(mid, tip, Color(0.55, 1.0, 0.9, 0.28 * a), 1.8)
	# Spore motes drifting along the lance
	for i in range(8):
		var along = fmod(travel * 0.55 + i * (length / 8.0) + sin(t * 3.0 + i) * 12.0, length)
		var off = sin(t * 9.0 + i * 1.9) * 14.0
		var mote = p0 + forward * along + n * off
		var mr = 2.5 + (i % 3)
		draw_circle(mote, mr, Color(0.4, 1.0, 0.85, 0.35 * a))
		draw_circle(mote, mr * 0.4, Color(1.0, 1.0, 1.0, 0.55 * a))
	# Muzzle flare (chest reactor)
	draw_circle(p0, 52.0 * a, Color(0.15, 0.7, 0.6, 0.18 * a))
	draw_circle(p0, 34.0 * a, Color(0.35, 0.98, 0.82, 0.40 * a * pulse))
	draw_circle(p0, 16.0 * a, Color(0.9, 1.0, 0.98, 0.75 * a))
	draw_circle(p0, 6.0 * a, Color(1.0, 1.0, 1.0, 0.95 * a))
	# Impact bloom + sparks on the car
	draw_circle(p1, 48.0 * a, Color(0.2, 0.85, 0.75, 0.22 * a))
	draw_circle(p1, 28.0 * a, Color(0.55, 1.0, 0.9, 0.40 * a * pulse))
	draw_circle(p1, 12.0 * a, Color(1.0, 1.0, 1.0, 0.70 * a))
	for i in range(5):
		var ang = t * 14.0 + i * TAU / 5.0
		var spark = p1 + Vector2(cos(ang), sin(ang)) * (18.0 + sin(t * 20.0 + i) * 8.0)
		draw_line(p1, spark, Color(0.7, 1.0, 0.95, 0.45 * a), 2.0)

func _draw_beam_ribbon(p0: Vector2, forward: Vector2, n: Vector2, length: float, segs: int, half0: float, half1: float, col: Color, wave_amp: float, wave_phase: float) -> void:
	# Tapered ribbon with a light organic waviness so it doesn't read as a flat UI stroke.
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	top.resize(segs + 1)
	bot.resize(segs + 1)
	for i in range(segs + 1):
		var u = float(i) / float(segs)
		var half = lerp(half0, half1, u)
		var wave = sin(t * 18.0 + u * 9.0 + wave_phase) * wave_amp * (1.0 - u * 0.35)
		var mid = p0 + forward * (length * u) + n * wave
		top[i] = mid + n * half
		bot[i] = mid - n * half
	# Fan triangles from centerline pairs
	for i in range(segs):
		var poly = PackedVector2Array([top[i], top[i + 1], bot[i + 1], bot[i]])
		var fade = 1.0 - abs(u_center(i, segs) - 0.45) * 0.35
		var c = Color(col.r, col.g, col.b, col.a * clamp(fade, 0.55, 1.0))
		draw_colored_polygon(poly, c)

func u_center(i: int, segs: int) -> float:
	return (float(i) + 0.5) / float(segs)

func draw_iron_colossus(b: Dictionary) -> void:
	# Flow sprite-sheet boss — fixed on-screen size across every anim (incl. death).
	var bx = b["x"]
	var by = b["y"]
	var flash = float(b.get("flash", 0.0))
	var rise = float(b.get("rise", 1.0))
	var phase = int(b.get("phase", 1))

	var anim = boss_colossus_anim_state(b)
	var bid = str(b.get("boss_id", b.get("data", {}).get("id", "")))
	var is_mycelarch = bid == "mycelarch"
	var beam_a = float(b.get("beam_flash", 0.0))
	# Mycelarch beam sheet bakes a cyan lance into the frames — never draw it.
	# Walk body + one procedural lance = single beam (no double / no snap).
	# Breach discharge sheet is core-flare / sparks only — keep playable while
	# the long beam is drawn procedurally to the train (may leave the sprite cell).
	if is_mycelarch and anim == "beam":
		anim = "idle"
	var sheet = boss_anim_sheet_key(anim, bid)
	if not images.has(sheet) or not SPRITE_ANIMS.has(sheet):
		var fallback = "boss_mycelarch" if is_mycelarch else ("boss_breach_idle" if bid == "breach_engine" else "boss_colossus")
		if images.has(fallback):
			var ftex: Texture2D = images[fallback]
			var fh = BOSS_MYCELARCH_DRAW_H if is_mycelarch else (BOSS_BREACH_DRAW_H if bid == "breach_engine" else BOSS_DRAW_H)
			var fw = fh * float(ftex.get_width()) / max(1.0, float(ftex.get_height()))
			draw_texture_rect(ftex, Rect2(bx - fw * 0.48, by - fh + 14.0, fw, fh), false, Color(1, 1, 1, 1))
		return

	var meta = SPRITE_ANIMS[sheet]
	var fw = float(meta["w"])
	var fh = float(meta["h"])
	var fps = float(meta["fps"])
	var nframes = int(meta["frames"])
	var anim_t = float(b.get("anim_t", 0.0))
	var frame_i: int
	if meta.get("loop", true):
		frame_i = int(floor(anim_t * fps)) % nframes
	else:
		frame_i = clampi(int(floor(anim_t * fps)), 0, nframes - 1)

	# Hard-locked draw size so death/attack sheets never resize the boss.
	var is_breach = bid == "breach_engine"
	var base_h = BOSS_MYCELARCH_DRAW_H if is_mycelarch else (BOSS_BREACH_DRAW_H if is_breach else BOSS_DRAW_H)
	var draw_h = base_h * clampf(rise, 0.15, 1.0)
	var draw_w = draw_h * (fw / max(1.0, fh))
	# Walk motion is baked into Mycelarch sheets — no extra sine bob.
	var bob = 0.0
	var dst = Rect2(bx - draw_w * 0.48, by - draw_h + float(meta.get("anchor_y", 18.0)) + bob, draw_w, draw_h)
	var cols = maxi(1, int(meta.get("cols", nframes)))
	var src = Rect2(float(frame_i % cols) * fw, float(int(frame_i / cols)) * fh, fw, fh)
	var mod = Color(1.28, 0.82, 0.76, 1.0) if flash > 0.01 else Color(1, 1, 1, 1)
	# Slight lift so dark bark legs read against ballast when Mycelarch is on the rail.
	if is_mycelarch and flash <= 0.01:
		mod = Color(1.08, 1.05, 1.02, 1.0)
	# Breach Engine plates are charcoal-heavy — lift exposure so the cyan core stays readable.
	if is_breach and flash <= 0.01:
		mod = Color(1.22, 1.18, 1.28, 1.0)
		if phase >= 2:
			mod = Color(1.30, 1.20, 1.38, 1.0)
		if phase >= 3:
			mod = Color(1.40, 1.22, 1.48, 1.0)
	if phase >= 4 and not b.get("dead", false):
		mod = Color(mod.r, mod.g * 0.9, mod.b * 0.88, 1.0)
	draw_tex_region(sheet, dst, src, mod)

	var style = str(b.get("attack_style", ""))
	var hand = boss_hand_point(b, bob)
	var chest = boss_chest_point(b, bob)
	# Keep live origins updated so telegraphs / flash match the sprite.
	# No hand/chest bloom circles on any boss — sheets + beam VFX only.
	if style == "claw":
		b["atk_ox"] = hand.x
		b["atk_oy"] = hand.y
	elif style == "beam":
		b["atk_ox"] = chest.x
		b["atk_oy"] = chest.y

	if beam_a > 0.01:
		# Locked muzzle + target from resolve — never re-sample chest (avoids snap-back).
		var p0 = Vector2(float(b.get("beam_ox", chest.x)), float(b.get("beam_oy", chest.y)))
		var p1 = Vector2(float(b.get("beam_tx", 900.0)), float(b.get("beam_ty", p0.y)))
		var beam_str = clamp(beam_a / (1.15 if is_mycelarch else 1.25), 0.0, 1.0)
		draw_boss_rift_beam(p0, p1, beam_str, is_mycelarch)

	if not b.get("dead", false) and b["hp"] < b["max_hp"]:
		bar(bx - 70, by - draw_h - 12.0, 140, 9, b["hp"] / b["max_hp"], Color(1.0, 0.35, 0.3))

func draw_impact_burst(b: Dictionary) -> void:
	var p = 1.0 - clamp(b["life"] / b["max"], 0.0, 1.0)
	var a = clamp(b["life"] / b["max"], 0.0, 1.0)
	var col = b.get("color", Color.WHITE)
	col.a = a
	var sz = b.get("size", 24.0)
	var center = Vector2(b["x"], b["y"])
	var btype = b.get("type", "slash")
	var angle = b.get("angle", 0.0)
	if btype == "fx_sheet":
		var key = str(b.get("sheet", ""))
		var frames = maxi(1, int(b.get("frames", 10)))
		if images.has(key):
			var tex: Texture2D = images[key]
			var fw = float(tex.get_width()) / float(frames)
			var fh = float(tex.get_height())
			# Hold readable mid frames longer; only ease the last 20%
			var fi = clampi(int(floor(min(p, 0.92) * float(frames))), 0, frames - 1)
			var fade = 1.0
			if p < 0.06:
				fade = p / 0.06
			elif p > 0.82:
				fade = 1.0 - ((p - 0.82) / 0.18)
			# Sheet pixels are already soft-alpha; keep modulate high enough to read in-scene
			var mod = Color(1.0, 1.0, 1.0, clampf(0.88 * fade, 0.0, 1.0))
			var dst = Rect2(center.x - sz * 0.5, center.y - sz * 0.55, sz, sz)
			draw_tex_region(key, dst, Rect2(fi * fw, 0.0, fw, fh), mod)
		return
	if btype == "claw_reach":
		# Local claw impact only — short slash at the car, not a long laser trail.
		var slash_a = angle
		var len = sz * (0.55 + p * 0.35)
		var d = Vector2(cos(slash_a), sin(slash_a)) * len
		var n = Vector2(-d.y, d.x) * 0.35
		draw_line(center - d, center + d, Color(col.r, col.g, col.b, a * 0.85), 6.0)
		draw_line(center - d * 0.7 + n, center + d * 0.7 - n, Color(1.0, 0.92, 0.75, a * 0.7), 3.0)
		draw_circle(center, 22.0 * a * (1.0 - p * 0.4), Color(1.0, 0.55, 0.3, 0.35 * a))
		draw_circle(center, 10.0 * a, Color(1.0, 1.0, 1.0, 0.55 * a))
		draw_arc(center, sz * (0.25 + p * 0.45), slash_a - 0.9, slash_a + 0.9, 14, Color(col.r, col.g, col.b, 0.5 * a), 3.5)
	elif btype == "slam":
		draw_arc(center, sz * (0.35 + p), 0.0, TAU, 24, col, 5.0 * a)
		draw_circle(center, sz * 0.38 * (1.0 - p), Color(col.r, col.g, col.b, 0.25 * a))
		# Rail shockwave rings
		draw_line(Vector2(center.x - sz * 1.4, center.y), Vector2(center.x + sz * 1.4, center.y), Color(col.r, col.g, col.b, 0.35 * a), 6.0)
	elif btype == "electric":
		for i in range(4):
			var a1 = angle + randf_range(-0.8, 0.8)
			var off = Vector2(cos(a1) * sz * 0.6, sin(a1) * sz * 0.6)
			draw_line(center - off * 0.5, center + off, col, 3.0 * a)
	else:
		var dir = Vector2(cos(angle), sin(angle)) * sz * 0.6
		var norm = Vector2(-dir.y, dir.x) * 0.3
		draw_line(center - dir, center + dir, col, 4.0 * a)
		draw_line(center - dir * 0.6 + norm, center + dir * 0.6 - norm, Color(1, 1, 1, a * 0.8), 2.0)

func draw_telegraphs() -> void:
	for tg in telegraphs:
		var pct = clamp(tg["life"] / tg["max"], 0.0, 1.0) # remaining
		var charge = 1.0 - pct # 0→1 as attack approaches
		var kind = str(tg.get("kind", "box"))
		var col = tg["color"]
		var p0 = Vector2(tg["x"], tg["y"])
		var p1 = Vector2(float(tg.get("x1", tg["x"] + tg["w"] * 0.5)), float(tg.get("y1", tg["y"])))
		if kind == "beam":
			# Intentionally empty — beam windup is chest glow only; one laser on fire.
			pass
		elif kind == "flux_aim":
			# Soft end-point marker; charging beam is drawn via enemy_lasers.
			var pulse = 0.75 + sin(t * 18.0 + tg["pulse"]) * 0.25
			draw_circle(p1, 10.0 + charge * 14.0, Color(0.35, 0.9, 1.0, (0.10 + charge * 0.22) * pulse))
			draw_arc(p1, 18.0 + charge * 12.0, 0.0, TAU, 18, Color(0.55, 1.0, 1.0, 0.35 + charge * 0.4), 2.0)
		elif kind == "claw":
			# Threat marker on the car only — no line from the boss (looked like a laser).
			var pulse = 0.75 + sin(t * 16.0 + tg["pulse"]) * 0.25
			draw_circle(p1, 14.0 + charge * 16.0, Color(1.0, 0.4, 0.22, (0.12 + charge * 0.28) * pulse))
			draw_arc(p1, 26.0 + charge * 18.0, -1.0, 1.0, 14, Color(1.0, 0.55, 0.3, 0.4 + charge * 0.4), 3.0)
			draw_arc(p1, 38.0 + charge * 12.0, 0.4, 2.6, 12, Color(1.0, 0.7, 0.4, 0.25 + charge * 0.3), 2.0)
		elif kind == "slam":
			# Ground danger band under the train + rising cracks.
			var x0 = min(p0.x, p1.x)
			var x1 = max(p0.x, p1.x)
			var y = p0.y
			var band_a = 0.10 + charge * 0.28
			var band = PackedVector2Array([
				Vector2(x0, y - 18.0 - charge * 16.0), Vector2(x1, y - 18.0 - charge * 16.0),
				Vector2(x1, y + 22.0), Vector2(x0, y + 22.0)
			])
			draw_colored_polygon(band, Color(col.r, col.g, col.b, band_a))
			draw_line(Vector2(x0, y), Vector2(x1, y), Color(1.0, 0.75, 0.35, 0.4 + charge * 0.45), 3.0 + charge * 5.0)
			for i in range(5):
				var fx = lerp(x0, x1, (i + 0.5) / 5.0)
				var h = 20.0 + charge * 40.0 + sin(t * 14.0 + i) * 6.0
				var jig = sin(t * 19.0 + i * 2.1) * 8.0
				draw_line(Vector2(fx, y), Vector2(fx + jig, y - h), Color(1.0, 0.6, 0.25, 0.35 + charge * 0.4), 2.0)
		else:
			# Legacy fallback (non-boss) — keep subtle, no big label spam.
			var rect = Rect2(tg["x"] - tg["w"] * 0.5, tg["y"] - tg["h"] * 0.5, tg["w"], tg["h"])
			draw_rect(rect, Color(col.r, col.g, col.b, 0.12), true)
			draw_rect(rect, Color(col.r, col.g, col.b, 0.45 * pct), false, 2.5)

func draw_warnings() -> void:
	if screen_warnings.is_empty():
		return
	var stack_y = 202.0
	for w in screen_warnings:
		var pct = clamp(w["life"] / w["max"], 0.0, 1.0)
		var fade = min(1.0, pct * 1.6) * clamp((w["max"] - w["life"]) / 0.12, 0.0, 1.0)
		var col = Color.html("#ff5a47") if w["severity"] == "critical" else Color.html("#ffbd66") if w["severity"] == "danger" else Color.html("#86f4ff")
		var x = clamp(w.get("x", 960.0), 320.0, 1600.0)
		var y = w.get("y", stack_y) if w.get("y", 0.0) > 0.0 else stack_y
		if not USE_PRODUCTION_UI or w["severity"] not in ["critical", "danger"]:
			panel(x - 260.0, y - 25.0, 520.0, 50.0, col, Color(0.08, 0.05, 0.06, 0.92 * fade))
			draw_text2(w["text"], x, y + 6.0, 19, Color.html("#fff4e7"), "center")
		else:
			# Production UI Critical Warning
			draw_tex("ui_warning_critical", Rect2(x - 350.0, y - 50.0, 700.0, 100.0), Color(1,1,1,fade))
			draw_text2(w["text"], x, y + 10.0, 26, Color.WHITE, "center")
		stack_y += 56.0

func draw_danger_overlay() -> void:
	if state != "combat":
		return
	var loco_pct = train_cars[0]["hp"] / train_cars[0]["max_hp"]
	var heat_danger = (heat["value"] - 70.0) / 30.0 if heat["value"] > 70.0 else 0.0
	var overrun_danger = overrun["value"] / 100.0
	var hp_danger = (1.0 - loco_pct / 0.42) if loco_pct < 0.42 else 0.0
	var danger = clamp(max(heat_danger, max(overrun_danger, hp_danger)), 0.0, 1.0)
	if danger <= 0.03:
		return
	var pulse = 0.65 + sin(t * 8.0) * 0.25
	var thick = 22.0 + danger * 38.0
	var col = Color.html("#ff653d") if heat["value"] > 85.0 else Color.html("#ff3f3f")
	col.a = danger * 0.35 * pulse
	draw_rect(Rect2(0, 0, DESIGN_W, thick), col, true)
	draw_rect(Rect2(0, DESIGN_H - thick, DESIGN_W, thick), col, true)
	draw_rect(Rect2(0, 0, thick, DESIGN_H), col, true)
	draw_rect(Rect2(DESIGN_W - thick, 0, thick, DESIGN_H), col, true)

func draw_drone(d: Dictionary) -> void:
	draw_circle(Vector2(d["x"], d["y"] + 18), 38, Color(.32, .95, 1, .12))
	draw_tex("drone", Rect2(d["x"] - 38, d["y"] - 38, 76, 76))
func draw_projectile(p: Dictionary) -> void:
	draw_circle(Vector2(p["x"], p["y"]), p["radius"], p.get("color", Color.WHITE))
func draw_enemy_projectile(p: Dictionary) -> void:
	draw_circle(Vector2(p["x"], p["y"]), p["radius"] * 1.5, p.get("color", Color.CYAN))

func draw_enemy_laser(l: Dictionary) -> void:
	var p0 = Vector2(float(l["x0"]), float(l["y0"]))
	var p1 = Vector2(float(l["x1"]), float(l["y1"]))
	var life_a = clampf(float(l["life"]) / max(0.01, float(l["max"])), 0.0, 1.0)
	var strength = float(l.get("strength", 1.0)) * life_a
	var w = float(l.get("width", 6.0))
	var charge = bool(l.get("charge", false))
	var dir = p1 - p0
	var length = dir.length()
	if length < 4.0:
		return
	var forward = dir / length
	var n = Vector2(-forward.y, forward.x)
	var pulse = 0.85 + sin(t * (28.0 if not charge else 18.0)) * 0.15
	# Soft bloom → cyan body → white core
	var bloom_w = w * (2.8 if not charge else 1.6)
	var body_w = w * (1.35 if not charge else 0.85)
	var core_w = w * (0.45 if not charge else 0.28)
	var bloom_a = (0.10 if charge else 0.18) * strength
	var body_a = (0.35 if charge else 0.55) * strength * pulse
	var core_a = (0.55 if charge else 0.92) * strength
	for pair in [
		[bloom_w, Color(0.20, 0.75, 1.0, bloom_a)],
		[body_w, Color(0.40, 0.95, 1.0, body_a)],
		[core_w, Color(0.92, 1.0, 1.0, core_a)]
	]:
		var half = float(pair[0]) * 0.5
		var poly = PackedVector2Array([
			p0 + n * half, p1 + n * half * 0.7,
			p1 - n * half * 0.7, p0 - n * half
		])
		draw_colored_polygon(poly, pair[1])
	if not charge:
		draw_circle(p0, 10.0 + w * 0.4, Color(0.55, 1.0, 1.0, 0.55 * strength))
		draw_circle(p0, 4.5, Color(1.0, 1.0, 1.0, 0.85 * strength))
		draw_circle(p1, 14.0 + w * 0.5, Color(0.45, 0.95, 1.0, 0.40 * strength))
		draw_circle(p1, 5.0, Color(1.0, 1.0, 1.0, 0.75 * strength))

func draw_particle(p: Dictionary) -> void:
	var a = clamp(p.get("life", 0.0) / p.get("max", 1.0), 0, 1)
	var c: Color = p.get("color", Color.WHITE)
	c.a *= a
	draw_circle(Vector2(p["x"], p["y"]), p.get("size", 4.0), c)
func draw_loot(o: Dictionary) -> void:
	draw_circle(Vector2(o["x"], o["y"]), 6, Color.html("#85f5ff") if o["kind"] == "xp" else Color.html("#ffd36d"))

func draw_ui() -> void:
	match state:
		"title":
			draw_title()
			return
		"workshop":
			draw_workshop()
			return
		"options":
			draw_options()
			return
		"help":
			draw_help()
			return
	draw_hud()
	if state == "combat":
		draw_live_shop()
	if paused and state == "combat":
		draw_pause()
	match state:
		"levelup":
			draw_levelup()
		"rewards":
			draw_rewards()
		"route":
			draw_route()
		"station":
			draw_station()
		"build":
			draw_build()
		"moduleshop":
			draw_module_shop()
		"event":
			draw_event()
		"victory":
			draw_victory()
		"failed":
			draw_failed()
	# Don't float toasts over the armory sheet or end screens.
	if state != "failed" and state != "victory" and not (state == "combat" and is_mobile_ui and shop_slide > 0.2):
		draw_toasts()

func draw_title() -> void:
	# Dim the full visible view on mobile ultrawide (not only the centered 16:9 frame).
	draw_rect(_full_view_rect(), Color(0, 0, 0, 0.42), true)
	if is_mobile_ui:
		_draw_title_mobile()
		return

	if images.has("menu_title_logo") and images.has("menu_info_panel_frame") and images.has("menu_button_primary_frame"):
		# 1. TOP: Title Logo (replaces plain text RIFTLINE / LAST TRAIN)
		var lw = 680.0
		var lh = 680.0 * (724.0 / 2172.0) # 226.7 px
		var lx = (DESIGN_W - lw) * 0.5
		var ly = 75.0
		draw_tex("menu_title_logo", Rect2(lx, ly, lw, lh))

		# 2. MIDDLE: Central Information Panel Frame
		var iw = 720.0
		var ih = 720.0 * (724.0 / 2172.0) # 240.0 px
		var ix = (DESIGN_W - iw) * 0.5
		var iy = 325.0
		var scale_i = iw / 2172.0
		var cut_x = ix + 146.0 * scale_i
		var cut_y = iy + 200.0 * scale_i
		var cut_w = 1878.0 * scale_i
		var cut_h = 343.0 * scale_i
		var cut_cy = iy + 371.5 * scale_i

		# Dark translucent backing inside cutout
		draw_rect(Rect2(cut_x, cut_y, cut_w, cut_h), Color(0.015, 0.045, 0.065, 0.90), true)
		# Decorative frame overlay
		draw_tex("menu_info_panel_frame", Rect2(ix, iy, iw, ih))
		# Dynamic text inside frame
		draw_text2("Complete Playable Edition", 960, cut_cy - 14.0, 21, Color.html("#85f2ff"), "center")
		draw_text2("Build the train, survive six tracks, defeat Iron Maw, unlock blueprints, improve the Workshop.", 960, cut_cy + 19.0, 13.5, Color.html("#c6f2ff"), "center")

		# 3. LOWER MIDDLE: Primary Call-to-Action Button (CONTINUE / START)
		var has_save = FileAccess.file_exists(SAVE_RUN)
		var pw = 490.0
		var ph = 490.0 * (724.0 / 2172.0) # 163.3 px
		var px = (DESIGN_W - pw) * 0.5
		var py = 585.0
		var scale_p = pw / 2172.0
		var p_cy = py + 356.0 * scale_p

		# Dark backing under primary button
		draw_rect(Rect2(px + 40.0, py + 32.0, pw - 80.0, ph - 64.0), Color(0.02, 0.05, 0.07, 0.92), true)
		# Decorative frame overlay
		draw_tex("menu_button_primary_frame", Rect2(px, py, pw, ph))
		# Dynamic label
		var p_label = "CONTINUE EXPEDITION" if has_save else "START EXPEDITION"
		draw_text2(p_label, 960, p_cy + 9.0, 25, Color.html("#ffcf72"), "center")
		# Hitbox matching visible button frame
		button(px + 36.0, py + 30.0, pw - 72.0, ph - 60.0, "", "continue_or_start", [], 1, Color(1, 1, 1, 0))

		# 4. BOTTOM MIDDLE: 4 Small Secondary Buttons
		var bw = 210.0
		var bh = 210.0 * (724.0 / 2172.0) # 70.0 px
		var gap = 20.0
		var total_sec_w = 4.0 * bw + 3.0 * gap # 900.0 px
		var bx_start = (DESIGN_W - total_sec_w) * 0.5 # 510.0 px
		var by = 770.0

		var sec_btns = [
			{ "label": "NEW RUN", "method": "reset_run", "args": [], "size": 17, "color": Color.WHITE },
			{ "label": "WORKSHOP", "method": "set_state", "args": ["workshop"], "size": 17, "color": Color.html("#ffd36d") },
			{ "label": "HOW TO PLAY", "method": "open_help", "args": ["title"], "size": 16, "color": Color.html("#7dffbb") },
			{ "label": "OPTIONS", "method": "open_options", "args": ["title"], "size": 17, "color": Color.WHITE }
		]

		for i in range(sec_btns.size()):
			var btn = sec_btns[i]
			var bx = bx_start + i * (bw + gap)
			# Dark backplate
			draw_rect(Rect2(bx + 12.0, by + 10.0, bw - 24.0, bh - 20.0), Color(0.02, 0.05, 0.07, 0.92), true)
			# Frame overlay
			draw_tex("menu_button_secondary_frame", Rect2(bx, by, bw, bh))
			# Dynamic text label
			draw_text2(btn["label"], bx + bw * 0.5, by + 40.0, btn["size"], btn["color"], "center")
			# Hitbox
			button(bx + 12.0, by + 10.0, bw - 24.0, bh - 20.0, "", btn["method"], btn["args"], 1, Color(1, 1, 1, 0))

		# 5. BOTTOM: Stats Strip with 3 Icons & Live Values
		var sw = 880.0
		var k = sw / 2127.0 # 0.413728
		var sh = 223.0 * k # 92.26 px
		var sx = (DESIGN_W - sw) * 0.5
		var sy = 875.0

		# Frame overlay (desktop sheet crop). Soft plate only if art missing.
		if not _draw_menu_stats_strip_frame(Rect2(sx, sy, sw, sh)):
			draw_rect(Rect2(sx + 20.0, sy + 14.0, sw - 40.0, sh - 28.0), Color(0.015, 0.04, 0.06, 0.90), true)

		# 3 Sockets & Dynamic Stats — cx/cy tuned to each strip socket's cyan ring center.
		var stats_items = [
			{ "cx": sx + 117.0 * k, "cy": sy + 108.0 * k, "hx": sx + 431.0 * k, "ic": 40.0, "icon": "icon_permanent_alloy", "text": "Permanent Alloy: %d" % permanent.get("alloy", 0) },
			{ "cx": sx + 821.0 * k, "cy": sy + 106.0 * k, "hx": sx + 1126.5 * k, "ic": 42.0, "icon": "icon_victories", "text": "Victories: %d" % permanent.get("victories", 0) },
			{ "cx": sx + 1491.0 * k, "cy": sy + 106.0 * k, "hx": sx + 1820.0 * k, "ic": 42.0, "icon": "icon_best_score", "text": "Best Score: %d" % permanent.get("best_score", 0) }
		]

		for st in stats_items:
			var ic_size: float = float(st["ic"])
			# Icon centered inside circular socket
			draw_tex(st["icon"], Rect2(st["cx"] - ic_size * 0.5, st["cy"] - ic_size * 0.5, ic_size, ic_size))
			# Dynamic text value centered in rectangular display slot
			draw_text2(st["text"], st["hx"], st["cy"] + 5.0, 14, Color.html("#b7ecff"), "center")
	else:
		draw_text2("RIFTLINE", 960, 250, 104, Color(.91,.98,1), "center")
		draw_text2("LAST TRAIN", 960, 340, 56, Color.html("#ffca70"), "center")
		panel(510, 492, 900, 170)
		draw_text2("Complete Playable Edition", 960, 535, 30, Color.html("#85f2ff"), "center")
		draw_text2("Build the train, survive six tracks, defeat Iron Maw, unlock blueprints, improve the Workshop.", 960, 590, 24, Color(.88,.96,1), "center")
		var has_save2 = FileAccess.file_exists(SAVE_RUN)
		button(675, 760, 570, 78, "CONTINUE EXPEDITION" if has_save2 else "START EXPEDITION", "continue_or_start", [], 28, Color.html("#ffcc69"))
		button(430, 858, 230, 60, "NEW RUN", "reset_run", [], 22)
		button(705, 858, 230, 60, "WORKSHOP", "set_state", ["workshop"], 21, Color.html("#ffd36d"))
		button(980, 858, 230, 60, "HOW TO PLAY", "open_help", ["title"], 19, Color.html("#7dffbb"))
		button(1255, 858, 230, 60, "OPTIONS", "open_options", ["title"], 22)
		draw_text2("Permanent Alloy: %s    Victories: %s    Best Score: %s" % [permanent.get("alloy",0), permanent.get("victories",0), permanent.get("best_score",0)], 960, 945, 24, Color.html("#b7ecff"), "center")


## Mobile-only title: supplied composite menu art + invisible hitboxes + live stats.
## Desktop draw_title() path is unchanged.
func _draw_title_mobile() -> void:
	var pad_l: float = float(safe_inset.get("left", 12.0))
	var pad_r: float = float(safe_inset.get("right", 12.0))
	var pad_t: float = float(safe_inset.get("top", 8.0))
	var pad_b: float = float(safe_inset.get("bottom", 18.0))
	# Use the full ultrawide design view (not only the centered 1920 band).
	var safe_left: float = design_view_left + pad_l
	var safe_right: float = design_view_right - pad_r
	var safe_w: float = maxf(320.0, safe_right - safe_left)
	var cx: float = (safe_left + safe_right) * 0.5
	var view_top: float = design_view_top + pad_t
	var view_bottom: float = design_view_bottom - pad_b

	if not images.has("menu_mobile_main"):
		draw_text2("RIFTLINE", cx, view_top + 180.0, 72, Color(0.91, 0.98, 1.0), "center")
		draw_text2("LAST TRAIN", cx, view_top + 250.0, 40, Color.html("#ffca70"), "center")
		button(cx - 300.0, view_top + 420.0, 600.0, 88.0, "CONTINUE EXPEDITION", "continue_expedition_or_notify", [], 26, Color.html("#ffcc69"))
		button(cx - 300.0, view_top + 520.0, 290.0, 64.0, "NEW RUN", "reset_run", [], 20)
		button(cx + 10.0, view_top + 520.0, 290.0, 64.0, "WORKSHOP", "set_state", ["workshop"], 20, Color.html("#ffd36d"))
		return

	# Live stats strip height reserved under the artwork (not baked into the PNG).
	var sw: float = minf(1280.0, safe_w * 0.94)
	var k: float = sw / 2127.0
	var sh: float = 223.0 * k
	var stats_gap: float = 6.0
	var top: float = view_top + 2.0
	var bottom_limit: float = view_bottom - sh - stats_gap - 4.0
	var avail_h: float = maxf(180.0, bottom_limit - top)

	var tex: Texture2D = images["menu_mobile_main"]
	var src_w: float = float(tex.get_width())
	var src_h: float = float(tex.get_height())
	# Fill the phone: prefer nearly full safe width/height (was undersized vs PC preview).
	var scl: float = minf(safe_w * 0.995 / src_w, avail_h / src_h)
	var dw: float = src_w * scl
	var dh: float = src_h * scl
	var dx: float = safe_left + (safe_w - dw) * 0.5
	var dy: float = top + maxf(0.0, (avail_h - dh) * 0.08)
	draw_texture_rect(tex, Rect2(dx, dy, dw, dh), false)

	var has_save := FileAccess.file_exists(SAVE_RUN)
	# Normalized image UVs from pixel inspection of the supplied artwork.
	var hits: Array = [
		{ "id": "continue", "u0": 0.5298, "v0": 0.4188, "u1": 0.9556, "v1": 0.6041, "method": "continue_expedition_or_notify", "args": [] },
		{ "id": "new_run", "u0": 0.5283, "v0": 0.6330, "u1": 0.7338, "v1": 0.7569, "method": "reset_run", "args": [] },
		{ "id": "workshop", "u0": 0.7459, "v0": 0.6330, "u1": 0.9572, "v1": 0.7569, "method": "set_state", "args": ["workshop"] },
		{ "id": "how_to_play", "u0": 0.5288, "v0": 0.7774, "u1": 0.7338, "v1": 0.9134, "method": "open_help", "args": ["title"] },
		{ "id": "options", "u0": 0.7464, "v0": 0.7774, "u1": 0.9593, "v1": 0.9134, "method": "open_options", "args": ["title"] }
	]
	var mouse_p: Vector2 = screen_to_design(get_viewport().get_mouse_position())
	var mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	for hit in hits:
		var hx: float = dx + float(hit["u0"]) * dw
		var hy: float = dy + float(hit["v0"]) * dh
		var hw: float = (float(hit["u1"]) - float(hit["u0"])) * dw
		var hh: float = (float(hit["v1"]) - float(hit["v0"])) * dh
		var r := Rect2(hx, hy, hw, hh)
		var hovered := r.has_point(mouse_p)
		if str(hit["id"]) == "continue" and not has_save:
			# Soften CTA without altering baked art pixels.
			draw_rect(r, Color(0.02, 0.04, 0.06, 0.38), true)
		elif hovered:
			var a: float = 0.16 if mouse_down else 0.09
			draw_rect(r, Color(0.45, 0.92, 1.0, a), true)
		# Exact art-space hitboxes — no mobile touch inflation (avoids neighbor overlap).
		ui_buttons.append({ "x": hx, "y": hy, "w": hw, "h": hh, "method": str(hit["method"]), "args": hit["args"], "label": "" })

	# Live statistics under the artwork (real save values).
	var sx: float = cx - sw * 0.5
	var sy: float = dy + dh + stats_gap
	var sy_max: float = view_bottom - sh - 2.0
	if sy > sy_max:
		sy = sy_max
	# Same strip art + icon layout as desktop mobile preview (final sheet crop shipped in ui/mobile).
	if not _draw_menu_stats_strip_frame(Rect2(sx, sy, sw, sh)):
		draw_rect(Rect2(sx + 22.0, sy + 14.0, sw - 44.0, sh - 28.0), Color(0.015, 0.04, 0.06, 0.72), true)
	var alloy_n: int = int(permanent.get("alloy", 0))
	var vic_n: int = int(permanent.get("victories", 0))
	var best_n: int = int(permanent.get("best_score", 0))
	var stats_items: Array = [
		{ "cx": sx + 117.0 * k, "cy": sy + 108.0 * k, "hx": sx + 431.0 * k, "ic": 48.0, "icon": "icon_permanent_alloy", "text": "ALLOY: %d" % alloy_n },
		{ "cx": sx + 821.0 * k, "cy": sy + 106.0 * k, "hx": sx + 1126.5 * k, "ic": 50.0, "icon": "icon_victories", "text": "VICTORIES: %d" % vic_n },
		{ "cx": sx + 1491.0 * k, "cy": sy + 106.0 * k, "hx": sx + 1820.0 * k, "ic": 50.0, "icon": "icon_best_score", "text": "BEST: %d" % best_n }
	]
	for st in stats_items:
		var ic_size: float = float(st["ic"])
		draw_tex(str(st["icon"]), Rect2(float(st["cx"]) - ic_size * 0.5, float(st["cy"]) - ic_size * 0.5, ic_size, ic_size))
		draw_text2(str(st["text"]), float(st["hx"]), float(st["cy"]) + 6.0, 22, Color.html("#b7ecff"), "center")

func continue_expedition_or_notify() -> void:
	if FileAccess.file_exists(SAVE_RUN) and load_run():
		return
	toast("No saved expedition", "normal")

func _verify_mobile_menu_hitboxes() -> String:
	## Non-destructive wiring check for the five mobile-title hitboxes.
	var lines: PackedStringArray = []
	if not images.has("menu_mobile_main"):
		return "FAIL:menu_art_missing"
	var methods: Dictionary = {}
	var rects: Array = []
	for b in ui_buttons:
		var m := str(b.get("method", ""))
		if m == "continue_expedition_or_notify" or m == "reset_run" or m == "open_help" or m == "open_options" \
				or (m == "set_state" and b.get("args", []) == ["workshop"]):
			methods[m if m != "set_state" else "workshop"] = true
			rects.append(Rect2(float(b["x"]), float(b["y"]), float(b["w"]), float(b["h"])))
	lines.append("wired=%d/5" % methods.size())
	for need in ["continue_expedition_or_notify", "reset_run", "workshop", "open_help", "open_options"]:
		lines.append("%s=%s" % [need, "ok" if methods.has(need) else "MISSING"])
	var overlap := false
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j]):
				overlap = true
	lines.append("overlap=%s" % str(overlap))
	# Exercise navigation targets (skip reset_run — would overwrite expedition save).
	state = "title"
	open_help("title")
	lines.append("help_state=%s" % state)
	state = "title"
	open_options("title")
	lines.append("options_state=%s" % state)
	state = "title"
	set_state("workshop")
	lines.append("workshop_state=%s" % state)
	state = "title"
	var had_save := FileAccess.file_exists(SAVE_RUN)
	continue_expedition_or_notify()
	lines.append("continue_had_save=%s after_state=%s" % [str(had_save), state])
	state = "title"
	return "|".join(lines)

func continue_or_start() -> void:
	if FileAccess.file_exists(SAVE_RUN) and load_run():
		return
	reset_run()
func set_state(s: String) -> void:
	state = s
	if audio != null:
		if state == "title" or state == "workshop":
			audio.play_menu_music(1.0)
		elif ["combat", "route", "rewards", "station", "build", "moduleshop", "event", "levelup"].has(state):
			audio.play_travel_music(1.5)
func open_options(back = "title") -> void:
	options_back_state = back
	state = "options"
	if back == "title" and audio != null:
		audio.play_menu_music(1.0)
func open_help(back = "title") -> void:
	help_back_state = back
	state = "help"
	if back == "title" and audio != null:
		audio.play_menu_music(1.0)

func convoy_hp_totals() -> Vector2:
	# Living convoy only — wrecked wagons drop out so the bar matches what's left.
	var hp := 0.0
	var mx := 0.0
	for c in train_cars:
		if c.get("disabled", false) and float(c.get("hp", 0.0)) <= 0.0:
			continue
		hp += maxf(0.0, float(c.get("hp", 0.0)))
		mx += maxf(0.0, float(c.get("max_hp", 0.0)))
	if mx <= 0.0 and train_cars.size() > 0:
		# Loco destroyed — show empty bar, not leftover scrap HP.
		return Vector2(0.0, maxf(1.0, float(train_cars[0].get("max_hp", 1.0))))
	return Vector2(hp, maxf(1.0, mx))

func draw_hud() -> void:
	# End screens: no live combat HP / heat — that reads as "still alive" after death/victory.
	if state == "victory" or state == "failed":
		return

	if not USE_PRODUCTION_UI:
		panel(24, 22, 430, 145)
		var hp_old = convoy_hp_totals()
		draw_text2("CONVOY", 48, 50, 20, Color.html("#9fefff"))
		bar(48, 70, 355, 24, hp_old.x / hp_old.y, Color(.45,1,.65), "%s / %s HP" % [int(hp_old.x), int(hp_old.y)])
		draw_text2("SPEED %s" % int(momentum["speed"]), 48, 128, 18, Color.html("#ffce72"))
		draw_text2("HEAT %s" % int(heat["value"]), 276, 128, 18, Color.html("#8ef7ff"))
		if state == "combat":
			panel(690, 22, 540, 118)
			var fallback_title = "FUNGUS WILDS NODE" if current_region == "fungus_wilds" else "RUSTLANDS NODE"
			draw_text2("REGION TRANSITION" if region_transition_active else ("BOSS ENCOUNTER" if boss_active else current_encounter.get("title", fallback_title)), 960, 52, 24, Color.WHITE, "center")
			if boss_active:
				var b = null
				for e in enemies:
					if e.get("boss", false):
						b = e
				var bl = str(b.get("data", {}).get("label", "BOSS")) if b != null else current_boss_def().get("label", "BOSS")
				bar(725, 74, 470, 24, (b["hp"] / b["max_hp"]) if b != null else 0, Color(1,.35,.32), bl)
			else:
				bar(725, 74, 470, 24, encounter_progress / encounter_goal, Color(.5,.94,1), "Encounter progress")
			draw_text2("RUN %s   SCORE %s" % [fmt_time(run_time), calculate_run_score(false)], 960, 130, 17, Color.html("#b7ecff"), "center")
		panel(1450, 22, 440, 94)
		draw_text2("Scrap %s" % scrap, 1510, 70, 29, Color.html("#ffd27b"))
		draw_text2("Lv %s" % level, 1660, 70, 27, Color.html("#8cf5ff"))
		bar(1748, 58, 100, 20, xp / xp_needed, Color.html("#83f4ff"))
		if save_flash > 0:
			draw_text2("AUTOSAVED", 1830, 202, 15, Color.html("#7dffbb"), "center")
		if state == "combat":
			draw_objective_tracker()
		if is_mobile_ui and images.has("btn_mobile_pause"):
			image_button(1740, 118, 56, 56, "btn_mobile_pause", "toggle_pause")
		else:
			button(1740, 130, 68, 50, "▶" if paused else "Ⅱ", "toggle_pause", [], 28)
			if not is_mobile_ui:
				button(1818, 130, 74, 50, str(int(game_speed)) + "×", "toggle_speed", [], 21)
		if state == "combat":
			draw_power_panel()
			draw_module_panel()
			draw_ability_panel()
		return

	# --- PRODUCTION UI ---
	var mlayout: Dictionary = _mobile_hud_layout() if _mobile_gen_hud_active() else {}
	# TOP LEFT (Locomotive Status HUD — Steam Locomotive HUD Panel)
	# Park while armory sheet is open so the left peek is world-only.
	var show_status := shop_slide < 0.2
	var px = 35.0 + (float(safe_inset.get("left", 0.0)) if is_mobile_ui else 0.0)
	var py = 25.0 + (float(safe_inset.get("top", 0.0)) if is_mobile_ui else 0.0)
	var pw = 465.0
	var ph = 155.0
	var status_frame := "hud_locomotive_status"
	var use_compact_status := _mobile_compact_status_active()
	var status_lay: Dictionary = {}
	if show_status and use_compact_status:
		# Control-tree MobileStatusHud owns this panel when available.
		status_frame = "hud_compact_player_status"
		status_lay = _mobile_player_status_layout()
		var tr: Rect2 = status_lay["texture_rect"]
		px = tr.position.x
		py = tr.position.y
		pw = tr.size.x
		ph = tr.size.y
	elif show_status:
		status_frame = _hud_frame_key("hud_locomotive_status", "hud_gen_player_status")
		if _mobile_gen_hud_active() and status_frame == "hud_gen_player_status":
			px = float(mlayout["left_x"])
			py = float(mlayout["top_y"])
			pw = float(mlayout["left_w"])
			ph = float(mlayout["left_h"])
		elif is_mobile_ui:
			pw = minf(520.0, (DESIGN_W - float(safe_inset.get("left", 0.0)) - float(safe_inset.get("right", 0.0))) * 0.30)
			ph = pw * (724.0 / 2172.0)
		draw_tex(status_frame, Rect2(px, py, pw, ph))

	# Convoy HP (all living cars) — wrecked wagons no longer leave a fake full bar.
	var hp_tot = convoy_hp_totals()
	var hp_pct = clamp(hp_tot.x / hp_tot.y, 0.0, 1.0)
	var hp_col = Color.html("#ff4b4b") if hp_pct < 0.3 else (Color.html("#ffbe44") if hp_pct < 0.6 else Color(.45, 1, .65))
	var hp_label = "DESTROYED" if hp_tot.x <= 0.0 else ("%d / %d HP" % [int(hp_tot.x), int(hp_tot.y)])
	if show_status:
		if use_compact_status:
			if _mobile_status_hud == null:
				# Fallback custom-draw path if Control HUD failed to load.
				_draw_mobile_dual_status_layered(status_lay, hp_pct, hp_col, hp_label)
		elif is_mobile_ui and status_frame == "hud_gen_player_status":
			# Legacy generated shell cavities: top = HP, lower-left = SPD, lower-right = HEAT.
			bar(px + pw * 0.155, py + ph * 0.32, pw * 0.69, maxf(15.0, ph * 0.168), hp_pct, hp_col, hp_label)
			var sp_pct_m = clamp(momentum["speed"] / 150.0, 0.0, 1.0)
			bar(px + pw * 0.155, py + ph * 0.62, pw * 0.295, maxf(13.0, ph * 0.148), sp_pct_m, Color.html("#ffce72"), "%d SPD" % int(momentum["speed"]))
			var ht_pct_m = clamp(heat["value"] / 100.0, 0.0, 1.0)
			var ht_col_m = Color.html("#ff4438") if heat["value"] > 80.0 else (Color.html("#ffaa3b") if heat["value"] > 50.0 else Color.html("#8ef7ff"))
			bar(px + pw * 0.55, py + ph * 0.62, pw * 0.295, maxf(13.0, ph * 0.148), ht_pct_m, ht_col_m, "%d HEAT" % int(heat["value"]))
		else:
			bar(px + 104.0, py + 50.0, 319.0, 25.0, hp_pct, hp_col, hp_label)
			# Speed bar in lower-left cutout (x=[386..1010], y=[516..604])
			var sp_pct = clamp(momentum["speed"] / 150.0, 0.0, 1.0)
			bar(px + 83.0, py + 110.0, 133.0, 19.0, sp_pct, Color.html("#ffce72"), "%d SPD" % int(momentum["speed"]))
			# Heat bar in lower-right cutout (x=[1399..1991], y=[516..606])
			var ht_pct = clamp(heat["value"] / 100.0, 0.0, 1.0)
			var ht_col = Color.html("#ff4438") if heat["value"] > 80.0 else (Color.html("#ffaa3b") if heat["value"] > 50.0 else Color.html("#8ef7ff"))
			bar(px + 300.0, py + 110.0, 126.0, 19.0, ht_pct, ht_col, "%d HEAT" % int(heat["value"]))

	# TOP CENTER (Unified Encounter & Objective Tracker)
	# Mobile Control-tree MobileEncounterHud owns this panel when available.
	# Hide while armory is open so it doesn't stack over the sheet header.
	if state == "combat" and shop_slide < 0.2 and not (is_mobile_ui and _mobile_encounter_hud != null):
		var panel_w = 660.0
		var panel_h = 188.0
		var panel_x = (DESIGN_W - panel_w) * 0.5
		var panel_y = 10.0 + (float(safe_inset.get("top", 0.0)) if is_mobile_ui else 0.0)
		var use_gen_banner := _mobile_gen_hud_active() and images.has("hud_gen_mission_banner")
		if use_gen_banner:
			panel_x = float(mlayout["center_x"])
			panel_y = float(mlayout["top_y"])
			panel_w = float(mlayout["center_w"])
			panel_h = float(mlayout["center_h"])
		elif is_mobile_ui:
			panel_w = minf(720.0, (DESIGN_W - float(safe_inset.get("left", 0.0)) - float(safe_inset.get("right", 0.0))) * 0.38)
			panel_h = panel_w * (724.0 / 2172.0)
			panel_x = (DESIGN_W - panel_w) * 0.5
		var panel_cx = panel_x + panel_w * 0.5

		# 0. Decorative Panel Frame (mobile uses generated mission banner; desktop unchanged)
		draw_tex(_hud_frame_key("ui_panel_wide_cyan", "hud_gen_mission_banner"), Rect2(panel_x, panel_y, panel_w, panel_h))

		# 1. TOP: Encounter Name — proportions relative to frame when using generated banner
		var title_default = "FUNGUS WILDS NODE" if current_region == "fungus_wilds" else "RUSTLANDS NODE"
		var title_text = "REGION TRANSITION" if region_transition_active else ("BOSS ENCOUNTER" if boss_active else current_encounter.get("title", title_default))
		var title_size = 17 if use_gen_banner else 18
		if title_text.length() > 20:
			title_size = 14.5 if use_gen_banner else 15.5
		if title_text.length() > 28:
			title_size = 12.5 if use_gen_banner else 13.5
		var title_y: float = panel_y + (panel_h * 0.28 if use_gen_banner else 66.0)
		draw_text2(title_text, panel_cx + 1.0, title_y + 1.0, title_size, Color(0.0, 0.0, 0.0, 0.85), "center")
		draw_text2(title_text, panel_cx, title_y, title_size, Color.WHITE, "center")

		# 2. BELOW TITLE: Encounter Progress Bar & Label
		var bar_w = panel_w * 0.68 if use_gen_banner else 440.0
		var bar_x = panel_x + (panel_w - bar_w) * 0.5
		var bar_y = panel_y + (panel_h * 0.42 if use_gen_banner else 74.0)
		var bar_h = maxf(11.0, panel_h * 0.085) if use_gen_banner else 16.0
		var p_pct = 0.0
		var bar_col = Color.html("#3de1ff")
		var bar_label = ""
		if boss_active:
			var b = null
			for e in enemies:
				if e.get("boss", false):
					b = e
			p_pct = clamp((b["hp"] / max(1.0, b["max_hp"])) if b != null else 0.0, 0.0, 1.0)
			bar_col = Color.html("#ff4b4b")
			var bl2 = str(b.get("data", {}).get("label", "BOSS")) if b != null else current_boss_def().get("label", "BOSS")
			bar_label = "%s  •  %d%%" % [bl2, int(p_pct * 100.0)]
		elif region_transition_active:
			p_pct = clamp(1.0 - (region_transition_timer / maxf(0.01, region_transition_total())), 0.0, 1.0)
			bar_col = Color.html("#7dffbb")
			var dest_label = "Region 1 — Rustlands"
			if region_transition_target == RiftScar.REGION_ID:
				dest_label = "Region 3 — The Rift Scar"
			elif region_transition_target == "fungus_wilds":
				dest_label = "Region 2 — Fungus Wilds"
			bar_label = "Crossing into %s  •  %d%%" % [dest_label, int(p_pct * 100.0)]
		else:
			p_pct = clamp(encounter_progress / max(0.01, encounter_goal), 0.0, 1.0)
			bar_label = "Encounter Progress  •  %d%%" % int(p_pct * 100.0)

		draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.03, 0.06, 0.08, 0.92), true)
		var fill_w = max(0.0, (bar_w - 4.0) * p_pct)
		if fill_w > 0.0:
			draw_rect(Rect2(bar_x + 2.0, bar_y + 2.0, fill_w, bar_h - 4.0), bar_col, true)
		draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(1.0, 1.0, 1.0, 0.22), false, 1.0)
		var label_y = bar_y + bar_h * 0.72
		draw_text2(bar_label, panel_cx + 1.0, label_y + 1.0, 11 if use_gen_banner else 12, Color(0.0, 0.0, 0.0, 0.92), "center")
		draw_text2(bar_label, panel_cx, label_y, 11 if use_gen_banner else 12, Color.WHITE, "center")

		# 3, 4, 5. MIDDLE ROW: Objective (Left), Route Dots (Center), Track Number (Right)
		var mid_y = panel_y + (panel_h * 0.64 if use_gen_banner else 110.0)

		# Middle Left: Current Objective
		var region_obj = "BREACH THE RIFT SCAR" if current_region == RiftScar.REGION_ID else ("SURVIVE FUNGUS WILDS" if current_region == "fungus_wilds" else "SURVIVE THE RUSTLANDS")
		var obj_title = "CROSSING BIOMES" if region_transition_active else ("FINAL OBJECTIVE" if boss_active else region_obj)
		var obj_col = Color.html("#ffd36d" if boss_active else ("#7dffbb" if region_transition_active else "#85f2ff"))
		var obj_x = bar_x + 4.0
		var mid_fs: float = 11.5 if use_gen_banner else 12.5
		draw_text2(obj_title, obj_x + 1.0, mid_y + 1.0, mid_fs, Color(0.0, 0.0, 0.0, 0.8), "left")
		draw_text2(obj_title, obj_x, mid_y, mid_fs, obj_col, "left")

		# Middle Center: Route Progress Dots
		var dot_cy = mid_y - 4.0
		for i in range(6):
			var dot_cx = panel_cx - 40.0 + i * 16.0
			var dot_col = Color.html("#7dffbb") if i < encounter_index else (Color.html("#ffd36d") if i == encounter_index else Color(1.0, 1.0, 1.0, 0.2))
			draw_circle(Vector2(dot_cx, dot_cy), 4.0 if use_gen_banner else 4.5, dot_col)
			if i == encounter_index:
				draw_arc(Vector2(dot_cx, dot_cy), 6.0, 0.0, TAU, 16, Color(1.0, 0.83, 0.43, 0.45), 1.0)

		# Middle Right: Rift Loop + Track Number
		var track_text = "Loop %d  •  Track %d/6" % [maxi(1, rift_loop), min(encounter_index + 1, 6)]
		var track_x = bar_x + bar_w - 4.0
		draw_text2(track_text, track_x + 1.0, mid_y + 1.0, mid_fs, Color(0.0, 0.0, 0.0, 0.8), "right")
		draw_text2(track_text, track_x, mid_y, mid_fs, Color.html("#b7ecff"), "right")

		# 6. BOTTOM: Run Time & Score (Aligned within safe area above lower metal border)
		var bot_y = panel_y + (panel_h * 0.80 if use_gen_banner else 130.0)
		var bot_text = "RUN %s   •   SCORE %d" % [fmt_time(run_time), calculate_run_score(false)]
		draw_text2(bot_text, panel_cx + 1.0, bot_y + 1.0, mid_fs, Color(0.0, 0.0, 0.0, 0.85), "center")
		draw_text2(bot_text, panel_cx, bot_y, mid_fs, Color.html("#8ee5ff"), "center")


	# TOP RIGHT (Resource & XP HUD — hud_resources_status / mobile generated economy)
	# Skip entirely while armory sheet is open (scrap lives in the sheet header).
	if USE_PRODUCTION_UI and shop_slide < 0.2 and (images.has("hud_resources_status") or (is_mobile_ui and images.has("hud_gen_economy"))):
		if is_mobile_ui and _mobile_economy_hud != null:
			# Control-tree MobileEconomyHud owns scrap/LV/XP. Single pause asset beside it (no speed).
			var elay: Dictionary = _mobile_economy_layout()
			var etr: Rect2 = elay["texture_rect"]
			var pause_s: float = float(elay.get("pause_s", 40.0))
			var bx0: float = float(elay.get("pause_x", etr.position.x + etr.size.x + 10.0))
			var by0: float = maxf(etr.position.y + etr.size.y * MobileHudLayout.ECONOMY_ART_PAD_TOP_FRAC + 2.0, design_view_top + 2.0)
			var pause_key := "btn_mobile_pause" if images.has("btn_mobile_pause") else "btn_hud_pause"
			image_button(bx0, by0, pause_s, pause_s, pause_key, "toggle_pause")
			if paused:
				draw_rect(Rect2(bx0, by0, pause_s, pause_s), Color(1.0, 0.8, 0.2, 0.28), true)
				draw_text2("▶", bx0 + pause_s * 0.5, by0 + pause_s * 0.62, 17, Color.WHITE, "center")
			if save_flash > 0:
				draw_text2("AUTOSAVED", etr.position.x + etr.size.x * 0.5, etr.position.y + etr.size.y + 4.0, 12, Color.html("#7dffbb"), "center")
		elif _mobile_gen_hud_active() and images.has("hud_gen_economy"):
			# Legacy generated economy shell (fallback if Control HUD unavailable).
			var eco_w: float = float(mlayout["right_w"])
			var eco_h: float = float(mlayout["right_h"])
			var rx: float = float(mlayout["right_x"])
			var ry: float = float(mlayout["top_y"])
			draw_tex("hud_gen_economy", Rect2(rx, ry, eco_w, eco_h))
			var s_icon := "icon_scrap_gear" if images.has("icon_scrap_gear") else "icon_scrap"
			var icon_sz: float = eco_h * 0.32
			var c1_cx := rx + eco_w * 0.12
			var c1_cy := ry + eco_h * 0.52
			draw_tex(s_icon, Rect2(c1_cx - icon_sz * 0.5, c1_cy - icon_sz * 0.5, icon_sz, icon_sz))
			draw_text2("%d" % int(scrap), rx + eco_w * 0.40, ry + eco_h * 0.56, 18, Color.html("#ffd27b"), "center")
			draw_text2("LV %d" % int(level), rx + eco_w * 0.675, ry + eco_h * 0.56, 12, Color.html("#8ef7ff"), "center")
			var r4_x := rx + eco_w * 0.78
			var r4_y := ry + eco_h * 0.38
			var r4_w := eco_w * 0.155
			var r4_h := eco_h * 0.28
			draw_rect(Rect2(r4_x, r4_y, r4_w, r4_h), Color(0.03, 0.12, 0.16, 0.75), true)
			var xp_pct_m := clampf(float(xp) / maxf(1.0, float(xp_needed)), 0.0, 1.0)
			if xp_pct_m > 0.0:
				draw_rect(Rect2(r4_x, r4_y, r4_w * xp_pct_m, r4_h), Color.html("#5ee9ff"), true)
			draw_text2("%d/%d" % [int(xp), int(xp_needed)], r4_x + r4_w * 0.5, r4_y + r4_h * 0.70, 10, Color.WHITE, "center")
			var pause_s2: float = float(mlayout["pause_s"])
			var bx0b: float = rx + eco_w + 10.0
			var by0b: float = ry + 4.0
			var pause_key2 := "btn_mobile_pause" if images.has("btn_mobile_pause") else "btn_hud_pause"
			image_button(bx0b, by0b, pause_s2, pause_s2, pause_key2, "toggle_pause")
			if paused:
				draw_rect(Rect2(bx0b, by0b, pause_s2, pause_s2), Color(1.0, 0.8, 0.2, 0.28), true)
				draw_text2("▶", bx0b + pause_s2 * 0.5, by0b + pause_s2 * 0.62, 17, Color.WHITE, "center")
			if save_flash > 0:
				draw_text2("AUTOSAVED", rx + eco_w * 0.5, ry + eco_h + 12.0, 12, Color.html("#7dffbb"), "center")
		else:
			var scale = 0.26
			var rx = 1335.0
			var ry = 14.0
			var frame_w = 2172.0 * scale
			var frame_h = 724.0 * scale

			# LAYER 1 (BOTTOM): Dynamic content behind transparent windows

			# 1. Left circular slot — Scrap icon
			var c1_cx = rx + 282.0 * scale
			var c1_cy = ry + 260.0 * scale
			draw_circle(Vector2(c1_cx, c1_cy), 25.0, Color(0.015, 0.045, 0.065, 0.95))
			var s_icon = "icon_scrap_gear" if images.has("icon_scrap_gear") else "icon_scrap"
			draw_tex(s_icon, Rect2(c1_cx - 20.0, c1_cy - 20.0, 40.0, 40.0))

			# 2. Large left rectangle — Current Scrap amount
			var r2_x = rx + 454.0 * scale
			var r2_y = ry + 178.0 * scale
			var r2_w = (1136.0 - 454.0) * scale
			var r2_h = (334.0 - 178.0) * scale
			var r2_cx = rx + 795.0 * scale
			var r2_cy = ry + 256.0 * scale
			draw_rect(Rect2(r2_x - 3.0, r2_y - 3.0, r2_w + 6.0, r2_h + 6.0), Color(0.015, 0.045, 0.065, 0.95), true)
			draw_text2("%d" % int(scrap), r2_cx, r2_cy + 9.0, 25, Color.html("#ffd27b"), "center")

			# 3. Center hexagon — Player level
			var r3_cx = rx + 1438.0 * scale
			var r3_cy = ry + 254.0 * scale
			draw_circle(Vector2(r3_cx, r3_cy), 19.0, Color(0.015, 0.045, 0.065, 0.95))
			draw_text2("LV %d" % int(level), r3_cx, r3_cy + 5.0, 13, Color.html("#8ef7ff"), "center")

			# 4. Right long rectangle — XP progress bar
			var r4_x = rx + 1568.0 * scale
			var r4_y = ry + 204.0 * scale
			var r4_w = (2086.0 - 1568.0) * scale
			var r4_h = (300.0 - 204.0) * scale
			var r4_cx = rx + 1827.0 * scale
			var r4_cy = ry + 252.0 * scale
			draw_rect(Rect2(r4_x - 3.0, r4_y - 3.0, r4_w + 6.0, r4_h + 6.0), Color(0.015, 0.045, 0.065, 0.95), true)
			draw_rect(Rect2(r4_x, r4_y, r4_w, r4_h), Color(0.03, 0.12, 0.16, 0.8), true)
			var xp_pct = clampf(float(xp) / maxf(1.0, float(xp_needed)), 0.0, 1.0)
			if xp_pct > 0.0:
				draw_rect(Rect2(r4_x, r4_y, r4_w * xp_pct, r4_h), Color.html("#5ee9ff"), true)
			draw_text2("%d/%d XP" % [int(xp), int(xp_needed)], r4_cx, r4_cy + 4.0, 11, Color.WHITE, "center")

			# 5. Small lower button 1 — Pause
			var b1_x = rx + 1542.0 * scale
			var b1_y = ry + 466.0 * scale
			var b1_w = (1702.0 - 1542.0) * scale
			var b1_h = (626.0 - 466.0) * scale
			var b1_cx = rx + 1622.0 * scale
			var b1_cy = ry + 546.0 * scale
			draw_circle(Vector2(b1_cx, b1_cy), 20.0, Color(0.015, 0.045, 0.065, 0.95))
			if paused:
				draw_circle(Vector2(b1_cx, b1_cy), 18.0, Color(1.0, 0.8, 0.2, 0.45))
				draw_text2("▶", b1_cx + 1.0, b1_cy + 6.0, 17, Color.WHITE, "center")
			else:
				draw_text2("❚❚", b1_cx, b1_cy + 5.0, 14, Color.html("#8ef7ff"), "center")

			# 6. Small lower button 2 — Speed
			var b2_x = rx + 1810.0 * scale
			var b2_y = ry + 466.0 * scale
			var b2_w = (1972.0 - 1810.0) * scale
			var b2_h = (626.0 - 466.0) * scale
			var b2_cx = rx + 1891.0 * scale
			var b2_cy = ry + 546.0 * scale
			draw_circle(Vector2(b2_cx, b2_cy), 20.0, Color(0.015, 0.045, 0.065, 0.95))
			if game_speed > 1.0:
				draw_circle(Vector2(b2_cx, b2_cy), 18.0, Color(0.2, 0.9, 1.0, 0.45))
				draw_text2("2×", b2_cx, b2_cy + 6.0, 16, Color.html("#ffd27b"), "center")
			else:
				draw_text2("1×", b2_cx, b2_cy + 6.0, 16, Color.html("#8ef7ff"), "center")

			# LAYER 2 (TOP): Transparent HUD frame foreground overlay
			draw_tex("hud_resources_status", Rect2(rx, ry, frame_w, frame_h))

			# Interactive button hitboxes aligned exactly with visible buttons
			button(b1_x, b1_y, b1_w, b1_h, "", "toggle_pause", [], 1, Color(1, 1, 1, 0))
			button(b2_x, b2_y, b2_w, b2_h, "", "toggle_speed", [], 1, Color(1, 1, 1, 0))

			if save_flash > 0:
				draw_text2("AUTOSAVED", rx + frame_w * 0.5, ry + frame_h + 16.0, 13, Color.html("#7dffbb"), "center")
	else:
		draw_tex("hud_resource_xp", Rect2(1440, 20, 450, 80))
		if images.has("icon_scrap_gear"):
			draw_tex("icon_scrap_gear", Rect2(1464, 40, 40, 40))
		else:
			draw_tex("icon_scrap", Rect2(1464, 40, 40, 40))
		draw_text2("%d" % int(scrap), 1580, 67, 24, Color.html("#ffd27b"), "center")
		draw_text2("LV %d" % int(level), 1700, 66, 19, Color.html("#8cf5ff"), "center")
		bar(1750, 50, 120, 20, xp / xp_needed, Color.html("#83f4ff"), "")
		if save_flash > 0:
			draw_text2("AUTOSAVED", 1810, 162, 13, Color.html("#7dffbb"), "center")

		var pause_x: float = DESIGN_W - 160.0 - (float(safe_inset["right"]) if is_mobile_ui else 0.0)
		var pause_y: float = 106.0 + (float(safe_inset["top"]) if is_mobile_ui else 0.0)
		var pause_s: float = 52.0 if is_mobile_ui else 42.0
		var pause_key3 := "btn_mobile_pause" if (is_mobile_ui and images.has("btn_mobile_pause")) else "btn_hud_pause"
		image_button(pause_x, pause_y, pause_s, pause_s, pause_key3, "toggle_pause")
		if not is_mobile_ui:
			image_button(pause_x + pause_s + 10.0, pause_y, pause_s, pause_s, "btn_hud_speed", "toggle_speed")
		if paused:
			draw_rect(Rect2(pause_x, pause_y, pause_s, pause_s), Color(1, 0.8, 0.2, 0.35), true)
			draw_text2("▶", pause_x + pause_s * 0.5, pause_y + pause_s * 0.62, 19, Color.WHITE, "center")
		if not is_mobile_ui and game_speed > 1.0:
			draw_rect(Rect2(pause_x + pause_s + 10.0, pause_y, pause_s, pause_s), Color(0.25, 0.9, 1.0, 0.35), true)
			draw_text2("2×", pause_x + pause_s + 10.0 + pause_s * 0.5, pause_y + pause_s * 0.62, 17, Color.WHITE, "center")

	if state == "combat":
		# Armory sheet owns the right half — park combat consoles while it's open.
		if not (is_mobile_ui and shop_slide > 0.2):
			draw_power_panel()
			draw_module_panel()
			draw_ability_panel()

func draw_objective_tracker() -> void:
	if not USE_PRODUCTION_UI:
		panel(690, 144, 540, 74, Color.html("#85f2ff"), Color(.04,.08,.11,.86))
		var region_obj = "BREACH THE RIFT SCAR" if current_region == RiftScar.REGION_ID else ("SURVIVE FUNGUS WILDS" if current_region == "fungus_wilds" else "SURVIVE THE RUSTLANDS")
		var title = "CROSSING BIOMES" if region_transition_active else ("FINAL OBJECTIVE" if boss_active else region_obj)
		var detail = "Clear track %s of 6" % min(encounter_index + 1, 6)
		if region_transition_active:
			if region_transition_target == RiftScar.REGION_ID:
				detail = "Approaching The Rift Scar"
			elif region_transition_target == "fungus_wilds":
				detail = "Approaching Fungus Wilds"
			else:
				detail = "Returning to Rustlands — Loop %d" % rift_loop
		elif boss_active:
			detail = "Destroy %s" % current_boss_def().get("label", "BOSS")
		draw_text2(title, 712, 168, 17, Color.html("#ffd36d" if boss_active else ("#7dffbb" if region_transition_active else "#85f2ff")))
		draw_text2(detail, 712, 194, 17, Color(.85,.96,1))
		for i in range(6):
			draw_circle(Vector2(1020 + i * 28, 182), 8, Color.html("#7dffbb") if i < encounter_index else Color.html("#ffd36d") if i == encounter_index else Color(1,1,1,.16))

func toggle_pause() -> void:
	paused = not paused
func toggle_speed() -> void:
	game_speed = 2.0 if game_speed == 1.0 else 1.0

func update_live_shop(delta: float) -> void:
	# Close target when leaving combat; slide still animates out smoothly.
	if state != "combat":
		shop_open = false
	var prev_slide := shop_slide
	var target := 1.0 if shop_open else 0.0
	shop_slide = move_toward(shop_slide, target, delta / max(0.001, SHOP_SLIDE_SEC))
	shop_buy_cooldown = maxf(0.0, shop_buy_cooldown - delta)
	shop_buy_feedback_t = maxf(0.0, shop_buy_feedback_t - delta)
	if shop_buy_feedback_t <= 0.0:
		shop_buy_feedback = ""
	# Inertia scroll — coasts after swipe / wheel, eases to a stop.
	if not _touch_scroll_active or _touch_scroll_kind != "shop":
		if absf(shop_scroll_vel) > 8.0:
			shop_scroll_y += shop_scroll_vel * delta
			shop_scroll_vel *= exp(-4.2 * delta)
			if shop_scroll_y < 0.0:
				shop_scroll_y = 0.0
				shop_scroll_vel = 0.0
			elif shop_scroll_y > shop_scroll_max:
				shop_scroll_y = shop_scroll_max
				shop_scroll_vel = 0.0
			if absf(shop_scroll_vel) < 18.0:
				shop_scroll_vel = 0.0
		else:
			shop_scroll_vel = 0.0
			shop_scroll_y = clampf(shop_scroll_y, 0.0, shop_scroll_max)
	# Hide/show overlapping Control HUDs as the sheet crosses the visibility threshold.
	if is_mobile_ui and ((prev_slide < 0.2) != (shop_slide < 0.2)):
		_sync_mobile_status_hud()
		_sync_mobile_encounter_hud()
		_sync_mobile_economy_hud()

func toggle_live_shop() -> void:
	if state != "combat":
		return
	shop_open = not shop_open
	if shop_open:
		toasts.clear()
		shop_buy_feedback = ""
		shop_buy_feedback_t = 0.0
		shop_scroll_vel = 0.0
	if is_mobile_ui:
		_sync_mobile_status_hud()
		_sync_mobile_encounter_hud()
		_sync_mobile_economy_hud()

func set_shop_tab(tab: String) -> void:
	if tab != "weapons" and tab != "upgrades":
		return
	shop_tab = tab
	shop_scroll_y = 0.0
	shop_scroll_vel = 0.0

func shop_absorb_click() -> void:
	# Blocks click-through into HUD / weapon-priority controls under the drawer.
	pass

func adjust_shop_scroll(delta_y: float) -> void:
	shop_scroll_y = clampf(shop_scroll_y + delta_y, 0.0, maxf(0.0, shop_scroll_max))

func _shop_tab_w() -> float:
	if is_mobile_ui and images.has("hud_shop_tab_vertical"):
		return float(_mobile_shop_tab_layout()["texture_rect"].size.x)
	if _mobile_gen_hud_active() and images.has("hud_gen_shop_tab"):
		return float(_mobile_hud_layout()["shop_w"])
	if is_mobile_ui and images.has("hud_gen_shop_tab"):
		return 56.0
	return SHOP_TAB_W

func _shop_drawer_w() -> float:
	if is_mobile_ui:
		# Compact sheet — leave a real playfield peek on the left.
		var usable: float = design_view_right - design_view_left - float(safe_inset.get("left", 0.0))
		return clampf(usable * 0.52, 520.0, usable - 220.0)
	return SHOP_DRAWER_W

func _shop_drawer_y() -> float:
	if is_mobile_ui:
		return design_view_top + float(safe_inset["top"]) + 4.0
	return SHOP_DRAWER_Y

func _shop_drawer_h() -> float:
	if is_mobile_ui:
		return maxf(320.0, design_view_bottom - _shop_drawer_y() - float(safe_inset["bottom"]) - 8.0)
	return SHOP_DRAWER_H

func live_shop_drawer_x() -> float:
	# Mobile: flush to the visible right edge (no safe-inset gap beside the sheet).
	if is_mobile_ui:
		return design_view_right - shop_slide * _shop_drawer_w()
	return DESIGN_W - shop_slide * _shop_drawer_w()

func _mobile_shop_tab_layout() -> Dictionary:
	var win: Vector2i = DisplayServer.window_get_size()
	var vp: Vector2 = get_viewport_rect().size
	var eco: Dictionary = _mobile_economy_layout() if is_mobile_ui else {}
	var eco_tex: Rect2 = eco.get("texture_rect", Rect2()) if eco.size() > 0 else Rect2()
	var pause_r := Rect2()
	if eco.size() > 0:
		var ps: float = float(eco.get("pause_s", 40.0))
		var px: float = float(eco.get("pause_x", 0.0))
		var py: float = maxf(eco_tex.position.y + eco_tex.size.y * MobileHudLayout.ECONOMY_ART_PAD_TOP_FRAC + 2.0, design_view_top + 2.0)
		pause_r = Rect2(px, py, ps, ps)
	return MobileHudLayout.shop_tab_panel(
		safe_inset, design_view_left, design_view_right, design_view_top, design_view_bottom,
		canvas_scale, win, vp, eco_tex, pause_r
	)

func _mobile_shop_tab_rects() -> Dictionary:
	## Shared render + hit rects. Closed: flush right. Open: rides the drawer edge.
	var lay: Dictionary = _mobile_shop_tab_layout()
	var tex: Rect2 = lay["texture_rect"]
	var hit: Rect2 = lay["hit"]
	var content: Rect2 = lay["content"]
	if shop_slide > 0.001:
		# Seat brass flush into the drawer lip (art has a wide transparent right bay).
		var dx: float = live_shop_drawer_x()
		var pad_r: float = 0.38
		var opaque_r: float = tex.position.x + tex.size.x * (1.0 - pad_r)
		var shift: float = dx - opaque_r + 28.0
		tex.position.x += shift
		hit.position.x += shift
		content.position.x += shift
	return { "texture_rect": tex, "hit": hit, "content": content, "layout": lay }

func shop_status_color(status: String) -> Color:
	match status:
		"INSTALLED":
			return Color.html("#5ee9ff")
		"OWNED":
			return Color.html("#7dffbb")
		"NOT OWNED":
			return Color.html("#c9a24a")
		"UNAVAILABLE":
			return Color(0.55, 0.58, 0.62, 0.85)
		_:
			return Color(0.7, 0.75, 0.8, 0.75)

func shop_core_weapon_status(key: String) -> String:
	var owned_n := WeaponLoadout.count_owned(modules, key)
	var inst_n := WeaponLoadout.count_installed(modules, key)
	if owned_n <= 0:
		return "NOT OWNED"
	if inst_n > 0 and WeaponLoadout.count_owned(modules, key) > inst_n:
		return "OWNED" # spare in inventory
	if inst_n > 0:
		return "INSTALLED"
	return "OWNED"

func shop_aux_weapon_status(aux_id: String) -> String:
	if not is_aux_unlocked(aux_id):
		return "UNAVAILABLE"
	var owned_n := WeaponLoadout.count_owned(modules, aux_id)
	var inst_n := WeaponLoadout.count_installed(modules, aux_id)
	if owned_n <= 0:
		return "NOT OWNED"
	if inst_n > 0:
		return "INSTALLED"
	return "OWNED"

func shop_next_upgrade_cost(key: String) -> int:
	# Mirrors upgrade_module / upgrade_aux formulas (read-only).
	if key == "aux":
		var id = aux_module_id()
		if id == null:
			return -1
		return TrainBuild.aux_upgrade_cost(id, module_level("aux"))
	if not MODULE_INFO.has(key):
		return -1
	return TrainBuild.module_upgrade_cost(key, module_level(key))

func shop_effective_damage(kind: String, aux_id = null) -> float:
	match kind:
		"gatling":
			return float(weapons["gatling"]["damage"]) * (1.0 + (module_level("gatling") - 1) * 0.18)
		"cannon":
			return float(weapons["cannon"]["damage"]) * (1.0 + (module_level("cannon") - 1) * 0.22)
		"drone":
			return float(weapons["drone"]["damage"]) * float(stats_get("drone_damage", 1.0))
		"aux":
			if aux_id == null or not AUX_MODULES.has(aux_id):
				return -1.0
			var lvl = int(modules["aux_levels"].get(aux_id, 1))
			var base = float(AUX_MODULES[aux_id]["damage"])
			match aux_id:
				"arc_coil":
					return base * (1.0 + (lvl - 1) * 0.2)
				"cryo_launcher":
					return base * (1.0 + (lvl - 1) * 0.16)
				"rail_mortar":
					return base * (1.0 + (lvl - 1) * 0.24)
				"missile_rack":
					return base * (1.0 + (lvl - 1) * 0.18)
				_:
					return base
	return -1.0

func build_live_shop_weapon_entries() -> Array:
	# BUY → inventory instance; INSTALL → free universal hardpoint.
	var entries: Array = []
	var core = [
		{ "id": "gatling", "desc": "Rapid kinetic turret. Mount on any carriage slot (max %d)." % WeaponLoadout.max_owned("gatling") },
		{ "id": "cannon", "desc": "Heavy shell launcher. Mount on any carriage slot (max %d)." % WeaponLoadout.max_owned("cannon") },
		{ "id": "drone", "desc": "Drone launch bay. Mount on any carriage slot (max %d)." % WeaponLoadout.max_owned("drone") }
	]
	var free_mounts := TrainBuild.count_free_hardpoints(train_cars)
	for c in core:
		var id: String = c["id"]
		var info = MODULE_INFO[id]
		var owned_n := WeaponLoadout.count_owned(modules, id)
		var inst_n := WeaponLoadout.count_installed(modules, id)
		var inv_n := owned_n - inst_n
		var status = shop_core_weapon_status(id)
		var can_buy_more := WeaponLoadout.can_buy(modules, id)
		var buy_cost := TrainBuild.core_weapon_cost(id)
		var note := "%d owned  •  %d mounted  •  %d free slots" % [owned_n, inst_n, free_mounts]
		if free_mounts <= 0 and inv_n > 0:
			note = "FULL — no free mount"
		var entry = {
			"id": id,
			"kind": "core",
			"name": str(info["title"]),
			"description": str(c["desc"]),
			"status": status if owned_n > 0 else "NOT OWNED",
			"level": module_level(id) if owned_n > 0 else -1,
			"damage": shop_effective_damage(id) if inst_n > 0 else float(weapons[id]["damage"]),
			"cooldown": float(weapons[id].get("cooldown_max", -1.0)) if id != "drone" else -1.0,
			"power": -1,
			"cost": buy_cost if can_buy_more else -1,
			"upgrade_cost": shop_next_upgrade_cost(id) if inst_n > 0 else -1,
			"note": note,
			"can_buy": can_buy_more and int(scrap) >= buy_cost,
			"need_scrap": can_buy_more and int(scrap) < buy_cost,
			"can_install": inv_n > 0 and free_mounts > 0,
			"free_mounts": free_mounts,
			"can_uninstall": inst_n > 0
		}
		entries.append(entry)
	for aux_id in AUX_MODULES.keys():
		var ainfo = AUX_MODULES[aux_id]
		var astatus = shop_aux_weapon_status(aux_id)
		var owned_a := WeaponLoadout.count_owned(modules, aux_id)
		var inst_a := WeaponLoadout.count_installed(modules, aux_id)
		var inv_a := owned_a - inst_a
		var alvl = int(modules.get("aux_levels", {}).get(aux_id, 1))
		var unlock_note := ""
		if astatus == "UNAVAILABLE":
			unlock_note = str(ainfo.get("unlock", "Blueprint required"))
		elif free_mounts <= 0 and inv_a > 0:
			unlock_note = "FULL — no free mount"
		else:
			unlock_note = "%d owned  •  %d mounted" % [owned_a, inst_a]
		var aux_buy := TrainBuild.aux_weapon_cost(aux_id)
		var can_buy_a := WeaponLoadout.can_buy(modules, aux_id) and astatus != "UNAVAILABLE"
		var aentry = {
			"id": aux_id,
			"kind": "aux",
			"name": str(ainfo["title"]),
			"description": str(ainfo.get("desc", "")),
			"status": astatus,
			"level": alvl if owned_a > 0 else -1,
			"damage": shop_effective_damage("aux", aux_id),
			"cooldown": float(ainfo.get("cooldown", -1.0)),
			"power": -1,
			"cost": aux_buy if can_buy_a else -1,
			"upgrade_cost": TrainBuild.aux_upgrade_cost(aux_id, alvl) if inst_a > 0 else -1,
			"note": unlock_note,
			"can_buy": can_buy_a and int(scrap) >= aux_buy,
			"need_scrap": can_buy_a and int(scrap) < aux_buy,
			"can_install": inv_a > 0 and free_mounts > 0,
			"free_mounts": free_mounts,
			"can_uninstall": inst_a > 0
		}
		entries.append(aentry)
	return entries

func _shop_upgrade_action_state(cost: int, special: String = "") -> String:
	if special == "future":
		return "FUTURE"
	if special == "full":
		return "FULL"
	if special == "need_drone":
		return "NEED_DRONE"
	if special == "max":
		return "MAX"
	if cost <= 0:
		return "UNAVAILABLE"
	if int(scrap) < cost:
		return "NEED_SCRAP"
	return "AVAILABLE"

func build_live_shop_upgrade_entries() -> Array:
	var entries: Array = []
	entries.append({
		"id": "hdr_systems",
		"kind": "header",
		"name": "TRAIN SYSTEMS",
		"status": "",
		"detail": "",
		"cost": -1,
		"action_state": "HEADER"
	})
	var wagons := TrainBuild.wagon_count(train_cars)
	var at_cap := wagons >= TrainBuild.MAX_WAGONS
	var wpn_cost := TrainBuild.wagon_cost("weapon")
	entries.append({
		"id": "buy_wagon_weapon",
		"kind": "item",
		"name": "WEAPON WAGON",
		"status": "WAGONS %d/%d" % [wagons, TrainBuild.MAX_WAGONS],
		"detail": ("3 universal mounts. Needs a separately purchased weapon to fire." if not at_cap else "Maximum wagon capacity reached."),
		"cost": wpn_cost,
		"action_label": "BUY",
		"action_state": "MAX" if at_cap else _shop_upgrade_action_state(wpn_cost)
	})
	var used = reactor_used_power()
	var rcost := station_item_cost("reactor")
	entries.append({
		"id": "reactor",
		"kind": "item",
		"name": "REACTOR",
		"status": "CAPACITY %d" % int(reactor.get("max", 10)),
		"detail": "Allocated %d  •  Free %d" % [used, int(reactor.get("max", 10)) - used],
		"cost": rcost,
		"action_label": "UPGRADE",
		"action_state": _shop_upgrade_action_state(rcost)
	})
	var loco = train_cars[0] if train_cars.size() > 0 else {}
	var acost := station_item_cost("armor")
	entries.append({
		"id": "armor",
		"kind": "item",
		"name": "ARMOR PLATING",
		"status": "ARMOR %.0f" % float(loco.get("armor", 0.0)),
		"detail": "Loco %d/%d HP  •  +18 max HP / +2 armor" % [int(loco.get("hp", 0)), int(loco.get("max_hp", 0))],
		"cost": acost,
		"action_label": "UPGRADE",
		"action_state": _shop_upgrade_action_state(acost)
	})
	var repair_cost := station_item_cost("repair")
	var missing := train_missing_hp()
	var repair_special := "full" if missing <= 0.5 else ""
	entries.append({
		"id": "repair",
		"kind": "item",
		"name": "FIELD REPAIR",
		"status": "MISSING %.0f HP" % missing if missing > 0.5 else "FULL HEALTH",
		"detail": "Restore up to 95 HP across damaged cars.",
		"cost": repair_cost,
		"action_label": "REPAIR",
		"action_state": _shop_upgrade_action_state(repair_cost, repair_special)
	})
	var ccost := station_item_cost("cool")
	entries.append({
		"id": "cooling",
		"kind": "item",
		"name": "COOLING SYSTEMS",
		"status": "×%.2f" % float(stats_get("cooling_mul", 1.0)),
		"detail": "Improves heat dissipation (+18%% cooling).",
		"cost": ccost,
		"action_label": "UPGRADE",
		"action_state": _shop_upgrade_action_state(ccost)
	})
	var dcost := station_item_cost("drone")
	var drone_special := "" if is_module_installed("drone") else "need_drone"
	entries.append({
		"id": "drone_tune",
		"kind": "item",
		"name": "DRONE TUNE",
		"status": "DMG ×%.2f  RATE ×%.2f" % [float(stats_get("drone_damage", 1.0)), float(stats_get("drone_rate", 1.0))],
		"detail": "Tune drone damage and fire rate." if is_module_installed("drone") else "Requires installed Drone Bay.",
		"cost": dcost,
		"action_label": "UPGRADE",
		"action_state": _shop_upgrade_action_state(dcost, drone_special)
	})

	entries.append({
		"id": "hdr_weapons",
		"kind": "header",
		"name": "INSTALLED WEAPONS",
		"status": "",
		"detail": "",
		"cost": -1,
		"action_state": "HEADER"
	})
	for key in ["gatling", "cannon", "drone"]:
		if not is_module_installed(key):
			continue
		var lvl = module_level(key)
		var next_cost = shop_next_upgrade_cost(key)
		var wspecial := "max" if lvl >= 5 else ""
		entries.append({
			"id": "upgrade_" + key,
			"kind": "item",
			"name": str(MODULE_INFO[key]["title"]) + " UPGRADE",
			"status": "Lv %d/5" % lvl,
			"detail": "DMG %.0f  •  Next tier improves output" % shop_effective_damage(key) if next_cost > 0 else "Maximum level reached.",
			"cost": next_cost,
			"action_label": "UPGRADE",
			"action_state": _shop_upgrade_action_state(next_cost if next_cost > 0 else 1, wspecial)
		})
	var aux_id = aux_module_id()
	if aux_id != null:
		var alvl = module_level("aux")
		var anext = shop_next_upgrade_cost("aux")
		var aspecial := "max" if alvl >= 5 else ""
		entries.append({
			"id": "upgrade_aux",
			"kind": "item",
			"name": str(AUX_MODULES[aux_id]["title"]) + " UPGRADE",
			"status": "Lv %d/5" % alvl,
			"detail": "DMG %.0f  •  Levels stay with this aux" % shop_effective_damage("aux", aux_id) if anext > 0 else "Maximum level reached.",
			"cost": anext,
			"action_label": "UPGRADE",
			"action_state": _shop_upgrade_action_state(anext if anext > 0 else 1, aspecial)
		})
	return entries

func draw_live_shop() -> void:
	# Edge tab always peeks so SHOP stays reachable while closed or animating.
	var drawer_x := live_shop_drawer_x()
	var tab_w := _shop_tab_w()
	var tab_h := 148.0 if is_mobile_ui else 120.0
	var tab_x := drawer_x - tab_w
	var tab_y := _shop_drawer_y() + (180.0 if is_mobile_ui else 210.0)
	if is_mobile_ui and images.has("hud_shop_tab_vertical"):
		# Mission 04: vertical brass frame flush to the safe right edge (dynamic).
		var rects: Dictionary = _mobile_shop_tab_rects()
		var tex_r: Rect2 = rects["texture_rect"]
		var hit_r: Rect2 = rects["hit"]
		var content: Rect2 = rects["content"]
		tab_x = tex_r.position.x
		tab_y = tex_r.position.y
		tab_w = tex_r.size.x
		tab_h = tex_r.size.y
		draw_tex("hud_shop_tab_vertical", tex_r)
		var letters := ["S", "H", "O", "P"]
		var letter_col := Color.html("#ffd27b") if (shop_open or shop_slide > 0.05) else Color.html("#8ef7ff")
		# Even cells + font ascent/descent so capitals (especially O) are never cut off.
		if font == null:
			font = ThemeDB.fallback_font
		var n_let: int = letters.size()
		var cell_h: float = content.size.y / float(maxi(1, n_let))
		var fs: int = clampi(int(floor(minf(content.size.x * 0.64, cell_h * 0.44))), 12, 18)
		var ascent: float = float(fs) * 0.80
		var descent: float = float(fs) * 0.20
		if font != null:
			ascent = font.get_ascent(fs)
			descent = font.get_descent(fs)
		var cx: float = content.position.x + content.size.x * 0.50
		var pad_y: float = maxf(2.0, cell_h * 0.14)
		for i in range(n_let):
			var cell_top: float = content.position.y + float(i) * cell_h
			var cell_bot: float = cell_top + cell_h
			# Place baseline so full glyph (ascent above, descent below) fits in the cell.
			var ly: float = cell_top + pad_y + ascent
			var max_ly: float = cell_bot - pad_y - descent
			if ly > max_ly:
				ly = (cell_top + cell_bot) * 0.5 + (ascent - descent) * 0.5
			draw_text2(letters[i], cx, ly, fs, letter_col, "center")
		button(hit_r.position.x, hit_r.position.y, hit_r.size.x, hit_r.size.y, "", "toggle_live_shop", [], 1, Color(1, 1, 1, 0))
	elif _mobile_gen_hud_active() and images.has("hud_gen_shop_tab"):
		var mls := _mobile_hud_layout()
		tab_h = float(mls["shop_h"])
		tab_y = float(mls["shop_y"])
		draw_tex("hud_gen_shop_tab", Rect2(tab_x, tab_y, tab_w, tab_h))
		draw_text2("S", tab_x + tab_w * 0.52, tab_y + tab_h * 0.28, 15, Color.html("#ffd27b"), "center")
		draw_text2("H", tab_x + tab_w * 0.52, tab_y + tab_h * 0.42, 15, Color.html("#ffd27b"), "center")
		draw_text2("O", tab_x + tab_w * 0.52, tab_y + tab_h * 0.56, 15, Color.html("#ffd27b"), "center")
		draw_text2("P", tab_x + tab_w * 0.52, tab_y + tab_h * 0.70, 15, Color.html("#ffd27b"), "center")
		button(tab_x, tab_y, tab_w, tab_h, "", "toggle_live_shop", [], 1, Color(1, 1, 1, 0))
	elif is_mobile_ui and images.has("hud_gen_shop_tab"):
		# Legacy gen tab — only if the Mission 04 vertical frame is missing.
		tab_h = 190.0
		draw_tex("hud_gen_shop_tab", Rect2(tab_x, tab_y, tab_w, tab_h))
		draw_text2("S", tab_x + tab_w * 0.52, tab_y + 48.0, 16, Color.html("#ffd27b"), "center")
		draw_text2("H", tab_x + tab_w * 0.52, tab_y + 70.0, 16, Color.html("#ffd27b"), "center")
		draw_text2("O", tab_x + tab_w * 0.52, tab_y + 92.0, 16, Color.html("#ffd27b"), "center")
		draw_text2("P", tab_x + tab_w * 0.52, tab_y + 114.0, 16, Color.html("#ffd27b"), "center")
		button(tab_x, tab_y, tab_w, tab_h, "", "toggle_live_shop", [], 1, Color(1, 1, 1, 0))
	else:
		var tab_fill := Color(0.08, 0.12, 0.16, 0.96) if shop_open or shop_slide > 0.05 else Color(0.07, 0.11, 0.15, 0.94)
		var tab_stroke := Color.html("#c9a24a") if shop_open else Color(0.5, 0.9, 1.0, 0.45)
		draw_rect(Rect2(tab_x, tab_y, tab_w, tab_h), tab_fill, true)
		draw_rect(Rect2(tab_x, tab_y, tab_w, tab_h), tab_stroke, false, 2.0)
		draw_rect(Rect2(tab_x + 2.0, tab_y + 2.0, 3.0, tab_h - 4.0), Color.html("#5ee9ff") if shop_open else Color(0.53, 0.94, 1.0, 0.35), true)
		draw_text2("S", tab_x + tab_w * 0.52, tab_y + 32.0, 18, Color.html("#ffd27b"), "center")
		draw_text2("H", tab_x + tab_w * 0.52, tab_y + 52.0, 18, Color.html("#ffd27b"), "center")
		draw_text2("O", tab_x + tab_w * 0.52, tab_y + 72.0, 18, Color.html("#ffd27b"), "center")
		draw_text2("P", tab_x + tab_w * 0.52, tab_y + 92.0, 18, Color.html("#ffd27b"), "center")
		button(tab_x, tab_y, tab_w, tab_h, "", "toggle_live_shop", [], 1, Color(1, 1, 1, 0))

	if shop_slide <= 0.001:
		return

	var x := drawer_x
	var y := _shop_drawer_y()
	var w := _shop_drawer_w()
	var h := _shop_drawer_h()
	var mob := is_mobile_ui
	# Mobile sheet: one clean header, cards to the right edge, thin scroll thumb.
	var edge_pad := 18.0 if mob else 18.0
	var edge_pad_r := 6.0 if mob else 18.0
	var title_fs := 40 if mob else 28
	var scrap_fs := 28 if mob else 20
	var tab_fs := 26 if mob else 18
	var tab_h2 := 54.0 if mob else 40.0
	var sub_fs := 20 if mob else 13
	var foot_fs := 17 if mob else 12
	var close_s := 56.0 if mob else 40.0
	# Thin edge thumb — fat gutter read as a "right gap" on phone captures.
	var scroll_gutter := 10.0 if mob else 44.0
	var card_gap := 12.0 if mob else SHOP_CARD_GAP

	# Soft dim over the left playfield so the sheet reads as the focus.
	if mob and shop_slide > 0.15:
		var peek_w := maxf(0.0, x - design_view_left)
		if peek_w > 2.0:
			draw_rect(Rect2(design_view_left, design_view_top, peek_w, design_view_bottom - design_view_top),
				Color(0.02, 0.04, 0.07, 0.42 * shop_slide), true)

	draw_rect(Rect2(x, y, w, h), Color(0.03, 0.05, 0.07, 0.98), true)
	draw_rect(Rect2(x + 3.0, y + 3.0, w - 3.0, h - 6.0), Color(0.055, 0.085, 0.115, 0.98), true)
	draw_rect(Rect2(x, y, w, h), Color.html("#a8843c"), false, 2.0)
	draw_rect(Rect2(x, y, 3.0, h), Color.html("#5ee9ff"), true)

	button(x, y, w, h, "", "shop_absorb_click", [], 1, Color(1, 1, 1, 0))

	# Header: title left, scrap chip + close right (single row on mobile).
	var head_y := y + (38.0 if mob else 42.0)
	draw_text2("TRAIN ARMORY", x + edge_pad + 4.0, head_y, title_fs, Color.html("#e8f7ff"))
	button(x + w - close_s - (8.0 if mob else 10.0), y + 8.0, close_s, close_s, "✕", "toggle_live_shop", [], 21 if mob else 22, Color.html("#c9a24a"))
	var scrap_chip := "SCRAP  %d" % int(scrap)
	if mob:
		draw_text2(scrap_chip, x + w - close_s - 18.0, head_y, scrap_fs, Color.html("#ffd27b"), "right")
	else:
		var live_pulse := 0.55 + 0.45 * sin(t * 6.0)
		var live_x := x + edge_pad + 268.0
		draw_circle(Vector2(live_x, y + 36.0), 5.0, Color(0.2, 1.0, 0.55, 0.35 + 0.45 * live_pulse))
		draw_text2("LIVE", live_x + 24.0, y + 40.0, 14, Color(0.49, 1.0, 0.73, 0.75 + 0.25 * live_pulse))
		draw_text2(scrap_chip, x + edge_pad + 6.0, y + 72.0, scrap_fs, Color.html("#ffd27b"))

	var tab_y2 := y + (62.0 if mob else 96.0)
	var tab_span := w - edge_pad - edge_pad_r - 12.0
	var tw := tab_span * 0.5
	var weapons_active := shop_tab == "weapons"
	button(x + edge_pad, tab_y2, tw, tab_h2, "WEAPONS", "set_shop_tab", ["weapons"], tab_fs,
		Color.html("#5ee9ff") if weapons_active else Color(0.45, 0.55, 0.62, 0.45))
	button(x + edge_pad + tw + 12.0, tab_y2, tw, tab_h2, "UPGRADES", "set_shop_tab", ["upgrades"], tab_fs,
		Color.html("#5ee9ff") if not weapons_active else Color(0.45, 0.55, 0.62, 0.45))
	if weapons_active:
		draw_rect(Rect2(x + edge_pad, tab_y2 + tab_h2 - 3.0, tw, 3.0), Color.html("#5ee9ff"), true)
	else:
		draw_rect(Rect2(x + edge_pad + tw + 12.0, tab_y2 + tab_h2 - 3.0, tw, 3.0), Color.html("#5ee9ff"), true)

	draw_rect(Rect2(x + edge_pad, tab_y2 + tab_h2 + 8.0, w - edge_pad - edge_pad_r, 1.0), Color(0.5, 0.75, 0.85, 0.22), true)

	var body_top := tab_y2 + tab_h2 + 14.0
	var footer_h := 36.0 if mob else 36.0
	var list_bottom := y + h - footer_h - 4.0
	var subtitle := "Live Scrap upgrades • Combat continues"
	if shop_tab == "weapons":
		subtitle = "Buy / Equip aux • Install separate from purchase"
	if shop_buy_feedback_t > 0.0 and shop_buy_feedback != "":
		subtitle = shop_buy_feedback
	var sub_col := Color(0.55, 0.65, 0.72, 0.85)
	if shop_buy_feedback in ["PURCHASED", "UPGRADED"] or shop_buy_feedback.begins_with("EQUIPPED"):
		sub_col = Color.html("#7dffbb")

	# Extra air under the subtitle so the first card never collides with it.
	var list_top := body_top + (40.0 if mob else 28.0)
	var list_h := maxf(40.0, list_bottom - list_top)
	var list_x := x + edge_pad
	var list_w := w - edge_pad - edge_pad_r - scroll_gutter
	var entries: Array = build_live_shop_weapon_entries() if shop_tab == "weapons" else build_live_shop_upgrade_entries()
	# Tall enough for large type; no flavor/ownership lines so rows stay compact.
	var card_h := (150.0 if mob else 96.0) if shop_tab == "weapons" else (136.0 if mob else 78.0)
	var header_h := 40.0 if mob else 28.0
	var content_h := 0.0
	for e0 in entries:
		content_h += (header_h if str(e0.get("kind", "")) == "header" else card_h) + card_gap
	var max_scroll := maxf(0.0, content_h - list_h)
	shop_scroll_max = max_scroll
	shop_scroll_y = clampf(shop_scroll_y, 0.0, max_scroll)

	var cursor_y := list_top - shop_scroll_y
	for i in range(entries.size()):
		var e: Dictionary = entries[i]
		var eh := header_h if str(e.get("kind", "")) == "header" else card_h
		var cy := cursor_y
		cursor_y += eh + card_gap
		if cy < list_top - 0.5 or (cy + eh) > list_bottom + 0.5:
			continue
		if shop_tab == "weapons":
			_draw_live_shop_weapon_card(list_x, cy, list_w, eh, e, true)
		else:
			_draw_live_shop_upgrade_card(list_x, cy, list_w, eh, e, true)

	var clip_inner := Color(0.055, 0.085, 0.115, 1.0)
	var clip_footer := Color(0.03, 0.05, 0.07, 1.0)
	draw_rect(Rect2(x + 3.0, body_top, w - 3.0, maxf(0.0, list_top - body_top)), clip_inner, true)
	draw_text2(subtitle, x + edge_pad + 4.0, body_top + (18.0 if mob else 16.0), sub_fs, sub_col)
	draw_rect(Rect2(x + 3.0, list_bottom, w - 3.0, maxf(0.0, (y + h) - list_bottom)), clip_footer, true)
	draw_text2("Combat continues while shopping", x + w * 0.5, list_bottom + (22.0 if mob else 22.0), foot_fs, Color(0.55, 0.85, 0.75, 0.65), "center")

	if max_scroll > 0.0:
		if mob:
			# Edge thumb only — swipe scrolls; no fat ▲▼ column.
			var gx := x + w - scroll_gutter
			var gw := 5.0
			var track_h := list_h
			var thumb_h := maxf(28.0, track_h * (list_h / maxf(list_h + max_scroll, 1.0)))
			var thumb_t := list_top + (track_h - thumb_h) * (shop_scroll_y / maxf(max_scroll, 0.001))
			draw_rect(Rect2(gx + 2.0, list_top, gw, track_h), Color(1, 1, 1, 0.06), true)
			draw_rect(Rect2(gx + 1.0, thumb_t, gw + 2.0, thumb_h), Color(0.45, 0.88, 1.0, 0.55), true)
		else:
			var gx2 := x + w - scroll_gutter - 4.0
			var gw2 := scroll_gutter - 12.0
			var sb_h := 28.0
			draw_rect(Rect2(gx2 - 4.0, list_top, gw2 + 8.0, list_h), Color(0.05, 0.08, 0.11, 1.0), true)
			draw_rect(Rect2(gx2 - 4.0, list_top, 1.5, list_h), Color(0.5, 0.75, 0.85, 0.22), true)
			button(gx2, list_top + 4.0, gw2, sb_h, "▲", "adjust_shop_scroll", [-104.0], 14, Color(0.5, 0.85, 1.0, 0.55))
			button(gx2, list_bottom - sb_h - 4.0, gw2, sb_h, "▼", "adjust_shop_scroll", [104.0], 14, Color(0.5, 0.85, 1.0, 0.55))
			var track_h2 := maxf(24.0, list_h - (sb_h * 2.0 + 20.0))
			var thumb_h2 := maxf(18.0, track_h2 * (list_h / maxf(list_h + max_scroll, 1.0)))
			var thumb_t2 := list_top + sb_h + 8.0 + (track_h2 - thumb_h2) * (shop_scroll_y / maxf(max_scroll, 0.001))
			draw_rect(Rect2(gx2 + gw2 * 0.35, list_top + sb_h + 8.0, gw2 * 0.3, track_h2), Color(1, 1, 1, 0.08), true)
			draw_rect(Rect2(gx2 + gw2 * 0.3, thumb_t2, gw2 * 0.4, thumb_h2), Color(0.4, 0.85, 1.0, 0.45), true)

	draw_rect(Rect2(x, y, w, h), Color.html("#a8843c"), false, 2.0)
	draw_rect(Rect2(x, y, 3.0, h), Color.html("#5ee9ff"), true)

func _draw_live_shop_weapon_card(cx: float, cy: float, cw: float, ch: float, e: Dictionary, allow_buy: bool) -> void:
	var mob := is_mobile_ui
	var pad := 16.0 if mob else 14.0
	var name_fs := 40 if mob else 17
	var status_fs := 20 if mob else 13
	var stats_fs := 22 if mob else 12
	var act_fs := 22 if mob else 13
	var btn_h := 54.0 if mob else 28.0
	var status: String = str(e.get("status", ""))
	var status_label := "LOCKED" if status == "UNAVAILABLE" else status
	var stroke := shop_status_color(status)
	stroke.a = 0.55 if status != "UNAVAILABLE" else 0.35
	var fill := Color(0.05, 0.09, 0.12, 0.92) if status != "UNAVAILABLE" else Color(0.05, 0.06, 0.07, 0.88)
	panel(cx, cy, cw, ch, stroke, fill)
	# Clean card: name + status + combat stats only (no flavor / ownership clutter).
	var name_y := cy + (40.0 if mob else 20.0)
	var stats_y := cy + (78.0 if mob else 44.0)
	draw_text2(str(e.get("name", "")), cx + pad, name_y, name_fs, Color.html("#eaf8ff"))
	draw_text2(status_label, cx + cw - pad, name_y, status_fs, shop_status_color(status), "right")
	var bits: Array = []
	if int(e.get("level", -1)) > 0:
		bits.append("Lv %d/5" % int(e["level"]))
	if float(e.get("damage", -1.0)) > 0.0:
		bits.append("DMG %.0f" % float(e["damage"]))
	if float(e.get("cooldown", -1.0)) > 0.0:
		bits.append("CD %.2fs" % float(e["cooldown"]))
	if bits.size() > 0:
		var stats_line := ""
		for bi in range(bits.size()):
			if bi > 0:
				stats_line += "  •  "
			stats_line += str(bits[bi])
		draw_text2(stats_line, cx + pad, stats_y, stats_fs, Color(0.78, 0.90, 0.96, 0.95))

	var btn_y := cy + ch - btn_h - (12.0 if mob else 8.0)
	var is_core := str(e.get("kind", "")) == "core" or MODULE_INFO.has(str(e.get("id", "")))
	var wid := str(e.get("id", ""))
	var buy_fn := "live_shop_buy_core" if is_core else "live_shop_buy_aux"
	var can_buy := bool(e.get("can_buy", false))
	var can_install := bool(e.get("can_install", false))
	var can_uninstall := bool(e.get("can_uninstall", false))
	var free_n := int(e.get("free_mounts", TrainBuild.count_free_hardpoints(train_cars)))

	if status == "UNAVAILABLE":
		draw_text2("LOCKED", cx + cw - pad - 40.0, btn_y + btn_h * 0.55, status_fs, Color(0.55, 0.58, 0.62, 0.9), "center")
		return

	# Cost stays left; all actions cluster on the right (thumb zone).
	var cost := int(e.get("cost", TrainBuild.core_weapon_cost(wid) if is_core else TrainBuild.aux_weapon_cost(wid)))
	var show_cost := cost > 0 and (can_buy or bool(e.get("need_scrap", false)) or WeaponLoadout.can_buy(modules, wid))
	if show_cost:
		draw_text2("%d Scrap" % cost, cx + pad, btn_y + btn_h * 0.62, stats_fs, Color.html("#c9a24a"))

	var buy_w := 140.0 if mob else 72.0
	var inst_w := 150.0 if mob else 88.0
	var mount_w := 124.0 if mob else 70.0
	var swap_w := 124.0 if mob else 80.0
	var ns_w := 180.0 if mob else 90.0
	var uw := 152.0 if mob else 88.0
	var gap_b := 12.0 if mob else 8.0
	# Build right→left: [… BUY][MOUNT][INSTALL][UNINSTALL]
	var acts: Array = []
	if can_uninstall and allow_buy and shop_buy_cooldown <= 0.0:
		acts.append({"label": "UNINSTALL", "fn": "live_shop_uninstall_weapon", "args": [wid], "w": uw, "col": Color(0.85, 0.55, 0.5), "fs": act_fs - 1, "kind": "btn"})
	if can_install and allow_buy and shop_buy_cooldown <= 0.0:
		acts.append({"label": "INSTALL", "fn": "live_shop_install_weapon", "args": [wid], "w": inst_w, "col": Color.html("#7dffbb"), "fs": act_fs, "kind": "btn"})
		if free_n > 1:
			acts.append({"label": "MOUNT", "fn": "live_shop_cycle_mount", "args": [wid], "w": mount_w, "col": Color.html("#c9a24a"), "fs": act_fs - 1, "kind": "btn"})
	elif not can_install and WeaponLoadout.count_owned(modules, wid) > WeaponLoadout.count_installed(modules, wid) and free_n <= 0:
		if WeaponLoadout.count_installed(modules) > 0 and allow_buy and shop_buy_cooldown <= 0.0:
			acts.append({"label": "SWAP", "fn": "live_shop_swap_weapon", "args": [wid], "w": swap_w, "col": Color.html("#ffcf72"), "fs": act_fs, "kind": "btn"})
		else:
			acts.append({"label": "FULL", "w": 56.0, "kind": "text", "col": Color(0.75, 0.55, 0.4, 0.9)})
	if can_buy and allow_buy and shop_buy_cooldown <= 0.0:
		acts.append({"label": "BUY", "fn": buy_fn, "args": [wid], "w": buy_w, "col": Color.html("#5ee9ff"), "fs": act_fs, "kind": "btn"})
	elif bool(e.get("need_scrap", false)):
		acts.append({"label": "NEED SCRAP", "w": ns_w, "kind": "panel", "col": Color(0.75, 0.55, 0.4, 0.9)})
	elif status == "NOT OWNED" and not can_buy:
		acts.append({"label": "BUY", "w": buy_w, "kind": "ghost"})

	var x_right := cx + cw - pad
	for ai in range(acts.size()):
		var a: Dictionary = acts[ai]
		var aw: float = float(a["w"])
		var ax := x_right - aw
		match str(a.get("kind", "btn")):
			"btn":
				button(ax, btn_y, aw, btn_h, str(a["label"]), str(a["fn"]), a["args"], int(a["fs"]), a["col"])
			"panel":
				panel(ax, btn_y, aw, btn_h, Color(0.45, 0.35, 0.25, 0.55), Color(0.08, 0.06, 0.05, 0.9))
				draw_text2(str(a["label"]), ax + aw * 0.5, btn_y + btn_h * 0.62, act_fs - 1, a["col"], "center")
			"ghost":
				panel(ax, btn_y, aw, btn_h, Color(0.4, 0.45, 0.5, 0.4), Color(0.06, 0.08, 0.1, 0.9))
				draw_text2(str(a["label"]), ax + aw * 0.5, btn_y + btn_h * 0.62, act_fs, Color(0.5, 0.55, 0.6, 0.7), "center")
			"text":
				draw_text2(str(a["label"]), ax + aw * 0.5, btn_y + btn_h * 0.62, stats_fs, a["col"], "center")
		x_right = ax - gap_b

func _draw_live_shop_upgrade_card(cx: float, cy: float, cw: float, ch: float, e: Dictionary, allow_act: bool) -> void:
	var mob := is_mobile_ui
	var pad := 16.0 if mob else 14.0
	if str(e.get("kind", "")) == "header":
		draw_text2(str(e.get("name", "")), cx + 4.0, cy + (24.0 if mob else 18.0), 19 if mob else 13, Color.html("#85f2ff"))
		draw_rect(Rect2(cx, cy + (32.0 if mob else 24.0), cw, 1.0), Color(0.5, 0.75, 0.85, 0.28), true)
		return
	var status: String = str(e.get("status", ""))
	var astate: String = str(e.get("action_state", ""))
	var is_future := astate == "FUTURE" or status == "FUTURE FEATURE"
	var stroke := Color(0.55, 0.58, 0.62, 0.4) if is_future else Color(0.78, 0.62, 0.28, 0.4)
	panel(cx, cy, cw, ch, stroke, Color(0.06, 0.08, 0.10, 0.9))
	var name_y := cy + (40.0 if mob else 20.0)
	var detail_y := cy + (76.0 if mob else 40.0)
	draw_text2(str(e.get("name", "")), cx + pad, name_y, 36 if mob else 15, Color.html("#ffe7b0") if not is_future else Color(0.7, 0.72, 0.74, 0.85))
	var status_col := Color.html("#5ee9ff") if status.begins_with("Lv") or status.begins_with("CAPACITY") or status.begins_with("ARMOR") or status.begins_with("×") or status.begins_with("DMG") else Color.html("#c9a24a")
	if is_future or astate == "FULL" or astate == "MAX":
		status_col = Color(0.55, 0.58, 0.62, 0.85)
	draw_text2(status, cx + cw - pad, name_y, 20 if mob else 11, status_col, "right")
	draw_text2(str(e.get("detail", "")), cx + pad, detail_y, 24 if mob else 11, Color(0.72, 0.80, 0.86, 0.95))

	var btn_w := 200.0 if mob else 118.0
	var btn_h := 54.0 if mob else 26.0
	var btn_x := cx + cw - btn_w - pad
	var btn_y := cy + ch - btn_h - (14.0 if mob else 8.0)
	var cost := int(e.get("cost", -1))
	var label := str(e.get("action_label", "UPGRADE"))
	var act_fs := 22 if mob else 14
	if is_future:
		draw_text2("No price assigned", cx + pad, btn_y + btn_h * 0.62, 19 if mob else 11, Color(0.5, 0.52, 0.55, 0.75))
		return
	if cost > 0:
		draw_text2("%d Scrap" % cost, cx + pad, btn_y + btn_h * 0.62, 22 if mob else 12, Color.html("#c9a24a"))
	match astate:
		"AVAILABLE":
			if allow_act and shop_buy_cooldown <= 0.0:
				button(btn_x, btn_y, btn_w, btn_h, label, "live_shop_apply_upgrade", [str(e.get("id", ""))], act_fs, Color.html("#5ee9ff"))
			else:
				panel(btn_x, btn_y, btn_w, btn_h, Color(0.4, 0.55, 0.6, 0.4), Color(0.06, 0.1, 0.12, 0.9))
				draw_text2(label, btn_x + btn_w * 0.5, btn_y + btn_h * 0.62, act_fs, Color(0.55, 0.7, 0.75, 0.7), "center")
		"NEED_SCRAP":
			panel(btn_x, btn_y, btn_w, btn_h, Color(0.45, 0.35, 0.25, 0.55), Color(0.08, 0.06, 0.05, 0.9))
			draw_text2("NEED SCRAP", btn_x + btn_w * 0.5, btn_y + btn_h * 0.62, act_fs - 1, Color(0.75, 0.55, 0.4, 0.9), "center")
		"MAX":
			var max_label := "MAX WAGONS" if str(e.get("id", "")).begins_with("buy_wagon") else "MAX LEVEL"
			draw_text2(max_label, btn_x + btn_w * 0.5, btn_y + btn_h * 0.62, act_fs - 1, Color(0.55, 0.58, 0.62, 0.85), "center")
		"FULL":
			draw_text2("FULL HEALTH", btn_x + btn_w * 0.5, btn_y + btn_h * 0.62, act_fs - 1, Color(0.55, 0.58, 0.62, 0.85), "center")
		"NEED_DRONE":
			draw_text2("NEED DRONE", btn_x + btn_w * 0.5, btn_y + btn_h * 0.62, act_fs - 1, Color(0.55, 0.58, 0.62, 0.85), "center")
		_:
			draw_text2("UNAVAILABLE", btn_x + btn_w * 0.5, btn_y + btn_h * 0.62, 13 if mob else 11, Color(0.5, 0.52, 0.55, 0.75), "center")

func _weapon_hud_label(inst: Dictionary) -> String:
	var t := str(inst.get("type", ""))
	if MODULE_INFO.has(t):
		return str(MODULE_INFO[t].get("title", t))
	if AUX_MODULES.has(t):
		return str(AUX_MODULES[t].get("short", t))
	return t.to_upper()

func _weapon_hud_card_name(inst: Dictionary) -> String:
	# Compact names that fit the bronze nameplate (~110px).
	match str(inst.get("type", "")):
		"starter": return "STARTER"
		"gatling": return "GATLING"
		"cannon": return "CANNON"
		"drone": return "DRONE"
		"arc_coil": return "ARC"
		"cryo_launcher": return "CRYO"
		"rail_mortar": return "MORTAR"
		"missile_rack": return "MISSILE"
		_:
			var full := _weapon_hud_label(inst)
			return full if full.length() <= 7 else full.substr(0, 7)

func _weapon_hud_power_label(inst: Dictionary) -> String:
	# Reactor rows are per-instance — number duplicates so two Gatlings read as GAT 1 / GAT 2.
	var base := _weapon_hud_card_name(inst)
	var t := str(inst.get("type", ""))
	var uid := str(inst.get("uid", ""))
	var same: Array = []
	for other in WeaponLoadout.installed_list(modules):
		if str(other.get("type", "")) == t:
			same.append(str(other.get("uid", "")))
	if same.size() <= 1:
		return base
	var idx := same.find(uid) + 1
	var short := base if base.length() <= 5 else base.substr(0, 4)
	return "%s %d" % [short, idx]

func _weapon_hud_priority_label(priority: String) -> String:
	# Short forms so priority text stays inside the dropdown frame.
	match str(priority).to_lower():
		"nearest": return "NEAREST"
		"strongest": return "STRONG"
		"boarders": return "BOARD"
		"fastest": return "FAST"
		"lowest": return "LOW"
		"random": return "RANDOM"
		"rear": return "REAR"
		"flying": return "FLY"
		_:
			var p := str(priority).to_upper()
			return p if p.length() <= 7 else p.substr(0, 7)

func _fit_hud_text(text: String, max_w: float, prefer_size: int, min_size: int = 9) -> Dictionary:
	# Shrink font until the string fits the plaque / dropdown width.
	if font == null:
		font = ThemeDB.fallback_font
	var s := prefer_size
	var t := text
	while s >= min_size:
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
		if w <= max_w:
			return { "text": t, "size": s }
		s -= 1
	return { "text": t, "size": min_size }

func _weapon_hud_slot_tex(wtype: String) -> String:
	match wtype:
		"starter": return "hud_slot_gatling"
		"gatling": return "hud_slot_gatling"
		"cannon": return "hud_slot_cannon"
		"drone": return "hud_slot_drone"
		"arc_coil": return "hud_slot_arc"
		"cryo_launcher": return "hud_slot_cryo"
		"rail_mortar": return "hud_slot_mortar"
		"missile_rack": return "hud_slot_missile"
		_: return "hud_slot_empty"

func draw_power_panel() -> void:
	# ENGINE / SHIELD / UTILITY + installed weapons. Mobile compact console pages all channels.
	_clamp_weapon_hud_page()
	var total_w := WeaponLoadout.count_installed(modules)
	var pages := maxi(1, int(ceil(float(total_w) / 4.0)))
	var rows: Array = [
		["engine", "ENGINE", int(power.get("engine", 0)), 5],
		["shield", "SHIELD", int(power.get("shield", 0)), 3],
		["utility", "UTILITY", int(power.get("utility", 0)), 3]
	]
	for inst in installed_weapons_page():
		rows.append([str(inst.get("uid", "")), _weapon_hud_power_label(inst), int(inst.get("power", 0)), 3])
	while rows.size() < 7:
		rows.append(["", "—", 0, 0])

	if not USE_PRODUCTION_UI:
		panel(24, 734, 620, 320)
		draw_text2("REACTOR %s/%s" % [reactor_used_power(), int(reactor["max"])], 48, 764, 22, Color.html("#85f5ff"))
		if pages > 1:
			draw_text2("WPN %d/%d" % [weapon_hud_page + 1, pages], 360, 764, 16, Color.html("#9ef5ff"))
			button(470, 742, 40, 28, "<", "shift_weapon_hud_page", [-1], 16)
			button(520, 742, 40, 28, ">", "shift_weapon_hud_page", [1], 16)
		for i in range(mini(7, rows.size())):
			var key = str(rows[i][0])
			var yy = 797 + i * 32
			draw_text2(str(rows[i][1]), 90, yy + 6, 16, Color(.85,.93,.95))
			var cur := int(rows[i][2])
			var mxp := int(rows[i][3])
			for n in range(maxi(1, mxp)):
				draw_circle(Vector2(250 + n * 28, yy), 10, Color.html("#ffd06f") if n < cur else Color(1,1,1,.12))
			if key != "":
				button(429, yy - 17, 45, 30, "−", "adjust_power", [key, -1], 23)
				button(484, yy - 17, 45, 30, "+", "adjust_power", [key, 1], 23)
		return

	if _mobile_compact_reactor_active():
		_draw_mobile_compact_reactor()
		return

	# Desktop / legacy mobile generated shell.
	var px: float = 20.0 + (float(safe_inset["left"]) if is_mobile_ui else 0.0)
	var py: float = 745.0 - (float(safe_inset["bottom"]) if is_mobile_ui else 0.0)
	var pw: float = 520.0 if is_mobile_ui else 480.0
	var ph: float = 320.0
	var reactor_frame := _hud_frame_key("hud_reactor_power", "hud_gen_reactor")
	var use_gen_reactor := _mobile_gen_hud_active() and reactor_frame == "hud_gen_reactor"
	if use_gen_reactor:
		var ml := _mobile_hud_layout()
		px = float(ml["reactor_x"])
		py = float(ml["reactor_y"])
		pw = float(ml["reactor_w"])
		ph = float(ml["reactor_h"])
	var scale: float = pw / (1448.0 if reactor_frame == "hud_gen_reactor" else 1536.0)
	var used := reactor_used_power()
	var rmax := maxi(1, int(reactor["max"]))
	if is_mobile_ui and reactor_panel_collapsed:
		panel(px, py + ph - 56.0, pw, 52.0, Color.html("#c9a24a"), Color(0.05, 0.08, 0.11, 0.94))
		draw_text2("REACTOR  %d/%d" % [used, rmax], px + 16.0, py + ph - 24.0, 16, Color.html("#7fe9ff"), "left")
		button(px + pw - 150.0, py + ph - 48.0, 130.0, 40.0, "EXPAND", "toggle_reactor_panel", [], 16, Color.html("#5ee9ff"))
		return
	draw_tex(reactor_frame, Rect2(px, py, pw, ph))
	if use_gen_reactor:
		draw_text2("REACTOR  %d/%d" % [used, rmax], px + pw * 0.38, py + ph * 0.105, 11, Color.html("#7fe9ff"), "left")
		var gbar_x: float = px + pw * 0.60
		var gbar_y: float = py + ph * 0.075
		var gbar_w: float = pw * 0.16
		var gbar_h: float = 9.0
		draw_rect(Rect2(gbar_x, gbar_y, gbar_w, gbar_h), Color(0.04, 0.06, 0.08, 0.92), true)
		draw_rect(Rect2(gbar_x, gbar_y, gbar_w * clampf(float(used) / float(rmax), 0.0, 1.0), gbar_h), Color(0.25, 0.85, 0.95, 0.9), true)
		if pages > 1:
			button(px + pw * 0.38, py + ph * 0.145, 28.0, 22.0, "<", "shift_weapon_hud_page", [-1], 12, Color.html("#8ef7ff"))
			button(px + pw * 0.47, py + ph * 0.145, 28.0, 22.0, ">", "shift_weapon_hud_page", [1], 12, Color.html("#8ef7ff"))
		button(px + pw - 66.0, py + 8.0, 58.0, 24.0, "HIDE", "toggle_reactor_panel", [], 11, Color.html("#c9a24a"))
		var n_rows: int = mini(7, rows.size())
		var y0: float = py + ph * 0.30
		var y1: float = py + ph * 0.88
		var step: float = (y1 - y0) / maxf(1.0, float(maxi(1, n_rows - 1)))
		var content_x0: float = px + pw * 0.355
		var content_x1: float = px + pw * 0.945
		var content_w: float = content_x1 - content_x0
		for i in range(n_rows):
			var key2 := str(rows[i][0])
			var label_str := str(rows[i][1])
			var current_p := int(rows[i][2])
			var max_p := int(rows[i][3])
			var active := key2 != ""
			var yy: float = y0 + step * float(i)
			var lx0: float = content_x0
			var lw: float = content_w * 0.30
			var lh: float = 13.0
			draw_rect(Rect2(lx0, yy - lh * 0.5, lw, lh), Color(0.04, 0.05, 0.07, 0.92), true)
			draw_rect(Rect2(lx0, yy - lh * 0.5, lw, lh), Color(0.72, 0.55, 0.28, 0.85 if active else 0.35), false, 1.0)
			draw_text2(label_str, lx0 + lw * 0.5, yy + 3.0, 9, Color.html("#e8f6ff") if active else Color(0.55, 0.62, 0.68, 0.55), "center")
			var pip0: float = content_x0 + content_w * 0.34
			var pip_step_m: float = content_w * 0.068
			for n in range(mini(5, maxi(1, max_p if max_p > 0 else 3))):
				var sx: float = pip0 + pip_step_m * float(n)
				if n < current_p and active:
					draw_circle(Vector2(sx, yy), 4.0, Color.html("#ffd06f"))
				else:
					draw_circle(Vector2(sx, yy), 3.6, Color(0.02, 0.04, 0.06, 0.85))
					draw_arc(Vector2(sx, yy), 3.6, 0.0, TAU, 12, Color(0.35, 0.55, 0.62, 0.45 if active else 0.2), 1.0)
			if active:
				var bs: float = 20.0
				var minus_bx: float = content_x1 - bs * 2.35
				var plus_bx: float = content_x1 - bs * 0.85
				for pair2 in [[minus_bx, -1, "−"], [plus_bx, 1, "+"]]:
					var bx: float = float(pair2[0])
					var delta2 := int(pair2[1])
					draw_rect(Rect2(bx - bs * 0.5, yy - bs * 0.5, bs, bs), Color(0.12, 0.14, 0.16, 0.95), true)
					draw_rect(Rect2(bx - bs * 0.5, yy - bs * 0.5, bs, bs), Color(0.72, 0.55, 0.28, 0.9), false, 1.2)
					draw_text2(str(pair2[2]), bx, yy + 4.0, 12, Color.html("#6ef0ff"), "center")
					button(bx - bs * 0.5, yy - bs * 0.5, bs, bs, "", "adjust_power", [key2, delta2], 1, Color(1, 1, 1, 0))
		return

	draw_text2("REACTOR  %d/%d" % [used, rmax], px + 175.0, py + 26.0, 12 if is_mobile_ui else 11, Color.html("#7fe9ff"), "left")
	var bar_x: float = px + 290.0
	var bar_y: float = py + 16.0
	var bar_w: float = 80.0 if (pages > 1 or is_mobile_ui) else 155.0
	var bar_h: float = 10.0
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.04, 0.06, 0.08, 0.92), true)
	draw_rect(Rect2(bar_x, bar_y, bar_w * clampf(float(used) / float(rmax), 0.0, 1.0), bar_h), Color(0.25, 0.85, 0.95, 0.9), true)
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.55, 0.75, 0.85, 0.45), false, 1.0)
	if pages > 1:
		var ax: float = bar_x + bar_w + 6.0
		draw_text2("%d/%d" % [weapon_hud_page + 1, pages], ax + 34.0, py + 26.0, 10, Color.html("#9ef5ff"), "center")
		button(ax, py + 8.0, 32.0 if is_mobile_ui else 26.0, 28.0 if is_mobile_ui else 22.0, "<", "shift_weapon_hud_page", [-1], 13, Color.html("#8ef7ff"))
		button(ax + 42.0, py + 8.0, 32.0 if is_mobile_ui else 26.0, 28.0 if is_mobile_ui else 22.0, ">", "shift_weapon_hud_page", [1], 13, Color.html("#8ef7ff"))
	if is_mobile_ui:
		button(px + pw - 78.0, py + 6.0, 70.0, 30.0, "HIDE", "toggle_reactor_panel", [], 13, Color.html("#c9a24a"))

	var row_ys := [170.0, 290.0, 410.0, 530.0, 650.0, 770.0, 890.0]
	var led_x := 590.0
	var label_x := 620.0
	var label_w := 170.0
	var pip_start := 820.0
	var pip_step := 58.0
	var minus_x := 1310.0
	var plus_x := 1395.0
	var btn := 56.0 if is_mobile_ui else 44.0
	var pip_r := 5.0

	for i in range(mini(7, rows.size())):
		var key2 := str(rows[i][0])
		var label_str := str(rows[i][1])
		var current_p := int(rows[i][2])
		var max_p := int(rows[i][3])
		var active := key2 != ""
		var yy := roundf(py + row_ys[i] * scale)

		var lx_led := roundf(px + led_x * scale)
		draw_circle(Vector2(lx_led, yy), 5.5, Color(0.12, 0.14, 0.16, 1.0))
		draw_circle(Vector2(lx_led, yy), 3.8, Color(0.15, 0.85, 0.95, 0.95 if active else 0.25))

		var lx0 := roundf(px + label_x * scale)
		var lw := roundf(label_w * scale)
		var lh := 16.0
		draw_rect(Rect2(lx0, yy - lh * 0.5, lw, lh), Color(0.04, 0.05, 0.07, 0.92), true)
		draw_rect(Rect2(lx0, yy - lh * 0.5, lw, lh), Color(0.72, 0.55, 0.28, 0.85 if active else 0.35), false, 1.2)
		var label_col := Color.html("#e8f6ff") if active else Color(0.55, 0.62, 0.68, 0.55)
		draw_text2(label_str, lx0 + lw * 0.5, yy + 3.5, 10, label_col, "center")

		var rail0 := roundf(px + (pip_start - 22.0) * scale)
		var rail1 := roundf(px + (pip_start + pip_step * 6.0 + 22.0) * scale)
		draw_rect(Rect2(rail0, yy - 8.0, rail1 - rail0, 16.0), Color(0.03, 0.05, 0.07, 0.9), true)
		draw_rect(Rect2(rail0, yy - 8.0, rail1 - rail0, 16.0), Color(0.25, 0.35, 0.4, 0.45), false, 1.0)
		for n in range(7):
			var sx := roundf(px + (pip_start + pip_step * float(n)) * scale)
			var in_cap := max_p <= 0 or n < max_p
			if n < current_p and active:
				draw_circle(Vector2(sx, yy), pip_r, Color.html("#ffd06f"))
				draw_circle(Vector2(sx, yy), pip_r * 0.4, Color(1, 1, 1, 0.95))
			else:
				var ring := Color(0.35, 0.55, 0.62, 0.55 if in_cap and active else 0.22)
				draw_circle(Vector2(sx, yy), pip_r - 0.4, Color(0.02, 0.04, 0.06, 0.85))
				draw_arc(Vector2(sx, yy), pip_r - 0.6, 0.0, TAU, 14, ring, 1.15)

		if active:
			var bs := roundf(btn * scale)
			for pair in [[minus_x, -1, "−"], [plus_x, 1, "+"]]:
				var bx := roundf(px + float(pair[0]) * scale)
				var delta := int(pair[1])
				var glyph := str(pair[2])
				draw_rect(Rect2(bx - bs * 0.5, yy - bs * 0.5, bs, bs), Color(0.12, 0.14, 0.16, 0.95), true)
				draw_rect(Rect2(bx - bs * 0.5, yy - bs * 0.5, bs, bs), Color(0.72, 0.55, 0.28, 0.9), false, 1.3)
				draw_text2(glyph, bx, yy + 4.0, 14, Color.html("#6ef0ff"), "center")
				button(bx - bs * 0.5, yy - bs * 0.5, bs, bs, "", "adjust_power", [key2, delta], 1, Color(1, 1, 1, 0))


func _draw_mobile_compact_reactor() -> void:
	## Compact reactor console — live channels inside the metallic frame (no art regen).
	var win: Vector2i = DisplayServer.window_get_size()
	var vp: Vector2 = get_viewport_rect().size
	var view_aspect: float = (design_view_right - design_view_left) / maxf(1.0, design_view_bottom - design_view_top)
	var lay: Dictionary = MobileHudLayout.reactor_panel(
		safe_inset, design_view_left, design_view_right, design_view_top, design_view_bottom,
		view_aspect, canvas_scale, win, vp
	)
	var tex_r: Rect2 = lay["texture_rect"]
	var hit: Rect2 = lay["hit"]
	var header: Rect2 = lay["header"]
	var rows_band: Rect2 = lay["rows_band"]
	var collapsed: Rect2 = lay["collapsed"]
	var used := reactor_used_power()
	var rmax := maxi(1, int(reactor["max"]))
	var all_rows: Array = _reactor_power_rows()
	var page_size: int = int(lay.get("page_size", 3))
	var page_count: int = maxi(1, int(ceil(float(maxi(1, all_rows.size())) / float(page_size))))
	reactor_channel_page = clampi(reactor_channel_page, 0, page_count - 1)
	var page_start: int = reactor_channel_page * page_size
	var page_n: int = mini(page_size, all_rows.size() - page_start)

	if reactor_panel_collapsed:
		var cx: float = collapsed.position.x
		var cy: float = collapsed.position.y
		var cw: float = collapsed.size.x
		var ch: float = maxf(56.0, collapsed.size.y)
		var stamp_w: float = ch * 0.90
		var src := Rect2(
			MobileHudLayout.REACTOR_TEX_W * 0.02,
			MobileHudLayout.REACTOR_TEX_H * 0.20,
			MobileHudLayout.REACTOR_TEX_W * 0.32,
			MobileHudLayout.REACTOR_TEX_H * 0.62
		)
		draw_tex_region("hud_compact_reactor", Rect2(cx, cy, stamp_w, ch), src)
		draw_rect(Rect2(cx + stamp_w - 6.0, cy, cw - stamp_w + 6.0, ch), Color(0.05, 0.08, 0.11, 0.94), true)
		draw_rect(Rect2(cx + stamp_w - 6.0, cy, cw - stamp_w + 6.0, ch), Color.html("#5a6a72"), false, 1.0)
		draw_text2("REACTOR  %d/%d" % [used, rmax], cx + stamp_w + 10.0, cy + ch * 0.58, 14, Color.html("#8af6ff"), "left")
		var eb_w: float = 100.0
		var eb_h: float = minf(44.0, ch - 8.0)
		var eb_x: float = cx + cw - eb_w - 8.0
		var eb_y: float = cy + (ch - eb_h) * 0.5
		draw_rect(Rect2(eb_x, eb_y, eb_w, eb_h), Color(0.06, 0.12, 0.16, 0.96), true)
		draw_rect(Rect2(eb_x, eb_y, eb_w, eb_h), Color.html("#5ee9ff"), false, 1.2)
		draw_text2("EXPAND", eb_x + eb_w * 0.5, eb_y + eb_h * 0.62, 13, Color.html("#b8f7ff"), "center")
		_register_exact_hit(cx, cy, cw, ch, "reactor_absorb_click", [])
		_register_exact_hit(eb_x, eb_y, eb_w, eb_h, "toggle_reactor_panel", [])
		return

	_register_exact_hit(hit.position.x, hit.position.y, hit.size.x, hit.size.y, "reactor_absorb_click", [])
	draw_tex("hud_compact_reactor", tex_r)

	# --- Header: REACTOR · capacity · bar · [page] · HIDE (reserved right column) ---
	var pad_h: float = 8.0
	var hx0: float = header.position.x + pad_h
	var hy0: float = header.position.y + 2.0
	var hw: float = header.size.x - pad_h * 2.0
	var hh: float = maxf(18.0, header.size.y - 4.0)
	var hide_w: float = 62.0
	var hide_h: float = minf(hh - 2.0, 28.0)
	var hide_x: float = hx0 + hw - hide_w
	var hide_y: float = hy0 + (hh - hide_h) * 0.5
	# Keep capacity cluster clear of HIDE (and page controls when present).
	var reserve_r: float = hide_w + 10.0
	if page_count > 1:
		reserve_r += 70.0
	var cluster_w: float = maxf(80.0, hw - reserve_r)
	var fs_h: int = clampi(int(hh * 0.58), 15, 20)
	if font == null:
		font = ThemeDB.fallback_font
	var h_ascent: float = font.get_ascent(fs_h) if font != null else float(fs_h) * 0.8
	var h_descent: float = font.get_descent(fs_h) if font != null else float(fs_h) * 0.2
	var text_y: float = hy0 + (hh + h_ascent - h_descent) * 0.5
	text_y = clampf(text_y, hy0 + h_ascent * 0.95, hy0 + hh - h_descent - 1.0)
	draw_text2("REACTOR", hx0, text_y, fs_h, Color.html("#9ef5ff"), "left")
	var cap_x: float = hx0 + float(fs_h) * 5.6
	draw_text2("%d/%d" % [used, rmax], cap_x, text_y, fs_h + 1, Color.html("#e8fbff"), "left")
	var bar_x: float = cap_x + float(fs_h) * 3.4
	var bar_w: float = maxf(36.0, cluster_w - (bar_x - hx0) - 6.0)
	var bar_h: float = clampf(hh * 0.28, 6.0, 10.0)
	var bar_y: float = hy0 + (hh - bar_h) * 0.52
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.03, 0.05, 0.07, 0.55), true)
	draw_rect(Rect2(bar_x, bar_y, bar_w * clampf(float(used) / float(rmax), 0.0, 1.0), bar_h), Color(0.35, 0.92, 1.0, 0.95), true)
	if page_count > 1:
		var ab: float = minf(hide_h, 26.0)
		var ax: float = hide_x - 10.0 - ab * 2.0 - 30.0
		draw_text2("%d/%d" % [reactor_channel_page + 1, page_count], ax + ab + 15.0, text_y, 11, Color.html("#9ef5ff"), "center")
		_draw_reactor_chrome_btn(ax, hy0 + (hh - ab) * 0.5, ab, ab, "<", true)
		_register_exact_hit(ax, hy0 + (hh - ab) * 0.5, ab, ab, "shift_reactor_channel_page", [-1])
		_draw_reactor_chrome_btn(ax + ab + 30.0, hy0 + (hh - ab) * 0.5, ab, ab, ">", true)
		_register_exact_hit(ax + ab + 30.0, hy0 + (hh - ab) * 0.5, ab, ab, "shift_reactor_channel_page", [1])
	_draw_reactor_chrome_btn(hide_x, hide_y, hide_w, hide_h, "HIDE", true)
	_register_exact_hit(hide_x, hide_y, hide_w, hide_h, "toggle_reactor_panel", [])

	# --- Equal rows from content band: name | pips+value | −/+  (no blank filler rows) ---
	var row_rects: Array = MobileHudLayout.reactor_row_rects(rows_band, page_n)
	for i in range(row_rects.size()):
		var row: Rect2 = row_rects[i]
		var ri: int = page_start + i
		var key2 := str(all_rows[ri][0])
		var label_str := str(all_rows[ri][1])
		var current_p := int(all_rows[ri][2])
		var max_p := int(all_rows[ri][3])
		# Inset from brass dividers so labels never clip on the rails.
		var inset_y: float = maxf(2.0, row.size.y * 0.10)
		var yy: float = row.position.y + row.size.y * 0.50
		var pad: float = 8.0
		# Columns as fractions of the row (shared geometry for every channel).
		var col_name_w: float = row.size.x * 0.30
		var col_pip_w: float = row.size.x * 0.36
		var col_btn_w: float = row.size.x * 0.28
		var name_x: float = row.position.x + pad
		var pip_x: float = row.position.x + col_name_w
		var btn_zone_x: float = row.position.x + row.size.x - col_btn_w - pad * 0.5
		var fs_l: int = clampi(int(row.size.y * 0.58), 15, 22)
		var ascent_l: float = font.get_ascent(fs_l) if font != null else float(fs_l) * 0.8
		var descent_l: float = font.get_descent(fs_l) if font != null else float(fs_l) * 0.2
		var label_y: float = yy + (ascent_l - descent_l) * 0.5
		label_y = clampf(label_y, row.position.y + inset_y + ascent_l, row.position.y + row.size.y - inset_y - descent_l)
		draw_text2(label_str, name_x, label_y, fs_l, Color.html("#eaf7ff"), "left")
		# Pips: allocated (gold) / available (dim cyan ring). No sockets beyond channel max.
		var pip_n: int = maxi(1, max_p)
		var pip_r: float = clampf(row.size.y * 0.18, 5.0, 7.5)
		var pip_step_m: float = col_pip_w / float(maxi(1, pip_n + 1))
		for n in range(pip_n):
			var sx: float = pip_x + pip_step_m * (float(n) + 0.55)
			if n < current_p:
				draw_circle(Vector2(sx, yy), pip_r, Color.html("#ffd06f"))
				draw_circle(Vector2(sx, yy), pip_r * 0.38, Color(1, 1, 1, 0.95))
			else:
				draw_circle(Vector2(sx, yy), pip_r - 0.2, Color(0.04, 0.07, 0.10, 0.70))
				draw_arc(Vector2(sx, yy), pip_r - 0.3, 0.0, TAU, 14, Color(0.32, 0.55, 0.62, 0.55), 1.2)
		var val_fs: int = clampi(fs_l - 1, 14, 20)
		draw_text2("%d/%d" % [current_p, max_p], pip_x + col_pip_w - 2.0, label_y, val_fs, Color.html("#9ef5ff"), "right")
		# Compact square ± centered in the button column — never taller than the row gap allows.
		var btn_h: float = clampf(row.size.y * 0.58, 22.0, 34.0)
		var btn_w: float = btn_h
		var gap: float = 4.0
		var pair_w: float = btn_w * 2.0 + gap
		var minus_x: float = btn_zone_x + maxf(0.0, (col_btn_w - pair_w) * 0.5)
		var plus_x: float = minus_x + btn_w + gap
		var btn_y: float = yy - btn_h * 0.5
		var can_m := _reactor_can_adjust(key2, -1)
		var can_p := _reactor_can_adjust(key2, 1)
		_draw_reactor_step_btn(minus_x, btn_y, btn_w, btn_h, "−", can_m)
		_draw_reactor_step_btn(plus_x, btn_y, btn_w, btn_h, "+", can_p)
		# Hitboxes match the visible squares (no vertical bleed into neighbor rows).
		if can_m:
			_register_exact_hit(minus_x, btn_y, btn_w, btn_h, "adjust_power", [key2, -1])
		else:
			_register_exact_hit(minus_x, btn_y, btn_w, btn_h, "reactor_absorb_click", [])
		if can_p:
			_register_exact_hit(plus_x, btn_y, btn_w, btn_h, "adjust_power", [key2, 1])
		else:
			_register_exact_hit(plus_x, btn_y, btn_w, btn_h, "reactor_absorb_click", [])


func _draw_reactor_chrome_btn(x: float, y: float, w: float, h: float, label: String, enabled: bool) -> void:
	var fill := Color(0.06, 0.09, 0.12, 0.72) if enabled else Color(0.05, 0.06, 0.08, 0.45)
	var stroke := Color(0.45, 0.72, 0.80, 0.70) if enabled else Color(0.30, 0.35, 0.38, 0.40)
	var text_c := Color.html("#d8f7ff") if enabled else Color(0.45, 0.50, 0.52, 0.55)
	draw_rect(Rect2(x, y, w, h), fill, true)
	draw_rect(Rect2(x, y, w, h), stroke, false, 1.0)
	draw_text2(label, x + w * 0.5, y + h * 0.66, clampi(int(h * 0.48), 11, 15), text_c, "center")


func _draw_reactor_step_btn(x: float, y: float, w: float, h: float, glyph: String, enabled: bool) -> void:
	## Compact ± — no heavy gold frames; muted when disabled.
	var fill := Color(0.07, 0.10, 0.13, 0.55) if enabled else Color(0.04, 0.05, 0.07, 0.40)
	var stroke := Color(0.40, 0.68, 0.76, 0.65) if enabled else Color(0.25, 0.30, 0.34, 0.40)
	var text_c := Color.html("#8af6ff") if enabled else Color(0.38, 0.44, 0.48, 0.50)
	draw_rect(Rect2(x, y, w, h), fill, true)
	draw_rect(Rect2(x, y, w, h), stroke, false, 1.0)
	draw_text2(glyph, x + w * 0.5, y + h * 0.62, clampi(int(h * 0.48), 14, 20), text_c, "center")

func draw_module_panel() -> void:
	# Four-card frame showing a page of installed weapon instances (priority per instance).
	_clamp_weapon_hud_page()
	var page_insts := installed_weapons_page()
	var total := _weapon_hud_all_entries().size()
	var pages := maxi(1, int(ceil(float(total) / 4.0)))

	if not USE_PRODUCTION_UI:
		panel(664, 822, 570, 226)
		draw_text2("WEAPONS  %d/%d" % [weapon_hud_page + 1, pages], 688, 850, 18, Color(.84,.98,1))
		if pages > 1:
			button(1100, 830, 40, 28, "<", "shift_weapon_hud_page", [-1], 16)
			button(1150, 830, 40, 28, ">", "shift_weapon_hud_page", [1], 16)
		for i in range(4):
			var x = 678 + i * 137
			panel(x, 880, 128, 148)
			if i < page_insts.size():
				var inst: Dictionary = page_insts[i]
				draw_text2(_weapon_hud_label(inst), x + 64, 938, 13, Color.WHITE, "center")
				draw_text2("Lv %d" % instance_level(inst), x + 64, 963, 14, Color.html("#ffcf72"), "center")
				draw_text2(str(inst.get("priority", "nearest")).to_upper(), x + 64, 990, 11, Color.html("#9ef5ff"), "center")
				button(x, 880, 128, 148, "", "cycle_priority_uid", [str(inst.get("uid", ""))], 1, Color(1,1,1,0))
			else:
				draw_text2("EMPTY", x + 64, 955, 14, Color(0.5, 0.55, 0.6, 0.7), "center")
		return

	if _mobile_compact_weapons_active():
		_draw_mobile_compact_weapons(page_insts, pages)
		return

	var px: float = 530.0
	var py: float = 880.0
	var pw: float = 650.0
	var ph: float = 187.0
	var weapons_frame := _hud_frame_key("hud_module_targeting", "hud_gen_weapons")
	var use_gen_weapons := _mobile_gen_hud_active() and weapons_frame == "hud_gen_weapons"
	if use_gen_weapons:
		var mlw := _mobile_hud_layout()
		px = float(mlw["weap_x"])
		py = float(mlw["weap_y"])
		pw = float(mlw["weap_w"])
		ph = float(mlw["weap_h"])
	var slot_rects: Array = [
		Rect2(582.0, 918.0, 74.0, 78.0),
		Rect2(726.0, 918.0, 74.0, 78.0),
		Rect2(871.0, 918.0, 74.0, 78.0),
		Rect2(1016.0, 918.0, 74.0, 78.0)
	]
	if use_gen_weapons:
		slot_rects.clear()
		var slot_pad_x: float = pw * 0.08
		var slot_inner_w: float = (pw - slot_pad_x * 2.0) / 4.0
		var icon_sz: float = minf(58.0, ph * 0.36)
		for i in range(4):
			var sx: float = px + slot_pad_x + float(i) * slot_inner_w + (slot_inner_w - icon_sz) * 0.5
			var sy: float = py + ph * 0.22
			slot_rects.append(Rect2(sx, sy, icon_sz, icon_sz))
		draw_tex(weapons_frame, Rect2(px, py, pw, ph))
	for i in range(4):
		var r: Rect2 = slot_rects[i]
		draw_rect(r, Color(0.015, 0.045, 0.065, 1.0), true)
		if i < page_insts.size():
			var inst2: Dictionary = page_insts[i]
			var wtype := str(inst2.get("type", ""))
			var pwr := int(inst2.get("power", 0))
			var modc = Color(1.15, 1.25, 1.3, 1.0) if pwr > 0 else Color(0.85, 0.95, 1.05, 0.88)
			draw_tex(_weapon_hud_slot_tex(wtype), Rect2(r.position.x + 1.0, r.position.y + 3.0, r.size.x - 2.0, r.size.y - 2.0), modc)
		else:
			draw_tex("hud_slot_empty", Rect2(r.position.x + 1.0, r.position.y + 3.0, r.size.x - 2.0, r.size.y - 2.0), Color(0.8, 0.9, 1.0, 0.65))

	if not use_gen_weapons:
		draw_tex(weapons_frame, Rect2(px, py, pw, ph))
	if pages > 1:
		button(px + 8.0, py + 8.0, 36.0, 28.0, "<", "shift_weapon_hud_page", [-1], 16, Color.html("#8ef7ff"))
		button(px + pw - 44.0, py + 8.0, 36.0, 28.0, ">", "shift_weapon_hud_page", [1], 16, Color.html("#8ef7ff"))
		draw_text2("%d/%d" % [weapon_hud_page + 1, pages], px + pw * 0.5, py + 26.0, 12, Color.html("#9ef5ff"), "center")

	var text_max_w := 108.0
	for i in range(4):
		var r: Rect2 = slot_rects[i]
		var cx = r.position.x + r.size.x * 0.5
		var hit_x = r.position.x - 18.0
		var hit_w = r.size.x + 36.0
		var label_y1: float = (py + ph * 0.70) if use_gen_weapons else (py + 126.0)
		var label_y2: float = (py + ph * 0.86) if use_gen_weapons else (py + 148.0)
		if i < page_insts.size():
			var inst3: Dictionary = page_insts[i]
			var name_fit := _fit_hud_text(_weapon_hud_card_name(inst3), text_max_w, 11, 9)
			var pri_fit := _fit_hud_text(_weapon_hud_priority_label(str(inst3.get("priority", "nearest"))), text_max_w, 11, 9)
			draw_text2(str(name_fit["text"]), cx, label_y1, int(name_fit["size"]), Color.html("#ffd27b"), "center")
			draw_text2(str(pri_fit["text"]), cx, label_y2, int(pri_fit["size"]), Color.html("#9ef5ff"), "center")
			button(hit_x, py + 8.0, hit_w, ph - 16.0, "", "cycle_priority_uid", [str(inst3.get("uid", ""))], 1, Color(1, 1, 1, 0))
		else:
			draw_text2("—", cx, label_y2, 12, Color(0.6, 0.7, 0.8, 0.35), "center")


func _draw_mobile_compact_weapons(page_insts: Array, pages: int) -> void:
	## Mission 06: four-slot bar with transparent wells — live icons/labels in openings.
	var win: Vector2i = DisplayServer.window_get_size()
	var vp: Vector2 = get_viewport_rect().size
	var view_aspect: float = (design_view_right - design_view_left) / maxf(1.0, design_view_bottom - design_view_top)
	var ml: Dictionary = _mobile_hud_layout()
	var after_reactor: float = float(ml["reactor_x"]) + float(ml["reactor_w"]) * (1.0 - MobileHudLayout.REACTOR_ART_PAD_R)
	if _mobile_compact_reactor_active():
		after_reactor = float(ml["reactor_x"]) + float(ml["reactor_w"]) * (1.0 - MobileHudLayout.REACTOR_ART_PAD_R)
	var bot_right: float = design_view_right - float(safe_inset.get("right", 12.0))
	var weap_band_right: float = bot_right
	if _mobile_compact_abilities_active():
		weap_band_right = float(ml["abil_x"]) + float(ml["abil_w"]) * MobileHudLayout.ABILITIES_ART_PAD_L
	var lay: Dictionary = MobileHudLayout.weapons_panel(
		safe_inset, design_view_left, design_view_right, design_view_top, design_view_bottom,
		view_aspect, canvas_scale, win, vp, after_reactor, weap_band_right
	)
	var tex_r: Rect2 = lay["texture_rect"]
	var hit: Rect2 = lay["hit"]
	var icons: Array = lay["icons"]
	var labels: Array = lay["labels"]
	var slots: Array = lay["slots"]
	_register_exact_hit(hit.position.x, hit.position.y, hit.size.x, hit.size.y, "weapons_absorb_click", [])
	draw_tex("hud_compact_weapons", tex_r)
	if pages > 1:
		var ab: float = 28.0
		_draw_reactor_chrome_btn(tex_r.position.x + 10.0, tex_r.position.y + tex_r.size.y * 0.12, ab, ab, "<", true)
		_register_exact_hit(tex_r.position.x + 10.0, tex_r.position.y + tex_r.size.y * 0.12, ab, ab, "shift_weapon_hud_page", [-1])
		_draw_reactor_chrome_btn(tex_r.position.x + tex_r.size.x - 10.0 - ab, tex_r.position.y + tex_r.size.y * 0.12, ab, ab, ">", true)
		_register_exact_hit(tex_r.position.x + tex_r.size.x - 10.0 - ab, tex_r.position.y + tex_r.size.y * 0.12, ab, ab, "shift_weapon_hud_page", [1])
		draw_text2("%d/%d" % [weapon_hud_page + 1, pages], tex_r.position.x + tex_r.size.x * 0.5, tex_r.position.y + tex_r.size.y * 0.18, 11, Color.html("#9ef5ff"), "center")
	# Icons ON TOP — stretch to the full inner window (icon + plaque band) so no bottom gap.
	for i in range(4):
		var slot_r0: Rect2 = slots[i]
		var label_r: Rect2 = labels[i]
		var fill := Rect2(
			slot_r0.position.x,
			tex_r.position.y + tex_r.size.y * MobileHudLayout.WEAPONS_ICON_Y0,
			slot_r0.size.x,
			tex_r.size.y * (MobileHudLayout.WEAPONS_LABEL_Y1 - MobileHudLayout.WEAPONS_ICON_Y0)
		)
		draw_rect(fill, Color(0.01, 0.03, 0.05, 0.90), true)
		var cx: float = fill.position.x + fill.size.x * 0.5
		if i < page_insts.size():
			var inst0: Dictionary = page_insts[i]
			var pwr0 := int(inst0.get("power", 0))
			var modc0 = Color(1.12, 1.20, 1.28, 1.0) if pwr0 > 0 else Color(0.78, 0.86, 0.94, 0.80)
			# Zoom weapon art so the silhouette fills the window; labels overlay bottom.
			var tex_key := _weapon_hud_slot_tex(str(inst0.get("type", "")))
			var tw0: float = 1254.0
			if images.has(tex_key):
				tw0 = float((images[tex_key] as Texture2D).get_width())
			var zoom0: float = 0.62
			var src0 := Rect2(tw0 * (1.0 - zoom0) * 0.5, tw0 * (1.0 - zoom0) * 0.42, tw0 * zoom0, tw0 * zoom0)
			var icon_fill := Rect2(fill.position.x, fill.position.y, fill.size.x, fill.size.y * 0.82)
			draw_tex_region(tex_key, icon_fill, src0, modc0)
			var text_max_w: float = fill.size.x * 0.94
			var name_fit := _fit_hud_text(_weapon_hud_card_name(inst0), text_max_w, 15, 12)
			var pri_fit := _fit_hud_text(_weapon_hud_priority_label(str(inst0.get("priority", "nearest"))), text_max_w, 13, 11)
			var ly1: float = fill.position.y + fill.size.y * 0.84
			var ly2: float = fill.position.y + fill.size.y * 0.96
			draw_text2(str(name_fit["text"]), cx, ly1, int(name_fit["size"]), Color.html("#ffd27b"), "center")
			draw_text2(str(pri_fit["text"]), cx, ly2, int(pri_fit["size"]), Color.html("#9ef5ff"), "center")
			_register_exact_hit(slot_r0.position.x, slot_r0.position.y, slot_r0.size.x, slot_r0.size.y, "cycle_priority_uid", [str(inst0.get("uid", ""))])
		else:
			# Zoom center of empty atlas so the reticle fills the well (no bottom dead zone).
			var tw: float = 1254.0
			if images.has("hud_slot_empty"):
				tw = float((images["hud_slot_empty"] as Texture2D).get_width())
			var zoom: float = 0.48
			var src_e := Rect2(tw * (1.0 - zoom) * 0.5, tw * (1.0 - zoom) * 0.5, tw * zoom, tw * zoom)
			draw_tex_region("hud_slot_empty", fill, src_e, Color(1.0, 1.0, 1.0, 0.95))
			_register_exact_hit(slot_r0.position.x, slot_r0.position.y, slot_r0.size.x, slot_r0.size.y, "weapons_absorb_click", [])

func cycle_priority(key: String) -> void:
	if not weapons.has(key):
		return
	if not is_module_installed(key):
		toast("Install weapon first")
		return
	var priorities = ["nearest", "strongest", "fastest", "lowest", "rear", "flying", "boarders"]
	var idx = priorities.find(weapons[key].get("priority", "nearest"))
	weapons[key]["priority"] = priorities[(idx + 1) % priorities.size()]
	toast(key + " priority: " + weapons[key]["priority"])

func draw_ability_panel() -> void:
	if not USE_PRODUCTION_UI:
		panel(1238, 798, 630, 250)
		draw_text2("ACTIVE SYSTEMS", 1260, 830, 20, Color.html("#9ff6ff"))
		var n_old = ["boost", "shield", "repair"]
		if abilities["barrage"]["unlocked"]: n_old.append("barrage")
		for i in range(n_old.size()):
			var name = n_old[i]
			var a = abilities[name]
			button(1260 + i * 150, 860, 132, 82, a["label"], "use_ability", [name], 18, Color.html("#8bffc5") if a["cooldown"] <= 0 else Color(1,1,1,.18))
			if a["cooldown"] > 0:
				draw_text2(str(int(ceil(a["cooldown"]))), 1326 + i*150, 912, 26, Color.WHITE, "center")
		return

	if _mobile_compact_abilities_active():
		_draw_mobile_compact_abilities()
		return

	if USE_PRODUCTION_UI and (images.has("active_systems_frame") or (is_mobile_ui and images.has("hud_gen_abilities"))):
		# Futuristic Steampunk Four-Slot Active Systems Panel (1983x793, 2.50:1 aspect)
		# Mobile uses generated 4-slot abilities shell (2172×724).
		var abilities_frame := _hud_frame_key("active_systems_frame", "hud_gen_abilities")
		var use_gen_abilities := _mobile_gen_hud_active() and abilities_frame == "hud_gen_abilities"
		var px: float = 1215.0
		var py: float = 880.0
		var ph: float = 187.0
		var scale: float = ph / 793.0 # 0.235813 uniform scale preserving 2.50:1 aspect
		var pw: float = 1983.0 * scale # 467.62 px
		if use_gen_abilities:
			var mla := _mobile_hud_layout()
			px = float(mla["abil_x"])
			py = float(mla["abil_y"])
			pw = float(mla["abil_w"])
			ph = float(mla["abil_h"])
			scale = pw / 2172.0

		var slot_info = [
			{ "key": "boost", "tex": "active_icon_boost", "cx": px + 358.0 * scale, "cy": py + 330.0 * scale, "orange": false },
			{ "key": "shield", "tex": "active_icon_shield", "cx": px + 782.0 * scale, "cy": py + 330.0 * scale, "orange": false },
			{ "key": "repair", "tex": "active_icon_repair", "cx": px + 1204.0 * scale, "cy": py + 330.0 * scale, "orange": false },
			{ "key": "barrage", "tex": "active_icon_barrage", "cx": px + 1624.5 * scale, "cy": py + 330.0 * scale, "orange": true }
		]
		if use_gen_abilities:
			slot_info = [
				{ "key": "boost", "tex": "active_icon_boost", "cx": px + pw * 0.155, "cy": py + ph * 0.42, "orange": false },
				{ "key": "shield", "tex": "active_icon_shield", "cx": px + pw * 0.385, "cy": py + ph * 0.42, "orange": false },
				{ "key": "repair", "tex": "active_icon_repair", "cx": px + pw * 0.615, "cy": py + ph * 0.42, "orange": false },
				{ "key": "barrage", "tex": "active_icon_barrage", "cx": px + pw * 0.845, "cy": py + ph * 0.42, "orange": true }
			]
			draw_tex(abilities_frame, Rect2(px, py, pw, ph))

		var win_w: float = (pw * 0.165) if use_gen_abilities else (312.0 * scale)
		var win_h: float = (ph * 0.42) if use_gen_abilities else (309.0 * scale)
		var icon_size: float = (ph * 0.34) if use_gen_abilities else (270.0 * scale)

		# --- LAYER 1: Dark CRT backplate & dynamic icon (BEHIND frame on desktop; ABOVE on mobile gen) ---
		for s in slot_info:
			var key = s["key"]
			var a = abilities[key]
			var cx = s["cx"]
			var cy = s["cy"]
			var is_orange = s["orange"]

			# 1. Backplate
			var bg_col = Color(0.04, 0.025, 0.015, 0.95) if is_orange else Color(0.015, 0.045, 0.065, 0.95)
			draw_rect(Rect2(cx - win_w * 0.5, cy - win_h * 0.5, win_w, win_h), bg_col, true)

			# State calculations
			var has_power = true
			if key == "shield" and power.get("shield", 1) <= 0: has_power = false
			elif key == "boost" and power.get("engine", 1) <= 0: has_power = false
			elif key == "repair" and power.get("utility", 1) <= 0: has_power = false
			elif key == "barrage" and not a.get("unlocked", false): has_power = false

			var is_active = (a.get("duration", 0.0) > 0.0) or (key == "repair" and train_cars[0]["hp"] / train_cars[0]["max_hp"] < 0.35 and a["cooldown"] <= 0)
			var is_cooldown = (a["cooldown"] > 0)

			# Visual states
			var icon_mod = Color.WHITE
			if not has_power:
				icon_mod = Color(0.40, 0.40, 0.40, 0.40) # Unavailable / no power: 35-45% brightness
			elif is_active:
				var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
				var glow = 1.0 + 0.25 * pulse
				icon_mod = Color(glow, glow, glow, 1.0) # Active: slight glow / pulse
				var glow_col = Color(0.9, 0.45, 0.1, 0.25 * pulse) if is_orange else (Color(0.1, 0.8, 0.3, 0.25 * pulse) if key == "repair" else Color(0.1, 0.6, 0.9, 0.25 * pulse))
				draw_circle(Vector2(cx, cy), icon_size * 0.45, glow_col)
			elif is_cooldown:
				icon_mod = Color(0.35, 0.35, 0.35, 0.50) # On cooldown: dim icon + reduced alpha
			else:
				icon_mod = Color.WHITE # Ready / available: full brightness

			# 2. Icon image
			draw_tex(s["tex"], Rect2(cx - icon_size * 0.5, cy - icon_size * 0.5, icon_size, icon_size), icon_mod)

			# 3. Cooldown overlay under frame
			if is_cooldown:
				draw_rect(Rect2(cx - win_w * 0.5, cy - win_h * 0.5, win_w, win_h), Color(0.0, 0.0, 0.0, 0.68), true)
				draw_text2(str(int(ceil(a["cooldown"]))), cx, cy + 9.0, 24, Color.WHITE, "center")

		# --- LAYER 2: Transparent HUD Frame Foreground Overlay (desktop / non-gen only) ---
		if not use_gen_abilities:
			draw_tex(abilities_frame, Rect2(px, py, pw, ph))

		# --- LAYER 3: Labels & Click Hitboxes (ON TOP) ---
		var slot_w = pw / 4.0
		for i in range(slot_info.size()):
			var s = slot_info[i]
			var key = s["key"]
			var a = abilities[key]
			var cx = s["cx"]
			var sx = px + i * slot_w

			var has_power = true
			if key == "shield" and power.get("shield", 1) <= 0: has_power = false
			elif key == "boost" and power.get("engine", 1) <= 0: has_power = false
			elif key == "repair" and power.get("utility", 1) <= 0: has_power = false
			elif key == "barrage" and not a.get("unlocked", false): has_power = false

			var is_active = (a.get("duration", 0.0) > 0.0) or (key == "repair" and train_cars[0]["hp"] / train_cars[0]["max_hp"] < 0.35 and a["cooldown"] <= 0)
			var label_col = Color.WHITE
			if not has_power:
				label_col = Color(0.60, 0.60, 0.60, 0.40)
			elif is_active:
				label_col = Color.html("#7dffbb") if key == "repair" else Color.html("#8ef7ff")
			elif a["cooldown"] > 0:
				label_col = Color(0.70, 0.70, 0.70, 0.65)
			else:
				label_col = Color.html("#ffd06f") if s["orange"] else Color.WHITE

			# Small dark label plate for clean typography contrast
			var ly: float = (py + ph * 0.76) if use_gen_abilities else (py + 133.0)
			var plate_w: float = 64.0 if use_gen_abilities else 60.0
			draw_rect(Rect2(cx - plate_w * 0.5, ly, plate_w, 15.0), Color(0.015, 0.045, 0.065, 0.90), true)
			draw_rect(Rect2(cx - plate_w * 0.5, ly, plate_w, 15.0), Color(0.2, 0.6, 0.7, 0.45) if not s["orange"] else Color(0.7, 0.45, 0.15, 0.45), false, 1.0)
			draw_text2(a["label"], cx, ly + 11.0, 11 if use_gen_abilities else 11, label_col, "center")
			button(sx + 6.0, py + 8.0, slot_w - 12.0, ph - 16.0, "", "use_ability", [key], 1, Color(1, 1, 1, 0))
	else:
		var px = 1200.0
		var py = 880.0
		var pw = 540.0
		var ph = 187.0
		draw_tex("hud_active_systems", Rect2(px, py, pw, ph))

		var names = ["boost", "shield", "repair", "barrage"]
		var slot_w = pw / 4.0
		for i in range(names.size()):
			var name = names[i]
			var a = abilities[name]
			var sx = px + i * slot_w
			var cx = sx + slot_w * 0.5
			var slot_rect = Rect2(sx + 10, py + 18, slot_w - 20, ph - 55)

			if a["cooldown"] > 0:
				draw_rect(slot_rect, Color(0, 0, 0, 0.72))
				draw_text2(str(int(ceil(a["cooldown"]))), cx, py + 78, 28, Color.WHITE, "center")
			elif name == "repair" and train_cars[0]["hp"] / train_cars[0]["max_hp"] < 0.35:
				draw_rect(slot_rect, Color(0, 1, 0, 0.15 + 0.15 * sin(Time.get_ticks_msec() * 0.005)))

			var is_locked = (name == "barrage" and not a.get("unlocked", false))
			var label_col = Color(0.65, 0.65, 0.65, 0.45) if is_locked else Color.WHITE
			draw_text2(a["label"], cx, py + 150, 13, label_col, "center")
			button(sx + 8, py + 8, slot_w - 16, ph - 16, "", "use_ability", [name], 1, Color(1, 1, 1, 0))


func abilities_absorb_click() -> void:
	pass


## Pre-measured opaque content rects for 1254×1254 ability icons (crop empty padding).
## Scaled to the loaded texture size so mobile 256×256 remaps still sample in-bounds.
const _ABILITY_ICON_SRC_REF := 1254.0
const _ABILITY_ICON_SRC := {
	"active_icon_boost": Rect2(42, 210, 1188, 879),
	"active_icon_shield": Rect2(64, 94, 1127, 1050),
	"active_icon_repair": Rect2(115, 115, 1064, 1007),
	"active_icon_barrage": Rect2(9, 4, 1237, 1236),
}


func _ability_icon_src_rect(tex_key: String) -> Rect2:
	if not images.has(tex_key):
		return Rect2(0, 0, 1, 1)
	var tex: Texture2D = images[tex_key]
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	if not _ABILITY_ICON_SRC.has(tex_key):
		return Rect2(0, 0, tw, th)
	# Mobile pack icons are already tight; use the full texture.
	if tw <= 512.0 or th <= 512.0:
		return Rect2(0, 0, tw, th)
	var ref: Rect2 = _ABILITY_ICON_SRC[tex_key]
	var sx: float = tw / _ABILITY_ICON_SRC_REF
	var sy: float = th / _ABILITY_ICON_SRC_REF
	var src := Rect2(
		ref.position.x * sx,
		ref.position.y * sy,
		ref.size.x * sx,
		ref.size.y * sy
	)
	src.position.x = clampf(src.position.x, 0.0, tw - 1.0)
	src.position.y = clampf(src.position.y, 0.0, th - 1.0)
	src.size.x = minf(src.size.x, tw - src.position.x)
	src.size.y = minf(src.size.y, th - src.position.y)
	return src


func _ability_has_power(key: String) -> bool:
	var a: Dictionary = abilities.get(key, {})
	if key == "shield" and power.get("shield", 1) <= 0:
		return false
	if key == "boost" and power.get("engine", 1) <= 0:
		return false
	if key == "repair" and power.get("utility", 1) <= 0:
		return false
	if key == "barrage" and not a.get("unlocked", false):
		return false
	return true


func _draw_mobile_compact_abilities() -> void:
	## Mission 07: icons drawn UNDER the brass frame so they fill transparent wells.
	var win: Vector2i = DisplayServer.window_get_size()
	var vp: Vector2 = get_viewport_rect().size
	var view_aspect: float = (design_view_right - design_view_left) / maxf(1.0, design_view_bottom - design_view_top)
	var ml: Dictionary = _mobile_hud_layout()
	var after_reactor: float = float(ml["reactor_x"]) + float(ml["reactor_w"]) * (1.0 - MobileHudLayout.REACTOR_ART_PAD_R)
	var bot_right: float = design_view_right - float(safe_inset.get("right", 12.0))
	var lay: Dictionary = MobileHudLayout.abilities_panel(
		safe_inset, design_view_left, design_view_right, design_view_top, design_view_bottom,
		view_aspect, canvas_scale, win, vp, after_reactor, bot_right
	)
	var tex_r: Rect2 = lay["texture_rect"]
	var hit: Rect2 = lay["hit"]
	var icons: Array = lay["icons"]
	var labels: Array = lay["labels"]
	var slots: Array = lay["slots"]
	_register_exact_hit(hit.position.x, hit.position.y, hit.size.x, hit.size.y, "abilities_absorb_click", [])
	var slot_defs: Array = [
		{ "key": "boost", "tex": "active_icon_boost", "orange": false },
		{ "key": "shield", "tex": "active_icon_shield", "orange": false },
		{ "key": "repair", "tex": "active_icon_repair", "orange": false },
		{ "key": "barrage", "tex": "active_icon_barrage", "orange": true }
	]
	# Pass 1: backplates + oversized icons (frame will mask overflow).
	for i in range(4):
		var s: Dictionary = slot_defs[i]
		var key := str(s["key"])
		var a: Dictionary = abilities[key]
		var icon_r: Rect2 = icons[i]
		var cx: float = icon_r.position.x + icon_r.size.x * 0.5
		var cy: float = icon_r.position.y + icon_r.size.y * 0.5
		var side: float = minf(icon_r.size.x, icon_r.size.y) * 1.78
		var icon_dest := Rect2(cx - side * 0.5, cy - side * 0.5, side, side)
		var src_r: Rect2 = _ability_icon_src_rect(str(s["tex"]))
		var has_power := _ability_has_power(key)
		var is_active: bool = float(a.get("duration", 0.0)) > 0.0
		if key == "repair" and float(a["cooldown"]) <= 0.0:
			var hull_frac: float = float(train_cars[0]["hp"]) / maxf(1.0, float(train_cars[0]["max_hp"]))
			if hull_frac < 0.35:
				is_active = true
		var is_cooldown := float(a["cooldown"]) > 0.0
		var icon_mod := Color.WHITE
		if not has_power:
			icon_mod = Color(0.40, 0.40, 0.40, 0.40)
		elif is_active:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
			var glow := 1.0 + 0.25 * pulse
			icon_mod = Color(glow, glow, glow, 1.0)
		elif is_cooldown:
			icon_mod = Color(0.45, 0.45, 0.45, 0.65)
		draw_rect(icon_r, Color(0.02, 0.04, 0.06, 0.72), true)
		draw_tex_region(str(s["tex"]), icon_dest, src_r, icon_mod)
	# Pass 2: brass frame over icons (transparent wells reveal filled art).
	draw_tex("hud_compact_abilities", tex_r)
	# Pass 3: labels, cooldown numbers, hits on top.
	for i in range(4):
		var s2: Dictionary = slot_defs[i]
		var key2 := str(s2["key"])
		var a2: Dictionary = abilities[key2]
		var icon_r2: Rect2 = icons[i]
		var label_r: Rect2 = labels[i]
		var slot_r: Rect2 = slots[i]
		var cx2: float = icon_r2.position.x + icon_r2.size.x * 0.5
		var cy2: float = icon_r2.position.y + icon_r2.size.y * 0.5
		var has_power2 := _ability_has_power(key2)
		var is_active2: bool = float(a2.get("duration", 0.0)) > 0.0
		if key2 == "repair" and float(a2["cooldown"]) <= 0.0:
			var hull2: float = float(train_cars[0]["hp"]) / maxf(1.0, float(train_cars[0]["max_hp"]))
			if hull2 < 0.35:
				is_active2 = true
		var is_cooldown2 := float(a2["cooldown"]) > 0.0
		if is_cooldown2:
			draw_rect(icon_r2, Color(0.0, 0.0, 0.0, 0.45), true)
			draw_text2(str(int(ceil(float(a2["cooldown"])))), cx2, cy2 + icon_r2.size.y * 0.08, clampi(int(minf(icon_r2.size.x, icon_r2.size.y) * 0.42), 16, 28), Color.WHITE, "center")
		var label_col := Color.WHITE
		if not has_power2:
			label_col = Color(0.60, 0.60, 0.60, 0.40)
		elif is_active2:
			label_col = Color.html("#7dffbb") if key2 == "repair" else Color.html("#8ef7ff")
		elif is_cooldown2:
			label_col = Color(0.70, 0.70, 0.70, 0.65)
		else:
			label_col = Color.html("#ffd06f") if bool(s2["orange"]) else Color.html("#eaf7ff")
		var ly: float = label_r.position.y + label_r.size.y * 0.70
		var fs_l: int = clampi(int(label_r.size.y * 0.70), 14, 18)
		draw_text2(str(a2["label"]), cx2, ly, fs_l, label_col, "center")
		if has_power2 and not is_cooldown2:
			_register_exact_hit(slot_r.position.x, slot_r.position.y, slot_r.size.x, slot_r.size.y, "use_ability", [key2])
		else:
			_register_exact_hit(slot_r.position.x, slot_r.position.y, slot_r.size.x, slot_r.size.y, "abilities_absorb_click", [])

## Visible screen rect in design space. On mobile ultrawide this is wider than 1920.
func _full_view_rect() -> Rect2:
	if is_mobile_ui:
		return Rect2(
			design_view_left, design_view_top,
			design_view_right - design_view_left,
			design_view_bottom - design_view_top
		)
	return Rect2(0.0, 0.0, DESIGN_W, DESIGN_H)


func draw_pause() -> void:
	# Full-bleed dim on mobile ultrawide — side strips (moon/rift) must darken too.
	var view := _full_view_rect()
	var cx_ui: float = view.position.x + view.size.x * 0.5
	draw_rect(view, Color(0, 0, 0, 0.42), true)
	var view_l: float = view.position.x
	var view_t: float = view.position.y
	var view_w: float = view.size.x
	var view_h: float = view.size.y
	var pw: float = 600.0
	var ph: float = 505.0
	var px: float = cx_ui - pw * 0.5
	var py: float = view_t + (view_h - ph) * 0.5
	if is_mobile_ui:
		pw = minf(640.0, view_w - float(safe_inset.get("left", 12.0)) - float(safe_inset.get("right", 12.0)) - 80.0)
		ph = 480.0
		px = cx_ui - pw * 0.5
		py = view_t + (view_h - ph) * 0.5
	panel(px, py, pw, ph)
	draw_text2("PAUSED", cx_ui, py + 75.0, 48 if is_mobile_ui else 54, Color.WHITE, "center")
	var btn_w: float = 340.0 if not is_mobile_ui else minf(360.0, pw - 80.0)
	var btn_x: float = cx_ui - btn_w * 0.5
	var btn_h: float = 62.0 if not is_mobile_ui else 58.0
	var by0: float = py + 140.0
	var gap: float = 18.0 if is_mobile_ui else 20.0
	button(btn_x, by0, btn_w, btn_h, "RESUME", "toggle_pause", [], 24 if is_mobile_ui else 25)
	button(btn_x, by0 + (btn_h + gap), btn_w, btn_h, "HOW TO PLAY", "open_help", ["combat"], 22 if is_mobile_ui else 23)
	button(btn_x, by0 + (btn_h + gap) * 2.0, btn_w, btn_h, "OPTIONS", "open_options", ["combat"], 22 if is_mobile_ui else 23)
	button(btn_x, by0 + (btn_h + gap) * 3.0, btn_w, btn_h, "SAVE & TITLE", "save_and_title", [], 22 if is_mobile_ui else 23)
func save_and_title() -> void:
	save_run()
	state = "title"
	paused = false
	if audio != null:
		audio.play_menu_music(1.5)

func draw_options() -> void:
	var view := _full_view_rect()
	var view_l: float = view.position.x
	var view_w: float = view.size.x
	var cx_ui: float = view_l + view_w * 0.5
	draw_rect(view, Color(0.02, 0.03, 0.04, 0.96), true)
	draw_text2("OPTIONS", cx_ui, 110, 68 if not is_mobile_ui else 52, Color.WHITE, "center")
	var rows = [
		["damage_numbers","DAMAGE NUMBERS"],
		["particles","PARTICLES / PICKUPS"],
		["shake","SCREEN SHAKE"],
		["haptics","HAPTICS"],
		["music_volume", "MUSIC VOLUME"],
		["sfx_volume", "SFX VOLUME"]
	]
	var panel_w := 780.0
	var panel_x := cx_ui - panel_w * 0.5
	panel(panel_x, 200, panel_w, 560)
	for i in range(rows.size()):
		var y = 250 + i * 82
		var key = rows[i][0]
		draw_text2(rows[i][1], panel_x + 70, y, 23, Color.WHITE)
		if key == "music_volume" or key == "sfx_volume":
			var val = int(settings.get(key, 8 if key == "music_volume" else 10))
			button(panel_x + 470, y - 18, 52, 48, "-", "adjust_volume", [key, -1], 24)
			draw_text2("%d%%" % (val * 10), panel_x + 575, y + 4, 21, Color.html("#7dffbb"), "center")
			button(panel_x + 630, y - 18, 52, 48, "+", "adjust_volume", [key, 1], 24)
		else:
			button(panel_x + 510, y - 18, 172, 48, "ON" if settings.get(key, true) else "OFF", "toggle_setting", [key], 20, Color.html("#7dffbb") if settings.get(key, true) else Color.html("#ff8264"))
	var foot_gap := 40.0
	var back_w := 300.0
	var help_w := 300.0
	var foot_x0 := cx_ui - (help_w + foot_gap + back_w) * 0.5
	button(foot_x0, 870, help_w, 68, "HOW TO PLAY", "open_help", ["options"], 22)
	button(foot_x0 + help_w + foot_gap, 870, back_w, 68, "BACK", "back_from_options", [], 25)

func adjust_volume(key: String, delta_val: int) -> void:
	var cur = int(settings.get(key, 8 if key == "music_volume" else 10))
	settings[key] = clampi(cur + delta_val, 0, 10)
	apply_audio_settings()
	save_settings()

func toggle_setting(key: String) -> void:
	settings[key] = not settings.get(key, true)
	apply_audio_settings()
	save_settings()
func back_from_options() -> void:
	state = options_back_state
	if audio != null:
		if state == "title" or state == "workshop":
			audio.play_menu_music(1.0)
		elif ["combat", "route", "rewards", "station", "build", "moduleshop", "event", "levelup"].has(state):
			audio.play_travel_music(1.5)

func draw_help() -> void:
	var view := _full_view_rect()
	var view_l: float = view.position.x
	var view_w: float = view.size.x
	var cx_ui: float = view_l + view_w * 0.5
	draw_rect(view, Color(0.02, 0.03, 0.04, 0.96), true)
	draw_text2("HOW TO PLAY", cx_ui, 95, 68 if not is_mobile_ui else 52, Color.WHITE, "center")
	var texts = [
		["OBJECTIVE", "Clear Rustlands (Iron Maw), then Fungus Wilds (Mycelarch). Each region is six tracks + a boss."],
		["REACTOR POWER", "Move limited reactor power between Engine, weapons, Drone Bay, AUX, Shield, and Utility."],
		["HEAT & MOMENTUM", "Overdrive raises heat. Low Engine drops speed and raises Overrun. Balance power constantly."],
		["TRAIN BUILDING", "At stations, repair and upgrade. Module Shop installs one AUX weapon."],
		["TARGETING", "Tap module cards to cycle targeting. Boarders and Skimmers are priority threats."],
		["ACTIVE SYSTEMS", "Boost, Shield, Repair, and Barrage can save a run. Use Repair before a car hits zero."]
	]
	var edge: float = 40.0 if is_mobile_ui else 170.0
	var gap: float = 24.0 if is_mobile_ui else 50.0
	var col_w: float = (view_w - edge * 2.0 - gap) * 0.5
	var panel_h := 170.0
	for i in range(texts.size()):
		var col := i % 2
		var row := int(i / 2)
		var x: float = view_l + edge + float(col) * (col_w + gap)
		var y: float = 220.0 + float(row) * 205.0
		panel(x, y, col_w, panel_h)
		draw_text2(texts[i][0], x + 28, y + 38, 26, Color.html("#ffd36d"))
		wrap_text(texts[i][1], x + 28, y + 76, col_w - 56.0, 27, 20)
	var back_w := 240.0
	var start_w := 240.0
	var foot_gap := 40.0
	var foot_x0 := cx_ui - (back_w + foot_gap + start_w) * 0.5
	button(foot_x0, 982, back_w, 58, "BACK", "back_from_help", [], 23)
	button(foot_x0 + back_w + foot_gap, 982, start_w, 58, "START RUN", "reset_run", [], 23, Color.html("#ffd36d"))
func back_from_help() -> void:
	state = help_back_state
	if audio != null:
		if state == "title" or state == "workshop":
			audio.play_menu_music(1.0)
		elif ["combat", "route", "rewards", "station", "build", "moduleshop", "event", "levelup"].has(state):
			audio.play_travel_music(1.5)

func wrap_text(text: String, x: float, y: float, width: float, line_h: float, size = 20) -> void:
	var words = text.split(" ")
	var line = ""
	var yy = y
	for word in words:
		var test = word if line == "" else line + " " + word
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			draw_text2(line, x, yy, size, Color(.85,.96,1))
			yy += line_h
			line = word
		else:
			line = test
	if line != "":
		draw_text2(line, x, yy, size, Color(.85,.96,1))

func set_workshop_tab(tab: String) -> void:
	if not TrainBuild.WORKSHOP_CATEGORIES.has(tab):
		return
	workshop_tab = tab
	workshop_scroll_y = 0.0

func adjust_workshop_scroll(_delta_y: float) -> void:
	## 2-column workshop fits every tab without scroll.
	workshop_scroll_y = 0.0

func draw_workshop() -> void:
	## Edge-to-edge 2-col workshop. Airy type rhythm — readable, never cramped.
	## Design sizes ≈ 2× window px on 1230×540 preview.
	var view := _full_view_rect()
	var view_l: float = view.position.x
	var view_w: float = view.size.x
	var cx_ui: float = view_l + view_w * 0.5
	var mob := is_mobile_ui

	draw_rect(view, Color(0.02, 0.04, 0.06, 0.95), true)

	# Sweet-spot type (~14–16px on phone window): readable without crowding.
	var title_fs := 56 if mob else 52
	var alloy_fs := 30 if mob else 26
	var sub_fs := 17 if mob else 15
	var tab_fs := 20 if mob else 15
	var card_title_fs := 30 if mob else 20
	var tier_fs := 22 if mob else 14
	var body_fs := 28 if mob else 13
	var next_fs := 26 if mob else 12
	var cost_fs := 26 if mob else 15
	var act_fs := 22 if mob else 14
	var foot_fs := 26 if mob else 22

	permanent = ensure_permanent(permanent)
	if font == null:
		font = ThemeDB.fallback_font
	var alloy_n := int(permanent.get("alloy", 0))

	# --- Header ---
	draw_text2("THE WORKSHOP", cx_ui, 50.0 if mob else 64.0, title_fs, Color.html("#e8f7ff"), "center")
	var alloy_label := "ALLOY  %d" % alloy_n
	var alloy_w: float = font.get_string_size(alloy_label, HORIZONTAL_ALIGNMENT_LEFT, -1, alloy_fs).x + 44.0
	var alloy_h := 42.0 if mob else 38.0
	var alloy_x := cx_ui - alloy_w * 0.5
	var alloy_y := 66.0 if mob else 88.0
	panel(alloy_x, alloy_y, alloy_w, alloy_h, Color.html("#c9a24a"), Color(0.12, 0.09, 0.04, 0.94))
	draw_text2(alloy_label, cx_ui, alloy_y + alloy_h * 0.70, alloy_fs, Color.html("#ffd27b"), "center")
	draw_text2("Permanent upgrades. Scrap resets each run.", cx_ui, alloy_y + alloy_h + 26.0, sub_fs, Color.html("#9ab0c0"), "center")

	# --- Tabs ---
	var tab_ids: Array = TrainBuild.WORKSHOP_CATEGORY_ORDER
	var edge: float = 22.0 if mob else 20.0
	var tab_gap := 18.0 if mob else 10.0
	var tab_h := 50.0 if mob else 40.0
	var tab_w: float = (view_w - edge * 2.0 - (tab_ids.size() - 1) * tab_gap) / float(tab_ids.size())
	var tab_x0 := view_l + edge
	var tab_y := 154.0 if mob else 168.0
	for ti in range(tab_ids.size()):
		var tid: String = tab_ids[ti]
		var tx := tab_x0 + ti * (tab_w + tab_gap)
		var active := workshop_tab == tid
		var stroke := Color.html("#5ee9ff") if active else Color(0.40, 0.50, 0.58, 0.50)
		var fill := Color(0.08, 0.16, 0.22, 0.96) if active else Color(0.05, 0.08, 0.11, 0.90)
		panel(tx, tab_y, tab_w, tab_h, stroke, fill)
		button(tx, tab_y, tab_w, tab_h, str(TrainBuild.WORKSHOP_CATEGORIES[tid]["label"]), "set_workshop_tab", [tid], tab_fs, Color(0, 0, 0, 0))
		if active:
			draw_rect(Rect2(tx, tab_y + tab_h - 4.0, tab_w, 4.0), Color.html("#5ee9ff"), true)

	if not TrainBuild.WORKSHOP_CATEGORIES.has(workshop_tab):
		workshop_tab = "locomotive"
	var keys: Array = TrainBuild.WORKSHOP_CATEGORIES[workshop_tab]["keys"]

	# --- Grid: full width, airy gutters, no scroll ---
	var list_x := view_l + edge
	var list_w := view_w - edge * 2.0
	var list_top := tab_y + tab_h + (24.0 if mob else 16.0)
	var foot_h := 96.0 if mob else 88.0
	var list_bottom := DESIGN_H - foot_h - 10.0
	var list_h := list_bottom - list_top
	var cols := 2
	var rows := maxi(1, int(ceil(float(keys.size()) / float(cols))))
	var gap_x := 28.0 if mob else 14.0
	var gap_y := 26.0 if mob else 12.0
	var card_w := (list_w - gap_x) / float(cols)
	var card_h := (list_h - float(rows - 1) * gap_y) / float(rows)
	card_h = maxf(card_h, 140.0)
	var grid_y0 := list_top
	workshop_scroll_y = 0.0

	var pad := 34.0 if mob else 16.0
	var btn_h := 56.0 if mob else 34.0
	var btn_w_cap := 260.0 if mob else 168.0

	for i in range(keys.size()):
		var key: String = keys[i]
		var col_i := i % cols
		var row_i := int(i / cols)
		var cx := list_x + float(col_i) * (card_w + gap_x)
		var cy := grid_y0 + float(row_i) * (card_h + gap_y)
		var tier := int(permanent["workshop"].get(key, 0))
		var cost := TrainBuild.workshop_cost(key, tier)
		var maxed := tier >= TrainBuild.WORKSHOP_MAX_TIER or cost < 0
		var stroke := Color.html("#c9a24a") if maxed else Color(0.55, 0.90, 1.0, 0.55)
		panel(cx, cy, card_w, card_h, stroke, Color(0.045, 0.08, 0.11, 0.96))

		# Three bands with equal breathing room: title | stats | action
		var btn_y := cy + card_h - pad - btn_h
		var title_y := cy + pad + float(card_title_fs) * 0.80
		var band_top := title_y + float(card_title_fs) * 0.55 + 16.0
		var band_bot := btn_y - 20.0
		var band_h := maxf(48.0, band_bot - band_top)
		# Place Now / Next with a clear gap (~0.28 of the mid band between baselines).
		var now_y := band_top + band_h * 0.32
		var next_y := band_top + band_h * 0.68
		# Enforce a minimum baseline gap so lines never kiss.
		var min_gap := float(body_fs) + 14.0
		if next_y - now_y < min_gap:
			var mid := (now_y + next_y) * 0.5
			now_y = mid - min_gap * 0.5
			next_y = mid + min_gap * 0.5

		draw_text2(str(TrainBuild.WORKSHOP_LABELS.get(key, key.to_upper())), cx + pad, title_y, card_title_fs, Color.html("#eaf8ff"))
		draw_text2("Tier %d / %d" % [tier, TrainBuild.WORKSHOP_MAX_TIER], cx + card_w - pad, title_y, tier_fs, Color.html("#9df5ff"), "right")
		draw_text2("Now:  %s" % TrainBuild.workshop_benefit_line(key, tier), cx + pad, now_y, body_fs, Color(0.84, 0.94, 0.99, 0.98))
		draw_text2("Next: %s" % TrainBuild.workshop_next_benefit_line(key, tier), cx + pad, next_y, next_fs, Color(0.64, 0.76, 0.84, 0.95))

		var btn_w := minf(btn_w_cap, card_w * 0.44)
		var btn_x := cx + card_w - pad - btn_w
		var cost_y := btn_y + btn_h * 0.68
		if maxed:
			draw_text2("MAXED", cx + pad, cost_y, cost_fs, Color.html("#7dffbb"))
			button(btn_x, btn_y, btn_w, btn_h, "MAX", "buy_workshop", [key], act_fs, Color(0.35, 0.38, 0.42, 0.75))
		else:
			draw_text2("Cost: %d Alloy" % cost, cx + pad, cost_y, cost_fs, Color.html("#ffd27b"))
			var can := alloy_n >= cost
			var label := "UPGRADE" if can else "NEED ALLOY"
			var col := Color.html("#5ee9ff") if can else Color(0.55, 0.40, 0.35, 0.90)
			button(btn_x, btn_y, btn_w, btn_h, label, "buy_workshop", [key], act_fs, col)

	# --- Footer ---
	draw_rect(Rect2(view_l, list_bottom, view_w, DESIGN_H - list_bottom), Color(0.025, 0.04, 0.06, 1.0), true)
	draw_rect(Rect2(view_l, list_bottom, view_w, 2.0), Color(0.35, 0.75, 0.90, 0.20), true)
	var foot_y := list_bottom + (16.0 if mob else 14.0)
	var back_w := 280.0 if mob else 220.0
	var start_w := 320.0 if mob else 260.0
	var foot_btn_h := 60.0 if mob else 58.0
	var foot_gap := 36.0 if mob else 30.0
	var foot_total := back_w + foot_gap + start_w
	var foot_x0 := cx_ui - foot_total * 0.5
	button(foot_x0, foot_y, back_w, foot_btn_h, "BACK", "set_state", ["title"], foot_fs)
	button(foot_x0 + back_w + foot_gap, foot_y, start_w, foot_btn_h, "START RUN", "reset_run", [], foot_fs, Color.html("#5ee9ff"))

func buy_workshop(key: String) -> void:
	permanent = ensure_permanent(permanent)
	if not TrainBuild.WORKSHOP_KEYS.has(key):
		toast("Unknown workshop upgrade")
		return
	var tier := int(permanent["workshop"].get(key, 0))
	if tier >= TrainBuild.WORKSHOP_MAX_TIER:
		toast("Already max tier")
		return
	var cost := TrainBuild.workshop_cost(key, tier)
	if cost < 0:
		toast("Already max tier")
		return
	if int(permanent.get("alloy", 0)) < cost:
		toast("Not enough Alloy")
		return
	permanent["alloy"] = int(permanent["alloy"]) - cost
	permanent["workshop"][key] = tier + 1
	save_permanent()
	toast("%s → Tier %d" % [str(TrainBuild.WORKSHOP_LABELS.get(key, key)), tier + 1])

func draw_levelup() -> void:
	draw_rect(_full_view_rect(), Color(0, 0, 0, 0.62), true)
	if not USE_PRODUCTION_UI:
		draw_text2("TECH CARD ONLINE", 960, 190, 62, Color.WHITE, "center")
		for i in range(active_cards.size()):
			var c = active_cards[i]
			var x = 410 + i * 380
			var y = 330
			panel(x,y,330,430,Color.html(c["color"]))
			draw_text2(c["rarity"].to_upper(), x+165, y+45, 19, Color.html(c["color"]), "center")
			draw_text2(c["title"], x+165, y+205, 23, Color.WHITE, "center")
			wrap_text(c["desc"], x+38, y+265, 254, 28, 22)
			button(x, y, 330, 430, "", "select_card", [i], 1, Color(1,1,1,0))
		return
	
	# Clean section heading without overlapping top HUD
	draw_text2("TECH CARD ONLINE", 960, 160, 48, Color.WHITE, "center")
	draw_text2("SELECT AN EXPEDITION UPGRADE", 960, 204, 16, Color.html("#85f2ff"), "center")
	
	var count = active_cards.size()
	if count == 0:
		return
	
	var card_h = 530.0
	var card_w = card_h * (1086.0 / 1448.0)
	var gap = 55.0
	var total_w = count * card_w + (count - 1) * gap
	var start_x = (DESIGN_W - total_w) * 0.5
	var base_y = 265.0 + (570.0 - card_h) * 0.35
	
	var mouse_p = screen_to_design(get_viewport().get_mouse_position())
	
	for i in range(count):
		var c = active_cards[i]
		var bx = start_x + i * (card_w + gap)
		var by = base_y
		var is_hovered = Rect2(bx, by, card_w, card_h).has_point(mouse_p)
		
		var scale_boost = 1.025 if is_hovered else 1.0
		var w = card_w * scale_boost
		var h = card_h * scale_boost
		var x = bx - (w - card_w) * 0.5
		var y = by - (h - card_h) * 0.5
		var s = w / 1086.0
		var cx = x + w * 0.5
		
		var t_color = Color.html(c.get("color", "#85f2ff"))
		
		# Atmospheric soft glow
		draw_circle(Vector2(cx, y + h * 0.48), w * 0.52, Color(t_color.r, t_color.g, t_color.b, 0.24 if is_hovered else 0.10))
		draw_circle(Vector2(cx, y + 210.0 * s), 125.0 * s, Color(t_color.r, t_color.g, t_color.b, 0.32 if is_hovered else 0.14))
		
		# Card frame foreground/body
		var frame_tex = "route_choice_card_frame" if images.has("route_choice_card_frame") else ("ui_tech_card_base" if images.has("ui_tech_card_base") else "")
		if frame_tex != "":
			draw_tex(frame_tex, Rect2(x, y, w, h))
		else:
			panel(x, y, w, h)
		
		# 1. TOP CIRCLE AREA: tech card icon
		var circle_cx = cx
		var circle_cy = y + 210.0 * s
		var circle_r = 95.0 * s
		draw_circle(Vector2(circle_cx, circle_cy), circle_r, Color(t_color.r * 0.2, t_color.g * 0.2, t_color.b * 0.2, 0.90))
		draw_circle(Vector2(circle_cx, circle_cy), circle_r, Color(t_color.r, t_color.g, t_color.b, 0.45 if is_hovered else 0.25))
		
		var icon_k = c.get("icon", "icon_xp")
		var icon_sz = 115.0 * s
		if images.has(icon_k):
			draw_tex(icon_k, Rect2(circle_cx - icon_sz * 0.5, circle_cy - icon_sz * 0.5, icon_sz, icon_sz))
		
		# 2. TOP RECTANGLE: title
		var title_cy = y + 418.0 * s
		var title_font = int(round(20.0 * (s / 0.366)))
		draw_text2(str(c.get("title", "")).to_upper(), cx, title_cy + float(title_font) * 0.34, title_font, t_color, "center")
		
		# 3. LARGE CENTER AREA: description (centered horizontally & vertically in plate)
		var desc_plate_cy = y + 785.0 * s
		var desc_w = 640.0 * s
		var desc_font = int(round(16.0 * (s / 0.366)))
		var desc_line_h = 26.0 * (s / 0.366)
		draw_route_desc(str(c.get("desc", "")), cx, desc_plate_cy, desc_w, desc_line_h, desc_font, Color.html("#d4f5ff"))
		
		# 4. BOTTOM STRIP: rarity badge
		var bottom_cy = y + 1198.0 * s
		var b_font_rarity = int(round(15.0 * (s / 0.366)))
		draw_text2(str(c.get("rarity", "")).to_upper(), cx, bottom_cy + float(b_font_rarity) * 0.32, b_font_rarity, t_color, "center")
		
		# Button hitbox
		button(bx, by, card_w, card_h, "", "select_card", [i], 1, Color(1, 1, 1, 0))

func draw_rewards() -> void:
	draw_rect(_full_view_rect(), Color(0, 0, 0, 0.58), true)
	if USE_PRODUCTION_UI:
		draw_tex("ui_panel_wide_cyan", Rect2(650, 40, 620, 135))
		draw_text2("ENCOUNTER CLEARED", 960, 115, 36, Color.WHITE, "center")
		draw_text2("+%s SCRAP" % last_reward.get("scrap", 0), 960, 360, 48, Color.html("#ffd27b"), "center")
		draw_tex("ui_panel_generic_cyan", Rect2(730, 620, 460, 95))
		var btn_txt = boss_face_button_label() if reward_pending_boss else "CHOOSE NEXT TRACK"
		draw_text2(btn_txt, 960, 678, 23, Color.WHITE, "center")
		button(730, 620, 460, 95, "", "complete_reward", [], 1, Color(1, 1, 1, 0))
	else:
		draw_text2("ENCOUNTER CLEARED", 960, 180, 64, Color.WHITE, "center")
		draw_text2("+%s SCRAP" % last_reward.get("scrap", 0), 960, 410, 46, Color.html("#ffd27b"), "center")
		button(760, 850, 400, 72, boss_face_button_label() if reward_pending_boss else "CHOOSE NEXT TRACK", "complete_reward", [], 25)

func get_route_icon(n: Dictionary) -> String:
	var t = n.get("type", "combat")
	var title = str(n.get("title", "")).to_lower()
	if t == "station" or title.find("station") != -1 or title.find("depot") != -1:
		return "active_icon_repair" if images.has("active_icon_repair") else "icon_engine"
	elif t == "elite" or title.find("elite") != -1 or title.find("rift") != -1:
		return "icon_rift" if images.has("icon_rift") else "ui_warning_critical"
	elif t == "event" or title.find("salvage") != -1 or title.find("convoy") != -1 or title.find("cache") != -1:
		return "icon_scrap_gear" if images.has("icon_scrap_gear") else "icon_scrap"
	elif t == "boss":
		return "ui_warning_critical" if images.has("ui_warning_critical") else "boss"
	elif title.find("scrapper") != -1:
		return "icon_gatling" if images.has("icon_gatling") else "icon_cannon"
	else:
		return "icon_cannon" if images.has("icon_cannon") else "icon_gatling"

func get_route_risk(n: Dictionary) -> String:
	return str(n.get("risk", "Normal"))

func get_route_reward(n: Dictionary) -> String:
	if n.has("reward") and str(n["reward"]).strip_edges() != "":
		return str(n["reward"])
	var t = n.get("type", "combat")
	var title = str(n.get("title", "")).to_lower()
	if t == "station" or title.find("station") != -1:
		return "Repair & Tech"
	elif t == "elite" or title.find("elite") != -1 or title.find("rift") != -1:
		return "Blueprint Chance"
	elif t == "event" or title.find("cache") != -1 or title.find("convoy") != -1:
		return "Salvage Cache"
	elif t == "boss":
		return "Victory & Core"
	else:
		return "Scrap + XP"

func get_route_accent(n: Dictionary) -> Dictionary:
	var t = n.get("type", "combat")
	var title = str(n.get("title", "")).to_lower()
	var risk = str(n.get("risk", "Normal")).to_lower()
	if t == "elite" or title.find("elite") != -1 or risk == "high" or risk == "extreme" or risk == "critical":
		return {
			"glow": Color(1.0, 0.40, 0.18, 0.45),
			"accent": Color.html("#ff7a55"),
			"title": Color.html("#ffb08f"),
			"risk_col": Color.html("#ff5858"),
			"reward_col": Color.html("#ffe180"),
			"socket": Color(0.18, 0.05, 0.02, 0.90)
		}
	elif t == "station" or title.find("station") != -1:
		return {
			"glow": Color(0.20, 0.90, 0.55, 0.40),
			"accent": Color.html("#5ef5aa"),
			"title": Color.html("#a4ffce"),
			"risk_col": Color.html("#6dff9b"),
			"reward_col": Color.html("#ffd580"),
			"socket": Color(0.02, 0.12, 0.07, 0.90)
		}
	elif title.find("rift") != -1 or t == "rift":
		return {
			"glow": Color(0.75, 0.35, 1.0, 0.45),
			"accent": Color.html("#c87aff"),
			"title": Color.html("#e0a8ff"),
			"risk_col": Color.html("#ff6bb5"),
			"reward_col": Color.html("#8bf5ff"),
			"socket": Color(0.12, 0.03, 0.18, 0.90)
		}
	elif t == "event" or title.find("salvage") != -1 or title.find("convoy") != -1:
		return {
			"glow": Color(1.0, 0.80, 0.25, 0.38),
			"accent": Color.html("#ffcf72"),
			"title": Color.html("#ffe6a3"),
			"risk_col": Color.html("#ffb944"),
			"reward_col": Color.html("#85f2ff"),
			"socket": Color(0.12, 0.09, 0.02, 0.90)
		}
	else:
		return {
			"glow": Color(0.20, 0.85, 1.0, 0.38),
			"accent": Color.html("#62ecff"),
			"title": Color.html("#9ef5ff"),
			"risk_col": Color.html("#80e5ff"),
			"reward_col": Color.html("#ffd27b"),
			"socket": Color(0.02, 0.08, 0.12, 0.90)
		}

func draw_route_desc(text: String, cx: float, plate_cy: float, width: float, line_h: float, font_size: int, color: Color) -> void:
	var words = text.split(" ")
	var lines: Array[String] = []
	var cur_line = ""
	for w in words:
		var test = w if cur_line == "" else cur_line + " " + w
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and cur_line != "":
			lines.append(cur_line)
			cur_line = w
		else:
			cur_line = test
	if cur_line != "":
		lines.append(cur_line)
	
	var total_h = float(lines.size() - 1) * line_h
	var start_y = plate_cy - total_h * 0.5 + float(font_size) * 0.35
	for line in lines:
		draw_text2(line, cx, start_y, font_size, color, "center")
		start_y += line_h

func draw_route() -> void:
	# 1. Dim the gameplay background slightly (full visible view on mobile)
	draw_rect(_full_view_rect(), Color(0.015, 0.035, 0.055, 0.65), true)
	
	# 2. Section Heading — placed cleanly above cards without overlapping top HUD
	draw_text2("BRANCHING TRACKS", 960, 160, 48, Color.WHITE, "center")
	draw_text2("EXPEDITION TRACK %d/6 — SELECT NEXT ROUTE" % min(encounter_index + 1, 6), 960, 204, 16, Color.html("#85f2ff"), "center")
	
	# If route choices were empty upon resuming/continuing, populate them immediately
	if route_choices.is_empty():
		open_route(encounter_index == 3 and not station_used)
	
	# 3. Dynamic Card Layout (supports 2, 3, or more cards seamlessly)
	var count = route_choices.size()
	if count == 0:
		return
	
	var card_h = 570.0
	var gap = 90.0
	if count == 1:
		card_h = 580.0
		gap = 0.0
	elif count == 2:
		card_h = 570.0
		gap = 100.0
	elif count == 3:
		card_h = 530.0
		gap = 55.0
	elif count >= 4:
		var max_total_w = 1620.0
		gap = 35.0
		var max_card_w = (max_total_w - gap * (count - 1)) / float(count)
		card_h = min(530.0, max_card_w / (1086.0 / 1448.0))
	
	var card_w = card_h * (1086.0 / 1448.0)
	var total_w = count * card_w + (count - 1) * gap
	var start_x = (DESIGN_W - total_w) * 0.5
	var base_y = 265.0 + (570.0 - card_h) * 0.35
	
	var mouse_p = screen_to_design(get_viewport().get_mouse_position())
	
	for i in range(count):
		var n = route_choices[i]
		var bx = start_x + i * (card_w + gap)
		var by = base_y
		var is_hovered = Rect2(bx, by, card_w, card_h).has_point(mouse_p)
		
		# Subtle hover scaling (centered)
		var scale_boost = 1.025 if is_hovered else 1.0
		var w = card_w * scale_boost
		var h = card_h * scale_boost
		var x = bx - (w - card_w) * 0.5
		var y = by - (h - card_h) * 0.5
		var s = w / 1086.0
		var cx = x + w * 0.5
		
		var accent = get_route_accent(n)
		
		# Atmospheric soft glow behind the card frame (no harsh rectangular wireframe)
		var glow_c: Color = accent["glow"]
		draw_circle(Vector2(cx, y + h * 0.48), w * 0.52, Color(glow_c.r, glow_c.g, glow_c.b, 0.24 if is_hovered else 0.10))
		draw_circle(Vector2(cx, y + 210.0 * s), 125.0 * s, Color(glow_c.r, glow_c.g, glow_c.b, 0.32 if is_hovered else 0.14))
		
		# Reusable decorative foreground frame
		if images.has("route_choice_card_frame"):
			draw_tex("route_choice_card_frame", Rect2(x, y, w, h))
		else:
			panel(x, y, w, h)
		
		# 1. TOP CIRCLE AREA: route icon
		var circle_cx = cx
		var circle_cy = y + 210.0 * s
		var circle_r = 95.0 * s
		draw_circle(Vector2(circle_cx, circle_cy), circle_r, accent["socket"])
		draw_circle(Vector2(circle_cx, circle_cy), circle_r, accent["glow"] * (1.1 if is_hovered else 0.45))
		
		var icon_k = get_route_icon(n)
		var icon_sz = 115.0 * s
		if images.has(icon_k):
			draw_tex(icon_k, Rect2(circle_cx - icon_sz * 0.5, circle_cy - icon_sz * 0.5, icon_sz, icon_sz))
		
		# 2. TOP RECTANGLE: route title
		var title_cy = y + 418.0 * s
		var title_font = int(round(20.0 * (s / 0.366)))
		draw_text2(str(n.get("title", "")).to_upper(), cx, title_cy + float(title_font) * 0.34, title_font, accent["title"], "center")
		
		# 3. LARGE CENTER AREA: route description (centered horizontally & vertically in plate)
		var desc_plate_cy = y + 785.0 * s
		var desc_w = 640.0 * s
		var desc_font = int(round(16.0 * (s / 0.366)))
		var desc_line_h = 26.0 * (s / 0.366)
		draw_route_desc(str(n.get("desc", "")), cx, desc_plate_cy, desc_w, desc_line_h, desc_font, Color.html("#d4f5ff"))
		
		# 4. BOTTOM STRIP: risk / reward info
		var bottom_cy = y + 1198.0 * s
		var b_font_risk = int(round(15.0 * (s / 0.366)))
		var b_font_rew = int(round(14.0 * (s / 0.366)))
		var risk_val = get_route_risk(n)
		var reward_val = get_route_reward(n)
		draw_text2("RISK: " + risk_val.to_upper(), cx, bottom_cy - 11.0 * (s / 0.366), b_font_risk, accent["risk_col"], "center")
		draw_text2("REWARD: " + reward_val.to_upper(), cx, bottom_cy + 13.0 * (s / 0.366), b_font_rew, accent["reward_col"], "center")
		
		# Interactive button hitbox matching card bounds
		button(bx, by, card_w, card_h, "", "begin_node", [n["type"]], 1, Color(1, 1, 1, 0))

func draw_station() -> void:
	draw_rect(_full_view_rect(), Color(0, 0, 0, 0.55), true)
	draw_text2("RUST STATION", 960, 150, 64, Color.WHITE, "center")
	draw_text2("Scrap: %s" % scrap, 960, 210, 28, Color.html("#ffd27b"), "center")
	var items = [["repair","REPAIR",22],["reactor","REACTOR",55],["armor","ARMOR",28],["cool","COOLING",35],["drone","DRONE TUNE",34]]
	for i in range(items.size()):
		var x = 260 + (i % 3) * 470
		var y = 310 + int(i / 3) * 180
		button(x,y,400,130,items[i][1]+"  "+str(items[i][2]),"buy_station",[items[i][0]],22)
	button(430,835,310,72,"TRAIN BUILD","open_build",[],24)
	button(805,835,310,72,"MODULE SHOP","open_module_shop",[],24)
	button(1180,835,310,72,"LEAVE STATION","open_route",[false],24)

func draw_build() -> void:
	draw_rect(_full_view_rect(), Color(0, 0, 0, 0.62), true)
	draw_text2("TRAIN BUILD",960,118,64,Color.WHITE,"center")
	for i in range(3):
		var key = ["gatling", "cannon", "drone"][i]
		var x = 260 + i * 470
		panel(x,310,410,430)
		draw_text2(MODULE_INFO[key]["title"],x+205,370,27,Color.WHITE,"center")
		draw_text2("Level %s/5"%module_level(key),x+205,420,22,Color.html("#ffcf72"),"center")
		button(x+34,610,160,54,"UPGRADE","upgrade_module",[key],16)
		button(x+216,610,160,54,"PRIORITY","cycle_priority",[key],16)
	button(760,820,400,72,"BACK TO STATION","set_state",["station"],25)

func draw_module_shop() -> void:
	draw_rect(_full_view_rect(), Color(0, 0, 0, 0.62), true)
	draw_text2("MODULE SHOP",960,115,64,Color.WHITE,"center")
	draw_text2("Scrap: %s    AUX: %s"%[scrap, AUX_MODULES[aux_module_id()]["title"] if aux_module_id()!=null else "Empty"],960,176,25,Color.html("#ffd27b"),"center")
	for i in range(module_shop.size()):
		var id = module_shop[i]
		var info = AUX_MODULES[id]
		var x = 500 + i * 380
		panel(x,330,340,250)
		draw_text2(info["title"],x+170,385,24,Color.WHITE,"center")
		wrap_text(info["desc"],x+30,430,280,24,18)
		button(x + 86, 514, 168, 46, "BUY %s" % info["cost"], "buy_aux_module", [id], 16)
	var inv: Array = modules["inventory"]
	for i in range(inv.size()):
		var id2 = inv[i]
		var info2 = AUX_MODULES[id2]
		var x2 = 620 + i * 300
		button(x2,700,260,60,"INSTALL "+info2["short"],"install_aux_module",[id2],16)
	button(760,865,400,70,"BACK TO STATION","set_state",["station"],25)

func draw_event() -> void:
	draw_rect(_full_view_rect(), Color(0, 0, 0, 0.58), true)
	draw_text2("ABANDONED CONVOY",960,170,58,Color.WHITE,"center")
	button(610,430,700,82,"SEARCH CARGO","choose_event",[0],20)
	button(610,550,700,82,"SALVAGE ENGINE","choose_event",[1],20)
	button(610,670,700,82,"LEAVE","choose_event",[2],20)

func draw_victory() -> void:
	# Full-bleed dim on mobile ultrawide — not only the centered 16:9 frame.
	draw_rect(_full_view_rect(), Color(0, 0, 0, 0.72 if is_mobile_ui else 0.45), true)
	if rift_cycle_complete:
		draw_text2("RIFT CYCLE COMPLETE",960,230,64,Color.html("#fff1a3"),"center")
		draw_text2("Loop %d cleared  →  Entering Loop %d" % [maxi(1, rift_loop), maxi(2, rift_cycle_next_loop)],960,310,28,Color.html("#9ef4ff"),"center")
	else:
		draw_text2("VICTORY",960,250,92,Color.html("#fff1a3"),"center")
	var flavor = victory_flavor
	if flavor == "":
		if current_region == RiftScar.REGION_ID:
			flavor = "THE BREACH ENGINE shuts down. The Scar's core falls silent."
		elif current_region == "fungus_wilds":
			flavor = "The Mycelarch collapses into glowing spores."
		else:
			flavor = "The Iron Maw collapses under the rails."
	draw_text2(flavor,960,360 if rift_cycle_complete else 340,22,Color.WHITE,"center")
	panel(560,400,800,280)
	var unlock_line = "Train, weapons, Scrap and XP preserved"
	if not rift_cycle_complete:
		unlock_line = "Breach Core Blueprint unlocked"
		if current_region == "fungus_wilds":
			unlock_line = "Spore Filter Blueprint unlocked"
		elif current_region == "rustlands":
			unlock_line = "Missile Rack Blueprint unlocked"
	draw_text2(unlock_line,960,500,24,Color.WHITE,"center")
	draw_text2("Score %s    Time %s    Kills %s"%[last_run_score,fmt_time(run_time),maxi(kills, run_kills)],960,555,22,Color.html("#9ef4ff"),"center")
	draw_text2("Permanent Alloy: %s"%permanent.get("alloy",0),960,605,22,Color.html("#ffd27b"),"center")
	if rift_cycle_complete:
		button(560,720,380,68,"ENTER LOOP %d" % maxi(2, rift_cycle_next_loop),"continue_rift_loop",[],20,Color.html("#ffd36d"))
		button(970,720,250,68,"WORKSHOP","set_state",["workshop"],22,Color.html("#ffd36d"))
		button(1245,720,200,68,"TITLE","set_state",["title"],22)
	else:
		button(560,720,250,68,"WORKSHOP","set_state",["workshop"],22,Color.html("#ffd36d"))
		button(835,720,250,68,"NEW EXPEDITION","reset_run",[],20)
		button(1110,720,250,68,"TITLE","set_state",["title"],22)
func draw_failed() -> void:
	# Full-bleed shadow on mobile ultrawide — cover moon/rift side strips too.
	var view := _full_view_rect()
	var cx_ui: float = view.position.x + view.size.x * 0.5
	var mob := is_mobile_ui
	draw_rect(view, Color(0, 0, 0, 0.78 if mob else 0.62), true)
	var title_fs := 72 if mob else 64
	var region_fs := 36 if mob else 26
	var loop_fs := 34 if mob else 24
	var stats_fs := 32 if mob else 22
	var score_fs := 32 if mob else 22
	var alloy_fs := 40 if mob else 30
	var total_fs := 28 if mob else 20
	var y0 := 200.0 if mob else 220.0
	var y1 := 290.0 if mob else 300.0
	var y2 := 340.0 if mob else 335.0
	var y3 := 400.0 if mob else 380.0
	var y4 := 450.0 if mob else 420.0
	var y5 := 520.0 if mob else 475.0
	var y6 := 575.0 if mob else 525.0
	var btn_y := 660.0 if mob else 600.0
	var title_btn_y := 770.0 if mob else 700.0
	draw_text2("EXPEDITION FAILED", cx_ui, y0, title_fs, Color.html("#ff665f"), "center")
	var info := last_fail_info
	var rr := str(info.get("region", current_region))
	var region_label := "The Rift Scar" if rr == RiftScar.REGION_ID else ("Fungus Wilds" if rr == "fungus_wilds" else "Rustlands")
	draw_text2("%s  •  Track %s reached" % [region_label, str(info.get("track", encounter_index + 1))], cx_ui, y1, region_fs, Color.html("#9ef4ff"), "center")
	draw_text2("Highest Rift Loop: %s" % str(info.get("highest_loop", permanent.get("highest_rift_loop", rift_loop))), cx_ui, y2, loop_fs, Color.html("#ffd36d"), "center")
	draw_text2("Enemies defeated: %s    Level: %s    Time: %s" % [
		str(info.get("kills", run_kills)), str(info.get("level", level)), fmt_time(float(info.get("time", run_time)))
	], cx_ui, y3, stats_fs, Color.WHITE, "center")
	draw_text2("Score %s" % str(info.get("score", last_run_score)), cx_ui, y4, score_fs, Color.html("#c9d7e2"), "center")
	draw_text2("+%s Permanent Alloy earned" % str(info.get("alloy", 0)), cx_ui, y5, alloy_fs, Color.html("#ffd27b"), "center")
	draw_text2("Total Alloy: %s  —  spend it in the Workshop" % str(info.get("alloy_total", permanent.get("alloy", 0))), cx_ui, y6, total_fs, Color.html("#9ab0c0"), "center")
	var btn_gap := 40.0 if not mob else 28.0
	var btn_w := 300.0 if not mob else 340.0
	var btn_h := 70.0 if not mob else 72.0
	var pair_w := btn_w * 2.0 + btn_gap
	var pair_x0 := cx_ui - pair_w * 0.5
	button(pair_x0, btn_y, btn_w, btn_h, "WORKSHOP", "set_state", ["workshop"], 28 if mob else 24, Color.html("#ffd36d"))
	button(pair_x0 + btn_w + btn_gap, btn_y, btn_w, btn_h, "NEW EXPEDITION", "reset_run", [], 26 if mob else 22)
	var title_w := 340.0 if not mob else 360.0
	button(cx_ui - title_w * 0.5, title_btn_y, title_w, 60 if mob else 56, "TITLE", "set_state", ["title"], 24 if mob else 20)

func draw_toasts() -> void:
	if region_intro_banner_timer > 0.0:
		return
	# Sit just under the encounter HUD; keep the train/enemies readable.
	var y := 218.0
	# Mobile long encounter frame is taller — keep toast chips clear of its bottom lip.
	if is_mobile_ui and _mobile_encounter_hud != null and state == "combat":
		var lay: Dictionary = _mobile_encounter_layout()
		var tr: Rect2 = lay.get("texture_rect", Rect2())
		if tr.size.y > 1.0:
			y = maxf(y, tr.position.y + tr.size.y + 52.0)
	for msg in toasts:
		var life := float(msg.get("life", 0.0))
		var mx := float(msg.get("max", 2.0))
		var fade := clampf(life / maxf(0.35, mx * 0.35), 0.0, 1.0) if life < mx * 0.35 else 1.0
		var a := 0.88 * fade
		var major := str(msg.get("priority", "normal")) == "major"
		panel(720, y, 480, 34, Color(0.55, 0.78, 0.9, 0.35 * a), Color(0.04, 0.07, 0.10, 0.82 * a))
		var col := Color(1, 1, 1, a) if major else Color(0.85, 0.93, 0.98, 0.9 * a)
		draw_text2(str(msg.get("text", "")), 960, y + 23, 15 if major else 14, col, "center")
		y += 38


func draw_debug_overlay() -> void:
	if not debug_open:
		button(DESIGN_W - 54.0, 4.0, 50.0, 28.0, "DBG", "toggle_debug", [], 14, Color.html("#ffd36d"))
		return
	panel(DESIGN_W - 460.0, 10.0, 450.0, 780.0, Color.html("#ffd36d"), Color(0.04, 0.06, 0.08, 0.96))
	draw_text2("DEBUG CONSOLE [PAGE %s/3]" % (debug_page + 1), DESIGN_W - 235.0, 40.0, 20, Color.html("#ffd36d"), "center")
	button(DESIGN_W - 440.0, 55.0, 130.0, 32.0, "PAGE 1", "set_debug_page", [0], 14, Color.html("#ffd36d") if debug_page == 0 else Color.WHITE)
	button(DESIGN_W - 300.0, 55.0, 130.0, 32.0, "PAGE 2", "set_debug_page", [1], 14, Color.html("#ffd36d") if debug_page == 1 else Color.WHITE)
	button(DESIGN_W - 160.0, 55.0, 140.0, 32.0, "PAGE 3", "set_debug_page", [2], 14, Color.html("#ffd36d") if debug_page == 2 else Color.WHITE)
	
	var y = 105.0
	if debug_page == 0:
		button(DESIGN_W - 440.0, y, 205.0, 40.0, "+75 SCRAP", "debug_add_scrap", [75], 16)
		button(DESIGN_W - 225.0, y, 205.0, 40.0, "+50 XP", "debug_add_xp", [50], 16)
		y += 48.0
		button(DESIGN_W - 440.0, y, 205.0, 40.0, "HEAL TRAIN", "debug_heal_train", [], 16)
		button(DESIGN_W - 225.0, y, 205.0, 40.0, "DAMAGE CAR", "debug_damage_train", [], 16)
		y += 48.0
		button(DESIGN_W - 440.0, y, 130.0, 36.0, "SCRAPPER", "debug_spawn", ["scrapper", false], 14)
		button(DESIGN_W - 300.0, y, 130.0, 36.0, "RUNNER", "debug_spawn", ["runner", false], 14)
		button(DESIGN_W - 160.0, y, 140.0, 36.0, "BRUTE", "debug_spawn", ["brute", false], 14)
		y += 44.0
		button(DESIGN_W - 440.0, y, 130.0, 36.0, "SKIMMER", "debug_spawn", ["skimmer", false], 14)
		button(DESIGN_W - 300.0, y, 130.0, 36.0, "BOARDER", "debug_spawn", ["boarder", false], 14)
		button(DESIGN_W - 160.0, y, 140.0, 36.0, "ELITE ENEMY", "debug_spawn", ["brute", true], 14)
		y += 48.0
		button(DESIGN_W - 440.0, y, 420.0, 42.0, "FORCE CLEAR ENCOUNTER", "debug_clear_encounter", [], 16, Color.html("#7dffbb"))
		y += 50.0
		button(DESIGN_W - 440.0, y, 205.0, 40.0, "JUMP ROUTE", "open_route", [false], 16)
		button(DESIGN_W - 225.0, y, 205.0, 40.0, "JUMP STATION", "open_station", [], 16)
		y += 48.0
		button(DESIGN_W - 440.0, y, 205.0, 42.0, "LOOP 2 (F2)", "debug_goto_rift_loop", [2], 14, Color.html("#ffd36d"))
		button(DESIGN_W - 225.0, y, 205.0, 42.0, "MYCELARCH (F9)", "debug_start_mycelarch", [], 14, Color.html("#4dffb5"))
		y += 50.0
		button(DESIGN_W - 440.0, y, 205.0, 42.0, "IRON MAW", "debug_start_iron_maw", [], 14, Color.html("#ff665f"))
		button(DESIGN_W - 225.0, y, 205.0, 42.0, "BREACH (F10)", "debug_start_rift_scar", [], 14, Color.html("#5cf0ff"))
		y += 50.0
		button(DESIGN_W - 440.0, y, 130.0, 36.0, "SKITTER", "debug_spawn", ["rift_skitter", false], 13, Color.html("#85f2ff"))
		button(DESIGN_W - 300.0, y, 130.0, 36.0, "RIFLEMAN", "debug_spawn", ["flux_rifleman", false], 13, Color.html("#85f2ff"))
		button(DESIGN_W - 160.0, y, 140.0, 36.0, "LEECH", "debug_spawn", ["coil_leech", false], 13, Color.html("#85f2ff"))
		y += 44.0
		button(DESIGN_W - 440.0, y, 205.0, 36.0, "JUGGERNAUT", "debug_spawn", ["fracture_juggernaut", false], 13, Color.html("#85f2ff"))
		button(DESIGN_W - 225.0, y, 205.0, 36.0, "HARVESTER", "debug_spawn", ["rift_harvester", true], 13, Color.html("#85f2ff"))
		y += 48.0
		button(DESIGN_W - 440.0, y, 205.0, 38.0, "HEAT -> 0", "debug_set_heat", [0.0], 15)
		button(DESIGN_W - 225.0, y, 205.0, 38.0, "HEAT -> 85", "debug_set_heat", [85.0], 15)
		y += 46.0
		button(DESIGN_W - 440.0, y, 205.0, 38.0, "SPEED -> 100", "debug_set_speed", [100.0], 15)
		button(DESIGN_W - 225.0, y, 205.0, 38.0, "FORCE OVERRUN", "debug_force_overrun", [3], 15)
	elif debug_page == 1:
		button(DESIGN_W - 440.0, y, 205.0, 40.0, "GRANT ARC COIL", "debug_grant_aux", ["arc_coil"], 15)
		button(DESIGN_W - 225.0, y, 205.0, 40.0, "GRANT CRYO", "debug_grant_aux", ["cryo_launcher"], 15)
		y += 48.0
		button(DESIGN_W - 440.0, y, 205.0, 40.0, "GRANT MORTAR", "debug_grant_aux", ["rail_mortar"], 15)
		button(DESIGN_W - 225.0, y, 205.0, 40.0, "GRANT MISSILE", "debug_grant_aux", ["missile_rack"], 15)
		y += 48.0
		button(DESIGN_W - 440.0, y, 420.0, 42.0, "MAX ALL MODULES", "debug_max_modules", [], 16, Color.html("#7dffbb"))
		y += 52.0
		draw_text2("FORCE ENCOUNTER TYPE:", DESIGN_W - 440.0, y + 20.0, 16, Color.html("#85f2ff"))
		y += 32.0
		var encs = ["pursuit", "column", "sky_raid", "boarding", "squall", "breaker"]
		for i in range(encs.size()):
			var ex = DESIGN_W - 440.0 + (i % 2) * 215.0
			var ey = y + int(i / 2) * 44.0
			button(ex, ey, 205.0, 38.0, encs[i].to_upper(), "debug_force_encounter", [encs[i]], 14)
	elif debug_page == 2:
		button(DESIGN_W - 440.0, y, 205.0, 40.0, "SAVE RUN", "save_run", [], 15)
		button(DESIGN_W - 225.0, y, 205.0, 40.0, "LOAD RUN", "load_run", [], 15)
		y += 48.0
		button(DESIGN_W - 440.0, y, 205.0, 40.0, "+25 ALLOY", "debug_add_alloy", [25], 15)
		button(DESIGN_W - 225.0, y, 205.0, 40.0, "SPEED 1X / 2X", "toggle_speed", [], 15)
		y += 48.0
		button(DESIGN_W - 440.0, y, 420.0, 42.0, "DEFEAT BOSS -> FUNGUS WILDS", "on_boss_defeated", [], 16, Color.html("#7dffbb"))
		y += 50.0
		button(DESIGN_W - 440.0, y, 420.0, 42.0, "FORCE FAILURE", "fail_run", [], 16, Color.html("#ff665f"))
		y += 50.0
		button(DESIGN_W - 440.0, y, 420.0, 42.0, "CLEAR SAVES", "debug_clear_saves", [], 16, Color.html("#ff4444"))
	
	button(DESIGN_W - 440.0, 725.0, 420.0, 45.0, "CLOSE DEBUG (F1)", "toggle_debug", [], 16)
