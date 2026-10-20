extends RefCounted
## Authoritative Rift Loop difficulty + elite-class configuration.
## All loop HP/damage weights and spawn probabilities live here.

const CLASS_NORMAL := "normal"
const CLASS_RED := "red"
const CLASS_BLUE := "blue"

## Max living Red/Blue elites at once ( overcrowding / stacked telegraphs ).
const MAX_LIVING_ELITES: int = 3

## Elite combat multipliers ON TOP of the loop's normal baseline.
const ELITE := {
	CLASS_NORMAL: { "hp": 1.00, "damage": 1.00, "scrap": 1.00, "armor_add": 0.0 },
	CLASS_RED: { "hp": 1.75, "damage": 1.25, "scrap": 1.35, "armor_add": 3.0 },
	CLASS_BLUE: { "hp": 2.50, "damage": 1.55, "scrap": 1.75, "armor_add": 5.0 }
}

## Thin silhouette outline colors (Blue is electric, not cyan).
## Keep alpha moderate so the rim doesn't read as a solid ground smear.
const OUTLINE := {
	CLASS_RED: Color(1.0, 0.18, 0.12, 0.78),
	CLASS_BLUE: Color(0.18, 0.28, 1.0, 0.78)
}

const HP_BAR := {
	CLASS_RED: Color(1.0, 0.28, 0.22, 1.0),
	CLASS_BLUE: Color(0.28, 0.38, 1.0, 1.0)
}

## Loop 1–5 exact tables; loop 6+ uses LOOP_6_PLUS + per-loop increments.
const LOOP_TABLE := {
	1: { "enemy_hp": 1.00, "enemy_damage": 1.00, "boss_hp": 1.00, "boss_damage": 1.00,
		"w_normal": 100, "w_red": 0, "w_blue": 0 },
	2: { "enemy_hp": 1.30, "enemy_damage": 1.30, "boss_hp": 1.60, "boss_damage": 1.30,
		"w_normal": 70, "w_red": 30, "w_blue": 0 },
	3: { "enemy_hp": 1.70, "enemy_damage": 1.60, "boss_hp": 2.30, "boss_damage": 1.60,
		"w_normal": 50, "w_red": 35, "w_blue": 15 },
	4: { "enemy_hp": 2.15, "enemy_damage": 1.90, "boss_hp": 3.10, "boss_damage": 1.90,
		"w_normal": 35, "w_red": 40, "w_blue": 25 },
	5: { "enemy_hp": 2.65, "enemy_damage": 2.20, "boss_hp": 4.00, "boss_damage": 2.20,
		"w_normal": 25, "w_red": 40, "w_blue": 35 }
}

const LOOP_6_PLUS := {
	"enemy_hp": 3.15, "enemy_damage": 2.45, "boss_hp": 4.90, "boss_damage": 2.45,
	"w_normal": 15, "w_red": 35, "w_blue": 50
}

const PER_LOOP_AFTER_6 := {
	"enemy_hp": 0.50, "enemy_damage": 0.25, "boss_hp": 0.90, "boss_damage": 0.25
}


static func clamp_loop(loop: int) -> int:
	return maxi(1, loop)


static func profile(loop: int) -> Dictionary:
	loop = clamp_loop(loop)
	if LOOP_TABLE.has(loop):
		return (LOOP_TABLE[loop] as Dictionary).duplicate()
	var extra: int = loop - 6
	var p: Dictionary = LOOP_6_PLUS.duplicate()
	p["enemy_hp"] = float(LOOP_6_PLUS["enemy_hp"]) + float(PER_LOOP_AFTER_6["enemy_hp"]) * float(extra)
	p["enemy_damage"] = float(LOOP_6_PLUS["enemy_damage"]) + float(PER_LOOP_AFTER_6["enemy_damage"]) * float(extra)
	p["boss_hp"] = float(LOOP_6_PLUS["boss_hp"]) + float(PER_LOOP_AFTER_6["boss_hp"]) * float(extra)
	p["boss_damage"] = float(LOOP_6_PLUS["boss_damage"]) + float(PER_LOOP_AFTER_6["boss_damage"]) * float(extra)
	return p


static func enemy_hp_mul(loop: int) -> float:
	return float(profile(loop)["enemy_hp"])


static func enemy_damage_mul(loop: int) -> float:
	return float(profile(loop)["enemy_damage"])


static func boss_hp_mul(loop: int) -> float:
	return float(profile(loop)["boss_hp"])


static func boss_damage_mul(loop: int) -> float:
	return float(profile(loop)["boss_damage"])


static func spawn_weights(loop: int) -> Dictionary:
	var p := profile(loop)
	return {
		CLASS_NORMAL: int(p["w_normal"]),
		CLASS_RED: int(p["w_red"]),
		CLASS_BLUE: int(p["w_blue"])
	}


static func roll_elite_class(loop: int, rng: RandomNumberGenerator = null) -> String:
	var w := spawn_weights(loop)
	var total: int = int(w[CLASS_NORMAL]) + int(w[CLASS_RED]) + int(w[CLASS_BLUE])
	if total <= 0:
		return CLASS_NORMAL
	var roll: int
	if rng != null:
		roll = rng.randi_range(0, total - 1)
	else:
		roll = randi() % total
	if roll < int(w[CLASS_NORMAL]):
		return CLASS_NORMAL
	roll -= int(w[CLASS_NORMAL])
	if roll < int(w[CLASS_RED]):
		return CLASS_RED
	return CLASS_BLUE


static func elite_hp_mul(eclass: String) -> float:
	return float(ELITE.get(eclass, ELITE[CLASS_NORMAL])["hp"])


static func elite_damage_mul(eclass: String) -> float:
	return float(ELITE.get(eclass, ELITE[CLASS_NORMAL])["damage"])


static func elite_scrap_mul(eclass: String) -> float:
	return float(ELITE.get(eclass, ELITE[CLASS_NORMAL])["scrap"])


static func elite_armor_add(eclass: String) -> float:
	return float(ELITE.get(eclass, ELITE[CLASS_NORMAL])["armor_add"])


static func outline_color(eclass: String) -> Color:
	if OUTLINE.has(eclass):
		return OUTLINE[eclass]
	return Color(1, 1, 1, 0)


static func hp_bar_color(eclass: String) -> Color:
	if HP_BAR.has(eclass):
		return HP_BAR[eclass]
	return Color(1.0, 0.35, 0.32, 1.0)


static func is_elite_class(eclass: String) -> bool:
	return eclass == CLASS_RED or eclass == CLASS_BLUE
