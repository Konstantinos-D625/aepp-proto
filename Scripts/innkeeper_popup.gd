extends Control

# ── Μονοπάτια εικόνων ─────────────────────────────────────────────────────
# Ο ΓΙΩΡΓΟΣ Ο ΤΑΒΕΡΝΙΑΡΗΣ της περιοχής ΕΠ (σπιτάκι «ΠΑΝΔΟΧΕΙΟ» στο
# ep.area.bg.png). ΙΔΙΟ ΜΟΤΙΒΟ ΜΕ ΤΗ ΒΟΤΑΝΟΥ/ΧΑΡΤΟΓΡΑΦΟ: δύο full-screen
# εικόνες της ίδιας σκηνής, με και χωρίς τον χαρακτήρα· στην Κατάσταση 2 η
# από πάνω κάνει fade out και «αποκαλύπτεται» το άδειο πανδοχείο.
#
# ΠΡΟΣΟΧΗ 1: όπως και στο charto.*, το «bg2» έχει τον χαρακτήρα και το «bg»
# είναι το άδειο δωμάτιο — ΑΝΤΙΘΕΤΑ από το bota.*. Μην τα ανταλλάξεις.
#
# ΠΡΟΣΟΧΗ 2: εδώ οι δύο εικόνες ΔΕΝ έχουν ίδιες διαστάσεις (1024×1536 vs
# 1086×1448) — είναι δύο ξεχωριστά renders της ίδιας σκηνής, όχι το ίδιο
# καρέ με/χωρίς τον χαρακτήρα. Άρα ΔΕΝ κάθονται pixel-πάνω-σε-pixel και το
# crossfade μετακινεί ελαφρώς το δωμάτιο (το pand.bg δείχνει πιο πολύ ταβάνι).
# Αν χρειαστεί να διορθωθεί, ο σωστός τρόπος είναι να ξανακοπεί το pand.bg
# στο ίδιο κάδρο με το pand.bg2 — όχι να μπει transform εδώ.
const BG_PATH    := "res://Εικόνες/pand.bg.png"    # χωρίς τον Γιώργο
const CHAR_PATH  := "res://Εικόνες/pand.bg2.png"   # με τον Γιώργο
const BOARD_PATH := "res://Εικόνες/board.png"

# ── Παλέτα (πανδοχείο — φως τζακιού, χάλκινες κούπες, σκονισμένο μπλε) ────
# Τα αδελφά popup χρησιμοποιούν ΒΙΟΛΕΤΙ (αλχημιστής), ΠΡΑΣΙΝΗ (βοτανού) ή
# ΓΑΛΑΖΙΑ (χαρτογράφος) πινελιά· εδώ ο τόνος είναι ΚΕΧΡΙΜΠΑΡΕΝΙΟΣ ώστε να
# δένει με το τζάκι και τα φανάρια, αλλά τα σχήματα/μεγέθη/αποστάσεις μένουν
# ακριβώς τα ίδια για συνεπές UI.
const C0       := Color(0, 0, 0, 0)
const C_AMB    := Color(0.900, 0.560, 0.250)   # κεχριμπαρένια πινελιά
const C_AMB_D  := Color(0.355, 0.180, 0.075)
const C_AMB_S  := Color(1.000, 0.830, 0.615)
const C_PARCH  := Color(0.975, 0.945, 0.895)   # ζεστό υπόλευκο
const C_PARCH_D:= Color(0.805, 0.775, 0.730)
const C_BLUE   := Color(0.420, 0.560, 0.760)   # σκονισμένο μπλε (σύννεφα/λάβαρο)
const C_WOOD   := Color(0.180, 0.130, 0.090)
const C_WOOD_D := Color(0.105, 0.075, 0.052)
const C_TEXT   := Color(0.145, 0.090, 0.055)
const C_OK     := Color(0.560, 0.900, 0.460)   # πράσινο «Σωστό!»
const C_BAD    := Color(0.960, 0.450, 0.400)   # κόκκινο «Λάθος»

# ── Σύστημα ασκήσεων ──────────────────────────────────────────────────────
# Ασκήσεις ΠΟΛΛΑΠΛΗΣ ΕΠΙΛΟΓΗΣ για τη Δομή Επανάληψης (ίδιος engine με
# blacksmith_popup.gd — QuizManager + get_current_options). Το UI χτίζει ένα
# κουμπί ανά επιλογή. Αντικατέστησε ΜΟΝΟ το JSON για άλλες ερωτήσεις.
const QUIZ_PATH := "res://innkeeper_quiz.json"
const QUESTIONS_PER_ROUND := 5

const W := 1080.0
const H := 1920.0

# ── Κατάσταση ─────────────────────────────────────────────────────────────
var _state  := 0
var _char   : TextureRect
var _bubble : Control
var _board  : Control
var _hint   : Label

## Το ΜΟΝΟ σημείο προσάρτησης για το περιεχόμενο του πίνακα. Ό,τι μπει εδώ
## στοιχίζεται αυτόματα μέσα στο ξύλινο πλαίσιο του board.png (βλ.
## _build_board). Γέμισμα → _populate_board().
var _board_content : VBoxContainer

# ── Κατάσταση quiz ─────────────────────────────────────────────────────────
var _quiz          : QuizManager
var _q_label       : Label
var _progress      : Label
var _feedback      : Label
var _options_box   : VBoxContainer
var _option_buttons: Array[Button] = []
var _input_locked  := false
var _answered      := 0
var _finished      := false
var _completion    : Control

# ═══════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_build()
	gui_input.connect(_on_gui_input)

func show_popup() -> void:
	visible = true
	_state  = 1
	# Καθάρισμα κατάστασης από προηγούμενη επίσκεψη (replay).
	_clear_board()
	if is_instance_valid(_completion):
		_completion.queue_free()
	_completion = null
	_input_locked = false
	_answered = 0
	_finished = false
	_option_buttons.clear()
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
# ΚΑΤΑΣΤΑΣΗ 2 — ο Γιώργος φεύγει (fade στο άδειο πανδοχείο), board εμφανίζεται
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
		_populate_board()
		var tw2 := create_tween()
		tw2.tween_property(_board, "modulate:a", 1.0, 0.55)
	)

# ═══════════════════════════════════════════════════════════════════════════
# ΠΕΡΙΕΧΟΜΕΝΟ ΠΙΝΑΚΑ
# ═══════════════════════════════════════════════════════════════════════════
## Καλείται κάθε φορά που ο πίνακας εμφανίζεται (Κατάσταση 2), αφού πρώτα
## έχει αδειάσει από την προηγούμενη επίσκεψη. Χτίζει το UI του quiz πολλαπλής
## επιλογής (Δομή Επανάληψης) και ξεκινά έναν νέο γύρο.
func _populate_board() -> void:
	_build_quiz_ui()
	_start_quiz()

# ── UI ασκήσεων μέσα στον πίνακα (πρόοδος, εκφώνηση, κουμπιά επιλογής, feedback) ──
func _build_quiz_ui() -> void:
	_progress = Label.new()
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress.add_theme_font_size_override("font_size", 26)
	_progress.add_theme_color_override("font_color", C_AMB_S)
	_progress.add_theme_color_override("font_shadow_color", Color(0,0,0,0.85))
	_progress.add_theme_constant_override("shadow_offset_x", 1)
	_progress.add_theme_constant_override("shadow_offset_y", 2)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_content.add_child(_progress)

	_q_label = _make_board_label("", 30, C_PARCH)
	_q_label.vertical_alignment  = VERTICAL_ALIGNMENT_CENTER
	_q_label.custom_minimum_size = Vector2(0, 300)
	_board_content.add_child(_q_label)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 16)
	_options_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_options_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_content.add_child(_options_box)

	_feedback = Label.new()
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.custom_minimum_size  = Vector2(0, 46)
	_feedback.add_theme_font_size_override("font_size", 30)
	_feedback.add_theme_color_override("font_shadow_color", Color(0,0,0,0.85))
	_feedback.add_theme_constant_override("shadow_offset_x", 1)
	_feedback.add_theme_constant_override("shadow_offset_y", 2)
	_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_content.add_child(_feedback)

# ═══════════════════════════════════════════════════════════════════════════
# ΣΥΣΤΗΜΑ ΑΣΚΗΣΕΩΝ — η λογική ζει στον QuizManager (βλ. blacksmith_popup.gd)
# ═══════════════════════════════════════════════════════════════════════════
func _start_quiz() -> void:
	_quiz = QuizManager.new()
	if not _quiz.load_from_file(QUIZ_PATH):
		_progress.text = ""
		_q_label.text  = "⚠  Δεν ήταν δυνατή η φόρτωση των ασκήσεων."
		return
	_quiz.question_changed.connect(_on_question_changed)
	_quiz.answer_result.connect(_on_answer_result)
	_quiz.quiz_completed.connect(_on_quiz_completed)
	_quiz.start(true, QUESTIONS_PER_ROUND)

func _on_question_changed(index: int, total: int, question_text: String) -> void:
	if _finished:
		return
	_input_locked = false
	_q_label.text = question_text
	_progress.text = "Ερώτηση %d / %d" % [index + 1, total]
	_feedback.text = ""
	_build_option_buttons(_quiz.get_current_options())

## Χτίζει ένα κουμπί ανά επιλογή· το πάτημα υποβάλλει το ΚΕΙΜΕΝΟ της επιλογής.
func _build_option_buttons(options: Array) -> void:
	_clear_options()
	for opt in options:
		var text := str(opt)
		var btn := _make_answer_button(text, C_AMB)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_font_size_override("font_size", 26)
		btn.pressed.connect(_on_option_pressed.bind(text))
		_options_box.add_child(btn)
		_option_buttons.append(btn)

func _clear_options() -> void:
	if _options_box == null:
		return
	for btn in _options_box.get_children():
		btn.queue_free()
	_option_buttons.clear()

func _on_option_pressed(value: String) -> void:
	if _input_locked or _quiz == null:
		return
	_answered += 1
	_set_options_enabled(false)
	_quiz.submit_answer(value)

func _set_options_enabled(enabled: bool) -> void:
	for btn in _option_buttons:
		if is_instance_valid(btn):
			btn.disabled = not enabled

func _on_answer_result(correct: bool) -> void:
	_input_locked = true
	_set_options_enabled(false)
	if correct:
		_feedback.add_theme_color_override("font_color", C_OK)
		_feedback.text = "✔  Σωστό!"
	else:
		_feedback.add_theme_color_override("font_color", C_BAD)
		_feedback.text = "✘  Λάθος!"
	var t := get_tree().create_timer(0.9)
	t.timeout.connect(func():
		if is_instance_valid(_quiz) and not _finished:
			_quiz.advance()
	)

func _on_quiz_completed(_score: int, _total: int) -> void:
	_finish()

# ── Ολοκλήρωση γύρου → οθόνη σκορ, μετά κλείνει το πανδοχείο ───────────────
func _finish() -> void:
	if _finished:
		return
	_finished = true
	_input_locked = true
	_set_options_enabled(false)
	if _answered <= 0:
		_close()
		return
	var score := _quiz.get_score() if _quiz else 0
	_show_completion("Ο Γιώργος σε ευχαριστεί!", score)

func _show_completion(title_text: String, score: int) -> void:
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
	const PH := 560.0
	var px := (W - PW) / 2.0
	var py := (H - PH) / 2.0
	_shadow(overlay, Vector2(px + 8, py + 10), Vector2(PW, PH), 20)
	_styled_panel(overlay, Vector2(px, py), Vector2(PW, PH), C_PARCH, C_AMB, 5, 20)
	_styled_panel(overlay, Vector2(px + 12, py + 12), Vector2(PW - 24, PH - 24), C0, C_AMB_D, 2, 16)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(px + 40, py + 70)
	title.size     = Vector2(PW - 80, 190)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", C_TEXT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(title)

	var header := Label.new()
	header.text = "Σωστές απαντήσεις: %d" % score
	header.position = Vector2(px + 40, py + 290)
	header.size     = Vector2(PW - 80, 130)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.vertical_alignment   = VERTICAL_ALIGNMENT_TOP
	header.add_theme_font_size_override("font_size", 30)
	header.add_theme_color_override("font_color", C_AMB_D)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(header)

	overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.40)
	tw.tween_interval(1.9)
	tw.tween_callback(_close)

## Αδειάζει τον πίνακα (κάθε νέα επίσκεψη ξεκινά από καθαρό πίνακα).
func _clear_board() -> void:
	if _board_content == null:
		return
	for child in _board_content.get_children():
		child.queue_free()

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

# ── Φόντο (άδειο πανδοχείο) ───────────────────────────────────────────────
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
	# Ελαφρύ σκούρο overlay για ατμόσφαιρα (και για να διαβάζεται το κείμενο)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.25)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

# ── Χαρακτήρας Γιώργος — full-screen layer «σκηνή με τον ταβερνιάρη» ───────
# ΙΔΙΟ expand/stretch με το _build_background. Κουβαλάει και δικό της dim
# overlay (ίδιο με του background) ως ΠΑΙΔΙ, ώστε η φωτεινότητα να είναι ίδια
# πριν και μετά το fade — τα παιδιά κληρονομούν το modulate του γονιού, οπότε
# σβήνουν όλα μαζί στο tween του _go_to_state2.
func _build_character() -> TextureRect:
	var tex : Texture2D = load(CHAR_PATH)
	var char_rect := TextureRect.new()
	if tex:
		char_rect.texture = tex
	char_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	char_rect.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	char_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	char_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(char_rect)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.25)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	char_rect.add_child(dim)
	return char_rect

# ── Φούσκα ομιλίας ────────────────────────────────────────────────────────
func _build_bubble() -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Ο Γιώργος στέκεται ΚΕΝΤΡΟ-ΑΡΙΣΤΕΡΑ και σηκώνει την κούπα ψηλά, οπότε η
	# φούσκα πάει δεξιά, με ουρά κάτω-αριστερά προς αυτόν.
	# ΠΡΟΣΟΧΗ ΣΤΟ ΥΨΟΣ: τα μαλλιά του ξεκινούν στο y≈464 της οθόνης (η εικόνα
	# 1086×1448 μπαίνει με KEEP_ASPECT_COVERED σε 1080×1920, άρα κλίμακα
	# 1.326 και οριζόντιο κόψιμο 180px ανά πλευρά). Η φούσκα ΠΡΕΠΕΙ να
	# τελειώνει πάνω από εκεί, αλλιώς σκεπάζει το πρόσωπό του.
	# Η πινακίδα «ΠΑΝΔΟΧΕΙΟ» είναι ΑΡΙΣΤΕΡΑ (x≈-54..264), οπότε δεν την κρύβει.
	const BX := 430.0
	const BY := 32.0
	const BW := 620.0
	const BH := 390.0

	# Σκιά
	_shadow(root, Vector2(BX+8, BY+8), Vector2(BW, BH), 18)

	# Κύριο πλαίσιο — ζεστό υπόλευκο με κεχριμπαρένιο περίγραμμα
	_styled_panel(root, Vector2(BX, BY), Vector2(BW, BH),
		C_PARCH, C_AMB, 5, 18)
	_styled_panel(root, Vector2(BX+10, BY+10), Vector2(BW-20, BH-20),
		C0, C_AMB_D, 2, 14)

	# Ουρά φούσκας (προς τον Γιώργο — κάτω-αριστερά)
	_bubble_tail(root, BX + 50, BY + BH - 2)

	# Τίτλος NPC
	_styled_panel(root, Vector2(BX+22, BY+22), Vector2(BW-44, 58),
		C_WOOD_D, C_AMB_D, 2, 8)
	_label(root, "✦  Ο Γιώργος ο Ταβερνιάρης",
		Vector2(BX+22, BY+22), Vector2(BW-44, 58),
		22, C_AMB_S, HORIZONTAL_ALIGNMENT_CENTER,
		Color(0,0,0,0.80), 1, 2)

	# Διαχωριστής
	_cr_on(root, Vector2(BX+30, BY+86), Vector2(BW-60, 2), C_AMB_D)

	# ΚΕΙΜΕΝΟ ΟΜΙΛΙΑΣ — άλλαξέ το ελεύθερα. ΟΡΙΟ: ~6 γραμμές των 26px (η φούσκα
	# δεν μπορεί να ψηλώσει, γιατί από κάτω αρχίζει το κεφάλι του Γιώργου).
	# Κάθε "\n" είναι νέα γραμμή· οι μεγάλες γραμμές σπάνε μόνες τους (autowrap).
	# Το «ξανά και ξανά» είναι νεύμα στη Δομή Επανάληψης, το θέμα της ΕΠ.
	var msg := Label.new()
	msg.text = "Καλώς τον! Γιώργο με λένε.\n\nΓεμίζω κούπες ξανά και ξανά,\nώσπου ν' αδειάσει το βαρέλι!\n\nΛύσε τις ασκήσεις στον πίνακα!"
	msg.position         = Vector2(BX+28, BY+96)
	msg.size             = Vector2(BW-56, BH-130)
	msg.autowrap_mode    = TextServer.AUTOWRAP_WORD_SMART
	msg.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	msg.add_theme_font_size_override("font_size", 26)
	msg.add_theme_color_override("font_color", C_TEXT)
	msg.add_theme_color_override("font_shadow_color", Color(1,1,1,0.30))
	msg.add_theme_constant_override("shadow_offset_x", 0)
	msg.add_theme_constant_override("shadow_offset_y", 1)
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(msg)

	# Σπίθες τζακιού γύρω από τη φούσκα
	_hearth_embers(root, BX, BY, BW, BH)

	return root

# Τα σκαλοπάτια της ουράς κατεβαίνουν προς τα ΑΡΙΣΤΕΡΑ (εκεί στέκεται ο
# Γιώργος μέσα στη σκηνή).
func _bubble_tail(parent: Control, tx: float, ty: float) -> void:
	_cr_on(parent, Vector2(tx,    ty),    Vector2(32, 14), C_PARCH)
	_cr_on(parent, Vector2(tx-8,  ty+12), Vector2(22, 14), C_PARCH)
	_cr_on(parent, Vector2(tx-14, ty+24), Vector2(14, 14), C_PARCH)
	_cr_on(parent, Vector2(tx-1,  ty-1),  Vector2(34,  5), C_AMB)
	_cr_on(parent, Vector2(tx-4,  ty+2),  Vector2(5,  14), C_AMB)

func _hearth_embers(parent: Control, bx: float, by: float, bw: float, bh: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 70413
	for _i in range(10):
		var sz  := 5.0 + rng.randf() * 8.0
		var sp  := Panel.new()
		sp.position = Vector2(
			bx + rng.randf_range(-20, bw+20),
			by + rng.randf_range(-20, bh+20)
		)
		sp.size = Vector2(sz, sz)
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s := StyleBoxFlat.new()
		# Εναλλάσσει κεχριμπαρένιο και μπλε (φως τζακιού / μοτίβο σύννεφων)
		s.bg_color = C_AMB_S if rng.randf() > 0.4 else C_BLUE
		s.set_corner_radius_all(int(sz / 2))
		sp.add_theme_stylebox_override("panel", s)
		parent.add_child(sp)
		var tw := create_tween()
		tw.set_loops()
		tw.tween_property(sp, "modulate:a", 0.0,  rng.randf_range(0.8, 2.5)).set_delay(rng.randf()*4.0)
		tw.tween_property(sp, "modulate:a", 0.88, 0.14)
		tw.tween_property(sp, "modulate:a", 0.0,  0.45)

# ── Board (Κατάσταση 2) ───────────────────────────────────────────────────
# Ίδιες διαστάσεις/περιθώρια με τα αδελφά popup, ώστε ο πίνακας να «κάθεται»
# στην ίδια θέση σε όλα τα σπιτάκια.
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

	# ── Περιοχή γραφής μέσα στον πίνακα ──────────────────────────────────
	# Το board.png έχει διάφανο περιθώριο γύρω από το ξύλινο πλαίσιο· αυτά τα
	# margins κρατούν το περιεχόμενο μέσα στο ξύλο.
	var pad := MarginContainer.new()
	pad.position = Vector2(BRD_X, BRD_Y)
	pad.size     = Vector2(BRD_W, BRD_H)
	pad.add_theme_constant_override("margin_left",   110)
	pad.add_theme_constant_override("margin_right",  110)
	pad.add_theme_constant_override("margin_top",    155)
	pad.add_theme_constant_override("margin_bottom", 135)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pad)

	# Το μοναδικό σημείο προσάρτησης περιεχομένου — βλ. _populate_board().
	_board_content = VBoxContainer.new()
	_board_content.add_theme_constant_override("separation", 24)
	_board_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(_board_content)

	return root

# ═══════════════════════════════════════════════════════════════════════════
# ΒΟΗΘΗΤΙΚΑ ΓΙΑ ΤΟ ΠΕΡΙΕΧΟΜΕΝΟ ΤΟΥ ΠΙΝΑΚΑ
# (έτοιμα «τουβλάκια» ώστε οι ασκήσεις να μπουν με λίγες γραμμές και να
#  δείχνουν ίδιες με των υπόλοιπων σπιτιών)
# ═══════════════════════════════════════════════════════════════════════════

## Label σε στυλ «κιμωλία πάνω στο ξύλο» — για εκφωνήσεις, προόδο, μηνύματα.
func _make_board_label(text: String, font_size: int = 34,
					   color: Color = C_PARCH) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0,0,0,0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("line_spacing", 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Κουμπί απάντησης στο στυλ των υπόλοιπων σπιτιών (σκούρο ξύλο + χρωματιστό
## περίγραμμα). Σύνδεσέ το με `btn.pressed.connect(...)`.
func _make_answer_button(text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size   = Vector2(0, 100)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 34)

	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.085, 0.075, 0.055, 0.92)
	n.border_color = accent.darkened(0.25)
	n.set_border_width_all(4)
	n.set_corner_radius_all(12)
	n.shadow_color = Color(0, 0, 0, 0.55)
	n.shadow_size = 6
	btn.add_theme_stylebox_override("normal", n)

	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.140, 0.120, 0.085, 0.96)
	h.border_color = accent
	h.shadow_color = accent.lightened(0.10)
	h.shadow_size = 14
	btn.add_theme_stylebox_override("hover", h)

	var pr := n.duplicate() as StyleBoxFlat
	pr.bg_color = Color(0.055, 0.045, 0.030, 0.98)
	pr.border_color = accent.darkened(0.35)
	btn.add_theme_stylebox_override("pressed", pr)

	var dis := n.duplicate() as StyleBoxFlat
	dis.bg_color = Color(0.085, 0.075, 0.055, 0.55)
	dis.border_color = C_AMB_D.darkened(0.25)
	btn.add_theme_stylebox_override("disabled", dis)

	btn.add_theme_stylebox_override("focus", StyleBoxFlat.new())
	btn.add_theme_color_override("font_color", C_PARCH)
	btn.add_theme_color_override("font_hover_color", accent.lightened(0.35))
	btn.add_theme_color_override("font_pressed_color", accent)
	btn.add_theme_color_override("font_disabled_color", C_PARCH_D.darkened(0.25))
	btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	btn.add_theme_constant_override("shadow_offset_x", 2)
	btn.add_theme_constant_override("shadow_offset_y", 3)
	return btn

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
	n.bg_color = C_WOOD_D; n.border_color = C_AMB.darkened(0.15)
	n.set_border_width_all(4); n.set_corner_radius_all(10)
	n.shadow_color = Color(0,0,0,0.68); n.shadow_size = 7
	btn.add_theme_stylebox_override("normal", n)
	var h := StyleBoxFlat.new()
	h.bg_color = C_WOOD; h.border_color = C_AMB
	h.set_border_width_all(5); h.set_corner_radius_all(10)
	h.shadow_color = C_AMB.lightened(0.10); h.shadow_size = 16
	btn.add_theme_stylebox_override("hover", h)
	var pr := StyleBoxFlat.new()
	pr.bg_color = Color(0.070,0.040,0.020); pr.border_color = C_AMB.darkened(0.25)
	pr.set_border_width_all(3); pr.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("pressed", pr)
	btn.add_theme_stylebox_override("focus", StyleBoxFlat.new())
	btn.add_theme_color_override("font_color",         C_AMB_S)
	btn.add_theme_color_override("font_hover_color",   Color(1,1,1))
	btn.add_theme_color_override("font_pressed_color", C_AMB.darkened(0.30))
	btn.add_theme_color_override("font_shadow_color",  Color(0,0,0,0.92))
	btn.add_theme_constant_override("shadow_offset_x", 2)
	btn.add_theme_constant_override("shadow_offset_y", 3)
