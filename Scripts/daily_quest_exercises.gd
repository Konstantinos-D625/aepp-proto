extends Control

# ═══════════════════════════════════════════════════════════════════════════
# Daily Quest — Οθόνη Ασκήσεων (3 levels)
# ═══════════════════════════════════════════════════════════════════════════
# Level 1: 3 ερωτήσεις Σωστό/Λάθος (ίδιος engine με cotton_popup.gd — QuizManager)
# Level 2: 3 ερωτήσεις πολλαπλής επιλογής A-F (ίδιος engine με blacksmith_popup.gd — QuizManager)
# Level 3: 1 γύρος αντιστοίχισης 3 ζευγαριών (ίδιος engine με miner_popup.gd —
#          MatchingQuizManager, γενικευμένο να δέχεται pair_count=3 αντί για
#          σταθερό 5 — βλ. σχόλιο στην κορυφή του MatchingQuizManager.gd).
#
# ΚΑΝΟΝΑΣ: πρώτο λάθος σε ΟΠΟΙΑΔΗΠΟΤΕ ερώτηση/level -> ΔΕΝ βγάζει τον παίκτη
# από την οθόνη. Δείχνει σύντομο μήνυμα λάθους/επανεκκίνησης και μετά από
# λίγο ξαναρχίζει ΑΥΤΟΜΑΤΑ από το Level 1 (Σ/Λ 1/3) — βλ. _restart_attempt().
# Ο παίκτης έχει ΑΠΕΡΙΟΡΙΣΤΕΣ προσπάθειες μέσα στην ίδια μέρα, οπότε αυτό το
# loop συνεχίζεται μέχρι να πετύχει και τα 3 levels ΜΙΑ φορά (τότε -> _finish,
# streak + κλείδωμα μέχρι αύριο). Μόνο το «◄ Πίσω» κλείνει πραγματικά το
# popup ενδιάμεσα — μετράει σαν αποτυχία ΑΥΤΗΣ της απόπειρας, όχι σαν χαμένη
# μέρα (ο παίκτης μπορεί να ξανανοίξει αμέσως).
#
# Προσαρμογή για το Level 3 (matching): το MatchingQuizManager αξιολογεί ΟΛΟ
# τον γύρο μαζί (όχι ανά ζευγάρι σαν το QuizManager) — "πρώτο λάθος" εδώ
# σημαίνει: αν ΤΟΥΛΑΧΙΣΤΟΝ ένα από τα 3 ζευγάρια είναι λάθος όταν ολοκληρωθεί
# η τοποθέτηση, ο γύρος αποτυγχάνει -> επανεκκίνηση.
#
# Δεν υπάρχει καμία ανταμοιβή σε νομίσματα/αντικείμενα από το Daily Quest.
# Το GameData.record_daily_quest_result() δεν κάνει ΤΙΠΟΤΑ σε αποτυχημένη
# απόπειρα (καμία επίδραση στο streak ή στη δυνατότητα να ξαναπροσπαθήσεις)
# — μόνο η ΠΡΩΤΗ πλήρης επιτυχία της ημέρας ανανεώνει το streak ΚΑΙ κλειδώνει
# περαιτέρω προσπάθειες μέχρι αύριο.

const LEVEL1_QUIZ_PATH := "res://cotton_quiz.json"
const LEVEL2_QUIZ_PATH := "res://blacksmith_quiz.json"
const LEVEL3_QUIZ_PATH := "res://miner_quiz.json"
const QUESTIONS_PER_LEVEL := 3
const LEVEL3_PAIRS := 3
const LEVEL3_ROUNDS := 3

const KEY_LETTERS: Array[String] = ["A", "B", "C", "D", "E", "F"]

# ── Παλέτα (ίδιο ύφος με daily_quest_popup.gd / bg του DailyQuestExercises.tscn) ─
const C0        := Color(0, 0, 0, 0)
const C_GOLD    := Color(0.940, 0.760, 0.160)
const C_GOLD_D  := Color(0.360, 0.278, 0.058)
const C_GOLD_S  := Color(1.000, 0.920, 0.560)
const C_BONE    := Color(0.868, 0.830, 0.685)
const C_BONE_D  := Color(0.415, 0.378, 0.290)
const C_STONE   := Color(0.155, 0.168, 0.195)
const C_OK      := Color(0.560, 0.900, 0.460)
const C_BAD     := Color(0.960, 0.450, 0.400)
const C_DOT_OFF := Color(0.30, 0.28, 0.24, 0.65)

# ── Κατάσταση ─────────────────────────────────────────────────────────────
var _level := 0
var _finished := false
var _dots: Array[Panel] = []
var _completion: Control

# ── Level 1/2 (QuizManager: Σωστό/Λάθος ή A-F) ─────────────────────────────
var _quiz: QuizManager
var _q_label: Label
var _progress_label: Label
var _feedback: Label
var _answer_buttons: Array[Button] = []

# ── Level 3 (MatchingQuizManager + MatchDragItem, ίδιο μοτίβο με miner_popup.gd) ─
var _matching: MatchingQuizManager
var _left_col: VBoxContainer
var _right_col: VBoxContainer
var _left_rows: Array[MatchDragItem] = []
var _left_row_labels: Array[Label] = []
var _right_rows: Array[MatchDragItem] = []
var _right_assigned_labels: Array[Label] = []
var _left_locked: Array[bool] = []
var _slot_left_index: Array[int] = []
var _matching_feedback: Label
var _matching_round_progress: Label
var _matching_result_shown := false


func _ready() -> void:
	hide()
	_build_dots()


## Καλείται όταν ο παίκτης πατάει "ΠΑΜΕ" στο DailyQuestPopup.
func open() -> void:
	if GameData.is_daily_quest_completed_today():
		# Άμυνα — το DailyQuestPopup δεν πρέπει να αφήνει να φτάσουμε εδώ αν
		# έχει ήδη ολοκληρωθεί σήμερα, αλλά το ελέγχουμε κι εδώ σιγουριάς χάριν.
		close_popup()
		return
	_finished = false
	show()
	_start_level(1)

func close_popup() -> void:
	if is_instance_valid(_completion):
		_completion.queue_free()
	_completion = null
	hide()

## «◄ Πίσω» ΚΑΤΑ ΤΗ ΔΙΑΡΚΕΙΑ μιας απόπειρας τερματίζει καθαρά ΑΥΤΗ την
## απόπειρα ως ημιτελή (_finish με ό,τι levels είχαν ολοκληρωθεί πριν) —
## δεν έχει καμία επίδραση στο streak ή στη δυνατότητα να ξαναπροσπαθήσει
## (ο παίκτης έχει ούτως ή άλλως απεριόριστες προσπάθειες τη μέρα).
func _on_back_pressed() -> void:
	if not _finished:
		_finish(_level - 1)
	else:
		close_popup()


# ═══════════════════════════════════════════════════════════════════════════
# ΔΕΙΚΤΗΣ ΠΡΟΟΔΟΥ (3 τελείες)
# ═══════════════════════════════════════════════════════════════════════════
func _build_dots() -> void:
	var row := HBoxContainer.new()
	row.name = "LevelDots"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	%VBox.add_child(row)
	%VBox.move_child(row, 1)   # μετά τον τίτλο, πριν το HintLabel

	_dots.clear()
	for _i in 3:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(30, 30)
		row.add_child(dot)
		_dots.append(dot)
	_update_dots()

func _update_dots() -> void:
	for i in _dots.size():
		var dot := _dots[i]
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(15)
		if i + 1 == _level:
			sb.bg_color = C_GOLD
			sb.border_color = C_GOLD_S
			sb.set_border_width_all(3)
			sb.shadow_color = C_GOLD.lightened(0.1)
			sb.shadow_size = 8
		else:
			sb.bg_color = C_DOT_OFF
			sb.border_color = Color(0.2, 0.18, 0.15)
			sb.set_border_width_all(2)
		dot.add_theme_stylebox_override("panel", sb)


# ═══════════════════════════════════════════════════════════════════════════
# ΕΝΑΡΞΗ LEVEL
# ═══════════════════════════════════════════════════════════════════════════
func _start_level(n: int) -> void:
	_level = n
	_update_dots()
	_clear_exercise_area()
	match n:
		1:
			%HintLabel.text = "Επίπεδο 1 από 3 — Σωστό ή Λάθος;"
			_start_quiz(LEVEL1_QUIZ_PATH, true)
		2:
			%HintLabel.text = "Επίπεδο 2 από 3 — Πολλαπλή Επιλογή"
			_start_quiz(LEVEL2_QUIZ_PATH, false)
		3:
			%HintLabel.text = "Επίπεδο 3 από 3 — Αντιστοίχιση"
			_start_matching()

func _clear_exercise_area() -> void:
	for c in %ExercisesContainer.get_children():
		c.queue_free()
	_answer_buttons.clear()

## Λάθος σε ΟΠΟΙΟΔΗΠΟΤΕ level -> ξαναρχίζει η ΙΔΙΑ απόπειρα από το Level 1
## (Σ/Λ 1/3), ΧΩΡΙΣ να κλείσει/βγάλει τον παίκτη από την οθόνη — μόνο το
## «◄ Πίσω» ή η πλήρης επιτυχία (βλ. _finish) κλείνουν το popup. Ο παίκτης
## έχει ούτως ή άλλως απεριόριστες προσπάθειες τη μέρα (βλ. GameData.
## record_daily_quest_result), οπότε δεν υπάρχει λόγος να βγει καν.
##
## Το timer που καλεί αυτή τη συνάρτηση (βλ. _on_answer_result/
## _on_matching_round_completed) ΔΕΝ ακυρώνεται αν ο παίκτης πατήσει «◄ Πίσω»
## ΚΑΤΑ ΤΗ ΔΙΑΡΚΕΙΑ του σύντομου μηνύματος λάθους — θα εξακολουθούσε να
## πυροδοτείται αργότερα και να ξαναχτίζει σιωπηλά το Level 1 ΠΙΣΩ από την
## ήδη κλειστή/completion οθόνη. Το guard εδώ το εμποδίζει: αν η απόπειρα
## έχει ήδη τερματίσει (_finished == true, μέσω back-press ή επιτυχίας) όταν
## χτυπήσει το timer, δεν κάνει τίποτα.
func _restart_attempt() -> void:
	if _finished:
		return
	_start_level(1)


# ═══════════════════════════════════════════════════════════════════════════
# LEVEL 1 / 2 — QuizManager (Σωστό/Λάθος ή A-F, ίδιο engine/JSON με
# cotton_popup.gd / blacksmith_popup.gd)
# ═══════════════════════════════════════════════════════════════════════════
func _start_quiz(path: String, true_false: bool) -> void:
	_quiz = QuizManager.new()
	if not _quiz.load_from_file(path):
		_show_load_error()
		return
	_quiz.question_changed.connect(_on_question_changed)
	_quiz.answer_result.connect(_on_answer_result)
	_quiz.quiz_completed.connect(_on_quiz_completed)
	_build_quiz_ui(true_false)
	_quiz.start(true, QUESTIONS_PER_LEVEL)

func _build_quiz_ui(true_false: bool) -> void:
	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_font_size_override("font_size", 24)
	_progress_label.add_theme_color_override("font_color", C_GOLD_S)
	%ExercisesContainer.add_child(_progress_label)

	_q_label = Label.new()
	_q_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_q_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_q_label.custom_minimum_size = Vector2(0, 260)
	_q_label.add_theme_font_size_override("font_size", 30)
	_q_label.add_theme_color_override("font_color", C_BONE)
	%ExercisesContainer.add_child(_q_label)

	_answer_buttons.clear()
	if true_false:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 20)
		%ExercisesContainer.add_child(row)

		var btn_true := _make_answer_button("ΣΩΣΤΟ", C_OK)
		btn_true.pressed.connect(_submit_answer.bind("ΣΩΣΤΟ"))
		row.add_child(btn_true)
		_answer_buttons.append(btn_true)

		var btn_false := _make_answer_button("ΛΑΘΟΣ", C_BAD)
		btn_false.pressed.connect(_submit_answer.bind("ΛΑΘΟΣ"))
		row.add_child(btn_false)
		_answer_buttons.append(btn_false)
	else:
		var grid := GridContainer.new()
		grid.columns = 3
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 16)
		%ExercisesContainer.add_child(grid)
		for letter in KEY_LETTERS:
			var btn := _make_answer_button(letter, C_GOLD)
			btn.custom_minimum_size = Vector2(150, 90)
			btn.pressed.connect(_submit_answer.bind(letter))
			grid.add_child(btn)
			_answer_buttons.append(btn)

	_feedback = Label.new()
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.custom_minimum_size = Vector2(0, 50)
	_feedback.add_theme_font_size_override("font_size", 28)
	%ExercisesContainer.add_child(_feedback)

func _make_answer_button(text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 100)
	btn.add_theme_font_size_override("font_size", 30)

	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.085, 0.075, 0.055, 0.95)
	n.border_color = accent.darkened(0.25)
	n.set_border_width_all(4)
	n.set_corner_radius_all(12)
	n.shadow_color = Color(0, 0, 0, 0.55)
	n.shadow_size = 6
	btn.add_theme_stylebox_override("normal", n)

	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.140, 0.120, 0.085, 0.98)
	h.border_color = accent
	h.shadow_color = accent.lightened(0.10)
	h.shadow_size = 14
	btn.add_theme_stylebox_override("hover", h)

	var pr := n.duplicate() as StyleBoxFlat
	pr.bg_color = Color(0.055, 0.045, 0.030, 0.98)
	pr.border_color = accent.darkened(0.35)
	btn.add_theme_stylebox_override("pressed", pr)

	var dis := n.duplicate() as StyleBoxFlat
	dis.bg_color = Color(0.085, 0.075, 0.055, 0.5)
	dis.border_color = C_GOLD_D.darkened(0.25)
	btn.add_theme_stylebox_override("disabled", dis)
	btn.add_theme_stylebox_override("focus", StyleBoxFlat.new())

	btn.add_theme_color_override("font_color", C_BONE)
	btn.add_theme_color_override("font_hover_color", accent.lightened(0.35))
	btn.add_theme_color_override("font_pressed_color", accent)
	btn.add_theme_color_override("font_disabled_color", C_BONE_D)
	return btn

func _on_question_changed(index: int, total: int, question_text: String) -> void:
	_q_label.text = question_text
	_progress_label.text = "Ερώτηση %d / %d" % [index + 1, total]
	_feedback.text = ""
	_set_answer_buttons_enabled(true)

func _submit_answer(text: String) -> void:
	if _quiz == null:
		return
	_set_answer_buttons_enabled(false)
	_quiz.submit_answer(text)

func _on_answer_result(correct: bool) -> void:
	if correct:
		_feedback.add_theme_color_override("font_color", C_OK)
		_feedback.text = "✔  Σωστό!"
		var t := get_tree().create_timer(0.7)
		t.timeout.connect(func():
			if not _finished and is_instance_valid(_quiz):
				_quiz.advance()
		)
	else:
		_feedback.add_theme_color_override("font_color", C_BAD)
		_feedback.text = "✘  Λάθος! Θα ξεκινήσεις ξανά από την αρχή..."
		var t := get_tree().create_timer(1.8)
		t.timeout.connect(func(): _restart_attempt())

func _on_quiz_completed(_score: int, _total: int) -> void:
	if _level == 1:
		_start_level(2)
	else:
		_start_level(3)

func _set_answer_buttons_enabled(enabled: bool) -> void:
	for btn in _answer_buttons:
		btn.disabled = not enabled


# ═══════════════════════════════════════════════════════════════════════════
# LEVEL 3 — MatchingQuizManager (ίδιο engine/JSON με miner_popup.gd, αλλά
# pair_count=3 αντί για 5 — βλ. γενίκευση στο MatchingQuizManager.gd)
# ═══════════════════════════════════════════════════════════════════════════
func _start_matching() -> void:
	_matching = MatchingQuizManager.new()
	if not _matching.load_from_file(LEVEL3_QUIZ_PATH):
		_show_load_error()
		return
	_matching.round_ready.connect(_on_matching_round_ready)
	_matching.round_completed.connect(_on_matching_round_completed)
	_matching.session_completed.connect(_on_matching_session_completed)
	_build_matching_ui()
	_matching.start_session(LEVEL3_ROUNDS, LEVEL3_PAIRS)

func _build_matching_ui() -> void:
	_matching_round_progress = Label.new()
	_matching_round_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_matching_round_progress.add_theme_font_size_override("font_size", 22)
	_matching_round_progress.add_theme_color_override("font_color", C_GOLD_S)
	%ExercisesContainer.add_child(_matching_round_progress)

	var title := Label.new()
	title.text = "Σύρε κάθε στοιχείο στη σωστή αντιστοιχία"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", C_BONE)
	%ExercisesContainer.add_child(title)

	var grid_row := HBoxContainer.new()
	grid_row.add_theme_constant_override("separation", 20)
	%ExercisesContainer.add_child(grid_row)

	_left_col = VBoxContainer.new()
	_left_col.add_theme_constant_override("separation", 20)
	_left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_row.add_child(_left_col)

	grid_row.add_child(VSeparator.new())

	_right_col = VBoxContainer.new()
	_right_col.add_theme_constant_override("separation", 20)
	_right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_row.add_child(_right_col)

	_matching_feedback = Label.new()
	_matching_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_matching_feedback.custom_minimum_size = Vector2(0, 40)
	_matching_feedback.add_theme_font_size_override("font_size", 26)
	_matching_feedback.add_theme_color_override("font_color", C_BONE)
	%ExercisesContainer.add_child(_matching_feedback)

func _on_matching_round_ready(round_index: int, total_rounds: int, left: Array, right: Array) -> void:
	_matching_round_progress.text = "Γύρος %d / %d" % [round_index + 1, total_rounds]
	_render_matching_round(left, right)

func _render_matching_round(left: Array, right: Array) -> void:
	_matching_result_shown = false
	_matching_feedback.text = "Σύρε κάθε στοιχείο πάνω στο σωστό ταίρι του"

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
		_left_col.add_child(_make_left_row(i, str(left[i])))
	for i in range(right.size()):
		_right_col.add_child(_make_right_row(i, str(right[i])))

func _make_left_row(index: int, text: String) -> MatchDragItem:
	var row := MatchDragItem.new()
	row.is_source = true
	row.payload = index
	row.preview_text = "%d.  %s" % [index + 1, text]
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	# Σημαντικά μεγαλύτερο ελάχιστο ύψος -> πολύ πιο εύκολο να πιάσεις/σύρεις/
	# αφήσεις το στοιχείο (πριν καθοριζόταν μόνο από το περιεχόμενο, πολύ
	# λεπτό). Εδώ υπάρχει άφθονος ελεύθερος κατακόρυφος χώρος (μόνο 3
	# ζευγάρια), οπότε δεν χρειάζεται αλλαγή στο μέγεθος του container.
	row.custom_minimum_size = Vector2(0, 150)
	row.add_theme_stylebox_override("panel", _row_style(C_STONE))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hbox)

	var badge := _row_badge(str(index + 1), C_GOLD)
	hbox.add_child(badge)

	var lbl := Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 25)
	lbl.add_theme_color_override("font_color", C_BONE)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(lbl)

	_left_rows.append(row)
	_left_row_labels.append(lbl)
	return row

func _make_right_row(index: int, text: String) -> MatchDragItem:
	var row := MatchDragItem.new()
	row.is_target = true
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.custom_minimum_size = Vector2(0, 150)
	row.add_theme_stylebox_override("panel", _row_style(C_STONE))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hbox)

	hbox.add_child(_row_badge(MatchingQuizManager.LETTERS[index], C_GOLD_D.lightened(0.3)))

	var assigned := Label.new()
	assigned.text = "—"
	assigned.custom_minimum_size = Vector2(42, 0)
	assigned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	assigned.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	assigned.add_theme_font_size_override("font_size", 25)
	assigned.add_theme_color_override("font_color", C_GOLD)
	assigned.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(assigned)

	var lbl := Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 25)
	lbl.add_theme_color_override("font_color", C_BONE)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(lbl)

	row.dropped_on.connect(_on_dropped_on_slot.bind(index))

	_right_rows.append(row)
	_right_assigned_labels.append(assigned)
	return row

func _row_badge(text: String, color: Color) -> Control:
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(56, 56)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.3)
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(28)
	badge.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	badge.add_child(lbl)
	return badge

func _row_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(bg.r, bg.g, bg.b, 0.65)
	s.border_color = C_GOLD_D
	s.set_border_width_all(1)
	s.set_corner_radius_all(12)
	# Μεγαλύτερο εσωτερικό padding ώστε το κείμενο να μην κολλάει στα άκρα
	# του πολύ ψηλότερου πλέον πλαισίου.
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 20
	s.content_margin_bottom = 20
	return s

func _on_dropped_on_slot(payload: Variant, right_index: int) -> void:
	if _matching == null or _matching_result_shown or typeof(payload) != TYPE_INT:
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
	_update_matching_progress()

func _set_left_row_placed(index: int, placed: bool) -> void:
	var row := _left_rows[index]
	var style := _row_style(C_STONE.darkened(0.35)) if placed else _row_style(C_STONE)
	if placed:
		style.border_color = C_GOLD
	row.add_theme_stylebox_override("panel", style)
	row.modulate.a = 0.55 if placed else 1.0

func _set_slot_assignment(right_index: int, left_index: int) -> void:
	_right_assigned_labels[right_index].text = str(left_index + 1) if left_index >= 0 else "—"

func _update_matching_progress() -> void:
	var placed: int = _left_locked.count(true)
	if placed < _left_locked.size():
		_matching_feedback.text = "Τοποθετήθηκαν %d / %d" % [placed, _left_locked.size()]

func _on_matching_round_completed(_round_index: int, _total_rounds: int, correct_count: int, pair_total: int, _earned: int, flags: Array) -> void:
	_matching_result_shown = true
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

	if correct_count == pair_total:
		_matching_feedback.add_theme_color_override("font_color", C_OK)
		_matching_feedback.text = "Όλα σωστά! (%d/%d)" % [correct_count, pair_total]
		var t := get_tree().create_timer(1.6)
		t.timeout.connect(func():
			if not _finished and is_instance_valid(_matching):
				_matching.advance()
		)
	else:
		_matching_feedback.add_theme_color_override("font_color", C_BAD)
		_matching_feedback.text = "%d/%d σωστά — Θα ξεκινήσεις ξανά από την αρχή..." % [correct_count, pair_total]
		var t2 := get_tree().create_timer(2.0)
		t2.timeout.connect(func(): _restart_attempt())

func _on_matching_session_completed(_total_correct: int, _total_pairs: int, _total_earned: int) -> void:
	_finish(3)


# ═══════════════════════════════════════════════════════════════════════════
# ΤΕΛΟΣ ΑΠΟΠΕΙΡΑΣ — καταγραφή αποτελέσματος (streak-only, καμία ανταμοιβή)
# ═══════════════════════════════════════════════════════════════════════════
func _finish(levels_completed: int) -> void:
	if _finished:
		return
	_finished = true
	_set_answer_buttons_enabled(false)

	var clamped := clampi(levels_completed, 0, 3)
	GameData.record_daily_quest_result(clamped)

	var title := "Δεν τα κατάφερες αυτή τη φορά..."
	var subtitle := "Το streak σου είναι ασφαλές — ξαναπροσπάθησε όσες φορές θέλεις!"
	if clamped >= 3:
		title = "Άριστα! Ολοκλήρωσες όλο το Daily Quest!"
		subtitle = "Το streak σου ανανεώθηκε! Έλα ξανά αύριο για να το κρατήσεις."
	elif clamped > 0:
		title = "Ολοκλήρωσες %d από τα 3 levels..." % clamped
	_show_completion(title, subtitle)

func _show_load_error() -> void:
	var lbl := Label.new()
	lbl.text = "⚠  Δεν ήταν δυνατή η φόρτωση των ασκήσεων."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", C_BAD)
	%ExercisesContainer.add_child(lbl)

func _show_completion(title_text: String, subtitle_text: String) -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_completion = overlay

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	const PW := 860.0
	const PH := 420.0
	var px := (1080.0 - PW) / 2.0
	var py := (1920.0 - PH) / 2.0

	var panel := Panel.new()
	panel.position = Vector2(px, py)
	panel.size = Vector2(PW, PH)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.075, 0.052, 0.024, 0.97)
	psb.border_color = C_GOLD
	psb.set_border_width_all(4)
	psb.set_corner_radius_all(20)
	psb.shadow_color = Color(0, 0, 0, 0.6)
	psb.shadow_size = 16
	panel.add_theme_stylebox_override("panel", psb)
	overlay.add_child(panel)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(px + 40, py + 40)
	title.size = Vector2(PW - 80, 140)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", C_GOLD_S)
	overlay.add_child(title)

	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.position = Vector2(px + 40, py + 190)
	subtitle.size = Vector2(PW - 80, 80)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 26)
	subtitle.add_theme_color_override("font_color", C_BONE_D)
	overlay.add_child(subtitle)

	var close_btn := Button.new()
	close_btn.text = "Κλείσιμο"
	close_btn.position = Vector2(px + PW / 2 - 150, py + PH - 110)
	close_btn.size = Vector2(300, 80)
	close_btn.add_theme_font_size_override("font_size", 30)
	_style_close_btn(close_btn)
	overlay.add_child(close_btn)
	close_btn.pressed.connect(close_popup)

func _style_close_btn(btn: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.130, 0.090, 0.030)
	n.border_color = C_GOLD.darkened(0.15)
	n.set_border_width_all(4)
	n.set_corner_radius_all(12)
	n.shadow_color = Color(0, 0, 0, 0.6)
	n.shadow_size = 6
	btn.add_theme_stylebox_override("normal", n)

	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.180, 0.130, 0.045)
	h.border_color = C_GOLD
	btn.add_theme_stylebox_override("hover", h)

	var pr := n.duplicate() as StyleBoxFlat
	pr.border_color = C_GOLD.darkened(0.3)
	btn.add_theme_stylebox_override("pressed", pr)
	btn.add_theme_stylebox_override("focus", StyleBoxFlat.new())

	btn.add_theme_color_override("font_color", C_GOLD)
	btn.add_theme_color_override("font_hover_color", C_GOLD_S)
