extends RefCounted
## Android / touch layout helpers. Desktop layout stays unchanged when inactive.
##
## Editor F5 mobile preview (Infinix X680B landscape):
##   Requires a SEPARATE game window (not embedded Game view).
##   Enable:  riftline/mobile_preview=true + editor run args --mobile-ui
##            .godot/editor/project_metadata.cfg game_view/embed_on_play=false
##   Disable: riftline/mobile_preview=false, clear run args, restore window overrides 1280×720
## Released Windows builds never enable preview (requires editor feature or CLI flag).

## Detected device: Infinix X680B — physical portrait 720×1640 @ 320dpi.
## Landscape physical: 1640×720. Landscape app/usable: 1480×720 (cutout + system bars).
const DEVICE_LANDSCAPE_W := 1640
const DEVICE_LANDSCAPE_H := 720
const DEVICE_APP_LANDSCAPE_W := 1480
const DEVICE_APP_LANDSCAPE_H := 720
const DEVICE_CUTOUT_LEFT_PX := 64
const DEVICE_SYSTEM_RIGHT_PX := 96 ## 1640 - 1480 - 64
const DEVICE_DENSITY_DPI := 320

## F5 window: same aspect as phone landscape, sized for a 1536×864 laptop desktop.
## 1230×540 == 1640×720 × 0.75
const PREVIEW_WINDOW_W := 1230
const PREVIEW_WINDOW_H := 540
const PREVIEW_ASPECT := float(PREVIEW_WINDOW_W) / float(PREVIEW_WINDOW_H)
const DEVICE_ASPECT := float(DEVICE_LANDSCAPE_W) / float(DEVICE_LANDSCAPE_H)


static func is_mobile_preview() -> bool:
	var args := OS.get_cmdline_args()
	var uargs := OS.get_cmdline_user_args()
	if args.has("--mobile-ui") or args.has("--mobile-preview"):
		return true
	if uargs.has("--mobile-ui") or uargs.has("--mobile-preview"):
		return true
	# Editor / F5 only — never active in exported desktop releases.
	if OS.has_feature("editor") and bool(ProjectSettings.get_setting("riftline/mobile_preview", false)):
		return true
	return false


static func wants_mobile_ui() -> bool:
	if OS.has_feature("android") or OS.has_feature("ios"):
		return true
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		return true
	return is_mobile_preview()


## Optional F5 / CLI override: --mobile-preview-size=1230x540 (window client area only).
static func preview_window_size() -> Vector2i:
	var raw := ""
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("--mobile-preview-size="):
			raw = s.substr(s.find("=") + 1)
			break
	if raw == "":
		for a in OS.get_cmdline_args():
			var s2 := str(a)
			if s2.begins_with("--mobile-preview-size="):
				raw = s2.substr(s2.find("=") + 1)
				break
	if raw != "":
		var parts: PackedStringArray = raw.to_lower().split("x")
		if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			var tw: int = maxi(320, int(parts[0]))
			var th: int = maxi(180, int(parts[1]))
			return Vector2i(tw, th)
	return Vector2i(PREVIEW_WINDOW_W, PREVIEW_WINDOW_H)


static func apply_preview_window_if_needed() -> void:
	if not is_mobile_preview():
		return
	if OS.has_feature("android") or OS.has_feature("ios"):
		return
	# Multi-size HUD capture drives the window itself — do not snap back to default.
	if OS.get_cmdline_args().has("--capture-mobile-status") or OS.get_cmdline_user_args().has("--capture-mobile-status") \
			or OS.get_cmdline_args().has("--capture-mobile-encounter") or OS.get_cmdline_user_args().has("--capture-mobile-encounter") \
			or OS.get_cmdline_args().has("--capture-mobile-economy") or OS.get_cmdline_user_args().has("--capture-mobile-economy") \
			or OS.get_cmdline_args().has("--capture-mobile-shop") or OS.get_cmdline_user_args().has("--capture-mobile-shop") \
			or OS.get_cmdline_args().has("--capture-mobile-reactor") or OS.get_cmdline_user_args().has("--capture-mobile-reactor") \
			or OS.get_cmdline_args().has("--capture-mobile-weapons") or OS.get_cmdline_user_args().has("--capture-mobile-weapons") \
			or OS.get_cmdline_args().has("--capture-mobile-abilities") or OS.get_cmdline_user_args().has("--capture-mobile-abilities") \
			or OS.get_cmdline_args().has("--capture-mobile-workshop") or OS.get_cmdline_user_args().has("--capture-mobile-workshop") \
			or OS.get_cmdline_args().has("--capture-mobile-help") or OS.get_cmdline_user_args().has("--capture-mobile-help") \
			or OS.get_cmdline_args().has("--capture-mobile-options") or OS.get_cmdline_user_args().has("--capture-mobile-options") \
			or OS.get_cmdline_args().has("--capture-mobile-failed") or OS.get_cmdline_user_args().has("--capture-mobile-failed"):
		return
	var embedded := false
	if Engine.has_method("is_embedded_in_editor"):
		embedded = bool(Engine.call("is_embedded_in_editor"))
	if embedded:
		push_warning("[Riftline] Mobile preview is EMBEDDED in the editor Game view — window size cannot match the phone. Disable Embed Game (project_metadata embed_on_play=false / Editor game_embed_mode=Disabled) and press F5 again.")
	var target := preview_window_size()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(target)
	var screen := DisplayServer.window_get_current_screen()
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var pos := Vector2i(
		usable.position.x + maxi(0, (usable.size.x - target.x) / 2),
		usable.position.y + maxi(0, (usable.size.y - target.y) / 2)
	)
	DisplayServer.window_set_position(pos)
	DisplayServer.window_set_title("RIFTLINE: LAST TRAIN — Mobile Preview (%dx%d · phone %dx%d)" % [
		target.x, target.y, DEVICE_LANDSCAPE_W, DEVICE_LANDSCAPE_H
	])


## Returns a diagnostics dictionary and prints/logs verification lines.
static func verify_preview_geometry(viewport_size: Vector2, canvas_scale: float, canvas_offset: Vector2) -> Dictionary:
	var win: Vector2i = DisplayServer.window_get_size()
	var win_mode := DisplayServer.window_get_mode()
	var embedded := false
	if Engine.has_method("is_embedded_in_editor"):
		embedded = bool(Engine.call("is_embedded_in_editor"))
	var aspect := 0.0
	if win.y > 0:
		aspect = float(win.x) / float(win.y)
	var content_w := DESIGN_CONTENT_W(canvas_scale)
	var content_h := DESIGN_CONTENT_H(canvas_scale)
	var info := {
		"embedded": embedded,
		"window": win,
		"viewport": viewport_size,
		"content_rect": Rect2(canvas_offset, Vector2(content_w, content_h)),
		"canvas_scale": canvas_scale,
		"window_aspect": aspect,
		"target_aspect": PREVIEW_ASPECT,
		"phone_aspect": DEVICE_ASPECT,
		"mobile_preview": is_mobile_preview(),
		"mobile_ui": wants_mobile_ui(),
		"window_mode": win_mode,
	}
	var line := "[Riftline] Preview geometry: embedded=%s window=%dx%d viewport=%.0fx%.0f content=%.0fx%.0f offset=(%.0f,%.0f) aspect=%.4f (target=%.4f phone=%.4f) mobile_ui=%s" % [
		str(embedded),
		win.x, win.y,
		viewport_size.x, viewport_size.y,
		content_w, content_h,
		canvas_offset.x, canvas_offset.y,
		aspect,
		PREVIEW_ASPECT,
		DEVICE_ASPECT,
		str(wants_mobile_ui()),
	]
	print(line)
	var target_sz := preview_window_size()
	if not embedded and (win.x != target_sz.x or win.y != target_sz.y):
		push_warning("[Riftline] Window client %dx%d != target %dx%d — re-applying size." % [
			win.x, win.y, target_sz.x, target_sz.y
		])
		apply_preview_window_if_needed()
	_write_preview_log(info, line)
	return info


static func DESIGN_CONTENT_W(canvas_scale: float) -> float:
	return 1920.0 * canvas_scale


static func DESIGN_CONTENT_H(canvas_scale: float) -> float:
	return 1080.0 * canvas_scale


static func _write_preview_log(info: Dictionary, line: String) -> void:
	var path := "user://mobile_preview_geometry.log"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(line + "\n")
	f.store_string(JSON.stringify(info, "\t") + "\n")
	f.close()
	# Also mirror beside project for easy inspection from the repo.
	var proj_path := "res://dev_captures/mobile_preview/geometry_last.txt"
	var abs_dir := ProjectSettings.globalize_path("res://dev_captures/mobile_preview")
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var pf := FileAccess.open(proj_path, FileAccess.WRITE)
	if pf:
		pf.store_string(line + "\n")
		pf.store_string("window=%s viewport=%s content=%s aspect=%.6f embedded=%s\n" % [
			str(info.get("window")), str(info.get("viewport")), str(info.get("content_rect")),
			float(info.get("window_aspect", 0.0)), str(info.get("embedded"))
		])
		pf.close()


## Safe-area insets in design pixels (1920×1080).
## viewport_size must be get_viewport_rect().size (not window pixels) so EXPAND mode stays correct.
## On Windows mobile-preview, inject the measured phone landscape cutout/system bars.
static func design_safe_insets(design_w: float, design_h: float, canvas_scale: float, canvas_offset: Vector2, viewport_size: Vector2 = Vector2.ZERO) -> Dictionary:
	var out := { "left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0 }
	if canvas_scale <= 0.001:
		return out
	var vp: Vector2 = viewport_size
	if vp.x <= 1.0 or vp.y <= 1.0:
		var win_i := DisplayServer.window_get_size()
		vp = Vector2(win_i)
	if vp.x <= 1.0 or vp.y <= 1.0:
		return out

	var left_px := 0.0
	var top_px := 0.0
	var right_px := 0.0
	var bottom_px := 0.0

	if is_mobile_preview() and not (OS.has_feature("android") or OS.has_feature("ios")):
		# Map phone cutouts into the same coordinate space as the expanded viewport.
		var sx := vp.x / float(DEVICE_LANDSCAPE_W)
		left_px = float(DEVICE_CUTOUT_LEFT_PX) * sx
		right_px = float(DEVICE_SYSTEM_RIGHT_PX) * sx
		top_px = 0.0
		bottom_px = 0.0
	else:
		var win_i2 := DisplayServer.window_get_size()
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		# Scale window-space safe area into viewport space when they differ (stretch/expand).
		var wx := float(maxi(1, win_i2.x))
		var wy := float(maxi(1, win_i2.y))
		var vx_scale := vp.x / wx
		var vy_scale := vp.y / wy
		left_px = float(maxi(0, safe.position.x)) * vx_scale
		top_px = float(maxi(0, safe.position.y)) * vy_scale
		right_px = float(maxi(0, win_i2.x - (safe.position.x + safe.size.x))) * vx_scale
		bottom_px = float(maxi(0, win_i2.y - (safe.position.y + safe.size.y))) * vy_scale

	var canvas_left := canvas_offset.x
	var canvas_top := canvas_offset.y
	var canvas_right := canvas_offset.x + design_w * canvas_scale
	var canvas_bottom := canvas_offset.y + design_h * canvas_scale
	out["left"] = maxf(0.0, (left_px - canvas_left) / canvas_scale)
	out["top"] = maxf(0.0, (top_px - canvas_top) / canvas_scale)
	out["right"] = maxf(0.0, (canvas_right - (vp.x - right_px)) / canvas_scale)
	out["bottom"] = maxf(0.0, (canvas_bottom - (vp.y - bottom_px)) / canvas_scale)
	out["left"] = maxf(out["left"], 12.0)
	out["right"] = maxf(out["right"], 12.0)
	out["top"] = maxf(out["top"], 8.0)
	out["bottom"] = maxf(out["bottom"], 18.0)
	return out


static func touch_pad() -> float:
	return 10.0


static func min_touch() -> float:
	return 48.0
