extends Control
## Mobile top-center encounter / mission HUD — taste pass.
## Asset: riftline_long_hud_frame_open (opaque textured bay + cyan lips).
## Layers: decorative SVG frame → clipped progress fill → live text.
## No glass / shadow box — art bay is already dark.

const FONT_PATH := "res://assets/ui/fonts/ShareTechMono-Regular.ttf"
const FRAME_PATH := "res://assets/ui/hud/riftline_long_hud_frame_open.png"

var _hud_font: FontFile = null

@onready var _frame: TextureRect = $Frame
@onready var _inner: Control = $InnerContent
@onready var _overlay: Control = $OverlayLabels
@onready var _glass: ColorRect = $InnerContent/Glass
@onready var _bar_track: ColorRect = $InnerContent/BarTrack
@onready var _bar_fill: ColorRect = $InnerContent/BarFill
@onready var _title: Label = $OverlayLabels/Title
@onready var _meta: Label = $OverlayLabels/Meta
@onready var _prog: Label = $OverlayLabels/ProgressLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.clip_contents = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.z_index = 0
	_inner.z_index = 10
	_overlay.z_index = 20
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_glass.visible = false
	_load_font()
	_load_frame()
	for lab in [_title, _meta, _prog]:
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
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_TOP
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


func apply(screen_frame: Rect2, content_design: Rect2, canvas_scale: float, canvas_offset: Vector2, data: Dictionary, win_to_vp: float = 1.0) -> void:
	if _hud_font == null:
		_load_font()
	if _frame.texture == null:
		_load_frame()
	position = screen_frame.position
	size = screen_frame.size
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var content_local := _design_to_local(content_design, canvas_scale, canvas_offset, screen_frame)
	if content_local.size.x <= 1.0:
		visible = false
		return

	_inner.position = content_local.position
	_inner.size = content_local.size
	_inner.clip_contents = true
	# Art bay already provides the dark field — no flat shadow box.
	_glass.visible = false

	var scale_f: float = maxf(1.0, win_to_vp)
	var compact: bool = bool(data.get("compact_meta", false))
	var title_px: int = clampi(int(round((16.0 if compact else 18.0) * scale_f)), 15, 38)
	var meta_px: int = clampi(int(round((12.0 if compact else 13.5) * scale_f)), 12, 28)
	var prog_px: int = clampi(int(round(12.5 * scale_f)), 12, 26)

	# Generous inset from cyan lips; clear non-overlapping vertical bands.
	var pad_x: float = maxf(10.0, content_local.size.x * 0.045)
	var pad_y: float = maxf(5.0, content_local.size.y * 0.08)
	var usable := Rect2(
		Vector2(pad_x, pad_y),
		Vector2(maxf(8.0, content_local.size.x - pad_x * 2.0), maxf(8.0, content_local.size.y - pad_y * 2.0))
	)

	var gap: float = maxf(4.0, usable.size.y * 0.08)
	var bar_h: float = clampf(usable.size.y * 0.18, 8.0, 14.0 * scale_f)
	var prog_w: float = clampf(usable.size.x * 0.13, 40.0 * scale_f, 72.0 * scale_f)
	# Glyph bands sized to the larger readable type.
	var title_h: float = float(title_px) * 1.18
	var meta_h: float = float(meta_px) * 1.25
	var origin: Vector2 = content_local.position + usable.position
	var title_r := Rect2(origin, Vector2(usable.size.x, title_h))
	var meta_r := Rect2(origin + Vector2(0.0, title_h + gap * 0.55), Vector2(usable.size.x, meta_h))
	var bar_y: float = usable.position.y + usable.size.y - bar_h
	var bar_track_w: float = maxf(24.0, usable.size.x - prog_w - gap * 1.4)
	var bar_local := Rect2(usable.position.x, bar_y, bar_track_w, bar_h)
	var prog_r := Rect2(
		content_local.position + Vector2(usable.position.x + bar_track_w + gap * 0.6, bar_y - 1.0),
		Vector2(prog_w, bar_h + 2.0)
	)

	_title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_meta.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_prog.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stamp(_title, title_r, str(data.get("title", "")), title_px, Color(0.97, 0.98, 0.95))
	_stamp(_meta, meta_r, str(data.get("meta", "")), meta_px, Color(0.62, 0.88, 0.94, 0.95))

	var pct: float = clampf(float(data.get("progress_pct", 0.0)), 0.0, 1.0)
	var bar_col: Color = data.get("progress_col", Color(0.24, 0.88, 1.0))
	# Whisper track on the art bay — no flat black slab.
	_bar_track.position = bar_local.position
	_bar_track.size = bar_local.size
	_bar_track.color = Color(0.02, 0.05, 0.08, 0.22)
	_bar_fill.position = bar_local.position
	_bar_fill.size = Vector2(maxf(0.0, bar_local.size.x * pct), bar_local.size.y)
	_bar_fill.color = Color(bar_col.r, bar_col.g, bar_col.b, 0.96)
	_bar_fill.visible = pct > 0.001

	# % sits beside the bar — never over the cyan fill (avoids ghost/blur).
	_prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp(_prog, prog_r, str(data.get("progress_label", "")), prog_px, Color(0.94, 0.96, 0.93))


func _design_to_local(design_r: Rect2, canvas_scale: float, canvas_offset: Vector2, screen_frame: Rect2) -> Rect2:
	if design_r.size.x <= 1.0:
		return Rect2()
	var screen_pos: Vector2 = canvas_offset + design_r.position * canvas_scale
	var screen_size: Vector2 = design_r.size * canvas_scale
	return Rect2(screen_pos - screen_frame.position, screen_size)


func _stamp(lab: Label, local_r: Rect2, text: String, font_px: int, col: Color) -> void:
	lab.visible = local_r.size.x > 1.0 and text != ""
	if not lab.visible:
		return
	lab.text = text
	lab.position = local_r.position
	lab.size = local_r.size
	if _hud_font != null:
		lab.add_theme_font_override("font", _hud_font)
	lab.add_theme_font_size_override("font_size", font_px)
	lab.add_theme_color_override("font_color", col)
	lab.add_theme_constant_override("outline_size", 0)
	lab.add_theme_constant_override("shadow_offset_x", 0)
	lab.add_theme_constant_override("shadow_offset_y", 0)
	lab.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
