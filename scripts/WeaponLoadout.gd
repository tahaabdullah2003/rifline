extends RefCounted
## Universal carriage weapon instances — ownership, mounts, install caps.
## GodotMain owns runtime `modules` dict; helpers here mutate it.

const TrainBuild = preload("res://scripts/TrainBuild.gd")

const MAX_INSTALL := {
	"gatling": 3,
	"cannon": 2,
	"drone": 2,
	"arc_coil": 1,
	"cryo_launcher": 1,
	"rail_mortar": 1,
	"missile_rack": 1
}

const CORE_TYPES := ["gatling", "cannon", "drone"]
const AUX_TYPES := ["arc_coil", "cryo_launcher", "rail_mortar", "missile_rack"]
const ALL_TYPES := ["gatling", "cannon", "drone", "arc_coil", "cryo_launcher", "rail_mortar", "missile_rack"]
const UNIVERSAL_COMPAT := ["gatling", "cannon", "drone", "aux", "arc_coil", "cryo_launcher", "rail_mortar", "missile_rack"]

const DEFAULT_PRIORITY := {
	"gatling": "nearest",
	"cannon": "strongest",
	"drone": "boarders",
	"arc_coil": "nearest",
	"cryo_launcher": "nearest",
	"rail_mortar": "strongest",
	"missile_rack": "strongest"
}

static func is_aux_type(weapon_type: String) -> bool:
	return AUX_TYPES.has(weapon_type)

static func is_core_type(weapon_type: String) -> bool:
	return CORE_TYPES.has(weapon_type)

static func max_owned(weapon_type: String) -> int:
	return int(MAX_INSTALL.get(weapon_type, 0))

static func ensure_loadout(modules: Dictionary) -> void:
	if not modules.has("loadout") or typeof(modules["loadout"]) != TYPE_DICTIONARY:
		modules["loadout"] = { "inventory": [], "installed": [], "next_serial": 1 }
	var lo: Dictionary = modules["loadout"]
	if not lo.has("inventory") or typeof(lo["inventory"]) != TYPE_ARRAY:
		lo["inventory"] = []
	if not lo.has("installed") or typeof(lo["installed"]) != TYPE_ARRAY:
		lo["installed"] = []
	lo["next_serial"] = maxi(1, int(lo.get("next_serial", 1)))

static func _alloc_uid(modules: Dictionary, weapon_type: String) -> String:
	ensure_loadout(modules)
	var lo: Dictionary = modules["loadout"]
	var n := int(lo["next_serial"])
	lo["next_serial"] = n + 1
	return "%s_%d" % [weapon_type, n]

static func make_instance(modules: Dictionary, weapon_type: String, level: int = 1) -> Dictionary:
	return {
		"uid": _alloc_uid(modules, weapon_type),
		"type": weapon_type,
		"level": clampi(level, 1, 5),
		"cooldown": 0.0,
		"priority": str(DEFAULT_PRIORITY.get(weapon_type, "nearest")),
		"power": 0,
		"car_uid": "",
		"hp_id": ""
	}

static func count_owned(modules: Dictionary, weapon_type: String) -> int:
	ensure_loadout(modules)
	var n := 0
	for inst in modules["loadout"]["inventory"]:
		if str(inst.get("type", "")) == weapon_type:
			n += 1
	for inst in modules["loadout"]["installed"]:
		if str(inst.get("type", "")) == weapon_type:
			n += 1
	return n

static func count_installed(modules: Dictionary, weapon_type: String = "") -> int:
	ensure_loadout(modules)
	if weapon_type == "":
		return (modules["loadout"]["installed"] as Array).size()
	var n := 0
	for inst in modules["loadout"]["installed"]:
		if str(inst.get("type", "")) == weapon_type:
			n += 1
	return n

static func installed_list(modules: Dictionary) -> Array:
	ensure_loadout(modules)
	return modules["loadout"]["installed"]

static func inventory_list(modules: Dictionary) -> Array:
	ensure_loadout(modules)
	return modules["loadout"]["inventory"]

static func find_installed(modules: Dictionary, uid: String) -> Dictionary:
	for inst in installed_list(modules):
		if str(inst.get("uid", "")) == uid:
			return inst
	return {}

static func find_inventory(modules: Dictionary, uid: String) -> Dictionary:
	for inst in inventory_list(modules):
		if str(inst.get("uid", "")) == uid:
			return inst
	return {}

static func can_buy(modules: Dictionary, weapon_type: String) -> bool:
	if not MAX_INSTALL.has(weapon_type):
		return false
	return count_owned(modules, weapon_type) < max_owned(weapon_type)

static func buy_to_inventory(modules: Dictionary, weapon_type: String, level: int = 1) -> Dictionary:
	if not can_buy(modules, weapon_type):
		return {}
	var inst := make_instance(modules, weapon_type, level)
	modules["loadout"]["inventory"].append(inst)
	_sync_legacy_flags(modules)
	return inst

static func free_hardpoint_count(cars: Array) -> int:
	var n := 0
	for c in cars:
		if c.get("disabled", false):
			continue
		var ct := str(c.get("car_type", c.get("id", "")))
		if ct == "loco":
			continue
		for hp in c.get("hardpoints", []):
			if str(hp.get("weapon", "")) == "":
				n += 1
	return n

static func list_free_hardpoints(cars: Array) -> Array:
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
			out.append({
				"car_uid": str(c["uid"]),
				"hp_id": str(hp["hp_id"]),
				"label": "%s/%s" % [str(c.get("label", "?")), str(hp["hp_id"])],
				"car": c,
				"hp": hp
			})
	return out

static func install(modules: Dictionary, cars: Array, inv_uid: String, car_uid: String = "", hp_id: String = "") -> String:
	## Returns "" on success, else error toast text.
	ensure_loadout(modules)
	var inst := find_inventory(modules, inv_uid)
	if inst.is_empty():
		return "Not in inventory"
	var wtype := str(inst.get("type", ""))
	if count_installed(modules, wtype) >= max_owned(wtype):
		return "Install limit reached"
	var slot: Dictionary = {}
	if car_uid != "" and hp_id != "":
		for c in cars:
			if str(c.get("uid", "")) != car_uid:
				continue
			if str(c.get("car_type", "")) == "loco":
				return "Cannot mount on locomotive"
			for hp in c.get("hardpoints", []):
				if str(hp.get("hp_id", "")) == hp_id:
					if str(hp.get("weapon", "")) != "":
						return "Hardpoint occupied"
					slot = { "car_uid": car_uid, "hp_id": hp_id, "car": c, "hp": hp }
					break
	else:
		var free := list_free_hardpoints(cars)
		if free.is_empty():
			return "FULL — no free mount"
		slot = free[0]
	if slot.is_empty():
		return "Hardpoint unavailable"
	# Move inventory → installed
	var inv: Array = modules["loadout"]["inventory"]
	for i in range(inv.size() - 1, -1, -1):
		if str(inv[i].get("uid", "")) == inv_uid:
			inv.remove_at(i)
			break
	inst["car_uid"] = str(slot["car_uid"])
	inst["hp_id"] = str(slot["hp_id"])
	inst["cooldown"] = 0.0
	if int(inst.get("power", 0)) <= 0:
		inst["power"] = 1
	slot["hp"]["weapon"] = str(inst["uid"])
	modules["loadout"]["installed"].append(inst)
	_sync_legacy_flags(modules)
	return ""

static func uninstall(modules: Dictionary, cars: Array, uid: String) -> String:
	ensure_loadout(modules)
	var inst := find_installed(modules, uid)
	if inst.is_empty():
		return "Not installed"
	_clear_hp_weapon(cars, uid)
	var installed: Array = modules["loadout"]["installed"]
	for i in range(installed.size() - 1, -1, -1):
		if str(installed[i].get("uid", "")) == uid:
			installed.remove_at(i)
			break
	inst["car_uid"] = ""
	inst["hp_id"] = ""
	inst["power"] = 0
	modules["loadout"]["inventory"].append(inst)
	_sync_legacy_flags(modules)
	return ""

static func swap(modules: Dictionary, cars: Array, installed_uid: String, inv_uid: String) -> String:
	## Replace mounted weapon with inventory weapon on the same hardpoint.
	var mounted := find_installed(modules, installed_uid)
	var incoming := find_inventory(modules, inv_uid)
	if mounted.is_empty():
		return "Not installed"
	if incoming.is_empty():
		return "Not in inventory"
	var car_uid := str(mounted.get("car_uid", ""))
	var hp_id := str(mounted.get("hp_id", ""))
	var err := uninstall(modules, cars, installed_uid)
	if err != "":
		return err
	err = install(modules, cars, inv_uid, car_uid, hp_id)
	if err != "":
		# Best-effort: reinstall old
		install(modules, cars, installed_uid, car_uid, hp_id)
		return err
	return ""

static func _clear_hp_weapon(cars: Array, weapon_uid: String) -> void:
	for c in cars:
		for hp in c.get("hardpoints", []):
			if str(hp.get("weapon", "")) == weapon_uid:
				hp["weapon"] = ""

static func resync_hardpoints(modules: Dictionary, cars: Array) -> void:
	## Clear wagon hardpoint weapons then rewrite from installed list.
	## Colliding mounts (two guns on one slot) are split onto free hardpoints first.
	resolve_mount_collisions(modules, cars)
	for c in cars:
		if str(c.get("car_type", c.get("id", ""))) == "loco":
			continue
		for hp in c.get("hardpoints", []):
			hp["weapon"] = ""
	for inst in installed_list(modules):
		var uid := str(inst.get("uid", ""))
		var car_uid := str(inst.get("car_uid", ""))
		var hp_id := str(inst.get("hp_id", ""))
		for c in cars:
			if str(c.get("uid", "")) != car_uid:
				continue
			for hp in c.get("hardpoints", []):
				if str(hp.get("hp_id", "")) == hp_id:
					hp["weapon"] = uid

static func resolve_mount_collisions(modules: Dictionary, cars: Array) -> void:
	## Ensure each installed instance has a unique car_uid+hp_id. First claim wins;
	## later duplicates take the next free hardpoint (or return to inventory if full).
	ensure_loadout(modules)
	var claimed: Dictionary = {}
	var to_reseat: Array = []
	for inst in installed_list(modules):
		var key := "%s|%s" % [str(inst.get("car_uid", "")), str(inst.get("hp_id", ""))]
		if str(inst.get("car_uid", "")) == "" or str(inst.get("hp_id", "")) == "" or claimed.has(key):
			to_reseat.append(inst)
		else:
			claimed[key] = str(inst.get("uid", ""))
	for inst2 in to_reseat:
		var free := list_free_hardpoints(cars)
		# Exclude already-claimed slots (hardpoint.weapon may still be empty mid-repair).
		var slot: Dictionary = {}
		for cand in free:
			var ck := "%s|%s" % [str(cand["car_uid"]), str(cand["hp_id"])]
			if claimed.has(ck):
				continue
			slot = cand
			break
		if slot.is_empty():
			# No room — park in inventory so it no longer stacks visually.
			var uid := str(inst2.get("uid", ""))
			var installed: Array = modules["loadout"]["installed"]
			for i in range(installed.size() - 1, -1, -1):
				if str(installed[i].get("uid", "")) == uid:
					installed.remove_at(i)
					break
			inst2["car_uid"] = ""
			inst2["hp_id"] = ""
			inst2["power"] = 0
			modules["loadout"]["inventory"].append(inst2)
			continue
		inst2["car_uid"] = str(slot["car_uid"])
		inst2["hp_id"] = str(slot["hp_id"])
		claimed["%s|%s" % [inst2["car_uid"], inst2["hp_id"]]] = str(inst2.get("uid", ""))
		slot["hp"]["weapon"] = str(inst2.get("uid", ""))

static func migrate_from_legacy(modules: Dictionary, cars: Array) -> void:
	ensure_loadout(modules)
	var lo: Dictionary = modules["loadout"]
	if (lo["installed"] as Array).size() > 0 or (lo["inventory"] as Array).size() > 0:
		resync_hardpoints(modules, cars)
		_sync_legacy_flags(modules)
		return
	# Legacy owned cores → inventory or installed via mounts
	var owned: Array = modules.get("owned_core", [])
	var mounts: Dictionary = modules.get("mounts", {})
	var levels: Dictionary = modules.get("levels", {})
	for core in CORE_TYPES:
		var owned_n := 0
		if owned.has(core) or bool(modules.get("installed", {}).get(core, false)):
			owned_n = 1
		# Multi-mount legacy: mounts[core] can be array
		var mount_entries: Array = []
		if mounts.has(core):
			var m = mounts[core]
			if typeof(m) == TYPE_ARRAY:
				mount_entries = m
			elif typeof(m) == TYPE_DICTIONARY:
				mount_entries = [m]
		if mount_entries.is_empty() and bool(modules.get("installed", {}).get(core, false)):
			# Will place on first free later
			var inst := make_instance(modules, core, int(levels.get(core, 1)))
			lo["inventory"].append(inst)
		else:
			for me in mount_entries:
				var inst2 := make_instance(modules, core, int(levels.get(core, 1)))
				inst2["car_uid"] = str(me.get("car_uid", ""))
				inst2["hp_id"] = str(me.get("hp_id", ""))
				inst2["power"] = 1
				lo["installed"].append(inst2)
			if owned_n > 0 and mount_entries.is_empty():
				pass
			elif owned_n > mount_entries.size() and owned.has(core):
				# Owned but extra not mounted
				pass
	# Aux: installed aux + inventory list of other aux ids
	var aux_levels: Dictionary = modules.get("aux_levels", {})
	var installed_aux = modules.get("installed", {}).get("aux", null)
	if installed_aux != null and str(installed_aux) != "":
		var ainst := make_instance(modules, str(installed_aux), int(aux_levels.get(str(installed_aux), 1)))
		var am = mounts.get("aux", {})
		if typeof(am) == TYPE_DICTIONARY:
			ainst["car_uid"] = str(am.get("car_uid", ""))
			ainst["hp_id"] = str(am.get("hp_id", ""))
		ainst["power"] = 1
		lo["installed"].append(ainst)
	for aux_id in modules.get("inventory", []):
		var aid := str(aux_id)
		if not AUX_TYPES.has(aid):
			continue
		if installed_aux != null and str(installed_aux) == aid:
			continue
		lo["inventory"].append(make_instance(modules, aid, int(aux_levels.get(aid, 1))))
	# Place any inventory cores that were "installed" without mounts
	for inst in lo["inventory"].duplicate():
		if not CORE_TYPES.has(str(inst.get("type", ""))):
			continue
		if bool(modules.get("installed", {}).get(str(inst["type"]), false)):
			var free := list_free_hardpoints(cars)
			if not free.is_empty():
				install(modules, cars, str(inst["uid"]), str(free[0]["car_uid"]), str(free[0]["hp_id"]))
	# Fix installed with missing mounts — claim each free slot so the next gun
	# cannot reuse the same front hardpoint (legacy drone+arc stack bug).
	for inst in lo["installed"].duplicate():
		if str(inst.get("car_uid", "")) == "" or str(inst.get("hp_id", "")) == "":
			var free2 := list_free_hardpoints(cars)
			if free2.is_empty():
				uninstall(modules, cars, str(inst["uid"]))
			else:
				inst["car_uid"] = str(free2[0]["car_uid"])
				inst["hp_id"] = str(free2[0]["hp_id"])
				free2[0]["hp"]["weapon"] = str(inst["uid"])
	resync_hardpoints(modules, cars)
	_sync_legacy_flags(modules)

static func _sync_legacy_flags(modules: Dictionary) -> void:
	## Keep old bool/aux fields coherent for harnesses & leftover readers.
	ensure_loadout(modules)
	if not modules.has("installed") or typeof(modules["installed"]) != TYPE_DICTIONARY:
		modules["installed"] = { "gatling": false, "cannon": false, "drone": false, "aux": null }
	if not modules.has("owned_core"):
		modules["owned_core"] = []
	if not modules.has("inventory"):
		modules["inventory"] = []
	if not modules.has("levels"):
		modules["levels"] = { "gatling": 1, "cannon": 1, "drone": 1 }
	if not modules.has("aux_levels"):
		modules["aux_levels"] = {}
	modules["installed"]["gatling"] = count_installed(modules, "gatling") > 0
	modules["installed"]["cannon"] = count_installed(modules, "cannon") > 0
	modules["installed"]["drone"] = count_installed(modules, "drone") > 0
	var first_aux = null
	var max_lvl := {}
	for inst in installed_list(modules):
		var t := str(inst.get("type", ""))
		var lv := int(inst.get("level", 1))
		max_lvl[t] = maxi(int(max_lvl.get(t, 1)), lv)
		if is_aux_type(t) and first_aux == null:
			first_aux = t
	for inst in inventory_list(modules):
		var t2 := str(inst.get("type", ""))
		var lv2 := int(inst.get("level", 1))
		max_lvl[t2] = maxi(int(max_lvl.get(t2, 1)), lv2)
	modules["installed"]["aux"] = first_aux
	modules["owned_core"].clear()
	for core in CORE_TYPES:
		if count_owned(modules, core) > 0:
			modules["owned_core"].append(core)
		if max_lvl.has(core):
			modules["levels"][core] = int(max_lvl[core])
	modules["inventory"].clear()
	for inst in inventory_list(modules):
		var t3 := str(inst.get("type", ""))
		if is_aux_type(t3) and not modules["inventory"].has(t3):
			modules["inventory"].append(t3)
		if is_aux_type(t3) and max_lvl.has(t3):
			modules["aux_levels"][t3] = int(max_lvl[t3])
	for inst in installed_list(modules):
		var t4 := str(inst.get("type", ""))
		if is_aux_type(t4) and max_lvl.has(t4):
			modules["aux_levels"][t4] = int(max_lvl[t4])

static func total_weapon_power(modules: Dictionary) -> int:
	var used := 0
	for inst in installed_list(modules):
		used += clampi(int(inst.get("power", 0)), 0, 3)
	return used

static func instance_mount_xy(cars: Array, inst: Dictionary, car_slot_ox_cb: Callable) -> Dictionary:
	var car_uid := str(inst.get("car_uid", ""))
	var hp_id := str(inst.get("hp_id", ""))
	for c in cars:
		if str(c.get("uid", "")) != car_uid:
			continue
		if c.get("disabled", false) and float(c.get("hp", 0.0)) <= 0.0:
			return {}
		for hp in c.get("hardpoints", []):
			if str(hp.get("hp_id", "")) != hp_id:
				continue
			var ox := float(car_slot_ox_cb.call(c))
			return {
				"car": c,
				"hp": hp,
				"mount_x": TrainBuild.mount_world_x(c, hp) + ox,
				"inst": inst
			}
	return {}
