extends Control
## Mobile top-left locomotive status HUD — taste/redesign pass.
## Idea (from the subject): cabin instrument under brass bezel — dark gauge glass,
## one cyan accent language matching the tube lights, brass as metal not neon.
## Hierarchy: value > unit > SHD. Left-aligned readings. Bottom phosphor strip only.
## Layer order: glass → rim → fill → frame → text.

const FONT_PATH := "res://assets/ui/fonts/ShareTechMono-Regular.ttf"
const GLASS_COLOR := Color(0.0313726, 0.0941176, 0.141176, 0.90) ## #081824
const RIM_COLOR := Color(0.45, 0.82, 0.92, 0.12)
## Bright phosphor fills — readable at a glance, still under the brass frame.
const COL_HP := Color(0.35, 0.95, 0.55)
const COL_SPD := Color(1.0, 0.82, 0.35)
const COL_HEAT := Color(0.45, 0.95, 1.0)
const FILL_ALPHA := 0.82
## Fill uses the full well (inset only) — width = % of max; height = whole compartment.
const FILL_BAND_FRAC := 1.0
const PAD_X_FRAC := 0.07

var _hud_font: FontFile = null
var _shd_local: Rect2 = Rect2()

@onready var _frame: TextureRect = $Frame
@onready var _inner: Control = $InnerContent
@onready var _overlay: Control = $OverlayLabels
@onready var _hp_slot: Control = $InnerContent/HpSlot
@onready var _spd_slot: Control = $InnerContent/SpdSlot
@onready var _heat_slot: Control = $InnerContent/HeatSlot
@onready var _hp_value: Label = $OverlayLabels/HpValue
@onready var _hp_unit: Label = $OverlayLabels/HpUnit
@onready var _shd_label: Label = $OverlayLabels/ShdLabel
@onready var _spd_value: Label = $OverlayLabels/SpdValue
@onready var _spd_unit: Label = $OverlayLabels/SpdUnit
@onready var _heat_value: Label = $OverlayLabels/HeatValue
@onready var _heat_unit: Label = $OverlayLabels/HeatUnit


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.clip_contents = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.z_index = 0
	_frame.z_index = 10
	_overlay.z_index = 20
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_load_hud_font()
	_load_frame_texture()
	for slot in [_hp_slot, _spd_slot, _heat_slot]:
		_init_slot(slot)
	for lab in [_hp_value, _hp_unit, _shd_label, _spd_value, _spd_unit, _heat_value, _heat_unit]:
		_style_label(lab)
	visible = false


func _load_hud_font() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_hud_font = load(FONT_PATH) as FontFile
	if _hud_font == null and FileAccess.file_exists(FONT_PATH):
		var ff := FontFile.new()
		var err := ff.load_dynamic_font(ProjectSettings.globalize_path(FONT_PATH))
		if err == OK:
			_hud_font = ff


func _load_frame_texture() -> void:
	var path := "res://assets/ui/hud/riftline_dual_section_hud_panel_empty_interior.png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null and FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			tex = ImageTexture.create_from_image(img)
	if tex != null:
		_frame.texture = tex


func _init_slot(slot: Control) -> void:
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.clip_contents = true
	var glass: ColorRect = slot.get_node("Glass") as ColorRect
	glass.color = GLASS_COLOR
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rim: ColorRect = slot.get_node_or_null("Rim") as ColorRect
	if rim != null:
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rim.color = RIM_COLOR
	var fill: ColorRect = slot.get_node_or_null("Fill") as ColorRect
	if fill != null:
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _style_label(lab: Label) -> void:
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _hud_font != null:
		lab.add_theme_font_override("font", _hud_font)
	# No black shadow / outline — clean stamp on the glass.
	lab.add_theme_constant_override("shadow_offset_x", 0)
	lab.add_theme_constant_override("shadow_offset_y", 0)
	lab.add_theme_constant_override("outline_size", 0)
	lab.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))


func apply(screen_frame: Rect2, regions_design: Dictionary, canvas_scale: float, canvas_offset: Vector2, stats: Dictionary, win_to_vp: float = 1.0) -> void:
	if _hud_font == null:
		_load_hud_font()
	if _frame.texture == null:
		_load_frame_texture()
	position = screen_frame.position
	size = screen_frame.size
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_place_slot(_hp_slot, regions_design.get("hp", Rect2()), canvas_scale, canvas_offset, screen_frame)
	_place_slot(_spd_slot, regions_design.get("spd", Rect2()), canvas_scale, canvas_offset, screen_frame)
	_place_slot(_heat_slot, regions_design.get("heat", Rect2()), canvas_scale, canvas_offset, screen_frame)
	_shd_local = _design_to_local(regions_design.get("shield", Rect2()), canvas_scale, canvas_offset, screen_frame)

	var scale_f: float = maxf(1.0, win_to_vp)
	# Value has presence; unit is quiet tracked caption. SHD quieter still.
	# Floors keep type readable on phone-density / Retina preview windows.
	var value_font: int = clampi(int(round(16.0 * scale_f)), 15, 36)
	var unit_font: int = clampi(int(round(11.0 * scale_f)), 11, 24)
	var shd_font: int = clampi(int(round(11.0 * scale_f)), 11, 22)
	var sub_value: int = clampi(int(round(14.0 * scale_f)), 13, 30)

	var hp_col: Color = _stat_fill_color(stats.get("hp_col", COL_HP), COL_HP)
	var heat_col: Color = _stat_fill_color(stats.get("heat_col", COL_HEAT), COL_HEAT)

	_set_bar(_hp_slot, float(stats.get("hp_pct", 0.0)), hp_col)
	_set_bar(_spd_slot, float(stats.get("spd_pct", 0.0)), COL_SPD)
	_set_bar(_heat_slot, float(stats.get("heat_pct", 0.0)), heat_col)

	var hp_parts := _split_reading(str(stats.get("hp_label", "")), "HP")
	var spd_parts := _split_reading(str(stats.get("spd_label", "")), "SPD")
	var heat_parts := _split_reading(str(stats.get("heat_label", "")), "HEAT")

	var hp_zone_w: float = _hp_slot.size.x
	if _shd_local.size.x > 1.0:
		hp_zone_w = maxf(8.0, _shd_local.position.x - _hp_slot.position.x - 4.0)

	_place_reading(_hp_value, _hp_unit, _hp_slot.position, Vector2(hp_zone_w, _hp_slot.size.y),
		hp_parts[0], hp_parts[1], value_font, unit_font, _hp_slot.visible)
	_place_reading(_spd_value, _spd_unit, _spd_slot.position, _spd_slot.size,
		spd_parts[0], spd_parts[1], sub_value, unit_font, _spd_slot.visible)
	_place_reading(_heat_value, _heat_unit, _heat_slot.position, _heat_slot.size,
		heat_parts[0], heat_parts[1], sub_value, unit_font, _heat_slot.visible)

	# Quiet SHD — right of HP well, no chip, no competing weight.
	_stamp(_shd_label, _shd_local, str(stats.get("shd_label", "")), shd_font,
		Color(0.62, 0.84, 0.90, 0.78), HORIZONTAL_ALIGNMENT_RIGHT, _shd_local.size.x > 1.0)


func _stat_fill_color(live: Color, fallback: Color) -> Color:
	## Keep live low-HP / heat warning hues, bright enough to read on glass.
	if live.r > 0.7 and live.g < 0.55:
		return Color(1.0, 0.32, 0.28)
	if live.r > 0.7 and live.g > 0.55 and live.b < 0.45:
		return Color(1.0, 0.78, 0.28)
	return fallback


func _split_reading(raw: String, default_unit: String) -> PackedStringArray:
	var t := raw.strip_edges()
	if t == "" or t == "DESTROYED" or t == "—":
		return PackedStringArray([t, ""])
	var parts := t.split(" ", false)
	if parts.size() >= 2:
		var unit := str(parts[parts.size() - 1])
		var value := " ".join(parts.slice(0, parts.size() - 1))
		return PackedStringArray([value, unit])
	return PackedStringArray([t, default_unit])


func _place_reading(value_lab: Label, unit_lab: Label, slot_pos: Vector2, slot_size: Vector2, value: String, unit: String, value_px: int, unit_px: int, show: bool) -> void:
	if not show or slot_size.x <= 1.0:
		value_lab.visible = false
		unit_lab.visible = false
		return
	var pad_x: float = maxf(4.0, slot_size.x * PAD_X_FRAC)
	var row := Rect2(slot_pos + Vector2(pad_x, 0.0), Vector2(maxf(8.0, slot_size.x - pad_x * 2.0), slot_size.y))
	# Value on the left, unit on the right — never stacked/overlapping in the well.
	var unit_w: float = 0.0
	if unit != "":
		unit_w = clampf(float(unit.length()) * float(unit_px) * 0.62 + 2.0, float(unit_px) * 2.2, row.size.x * 0.42)
	var gap: float = maxf(4.0, float(unit_px) * 0.35) if unit != "" else 0.0
	var value_w: float = maxf(8.0, row.size.x - unit_w - gap)

	_stamp(value_lab, Rect2(row.position, Vector2(value_w, row.size.y)), value, value_px,
		Color(0.95, 0.96, 0.94), HORIZONTAL_ALIGNMENT_LEFT, true)
	_stamp(unit_lab, Rect2(Vector2(row.position.x + value_w + gap, row.position.y), Vector2(unit_w, row.size.y)), unit, unit_px,
		Color(0.55, 0.78, 0.86, 0.80), HORIZONTAL_ALIGNMENT_RIGHT, unit != "")
	if unit != "":
		unit_lab.add_theme_constant_override("letter_spacing", 1)


func _stamp(lab: Label, local_r: Rect2, text: String, font_px: int, col: Color, align: HorizontalAlignment, show: bool) -> void:
	lab.visible = show and local_r.size.x > 1.0
	if not lab.visible:
		return
	lab.text = text
	lab.horizontal_alignment = align
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.position = local_r.position
	lab.size = local_r.size
	if _hud_font != null:
		lab.add_theme_font_override("font", _hud_font)
	lab.add_theme_font_size_override("font_size", font_px)
	lab.add_theme_constant_override("outline_size", 0)
	lab.add_theme_constant_override("shadow_offset_x", 0)
	lab.add_theme_constant_override("shadow_offset_y", 0)
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	lab.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	lab.add_theme_color_override("font_color", col)


func _design_to_local(design_r: Rect2, canvas_scale: float, canvas_offset: Vector2, screen_frame: Rect2) -> Rect2:
	if design_r.size.x <= 1.0:
		return Rect2()
	var screen_pos: Vector2 = canvas_offset + design_r.position * canvas_scale
	var screen_size: Vector2 = design_r.size * canvas_scale
	return Rect2(screen_pos - screen_frame.position, screen_size)


func _place_slot(slot: Control, design_r: Rect2, canvas_scale: float, canvas_offset: Vector2, screen_frame: Rect2) -> void:
	if design_r.size.x <= 1.0:
		slot.visible = false
		return
	slot.visible = true
	var local_r: Rect2 = _design_to_local(design_r, canvas_scale, canvas_offset, screen_frame)
	slot.position = local_r.position
	slot.size = local_r.size
	var glass: ColorRect = slot.get_node("Glass") as ColorRect
	glass.visible = true
	glass.color = GLASS_COLOR
	glass.position = Vector2.ZERO
	glass.size = slot.size
	var rim: ColorRect = slot.get_node_or_null("Rim") as ColorRect
	if rim != null:
		rim.visible = true
		rim.color = RIM_COLOR
		rim.position = Vector2(1.0, 1.0)
		rim.size = Vector2(maxf(1.0, slot.size.x - 2.0), 1.5)


func _set_bar(slot: Control, pct: float, col: Color) -> void:
	var fill: ColorRect = slot.get_node_or_null("Fill") as ColorRect
	if fill == null:
		return
	# Minimal inset so the bright fill nearly fills the whole well.
	var inset: float = maxf(1.0, minf(slot.size.x, slot.size.y) * 0.04)
	var full_w: float = maxf(1.0, slot.size.x - inset * 2.0)
	var full_h: float = maxf(1.0, slot.size.y - inset * 2.0)
	var p: float = clampf(pct, 0.0, 1.0)
	fill.color = Color(col.r, col.g, col.b, FILL_ALPHA)
	fill.position = Vector2(inset, inset)
	fill.size = Vector2(full_w * p, full_h)
	fill.visible = p > 0.001
