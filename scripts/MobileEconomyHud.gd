extends Control
## Mobile top-right scrap / level / XP HUD — Mission 03 polish.
## Gear sits ON TOP of the brass circle (centered in the well); XP fill + text above.
## Level badge shows the bare number (e.g. "3") so it fits the octagon.

const FONT_PATH := "res://assets/ui/fonts/ShareTechMono-Regular.ttf"
## Frame with scrap gear baked dead-center in the circular well (on top of the bay).
const FRAME_PATH := "res://assets/ui/hud/riftline_wide_hud_bar_a_with_gear.png"
const GEAR_PATH := "res://assets/ui/hud/economy_scrap_gear.png"
const COL_SCRAP := Color(1.0, 0.82, 0.48) ## #ffd27b
const COL_LEVEL := Color(0.55, 0.97, 1.0) ## #8ef7ff
const COL_XP := Color(0.37, 0.91, 1.0) ## #5ee9ff

var _hud_font: FontFile = null

@onready var _icon: TextureRect = $ScrapIcon
@onready var _frame: TextureRect = $Frame
@onready var _xp_clip: Control = $XpClip
@onready var _bar_track: ColorRect = $XpClip/BarTrack
@onready var _bar_fill: ColorRect = $XpClip/BarFill
@onready var _overlay: Control = $OverlayLabels
@onready var _scrap: Label = $OverlayLabels/ScrapValue
@onready var _level: Label = $OverlayLabels/LevelValue
@onready var _xp_lab: Label = $OverlayLabels/XpValue


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_clip.clip_contents = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# brass frame → gear (on top, in circle) → XP fill → live text
	_frame.z_index = 0
	_icon.z_index = 5
	_xp_clip.z_index = 10
	_overlay.z_index = 20
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_load_font()
	_load_frame()
	for lab in [_scrap, _level, _xp_lab]:
		_style_label(lab)
	visible = false


func _load_font() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_hud_font = load(FONT_PATH) as FontFile
	if _hud_font == null and FileAccess.file_exists(FONT_PATH):
		var ff := FontFile.new()
		if ff.load_dynamic_font(ProjectSettings.globalize_path(FONT_PATH)) == OK:
			_hud_font = ff


func _load_frame() -> void:
	var tex: Texture2D = null
	if ResourceLoader.exists(FRAME_PATH):
		tex = load(FRAME_PATH) as Texture2D
	if tex == null and FileAccess.file_exists(FRAME_PATH):
		var img := Image.load_from_file(ProjectSettings.globalize_path(FRAME_PATH))
		if img != null:
			tex = ImageTexture.create_from_image(img)
	if tex != null:
		_frame.texture = tex


func _style_label(lab: Label) -> void:
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.clip_text = true
	lab.autowrap_mode = TextServer.AUTOWRAP_OFF
	lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if _hud_font != null:
		lab.add_theme_font_override("font", _hud_font)
	lab.add_theme_constant_override("outline_size", 0)
	lab.add_theme_constant_override("shadow_offset_x", 0)
	lab.add_theme_constant_override("shadow_offset_y", 0)
	lab.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))


func apply(screen_frame: Rect2, regions_design: Dictionary, canvas_scale: float, canvas_offset: Vector2, data: Dictionary, win_to_vp: float = 1.0) -> void:
	if _hud_font == null:
		_load_font()
	if _frame.texture == null:
		_load_frame()
	position = screen_frame.position
	size = screen_frame.size
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var emblem := _design_to_local(regions_design.get("emblem", Rect2()), canvas_scale, canvas_offset, screen_frame)
	var scrap_r := _design_to_local(regions_design.get("scrap", Rect2()), canvas_scale, canvas_offset, screen_frame)
	var level_r := _design_to_local(regions_design.get("level", Rect2()), canvas_scale, canvas_offset, screen_frame)
	var xp_r := _design_to_local(regions_design.get("xp", Rect2()), canvas_scale, canvas_offset, screen_frame)
	if scrap_r.size.x <= 1.0:
		visible = false
		return

	var scale_f: float = maxf(1.0, win_to_vp)
	var compact: bool = bool(data.get("compact", false))
	# Readable type inside the opaque wells (old max~14 left XP unreadable on Retina).
	var scrap_px: int = clampi(int(round((13.0 if compact else 15.0) * scale_f)), 13, 30)
	var level_px: int = clampi(int(round((13.0 if compact else 15.0) * scale_f)), 13, 30)
	var xp_px: int = clampi(int(round((11.0 if compact else 12.0) * scale_f)), 11, 24)

	# Gear is baked into FRAME_PATH (centered in the circle). Hide the live overlay.
	_icon.visible = false
	_icon.texture = null

	_stamp(_scrap, scrap_r, str(data.get("scrap_label", "")), scrap_px, COL_SCRAP,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	# Bare level digit only — fits the small badge.
	_stamp(_level, level_r, str(data.get("level_label", "")), level_px, COL_LEVEL,
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)

	# No XP fill bar — reading text alone sits in the bay.
	_xp_clip.visible = false
	_bar_track.visible = false
	_bar_fill.visible = false

	_stamp(_xp_lab, xp_r, str(data.get("xp_label", "")), xp_px, Color(0.96, 0.97, 0.95),
		HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)


func _load_icon_tex(path: String) -> Texture2D:
	# Prefer the centered generated gear (transparent PNG behind the bezel).
	var candidates: Array[String] = [GEAR_PATH, path]
	if path != "" and not path.begins_with("res://"):
		candidates.append("res://" + path)
	candidates.append("res://assets/ui/final/icon_scrap_gear.png")
	candidates.append("res://assets/icon_scrap.png")
	for p in candidates:
		if p == null or str(p) == "":
			continue
		var ps := str(p)
		if ResourceLoader.exists(ps):
			var t := load(ps) as Texture2D
			if t != null:
				return t
		if FileAccess.file_exists(ps):
			var img := Image.load_from_file(ProjectSettings.globalize_path(ps))
			if img != null:
				return ImageTexture.create_from_image(img)
	return null


func _design_to_local(design_r: Rect2, canvas_scale: float, canvas_offset: Vector2, screen_frame: Rect2) -> Rect2:
	if design_r.size.x <= 1.0:
		return Rect2()
	var screen_pos: Vector2 = canvas_offset + design_r.position * canvas_scale
	var screen_size: Vector2 = design_r.size * canvas_scale
	return Rect2(screen_pos - screen_frame.position, screen_size)


func _stamp(lab: Label, local_r: Rect2, text: String, font_px: int, col: Color, h_align: HorizontalAlignment, v_align: VerticalAlignment) -> void:
	lab.visible = local_r.size.x > 1.0 and text != ""
	if not lab.visible:
		return
	lab.text = text
	lab.horizontal_alignment = h_align
	lab.vertical_alignment = v_align
	lab.position = local_r.position
	lab.size = local_r.size
	if _hud_font != null:
		lab.add_theme_font_override("font", _hud_font)
	lab.add_theme_font_size_override("font_size", font_px)
	lab.add_theme_color_override("font_color", col)
	lab.add_theme_constant_override("outline_size", 0)
	lab.add_theme_constant_override("shadow_offset_x", 0)
	lab.add_theme_constant_override("shadow_offset_y", 0)
