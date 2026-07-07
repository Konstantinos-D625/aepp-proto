extends Control

# Popup "Νεράιδα στο Κλουβί": φυλακισμένη της μάγισσας μέσα στο δάσος.
# Κατάσταση 1: η νεράιδα μιλάει (ίδιο μοτίβο bubble+character με cotton_popup.gd/
# miner_popup.gd/blacksmith_popup.gd). Κατάσταση 2: αντί για quiz, δείχνει
# ΤΡΕΙΣ σταθερές ανταλλαγές — 1 Μαγική Σφαίρα -> +1 μόνιμο stat point (Σφαίρα
# Δύναμης -> Δύναμη, Σφαίρα Ταχύτητας -> Ταχύτητα, Σφαίρα Εξυπνάδας ->
# Εξυπνάδα). Ο παίκτης μπορεί να ανταλλάξει όσες φορές θέλει σε μία επίσκεψη
# (όσο έχει σφαίρες) — δεν είναι one-shot loot σαν τα άλλα NPC.
#
# Το μόνιμο bonus γράφεται στο GameData (GameData.add_stat_bonus), που είναι
# η ΜΟΝΑΔΙΚΗ πηγή τέτοιου bonus στο project — το CharacterEditPopup το
# διαβάζει με GameData.get_stat_bonus() και το προσθέτει στο bonus εξοπλισμού.
#
# Ίδιο navigation μοτίβο με WitchHouseButton -> BossPopup: ανοίγει από ΚΩΔΙΚΑ
# (Scripts/witch_map_popup.gd), όχι από εύθραυστο connection στο Area1.tscn.

const BG_PATH   := "res://Εικόνες/fairy-bg.png"
const CHAR_PATH := "res://Εικόνες/fairy-in-cage.png"
const BOARD_PATH := "res://Εικόνες/board.png"

# Κάθε ανταλλαγή: 1 Μαγική Σφαίρα -> +1 στο αντίστοιχο μόνιμο stat.
const TRADES := [
	{ "currency": "Σφαίρα Δύναμης",   "stat": "Δύναμη",   "icon": "res://Εικόνες/red-orb.png" },
	{ "currency": "Σφαίρα Ταχύτητας", "stat": "Ταχύτητα", "icon": "res://Εικόνες/green-orb.png" },
	{ "currency": "Σφαίρα Εξυπνάδας", "stat": "Εξυπνάδα", "icon": "res://Εικόνες/blue-orb.png" },
]

# ── Παλέτα (μαγική/ψυχρή — ίδιο ύφος με boss_popup.gd, ταιριάζει με το δάσος) ─
const C0        := Color(0, 0, 0, 0)
const C_GOLD    := Color(0.940, 0.760, 0.160)
const C_GOLD_D  := Color(0.360, 0.278, 0.058)
const C_GOLD_S  := Color(1.000, 0.920, 0.560)
const C_PARCH   := Color(0.900, 0.860, 0.940)
const C_PARCH_D := Color(0.720, 0.680, 0.760)
const C_WOOD    := Color(0.200, 0.120, 0.052)
const C_WOOD_D  := Color(0.130, 0.075, 0.028)
const C_TEXT    := Color(0.110, 0.070, 0.030)
const C_MAGIC   := Color(0.420, 0.140, 0.640)
const C_OK      := Color(0.560, 0.900, 0.460)
const C_DISABLED:= Color(0.360, 0.330, 0.360)

const W := 1080.0
const H := 1920.0

# ── Κατάσταση ─────────────────────────────────────────────────────────────
var _state := 0   # 1 = η νεράιδα μιλάει, 2 = board με ανταλλαγές
var _char   : TextureRect
var _bubble : Control
var _board  : Control
var _hint   : Label
var _feedback : Label
var _owned_labels: Dictionary = {}   # currency -> Label (δείχνει πόσες έχεις)
var _trade_buttons: Dictionary = {}  # currency -> Button

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_build()
	gui_input.connect(_on_gui_input)
	Currency.changed.connect(_refresh_trade_rows)

func show_popup() -> void:
	visible   = true
	_state    = 1
	_char.visible      = true
	_char.modulate.a   = 1.0
	_bubble.visible    = true
	_bubble.modulate.a = 1.0
	_board.visible     = false
	_hint.visible      = true
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
# ΚΑΤΑΣΤΑΣΗ 2 — η νεράιδα σιωπά, το board με τις ανταλλαγές εμφανίζεται
# ═══════════════════════════════════════════════════════════════════════════
func _go_to_state2() -> void:
	_state = 2
	_hint.visible = false
	var tw := create_tween()
	tw.tween_property(_char,   "modulate:a", 0.0, 0.40)
	tw.parallel().tween_property(_bubble, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		_char.visible   = false
		_bubble.visible = false
		_board.modulate.a = 0.0
		_board.visible  = true
		_refresh_trade_rows()
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
	# Ψυχρό, μαγικό σκοτάδι — ίδιο με boss_popup.gd
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.0, 0.08, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

# ── Χαρακτήρας: το κλουβί με τη νεράιδα, δεξί μέρος οθόνης — ίδια θέση/
# λογική με cotton_popup.gd/miner_popup.gd/blacksmith_popup.gd. Η εικόνα
# είναι landscape (όχι portrait όπως οι άλλοι NPC), αλλά το
# STRETCH_KEEP_ASPECT_CENTERED τη χωράει σωστά μέσα στο ίδιο πλαίσιο χωρίς
# παραμόρφωση. ──────────────────────────────────────────────────────────────
func _build_character() -> TextureRect:
	var tex : Texture2D = load(CHAR_PATH)
	var char_rect := TextureRect.new()
	if tex:
		char_rect.texture = tex
	char_rect.position     = Vector2(500, 620)
	char_rect.size         = Vector2(550, 480)
	char_rect.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	char_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	char_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(char_rect)
	return char_rect

# ── Φούσκα ομιλίας — ίδια θέση/μέγεθος/tail με τα υπόλοιπα popups ──────────
func _build_bubble() -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	const BX := 32.0
	const BY := 155.0
	const BW := 570.0
	const BH := 480.0

	_shadow(root, Vector2(BX+8, BY+8), Vector2(BW, BH), 18)

	_styled_panel(root, Vector2(BX, BY), Vector2(BW, BH),
		C_PARCH, C_MAGIC, 5, 18)
	_styled_panel(root, Vector2(BX+10, BY+10), Vector2(BW-20, BH-20),
		C0, C_MAGIC.darkened(0.35), 2, 14)

	_bubble_tail(root, BX + BW - 48, BY + BH - 2)

	_styled_panel(root, Vector2(BX+22, BY+22), Vector2(BW-44, 58),
		C_WOOD_D, C_MAGIC.darkened(0.3), 2, 8)
	_label(root, "🧚  Φυλακισμένη Νεράιδα",
		Vector2(BX+22, BY+22), Vector2(BW-44, 58),
		22, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER,
		Color(0,0,0,0.80), 1, 2)

	_cr_on(root, Vector2(BX+30, BY+86), Vector2(BW-60, 2), C_MAGIC.darkened(0.3))

	var msg := Label.new()
	msg.text = "Ψιτ... εδώ πέρα!\n\nΗ μάγισσα με κρατάει κλεισμένη σε αυτό\nτο κλουβί, αλλά η μαγεία μου ακόμα\nλειτουργεί!\n\nΑν μου φέρεις Μαγικές Σφαίρες, μπορώ\nνα τις μετατρέψω σε πραγματική δύναμη\nγια σένα — μία σφαίρα, ένα μόνιμο\nστατιστικό. Έλα να δεις!"
	msg.position         = Vector2(BX+28, BY+96)
	msg.size             = Vector2(BW-56, BH-130)
	msg.autowrap_mode    = TextServer.AUTOWRAP_WORD_SMART
	msg.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	msg.add_theme_font_size_override("font_size", 25)
	msg.add_theme_color_override("font_color", C_TEXT)
	msg.add_theme_color_override("font_shadow_color", Color(1,1,1,0.28))
	msg.add_theme_constant_override("shadow_offset_x", 0)
	msg.add_theme_constant_override("shadow_offset_y", 1)
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(msg)

	_magic_sparkles(root, BX, BY, BW, BH)

	return root

func _bubble_tail(parent: Control, tx: float, ty: float) -> void:
	_cr_on(parent, Vector2(tx,    ty),    Vector2(32, 14), C_PARCH)
	_cr_on(parent, Vector2(tx+8,  ty+12), Vector2(22, 14), C_PARCH)
	_cr_on(parent, Vector2(tx+16, ty+24), Vector2(14, 14), C_PARCH)
	_cr_on(parent, Vector2(tx-1,  ty-1),  Vector2(34, 5),  C_MAGIC)
	_cr_on(parent, Vector2(tx+31, ty+2),  Vector2(5, 14),  C_MAGIC)

func _magic_sparkles(parent: Control, bx: float, by: float, bw: float, bh: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33221
	for _i in range(10):
		var sz  := 4.0 + rng.randf() * 6.0
		var sp  := ColorRect.new()
		sp.position = Vector2(
			bx + rng.randf_range(-20, bw+20),
			by + rng.randf_range(-20, bh+20)
		)
		sp.size        = Vector2(sz, sz)
		sp.color       = Color(C_MAGIC.r, C_MAGIC.g, C_MAGIC.b, 0.0)
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(sp)
		var tw := create_tween()
		tw.set_loops()
		tw.tween_property(sp, "color:a", 0.0,  rng.randf_range(0.6, 2.0)).set_delay(rng.randf()*3.0)
		tw.tween_property(sp, "color:a", 0.90, 0.12)
		tw.tween_property(sp, "color:a", 0.0,  0.35)

# ── Board (Κατάσταση 2) — 3 σταθερές ανταλλαγές ────────────────────────────
func _build_board() -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	const BRD_X := 60.0
	const BRD_Y := 220.0
	const BRD_W := 960.0
	const BRD_H := 1320.0

	var brd_tex : Texture2D = load(BOARD_PATH)
	var brd := TextureRect.new()
	if brd_tex:
		brd.texture = brd_tex
	brd.position     = Vector2(BRD_X, BRD_Y)
	brd.size         = Vector2(BRD_W, BRD_H)
	brd.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	brd.stretch_mode = TextureRect.STRETCH_SCALE
	brd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(brd)

	var pad := MarginContainer.new()
	pad.position = Vector2(BRD_X, BRD_Y)
	pad.size     = Vector2(BRD_W, BRD_H)
	pad.add_theme_constant_override("margin_left",   90)
	pad.add_theme_constant_override("margin_right",  90)
	# Ίδιο ζήτημα διάφανου περιθωρίου στην κορυφή του board.png όπως στο
	# miner_popup.gd — 340 το κατεβάζει καθαρά μέσα στο ορατό ξύλο.
	pad.add_theme_constant_override("margin_top",    340)
	pad.add_theme_constant_override("margin_bottom", 130)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)

	var title := Label.new()
	title.text = "🧚  Αντάλλαξε Μαγικές Σφαίρες για Στατιστικά!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", C_GOLD_S)
	title.add_theme_color_override("font_shadow_color", Color(0,0,0,0.85))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)

	for trade in TRADES:
		col.add_child(_make_trade_row(trade))

	_feedback = Label.new()
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.custom_minimum_size  = Vector2(0, 40)
	_feedback.add_theme_font_size_override("font_size", 26)
	_feedback.add_theme_color_override("font_color", C_OK)
	_feedback.add_theme_color_override("font_shadow_color", Color(0,0,0,0.85))
	_feedback.add_theme_constant_override("shadow_offset_x", 1)
	_feedback.add_theme_constant_override("shadow_offset_y", 2)
	_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_feedback)

	return root

## Μία γραμμή ανταλλαγής: εικονίδιο σφαίρας + πόσες έχεις + κουμπί
## ανταλλαγής (απενεργοποιημένο όταν δεν έχεις καμία).
func _make_trade_row(trade: Dictionary) -> Control:
	# ΔΕΝ χρησιμοποιεί το _styled_panel() helper εδώ, γιατί αυτό κάνει ήδη
	# add_child στο parent που του δίνεις — θα είχε προσθέσει το card ως
	# παιδί του self ΠΡΙΝ προλάβει το col.add_child(...) του καλούντος να το
	# τοποθετήσει σωστά μέσα στο VBoxContainer (Godot σκάει σε προσπάθεια
	# επανα-parenting node που έχει ήδη γονέα).
	var card := Panel.new()
	card.custom_minimum_size = Vector2(0, 130)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color     = C_WOOD_D
	card_sb.border_color = C_MAGIC.darkened(0.2)
	card_sb.set_border_width_all(2)
	card_sb.set_corner_radius_all(12)
	card.add_theme_stylebox_override("panel", card_sb)

	# "margin_left" δεν είναι έγκυρο theme constant για HBoxContainer (αυτό
	# είναι ιδιότητα MarginContainer) — το inset γίνεται εδώ με offset_left/
	# right πάνω στο ίδιο το FULL_RECT preset.
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left  = 20
	row.offset_right = -20
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var icon := TextureRect.new()
	var icon_path: String = str(trade["icon"])
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	icon.custom_minimum_size = Vector2(80, 80)
	icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 4)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = str(trade["currency"])
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", C_PARCH)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_lbl)

	var owned_lbl := Label.new()
	owned_lbl.add_theme_font_size_override("font_size", 20)
	owned_lbl.add_theme_color_override("font_color", C_PARCH_D)
	owned_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(owned_lbl)
	_owned_labels[trade["currency"]] = owned_lbl

	var btn := Button.new()
	btn.text = "+1 %s" % str(trade["stat"])
	btn.custom_minimum_size = Vector2(190, 84)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_trade_btn(btn)
	row.add_child(btn)
	btn.pressed.connect(_on_trade_pressed.bind(trade))
	_trade_buttons[trade["currency"]] = btn

	return card

func _refresh_trade_rows() -> void:
	for trade in TRADES:
		var currency: String = trade["currency"]
		var amount := Currency.get_amount(currency)
		if _owned_labels.has(currency):
			(_owned_labels[currency] as Label).text = "Έχεις: %d" % amount
		if _trade_buttons.has(currency):
			(_trade_buttons[currency] as Button).disabled = amount <= 0

func _on_trade_pressed(trade: Dictionary) -> void:
	var currency: String = trade["currency"]
	var stat: String = trade["stat"]
	if not Currency.spend({ currency: 1 }):
		return
	GameData.add_stat_bonus(stat, 1)
	_feedback.text = "✔  +1 %s!" % stat
	_refresh_trade_rows()

# ── Hint ──────────────────────────────────────────────────────────────────
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
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(l, "modulate:a", 0.25, 1.0)
	tw.tween_property(l, "modulate:a", 1.00, 1.0)
	return l

# ── Κουμπί Πίσω ───────────────────────────────────────────────────────────
func _build_back_button() -> void:
	_shadow_plain(Vector2(W/2 - 195, H - 134), Vector2(390, 84))

	var btn := Button.new()
	btn.text     = "◄   Πίσω στο Δάσος"
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

func _style_trade_btn(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", 22)
	var n := StyleBoxFlat.new()
	n.bg_color = C_MAGIC.darkened(0.35); n.border_color = C_GOLD.darkened(0.15)
	n.set_border_width_all(3); n.set_corner_radius_all(10)
	n.shadow_color = Color(0,0,0,0.60); n.shadow_size = 6
	btn.add_theme_stylebox_override("normal", n)

	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = C_MAGIC.darkened(0.15); h.border_color = C_GOLD
	h.shadow_color = C_GOLD.lightened(0.10); h.shadow_size = 14
	btn.add_theme_stylebox_override("hover", h)

	var pr := n.duplicate() as StyleBoxFlat
	pr.bg_color = C_MAGIC.darkened(0.5); pr.border_color = C_GOLD.darkened(0.25)
	btn.add_theme_stylebox_override("pressed", pr)

	var dis := n.duplicate() as StyleBoxFlat
	dis.bg_color = C_DISABLED.darkened(0.4); dis.border_color = C_DISABLED
	btn.add_theme_stylebox_override("disabled", dis)
	btn.add_theme_stylebox_override("focus", StyleBoxFlat.new())

	btn.add_theme_color_override("font_color",          C_GOLD_S)
	btn.add_theme_color_override("font_hover_color",    C_GOLD)
	btn.add_theme_color_override("font_pressed_color",  C_GOLD.darkened(0.30))
	btn.add_theme_color_override("font_disabled_color", C_PARCH_D.darkened(0.35))
	btn.add_theme_color_override("font_shadow_color",   Color(0,0,0,0.9))
	btn.add_theme_constant_override("shadow_offset_x", 1)
	btn.add_theme_constant_override("shadow_offset_y", 2)

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
