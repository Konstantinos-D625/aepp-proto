extends Control

# ── Μονοπάτια εικόνων ─────────────────────────────────────────────────────
const BG_PATH     := "res://Εικόνες/bl.background.png"
const CHAR_PATH   := "res://Εικόνες/blacksmith.png"
const BOARD_PATH  := "res://Εικόνες/board.png"
# Εδώ θα μπει η εικόνα-πρόβλημα αργότερα:
const PUZZLE_PATH := "res://Εικόνες/puzzle_image.png"

# ── Παλέτα ────────────────────────────────────────────────────────────────
const C0       := Color(0, 0, 0, 0)
const C_GOLD   := Color(0.940, 0.760, 0.160)
const C_GOLD_D := Color(0.360, 0.278, 0.058)
const C_GOLD_S := Color(1.000, 0.920, 0.560)
const C_PARCH  := Color(0.960, 0.920, 0.760)   # χρώμα περγαμηνής
const C_PARCH_D:= Color(0.820, 0.760, 0.560)
const C_WOOD   := Color(0.200, 0.120, 0.052)
const C_WOOD_D := Color(0.130, 0.075, 0.028)
const C_IRON   := Color(0.148, 0.140, 0.128)
const C_TEXT   := Color(0.130, 0.072, 0.022)   # σκούρο καφέ για κείμενο
const C_CRIMSON:= Color(0.580, 0.058, 0.058)

const W := 1080.0
const H := 1920.0

# ── Κατάσταση ─────────────────────────────────────────────────────────────
var _state  := 0   # 1 = blacksmith μιλάει, 2 = board με εικόνα
var _char   : TextureRect
var _bubble : Control
var _board  : Control
var _hint   : Label

# ═══════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_build()
	gui_input.connect(_on_gui_input)

# Καλείται από το Houses/House3 pressed signal
func show_popup() -> void:
	visible   = true
	_state    = 1
	_char.visible    = true
	_char.modulate.a = 1.0
	_bubble.visible  = true
	_bubble.modulate.a = 1.0
	_board.visible   = false
	_hint.visible    = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.45)

func _close() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.30)
	tw.tween_callback(func(): visible = false)

# ── Χειρισμός κλικ ────────────────────────────────────────────────────────
func _on_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _state == 1:
		_go_to_state2()
	accept_event()

# ═══════════════════════════════════════════════════════════════════════════
# ΚΑΤΑΣΤΑΣΗ 2 — blacksmith φεύγει, board εμφανίζεται
# ═══════════════════════════════════════════════════════════════════════════
func _go_to_state2() -> void:
	_state = 2
	_hint.visible = false
	var tw := create_tween()
	# Fade out character + bubble παράλληλα
	tw.tween_property(_char,   "modulate:a", 0.0, 0.40)
	tw.parallel().tween_property(_bubble, "modulate:a", 0.0, 0.35)
	# Μετά: κρύψε τους, δείξε board
	tw.tween_callback(func():
		_char.visible   = false
		_bubble.visible = false
		_board.modulate.a = 0.0
		_board.visible  = true
		var tw2 := create_tween()
		tw2.tween_property(_board, "modulate:a", 1.0, 0.55)
	)

# ═══════════════════════════════════════════════════════════════════════════
# ΚΑΤΑΣΚΕΥΗ UI
# ═══════════════════════════════════════════════════════════════════════════
func _build() -> void:
	_build_background()
	_char   = _build_character()
	_bubble = _build_bubble()
	_board  = _build_board()
	_board.visible = false
	_hint   = _build_hint()
	_build_back_button()

# ── Φόντο ─────────────────────────────────────────────────────────────────
func _build_background() -> void:
	var tex : Texture2D = load(BG_PATH)
	var bg  := TextureRect.new()
	if tex:
		bg.texture = tex
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Ελαφρύ σκοτάδι για να ξεχωρίζουν τα στοιχεία
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.38)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

# ── Χαρακτήρας blacksmith ─────────────────────────────────────────────────
func _build_character() -> TextureRect:
	var tex : Texture2D = load(CHAR_PATH)
	var char_rect := TextureRect.new()
	if tex:
		char_rect.texture = tex
	# Δεξί μέρος οθόνης, κεντρο-κάτω
	char_rect.position     = Vector2(530, 580)
	char_rect.size         = Vector2(510, 960)
	char_rect.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	char_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	char_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(char_rect)
	return char_rect

# ── Φούσκα ομιλίας ────────────────────────────────────────────────────────
func _build_bubble() -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	const BX := 32.0
	const BY := 170.0
	const BW := 570.0
	const BH := 460.0

	# Σκιά
	_shadow(root, Vector2(BX+8, BY+8), Vector2(BW, BH), 18)

	# Κύριο πλαίσιο — περγαμηνή
	_styled_panel(root, Vector2(BX, BY), Vector2(BW, BH),
		C_PARCH, C_GOLD, 5, 18)
	# Εσωτερικό περίγραμμα
	_styled_panel(root, Vector2(BX+10, BY+10), Vector2(BW-20, BH-20),
		C0, C_GOLD_D, 2, 14)

	# Ουρά φούσκας (δείχνει προς τον blacksmith — κάτω-δεξιά)
	_bubble_tail(root, BX + BW - 48, BY + BH - 2)

	# Τίτλος — όνομα NPC
	_styled_panel(root, Vector2(BX+22, BY+22), Vector2(BW-44, 58),
		C_WOOD_D, C_GOLD_D, 2, 8)
	_label(root, "⚒  Γκάρεθ ο Σιδηρουργός",
		Vector2(BX+22, BY+22), Vector2(BW-44, 58),
		22, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER,
		Color(0,0,0,0.80), 1, 2)

	# Διαχωριστής
	_cr_on(root, Vector2(BX+30, BY+86), Vector2(BW-60, 2), C_GOLD_D)

	# Κείμενο ομιλίας
	var msg := Label.new()
	msg.text = "Α! Καλωσόρισες, περιπλανώμενε!\n\nΘα χαρώ να σε βοηθήσω\nμε υλικά για το ταξίδι σου...\n\nΑλλά πρώτα χρειάζομαι\nτη βοήθειά σου σε ένα\nμικρό πρόβλημα!"
	msg.position         = Vector2(BX+28, BY+96)
	msg.size             = Vector2(BW-56, BH-130)
	msg.autowrap_mode    = TextServer.AUTOWRAP_WORD_SMART
	msg.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	msg.add_theme_font_size_override("font_size", 28)
	msg.add_theme_color_override("font_color", C_TEXT)
	msg.add_theme_color_override("font_shadow_color", Color(1,1,1,0.30))
	msg.add_theme_constant_override("shadow_offset_x", 0)
	msg.add_theme_constant_override("shadow_offset_y", 1)
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(msg)

	# Αστεράκια / Disney sparkles γύρω από τη φούσκα
	_sparkle_dots(root, BX, BY, BW, BH)

	return root

func _bubble_tail(parent: Control, tx: float, ty: float) -> void:
	# Τριγωνοειδής ουρά από επικαλυπτόμενα ορθογώνια
	_cr_on(parent, Vector2(tx,    ty),    Vector2(32, 14), C_PARCH)
	_cr_on(parent, Vector2(tx+8,  ty+12), Vector2(22, 14), C_PARCH)
	_cr_on(parent, Vector2(tx+16, ty+24), Vector2(14, 14), C_PARCH)
	# Χρυσή περιγραφή ουράς
	_cr_on(parent, Vector2(tx-1,  ty-1),  Vector2(34, 5),  C_GOLD)
	_cr_on(parent, Vector2(tx+31, ty+2),  Vector2(5, 14),  C_GOLD)

func _sparkle_dots(parent: Control, bx: float, by: float, bw: float, bh: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for _i in range(8):
		var sz  := 4.0 + rng.randf() * 6.0
		var sp  := ColorRect.new()
		var pos := Vector2(
			bx + rng.randf_range(-20, bw+20),
			by + rng.randf_range(-20, bh+20)
		)
		sp.position    = pos
		sp.size        = Vector2(sz, sz)
		sp.color       = Color(C_GOLD_S.r, C_GOLD_S.g, C_GOLD_S.b, 0.0)
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(sp)
		var tw := create_tween()
		tw.set_loops()
		tw.tween_property(sp, "color:a", 0.0,  rng.randf_range(0.6, 2.0)).set_delay(rng.randf()*3.0)
		tw.tween_property(sp, "color:a", 0.90, 0.12)
		tw.tween_property(sp, "color:a", 0.0,  0.35)

# ── Board (Κατάσταση 2) ───────────────────────────────────────────────────
func _build_board() -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Board.png ως φόντο — κεντρικά
	const BRD_X := 60.0
	const BRD_Y := 220.0
	const BRD_W := 960.0
	const BRD_H := 1320.0

	var brd_tex : Texture2D = load(BOARD_PATH)
	var brd := TextureRect.new()
	if brd_tex:
		brd.texture = brd_tex
	brd.position    = Vector2(BRD_X, BRD_Y)
	brd.size        = Vector2(BRD_W, BRD_H)
	brd.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	brd.stretch_mode= TextureRect.STRETCH_SCALE
	brd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(brd)

	# Εσωτερικό — περιοχή για την εικόνα-πρόβλημα
	const IMG_X := BRD_X + 80.0
	const IMG_Y := BRD_Y + 120.0
	const IMG_W := BRD_W - 160.0
	const IMG_H := BRD_H - 240.0

	var puzzle_tex : Texture2D = null
	if ResourceLoader.exists(PUZZLE_PATH):
		puzzle_tex = load(PUZZLE_PATH)
	var img := TextureRect.new()
	if puzzle_tex:
		img.texture     = puzzle_tex
		img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		img.stretch_mode= TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		# Placeholder μέχρι να μπει η εικόνα
		var ph := Panel.new()
		ph.position = Vector2(IMG_X, IMG_Y)
		ph.size     = Vector2(IMG_W, IMG_H)
		ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s := StyleBoxFlat.new()
		s.bg_color     = Color(0.08, 0.055, 0.025, 0.85)
		s.border_color = C_GOLD_D
		s.set_border_width_all(3)
		s.set_corner_radius_all(8)
		ph.add_theme_stylebox_override("panel", s)
		root.add_child(ph)
		var pl := Label.new()
		pl.text     = "[ Εδώ θα εμφανιστεί\nη εικόνα-πρόβλημα ]"
		pl.position = Vector2(IMG_X, IMG_Y)
		pl.size     = Vector2(IMG_W, IMG_H)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		pl.add_theme_font_size_override("font_size", 32)
		pl.add_theme_color_override("font_color", C_GOLD_D)
		pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(pl)

	img.position    = Vector2(IMG_X, IMG_Y)
	img.size        = Vector2(IMG_W, IMG_H)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(img)

	return root

# ── Hint "Πάτα για να συνεχίσεις" ─────────────────────────────────────────
func _build_hint() -> Label:
	var l := Label.new()
	l.text     = "✦  Πάτα οπουδήποτε για να συνεχίσεις  ✦"
	l.position = Vector2(0, H - 190)
	l.size     = Vector2(W, 50)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", C_PARCH_D)
	l.add_theme_color_override("font_shadow_color", Color(0,0,0,0.90))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	# Αναβοσβήνει
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(l, "modulate:a", 0.25, 1.0)
	tw.tween_property(l, "modulate:a", 1.00, 1.0)
	return l

# ── Κουμπί Πίσω ───────────────────────────────────────────────────────────
func _build_back_button() -> void:
	# Σκιά
	_shadow_plain(Vector2(W/2 - 195, H - 134), Vector2(390, 84))

	var btn := Button.new()
	btn.text     = "◄   Πίσω στο Χωριό"
	btn.position = Vector2(W/2 - 195, H - 138)
	btn.size     = Vector2(390, 84)
	btn.add_theme_font_size_override("font_size", 30)
	_style_back_btn(btn)
	add_child(btn)
	btn.pressed.connect(_close)

# ═══════════════════════════════════════════════════════════════════════════
# ΒΟΗΘΗΤΙΚΕΣ ΣΥΝΑΡΤΗΣΕΙΣ
# ═══════════════════════════════════════════════════════════════════════════

func _styled_panel(parent: Control, pos: Vector2, sz: Vector2,
				   bg: Color, border: Color, bw: int, cr: int) -> Panel:
	var p := Panel.new()
	p.position = pos; p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color     = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(cr)
	p.add_theme_stylebox_override("panel", s)
	parent.add_child(p)
	return p

func _shadow(parent: Control, pos: Vector2, sz: Vector2, cr: int) -> void:
	var p := Panel.new()
	p.position = pos; p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0.55)
	s.set_corner_radius_all(cr)
	s.shadow_color = Color(0, 0, 0, 0.40)
	s.shadow_size  = 20
	p.add_theme_stylebox_override("panel", s)
	parent.add_child(p)

func _shadow_plain(pos: Vector2, sz: Vector2) -> void:
	var p := Panel.new()
	p.position = pos + Vector2(5, 6)
	p.size     = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0.60)
	s.set_corner_radius_all(10)
	p.add_theme_stylebox_override("panel", s)
	add_child(p)

func _cr_on(parent: Control, pos: Vector2, sz: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.position = pos; r.size = sz; r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)

func _label(parent: Control, text: String, pos: Vector2, sz: Vector2,
			fsz: int, col: Color,
			align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
			shadow: Color = Color(0,0,0,0), sx: int = 0, sy: int = 0) -> Label:
	var l := Label.new()
	l.text = text; l.position = pos; l.size = sz
	l.horizontal_alignment = align
	l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fsz)
	l.add_theme_color_override("font_color", col)
	if shadow.a > 0.0:
		l.add_theme_color_override("font_shadow_color", shadow)
		l.add_theme_constant_override("shadow_offset_x", sx)
		l.add_theme_constant_override("shadow_offset_y", sy)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _style_back_btn(btn: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = C_WOOD_D; n.border_color = C_GOLD.darkened(0.15)
	n.set_border_width_all(4); n.set_corner_radius_all(10)
	n.shadow_color = Color(0,0,0,0.68); n.shadow_size = 7
	btn.add_theme_stylebox_override("normal", n)

	var h := StyleBoxFlat.new()
	h.bg_color = C_WOOD; h.border_color = C_GOLD
	h.set_border_width_all(5); h.set_corner_radius_all(10)
	h.shadow_color = C_GOLD.lightened(0.10); h.shadow_size = 16
	btn.add_theme_stylebox_override("hover", h)

	var pr := StyleBoxFlat.new()
	pr.bg_color = Color(0.055,0.028,0.008); pr.border_color = C_GOLD.darkened(0.25)
	pr.set_border_width_all(3); pr.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("pressed", pr)
	btn.add_theme_stylebox_override("focus", StyleBoxFlat.new())

	btn.add_theme_color_override("font_color",         C_GOLD)
	btn.add_theme_color_override("font_hover_color",   C_GOLD_S)
	btn.add_theme_color_override("font_pressed_color", C_GOLD.darkened(0.30))
	btn.add_theme_color_override("font_shadow_color",  Color(0,0,0,0.92))
	btn.add_theme_constant_override("shadow_offset_x", 2)
	btn.add_theme_constant_override("shadow_offset_y", 3)
