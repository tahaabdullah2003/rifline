extends RefCounted
class_name MobileHudLayout
## Reusable responsive mobile HUD geometry (design-space, 1920×1080).
## Drawing + hit-testing must share the same authoritative Rect2 from these helpers.
## Desktop callers should not use this — mobile / F5 preview only.

const DESIGN_W := 1920.0
const DESIGN_H := 1080.0

## F5 mobile preview client width — REF_WIN_* sizes are authored against this.
## Real phones (e.g. 1640×720) must keep the same *screen fraction*, not the same raw px.
const PREVIEW_REF_WIN_W := 1230.0
## Extra global boost so touch HUD reads larger than the old compact authoring.
const HUD_SIZE_BOOST := 1.32

## Empty-interior dual-section shell (Downloads SVG embed → PNG).
## Source: assets/ui/hud/riftline_dual_section_hud_panel_empty_interior.svg — 2048×682.
const STATUS_TEX_W := 2048.0
const STATUS_TEX_H := 682.0
const STATUS_ASPECT := STATUS_TEX_W / STATUS_TEX_H ## ≈ 3.0029

## Width guideline: ~18–25% of usable landscape width (viewport-relative).
const STATUS_WIDTH_FRAC_MIN := 0.18
const STATUS_WIDTH_FRAC_MAX := 0.25
const STATUS_WIDTH_FRAC_PREF := 0.21
## Flush to screen-left. Top uses art-lift so solid brass kisses the bezel.
const STATUS_REF_WIN_X := 0.0
const STATUS_REF_WIN_Y := 0.0
const STATUS_TOP_GAP_FRAC := 0.0
const STATUS_TOP_GAP_WIN_MIN := 0.0
const STATUS_TOP_GAP_WIN_MAX := 0.0
const STATUS_REF_WIN_W := 275.0
## Transparent / thin tip above the solid brass band (~y 0–114 / 682).
## Under-lifting this left a visible air gap under the window top.
const STATUS_ART_PAD_TOP_FRAC := 0.167
const STATUS_MIN_W := 380.0
const STATUS_MAX_W := 640.0
const STATUS_MIN_H := 120.0
const STATUS_MAX_H := 230.0
const STATUS_MIN_LABEL_PX := 15.0
## Floor for mobile HUD type — below this, labels are unreadable on phone-density screens.
const READABLE_LABEL_MIN_PX := 14.0


static func safe_rect(design_w: float, design_h: float, inset: Dictionary) -> Rect2:
	var l: float = float(inset.get("left", 12.0))
	var t: float = float(inset.get("top", 8.0))
	var r: float = float(inset.get("right", 12.0))
	var b: float = float(inset.get("bottom", 18.0))
	return Rect2(l, t, maxf(1.0, design_w - l - r), maxf(1.0, design_h - t - b))


static func aspect_size(aspect: float, width: float = -1.0, height: float = -1.0) -> Vector2:
	if width > 0.0:
		return Vector2(width, width / maxf(0.001, aspect))
	if height > 0.0:
		return Vector2(height * aspect, height)
	return Vector2.ZERO


static func clamp_size(sz: Vector2, min_s: Vector2, max_s: Vector2, aspect: float) -> Vector2:
	var w: float = clampf(sz.x, min_s.x, max_s.x)
	var h: float = w / maxf(0.001, aspect)
	if h < min_s.y:
		h = min_s.y
		w = h * aspect
	if h > max_s.y:
		h = max_s.y
		w = h * aspect
	w = clampf(w, min_s.x, max_s.x)
	h = w / maxf(0.001, aspect)
	return Vector2(w, h)


static func texture_dest_rect(panel: Rect2, tex_aspect: float) -> Rect2:
	var panel_aspect: float = panel.size.x / maxf(0.001, panel.size.y)
	if absf(panel_aspect - tex_aspect) < 0.01:
		return panel
	if panel_aspect > tex_aspect:
		var h: float = panel.size.y
		var w: float = h * tex_aspect
		return Rect2(panel.position.x + (panel.size.x - w) * 0.5, panel.position.y, w, h)
	var w2: float = panel.size.x
	var h2: float = w2 / tex_aspect
	return Rect2(panel.position.x, panel.position.y + (panel.size.y - h2) * 0.5, w2, h2)


static func text_size_for_panel(panel_h: float, base: float = 18.0, min_px: float = STATUS_MIN_LABEL_PX, max_px: float = 32.0) -> float:
	var t: float = base * (panel_h / 190.0)
	return clampf(t, maxf(min_px, READABLE_LABEL_MIN_PX), max_px)


static func screen_to_design(screen_pos: Vector2, canvas_offset: Vector2, canvas_scale: float) -> Vector2:
	return (screen_pos - canvas_offset) / maxf(0.001, canvas_scale)


static func design_to_screen(design_pos: Vector2, canvas_offset: Vector2, canvas_scale: float) -> Vector2:
	return canvas_offset + design_pos * canvas_scale


static func hit_test(panel: Rect2, design_pos: Vector2) -> bool:
	return panel.has_point(design_pos)


static func _win_to_design_px(win_px: float, window_size: Vector2i, viewport_size: Vector2, canvas_scale: float) -> float:
	var wx: float = maxf(1.0, float(window_size.x))
	var vx: float = maxf(1.0, viewport_size.x)
	# Same fraction of screen as the 1230-wide preview, then apply touch boost.
	var scaled_win_px: float = win_px * (wx / PREVIEW_REF_WIN_W) * HUD_SIZE_BOOST
	return (scaled_win_px * (vx / wx)) / maxf(0.001, canvas_scale)


## Dual-section cavities measured from empty-interior PNG alpha (2048×682).
## Upper opening ≈ x[0.120..0.881] y[0.290..0.500]; lower-left ≈ [0.095..0.425]×[0.600..0.777];
## lower-right ≈ [0.598..0.924]×[0.600..0.777].
static func dual_section_regions(panel: Rect2) -> Dictionary:
	var p := panel
	# Full upper cavity glass/fill; SHD is a quiet right-side stamp only (no chip).
	var hp := Rect2(
		p.position.x + p.size.x * 0.120,
		p.position.y + p.size.y * 0.290,
		p.size.x * 0.761,
		p.size.y * 0.210
	)
	var spd := Rect2(
		p.position.x + p.size.x * 0.095,
		p.position.y + p.size.y * 0.600,
		p.size.x * 0.330,
		p.size.y * 0.177
	)
	var heat := Rect2(
		p.position.x + p.size.x * 0.598,
		p.position.y + p.size.y * 0.600,
		p.size.x * 0.326,
		p.size.y * 0.177
	)
	var shd := Rect2(
		p.position.x + p.size.x * 0.72,
		p.position.y + p.size.y * 0.310,
		p.size.x * 0.145,
		p.size.y * 0.170
	)
	return { "hp": hp, "spd": spd, "heat": heat, "shield": shd }


## Authoritative top-left player status panel in design space.
## Flush to visible design-view left; art-lifted so brass sits on the screen top.
static func player_status_panel(
	safe_inset: Dictionary,
	view_left: float,
	view_right: float,
	view_top: float,
	view_aspect: float,
	canvas_scale: float,
	window_size: Vector2i,
	viewport_size: Vector2
) -> Dictionary:
	# Left: always flush to the visible screen/view edge (no aesthetic left pad).
	var pad_x: float = 0.0
	# Top: no aesthetic gap — transparent PNG pad is compensated via art-lift.
	var pad_y: float = 0.0
	var usable_w: float = maxf(1.0, view_right - view_left)
	var ref_w: float = _win_to_design_px(STATUS_REF_WIN_W, window_size, viewport_size, canvas_scale)
	var frac: float = STATUS_WIDTH_FRAC_PREF
	if view_aspect > 0.01:
		if view_aspect < 1.85:
			frac = STATUS_WIDTH_FRAC_MAX
		elif view_aspect > 2.25:
			frac = STATUS_WIDTH_FRAC_MIN
		else:
			frac = lerpf(STATUS_WIDTH_FRAC_MAX, STATUS_WIDTH_FRAC_MIN, (view_aspect - 1.85) / 0.40)
	var frac_w: float = usable_w * frac
	var target_w: float = lerpf(ref_w, frac_w, 0.35)
	var sz: Vector2 = aspect_size(STATUS_ASPECT, target_w, -1.0)
	sz = clamp_size(
		sz,
		Vector2(STATUS_MIN_W, STATUS_MIN_H),
		Vector2(STATUS_MAX_W, STATUS_MAX_H),
		STATUS_ASPECT
	)
	var x: float = view_left + pad_x
	# Keep a gap before the design-space center so we don't crowd the mission banner.
	# Constrain THIS panel only — do not relocate other top HUD groups.
	var right_limit: float = minf(DESIGN_W * 0.355, view_right - 80.0)
	if x + sz.x > right_limit:
		var fit_w: float = maxf(STATUS_MIN_W * 0.85, right_limit - x)
		sz = aspect_size(STATUS_ASPECT, fit_w, -1.0)
		sz = clamp_size(sz, Vector2(STATUS_MIN_W * 0.85, STATUS_MIN_H * 0.85),
			Vector2(STATUS_MAX_W, STATUS_MAX_H), STATUS_ASPECT)
	# Pull texture up by transparent top pad so visible brass kisses the bezel.
	var art_lift: float = sz.y * STATUS_ART_PAD_TOP_FRAC
	var y: float = view_top + pad_y - art_lift
	var panel := Rect2(x, y, sz.x, sz.y)
	# Left + top align the texture inside the panel (never horizontally centered).
	var tex_r := Rect2(panel.position, aspect_size(STATUS_ASPECT, panel.size.x, -1.0))
	if tex_r.size.y > panel.size.y:
		tex_r.size = aspect_size(STATUS_ASPECT, -1.0, panel.size.y)
		tex_r.position = Vector2(panel.position.x, panel.position.y)
	var regions: Dictionary = dual_section_regions(tex_r)
	return {
		"panel": panel,
		"texture_rect": tex_r,
		"aspect": STATUS_ASPECT,
		"label_px": text_size_for_panel(tex_r.size.y),
		"hp": regions["hp"],
		"spd": regions["spd"],
		"heat": regions["heat"],
		"shield": regions["shield"],
		"width_frac": tex_r.size.x / usable_w,
		"usable_w": usable_w,
		"view_aspect": view_aspect,
		"anchor_pad": Vector2(pad_x, pad_y),
	}


static func overlaps(a: Rect2, b: Rect2) -> bool:
	return a.intersects(b)


## Long open encounter frame (Downloads SVG embed → original PNG).
## Source: assets/ui/hud/riftline_long_hud_frame_open.svg — 2048×682.
## Opaque recessed navy bay with cyan inner lips; no punch/derivative.
## Runtime layers: SVG frame → clipped progress → text (inside bay).
const ENCOUNTER_TEX_W := 2048.0
const ENCOUNTER_TEX_H := 682.0
const ENCOUNTER_ASPECT := ENCOUNTER_TEX_W / ENCOUNTER_TEX_H ## ≈ 3.0029
## Longer bar — authored @ 1230×540; scaled by HUD_SIZE_BOOST + screen fraction.
const ENCOUNTER_REF_WIN_W := 490.0
## Flush to screen top (0 client px). Kept for report/compat; not used as a gap.
const ENCOUNTER_REF_WIN_Y := 0.0
## Transparent pad in the source PNG above the visible brass (measured opaque bbox).
const ENCOUNTER_ART_PAD_TOP_FRAC := 0.123
const ENCOUNTER_MIN_W := 640.0
const ENCOUNTER_MAX_W := 1050.0
const ENCOUNTER_MIN_H := 200.0
const ENCOUNTER_MAX_H := 350.0
## Gap from neighboring top HUD panels (design px).
const ENCOUNTER_NEIGHBOR_GAP := 8.0


## Inner display bounds for live text/progress (inside cyan-outlined open bay).
## Slightly taller/wider usable bay for non-overlapping title → meta → bar.
static func encounter_content_region(panel: Rect2) -> Rect2:
	var p := panel
	return Rect2(
		p.position.x + p.size.x * 0.170,
		p.position.y + p.size.y * 0.300,
		p.size.x * 0.660,
		p.size.y * 0.380
	)


## Top Y in design px — flush to the visible screen/view top (no aesthetic gap).
static func encounter_top_margin(
	_safe_inset: Dictionary,
	view_top: float,
	_canvas_scale: float,
	_window_size: Vector2i,
	_viewport_size: Vector2
) -> float:
	return maxf(0.0, view_top)


## Authoritative top-center encounter / mission panel in design space.
## Flush to screen top; width scales with viewport; neighbor-aware.
static func encounter_panel(
	safe_inset: Dictionary,
	view_left: float,
	view_right: float,
	view_top: float,
	view_aspect: float,
	canvas_scale: float,
	window_size: Vector2i,
	viewport_size: Vector2,
	status_tex: Rect2 = Rect2(),
	scrap_tex: Rect2 = Rect2()
) -> Dictionary:
	var y: float = encounter_top_margin(safe_inset, view_top, canvas_scale, window_size, viewport_size)
	var usable_w: float = maxf(1.0, view_right - view_left)
	var ref_w: float = _win_to_design_px(ENCOUNTER_REF_WIN_W, window_size, viewport_size, canvas_scale)
	# Long frame: prefer more width so meta line stays readable.
	var frac: float = 0.32
	if view_aspect > 0.01:
		if view_aspect < 1.85:
			frac = 0.36
		elif view_aspect > 2.25:
			frac = 0.29
		else:
			frac = lerpf(0.36, 0.29, (view_aspect - 1.85) / 0.40)
	var target_w: float = lerpf(ref_w, usable_w * frac, 0.55)
	var sz: Vector2 = aspect_size(ENCOUNTER_ASPECT, target_w, -1.0)
	sz = clamp_size(
		sz,
		Vector2(ENCOUNTER_MIN_W, ENCOUNTER_MIN_H),
		Vector2(ENCOUNTER_MAX_W, ENCOUNTER_MAX_H),
		ENCOUNTER_ASPECT
	)
	var mid_x: float = (view_left + view_right) * 0.5
	var x: float = mid_x - sz.x * 0.5
	# Shrink / re-center if we collide with left status or right scrap shells.
	var left_limit: float = view_left + 40.0
	var right_limit: float = view_right - 40.0
	if status_tex.size.x > 1.0:
		left_limit = maxf(left_limit, status_tex.position.x + status_tex.size.x + ENCOUNTER_NEIGHBOR_GAP)
	if scrap_tex.size.x > 1.0:
		right_limit = minf(right_limit, scrap_tex.position.x - ENCOUNTER_NEIGHBOR_GAP)
	var avail: float = right_limit - left_limit
	if avail > 80.0 and sz.x > avail:
		sz = aspect_size(ENCOUNTER_ASPECT, avail, -1.0)
		sz = clamp_size(sz, Vector2(ENCOUNTER_MIN_W * 0.75, ENCOUNTER_MIN_H * 0.75),
			Vector2(ENCOUNTER_MAX_W, ENCOUNTER_MAX_H), ENCOUNTER_ASPECT)
	x = clampf(mid_x - sz.x * 0.5, left_limit, maxf(left_limit, right_limit - sz.x))
	# Pull the texture up by its transparent top pad so visible brass kisses the bezel.
	var art_lift: float = sz.y * ENCOUNTER_ART_PAD_TOP_FRAC
	var panel := Rect2(x, y - art_lift, sz.x, sz.y)
	# Keep the decorative texture top-aligned inside the panel (never vertically centered).
	var tex_r := Rect2(panel.position, aspect_size(ENCOUNTER_ASPECT, panel.size.x, -1.0))
	if tex_r.size.y > panel.size.y:
		tex_r.size = aspect_size(ENCOUNTER_ASPECT, -1.0, panel.size.y)
		tex_r.position.x = panel.position.x + (panel.size.x - tex_r.size.x) * 0.5
		tex_r.position.y = panel.position.y
	var content: Rect2 = encounter_content_region(tex_r)
	var conflict := ""
	if status_tex.size.x > 1.0 and overlaps(tex_r, status_tex):
		conflict = "ENCOUNTER_OVERLAPS_STATUS"
	if scrap_tex.size.x > 1.0 and overlaps(tex_r, scrap_tex):
		conflict = "ENCOUNTER_OVERLAPS_SCRAP" if conflict == "" else conflict + "+SCRAP"
	# Visible top (opaque brass) after art-lift — should be ~view_top.
	var visible_top: float = tex_r.position.y + tex_r.size.y * ENCOUNTER_ART_PAD_TOP_FRAC
	return {
		"panel": panel,
		"texture_rect": tex_r,
		"content": content,
		"aspect": ENCOUNTER_ASPECT,
		"width_frac": tex_r.size.x / usable_w,
		"usable_w": usable_w,
		"view_aspect": view_aspect,
		"top_margin": visible_top - view_top,
		"conflict": conflict,
		"compact_meta": tex_r.size.x < ENCOUNTER_MIN_W * 0.95,
	}


## Wide economy / scrap bar (Downloads SVG embed → original opaque PNG).
## Source: assets/ui/hud/riftline_wide_hud_bar_a.svg — 2048×682.
## Compartments (measured dark wells): emblem · scrap · LV badge · XP.
## Runtime: SVG frame → clipped XP fill → icon/text. Pause/speed stay outside to the right.
const ECONOMY_TEX_W := 2048.0
const ECONOMY_TEX_H := 682.0
const ECONOMY_ASPECT := ECONOMY_TEX_W / ECONOMY_TEX_H ## ≈ 3.0029
## Economy strip — larger for readable scrap/XP on phone.
const ECONOMY_REF_WIN_W := 340.0
## Small top nudge in window/client px so the bar sits just under the bezel.
const ECONOMY_REF_WIN_Y := 10.0
## Transparent pad above visible brass in the source PNG.
const ECONOMY_ART_PAD_TOP_FRAC := 0.213
const ECONOMY_MIN_W := 560.0
const ECONOMY_MAX_W := 860.0
const ECONOMY_MIN_H := 180.0
const ECONOMY_MAX_H := 290.0
## Pause / speed strip reserved on the far right (window/client px → design).
const ECONOMY_PAUSE_WIN := 48.0
const ECONOMY_PAUSE_GAP_WIN := 10.0
const ECONOMY_ENCOUNTER_GAP := 10.0


## Compartment wells as fractions of the texture rect (opaque bay interiors).
static func economy_regions(panel: Rect2) -> Dictionary:
	var p := panel
	return {
		# Cyan bezel center tuned from 1230 capture (gear on top of solid frame).
		"emblem": Rect2(
			p.position.x + p.size.x * 0.0460,
			p.position.y + p.size.y * 0.3320,
			p.size.x * 0.1192,
			p.size.y * 0.3579
		),
		"scrap": Rect2(
			p.position.x + p.size.x * 0.205,
			p.position.y + p.size.y * 0.340,
			p.size.x * 0.335,
			p.size.y * 0.320
		),
		"level": Rect2(
			p.position.x + p.size.x * 0.585,
			p.position.y + p.size.y * 0.330,
			p.size.x * 0.090,
			p.size.y * 0.340
		),
		# XP well measured on texture ≈ x 0.700–0.955, y 0.330–0.635 (full bay height).
		"xp": Rect2(
			p.position.x + p.size.x * 0.708,
			p.position.y + p.size.y * 0.345,
			p.size.x * 0.242,
			p.size.y * 0.300
		),
	}


## Authoritative top-right scrap / level / XP panel in design space.
## Flush to screen top (art-lifted); right edge leaves a pause/speed reserve.
static func economy_panel(
	safe_inset: Dictionary,
	view_left: float,
	view_right: float,
	view_top: float,
	view_aspect: float,
	canvas_scale: float,
	window_size: Vector2i,
	viewport_size: Vector2,
	encounter_tex: Rect2 = Rect2(),
	status_tex: Rect2 = Rect2()
) -> Dictionary:
	var inset_r: float = float(safe_inset.get("right", 0.0))
	var pause_w: float = _win_to_design_px(ECONOMY_PAUSE_WIN, window_size, viewport_size, canvas_scale)
	var pause_gap: float = _win_to_design_px(ECONOMY_PAUSE_GAP_WIN, window_size, viewport_size, canvas_scale)
	# Far-right strip for pause + speed hitboxes — never covered by the economy shell.
	var right_limit: float = view_right - maxf(0.0, inset_r) - pause_w - pause_gap
	var usable_w: float = maxf(1.0, view_right - view_left)
	var ref_w: float = _win_to_design_px(ECONOMY_REF_WIN_W, window_size, viewport_size, canvas_scale)
	var frac: float = 0.26
	if view_aspect > 0.01:
		if view_aspect < 1.85:
			frac = 0.30
		elif view_aspect > 2.25:
			frac = 0.24
		else:
			frac = lerpf(0.30, 0.24, (view_aspect - 1.85) / 0.40)
	var target_w: float = lerpf(ref_w, usable_w * frac, 0.42)
	var sz: Vector2 = aspect_size(ECONOMY_ASPECT, target_w, -1.0)
	sz = clamp_size(
		sz,
		Vector2(ECONOMY_MIN_W, ECONOMY_MIN_H),
		Vector2(ECONOMY_MAX_W, ECONOMY_MAX_H),
		ECONOMY_ASPECT
	)
	# Left bound: clear the encounter (and status) with a neighbor gap.
	var left_limit: float = view_left + 40.0
	if status_tex.size.x > 1.0:
		left_limit = maxf(left_limit, status_tex.position.x + status_tex.size.x * 0.15)
	if encounter_tex.size.x > 1.0:
		left_limit = maxf(left_limit, encounter_tex.position.x + encounter_tex.size.x + ECONOMY_ENCOUNTER_GAP)
	var avail: float = right_limit - left_limit
	if avail > 80.0 and sz.x > avail:
		sz = aspect_size(ECONOMY_ASPECT, avail, -1.0)
		sz = clamp_size(sz, Vector2(ECONOMY_MIN_W * 0.70, ECONOMY_MIN_H * 0.70),
			Vector2(ECONOMY_MAX_W, ECONOMY_MAX_H), ECONOMY_ASPECT)
	var x: float = right_limit - sz.x
	x = maxf(x, left_limit)
	var top_nudge: float = _win_to_design_px(ECONOMY_REF_WIN_Y, window_size, viewport_size, canvas_scale)
	var y: float = maxf(0.0, view_top) + top_nudge
	var art_lift: float = sz.y * ECONOMY_ART_PAD_TOP_FRAC
	var panel := Rect2(x, y - art_lift, sz.x, sz.y)
	var tex_r := Rect2(panel.position, aspect_size(ECONOMY_ASPECT, panel.size.x, -1.0))
	if tex_r.size.y > panel.size.y:
		tex_r.size = aspect_size(ECONOMY_ASPECT, -1.0, panel.size.y)
		tex_r.position = Vector2(panel.position.x + (panel.size.x - tex_r.size.x), panel.position.y)
	var regions: Dictionary = economy_regions(tex_r)
	var conflict := ""
	if encounter_tex.size.x > 1.0 and overlaps(tex_r, encounter_tex):
		conflict = "ECONOMY_OVERLAPS_ENCOUNTER"
	var pause_x: float = tex_r.position.x + tex_r.size.x + pause_gap
	return {
		"panel": panel,
		"texture_rect": tex_r,
		"emblem": regions["emblem"],
		"scrap": regions["scrap"],
		"level": regions["level"],
		"xp": regions["xp"],
		"aspect": ECONOMY_ASPECT,
		"width_frac": tex_r.size.x / usable_w,
		"usable_w": usable_w,
		"view_aspect": view_aspect,
		"pause_x": pause_x,
		"pause_s": pause_w,
		"pause_gap": pause_gap,
		"conflict": conflict,
		"compact": tex_r.size.x < ECONOMY_MIN_W * 0.92,
	}


## Vertical SHOP edge tab (Downloads SVG embed → PNG).
## Source: assets/ui/hud/riftline_vertical_hud_frame.svg — 682×2048.
## Tall narrow brass/cyan frame; sticks to the safe right edge.
const SHOP_TEX_W := 682.0
const SHOP_TEX_H := 2048.0
const SHOP_ASPECT := SHOP_TEX_W / SHOP_TEX_H ## ≈ 0.3330
## Compact vertical SHOP tab @ 1230×540 — slim edge handle, slightly roomy for SHOP type.
const SHOP_REF_WIN_W := 62.0
const SHOP_MIN_WIN_W := 56.0
const SHOP_MAX_WIN_W := 70.0
## Transparent pads in the source PNG (measured opaque bbox).
const SHOP_ART_PAD_L := 0.218
const SHOP_ART_PAD_R := 0.221
const SHOP_ART_PAD_T := 0.085
const SHOP_ART_PAD_B := 0.073
## True dark letter bay between inner brass/cyan rails (luminance profile @ mid height).
const SHOP_WELL_L := 0.430
const SHOP_WELL_R := 0.310
## Keep clear of top economy / pause strip.
const SHOP_TOP_CLEAR_WIN := 100.0
const SHOP_BOTTOM_CLEAR_WIN := 130.0


## Authoritative mid-right SHOP tab. Flush to the safe right edge; vertical band
## between the top HUD rail and the bottom ability/weapon strips.
static func shop_tab_panel(
	safe_inset: Dictionary,
	view_left: float,
	view_right: float,
	view_top: float,
	view_bottom: float,
	canvas_scale: float,
	window_size: Vector2i,
	viewport_size: Vector2,
	economy_tex: Rect2 = Rect2(),
	pause_rect: Rect2 = Rect2()
) -> Dictionary:
	var inset_b: float = float(safe_inset.get("bottom", 0.0))
	# Stick to the absolute right of the visible gameplay view; transparent
	# art pad already clears gesture nav. Do not leave a floating mid-gap.
	var right_limit: float = view_right
	var win_w: float = clampf(SHOP_REF_WIN_W, SHOP_MIN_WIN_W, SHOP_MAX_WIN_W)
	# Scale slightly with ultra-wide / short phones.
	var view_aspect: float = (view_right - view_left) / maxf(1.0, view_bottom - view_top)
	if view_aspect > 2.25:
		win_w = minf(win_w + 2.0, SHOP_MAX_WIN_W)
	elif view_aspect < 1.90:
		win_w = maxf(win_w - 2.0, SHOP_MIN_WIN_W)
	var tex_w: float = _win_to_design_px(win_w, window_size, viewport_size, canvas_scale)
	var sz: Vector2 = aspect_size(SHOP_ASPECT, tex_w, -1.0)
	# Vertical band: below top HUD / pause, above bottom strips.
	var top_clear: float = _win_to_design_px(SHOP_TOP_CLEAR_WIN, window_size, viewport_size, canvas_scale)
	var bot_clear: float = _win_to_design_px(SHOP_BOTTOM_CLEAR_WIN, window_size, viewport_size, canvas_scale)
	var band_top: float = view_top + top_clear
	var band_bot: float = view_bottom - maxf(0.0, inset_b) - bot_clear
	if economy_tex.size.x > 1.0:
		band_top = maxf(band_top, economy_tex.position.y + economy_tex.size.y + 8.0)
	if pause_rect.size.x > 1.0:
		band_top = maxf(band_top, pause_rect.position.y + pause_rect.size.y + 8.0)
	var band_h: float = maxf(sz.y, band_bot - band_top)
	# Cap height so the tab stays a short mid-right handle (~half of the open band).
	var max_h: float = minf(band_h * 0.50, _win_to_design_px(185.0, window_size, viewport_size, canvas_scale))
	if sz.y > max_h and max_h > 80.0:
		sz = aspect_size(SHOP_ASPECT, -1.0, max_h)
	# Pull opaque right edge flush to the screen (compensate transparent right pad).
	var x: float = right_limit - sz.x * (1.0 - SHOP_ART_PAD_R)
	var y: float = band_top + maxf(0.0, (band_bot - band_top - sz.y) * 0.50)
	# Nudge up by top transparent pad so visible brass sits in the band.
	y -= sz.y * SHOP_ART_PAD_T * 0.35
	var tex_r := Rect2(x, y, sz.x, sz.y)
	# Hitbox: slightly wider leftward for 48dp touch, still clear of pause/economy.
	var hit_pad_l: float = _win_to_design_px(10.0, window_size, viewport_size, canvas_scale)
	var hit := Rect2(
		tex_r.position.x - hit_pad_l,
		tex_r.position.y + tex_r.size.y * SHOP_ART_PAD_T * 0.5,
		tex_r.size.x + hit_pad_l - tex_r.size.x * SHOP_ART_PAD_R * 0.25,
		tex_r.size.y * (1.0 - SHOP_ART_PAD_T * 0.5 - SHOP_ART_PAD_B * 0.5)
	)
	# Letter column: stay inside the dark bay, clear of top/bottom brass rails.
	var well_x: float = tex_r.position.x + tex_r.size.x * SHOP_WELL_L
	var well_w: float = tex_r.size.x * (1.0 - SHOP_WELL_L - SHOP_WELL_R)
	var side_pad: float = well_w * 0.08
	var content := Rect2(
		well_x + side_pad,
		tex_r.position.y + tex_r.size.y * (SHOP_ART_PAD_T + 0.18),
		maxf(8.0, well_w - side_pad * 2.0),
		tex_r.size.y * (1.0 - SHOP_ART_PAD_T - SHOP_ART_PAD_B - 0.36)
	)
	return {
		"texture_rect": tex_r,
		"hit": hit,
		"content": content,
		"aspect": SHOP_ASPECT,
		"view_aspect": view_aspect,
		"right_limit": right_limit,
		"band_top": band_top,
		"band_bot": band_bot,
	}


## Compact reactor console (Downloads SVG embed → PNG).
## Source: assets/ui/hud/riftline_compact_hud_bar.svg — 1448×1086.
## Left: glowing cyan reactor cylinder. Right: 4-row brass control panel.
const REACTOR_TEX_W := 1448.0
const REACTOR_TEX_H := 1086.0
const REACTOR_ASPECT := REACTOR_TEX_W / REACTOR_TEX_H ## ≈ 1.3333
## Compact bottom-left console @ 1230×540 — keep small so combat stays visible.
const REACTOR_REF_WIN_W := 270.0
const REACTOR_MIN_WIN_W := 230.0
const REACTOR_MAX_WIN_W := 310.0
## Transparent pads from opaque alpha bbox.
const REACTOR_ART_PAD_L := 0.0262
const REACTOR_ART_PAD_R := 0.0290
const REACTOR_ART_PAD_T := 0.1823
const REACTOR_ART_PAD_B := 0.1593
## Control-bay content (inside navy panel; clears brass rails / cylinder).
const REACTOR_CONTENT_X0 := 0.388
const REACTOR_CONTENT_X1 := 0.935
const REACTOR_CONTENT_Y0 := 0.318
const REACTOR_CONTENT_Y1 := 0.755
## Header is the top slice of the content bay; rows share the rest equally.
const REACTOR_HEADER_FRAC := 0.20
## Flush to bottom safe edge (preview client px).
const REACTOR_BOT_MARGIN_WIN := 2.0
## Max visible channels per page — keeps row height touch-friendly.
const REACTOR_PAGE_SIZE := 3


## Authoritative bottom-left reactor console. Opaque brass flush to safe left;
## bottom margin clears the safe area; aspect locked to the SVG embed.
static func reactor_panel(
	safe_inset: Dictionary,
	view_left: float,
	view_right: float,
	view_top: float,
	view_bottom: float,
	view_aspect: float,
	canvas_scale: float,
	window_size: Vector2i,
	viewport_size: Vector2
) -> Dictionary:
	var inset_l: float = float(safe_inset.get("left", 0.0))
	var inset_b: float = float(safe_inset.get("bottom", 0.0))
	var usable_w: float = maxf(1.0, view_right - view_left)
	var ref_w: float = _win_to_design_px(REACTOR_REF_WIN_W, window_size, viewport_size, canvas_scale)
	var min_w: float = _win_to_design_px(REACTOR_MIN_WIN_W, window_size, viewport_size, canvas_scale)
	var max_w: float = _win_to_design_px(REACTOR_MAX_WIN_W, window_size, viewport_size, canvas_scale)
	# Keep reactor a modest corner console (~16–20% width).
	var frac: float = 0.18
	if view_aspect > 0.01:
		if view_aspect < 1.85:
			frac = 0.20
		elif view_aspect > 2.25:
			frac = 0.16
		else:
			frac = lerpf(0.20, 0.16, (view_aspect - 1.85) / 0.40)
	var target_w: float = lerpf(ref_w, usable_w * frac, 0.40)
	var sz: Vector2 = aspect_size(REACTOR_ASPECT, target_w, -1.0)
	sz = clamp_size(sz, Vector2(min_w, min_w / REACTOR_ASPECT), Vector2(max_w, max_w / REACTOR_ASPECT), REACTOR_ASPECT)
	# Hard height cap — sit in the bottom band, leave combat visible above.
	var max_h: float = maxf(140.0, (view_bottom - view_top) * 0.28)
	if sz.y > max_h:
		sz = aspect_size(REACTOR_ASPECT, -1.0, max_h)
		sz = clamp_size(sz, Vector2(min_w * 0.80, min_w * 0.80 / REACTOR_ASPECT),
			Vector2(max_w, max_w / REACTOR_ASPECT), REACTOR_ASPECT)
	var bot_m: float = _win_to_design_px(REACTOR_BOT_MARGIN_WIN, window_size, viewport_size, canvas_scale)
	bot_m = maxf(bot_m, inset_b * 0.15)
	# Opaque left flush to safe-left (compensate transparent pad). No extra gutter.
	var safe_l: float = view_left + maxf(0.0, inset_l)
	var x: float = safe_l - sz.x * REACTOR_ART_PAD_L
	# Pin opaque bottom to the safe bottom edge.
	var y: float = view_bottom - bot_m - sz.y * (1.0 - REACTOR_ART_PAD_B)
	var tex_r := Rect2(x, y, sz.x, sz.y)
	var hit := Rect2(
		tex_r.position.x + tex_r.size.x * REACTOR_ART_PAD_L * 0.35,
		tex_r.position.y + tex_r.size.y * REACTOR_ART_PAD_T * 0.55,
		tex_r.size.x * (1.0 - REACTOR_ART_PAD_L * 0.35 - REACTOR_ART_PAD_R * 0.35),
		tex_r.size.y * (1.0 - REACTOR_ART_PAD_T * 0.55 - REACTOR_ART_PAD_B * 0.45)
	)
	var content := Rect2(
		tex_r.position.x + tex_r.size.x * REACTOR_CONTENT_X0,
		tex_r.position.y + tex_r.size.y * REACTOR_CONTENT_Y0,
		tex_r.size.x * (REACTOR_CONTENT_X1 - REACTOR_CONTENT_X0),
		tex_r.size.y * (REACTOR_CONTENT_Y1 - REACTOR_CONTENT_Y0)
	)
	var header_h: float = content.size.y * REACTOR_HEADER_FRAC
	var header := Rect2(content.position.x, content.position.y, content.size.x, header_h)
	var rows_band := Rect2(
		content.position.x,
		content.position.y + header_h,
		content.size.x,
		maxf(8.0, content.size.y - header_h)
	)
	# Collapsed strip: left cylinder crop + readout, bottom-aligned.
	var col_h: float = maxf(52.0, sz.y * 0.16)
	var col_w: float = minf(sz.x * 0.72, maxf(220.0, usable_w * 0.18))
	var collapsed := Rect2(
		view_left + maxf(0.0, inset_l),
		view_bottom - bot_m - col_h,
		col_w,
		col_h
	)
	return {
		"texture_rect": tex_r,
		"hit": hit,
		"content": content,
		"header": header,
		"rows_band": rows_band,
		"collapsed": collapsed,
		"aspect": REACTOR_ASPECT,
		"view_aspect": view_aspect,
		"width_frac": tex_r.size.x / usable_w,
		"page_size": REACTOR_PAGE_SIZE,
		"bot_margin": bot_m,
	}


## Equal row rects inside the reactor rows band for the channels on this page.
static func reactor_row_rects(rows_band: Rect2, count: int) -> Array:
	var out: Array = []
	var n: int = maxi(0, count)
	if n <= 0 or rows_band.size.y < 1.0:
		return out
	# Tiny gap — brass rails already separate rows; more height = larger unclipped labels.
	var gap: float = 1.0
	var total_gap: float = gap * float(maxi(0, n - 1))
	var rh: float = maxf(20.0, (rows_band.size.y - total_gap) / float(n))
	for i in range(n):
		out.append(Rect2(
			rows_band.position.x,
			rows_band.position.y + float(i) * (rh + gap),
			rows_band.size.x,
			rh
		))
	return out


## Four-slot weapon priority console (Downloads SVG embed → PNG).
## Source: riftline_four_slot_hud_bar_transparent_slots.svg — 2048×682.
## Four brass compartments with transparent slot openings + cyan accents.
const WEAPONS_TEX_W := 2048.0
const WEAPONS_TEX_H := 682.0
const WEAPONS_ASPECT := WEAPONS_TEX_W / WEAPONS_TEX_H ## ≈ 3.0029
## Target visible width @ 1230×540 preview (client px).
const WEAPONS_REF_WIN_W := 355.0
const WEAPONS_MIN_WIN_W := 300.0
const WEAPONS_MAX_WIN_W := 380.0
const WEAPONS_ART_PAD_L := 0.0259
const WEAPONS_ART_PAD_R := 0.0259
const WEAPONS_ART_PAD_T := 0.1217
const WEAPONS_ART_PAD_B := 0.1290
## Measured dark navy wells (normalized to texture).
const WEAPONS_SLOT_X := [
	[0.126, 0.259],
	[0.335, 0.465],
	[0.537, 0.674],
	[0.737, 0.880],
]
## Transparent openings measured from PNG alpha (~y 0.30–0.63).
const WEAPONS_ICON_Y0 := 0.30
const WEAPONS_ICON_Y1 := 0.63
const WEAPONS_LABEL_Y0 := 0.66
const WEAPONS_LABEL_Y1 := 0.78
## Flush opaque brass to the screen bottom (no floating gap).
const WEAPONS_BOT_MARGIN_WIN := 0.0
const WEAPONS_NEIGHBOR_GAP_WIN := 10.0


## Authoritative bottom weapon strip: centered in the bottom band between
## reactor (left) and abilities (right), aspect-locked, bottom-aligned.
static func weapons_panel(
	safe_inset: Dictionary,
	view_left: float,
	view_right: float,
	view_top: float,
	view_bottom: float,
	view_aspect: float,
	canvas_scale: float,
	window_size: Vector2i,
	viewport_size: Vector2,
	left_limit: float = -1.0,
	right_limit: float = -1.0
) -> Dictionary:
	var usable_w: float = maxf(1.0, view_right - view_left)
	var ref_w: float = _win_to_design_px(WEAPONS_REF_WIN_W, window_size, viewport_size, canvas_scale)
	var min_w: float = _win_to_design_px(WEAPONS_MIN_WIN_W, window_size, viewport_size, canvas_scale)
	var max_w: float = _win_to_design_px(WEAPONS_MAX_WIN_W, window_size, viewport_size, canvas_scale)
	var gap: float = _win_to_design_px(WEAPONS_NEIGHBOR_GAP_WIN, window_size, viewport_size, canvas_scale)
	var l_lim: float = left_limit if left_limit >= 0.0 else view_left
	var r_lim: float = right_limit if right_limit >= 0.0 else view_right
	# Band between neighbors (with gaps), then center the frame in that band.
	var band_l: float = l_lim + gap
	var band_r: float = r_lim - gap
	var avail: float = maxf(80.0, band_r - band_l)
	var frac: float = 0.28
	if view_aspect > 0.01:
		if view_aspect < 1.85:
			frac = 0.32
		elif view_aspect > 2.25:
			frac = 0.26
		else:
			frac = lerpf(0.32, 0.26, (view_aspect - 1.85) / 0.40)
	var target_w: float = lerpf(ref_w, usable_w * frac, 0.35)
	target_w = minf(target_w, avail)
	var sz: Vector2 = aspect_size(WEAPONS_ASPECT, target_w, -1.0)
	sz = clamp_size(sz, Vector2(min_w * 0.75, min_w * 0.75 / WEAPONS_ASPECT),
		Vector2(max_w, max_w / WEAPONS_ASPECT), WEAPONS_ASPECT)
	if sz.x > avail:
		sz = aspect_size(WEAPONS_ASPECT, avail, -1.0)
	var bot_m: float = _win_to_design_px(WEAPONS_BOT_MARGIN_WIN, window_size, viewport_size, canvas_scale)
	# Center opaque metal on the screen bottom; nudge only if neighbors collide.
	var opaque_w: float = sz.x * (1.0 - WEAPONS_ART_PAD_L - WEAPONS_ART_PAD_R)
	var screen_mid: float = (view_left + view_right) * 0.5
	var x: float = screen_mid - opaque_w * 0.5 - sz.x * WEAPONS_ART_PAD_L
	var opaque_l: float = x + sz.x * WEAPONS_ART_PAD_L
	var opaque_r: float = x + sz.x * (1.0 - WEAPONS_ART_PAD_R)
	if opaque_l < band_l:
		x += band_l - opaque_l
		opaque_l = x + sz.x * WEAPONS_ART_PAD_L
		opaque_r = x + sz.x * (1.0 - WEAPONS_ART_PAD_R)
	if opaque_r > band_r:
		x -= opaque_r - band_r
		opaque_l = x + sz.x * WEAPONS_ART_PAD_L
		# If still can't fit, shrink into the free band and re-center there.
		if opaque_l < band_l:
			sz = aspect_size(WEAPONS_ASPECT, avail, -1.0)
			opaque_w = sz.x * (1.0 - WEAPONS_ART_PAD_L - WEAPONS_ART_PAD_R)
			x = (band_l + band_r) * 0.5 - opaque_w * 0.5 - sz.x * WEAPONS_ART_PAD_L
	# Pin opaque bottom to view_bottom (screen edge).
	var y: float = view_bottom - bot_m - sz.y * (1.0 - WEAPONS_ART_PAD_B)
	var tex_r := Rect2(x, y, sz.x, sz.y)
	var hit := Rect2(
		tex_r.position.x + tex_r.size.x * WEAPONS_ART_PAD_L * 0.4,
		tex_r.position.y + tex_r.size.y * WEAPONS_ART_PAD_T * 0.55,
		tex_r.size.x * (1.0 - WEAPONS_ART_PAD_L * 0.4 - WEAPONS_ART_PAD_R * 0.4),
		tex_r.size.y * (1.0 - WEAPONS_ART_PAD_T * 0.55 - WEAPONS_ART_PAD_B * 0.45)
	)
	var slots: Array = []
	var icons: Array = []
	var labels: Array = []
	for pair in WEAPONS_SLOT_X:
		var x0: float = float(pair[0])
		var x1: float = float(pair[1])
		var well := Rect2(
			tex_r.position.x + tex_r.size.x * x0,
			tex_r.position.y + tex_r.size.y * WEAPONS_ICON_Y0,
			tex_r.size.x * (x1 - x0),
			tex_r.size.y * (WEAPONS_LABEL_Y1 - WEAPONS_ICON_Y0)
		)
		slots.append(well)
		icons.append(Rect2(
			well.position.x + well.size.x * 0.10,
			tex_r.position.y + tex_r.size.y * WEAPONS_ICON_Y0,
			well.size.x * 0.80,
			tex_r.size.y * (WEAPONS_ICON_Y1 - WEAPONS_ICON_Y0)
		))
		labels.append(Rect2(
			well.position.x + well.size.x * 0.06,
			tex_r.position.y + tex_r.size.y * WEAPONS_LABEL_Y0,
			well.size.x * 0.88,
			tex_r.size.y * (WEAPONS_LABEL_Y1 - WEAPONS_LABEL_Y0)
		))
	var conflict := ""
	if sz.x < min_w * 0.85:
		conflict = "WEAPONS_COMPACTED_FOR_NEIGHBORS"
	return {
		"texture_rect": tex_r,
		"hit": hit,
		"slots": slots,
		"icons": icons,
		"labels": labels,
		"aspect": WEAPONS_ASPECT,
		"view_aspect": view_aspect,
		"width_frac": tex_r.size.x / usable_w,
		"bot_margin": bot_m,
		"conflict": conflict,
		"avail": avail,
	}


## Four-slot Active Abilities console (Downloads SVG embed → PNG).
## Source: riftline_reactor_status_panel.svg — 2048×682 (runtime PNG renamed to riftline_abilities_bar.png).
## Brass/cyan frame; transparent icon openings + opaque label wells beneath.
const ABILITIES_TEX_W := 2048.0
const ABILITIES_TEX_H := 682.0
const ABILITIES_ASPECT := ABILITIES_TEX_W / ABILITIES_TEX_H ## ≈ 3.0029
const ABILITIES_REF_WIN_W := 380.0
const ABILITIES_MIN_WIN_W := 320.0
const ABILITIES_MAX_WIN_W := 430.0
const ABILITIES_ART_PAD_L := 0.0225
const ABILITIES_ART_PAD_R := 0.0225
const ABILITIES_ART_PAD_T := 0.1481
const ABILITIES_ART_PAD_B := 0.1246
const ABILITIES_SLOT_X := [
	[0.120, 0.234],
	[0.338, 0.451],
	[0.547, 0.660],
	[0.766, 0.880],
]
## Transparent square openings measured from PNG alpha (~y 0.325–0.615).
const ABILITIES_ICON_Y0 := 0.315
const ABILITIES_ICON_Y1 := 0.595
const ABILITIES_LABEL_Y0 := 0.62
const ABILITIES_LABEL_Y1 := 0.84
## Flush opaque brass to the screen bottom (matches weapons).
const ABILITIES_BOT_MARGIN_WIN := 0.0
const ABILITIES_NEIGHBOR_GAP_WIN := 10.0


## Authoritative abilities strip. Aspect-locked; bottom-aligned with weapons.
## attach_after >= 0: place opaque-left at attach_after + responsive gap (beside weapons).
## attach_after < 0: flush opaque-right to safe-right (ghost neighbor for weapons band).
static func abilities_panel(
	safe_inset: Dictionary,
	view_left: float,
	view_right: float,
	view_top: float,
	view_bottom: float,
	view_aspect: float,
	canvas_scale: float,
	window_size: Vector2i,
	viewport_size: Vector2,
	left_limit: float = -1.0,
	right_limit: float = -1.0,
	attach_after: float = -1.0
) -> Dictionary:
	var inset_r: float = float(safe_inset.get("right", 0.0))
	var usable_w: float = maxf(1.0, view_right - view_left)
	var ref_w: float = _win_to_design_px(ABILITIES_REF_WIN_W, window_size, viewport_size, canvas_scale)
	var min_w: float = _win_to_design_px(ABILITIES_MIN_WIN_W, window_size, viewport_size, canvas_scale)
	var max_w: float = _win_to_design_px(ABILITIES_MAX_WIN_W, window_size, viewport_size, canvas_scale)
	var gap: float = _win_to_design_px(ABILITIES_NEIGHBOR_GAP_WIN, window_size, viewport_size, canvas_scale)
	var l_lim: float = left_limit if left_limit >= 0.0 else view_left
	var r_lim: float = right_limit if right_limit >= 0.0 else (view_right - maxf(0.0, inset_r))
	var avail: float = maxf(80.0, r_lim - l_lim - gap)
	if attach_after >= 0.0:
		avail = maxf(80.0, r_lim - (attach_after + gap))
	var frac: float = 0.28
	if view_aspect > 0.01:
		if view_aspect < 1.85:
			frac = 0.32
		elif view_aspect > 2.25:
			frac = 0.26
		else:
			frac = lerpf(0.32, 0.26, (view_aspect - 1.85) / 0.40)
	var target_w: float = lerpf(ref_w, usable_w * frac, 0.34)
	target_w = minf(target_w, avail)
	var sz: Vector2 = aspect_size(ABILITIES_ASPECT, target_w, -1.0)
	sz = clamp_size(sz, Vector2(min_w * 0.75, min_w * 0.75 / ABILITIES_ASPECT),
		Vector2(max_w, max_w / ABILITIES_ASPECT), ABILITIES_ASPECT)
	if sz.x > avail:
		sz = aspect_size(ABILITIES_ASPECT, avail, -1.0)
	var bot_m: float = _win_to_design_px(ABILITIES_BOT_MARGIN_WIN, window_size, viewport_size, canvas_scale)
	var x: float
	if attach_after >= 0.0:
		# Opaque left sits at weapon_opaque_right + gap (compensate transparent pad).
		var opaque_left: float = attach_after + gap
		x = opaque_left - sz.x * ABILITIES_ART_PAD_L
		var opaque_right: float = x + sz.x * (1.0 - ABILITIES_ART_PAD_R)
		if opaque_right > r_lim:
			var fit_opaque: float = maxf(60.0, r_lim - opaque_left)
			var fit_w: float = fit_opaque / maxf(0.001, 1.0 - ABILITIES_ART_PAD_L - ABILITIES_ART_PAD_R)
			sz = aspect_size(ABILITIES_ASPECT, fit_w, -1.0)
			x = opaque_left - sz.x * ABILITIES_ART_PAD_L
	else:
		# Flush opaque right edge to safe-right (ghost / legacy).
		x = r_lim - sz.x * (1.0 - ABILITIES_ART_PAD_R)
		if x < l_lim + gap:
			x = l_lim + gap
			var fit_w2: float = maxf(80.0, r_lim - x)
			sz = aspect_size(ABILITIES_ASPECT, fit_w2 / maxf(0.001, 1.0 - ABILITIES_ART_PAD_R), -1.0)
			x = r_lim - sz.x * (1.0 - ABILITIES_ART_PAD_R)
	var y: float = view_bottom - bot_m - sz.y * (1.0 - ABILITIES_ART_PAD_B)
	var tex_r := Rect2(x, y, sz.x, sz.y)
	var hit := Rect2(
		tex_r.position.x + tex_r.size.x * ABILITIES_ART_PAD_L * 0.4,
		tex_r.position.y + tex_r.size.y * ABILITIES_ART_PAD_T * 0.55,
		tex_r.size.x * (1.0 - ABILITIES_ART_PAD_L * 0.4 - ABILITIES_ART_PAD_R * 0.4),
		tex_r.size.y * (1.0 - ABILITIES_ART_PAD_T * 0.55 - ABILITIES_ART_PAD_B * 0.45)
	)
	var slots: Array = []
	var icons: Array = []
	var labels: Array = []
	for pair in ABILITIES_SLOT_X:
		var x0: float = float(pair[0])
		var x1: float = float(pair[1])
		var well := Rect2(
			tex_r.position.x + tex_r.size.x * x0,
			tex_r.position.y + tex_r.size.y * ABILITIES_ICON_Y0,
			tex_r.size.x * (x1 - x0),
			tex_r.size.y * (ABILITIES_LABEL_Y1 - ABILITIES_ICON_Y0)
		)
		slots.append(well)
		# Exact transparent opening — icons cover this rect edge-to-edge.
		icons.append(Rect2(
			well.position.x,
			tex_r.position.y + tex_r.size.y * ABILITIES_ICON_Y0,
			well.size.x,
			tex_r.size.y * (ABILITIES_ICON_Y1 - ABILITIES_ICON_Y0)
		))
		labels.append(Rect2(
			well.position.x + well.size.x * 0.06,
			tex_r.position.y + tex_r.size.y * ABILITIES_LABEL_Y0,
			well.size.x * 0.88,
			tex_r.size.y * (ABILITIES_LABEL_Y1 - ABILITIES_LABEL_Y0)
		))
	var conflict := ""
	if sz.x < min_w * 0.85:
		conflict = "ABILITIES_COMPACTED_FOR_NEIGHBORS"
	if attach_after >= 0.0 and (tex_r.position.x + tex_r.size.x * (1.0 - ABILITIES_ART_PAD_R)) > r_lim + 0.5:
		conflict = "ABILITIES_CLIP_SAFE_RIGHT"
	return {
		"texture_rect": tex_r,
		"hit": hit,
		"slots": slots,
		"icons": icons,
		"labels": labels,
		"aspect": ABILITIES_ASPECT,
		"view_aspect": view_aspect,
		"width_frac": tex_r.size.x / usable_w,
		"bot_margin": bot_m,
		"conflict": conflict,
		"avail": avail,
		"gap": gap,
	}
