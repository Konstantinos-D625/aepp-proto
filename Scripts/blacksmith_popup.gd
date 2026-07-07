extends Control

# ── Μονοπάτια εικόνων ─────────────────────────────────────────────────────
const BG_PATH     := "res://Εικόνες/bl.background.png"
const CHAR_PATH   := "res://Εικόνες/blacksmith.png"
const BOARD_PATH  := "res://Εικόνες/board.png"

# ── Σύστημα ασκήσεων ──────────────────────────────────────────────────────
# Αρχείο ερωτήσεων πολλαπλής επιλογής (απάντηση πάντα A/B/C/D/E/F).
const QUIZ_PATH := "res://blacksmith_quiz.json"

# Πόσες ερωτήσεις ανά επίσκεψη (τυχαίες κάθε φορά). 0 = όλες.
const QUESTIONS_PER_ROUND := 5

# Loot: μόνο σίδερο. Η ποσότητα εξαρτάται από τη ΔΥΣΚΟΛΙΑ των ερωτήσεων που
# απαντήθηκαν σωστά. Δίνεται όταν φεύγεις, αρκεί να απάντησες ≥1 ερώτηση.
const IRON_BASE := 2

# Επιπλέον, σταθερό μπόνους (1) σε κάθε ολοκληρωμένη επίσκεψη — ο Blacksmith
# είναι ο ΜΟΝΑΔΙΚΟΣ NPC που δίνει Σφαίρα Δύναμης (Cottonman -> Εξυπνάδας,
# Miner -> Ταχύτητας, βλ. αντίστοιχα σχόλια εκεί). Ίδιες προϋποθέσεις με το
# κανονικό loot παραπάνω (μόνο αν απαντήθηκε ≥1 ερώτηση σωστά).
const SPHERE_NAME := "Σφαίρα Δύναμης"
const SPHERE_ICON := "res://Εικόνες/red-orb.png"

# ── Παλέτα (σιδηρουργείο — σκοτεινό μέταλλο, χρυσό φως καμινιού) ─────────
const C0       := Color(0, 0, 0, 0)
const C_GOLD   := Color(0.940, 0.760, 0.160)
const C_GOLD_D := Color(0.360, 0.278, 0.058)
const C_GOLD_S := Color(1.000, 0.920, 0.560)
const C_PARCH  := Color(0.960, 0.920, 0.760)
const C_PARCH_D:= Color(0.820, 0.760, 0.560)
const C_WOOD   := Color(0.200, 0.120, 0.052)
const C_WOOD_D := Color(0.130, 0.075, 0.028)
const C_IRON   := Color(0.148, 0.140, 0.128)
const C_TEXT   := Color(0.130, 0.072, 0.022)
const C_CRIMSON:= Color(0.580, 0.058, 0.058)
const C_OK     := Color(0.560, 0.900, 0.460)
const C_BAD    := Color(0.960, 0.450, 0.400)
# Χρώματα ειδικά για το πληκτρολόγιο (ατσάλινο σκελετό γύρω από τα πλήκτρα)
const C_STEEL   := Color(0.560, 0.575, 0.605)
const C_STEEL_D := Color(0.260, 0.270, 0.290)

const W := 1080.0
const H := 1920.0

# ── Κατάσταση ─────────────────────────────────────────────────────────────
var _state  := 0
var _char   : TextureRect
var _bubble : Control
var _board  : Control
var _hint   : Label

# ── Κατάσταση quiz ─────────────────────────────────────────────────────────
var _quiz         : QuizManager
var _q_label      : Label
var _feedback     : Label
var _progress     : Label
var _input_locked := false
var _completion   : Control
var _answered     := 0
var _loot_given   := false

# ── Πληκτρολόγιο σιδηρουργού (μόνο A-F λειτουργικά) ────────────────────────
const KEY_LETTERS: Array[String] = ["A", "B", "C", "D", "E", "F"]
const KEY_ICONS := {
	"A": "⚒", "B": "⛓", "C": "⚔", "D": "⚙", "E": "🛡", "F": "🔥",
}
var _key_buttons : Dictionary = {}   # letter (String) → Button

# ═══════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	randomize()
	_build()
	gui_input.connect(_on_gui_input)

func show_popup() -> void:
	visible   = true
	_state    = 1
	if is_instance_valid(_completion):
		_completion.queue_free()
	_completion = null
	_input_locked = false
	_answered = 0
	_loot_given = false
	if _feedback: _feedback.text = ""
	if _progress: _progress.text = ""
	_set_keyboard_enabled(false)
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

# ── Φυσικό πληκτρολόγιο: τα πλήκτρα A-F λειτουργούν και από το πραγματικό
#    πληκτρολόγιο, όχι μόνο με κλικ πάνω στο on-screen πληκτρολόγιο ────────
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or _state != 2 or _input_locked:
		return
	var ke := event as InputEventKey
	if ke == null or not ke.pressed or ke.echo:
		return
	var letter := ""
	match ke.keycode:
		KEY_A: letter = "A"
		KEY_B: letter = "B"
		KEY_C: letter = "C"
		KEY_D: letter = "D"
		KEY_E: letter = "E"
		KEY_F: letter = "F"
	if letter != "":
		_on_key_pressed(letter)
		get_viewport().set_input_as_handled()

# ═══════════════════════════════════════════════════════════════════════════
# ΚΑΤΑΣΤΑΣΗ 2 — blacksmith φεύγει, board + πληκτρολόγιο εμφανίζονται
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
		_start_quiz()
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

	_shadow(root, Vector2(BX+8, BY+8), Vector2(BW, BH), 18)

	_styled_panel(root, Vector2(BX, BY), Vector2(BW, BH),
		C_PARCH, C_GOLD, 5, 18)
	_styled_panel(root, Vector2(BX+10, BY+10), Vector2(BW-20, BH-20),
		C0, C_GOLD_D, 2, 14)

	_bubble_tail(root, BX + BW - 48, BY + BH - 2)

	_styled_panel(root, Vector2(BX+22, BY+22), Vector2(BW-44, 58),
		C_WOOD_D, C_GOLD_D, 2, 8)
	_label(root, "⚒  Γκάρεθ ο Σιδηρουργός",
		Vector2(BX+22, BY+22), Vector2(BW-44, 58),
		22, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER,
		Color(0,0,0,0.80), 1, 2)

	_cr_on(root, Vector2(BX+30, BY+86), Vector2(BW-60, 2), C_GOLD_D)

	var msg := Label.new()
	msg.text = "Α! Καλωσόρισες, περιπλανώμενε!\n\nΘα χαρώ να σε βοηθήσω\nμε υλικά για το ταξίδι σου...\n\nΑλλά πρώτα λύσε μερικές\nασκήσεις μου! Θα βλέπεις\nτο πρόβλημα στον πίνακα και\nθα απαντάς πατώντας ένα από\nτα πλήκτρα A B C D E F στο\nπληκτρολόγιο του σιδηρουργείου!"
	msg.position         = Vector2(BX+28, BY+96)
	msg.size             = Vector2(BW-56, BH-130)
	msg.autowrap_mode    = TextServer.AUTOWRAP_WORD_SMART
	msg.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	msg.add_theme_font_size_override("font_size", 25)
	msg.add_theme_color_override("font_color", C_TEXT)
	msg.add_theme_color_override("font_shadow_color", Color(1,1,1,0.30))
	msg.add_theme_constant_override("shadow_offset_x", 0)
	msg.add_theme_constant_override("shadow_offset_y", 1)
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(msg)

	_sparkle_dots(root, BX, BY, BW, BH)

	return root

func _bubble_tail(parent: Control, tx: float, ty: float) -> void:
	_cr_on(parent, Vector2(tx,    ty),    Vector2(32, 14), C_PARCH)
	_cr_on(parent, Vector2(tx+8,  ty+12), Vector2(22, 14), C_PARCH)
	_cr_on(parent, Vector2(tx+16, ty+24), Vector2(14, 14), C_PARCH)
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

# ── Board (Κατάσταση 2) — εκφώνηση + πληκτρολόγιο A-F ──────────────────────
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
	pad.add_theme_constant_override("margin_left",   110)
	pad.add_theme_constant_override("margin_right",  110)
	pad.add_theme_constant_override("margin_top",    150)
	pad.add_theme_constant_override("margin_bottom", 130)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)

	_progress = Label.new()
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress.add_theme_font_size_override("font_size", 26)
	_progress.add_theme_color_override("font_color", C_GOLD_S)
	_progress.add_theme_color_override("font_shadow_color", Color(0,0,0,0.85))
	_progress.add_theme_constant_override("shadow_offset_x", 1)
	_progress.add_theme_constant_override("shadow_offset_y", 2)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_progress)

	_q_label = Label.new()
	_q_label.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_q_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_q_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_q_label.size_flags_vertical  = Control.SIZE_EXPAND_FILL
	_q_label.custom_minimum_size  = Vector2(0, 520)
	_q_label.add_theme_font_size_override("font_size", 30)
	_q_label.add_theme_color_override("font_color", C_PARCH)
	_q_label.add_theme_color_override("font_shadow_color", Color(0,0,0,0.85))
	_q_label.add_theme_constant_override("shadow_offset_x", 1)
	_q_label.add_theme_constant_override("shadow_offset_y", 2)
	_q_label.add_theme_constant_override("line_spacing", 10)
	_q_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_q_label)

	col.add_child(_build_keyboard())

	_feedback = Label.new()
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.custom_minimum_size  = Vector2(0, 46)
	_feedback.add_theme_font_size_override("font_size", 30)
	_feedback.add_theme_color_override("font_shadow_color", Color(0,0,0,0.85))
	_feedback.add_theme_constant_override("shadow_offset_x", 1)
	_feedback.add_theme_constant_override("shadow_offset_y", 2)
	_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_feedback)

	return root

# ── Πληκτρολόγιο σιδηρουργού — μεταλλικό πλαίσιο με πλήκτρα A-F ───────────
func _build_keyboard() -> Control:
	const FRAME_H := 250.0

	var frame := Panel.new()
	frame.custom_minimum_size  = Vector2(0, FRAME_H)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := StyleBoxFlat.new()
	fs.bg_color     = C_STEEL_D
	fs.border_color = C_STEEL
	fs.set_border_width_all(5)
	fs.set_corner_radius_all(16)
	fs.shadow_color = Color(0, 0, 0, 0.55)
	fs.shadow_size  = 12
	frame.add_theme_stylebox_override("panel", fs)

	var inner_margin := MarginContainer.new()
	inner_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner_margin.add_theme_constant_override("margin_left", 18)
	inner_margin.add_theme_constant_override("margin_right", 18)
	inner_margin.add_theme_constant_override("margin_top", 18)
	inner_margin.add_theme_constant_override("margin_bottom", 18)
	inner_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(inner_margin)

	var vcol := VBoxContainer.new()
	vcol.add_theme_constant_override("separation", 10)
	vcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_margin.add_child(vcol)

	var title := Label.new()
	title.text = "⚒  ΠΛΗΚΤΡΟΛΟΓΙΟ ΣΙΔΗΡΟΥΡΓΕΙΟΥ  ⚒"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", C_GOLD_S)
	title.add_theme_color_override("font_shadow_color", Color(0,0,0,0.85))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vcol.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vcol.add_child(row)

	_key_buttons.clear()
	for letter in KEY_LETTERS:
		var btn := Button.new()
		btn.text = "%s\n%s" % [KEY_ICONS[letter], letter]
		btn.custom_minimum_size = Vector2(0, 150)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		_style_key_btn(btn)
		btn.pressed.connect(_on_key_pressed.bind(letter))
		row.add_child(btn)
		_key_buttons[letter] = btn

	return frame

# ═══════════════════════════════════════════════════════════════════════════
# ΣΥΣΤΗΜΑ ΑΣΚΗΣΕΩΝ — η λογική ζει στον QuizManager, το scene μόνο δείχνει UI
# ═══════════════════════════════════════════════════════════════════════════
func _start_quiz() -> void:
	_quiz = QuizManager.new()
	if not _quiz.load_from_file(QUIZ_PATH):
		_progress.text = ""
		_q_label.text  = "⚠  Δεν ήταν δυνατή η φόρτωση των ασκήσεων."
		_set_keyboard_enabled(false)
		return
	_quiz.question_changed.connect(_on_question_changed)
	_quiz.answer_result.connect(_on_answer_result)
	_quiz.quiz_completed.connect(_on_quiz_completed)
	_quiz.start(true, QUESTIONS_PER_ROUND)

func _on_question_changed(index: int, total: int, question_text: String) -> void:
	if _loot_given:
		return
	_input_locked = false
	_q_label.text = question_text
	_progress.text = "Ερώτηση %d / %d" % [index + 1, total]
	_feedback.text = ""
	_set_keyboard_enabled(true)

func _on_key_pressed(letter: String) -> void:
	if _input_locked or _quiz == null or _state != 2:
		return
	_answered += 1
	_quiz.submit_answer(letter)

func _on_answer_result(correct: bool) -> void:
	_input_locked = true
	_set_keyboard_enabled(false)
	if correct:
		_feedback.add_theme_color_override("font_color", C_OK)
		_feedback.text = "✔  Σωστό!"
	else:
		_feedback.add_theme_color_override("font_color", C_BAD)
		_feedback.text = "✘  Λάθος!"
	var t := get_tree().create_timer(0.9)
	t.timeout.connect(func():
		if is_instance_valid(_quiz) and not _loot_given:
			_quiz.advance()
	)

func _on_quiz_completed(_score: int, _total: int) -> void:
	_finish(true)

# ═══════════════════════════════════════════════════════════════════════════
# ΚΛΕΙΣΙΜΟ + LOOT
# ═══════════════════════════════════════════════════════════════════════════
func _finish(completed: bool) -> void:
	if _loot_given:
		return
	_loot_given = true
	_input_locked = true
	_set_keyboard_enabled(false)

	# Χωρίς έστω μία σωστή απάντηση δεν δίνεται καθόλου σίδερο.
	var score := _quiz.get_score() if _quiz else 0
	if _answered <= 0 or score <= 0:
		_close()
		return

	var results := _generate_and_apply_loot()
	var title := "Ο σιδηρουργός σου έδωσε σίδερο!" if completed else "Ευχαριστώ για τη βοήθεια!"
	_show_completion(title, score, results)

func _on_back_pressed() -> void:
	if _state == 2 and not _loot_given and _answered > 0:
		_finish(false)
	else:
		_close()

func _generate_and_apply_loot() -> Array:
	var results: Array = []
	var earned := _quiz.get_earned_difficulty() if _quiz else 0
	var iron := IRON_BASE + earned
	Currency.add("Σίδερο", iron)
	results.append({ "name": "Σίδερο", "amount": iron })
	Currency.add(SPHERE_NAME, 1)
	results.append({ "name": SPHERE_NAME, "amount": 1, "icon": SPHERE_ICON })
	return results

func _show_completion(title_text: String, score: int, results: Array) -> void:
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
	const PH := 700.0
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

	var header := Label.new()
	header.text = "Σωστές απαντήσεις: %d\n\nΚέρδισες:" % score
	header.position = Vector2(px + 40, py + 240)
	header.size     = Vector2(PW - 80, 130)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.vertical_alignment   = VERTICAL_ALIGNMENT_TOP
	header.add_theme_font_size_override("font_size", 30)
	header.add_theme_color_override("font_color", C_GOLD_D)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(header)

	_build_loot_rows(overlay, results, Vector2(px + 40, py + 370), PW - 80)

	overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.40)
	tw.tween_interval(1.9)
	tw.tween_callback(_close)

## Μία γραμμή ανά ανταμοιβή· αν έχει "icon" δείχνει την εικόνα δίπλα στο
## κείμενο (π.χ. οι νέες Σφαίρες), αλλιώς μένει στο απλό bullet-κείμενο
## (υλικά όπως Σίδερο/Χρυσό, που δεν έχουν ακόμα δικό τους εικονίδιο εδώ).
## Κοινό μοτίβο με cotton_popup.gd/miner_popup.gd.
func _build_loot_rows(parent: Control, results: Array, pos: Vector2, width: float) -> void:
	var col := VBoxContainer.new()
	col.position = pos
	col.size     = Vector2(width, 0)
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(col)
	for item in results:
		col.add_child(_make_loot_row(item))

func _make_loot_row(item: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_path: String = str(item.get("icon", ""))
	var lbl := Label.new()
	lbl.text = "+%d %s" % [item["amount"], item["name"]]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", C_GOLD_D)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(lbl)

	# Το εικονίδιο μπαίνει ΚΑΤΩ από το κείμενο, κεντραρισμένο, σε αρκετά
	# μεγάλο μέγεθος ώστε να φαίνεται καθαρά το σχέδιο της σφαίρας (όχι σαν
	# μικρό bullet-εικονίδιο δίπλα στο κείμενο όπως πριν).
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.custom_minimum_size = Vector2(110, 110)
		icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(icon)

	return col

# ── Ενεργοποίηση/απενεργοποίηση πλήκτρων A-F ───────────────────────────────
func _set_keyboard_enabled(enabled: bool) -> void:
	for letter in _key_buttons:
		(_key_buttons[letter] as Button).disabled = not enabled

# ── Στυλ πλήκτρου (μεταλλικό keycap σιδηρουργείου) ──────────────────────────
func _style_key_btn(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", 30)
	var n := StyleBoxFlat.new()
	n.bg_color = C_IRON
	n.border_color = C_GOLD_D
	n.set_border_width_all(4)
	n.set_corner_radius_all(10)
	n.shadow_color = Color(0, 0, 0, 0.60)
	n.shadow_size = 5
	btn.add_theme_stylebox_override("normal", n)

	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = C_IRON.lightened(0.10)
	h.border_color = C_GOLD
	h.shadow_color = C_GOLD.lightened(0.10)
	h.shadow_size = 14
	btn.add_theme_stylebox_override("hover", h)

	var pr := n.duplicate() as StyleBoxFlat
	pr.bg_color = Color(0.06, 0.055, 0.045)
	pr.border_color = C_GOLD.darkened(0.20)
	btn.add_theme_stylebox_override("pressed", pr)

	var dis := n.duplicate() as StyleBoxFlat
	dis.bg_color = C_IRON.darkened(0.30)
	dis.border_color = C_GOLD_D.darkened(0.35)
	btn.add_theme_stylebox_override("disabled", dis)

	btn.add_theme_stylebox_override("focus", StyleBoxFlat.new())
	btn.add_theme_color_override("font_color", C_GOLD_S)
	btn.add_theme_color_override("font_hover_color", C_GOLD_S.lightened(0.15))
	btn.add_theme_color_override("font_pressed_color", C_GOLD)
	btn.add_theme_color_override("font_disabled_color", C_GOLD_D.darkened(0.15))
	btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	btn.add_theme_constant_override("shadow_offset_x", 1)
	btn.add_theme_constant_override("shadow_offset_y", 2)

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
