extends Panel

# ═══════════════════════════════════════════════════════════════════════════
# CharacterSelect — η οθόνη «Η Ομάδα σου» (party slots)
# ═══════════════════════════════════════════════════════════════════════════
# Grid 6 party slots (2×3). Τα 2 πρώτα ξεκλείδωτα, τα 4 κλειδωμένα (μελλοντικό
# unlock). Κάθε ξεκλείδωτο slot: ή κρατά έναν ήρωα (avatar+όνομα+mini stats),
# ή είναι κενό (＋). Πατώντας ξεκλείδωτο slot ανοίγει το HeroSlotPopup όπου
# διαλέγεις ήρωα + items. ΟΛΑ τα δεδομένα ζουν στο Heroes autoload· εδώ μόνο UI.
# Το grid ξαναχτίζεται σε κάθε Heroes.changed (ανάθεση/αγορά/εξοπλισμός).

# ── Palette ───────────────────────────────────────────────────────
const C0  := Color(0, 0, 0, 0)
const C_BG   := Color(0.032, 0.022, 0.010, 0.82)
const C_DARK := Color(0.055, 0.038, 0.018)
const C_MID  := Color(0.095, 0.068, 0.035)
const C_IRON := Color(0.185, 0.168, 0.140)
const C_IRON_L := Color(0.265, 0.242, 0.208)
const C_SILVER := Color(0.572, 0.548, 0.510)
const C_BRONZE := Color(0.435, 0.308, 0.072)
const C_GOLD   := Color(0.820, 0.645, 0.118)
const C_GOLD_D := Color(0.268, 0.192, 0.032)
const C_CRIMSON:= Color(0.455, 0.030, 0.030)
const C_BONE   := Color(0.868, 0.830, 0.685)
const C_BONE_D := Color(0.415, 0.378, 0.290)
const C_MAGIC  := Color(0.375, 0.130, 0.618)
const C_BUFF   := Color(0.46, 0.80, 0.46)

# ── Fixed layout (1080 × 1920) ───────────────────────────────────
const HDR_H  := 278.0
const BAR_H  := 60.0
const MX     := 40.0
const GX     := 20.0
const GY     := 18.0
const PW     := (1080.0 - MX * 2.0 - GX) / 2.0     # ≈ 490
const PH     := ((1920.0 - HDR_H - BAR_H - 50.0) - GY * 2.0) / 3.0
const GRID_Y := HDR_H + 18.0
const AI     := 10.0
const PLH    := 92.0   # name-plate height (λίγο ψηλότερο για τη γραμμή stats)

var _grid_root: Control            # όλα τα cards — καθαρίζεται/ξαναχτίζεται
var _hero_popup: HeroSlotPopup

func _ready() -> void:
	_overlay()
	_header()
	_grid_root = Control.new()
	_grid_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid_root)
	_hero_popup = preload("res://Scenes/HeroSlotPopup.tscn").instantiate()
	add_child(_hero_popup)
	Heroes.changed.connect(_rebuild_grid)
	_rebuild_grid()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.30)

func show_screen() -> void:
	visible = true
	_rebuild_grid()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.30)

# ═══════════════════════════════════════════════════════════════
# BACKGROUND OVERLAY
# ═══════════════════════════════════════════════════════════════
func _overlay() -> void:
	var ov := ColorRect.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.color = C_BG
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ov)
	_cr(Vector2(0, 1540), Vector2(1080, 380), Color(0, 0, 0, 0.72))
	_cr(Vector2(0, 0), Vector2(1080, 200), Color(0, 0, 0, 0.40))
	_cr(Vector2(0, 0), Vector2(80, 1920), Color(0, 0, 0, 0.28))
	_cr(Vector2(1000, 0), Vector2(80, 1920), Color(0, 0, 0, 0.28))
	_circle_glow(Vector2(540, 0), 420, Color(0.65, 0.35, 0.08), 0.045)
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
	_add_panel(self, Vector2(0, 0), Vector2(1080, HDR_H), Color(0.048, 0.032, 0.015, 0.96), C_BRONZE, 0, 4, 0)
	_cr(Vector2(0, HDR_H - 4), Vector2(1080, 4), C_GOLD)
	_cr(Vector2(0, HDR_H),     Vector2(1080, 2), C_CRIMSON)
	for xv: float in [0.0, 1052.0]:
		_add_panel(self, Vector2(xv, 0), Vector2(28, HDR_H), Color(0.065, 0.044, 0.020, 0.92), C_BRONZE, 0, 0, 0)

	var back := Button.new()
	back.text     = "◄  ΠΙΣΩ"
	back.position = Vector2(38, 84)
	back.size     = Vector2(208, 100)
	_style_iron(back)
	back.add_theme_font_size_override("font_size", 36)
	add_child(back)
	back.pressed.connect(_on_back_pressed)

	const TITLE_BX := 266.0
	const TITLE_BW := 680.0
	const TITLE_BY := 36.0
	const TITLE_BH := 116.0
	_add_panel(self, Vector2(TITLE_BX + 4, TITLE_BY + 4), Vector2(TITLE_BW, TITLE_BH), Color(0,0,0,0.65), C0, 0, 6, 0)
	_add_panel(self, Vector2(TITLE_BX, TITLE_BY), Vector2(TITLE_BW, TITLE_BH), Color(0.065, 0.044, 0.020), C_GOLD, 4, 6, 0)
	_add_panel(self, Vector2(TITLE_BX + 6, TITLE_BY + 6), Vector2(TITLE_BW - 12, TITLE_BH - 12), C0, C_GOLD_D, 1, 3, 0)
	_lbl(self, "Η ΟΜΑΔΑ ΣΟΥ", Vector2(TITLE_BX, TITLE_BY), Vector2(TITLE_BW, TITLE_BH),
		 56, C_BONE, HORIZONTAL_ALIGNMENT_CENTER, Color(0,0,0,0.95), 3, 4)
	_lbl(self, "Πάτα μια θέση για να βάλεις ήρωα", Vector2(0, 183), Vector2(1080, 50),
		 28, Color(0.50, 0.40, 0.22), HORIZONTAL_ALIGNMENT_CENTER)
	_ornament(56, 244, 968)

# ═══════════════════════════════════════════════════════════════
# SLOTS GRID
# ═══════════════════════════════════════════════════════════════
func _rebuild_grid() -> void:
	if _grid_root == null:
		return
	for c in _grid_root.get_children():
		c.queue_free()
	for i in range(Heroes.NUM_SLOTS):
		var row := int(i / 2.0)
		var col := i % 2
		_slot_card(i, MX + col * (PW + GX), GRID_Y + row * (PH + GY))

func _slot_card(idx: int, x: float, y: float) -> void:
	var unlocked: bool = Heroes.is_slot_unlocked(idx)
	var hero: Dictionary = Heroes.get_slot_hero(idx)
	var has_hero: bool = not hero.is_empty()
	var art_h: float = PH - PLH - AI

	# Shadow
	_add_panel(_grid_root, Vector2(x + 7, y + 9), Vector2(PW, PH), Color(0,0,0,0.78), C0, 0, 5, 0)

	# Aura for occupied unlocked slots
	if unlocked and has_hero:
		var glow := Panel.new()
		glow.position = Vector2(x - 8, y - 8)
		glow.size     = Vector2(PW + 16, PH + 16)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gs := StyleBoxFlat.new()
		gs.bg_color = C0
		gs.border_color = Color(C_MAGIC.r, C_MAGIC.g, C_MAGIC.b, 0.72)
		gs.set_border_width_all(3); gs.set_corner_radius_all(8)
		gs.shadow_color = Color(C_MAGIC.r, C_MAGIC.g, C_MAGIC.b, 0.88); gs.shadow_size = 22
		glow.add_theme_stylebox_override("panel", gs)
		_grid_root.add_child(glow)
		# ΠΡΟΣΟΧΗ: glow.create_tween() (ΟΧΙ create_tween()) — το tween δένεται
		# στον ΙΔΙΟ τον glow, οπότε πεθαίνει μαζί του στο _rebuild_grid(). Με
		# create_tween() δενόταν σε ΕΜΑΣ (CharacterSelect) και επιβίωνε μετά το
		# queue_free() του στόχου: η διάρκειά του κατέρρεε στο 0 και με το
		# set_loops() ο Godot πετούσε "Infinite loop detected" σε κάθε rebuild.
		var tw := glow.create_tween()
		tw.set_loops()
		tw.tween_property(glow, "modulate:a", 0.18, 2.2)
		tw.tween_property(glow, "modulate:a", 1.00, 2.2)

	var border_col := C_GOLD if unlocked else C_GOLD_D
	_add_panel(_grid_root, Vector2(x, y), Vector2(PW, PH), C_DARK, border_col, 9, 5, 0)
	_cr_child(_grid_root, Vector2(x, y), Vector2(PW, 3), Color(1, 1, 1, 0.055))
	_cr_child(_grid_root, Vector2(x, y + PH - 3), Vector2(PW, 3), Color(0, 0, 0, 0.78))
	_add_panel(_grid_root, Vector2(x + 9, y + 9), Vector2(PW - 18, PH - 18), C0, border_col.darkened(0.38), 1, 3, 0)
	_brackets(x, y, PW, PH, border_col)

	# Art background
	var art_col := C_MAGIC if (unlocked and has_hero) else Color(0.10, 0.10, 0.12)
	_add_panel(_grid_root, Vector2(x + AI, y + AI), Vector2(PW - AI*2, art_h),
			   art_col.darkened(0.55 if not unlocked else 0.30), C0, 0, 0, 0)

	if unlocked and has_hero:
		var tex := Heroes.hero_texture(hero)
		if tex != null:
			# ΟΝΟΜΑ: «art», ΟΧΙ «tr» — το tr() είναι ήδη μέθοδος του Object
			# (μετάφραση), οπότε μια τοπική «tr» το σκιάζει και ο Godot βγάζει
			# warning σε κάθε reload.
			var art := TextureRect.new()
			# EXPAND_IGNORE_SIZE + ΣΕΙΡΑ: το expand_mode μπαίνει ΠΡΙΝ το size,
			# αλλιώς το Godot κλειδώνει το size στο φυσικό μέγεθος της υφής και
			# ψηλές φιγούρες ξεχειλίζουν. Με IGNORE_SIZE (πρώτα) το .size (το
			# κουτί) γίνεται σεβαστό και η εικόνα χωράει ΟΛΟΚΛΗΡΗ (contain-fit).
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			art.texture = tex
			art.position = Vector2(x + AI, y + AI)
			art.size = Vector2(PW - AI*2, art_h)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_grid_root.add_child(art)
		_lbl(_grid_root, "★", Vector2(x + PW - 50, y + AI + 4), Vector2(40, 40),
			 36, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, Color(0,0,0,0.95), 2, 2)
	elif unlocked:
		# Empty unlocked slot — big plus
		_lbl(_grid_root, "＋", Vector2(x + AI, y + AI), Vector2(PW - AI*2, art_h),
			 120, C_BONE_D, HORIZONTAL_ALIGNMENT_CENTER)

	# Vignette
	var vig := Panel.new()
	vig.position = Vector2(x + AI, y + AI)
	vig.size     = Vector2(PW - AI*2, art_h)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vs := StyleBoxFlat.new()
	vs.bg_color = C0
	vs.border_color = Color(0, 0, 0, 0.70 if not unlocked else 0.50)
	vs.set_border_width_all(18)
	vig.add_theme_stylebox_override("panel", vs)
	_grid_root.add_child(vig)

	_badge(str(idx + 1), x + AI + 2, y + AI + 2, unlocked)

	# Name plate
	_slot_plate(idx, unlocked, hero, x, y)

	# Locked overlay
	if not unlocked:
		_cr_child(_grid_root, Vector2(x + AI, y + AI), Vector2(PW - AI*2, art_h), Color(0.03, 0.02, 0.05, 0.70))
		_shield_lock(x + PW / 2.0, y + AI + art_h * 0.42)

	# Clickable button (unlocked only)
	var btn := Button.new()
	btn.position = Vector2(x, y)
	btn.size     = Vector2(PW, PH)
	btn.add_theme_stylebox_override("normal",  _sb(C0, C0, 0, 5))
	btn.add_theme_stylebox_override("hover",   _sb(Color(0.36, 0.12, 0.60, 0.14) if unlocked else Color(0.48,0.03,0.03,0.10), C0, 0, 5))
	btn.add_theme_stylebox_override("pressed", _sb(C0, C0, 0, 5))
	btn.add_theme_stylebox_override("focus",   _sb(C0, C0, 0, 5))
	_grid_root.add_child(btn)
	if unlocked:
		btn.pressed.connect(func(): _hero_popup.open(idx))

func _slot_plate(idx: int, unlocked: bool, hero: Dictionary, x: float, y: float) -> void:
	var py := y + PH - PLH
	_cr_child(_grid_root, Vector2(x + 3, py + 4), Vector2(PW, PLH), Color(0,0,0,0.70))
	_add_panel(_grid_root, Vector2(x, py), Vector2(PW, PLH), C_DARK,
			   C_BRONZE if unlocked else C_BRONZE.darkened(0.42), 0, 5, 0)
	_cr_child(_grid_root, Vector2(x, py), Vector2(PW, 4), C_GOLD if unlocked else C_GOLD_D)

	if not unlocked:
		_lbl(_grid_root, "Θέση %d" % (idx + 1), Vector2(x, py + 6), Vector2(PW, 42),
			 30, C_BONE_D, HORIZONTAL_ALIGNMENT_CENTER, Color(0,0,0,0.9), 2, 3)
		_lbl(_grid_root, "— Κλειδωμένο —", Vector2(x, py + 50), Vector2(PW, 30), 20,
			 Color(0.28, 0.20, 0.08, 0.68), HORIZONTAL_ALIGNMENT_CENTER)
		return
	if hero.is_empty():
		_lbl(_grid_root, "Κενή Θέση", Vector2(x, py + 6), Vector2(PW, 42),
			 30, C_BONE, HORIZONTAL_ALIGNMENT_CENTER, Color(0,0,0,0.9), 2, 3)
		_lbl(_grid_root, "— Πάτα για ήρωα —", Vector2(x, py + 50), Vector2(PW, 30), 20,
			 C_BRONZE, HORIZONTAL_ALIGNMENT_CENTER)
		return
	_lbl(_grid_root, str(hero["name"]), Vector2(x, py + 6), Vector2(PW, 40),
		 28, C_BONE, HORIZONTAL_ALIGNMENT_CENTER, Color(0,0,0,0.95), 2, 3)
	var fin := Heroes.get_final_stats(hero)
	var stats_line := "%s%d  %s%d  %s%d  %s%d" % [
		Heroes.STAT_ICONS["HP"], fin["HP"],
		Heroes.STAT_ICONS["Damage"], fin["Damage"],
		Heroes.STAT_ICONS["Shield"], fin["Shield"],
		Heroes.STAT_ICONS["AttackSpeed"], fin["AttackSpeed"]]
	_lbl(_grid_root, stats_line, Vector2(x, py + 48), Vector2(PW, 34), 22,
		 C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)

# ─── card helpers (draw into _grid_root) ───────────────────────
func _brackets(x: float, y: float, w: float, h: float, col: Color) -> void:
	const L := 28.0
	const T := 5.0
	const O := 8.0
	var bot_y: float = y + h - PLH - O - T
	var arms: Array[Rect2] = [
		Rect2(x + O, y + O, L, T), Rect2(x + O, y + O, T, L),
		Rect2(x + w - O - L, y + O, L, T), Rect2(x + w - O - T, y + O, T, L),
		Rect2(x + O, bot_y, L, T), Rect2(x + O, bot_y - L + T, T, L),
		Rect2(x + w - O - L, bot_y, L, T), Rect2(x + w - O - T, bot_y - L + T, T, L),
	]
	for r in arms:
		var p := Panel.new()
		p.position = r.position; p.size = r.size
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s := StyleBoxFlat.new()
		s.bg_color = col; s.border_color = col.lightened(0.25); s.set_border_width_all(1)
		p.add_theme_stylebox_override("panel", s)
		_grid_root.add_child(p)

func _badge(text: String, x: float, y: float, bright: bool) -> void:
	_add_panel(_grid_root, Vector2(x + 2, y + 2), Vector2(40, 40), Color(0,0,0,0.68), C0, 0, 3, 0)
	_add_panel(_grid_root, Vector2(x, y), Vector2(40, 40), C_MID,
			   C_BRONZE if bright else C_BRONZE.darkened(0.4), 2, 3, 0)
	_lbl(_grid_root, text, Vector2(x, y), Vector2(40, 40), 22,
		 C_GOLD if bright else C_GOLD_D, HORIZONTAL_ALIGNMENT_CENTER, Color(0,0,0,0.92), 1, 2)

func _shield_lock(cx: float, cy: float) -> void:
	const SW := 100.0
	const SH := 118.0
	var sx := cx - SW / 2.0
	var sy := cy - SH * 0.44
	for bx: float in [cx - 26.0, cx + 6.0]:
		var bar := Panel.new()
		bar.position = Vector2(bx, sy - 52); bar.size = Vector2(20, 56)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bs := _sb(Color(0.40, 0.28, 0.05), Color(0.60, 0.44, 0.08), 3, 10)
		bar.add_theme_stylebox_override("panel", bs)
		_grid_root.add_child(bar)
	var top := Panel.new()
	top.position = Vector2(cx - 26, sy - 52); top.size = Vector2(52, 20)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_stylebox_override("panel", _sb(Color(0.40, 0.28, 0.05), Color(0.60, 0.44, 0.08), 3, 10))
	_grid_root.add_child(top)
	_add_panel(_grid_root, Vector2(sx + 5, sy + 6), Vector2(SW, SH), Color(0,0,0,0.80), C0, 0, 0, 50)
	_add_panel(_grid_root, Vector2(sx, sy), Vector2(SW, SH), Color(0.28, 0.19, 0.04), C_BRONZE, 5, 6, 50)
	_add_panel(_grid_root, Vector2(sx + 5, sy + 5), Vector2(SW - 10, SH - 10), Color(0.18, 0.12, 0.02), C0, 0, 4, 48)
	_add_panel(_grid_root, Vector2(cx-12, sy + SH*0.38), Vector2(24, 24), Color(0.05, 0.03, 0.01), C_BRONZE.darkened(0.30), 1, 0, 12)
	_cr_child(_grid_root, Vector2(cx - 6, sy + SH*0.38 + 19), Vector2(12, 20), Color(0.05, 0.03, 0.01))

# ═══════════════════════════════════════════════════════════════
# SIGNAL HANDLERS
# ═══════════════════════════════════════════════════════════════
func _on_back_pressed() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func(): visible = false)

# ═══════════════════════════════════════════════════════════════
# PRIMITIVES
# ═══════════════════════════════════════════════════════════════
func _sb(bg: Color, border: Color, bw: int, cr: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = border
	s.set_border_width_all(bw); s.set_corner_radius_all(cr)
	return s

func _add_panel(parent: Control, pos: Vector2, sz: Vector2, bg: Color,
				border: Color, bw: int, cr: int, cr_bottom: int) -> Panel:
	var p := Panel.new()
	p.position = pos; p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = border
	s.set_border_width_all(bw)
	s.corner_radius_top_left = cr
	s.corner_radius_top_right = cr
	s.corner_radius_bottom_right = cr_bottom if cr_bottom > 0 else cr
	s.corner_radius_bottom_left  = cr_bottom if cr_bottom > 0 else cr
	p.add_theme_stylebox_override("panel", s)
	parent.add_child(p)
	return p

func _cr(pos: Vector2, sz: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.position = pos; r.size = sz; r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)

func _cr_child(parent: Control, pos: Vector2, sz: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.position = pos; r.size = sz; r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)

func _lbl(parent: Control, text: String, pos: Vector2, sz: Vector2, font_sz: int,
		  col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
		  shadow: Color = Color(0,0,0,0), sx: int = 0, sy: int = 0) -> void:
	var l := Label.new()
	l.text = text; l.position = pos; l.size = sz
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
	var r := ColorRect.new()
	r.position = Vector2(x + 16, y + 1); r.size = Vector2(w - 32, 2)
	r.color = C_BRONZE.darkened(0.30); r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	for lp: Vector2 in [Vector2(x, y - 6), Vector2(x + w - 16, y - 6)]:
		var d := Label.new()
		d.text = "◆"; d.position = lp; d.size = Vector2(18, 18)
		d.add_theme_font_size_override("font_size", 14)
		d.add_theme_color_override("font_color", C_CRIMSON)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(d)
	var fl := Label.new()
	fl.text = "⚜"; fl.position = Vector2(x + w / 2.0 - 12, y - 8); fl.size = Vector2(24, 18)
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fl.add_theme_font_size_override("font_size", 16)
	fl.add_theme_color_override("font_color", C_BRONZE.darkened(0.18))
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fl)

func _style_iron(btn: Button, golden: bool = false) -> void:
	var trim  := C_GOLD  if golden else C_SILVER
	var fcol  := C_GOLD  if golden else C_BONE
	var fcolh := C_GOLD  if golden else C_SILVER.lightened(0.18)
	var n := _sb(C_IRON, trim.darkened(0.22), 4, 4)
	n.shadow_color = Color(0,0,0,0.72); n.shadow_size = 7
	btn.add_theme_stylebox_override("normal", n)
	var h := _sb(C_IRON_L, trim, 5, 4)
	h.shadow_color = trim.lightened(0.08); h.shadow_size = 14
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", _sb(Color(0.06, 0.04, 0.02), trim.darkened(0.28), 3, 4))
	btn.add_theme_stylebox_override("focus",   _sb(C0, C0, 0, 0))
	btn.add_theme_color_override("font_color",         fcol)
	btn.add_theme_color_override("font_hover_color",   fcolh)
	btn.add_theme_color_override("font_pressed_color", fcol.darkened(0.32))
	btn.add_theme_color_override("font_shadow_color",  Color(0,0,0,0.92))
	btn.add_theme_constant_override("shadow_offset_x", 2)
	btn.add_theme_constant_override("shadow_offset_y", 3)
