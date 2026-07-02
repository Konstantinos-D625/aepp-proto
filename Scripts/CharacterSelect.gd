extends Panel

const CHAR_TEX := preload("res://Εικόνες/char.png")

const CHAR_DATA: Array[Dictionary] = [
	{"name": "Lyra Shadowveil", "class": "Μάγισσα Σκιών",    "color": Color(0.28, 0.08, 0.40), "locked": false,
		"stats": {"Άμυνα": 6, "Επίθεση": 12, "Ταχύτητα": 9, "Εξυπνάδα": 14, "Δύναμη": 5}},
	{"name": "Aelindra",        "class": "Τοξότης Ξωτικών",  "color": Color(0.08, 0.20, 0.12), "locked": true,
		"stats": {"Άμυνα": 7, "Επίθεση": 13, "Ταχύτητα": 15, "Εξυπνάδα": 9, "Δύναμη": 7}},
	{"name": "Elder Bromwick",  "class": "Αρχαίος Δρυΐδης",  "color": Color(0.10, 0.16, 0.26), "locked": true,
		"stats": {"Άμυνα": 8, "Επίθεση": 9, "Ταχύτητα": 6, "Εξυπνάδα": 15, "Δύναμη": 6}},
	{"name": "Thordin",         "class": "Νάνος Πολεμιστής", "color": Color(0.26, 0.14, 0.04), "locked": true,
		"stats": {"Άμυνα": 14, "Επίθεση": 11, "Ταχύτητα": 5, "Εξυπνάδα": 6, "Δύναμη": 15}},
	{"name": "Sir Gareth",      "class": "Σιδηρούς Ιππότης", "color": Color(0.16, 0.17, 0.20), "locked": true,
		"stats": {"Άμυνα": 15, "Επίθεση": 10, "Ταχύτητα": 6, "Εξυπνάδα": 7, "Δύναμη": 12}},
	{"name": "Lady Seraphina",  "class": "Ευγενής Μάγισσα",  "color": Color(0.28, 0.05, 0.08), "locked": true,
		"stats": {"Άμυνα": 7, "Επίθεση": 14, "Ταχύτητα": 10, "Εξυπνάδα": 13, "Δύναμη": 5}},
]

# ── Palette ───────────────────────────────────────────────────────
const C0  := Color(0, 0, 0, 0)                    # transparent
const C_BG   := Color(0.032, 0.022, 0.010, 0.82)  # warm semi-transparent overlay
const C_DARK := Color(0.055, 0.038, 0.018)         # darkest panels
const C_MID  := Color(0.095, 0.068, 0.035)         # mid panels
const C_IRON := Color(0.185, 0.168, 0.140)         # iron buttons
const C_IRON_L := Color(0.265, 0.242, 0.208)       # lighter iron hover
const C_SILVER := Color(0.572, 0.548, 0.510)       # silver trim
const C_BRONZE := Color(0.435, 0.308, 0.072)       # bronze accent
const C_GOLD   := Color(0.820, 0.645, 0.118)       # active gold
const C_GOLD_D := Color(0.268, 0.192, 0.032)       # locked/dim gold
const C_CRIMSON:= Color(0.455, 0.030, 0.030)       # red accent
const C_BONE   := Color(0.868, 0.830, 0.685)       # primary text
const C_BONE_D := Color(0.415, 0.378, 0.290)       # secondary/locked text
const C_MAGIC  := Color(0.375, 0.130, 0.618)       # unlocked magic aura

# ── Fixed layout (1080 × 1920) ───────────────────────────────────
const HDR_H  := 278.0
const BAR_H  := 218.0
const MX     := 40.0   # horizontal margin
const GX     := 20.0   # horizontal gap between columns
const GY     := 18.0   # vertical gap between rows
const PW     := (1080.0 - MX * 2.0 - GX) / 2.0     # portrait width  ≈ 490
const PH     := ((1920.0 - HDR_H - BAR_H - 50.0) - GY * 2.0) / 3.0  # ≈ 438
const GRID_Y := HDR_H + 18.0
const AI     := 10.0   # art inset
const PLH    := 76.0   # name-plate height

var _bar: Panel
var _selected_idx := -1
var _edit_popup: CharacterEditPopup

func _ready() -> void:
	_overlay()
	_header()
	_grid()
	_action_bar()
	_edit_popup = preload("res://Scenes/CharacterEditPopup.tscn").instantiate()
	add_child(_edit_popup)
	# Fade-in entrance
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.30)

func show_screen() -> void:
	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.30)

# ═══════════════════════════════════════════════════════════════
# BACKGROUND OVERLAY
# ═══════════════════════════════════════════════════════════════

func _overlay() -> void:
	# Warm dark veil — game BG visible through the panel
	var ov := ColorRect.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.color = C_BG
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ov)
	# Heavy bottom vignette
	_cr(Vector2(0, 1540), Vector2(1080, 380), Color(0, 0, 0, 0.72))
	# Soft top vignette
	_cr(Vector2(0, 0), Vector2(1080, 200), Color(0, 0, 0, 0.40))
	# Side vignettes
	_cr(Vector2(0, 0), Vector2(80, 1920), Color(0, 0, 0, 0.28))
	_cr(Vector2(1000, 0), Vector2(80, 1920), Color(0, 0, 0, 0.28))
	# Warm atmospheric centre-top glow (simulates torchlight from above)
	_circle_glow(Vector2(540, 0), 420, Color(0.65, 0.35, 0.08), 0.045)
	# Floating dust
	_dust()

func _circle_glow(center: Vector2, radius: float, col: Color, alpha: float) -> void:
	var steps: Array[int] = [5, 4, 3, 2, 1]
	for i in steps.size():
		var r: float = radius * (1.0 - i * 0.16)
		var p := Panel.new()
		p.position = Vector2(center.x - r, center.y - r)
		p.size     = Vector2(r * 2.0, r * 2.0)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s := StyleBoxFlat.new()
		var ir: int = int(r)
		s.bg_color = Color(col.r, col.g, col.b, alpha * (0.30 + i * 0.14))
		s.corner_radius_top_left     = ir
		s.corner_radius_top_right    = ir
		s.corner_radius_bottom_right = ir
		s.corner_radius_bottom_left  = ir
		s.set_border_width_all(0)
		p.add_theme_stylebox_override("panel", s)
		add_child(p)

func _dust() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 44401
	for _i in range(28):
		var sz: float = 1.5 + rng.randf() * 3.0
		var d := ColorRect.new()
		d.size     = Vector2(sz, sz)
		d.position = Vector2(rng.randi_range(80, 1000), rng.randi_range(0, 1920))
		d.color    = Color(0.80 + rng.randf() * 0.15, 0.65 + rng.randf() * 0.20, 0.35 + rng.randf() * 0.25, 0.65)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(d)
		var tw := create_tween()
		tw.set_loops()
		tw.tween_property(d, "modulate:a", 0.04, 1.6 + rng.randf() * 3.0).set_delay(rng.randf() * 5.0)
		tw.tween_property(d, "modulate:a", 1.00, 1.6 + rng.randf() * 3.0)

# ═══════════════════════════════════════════════════════════════
# HEADER
# ═══════════════════════════════════════════════════════════════

func _header() -> void:
	# Stone slab
	_add_panel(self, Vector2(0, 0), Vector2(1080, HDR_H), Color(0.048, 0.032, 0.015, 0.96), C_BRONZE, 0, 4, 0)
	# Gold bottom rule
	_cr(Vector2(0, HDR_H - 4), Vector2(1080, 4), C_GOLD)
	_cr(Vector2(0, HDR_H),     Vector2(1080, 2), C_CRIMSON)

	# Side column accents
	for xv: float in [0.0, 1052.0]:
		_add_panel(self, Vector2(xv, 0), Vector2(28, HDR_H), Color(0.065, 0.044, 0.020, 0.92), C_BRONZE, 0, 0, 0)
		var side_brd_s := StyleBoxFlat.new()
		side_brd_s.bg_color = C0
		side_brd_s.border_color = C_BRONZE
		side_brd_s.border_width_right = 2 if xv == 0 else 0
		side_brd_s.border_width_left  = 0 if xv == 0 else 2
		var side_p := get_child(get_child_count() - 1) as Panel
		side_p.add_theme_stylebox_override("panel", side_brd_s)

	# Back button
	var back := Button.new()
	back.text     = "◄  ΠΙΣΩ"
	back.position = Vector2(38, 84)
	back.size     = Vector2(208, 100)
	_style_iron(back)
	back.add_theme_font_size_override("font_size", 36)
	add_child(back)
	back.pressed.connect(_on_back_pressed)

	# Title banner (sunken stone look)
	_add_panel(self, Vector2(264 + 4, 36 + 4), Vector2(552, 116), Color(0,0,0,0.65), C0, 0, 6, 0)
	_add_panel(self, Vector2(264, 36), Vector2(552, 116), Color(0.065, 0.044, 0.020), C_GOLD, 4, 6, 0)
	# Inner hairline
	_add_panel(self, Vector2(270, 42), Vector2(540, 104), C0, C_GOLD_D, 1, 3, 0)
	# Bevel
	_cr(Vector2(264, 36), Vector2(552, 2), Color(1, 1, 1, 0.06))
	_cr(Vector2(264, 150), Vector2(552, 2), Color(0, 0, 0, 0.75))

	# Title
	_lbl(self, "ΕΠΙΛΟΓΗ ΧΑΡΑΚΤΗΡΑ", Vector2(0, 46), Vector2(1080, 106),
		 68, C_BONE, HORIZONTAL_ALIGNMENT_CENTER, Color(0,0,0,0.95), 3, 4)

	# Subtitle
	_lbl(self, "Επίλεξε τον ήρωά σου", Vector2(0, 183), Vector2(1080, 50),
		 28, Color(0.50, 0.40, 0.22), HORIZONTAL_ALIGNMENT_CENTER)

	# Ornament separator
	_ornament(56, 244, 968)

# ═══════════════════════════════════════════════════════════════
# PORTRAIT GRID
# ═══════════════════════════════════════════════════════════════

func _grid() -> void:
	for i in range(6):
		var row := int(i / 2.0)
		var col := i % 2
		_portrait(i, MX + col * (PW + GX), GRID_Y + row * (PH + GY))

func _portrait(idx: int, x: float, y: float) -> void:
	var d: Dictionary = CHAR_DATA[idx]
	var locked: bool  = bool(d["locked"])
	var pcol: Color   = d["color"] as Color
	var art_h: float  = PH - PLH - AI

	# ── Shadow ───────────────────────────────────
	_add_panel(self, Vector2(x + 7, y + 9), Vector2(PW, PH),
			   Color(0,0,0,0.78), C0, 0, 5, 0)

	# ── Magic aura (unlocked) ────────────────────
	if not locked:
		var glow := Panel.new()
		glow.position = Vector2(x - 8, y - 8)
		glow.size     = Vector2(PW + 16, PH + 16)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gs := StyleBoxFlat.new()
		gs.bg_color     = C0
		gs.border_color = Color(C_MAGIC.r, C_MAGIC.g, C_MAGIC.b, 0.72)
		gs.set_border_width_all(3)
		gs.corner_radius_top_left     = 8
		gs.corner_radius_top_right    = 8
		gs.corner_radius_bottom_right = 8
		gs.corner_radius_bottom_left  = 8
		gs.shadow_color = Color(C_MAGIC.r, C_MAGIC.g, C_MAGIC.b, 0.88)
		gs.shadow_size  = 22
		glow.add_theme_stylebox_override("panel", gs)
		add_child(glow)
		var tw := create_tween()
		tw.set_loops()
		tw.tween_property(glow, "modulate:a", 0.18, 2.2)
		tw.tween_property(glow, "modulate:a", 1.00, 2.2)

	# ── Main frame ───────────────────────────────
	var border_col := C_GOLD if not locked else C_GOLD_D
	_add_panel(self, Vector2(x, y), Vector2(PW, PH), C_DARK, border_col, 9, 5, 0)
	# Bevel top-highlight / bottom-shadow
	_cr(Vector2(x, y), Vector2(PW, 3), Color(1, 1, 1, 0.055))
	_cr(Vector2(x, y + PH - 3), Vector2(PW, 3), Color(0, 0, 0, 0.78))
	# Inner hair-line border
	_add_panel(self, Vector2(x + 9, y + 9), Vector2(PW - 18, PH - 18),
			   C0, border_col.darkened(0.38), 1, 3, 0)

	# ── Corner L-brackets ────────────────────────
	_brackets(x, y, PW, PH, border_col)

	# ── Art background ───────────────────────────
	_add_panel(self, Vector2(x + AI, y + AI), Vector2(PW - AI*2, art_h),
			   pcol.darkened(0.48 if locked else 0.12), C0, 0, 0, 0)

	# ── Portrait image / locked placeholder ──────
	if not locked:
		var char_tr := TextureRect.new()
		char_tr.texture      = CHAR_TEX
		char_tr.position     = Vector2(x + AI, y + AI)
		char_tr.size         = Vector2(PW - AI*2, art_h)
		char_tr.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		char_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		char_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(char_tr)
		# Star badge
		_lbl(self, "★", Vector2(x + PW - 50, y + AI + 4), Vector2(40, 40),
			 36, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, Color(0,0,0,0.95), 2, 2)
	else:
		# Faint colour hint of the hidden character
		_cr(Vector2(x + AI, y + AI), Vector2(PW - AI*2, art_h * 0.45), pcol.darkened(0.75))

	# Vignette border over art
	var vig := Panel.new()
	vig.position = Vector2(x + AI, y + AI)
	vig.size     = Vector2(PW - AI*2, art_h)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vs := StyleBoxFlat.new()
	vs.bg_color     = C0
	vs.border_color = Color(0, 0, 0, 0.70 if locked else 0.50)
	vs.set_border_width_all(18)
	vig.add_theme_stylebox_override("panel", vs)
	add_child(vig)

	# Slot number badge
	_badge(str(idx + 1), x + AI + 2, y + AI + 2, not locked)

	# ── Name plate ───────────────────────────────
	_name_plate(d, locked, x, y)

	# ── Lock overlay + shield padlock ────────────
	if locked:
		_cr(Vector2(x + AI, y + AI), Vector2(PW - AI*2, art_h), Color(0.03, 0.02, 0.05, 0.70))
		_shield_lock(x + PW / 2.0, y + AI + art_h * 0.42)

	# ── Transparent clickable button (always on top) ──
	var btn := Button.new()
	btn.position = Vector2(x, y)
	btn.size     = Vector2(PW, PH)
	var ts := _sb(C0, C0, 0, 5)
	var hs := _sb(Color(0.48, 0.03, 0.03, 0.12) if locked else Color(0.36, 0.12, 0.60, 0.14), C0, 0, 5)
	btn.add_theme_stylebox_override("normal",  ts)
	btn.add_theme_stylebox_override("hover",   hs)
	btn.add_theme_stylebox_override("pressed", ts)
	btn.add_theme_stylebox_override("focus",   ts)
	add_child(btn)
	if not locked:
		btn.pressed.connect(func(): _on_char_selected(idx))

# ─── Portrait helpers ──────────────────────────────────────────

func _brackets(x: float, y: float, w: float, h: float, col: Color) -> void:
	const L := 28.0   # bracket arm length
	const T := 5.0    # bracket arm thickness
	const O := 8.0    # offset from frame edge (inside border)
	var bot_y: float = y + h - PLH - O - T  # bottom bracket stops above name plate
	# arm pairs: [horizontal rect, vertical rect]
	var arms: Array[Rect2] = [
		# top-left
		Rect2(x + O, y + O, L, T), Rect2(x + O, y + O, T, L),
		# top-right
		Rect2(x + w - O - L, y + O, L, T), Rect2(x + w - O - T, y + O, T, L),
		# bottom-left
		Rect2(x + O, bot_y, L, T), Rect2(x + O, bot_y - L + T, T, L),
		# bottom-right
		Rect2(x + w - O - L, bot_y, L, T), Rect2(x + w - O - T, bot_y - L + T, T, L),
	]
	for r in arms:
		var p := Panel.new()
		p.position = r.position
		p.size     = r.size
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s := StyleBoxFlat.new()
		s.bg_color     = col
		s.border_color = col.lightened(0.25)
		s.set_border_width_all(1)
		p.add_theme_stylebox_override("panel", s)
		add_child(p)

func _badge(text: String, x: float, y: float, bright: bool) -> void:
	_add_panel(self, Vector2(x + 2, y + 2), Vector2(40, 40), Color(0,0,0,0.68), C0, 0, 3, 0)
	_add_panel(self, Vector2(x, y), Vector2(40, 40), C_MID,
			   C_BRONZE if bright else C_BRONZE.darkened(0.4), 2, 3, 0)
	_lbl(self, text, Vector2(x, y), Vector2(40, 40), 22,
		 C_GOLD if bright else C_GOLD_D, HORIZONTAL_ALIGNMENT_CENTER,
		 Color(0,0,0,0.92), 1, 2)

func _name_plate(d: Dictionary, locked: bool, x: float, y: float) -> void:
	var py := y + PH - PLH
	# Shadow
	_cr(Vector2(x + 3, py + 4), Vector2(PW, PLH), Color(0,0,0,0.70))
	# Plate
	_add_panel(self, Vector2(x, py), Vector2(PW, PLH), C_DARK,
			   C_BRONZE if not locked else C_BRONZE.darkened(0.42), 0, 5, 0)
	# Top border line (matches frame colour)
	_cr(Vector2(x, py), Vector2(PW, 4), C_GOLD if not locked else C_GOLD_D)
	# Bevel bottom
	_cr(Vector2(x, py + PLH - 2), Vector2(PW, 2), Color(0,0,0,0.80))
	# Inner subtle divider
	_cr(Vector2(x + 18, py + PLH - 14), Vector2(PW - 36, 1), C_BRONZE.darkened(0.50))

	_lbl(self, str(d["name"]), Vector2(x, py + 5), Vector2(PW, 42),
		 30, C_BONE if not locked else C_BONE_D, HORIZONTAL_ALIGNMENT_CENTER,
		 Color(0,0,0,0.95), 2, 3)
	_lbl(self, str(d["class"]) if not locked else "— Κλειδωμένο —",
		 Vector2(x, py + 44), Vector2(PW, 28), 20,
		 C_BRONZE if not locked else Color(0.28, 0.20, 0.08, 0.68),
		 HORIZONTAL_ALIGNMENT_CENTER)

func _shield_lock(cx: float, cy: float) -> void:
	const SW := 100.0
	const SH := 118.0
	var sx := cx - SW / 2.0
	var sy := cy - SH * 0.44

	# Shackle
	for bx: float in [cx - 26.0, cx + 6.0]:
		var bar := Panel.new()
		bar.position = Vector2(bx, sy - 52)
		bar.size     = Vector2(20, 56)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bs := _sb(Color(0.40, 0.28, 0.05), Color(0.60, 0.44, 0.08), 3, 10)
		bs.corner_radius_top_left  = 10
		bs.corner_radius_top_right = 10
		bar.add_theme_stylebox_override("panel", bs)
		add_child(bar)
	var top := Panel.new()
	top.position = Vector2(cx - 26, sy - 52)
	top.size     = Vector2(52, 20)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ts := _sb(Color(0.40, 0.28, 0.05), Color(0.60, 0.44, 0.08), 3, 10)
	ts.corner_radius_top_left  = 10
	ts.corner_radius_top_right = 10
	top.add_theme_stylebox_override("panel", ts)
	add_child(top)

	# Shield shadow
	_add_panel(self, Vector2(sx + 5, sy + 6), Vector2(SW, SH), Color(0,0,0,0.80), C0, 0, 0, 50)

	# Shield body
	_add_panel(self, Vector2(sx, sy), Vector2(SW, SH),
			   Color(0.28, 0.19, 0.04), C_BRONZE, 5, 6, 50)
	# Shield face (inner darker)
	_add_panel(self, Vector2(sx + 5, sy + 5), Vector2(SW - 10, SH - 10),
			   Color(0.18, 0.12, 0.02), C0, 0, 4, 48)
	# Inner gold inlay ring
	_add_panel(self, Vector2(sx + 5, sy + 5), Vector2(SW - 10, SH - 10),
			   C0, C_GOLD_D, 1, 4, 48)
	# Bevel
	_cr(Vector2(sx, sy), Vector2(SW, 3), Color(1, 1, 1, 0.07))

	# Boss rivets
	for rv: Vector2 in [Vector2(sx+12,sy+12), Vector2(sx+SW-22,sy+12),
						 Vector2(sx+12,sy+SH-42), Vector2(sx+SW-22,sy+SH-42)]:
		_add_panel(self, rv, Vector2(10, 10), C_BRONZE, C_GOLD_D, 1, 0, 5)

	# Keyhole — oval
	_add_panel(self, Vector2(cx-12, sy + SH*0.38), Vector2(24, 24),
			   Color(0.05, 0.03, 0.01), C_BRONZE.darkened(0.30), 1, 0, 12)
	# Keyhole — slot
	_cr(Vector2(cx - 6, sy + SH*0.38 + 19), Vector2(12, 20), Color(0.05, 0.03, 0.01))

# ═══════════════════════════════════════════════════════════════
# ACTION BAR
# ═══════════════════════════════════════════════════════════════

func _action_bar() -> void:
	const BY := 1920.0 - BAR_H

	# Shadow strip
	_cr(Vector2(0, BY - 12), Vector2(1080, 14), Color(0,0,0,0.88))

	_bar          = Panel.new()
	_bar.name     = "ActionBar"
	_bar.position = Vector2(0, BY)
	_bar.size     = Vector2(1080, BAR_H)
	_bar.visible  = false
	var bs := _sb(Color(0.038, 0.026, 0.012, 0.97), C_BRONZE, 0, 0)
	bs.border_width_top = 4
	_bar.add_theme_stylebox_override("panel", bs)
	add_child(_bar)

	# Top rules
	_cr_child(_bar, Vector2(0, 0), Vector2(1080, 4), C_GOLD)
	_cr_child(_bar, Vector2(0, 4), Vector2(1080, 2), C_CRIMSON)
	_cr_child(_bar, Vector2(0, 6), Vector2(1080, 1), Color(1,1,1,0.04))
	# Bottom ornament
	_ornament_child(_bar, 44, BAR_H - 22, 992)

	# EDIT
	var e := _bar_btn("EDIT", 44, 44, 264, 132)
	_bar.add_child(e)
	e.pressed.connect(_on_action_edit)
	_gem_child(_bar, Vector2(14, 109), C_CRIMSON.lightened(0.20))

	# Divider
	_vdiv_child(_bar, 316)

	# BACK
	var b := _bar_btn("BACK", 326, 44, 264, 132)
	_bar.add_child(b)
	b.pressed.connect(_on_action_back)

	# Centre deco
	var fl := Label.new()
	fl.text     = "⚜"
	fl.position = Vector2(606, 64)
	fl.size     = Vector2(58, 88)
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fl.add_theme_font_size_override("font_size", 52)
	fl.add_theme_color_override("font_color",        C_BRONZE.darkened(0.12))
	fl.add_theme_color_override("font_shadow_color", Color(0,0,0,0.90))
	fl.add_theme_constant_override("shadow_offset_x", 2)
	fl.add_theme_constant_override("shadow_offset_y", 2)
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(fl)

	# CONFIRM
	var c := _bar_btn("CONFIRM", 674, 44, 360, 132, true)
	_bar.add_child(c)
	c.pressed.connect(_on_action_confirm)
	_gem_child(_bar, Vector2(1066, 109), C_GOLD)

func _bar_btn(txt: String, bx: float, by: float, bw: float, bh: float, gold: bool = false) -> Button:
	var btn := Button.new()
	btn.text     = txt
	btn.position = Vector2(bx, by)
	btn.size     = Vector2(bw, bh)
	_style_iron(btn, gold)
	btn.add_theme_font_size_override("font_size", 50 if txt == "CONFIRM" else 54)
	return btn

func _gem_child(parent: Control, pos: Vector2, col: Color) -> void:
	# Outer ring
	var ring := Panel.new()
	ring.position = Vector2(pos.x - 14, pos.y - 14)
	ring.size     = Vector2(28, 28)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rs := _sb(C_MID, C_BRONZE, 2, 14)
	ring.add_theme_stylebox_override("panel", rs)
	parent.add_child(ring)
	# Gem
	var gem := Panel.new()
	gem.position = Vector2(pos.x - 9, pos.y - 9)
	gem.size     = Vector2(18, 18)
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gs := _sb(col, col.lightened(0.38), 1, 9)
	gem.add_theme_stylebox_override("panel", gs)
	parent.add_child(gem)
	# Highlight
	var hi := ColorRect.new()
	hi.position = Vector2(pos.x - 5, pos.y - 7)
	hi.size     = Vector2(5, 4)
	hi.color    = Color(1, 1, 1, 0.55)
	hi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(hi)

func _vdiv_child(parent: Control, xp: float) -> void:
	for d: Array in [[Color(1,1,1,0.06), xp-1], [C_BRONZE, xp], [Color(0,0,0,0.60), xp+2]]:
		var r := ColorRect.new()
		r.color    = d[0]
		r.position = Vector2(d[1], 34)
		r.size     = Vector2(2, 152)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(r)

# ═══════════════════════════════════════════════════════════════
# SIGNAL HANDLERS
# ═══════════════════════════════════════════════════════════════

func _on_char_selected(idx: int) -> void:
	_selected_idx = idx
	_bar.visible = true

func _on_action_edit() -> void:
	_bar.visible = false
	if _selected_idx >= 0 and _selected_idx < CHAR_DATA.size():
		_edit_popup.open_character(CHAR_DATA[_selected_idx])

func _on_action_back() -> void:    _bar.visible = false
func _on_action_confirm() -> void: _bar.visible = false
func _on_back_pressed() -> void:
	_bar.visible = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func(): visible = false)

# ═══════════════════════════════════════════════════════════════
# PRIMITIVES
# ═══════════════════════════════════════════════════════════════

func _sb(bg: Color, border: Color, bw: int, cr: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.corner_radius_top_left     = cr
	s.corner_radius_top_right    = cr
	s.corner_radius_bottom_right = cr
	s.corner_radius_bottom_left  = cr
	return s

func _add_panel(parent: Control, pos: Vector2, sz: Vector2, bg: Color,
				border: Color, bw: int, cr: int, cr_bottom: int) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size     = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color     = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.corner_radius_top_left     = cr
	s.corner_radius_top_right    = cr
	s.corner_radius_bottom_right = cr_bottom if cr_bottom > 0 else cr
	s.corner_radius_bottom_left  = cr_bottom if cr_bottom > 0 else cr
	p.add_theme_stylebox_override("panel", s)
	parent.add_child(p)
	return p

func _cr(pos: Vector2, sz: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.position = pos
	r.size     = sz
	r.color    = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)

func _cr_child(parent: Control, pos: Vector2, sz: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.position = pos
	r.size     = sz
	r.color    = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)

func _lbl(parent: Control, text: String, pos: Vector2, sz: Vector2, font_sz: int,
		  col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
		  shadow: Color = Color(0,0,0,0), sx: int = 0, sy: int = 0) -> void:
	var l := Label.new()
	l.text     = text
	l.position = pos
	l.size     = sz
	l.horizontal_alignment = align
	l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_sz)
	l.add_theme_color_override("font_color", col)
	if shadow.a > 0:
		l.add_theme_color_override("font_shadow_color", shadow)
		l.add_theme_constant_override("shadow_offset_x", sx)
		l.add_theme_constant_override("shadow_offset_y", sy)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)

func _ornament(x: float, y: float, w: float) -> void:
	_ornament_child(self, x, y, w)

func _ornament_child(parent: Control, x: float, y: float, w: float) -> void:
	# Main line
	var r := ColorRect.new()
	r.position = Vector2(x + 16, y + 1)
	r.size     = Vector2(w - 32, 2)
	r.color    = C_BRONZE.darkened(0.30)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	# Left/right diamonds
	for lp: Vector2 in [Vector2(x, y - 6), Vector2(x + w - 16, y - 6)]:
		var d := Label.new()
		d.text     = "◆"
		d.position = lp
		d.size     = Vector2(18, 18)
		d.add_theme_font_size_override("font_size", 14)
		d.add_theme_color_override("font_color", C_CRIMSON)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(d)
	# Centre ⚜
	var fl := Label.new()
	fl.text     = "⚜"
	fl.position = Vector2(x + w / 2.0 - 12, y - 8)
	fl.size     = Vector2(24, 18)
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fl.add_theme_font_size_override("font_size", 16)
	fl.add_theme_color_override("font_color", C_BRONZE.darkened(0.18))
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fl)

func _style_iron(btn: Button, golden: bool = false) -> void:
	var trim  := C_GOLD  if golden else C_SILVER
	var fcol  := C_GOLD  if golden else C_BONE
	var fcolh := C_GOLD  if golden else C_SILVER.lightened(0.18)

	var n := _sb(C_IRON, trim.darkened(0.22), 4, 4)
	n.shadow_color = Color(0,0,0,0.72)
	n.shadow_size  = 7
	btn.add_theme_stylebox_override("normal", n)

	var h := _sb(C_IRON_L, trim, 5, 4)
	h.shadow_color = trim.lightened(0.08)
	h.shadow_size  = 14
	btn.add_theme_stylebox_override("hover", h)

	btn.add_theme_stylebox_override("pressed", _sb(Color(0.06, 0.04, 0.02), trim.darkened(0.28), 3, 4))
	btn.add_theme_stylebox_override("focus",   _sb(C0, C0, 0, 0))

	btn.add_theme_color_override("font_color",         fcol)
	btn.add_theme_color_override("font_hover_color",   fcolh)
	btn.add_theme_color_override("font_pressed_color", fcol.darkened(0.32))
	btn.add_theme_color_override("font_shadow_color",  Color(0,0,0,0.92))
	btn.add_theme_constant_override("shadow_offset_x", 2)
	btn.add_theme_constant_override("shadow_offset_y", 3)
