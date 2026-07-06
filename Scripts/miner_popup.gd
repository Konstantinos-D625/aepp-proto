extends Control

# ── Μονοπάτια εικόνων ─────────────────────────────────────────────────────
const BG_PATH     := "res://Εικόνες/mine.background.png"
const CHAR_PATH   := "res://Εικόνες/miner.png"
const BOARD_PATH  := "res://Εικόνες/board.png"

# ── Σύστημα ασκήσεων (αντιστοίχιση) ────────────────────────────────────────
# Αρχείο ασκήσεων για αυτό το σπίτι/NPC — ίδιο μοτίβο με το
# QUIZ_PATH/cotton_quiz.json του cotton_popup.gd, απλώς με τη μορφή
# αντιστοίχισης που καταλαβαίνει το MatchingQuizManager.
const QUIZ_PATH := "res://miner_quiz.json"

# Κάθε επίσκεψη = 3 διαφορετικές ασκήσεις αντιστοίχισης (γύροι), τυχαία
# επιλεγμένες από το pool — ίδια λογική με το QUESTIONS_PER_ROUND του
# cotton_popup.gd, απλώς κάθε "ερώτηση" εδώ είναι μια άσκηση 5 ζευγαριών
# αντί για μία ερώτηση Σωστό/Λάθος.
const MATCHING_ROUNDS_PER_VISIT := 3

# Loot: μόνο χρυσό. Ίδια λογική βάσης με το COTTON_BASE του cotton_popup.gd
# (ίδια σταθερά GOLD_BASE=2) — αλλάζει μόνο το resource type. Η ανταμοιβή
# είναι GOLD_BASE + άθροισμα (σωστά ζευγάρια × δυσκολία άσκησης) σε ΟΛΟΥΣ
# τους γύρους της επίσκεψης — αφού τώρα υπάρχουν 3 γύροι (15 ζευγάρια)
# αντί για 1, το ανώτατο δυνατό ποσό είναι φυσιολογικά μεγαλύτερο από το
# cotton man (έως 2+15×3=47 αντί για 2+5×3=17), ανάλογο με την επιπλέον
# προσπάθεια.
const GOLD_BASE := 2

# ── Παλέτα (mine / σπηλιά) ────────────────────────────────────────────────
const C0       := Color(0, 0, 0, 0)
const C_GOLD   := Color(0.940, 0.760, 0.160)
const C_GOLD_D := Color(0.360, 0.278, 0.058)
const C_GOLD_S := Color(1.000, 0.920, 0.560)
const C_PARCH  := Color(0.950, 0.910, 0.740)
const C_PARCH_D:= Color(0.780, 0.730, 0.520)
const C_STONE  := Color(0.155, 0.168, 0.195)   # μπλε-γκρι πέτρα σπηλιάς
const C_STONE_D:= Color(0.095, 0.105, 0.125)
const C_WOOD   := Color(0.200, 0.140, 0.065)
const C_WOOD_D := Color(0.130, 0.085, 0.035)
const C_AMBER  := Color(0.985, 0.645, 0.115)   # φανάρι ορυχείου
const C_TEXT   := Color(0.100, 0.060, 0.018)
const C_CRYSTAL:= Color(0.440, 0.780, 0.960)   # κρύσταλλο / πολύτιμο ορυκτό
const C_OK     := Color(0.560, 0.900, 0.460)   # πράσινο «Σωστό!»
const C_BAD    := Color(0.960, 0.450, 0.400)   # κόκκινο «Λάθος»

const W := 1080.0
const H := 1920.0

# ── Κατάσταση ─────────────────────────────────────────────────────────────
var _state  := 0   # 1 = miner μιλάει, 2 = board με αντιστοίχιση
var _char   : TextureRect
var _bubble : Control
var _board  : Control
var _hint   : Label

# ── Κατάσταση αντιστοίχισης (drag & drop) ───────────────────────────────────
var _matching        : MatchingQuizManager
var _left_col        : VBoxContainer
var _right_col       : VBoxContainer
var _left_rows       : Array[MatchDragItem] = []
var _left_row_labels : Array[Label] = []
var _right_rows      : Array[MatchDragItem] = []
var _right_assigned_labels: Array[Label] = []
var _left_locked      : Array[bool] = []   # left_index -> έχει ήδη τοποθετηθεί κάπου;
var _slot_left_index  : Array[int]  = []   # right_index -> left_index εκεί (ή -1)
var _progress         : Label
var _feedback        : Label
var _result_shown    := false
var _loot_given      := false
var _completion      : Control

# ═══════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	randomize()   # για διαφορετική άσκηση/ανακάτεμα κάθε φορά
	_build()
	gui_input.connect(_on_gui_input)

func show_popup() -> void:
	visible   = true
	_state    = 1
	if is_instance_valid(_completion):
		_completion.queue_free()
	_completion = null
	_loot_given   = false
	_result_shown = false
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
# ΚΑΤΑΣΤΑΣΗ 2 — miner φεύγει, board εμφανίζεται με την άσκηση αντιστοίχισης
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
		_start_matching()
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
	# Ελαφρύ σκοτάδι — σπηλιά είναι σκοτεινή
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.32)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

# ── Χαρακτήρας miner ──────────────────────────────────────────────────────
func _build_character() -> TextureRect:
	var tex : Texture2D = load(CHAR_PATH)
	var char_rect := TextureRect.new()
	if tex:
		char_rect.texture = tex
	# Δεξί μέρος οθόνης
	char_rect.position     = Vector2(530, 560)
	char_rect.size         = Vector2(510, 980)
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
	const BY := 155.0
	const BW := 570.0
	const BH := 490.0

	# Σκιά
	_shadow(root, Vector2(BX+8, BY+8), Vector2(BW, BH), 18)

	# Κύριο πλαίσιο — περγαμηνή
	_styled_panel(root, Vector2(BX, BY), Vector2(BW, BH),
		C_PARCH, C_GOLD, 5, 18)
	_styled_panel(root, Vector2(BX+10, BY+10), Vector2(BW-20, BH-20),
		C0, C_GOLD_D, 2, 14)

	# Ουρά φούσκας (προς τον miner — κάτω-δεξιά)
	_bubble_tail(root, BX + BW - 48, BY + BH - 2)

	# Τίτλος NPC
	_styled_panel(root, Vector2(BX+22, BY+22), Vector2(BW-44, 58),
		C_STONE_D, C_GOLD_D, 2, 8)
	_label(root, "⛏  Κοσμάς ο Μεταλλωρύχος",
		Vector2(BX+22, BY+22), Vector2(BW-44, 58),
		20, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER,
		Color(0,0,0,0.80), 1, 2)

	# Διαχωριστής
	_cr_on(root, Vector2(BX+30, BY+86), Vector2(BW-60, 2), C_GOLD_D)

	# Κείμενο ομιλίας
	var msg := Label.new()
	msg.text = "Γεια χαρά, μικρέ μαθητή!\n\nΈχω στο ορυχείο μου πολύτιμα\nορυκτά που μπορώ να σου δώσω...\n\nΑλλά δεν τα δίνω τζάμπα!\nΘα πρέπει να λύσεις\nμια αντιστοίχιση για μένα!\n\nΕίσαι έτοιμος για την πρόκληση;"
	msg.position         = Vector2(BX+28, BY+96)
	msg.size             = Vector2(BW-56, BH-130)
	msg.autowrap_mode    = TextServer.AUTOWRAP_WORD_SMART
	msg.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	msg.add_theme_font_size_override("font_size", 26)
	msg.add_theme_color_override("font_color", C_TEXT)
	msg.add_theme_color_override("font_shadow_color", Color(1,1,1,0.28))
	msg.add_theme_constant_override("shadow_offset_x", 0)
	msg.add_theme_constant_override("shadow_offset_y", 1)
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(msg)

	# Κρυσταλλάκια / sparkles Disney style
	_crystal_sparkles(root, BX, BY, BW, BH)

	return root

func _bubble_tail(parent: Control, tx: float, ty: float) -> void:
	_cr_on(parent, Vector2(tx,    ty),    Vector2(32, 14), C_PARCH)
	_cr_on(parent, Vector2(tx+8,  ty+12), Vector2(22, 14), C_PARCH)
	_cr_on(parent, Vector2(tx+16, ty+24), Vector2(14, 14), C_PARCH)
	_cr_on(parent, Vector2(tx-1,  ty-1),  Vector2(34, 5),  C_GOLD)
	_cr_on(parent, Vector2(tx+31, ty+2),  Vector2(5,  14), C_GOLD)

func _crystal_sparkles(parent: Control, bx: float, by: float, bw: float, bh: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 98765
	for _i in range(10):
		var sz  := 4.0 + rng.randf() * 7.0
		var sp  := ColorRect.new()
		sp.position = Vector2(
			bx + rng.randf_range(-18, bw+18),
			by + rng.randf_range(-18, bh+18)
		)
		sp.size        = Vector2(sz, sz)
		# Εναλλάσσει χρυσό και κρυσταλλένιο μπλε
		var col := C_GOLD_S if rng.randf() > 0.5 else C_CRYSTAL
		sp.color       = Color(col.r, col.g, col.b, 0.0)
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(sp)
		var tw := create_tween()
		tw.set_loops()
		tw.tween_property(sp, "color:a", 0.0,  rng.randf_range(0.8, 2.5)).set_delay(rng.randf()*4.0)
		tw.tween_property(sp, "color:a", 0.92, 0.10)
		tw.tween_property(sp, "color:a", 0.0,  0.40)

# ── Board (Κατάσταση 2) — άσκηση αντιστοίχισης ────────────────────────────
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
	# Το board.png έχει ~15% διάφανο περιθώριο στην κορυφή πριν καν ξεκινήσει
	# το ξύλινο πλαίσιο (bounding box της εικόνας, όχι του BRD_H) — 150 δεν
	# έφτανε. 340 (~25.8% του BRD_H=1320) το κατεβάζει ακόμα πιο καθαρά μέσα
	# στο ορατό ξύλο (μετά από feedback ότι το 260 ήταν ακόμα λίγο ψηλά).
	pad.add_theme_constant_override("margin_top",    340)
	pad.add_theme_constant_override("margin_bottom", 130)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)

	var title := Label.new()
	title.text = "⛏  Σύρε κάθε στοιχείο στη σωστή αντιστοιχία!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", C_GOLD_S)
	title.add_theme_color_override("font_shadow_color", Color(0,0,0,0.85))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)

	_progress = Label.new()
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress.add_theme_font_size_override("font_size", 24)
	_progress.add_theme_color_override("font_color", C_CRYSTAL)
	_progress.add_theme_color_override("font_shadow_color", Color(0,0,0,0.85))
	_progress.add_theme_constant_override("shadow_offset_x", 1)
	_progress.add_theme_constant_override("shadow_offset_y", 2)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_progress)

	var grid_row := HBoxContainer.new()
	grid_row.add_theme_constant_override("separation", 20)
	grid_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grid_row)

	_left_col = VBoxContainer.new()
	_left_col.add_theme_constant_override("separation", 12)
	_left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_row.add_child(_left_col)

	var sep := VSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_row.add_child(sep)

	_right_col = VBoxContainer.new()
	_right_col.add_theme_constant_override("separation", 12)
	_right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_row.add_child(_right_col)

	_feedback = Label.new()
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.custom_minimum_size  = Vector2(0, 40)
	_feedback.add_theme_font_size_override("font_size", 26)
	_feedback.add_theme_color_override("font_color", C_PARCH)
	_feedback.add_theme_color_override("font_shadow_color", Color(0,0,0,0.85))
	_feedback.add_theme_constant_override("shadow_offset_x", 1)
	_feedback.add_theme_constant_override("shadow_offset_y", 2)
	_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_feedback)

	return root

# ═══════════════════════════════════════════════════════════════════════════
# ΣΥΣΤΗΜΑ ΑΝΤΙΣΤΟΙΧΙΣΗΣ — η λογική ζει στο MatchingQuizManager, το scene
# μόνο δείχνει UI (ίδιο μοτίβο με cotton_popup.gd/QuizManager)
# ═══════════════════════════════════════════════════════════════════════════
func _start_matching() -> void:
	_matching = MatchingQuizManager.new()
	if not _matching.load_from_file(QUIZ_PATH):
		_feedback.text = "⚠  Δεν ήταν δυνατή η φόρτωση των ασκήσεων."
		return
	_matching.round_ready.connect(_on_round_ready)
	_matching.round_completed.connect(_on_round_completed)
	_matching.session_completed.connect(_on_session_completed)
	_matching.start_session(MATCHING_ROUNDS_PER_VISIT)

func _on_round_ready(round_index: int, total_rounds: int, left: Array, right: Array) -> void:
	_progress.text = "Άσκηση %d / %d" % [round_index + 1, total_rounds]
	_render_round(left, right)

func _render_round(left: Array, right: Array) -> void:
	_result_shown = false
	_feedback.text = "Σύρε κάθε στοιχείο (1-5) πάνω στο σωστό ταίρι του (α-ε)"

	for c in _left_col.get_children():
		c.queue_free()
	for c in _right_col.get_children():
		c.queue_free()
	_left_rows.clear()
	_left_row_labels.clear()
	_right_rows.clear()
	_right_assigned_labels.clear()

	_left_locked = []
	_slot_left_index = []
	for _i in left.size():
		_left_locked.append(false)
		_slot_left_index.append(-1)

	for i in range(left.size()):
		var lrow := _make_left_row(i, str(left[i]))
		_left_col.add_child(lrow)

	for i in range(right.size()):
		var rrow := _make_right_row(i, str(right[i]))
		_right_col.add_child(rrow)

# ── Αριστερή στήλη — σέρνεται (drag source) ─────────────────────────────────
func _make_left_row(index: int, text: String) -> MatchDragItem:
	var row := MatchDragItem.new()
	row.is_source = true
	row.payload = index
	row.preview_text = "%d.  %s" % [index + 1, text]
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_stylebox_override("panel", _row_style(C_STONE))
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hbox)

	hbox.add_child(_row_badge(str(index + 1), C_AMBER))

	var lbl := Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", C_PARCH)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(lbl)

	_left_rows.append(row)
	_left_row_labels.append(lbl)
	return row

# ── Δεξιά στήλη — δέχεται drop (drop target) ────────────────────────────────
func _make_right_row(index: int, text: String) -> MatchDragItem:
	var row := MatchDragItem.new()
	row.is_target = true
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_stylebox_override("panel", _row_style(C_STONE))
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hbox)

	hbox.add_child(_row_badge(MatchingQuizManager.LETTERS[index], C_CRYSTAL))

	var assigned := Label.new()
	assigned.text = "—"
	assigned.custom_minimum_size = Vector2(34, 0)
	assigned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	assigned.add_theme_font_size_override("font_size", 22)
	assigned.add_theme_color_override("font_color", C_AMBER)
	assigned.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(assigned)

	var lbl := Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", C_PARCH)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(lbl)

	row.dropped_on.connect(_on_dropped_on_slot.bind(index))

	_right_rows.append(row)
	_right_assigned_labels.append(assigned)
	return row

func _row_badge(text: String, color: Color) -> Control:
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(40, 40)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color     = color.darkened(0.30)
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(20)
	badge.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(lbl)
	return badge

func _row_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(bg.r, bg.g, bg.b, 0.65)
	s.border_color = C_GOLD_D
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.content_margin_left   = 10
	s.content_margin_right  = 10
	s.content_margin_top    = 8
	s.content_margin_bottom = 8
	return s

## Καλείται όταν ο παίκτης αφήνει ένα αριστερό στοιχείο (payload = index του)
## πάνω σε δεξιό στόχο (right_index). Αν ο στόχος είναι ήδη κατειλημμένος,
## ο προηγούμενος "κάτοικός" του ελευθερώνεται και ξαναγίνεται σύρσιμο.
func _on_dropped_on_slot(payload: Variant, right_index: int) -> void:
	if _matching == null or _result_shown or typeof(payload) != TYPE_INT:
		return
	var left_index: int = payload
	if left_index < 0 or left_index >= _left_locked.size() or _left_locked[left_index]:
		return

	var previous_occupant: int = _slot_left_index[right_index]
	if previous_occupant != -1:
		_left_locked[previous_occupant] = false
		_left_rows[previous_occupant].locked = false
		_set_left_row_placed(previous_occupant, false)
		_matching.clear(previous_occupant)

	_slot_left_index[right_index] = left_index
	_left_locked[left_index] = true
	_left_rows[left_index].locked = true
	_set_left_row_placed(left_index, true)
	_set_slot_assignment(right_index, left_index)

	_matching.choose(left_index, MatchingQuizManager.LETTERS[right_index])
	_update_progress_feedback()

func _set_left_row_placed(index: int, placed: bool) -> void:
	var row := _left_rows[index]
	var style := _row_style(C_STONE.darkened(0.35)) if placed else _row_style(C_STONE)
	if placed:
		style.border_color = C_AMBER
	row.add_theme_stylebox_override("panel", style)
	row.modulate.a = 0.55 if placed else 1.0

func _set_slot_assignment(right_index: int, left_index: int) -> void:
	_right_assigned_labels[right_index].text = str(left_index + 1) if left_index >= 0 else "—"

func _update_progress_feedback() -> void:
	var placed: int = _left_locked.count(true)
	if placed < _left_locked.size():
		_feedback.text = "Τοποθετήθηκαν %d / %d" % [placed, _left_locked.size()]

func _on_round_completed(_round_index: int, _total_rounds: int, correct_count: int, pair_total: int, _earned_difficulty: int, flags: Array) -> void:
	_result_shown = true
	for row in _right_rows:
		row.is_target = false
	for i in _left_rows.size():
		var ok: bool = flags[i]
		var style := _row_style(C_OK.darkened(0.55)) if ok else _row_style(C_BAD.darkened(0.45))
		style.border_color = C_OK if ok else C_BAD
		style.set_border_width_all(2)
		_left_rows[i].add_theme_stylebox_override("panel", style)
		_left_rows[i].modulate.a = 1.0
		_left_row_labels[i].text += ("  ✔" if ok else "  ✘")

	_feedback.text = "Σωστά: %d / %d" % [correct_count, pair_total]

	var t := get_tree().create_timer(1.8)
	t.timeout.connect(func():
		if is_instance_valid(_matching):
			_matching.advance()   # επόμενος γύρος, ή session_completed αν ήταν ο τελευταίος
	)

func _on_session_completed(total_correct: int, total_pairs: int, total_earned: int) -> void:
	_finish(total_correct, total_pairs, GOLD_BASE + total_earned)

# ═══════════════════════════════════════════════════════════════════════════
# ΚΛΕΙΣΙΜΟ + LOOT
# ═══════════════════════════════════════════════════════════════════════════
# Ένας γύρος (5 ζευγάρια) μετράει στην ανταμοιβή μόνο όταν ολοκληρωθεί
# πλήρως. Αν όμως ο παίκτης φύγει νωρίς αφού έχει ήδη ολοκληρώσει
# τουλάχιστον έναν γύρο, παίρνει την ανταμοιβή για ό,τι έχει ήδη
# ολοκληρώσει — ίδια λογική με το "μερικό loot" του cotton_popup.gd,
# προσαρμοσμένη σε γύρους αντί για μεμονωμένες ερωτήσεις.
func _finish(correct_count: int, total: int, gold: int) -> void:
	if _loot_given:
		return
	_loot_given = true
	Currency.add("Χρυσό", gold)
	var results := [{ "name": "Χρυσό", "amount": gold }]
	_show_completion("Ο μεταλλωρύχος σου έδωσε το χρυσάφι!", correct_count, total, results)

func _on_back_pressed() -> void:
	if _state == 2 and not _loot_given and is_instance_valid(_matching) and _matching.get_total_pairs() > 0:
		_finish(_matching.get_total_correct(), _matching.get_total_pairs(), GOLD_BASE + _matching.get_total_earned())
	else:
		_close()

# ── Οθόνη ολοκλήρωσης (ίδιο μοτίβο με cotton_popup.gd) ──────────────────────
func _show_completion(title_text: String, score: int, total: int, results: Array) -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_completion = overlay

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	const PW := 820.0
	const PH := 540.0
	var px := (W - PW) / 2.0
	var py := (H - PH) / 2.0
	_shadow(overlay, Vector2(px + 8, py + 10), Vector2(PW, PH), 20)
	_styled_panel(overlay, Vector2(px, py), Vector2(PW, PH), C_PARCH, C_GOLD, 5, 20)
	_styled_panel(overlay, Vector2(px + 12, py + 12), Vector2(PW - 24, PH - 24), C0, C_GOLD_D, 2, 16)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(px + 40, py + 55)
	title.size     = Vector2(PW - 80, 170)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", C_TEXT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(title)

	var lines := "Σωστές αντιστοιχίσεις: %d/%d\n\nΚέρδισες:" % [score, total]
	for item in results:
		lines += "\n•  +%d %s" % [item["amount"], item["name"]]
	var loot := Label.new()
	loot.text = lines
	loot.position = Vector2(px + 40, py + 240)
	loot.size     = Vector2(PW - 80, PH - 280)
	loot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loot.vertical_alignment   = VERTICAL_ALIGNMENT_TOP
	loot.add_theme_font_size_override("font_size", 30)
	loot.add_theme_color_override("font_color", C_GOLD_D)
	loot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(loot)

	overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.40)
	tw.tween_interval(1.9)
	tw.tween_callback(_close)

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
	tw.tween_property(l, "modulate:a", 0.22, 1.0)
	tw.tween_property(l, "modulate:a", 1.00, 1.0)
	return l

# ── Κουμπί Πίσω ───────────────────────────────────────────────────────────
func _build_back_button() -> void:
	_shadow_plain(Vector2(W/2 - 195, H - 134), Vector2(390, 84))
	var btn := Button.new()
	btn.text     = "◄   Πίσω στο Χωριό"
	btn.position = Vector2(W/2 - 195, H - 138)
	btn.size     = Vector2(390, 84)
	btn.add_theme_font_size_override("font_size", 30)
	_style_back_btn(btn)
	add_child(btn)
	btn.pressed.connect(_on_back_pressed)

# ═══════════════════════════════════════════════════════════════════════════
# ΒΟΗΘΗΤΙΚΕΣ ΣΥΝΑΡΤΗΣΕΙΣ
# ═══════════════════════════════════════════════════════════════════════════
func _styled_panel(parent: Control, pos: Vector2, sz: Vector2,
				   bg: Color, border: Color, bw: int, cr: int) -> Panel:
	var p := Panel.new()
	p.position = pos; p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = border
	s.set_border_width_all(bw); s.set_corner_radius_all(cr)
	p.add_theme_stylebox_override("panel", s)
	parent.add_child(p)
	return p

func _shadow(parent: Control, pos: Vector2, sz: Vector2, cr: int) -> void:
	var p := Panel.new()
	p.position = pos; p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color    = Color(0, 0, 0, 0.55)
	s.set_corner_radius_all(cr)
	s.shadow_color = Color(0, 0, 0, 0.40); s.shadow_size = 20
	p.add_theme_stylebox_override("panel", s)
	parent.add_child(p)

func _shadow_plain(pos: Vector2, sz: Vector2) -> void:
	var p := Panel.new()
	p.position = pos + Vector2(5, 6); p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0.60); s.set_corner_radius_all(10)
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
