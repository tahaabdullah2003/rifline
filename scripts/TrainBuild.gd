extends RefCounted
## Centralized train-building + hardcore economy data (Stage 03).
## GodotMain owns runtime state; all purchase/upgrade prices come from here.

const MAX_WAGONS: int = 3
const CAR_GAP: float = 12.0
const LOCO_LEFT_X: float = 1178.0
const MIN_LEFT_EDGE: float = 70.0

# --- Purchase prices (authoritative) ----------------------------------------
const WAGON_PRICES := {
	"weapon": 150
}

const CORE_WEAPON_PRICES := {
	"gatling": 50,
	"cannon": 450,
	"drone": 425
}

const AUX_WEAPON_PRICES := {
	"arc_coil": 330,
	"cryo_launcher": 310,
	"rail_mortar": 540,
	"missile_rack": 780
}

# Run-upgrade bases (~3.5–4× pre-hardcore). Cost = base * pow(level, UPGRADE_EXP).
const MODULE_UPGRADE_BASE := {
	"gatling": 75,
	"cannon": 90,
	"drone": 82
}

const AUX_UPGRADE_BASE := {
	"arc_coil": 72,
	"cryo_launcher": 68,
	"rail_mortar": 88,
	"missile_rack": 98
}

const UPGRADE_EXP: float = 1.42

# Live Armory train-system upgrades (Scrap).
const STATION_COSTS := {
	"repair": 48,
	"reactor": 125,
	"armor": 90,
	"cool": 100,
	"drone": 95
}

const REPAIR_AMOUNT: float = 70.0

# --- Starter gun (weak; Workshop can improve) --------------------------------
# Slightly above prior 6.5 so fresh runs are learnable; armor-pierce handles brutes.
const STARTER_DAMAGE: float = 7.8
const STARTER_COOLDOWN: float = 0.40
## Full playfield engage — loco must hit enemies behind purchased wagons.
const STARTER_RANGE: float = 2200.0

# --- Continuous expedition knobs --------------------------------------------
const TRACK_CLEAR_XP_BASE: float = 14.0
const TRACK_CLEAR_XP_PER_NODE: float = 2.5
const MID_RUN_DEPOT_SCRAP: int = 40
const MID_RUN_DEPOT_REPAIR: float = 55.0
const ELITE_ROUTE_CHANCE: float = 0.32
const SALVAGE_SPIKE_CHANCE: float = 0.10
const SALVAGE_SPIKE_SCRAP: int = 22

# --- Permanent Workshop -----------------------------------------------------
const WORKSHOP_MAX_TIER: int = 5
const WORKSHOP_KEYS := [
	"hull", "starter", "armor_pierce", "targeting",
	"reactor", "cooling", "reinforced", "impact", "field_eng",
	"salvage", "starter_scrap", "weapons_eng"
]
const WORKSHOP_CATEGORIES := {
	"locomotive": {
		"label": "LOCOMOTIVE",
		"keys": ["hull", "starter", "armor_pierce", "targeting"]
	},
	"defense": {
		"label": "DEFENSE",
		"keys": ["reactor", "cooling", "reinforced", "impact", "field_eng"]
	},
	"economy": {
		"label": "ECONOMY & WEAPONS",
		"keys": ["salvage", "starter_scrap", "weapons_eng"]
	}
}
const WORKSHOP_CATEGORY_ORDER := ["locomotive", "defense", "economy"]
const WORKSHOP_LABELS := {
	"hull": "LOCOMOTIVE HULL",
	"starter": "STARTER GUN",
	"armor_pierce": "ARMOR-PIERCING ROUNDS",
	"targeting": "TARGETING CALIBRATION",
	"reactor": "REACTOR CORE",
	"cooling": "HEAT MANAGEMENT",
	"reinforced": "REINFORCED CARRIAGES",
	"impact": "IMPACT RESISTANCE",
	"field_eng": "FIELD ENGINEERING",
	"salvage": "SALVAGE RIGS",
	"starter_scrap": "STARTER SCRAP RESERVE",
	"weapons_eng": "WEAPONS ENGINEERING"
}
const WORKSHOP_DESC := {
	"hull": "+12 loco HP and +1 armor per tier",
	"starter": "+0.7 dmg and −3% cooldown per tier",
	"armor_pierce": "+1.5 starter-gun armor penetration per tier",
	"targeting": "+6% starter-gun targeting range per tier",
	"reactor": "+1 reactor capacity per tier",
	"cooling": "+6% cooling efficiency per tier",
	"reinforced": "+12 max HP per tier on purchased wagons",
	"impact": "−3% incoming train damage per tier",
	"field_eng": "Restore up to 8 HP per tier to damaged cars after each track",
	"salvage": "+4% Scrap finds per tier",
	"starter_scrap": "+25 starting Scrap per tier on new expeditions",
	"weapons_eng": "+4% damage per tier for installed purchased weapons"
}

## Visual / physical specs keyed by car_type (matches existing art).
const TYPE_SPECS := {
	"loco": {
		"tex": "loco",
		"label": "Locomotive",
		# Same draw scale as weapon wagons so the convoy reads as one train.
		"k": 0.68,
		"contact": 440.0,
		"png_w": 950.0,
		"png_h": 426.0,
		"max_hp": 220.0,
		"armor": 8.0,
		"wheels": "loco"
	},
	"weapon": {
		"tex": "car_weapon",
		"label": "Weapon Car",
		"k": 0.68,
		"contact": 290.0,
		"png_w": 700.0,
		"png_h": 279.0,
		"max_hp": 155.0,
		"armor": 5.0,
		"wheels": "car"
	}
}

# Universal carriage mounts — any bought weapon type fits front / mid / rear.
# Loco starter remains locked. Spacing keeps three roof turrets from overlapping.
const UNIVERSAL_COMPAT := ["gatling", "cannon", "drone", "aux", "arc_coil", "cryo_launcher", "rail_mortar", "missile_rack"]
const HARDPOINT_TEMPLATES := {
	"loco": [
		# roof_dy ≈ PNG dome y (89) * loco k — runtime also re-derives from scale.
		{ "hp_id": "starter", "compat": ["starter"], "rel_x": 0.408, "roof_dy": 60.5 }
	],
	"weapon": [
		{ "hp_id": "front", "compat": UNIVERSAL_COMPAT, "rel_x": 0.22, "roof_dy": 28.0 },
		{ "hp_id": "mid", "compat": UNIVERSAL_COMPAT, "rel_x": 0.50, "roof_dy": 28.0 },
		{ "hp_id": "rear", "compat": UNIVERSAL_COMPAT, "rel_x": 0.78, "roof_dy": 28.0 }
	]
}

static func car_pixel_w(car_type: String) -> float:
	var spec: Dictionary = TYPE_SPECS.get(car_type, TYPE_SPECS["weapon"])
	return float(spec["png_w"]) * float(spec["k"])

static func car_pixel_h(car_type: String) -> float:
	var spec: Dictionary = TYPE_SPECS.get(car_type, TYPE_SPECS["weapon"])
	return float(spec["png_h"]) * float(spec["k"])

static func make_hardpoints(car_type: String) -> Array:
	var out: Array = []
	var templates: Array = HARDPOINT_TEMPLATES.get(car_type, [])
	for t in templates:
		out.append({
			"hp_id": str(t["hp_id"]),
			"compat": (t["compat"] as Array).duplicate(),
			"rel_x": float(t["rel_x"]),
			"roof_dy": float(t["roof_dy"]),
			"weapon": ""
		})
	return out

static func make_car(car_type: String, uid: String) -> Dictionary:
	var spec: Dictionary = TYPE_SPECS[car_type]
	var car := {
		"uid": uid,
		"id": car_type,
		"car_type": car_type,
		"label": str(spec["label"]),
		"x": 0.0,
		"left_x": 0.0,
		"max_hp": float(spec["max_hp"]),
		"hp": float(spec["max_hp"]),
		"armor": float(spec["armor"]),
		"disabled": false,
		"wreck_t": 0.0,
		"hardpoints": make_hardpoints(car_type)
	}
	if car_type == "loco":
		for hp in car["hardpoints"]:
			if str(hp["hp_id"]) == "starter":
				hp["weapon"] = "starter"
	return car

static func make_starter_loco(uid: String = "loco_1") -> Dictionary:
	return make_car("loco", uid)

static func wagon_cost(car_type: String) -> int:
	return int(WAGON_PRICES.get(car_type, -1))

static func core_weapon_cost(weapon_id: String) -> int:
	return int(CORE_WEAPON_PRICES.get(weapon_id, -1))

static func aux_weapon_cost(weapon_id: String) -> int:
	return int(AUX_WEAPON_PRICES.get(weapon_id, -1))

static func module_upgrade_cost(weapon_id: String, current_level: int) -> int:
	if not MODULE_UPGRADE_BASE.has(weapon_id):
		return -1
	if current_level >= 5:
		return -1
	return int(float(MODULE_UPGRADE_BASE[weapon_id]) * pow(float(current_level), UPGRADE_EXP))

static func aux_upgrade_cost(aux_id: String, current_level: int) -> int:
	if not AUX_UPGRADE_BASE.has(aux_id):
		return -1
	if current_level >= 5:
		return -1
	return int(float(AUX_UPGRADE_BASE[aux_id]) * pow(float(current_level), UPGRADE_EXP))

static func station_cost(item: String) -> int:
	return int(STATION_COSTS.get(item, -1))

static func workshop_cost(key: String, current_tier: int) -> int:
	# Escalating Alloy cost. Tier 0→1 is approachable; later tiers bite.
	if current_tier >= WORKSHOP_MAX_TIER:
		return -1
	if not WORKSHOP_KEYS.has(key):
		return -1
	var next := current_tier + 1
	return int(22 * pow(float(next), 1.55) + next * 8)

static func workshop_benefit_line(key: String, tier: int) -> String:
	# Human-readable total benefit at `tier` (0 = none).
	if tier <= 0:
		return "No bonus yet"
	match key:
		"hull":
			return "+%d loco HP  •  +%d armor" % [tier * 12, tier]
		"starter":
			return "+%.1f dmg  •  −%d%% cooldown" % [float(tier) * 0.7, tier * 3]
		"armor_pierce":
			return "+%.1f starter armor pen" % [float(tier) * 1.5]
		"targeting":
			return "+%d%% starter range" % [tier * 6]
		"reactor":
			return "+%d reactor capacity" % tier
		"cooling":
			return "+%d%% cooling efficiency" % [tier * 6]
		"reinforced":
			return "+%d wagon max HP" % [tier * 12]
		"impact":
			return "−%d%% incoming damage" % [tier * 3]
		"field_eng":
			return "Heal up to %d HP / car after each track" % [tier * 8]
		"salvage":
			return "+%d%% Scrap finds" % [tier * 4]
		"starter_scrap":
			return "+%d starting Scrap" % [tier * 25]
		"weapons_eng":
			return "+%d%% purchased weapon damage" % [tier * 4]
		_:
			return WORKSHOP_DESC.get(key, "")

static func workshop_next_benefit_line(key: String, current_tier: int) -> String:
	if current_tier >= WORKSHOP_MAX_TIER:
		return "MAXED"
	return workshop_benefit_line(key, current_tier + 1)

static func layout_cars(cars: Array) -> float:
	if cars.is_empty():
		return 0.0
	var loco_left := LOCO_LEFT_X
	var loco: Dictionary = cars[0]
	var loco_type := str(loco.get("car_type", loco.get("id", "loco")))
	var lw := car_pixel_w(loco_type)
	loco["left_x"] = loco_left
	loco["x"] = loco_left + lw * 0.5
	var cursor_left := loco_left
	for i in range(1, cars.size()):
		var c: Dictionary = cars[i]
		var ct := str(c.get("car_type", c.get("id", "weapon")))
		var cw := car_pixel_w(ct)
		cursor_left = cursor_left - CAR_GAP - cw
		c["left_x"] = cursor_left
		c["x"] = cursor_left + cw * 0.5
	# Do NOT bump the whole convoy right for MIN_LEFT_EDGE here.
	# Combat view shift (GodotMain.combat_shift_for_rear_focus) slides the train
	# right when wagons are added so the left rail stays an enemy stage.
	return 0.0

static func mount_world_x(car: Dictionary, hp: Dictionary) -> float:
	var left := float(car.get("left_x", 0.0))
	var ct := str(car.get("car_type", car.get("id", "weapon")))
	return left + car_pixel_w(ct) * float(hp.get("rel_x", 0.5))

static func mount_roof_y(car: Dictionary, hp: Dictionary, bob: float = 0.0) -> float:
	var ct := str(car.get("car_type", car.get("id", "weapon")))
	var spec: Dictionary = TYPE_SPECS.get(ct, TYPE_SPECS["weapon"])
	var y0 := 718.0 - float(spec["contact"]) * float(spec["k"]) + bob
	return y0 + float(hp.get("roof_dy", 30.0))

static func _compat_matches(compat: Array, weapon_key: String) -> bool:
	if compat.has(weapon_key):
		return true
	# Legacy "aux" slot accepts any auxiliary weapon type.
	if weapon_key in ["arc_coil", "cryo_launcher", "rail_mortar", "missile_rack"] and compat.has("aux"):
		return true
	if weapon_key == "aux" and (compat.has("aux") or compat.has("arc_coil")):
		return true
	return false

static func find_free_hardpoint(cars: Array, weapon_key: String) -> Dictionary:
	for c in cars:
		if c.get("disabled", false):
			continue
		var ct := str(c.get("car_type", c.get("id", "")))
		if ct == "loco" and weapon_key != "starter":
			continue
		for hp in c.get("hardpoints", []):
			if str(hp.get("weapon", "")) != "":
				continue
			var compat: Array = hp.get("compat", [])
			if _compat_matches(compat, weapon_key):
				return { "car_uid": str(c["uid"]), "hp_id": str(hp["hp_id"]), "car": c, "hp": hp }
	return {}

static func count_free_hardpoints(cars: Array, weapon_key: String = "") -> int:
	var n := 0
	for c in cars:
		if c.get("disabled", false):
			continue
		var ct := str(c.get("car_type", c.get("id", "")))
		if ct == "loco":
			continue
		for hp in c.get("hardpoints", []):
			if str(hp.get("weapon", "")) != "":
				continue
			if weapon_key == "" or _compat_matches(hp.get("compat", []), weapon_key):
				n += 1
	return n

static func list_free_hardpoints(cars: Array, weapon_key: String = "") -> Array:
	var out: Array = []
	for c in cars:
		if c.get("disabled", false):
			continue
		var ct := str(c.get("car_type", c.get("id", "")))
		if ct == "loco":
			continue
		for hp in c.get("hardpoints", []):
			if str(hp.get("weapon", "")) != "":
				continue
			if weapon_key != "" and not _compat_matches(hp.get("compat", []), weapon_key):
				continue
			out.append({
				"car_uid": str(c["uid"]),
				"hp_id": str(hp["hp_id"]),
				"label": "%s/%s" % [str(c.get("label", "?")), str(hp["hp_id"])]
			})
	return out

static func find_hardpoint(cars: Array, car_uid: String, hp_id: String) -> Dictionary:
	for c in cars:
		if str(c.get("uid", "")) != car_uid:
			continue
		for hp in c.get("hardpoints", []):
			if str(hp.get("hp_id", "")) == hp_id:
				return { "car": c, "hp": hp }
	return {}

static func clear_weapon_from_hardpoints(cars: Array, weapon_key: String) -> void:
	for c in cars:
		for hp in c.get("hardpoints", []):
			if str(hp.get("weapon", "")) == weapon_key:
				hp["weapon"] = ""

static func wagon_count(cars: Array) -> int:
	var n := 0
	for c in cars:
		var ct := str(c.get("car_type", c.get("id", "")))
		if ct != "loco":
			n += 1
	return n

## Permanent Alloy granted on failure. Anti-farm: near-instant suicides earn almost nothing.
static func fail_alloy_reward(encounter_index: int, region: String, kills: int, level: int, run_time: float) -> int:
	if run_time < 35.0 and encounter_index <= 0 and kills < 4:
		return 1
	var alloy := 4
	alloy += encounter_index * 9 # track progress is the main lever
	if region == "fungus_wilds":
		alloy += 30
	alloy += mini(24, int(kills / 4))
	alloy += level * 2
	alloy += int(clampf(run_time / 90.0, 0.0, 8.0))
	return alloy

## Encounter threat multiplier for hardcore pacing (applied on spawn).
## Early Rustlands curve softened so maxed Workshop builds can clear Track 3;
## later tracks / regions keep meaningful pressure.
static func encounter_threat_mul(encounter_index: int, region: String) -> float:
	var m := 1.0 + float(encounter_index) * 0.07
	if encounter_index >= 2:
		m *= 1.06
	if encounter_index >= 4:
		m *= 1.10
	if region == "fungus_wilds":
		m *= 1.28
	elif region == "rift_scar":
		m *= 1.40
	return m
