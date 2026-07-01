extends Control

# ═══════════════════════════════════════════════════════════════════════════
# Daily Quest — Οθόνη Ασκήσεων (PLACEHOLDER)
# ═══════════════════════════════════════════════════════════════════════════
# Προσωρινή οθόνη· εμφανίζεται όταν ο παίκτης πατάει "ΠΑΜΕ" στο
# DailyQuestPopup. Οι πραγματικές ασκήσεις δεν υπάρχουν ακόμη — αυτό το
# script υλοποιεί ΜΟΝΟ την πλοήγηση και τη δομή, ώστε να μπορεί να
# επεκταθεί εύκολα αργότερα:
#
#   - Οι πραγματικές ασκήσεις πρέπει να προστεθούν μέσα στο
#     %ExercisesContainer (VBoxContainer, προς το παρόν άδειο).
#   - Σε ΚΑΘΕ σωστή απάντηση, η άσκηση πρέπει να καλεί:
#         GameData.record_daily_quest_correct_answer()
#     Σε λάθος απάντηση δεν καλείται τίποτα (αγνοείται σκόπιμα).
#   - Η μέτρηση/ολοκλήρωση/ανανέωση streak γίνεται αυτόματα από το
#     GameData· δεν χρειάζεται άλλος κώδικας εδώ.

func _ready() -> void:
	hide()
	if OS.is_debug_build():
		_build_debug_tools()


## Καλείται όταν ο παίκτης πατάει "ΠΑΜΕ" στο DailyQuestPopup.
func open() -> void:
	GameData.begin_daily_quest_session()
	show()
	_refresh_debug_label()

func close_popup() -> void:
	hide()

func _on_back_pressed() -> void:
	close_popup()


# ═══════════════════════════════════════════════════════════════════════════
# ΠΡΟΣΩΡΙΝΑ ΕΡΓΑΛΕΙΑ QA — εμφανίζονται ΜΟΝΟ σε debug builds (ποτέ σε
# εξαγόμενο/release build), ώστε να μπορεί να ελεγχθεί η καταμέτρηση
# σωστών απαντήσεων πριν προστεθούν οι πραγματικές ασκήσεις. Μπορούν να
# αφαιρεθούν με ασφάλεια μόλις υπάρξουν πραγματικές ασκήσεις που καλούν
# οι ίδιες το GameData.record_daily_quest_correct_answer().
# ═══════════════════════════════════════════════════════════════════════════
var _debug_label: Label

# Προστίθενται μέσα στο %ExercisesContainer (VBoxContainer) — η ίδια θέση
# όπου θα μπουν αργότερα οι πραγματικές ασκήσεις — οπότε το layout τους
# γίνεται αυτόματα από το container, χωρίς χειροκίνητο position/size.
func _build_debug_tools() -> void:
	var sep := HSeparator.new()
	%ExercisesContainer.add_child(sep)

	var box := HBoxContainer.new()
	box.name                 = "DebugTools"
	box.alignment             = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation", 24)
	%ExercisesContainer.add_child(box)

	var correct_btn := Button.new()
	correct_btn.text = "DEBUG: Σωστή απάντηση"
	correct_btn.pressed.connect(func() -> void:
		GameData.record_daily_quest_correct_answer()
		_refresh_debug_label()
	)
	box.add_child(correct_btn)

	var wrong_btn := Button.new()
	wrong_btn.text = "DEBUG: Λάθος απάντηση"
	wrong_btn.pressed.connect(func() -> void:
		pass # οι λανθασμένες απαντήσεις αγνοούνται σκόπιμα — δεν καλείται τίποτα
	)
	box.add_child(wrong_btn)

	_debug_label = Label.new()
	_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_debug_label.add_theme_font_size_override("font_size", 22)
	_debug_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	%ExercisesContainer.add_child(_debug_label)

func _refresh_debug_label() -> void:
	if _debug_label == null:
		return
	_debug_label.text = "[debug] σωστές σήμερα: %d/%d — ολοκληρωμένο: %s" % [
		GameData.daily_quest_correct_count,
		GameData.DAILY_QUEST_REQUIRED_CORRECT,
		str(GameData.is_daily_quest_completed_today())
	]
