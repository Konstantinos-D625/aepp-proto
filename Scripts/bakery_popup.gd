extends Control

# ── Μονοπάτια εικόνων ─────────────────────────────────────────────────────
# Ο ΦΟΥΡΝΑΡΗΣ της περιοχής ΔΕ (σπιτάκι «ΦΟΥΡΝΟΣ» στο de.area.bg.png).
# ΙΔΙΟ ΜΟΤΙΒΟ ΜΕ ΤΗ ΔΕΡΜΑΤΟΥ (cotton_popup.gd): το bakery.bg2.png είναι
# ΟΛΟΚΛΗΡΗ σκηνή (ο φούρναρης ΜΑΖΙ με το φουρνάρικο) και το bakery.bg.png
# είναι η ΙΔΙΑ ακριβώς σκηνή ΧΩΡΙΣ τον φούρναρη. Γι' αυτό το _build_character
# δεν τοποθετεί μικρό TextureRect, αλλά ΔΕΥΤΕΡΟ full-screen layer πάνω από το
# BG_PATH: όταν στην Κατάσταση 2 το _char κάνει fade out, «αποκαλύπτεται» το
# άδειο φουρνάρικο από κάτω — ο φούρναρης μοιάζει να φεύγει, το δωμάτιο μένει.
const BG_PATH     := "res://Εικόνες/bakery.bg.png"    # χωρίς φούρναρη
const CHAR_PATH   := "res://Εικόνες/bakery.bg2.png"   # με τον φούρναρη
const BOARD_PATH  := "res://Εικόνες/board.png"

# ── Σύστημα ασκήσεων ──────────────────────────────────────────────────────
# Αρχείο ερωτήσεων για αυτό το σπίτι/NPC. Άλλα σπίτια βάζουν άλλο JSON.
# ΠΡΟΣΩΡΙΝΟ ΠΕΡΙΕΧΟΜΕΝΟ: οι ερωτήσεις στο bakery_quiz.json είναι placeholder
# μέχρι να μπουν οι πραγματικές ασκήσεις — αντικατέστησε ΜΟΝΟ το JSON, ο
# κώδικας εδώ δεν χρειάζεται αλλαγή.
const QUIZ_PATH := "res://bakery_quiz.json"

# Πόσες ερωτήσεις ανά επίσκεψη (τυχαίες κάθε φορά). 0 = όλες.
const QUESTIONS_PER_ROUND := 5

# ── Παλέτα (φουρνάρικο — ζεστό ψωμί, κρούστα, αλεύρι) ─────────────────────
const C0       := Color(0, 0, 0, 0)
const C_GOLD   := Color(0.940, 0.700, 0.240)   # χρυσό κρούστας
const C_GOLD_D := Color(0.380, 0.240, 0.070)
const C_GOLD_S := Color(1.000, 0.880, 0.560)
const C_PARCH  := Color(0.980, 0.945, 0.870)   # λευκό-κρεμ περγαμηνή
const C_PARCH_D:= Color(0.820, 0.770, 0.660)
const C_FLOUR  := Color(0.980, 0.975, 0.960)   # σκόνη αλευριού
const C_CRYST  := Color(0.450, 0.470, 0.860)   # μπλε κρύσταλλο (θέμα περιοχής)
const C_WOOD   := Color(0.200, 0.140, 0.065)
const C_WOOD_D := Color(0.130, 0.085, 0.035)
const C_TEXT   := Color(0.100, 0.065, 0.025)
const C_OK     := Color(0.560, 0.900, 0.460)   # πράσινο «Σωστό!»
const C_BAD    := Color(0.960, 0.450, 0.400)   # κόκκινο «Λάθος»

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
var _btn_true     : Button
var _btn_false    : Button
var _feedback     : Label
var _progress     : Label
var _input_locked := false
var _completion   : Control
var _answered     := 0        # πόσες ερωτήσεις απαντήθηκαν σε αυτή την επίσκεψη
var _finished     := false    # έκλεισε ήδη ο γύρος σε αυτή την επίσκεψη;

# ═══════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_build()
	gui_input.connect(_on_gui_input)

func show_popup() -> void:
	visible   = true
	_state    = 1
	# Καθάρισμα τυχόν κατάστασης από προηγούμενη επίσκεψη (replay).
	if is_instance_valid(_completion):
		_completion.queue_free()
	_completion = null
	_input_locked = false
	_answered = 0
	_finished = false
	if _feedback: _feedback.text = ""
	if _progress: _progress.text = ""
	_set_answer_buttons_enabled(false)
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
# ΚΑΤΑΣΤΑΣΗ 2 — ο Φούρναρης φεύγει (fade στο άδειο φουρνάρικο), board εμφανίζεται
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

# ── Φόντο (άδειο φουρνάρικο) ──────────────────────────────────────────────
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

# ── Χαρακτήρας Φούρναρης — full-screen layer «σκηνή με τον φούρναρη» ───────
# ΙΔΙΟ expand/stretch με το _build_background ώστε οι δύο εικόνες (με/χωρίς
# τον φούρναρη) να κάθονται pixel-πάνω-σε-pixel — αλλιώς το fade της
# Κατάστασης 2 θα «κουνούσε» το δωμάτιο. Κουβαλάει και δικό της dim overlay
# (ίδιο με του background) ως ΠΑΙΔΙ, ώστε η φωτεινότητα να είναι ίδια πριν
# και μετά το fade — τα παιδιά κληρονομούν το modulate του γονιού, οπότε
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

	# Ο φούρναρης στέκεται ΑΡΙΣΤΕΡΑ-ΚΕΝΤΡΟ μέσα στη σκηνή (μπροστά στον
	# φούρνο), οπότε η φούσκα πάει δεξιά, με ουρά κάτω-αριστερά προς αυτόν.
	# ΠΡΟΣΟΧΗ ΣΤΟ ΥΨΟΣ: ο σκούφος του μαγείρου ξεκινά στο y≈494 της οθόνης
	# (η εικόνα 1024×1536 μπαίνει με KEEP_ASPECT_COVERED σε 1080×1920, άρα
	# κλίμακα 1.25 και οριζόντιο κόψιμο 80px ανά πλευρά). Η φούσκα ΠΡΕΠΕΙ να
	# τελειώνει πάνω από εκεί, αλλιώς σκεπάζει το πρόσωπό του.
	const BX := 400.0
	const BY := 32.0
	const BW := 650.0
	const BH := 410.0

	# Σκιά
	_shadow(root, Vector2(BX+8, BY+8), Vector2(BW, BH), 18)

	# Κύριο πλαίσιο — ζεστό κρεμ
	_styled_panel(root, Vector2(BX, BY), Vector2(BW, BH),
		C_PARCH, C_GOLD, 5, 18)
	_styled_panel(root, Vector2(BX+10, BY+10), Vector2(BW-20, BH-20),
		C0, C_GOLD_D, 2, 14)

	# Ουρά φούσκας (προς τον Φούρναρη — κάτω-αριστερά)
	_bubble_tail(root, BX + 48, BY + BH - 2)

	# Τίτλος NPC
	_styled_panel(root, Vector2(BX+22, BY+22), Vector2(BW-44, 58),
		C_WOOD_D, C_GOLD_D, 2, 8)
	_label(root, "🍞  Ο Φούρναρης",
		Vector2(BX+22, BY+22), Vector2(BW-44, 58),
		22, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER,
		Color(0,0,0,0.80), 1, 2)

	# Διαχωριστής
	_cr_on(root, Vector2(BX+30, BY+86), Vector2(BW-60, 2), C_GOLD_D)

	# Κείμενο ομιλίας — παραπέμπει στον πίνακα «ΣΗΜΕΙΩΣΕΙΣ» της εικόνας
	# (ΑΛΕΥΡΙ – ΜΑΓΙΑ – ΑΓΑΠΗ – ΥΠΟΜΟΝΗ).
	var msg := Label.new()
	msg.text = "Καλώς ήρθες στον φούρνο μου!\n\nΖυμώνω με αλεύρι, μαγιά,\nαγάπη και πολλή υπομονή!\n\nΛύσε μερικές ασκήσεις στον\nπίνακά μου, για ζεστό ψωμί!"
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

	# Σκόνη αλευριού γύρω από τη φούσκα
	_flour_sparkles(root, BX, BY, BW, BH)

	return root

# Τα σκαλοπάτια της ουράς κατεβαίνουν προς τα ΑΡΙΣΤΕΡΑ (εκεί στέκεται ο
# φούρναρης μέσα στη σκηνή).
func _bubble_tail(parent: Control, tx: float, ty: float) -> void:
	_cr_on(parent, Vector2(tx,    ty),    Vector2(32, 14), C_PARCH)
	_cr_on(parent, Vector2(tx-8,  ty+12), Vector2(22, 14), C_PARCH)
	_cr_on(parent, Vector2(tx-14, ty+24), Vector2(14, 14), C_PARCH)
	_cr_on(parent, Vector2(tx-1,  ty-1),  Vector2(34,  5), C_GOLD)
	_cr_on(parent, Vector2(tx-4,  ty+2),  Vector2(5,  14), C_GOLD)

func _flour_sparkles(parent: Control, bx: float, by: float, bw: float, bh: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13579
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
		# Εναλλάσσει λευκό αλεύρι και μπλε κρύσταλλο (θέμα της περιοχής ΔΕ)
		s.bg_color = C_FLOUR if rng.randf() > 0.35 else C_CRYST
		s.set_corner_radius_all(int(sz / 2))
		sp.add_theme_stylebox_override("panel", s)
		parent.add_child(sp)
		var tw := create_tween()
		tw.set_loops()
		tw.tween_property(sp, "modulate:a", 0.0,  rng.randf_range(0.8, 2.5)).set_delay(rng.randf()*4.0)
		tw.tween_property(sp, "modulate:a", 0.88, 0.14)
		tw.tween_property(sp, "modulate:a", 0.0,  0.45)

# ── Board (Κατάσταση 2) ───────────────────────────────────────────────────
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

	# ── Περιοχή γραφής μέσα στον πίνακα (αρκετό περιθώριο ώστε να μη βγαίνει έξω) ──
	var pad := MarginContainer.new()
	pad.position = Vector2(BRD_X, BRD_Y)
	pad.size     = Vector2(BRD_W, BRD_H)
	pad.add_theme_constant_override("margin_left",   110)
	pad.add_theme_constant_override("margin_right",  110)
	pad.add_theme_constant_override("margin_top",    155)
	pad.add_theme_constant_override("margin_bottom", 135)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)

	# Δείκτης προόδου (π.χ. «Ερώτηση 1 / 5»)
	_progress = Label.new()
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress.add_theme_font_size_override("font_size", 26)
	_progress.add_theme_color_override("font_color", C_GOLD_S)
	_progress.add_theme_color_override("font_shadow_color", Color(0,0,0,0.85))
	_progress.add_theme_constant_override("shadow_offset_x", 1)
	_progress.add_theme_constant_override("shadow_offset_y", 2)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_progress)

	# Εκφώνηση (με word wrapping, ευανάγνωστη πάνω στον πίνακα)
	_q_label = Label.new()
	_q_label.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_q_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_q_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_q_label.size_flags_vertical  = Control.SIZE_EXPAND_FILL
	_q_label.custom_minimum_size  = Vector2(0, 470)
	_q_label.add_theme_font_size_override("font_size", 34)
	_q_label.add_theme_color_override("font_color", C_PARCH)
	_q_label.add_theme_color_override("font_shadow_color", Color(0,0,0,0.85))
	_q_label.add_theme_constant_override("shadow_offset_x", 1)
	_q_label.add_theme_constant_override("shadow_offset_y", 2)
	_q_label.add_theme_constant_override("line_spacing", 10)
	_q_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_q_label)

	# Κουμπιά απάντησης — ΣΩΣΤΟ / ΛΑΘΟΣ (χωρίς πληκτρολόγιο)
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 28)
	btn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(btn_row)

	_btn_true = Button.new()
	_btn_true.text = "ΣΩΣΤΟ"
	_btn_true.custom_minimum_size = Vector2(0, 100)
	_btn_true.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_answer_btn(_btn_true, C_OK)
	_btn_true.pressed.connect(_on_answer_button.bind("ΣΩΣΤΟ"))
	btn_row.add_child(_btn_true)

	_btn_false = Button.new()
	_btn_false.text = "ΛΑΘΟΣ"
	_btn_false.custom_minimum_size = Vector2(0, 100)
	_btn_false.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_answer_btn(_btn_false, C_BAD)
	_btn_false.pressed.connect(_on_answer_button.bind("ΛΑΘΟΣ"))
	btn_row.add_child(_btn_false)

	# Ανατροφοδότηση (Σωστό! / Λάθος!)
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

# ═══════════════════════════════════════════════════════════════════════════
# ΣΥΣΤΗΜΑ ΑΣΚΗΣΕΩΝ — η λογική ζει στον QuizManager, το scene μόνο δείχνει UI
# ═══════════════════════════════════════════════════════════════════════════
func _start_quiz() -> void:
	_quiz = QuizManager.new()
	if not _quiz.load_from_file(QUIZ_PATH):
		_progress.text = ""
		_q_label.text  = "⚠  Δεν ήταν δυνατή η φόρτωση των ασκήσεων."
		_set_answer_buttons_enabled(false)
		return
	_quiz.question_changed.connect(_on_question_changed)
	_quiz.answer_result.connect(_on_answer_result)
	_quiz.quiz_completed.connect(_on_quiz_completed)
	# Ανακάτεμα + υποσύνολο → διαφορετικές ερωτήσεις κάθε φορά που μπαίνεις.
	_quiz.start(true, QUESTIONS_PER_ROUND)

func _on_question_changed(index: int, total: int, question_text: String) -> void:
	if _finished:
		return
	_input_locked = false
	_q_label.text = question_text
	_progress.text = "Ερώτηση %d / %d" % [index + 1, total]
	_feedback.text = ""
	_set_answer_buttons_enabled(true)

func _on_answer_button(value: String) -> void:
	if _input_locked or _quiz == null:
		return
	_answered += 1
	_quiz.submit_answer(value)

func _on_answer_result(correct: bool) -> void:
	# Δείξε το αποτέλεσμα και προχώρα ΠΑΝΤΑ στην επόμενη (σωστό ή λάθος).
	_input_locked = true
	_set_answer_buttons_enabled(false)
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
	# Απαντήθηκαν όλες → οθόνη ολοκλήρωσης και κλείσιμο.
	_finish(true)

# ═══════════════════════════════════════════════════════════════════════════
# ΚΛΕΙΣΙΜΟ
# ═══════════════════════════════════════════════════════════════════════════
# Καλείται είτε όταν τελειώσουν όλες οι ερωτήσεις, είτε όταν ο παίκτης πατήσει
# «Πίσω στο Χωριό».
#
# ΑΝΤΑΜΟΙΒΗ: ο φούρναρης δεν δίνει ακόμα loot — δεν έχει αποφασιστεί τι θα
# δίνει. Όταν αποφασιστεί, μπαίνει εδώ (μοτίβο cotton_popup.gd):
#     Currency.add("<πόρος>", <ποσό>)
# και η γραμμή περνά στο _show_completion ως results.
func _finish(completed: bool) -> void:
	if _finished:
		return
	_finished = true
	_input_locked = true
	_set_answer_buttons_enabled(false)

	var score := _quiz.get_score() if _quiz else 0
	if _answered <= 0:
		_close()
		return

	var title := "Ο Φούρναρης σε ευχαριστεί!" if completed else "Πέρνα πάλι όποτε θες!"
	_show_completion(title, score)

func _on_back_pressed() -> void:
	# Αν έχει αρχίσει το quiz και έχει απαντήσει, δείξε το αποτέλεσμα·
	# αλλιώς απλό κλείσιμο.
	if _state == 2 and not _finished and _answered > 0:
		_finish(false)
	else:
		_close()

# ── Οθόνη ολοκλήρωσης → μετά κλείνει ο φούρνος (επιστροφή στην περιοχή) ────
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
	_styled_panel(overlay, Vector2(px, py), Vector2(PW, PH), C_PARCH, C_GOLD, 5, 20)
	_styled_panel(overlay, Vector2(px + 12, py + 12), Vector2(PW - 24, PH - 24), C0, C_GOLD_D, 2, 16)

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
	header.add_theme_color_override("font_color", C_GOLD_D)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(header)

	overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.40)
	tw.tween_interval(1.9)
	tw.tween_callback(_close)

# ── Ενεργοποίηση/απενεργοποίηση κουμπιών απάντησης ─────────────────────────
func _set_answer_buttons_enabled(enabled: bool) -> void:
	if _btn_true:
		_btn_true.disabled = not enabled
	if _btn_false:
		_btn_false.disabled = not enabled

# ── Στυλ κουμπιού απάντησης (ταιριαστό με τον πίνακα, με χρώμα-τόνο) ────────
func _style_answer_btn(btn: Button, accent: Color) -> void:
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
	dis.border_color = C_GOLD_D.darkened(0.25)
	btn.add_theme_stylebox_override("disabled", dis)

	btn.add_theme_stylebox_override("focus", StyleBoxFlat.new())
	btn.add_theme_color_override("font_color", C_PARCH)
	btn.add_theme_color_override("font_hover_color", accent.lightened(0.35))
	btn.add_theme_color_override("font_pressed_color", accent)
	btn.add_theme_color_override("font_disabled_color", C_PARCH_D.darkened(0.25))
	btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	btn.add_theme_constant_override("shadow_offset_x", 2)
	btn.add_theme_constant_override("shadow_offset_y", 3)

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
