extends RefCounted
## Chapter 3 — THE RIFT SCAR: encounters, enemies, boss defs, stage helpers.

const REGION_ID := "rift_scar"
const REGION_LABEL := "THE RIFT SCAR"
const TRANSITION_DURATION := 16.0

const BOSS_BREACH_ENGINE := {
	"id": "breach_engine",
	"label": "THE BREACH ENGINE",
	"max_hp": 5200.0,
	"armor": 12.0,
	"speed": 28.0,
	"xp": 320.0,
	"scrap_min": 70,
	"scrap_max": 100
}

const ENEMY_DATA := {
	"rift_skitter": {
		"label": "Rift Skitter", "sprite": "rift_skitter",
		"max_hp": 42.0, "armor": 2.0, "speed": 148.0, "attack": 5.5, "range": 70.0, "cd": 0.78,
		"xp": 11.0, "scrap_min": 2, "scrap_max": 4, "cost": 2, "scale": 0.72, "jitter": 48.0,
		"rift": true
	},
	"flux_rifleman": {
		"label": "Flux Rifleman", "sprite": "flux_rifleman",
		"max_hp": 68.0, "armor": 3.0, "speed": 78.0, "attack": 7.5, "range": 340.0, "cd": 1.55,
		"xp": 16.0, "scrap_min": 3, "scrap_max": 5, "cost": 4, "scale": 0.84, "jitter": 40.0,
		"rift": true, "ranged": true, "aim_warn": 0.42
	},
	"coil_leech": {
		"label": "Coil Leech", "sprite": "coil_leech",
		"max_hp": 48.0, "armor": 1.0, "speed": 118.0, "attack": 3.2, "range": 55.0, "cd": 0.95,
		"xp": 14.0, "scrap_min": 2, "scrap_max": 4, "cost": 3, "scale": 0.68, "jitter": 50.0,
		"rift": true, "leech": true
	},
	"fracture_juggernaut": {
		"label": "Fracture Juggernaut", "sprite": "fracture_juggernaut",
		"max_hp": 260.0, "armor": 16.0, "speed": 38.0, "attack": 14.0, "range": 95.0, "cd": 1.85,
		"xp": 28.0, "scrap_min": 5, "scrap_max": 8, "cost": 6, "scale": 1.12, "jitter": 28.0,
		"rift": true, "heavy": true, "telegraph": 0.55
	},
	"rift_harvester": {
		"label": "Rift Harvester", "sprite": "rift_harvester",
		"max_hp": 420.0, "armor": 10.0, "speed": 52.0, "attack": 11.0, "range": 300.0, "cd": 1.35,
		"xp": 48.0, "scrap_min": 10, "scrap_max": 16, "cost": 8, "scale": 1.18, "jitter": 36.0,
		"rift": true, "elite_kind": true, "area_warn": 0.70
	}
}

const ENCOUNTERS := [
	{ "id": "scar_scouts", "title": "Fracture Scouts", "subtitle": "Skitters probe the convoy.", "min": 1,
		"weights": { "rift_skitter": 9, "flux_rifleman": 3 }, "budget": 14.0, "budget_node": 2.6,
		"goal": 50.0, "goal_node": 4.0, "spawn_min": 0.85, "spawn_max": 1.45, "reward": 16 },
	{ "id": "flux_line", "title": "Flux Firing Line", "subtitle": "Riflemen hold the shattered embankment.", "min": 2,
		"weights": { "rift_skitter": 5, "flux_rifleman": 7 }, "budget": 18.0, "budget_node": 3.0,
		"goal": 58.0, "goal_node": 4.0, "spawn_min": 0.90, "spawn_max": 1.55, "reward": 18 },
	{ "id": "coil_pressure", "title": "Coil Pressure", "subtitle": "Leeches hunt reactor heat.", "min": 3,
		"weights": { "rift_skitter": 4, "flux_rifleman": 4, "coil_leech": 6 }, "budget": 22.0, "budget_node": 3.4,
		"goal": 66.0, "goal_node": 5.0, "spawn_min": 0.82, "spawn_max": 1.40, "reward": 20, "heat_mul": 1.08 },
	{ "id": "jugger_column", "title": "Juggernaut Column", "subtitle": "Armored rift-fused walkers advance.", "min": 3,
		"weights": { "flux_rifleman": 3, "coil_leech": 3, "fracture_juggernaut": 5, "rift_skitter": 3 },
		"budget": 24.0, "budget_node": 3.6, "goal": 72.0, "goal_node": 5.0, "spawn_min": 0.95, "spawn_max": 1.60, "reward": 22 },
	{ "id": "scar_storm", "title": "Scar Storm", "subtitle": "Mixed rift warforms under electrical weather.", "min": 5,
		"weights": { "rift_skitter": 4, "flux_rifleman": 4, "coil_leech": 4, "fracture_juggernaut": 4 },
		"budget": 28.0, "budget_node": 4.0, "goal": 80.0, "goal_node": 5.0, "spawn_min": 0.75, "spawn_max": 1.30,
		"reward": 24, "heat_mul": 1.14 },
	{ "id": "heart_approach", "title": "Heart Approach", "subtitle": "The Breach Engine's outer defenses.", "min": 5,
		"weights": { "rift_skitter": 3, "flux_rifleman": 4, "coil_leech": 3, "fracture_juggernaut": 5, "rift_harvester": 2 },
		"budget": 32.0, "budget_node": 4.4, "goal": 88.0, "goal_node": 5.0, "spawn_min": 0.70, "spawn_max": 1.25, "reward": 28 }
]

static func stage_for_track(encounter_index: int, transitioning: bool = false) -> String:
	if transitioning:
		return "frontier"
	if encounter_index <= 1:
		return "frontier"
	if encounter_index <= 3:
		return "expansion"
	return "heart"

static func stage_keys(stage: String) -> Dictionary:
	# Same blend weights as Stage 1/2 — full-opacity plates, soft sparks only.
	match stage:
		"expansion":
			return { "sky": "r3_expansion_sky", "mid": "r3_expansion_mid", "fg": "r3_expansion_fg", "distant": "", "spark": 0.22, "mid_a": 1.0, "fg_a": 1.0, "sky_a": 1.0 }
		"heart":
			return { "sky": "r3_heart_sky", "mid": "r3_heart_mid", "fg": "r3_heart_fg", "distant": "r3_heart_distant", "spark": 0.55, "mid_a": 1.0, "fg_a": 1.0, "sky_a": 1.0, "dist_a": 0.92 }
		_:
			return { "sky": "r3_frontier_sky", "mid": "r3_frontier_mid", "fg": "r3_frontier_fg", "distant": "", "spark": 0.16, "mid_a": 1.0, "fg_a": 1.0, "sky_a": 1.0 }

static func merge_enemy_data(into: Dictionary) -> void:
	for k in ENEMY_DATA.keys():
		into[k] = ENEMY_DATA[k].duplicate(true)

static func is_rift_enemy(type_id: String) -> bool:
	return ENEMY_DATA.has(type_id)

static func boss_phase(hp_ratio: float) -> int:
	if hp_ratio > 0.66:
		return 1
	if hp_ratio > 0.33:
		return 2
	return 3
