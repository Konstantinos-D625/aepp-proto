extends Control

# ── Μονοπάτια εικόνων ─────────────────────────────────────────────────────
const BG_PATH     := "res://Εικόνες/blacksmith-bg.png"
const CHAR_PATH   := "res://Εικόνες/blacksmith.png"
const BOARD_PATH  := "res://Εικόνες/board.png"

# ── Σύστημα ασκήσεων ──────────────────────────────────────────────────────
# Οι 20 ασκήσεις ΑΕΠΠ. Ο παίκτης γράφει την απάντηση με το πληκτρολόγιο
# οθόνης (βλ. _build_keyboard) — δεν είναι πολλαπλής επιλογής, εκτός από την
# τελευταία ("mode": "choice" στο JSON).
#
# ΠΡΟΣΟΧΗ: το παλιό blacksmith_quiz.json (A-F) ΔΕΝ διαγράφηκε — το
# χρησιμοποιεί ακόμη το Level 2 του daily_quest_exercises.gd.
const QUIZ_PATH := "res://blacksmith_exercises.json"

# 5 τυχαίες ασκήσεις από τις 20 ανά επίσκεψη (βλ. _quiz.start πιο κάτω,
# shuffle=true) — ίδιο μοτίβο με τη Δερματού (cotton_popup.gd).
const QUESTIONS_PER_ROUND := 5

# Loot: μόνο σίδερο. Η ποσότητα εξαρτάται από τη ΔΥΣΚΟΛΙΑ των ερωτήσεων που
# απαντήθηκαν σωστά. Δίνεται όταν φεύγεις, αρκεί να απάντησες ≥1 ερώτηση.
const IRON_BASE := 2

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

# ── Πεδίο απάντησης + πληκτρολόγιο οθόνης ─────────────────────────────────
# Το πεδίο απάντησης είναι Label μέσα σε Panel, ΟΧΙ LineEdit: ένα LineEdit
# (ακόμη κι editable=false) μπορεί να πάρει focus και να σηκώσει το
# πληκτρολόγιο του κινητού — που είναι ακριβώς ό,τι θέλουμε να αποφύγουμε.
var _answer_text  := ""
var _answer_label : Label
var _keyboard     : Control   # πλήρες πληκτρολόγιο (ασκήσεις 1-19)
var _extra_actions: Control   # κενό/Σβήσε/Καθαρισμός — ξεχωριστά απ' το πληκτρολόγιο
var _choices      : Control   # 4 κουμπιά επιλογής (άσκηση 20)
var _keys         : Array[Button] = []   # όλα τα πλήκτρα, για enable/disable

# Λέξεις-κουμπιά: ένα πάτημα = όλη η λέξη.
# Το ΟΧΙ είναι ένα κουμπί που καλύπτει και τον λογικό τελεστή και την
# απάντηση "ΟΧΙ" — δύο ξεχωριστά κουμπιά θα έγραφαν ακριβώς το ίδιο κείμενο.
const WORD_KEYS_A: Array[String] = ["div", "mod", "ΚΑΙ", "Ή", "ΟΧΙ", "ΝΑΙ"]
const WORD_KEYS_B: Array[String] = ["ΑΛΗΘΗΣ", "ΨΕΥΔΗΣ", "ΑΚΕΡΑΙΑ", "ΑΡΤΙΟΣ"]
const WORD_KEYS_C: Array[String] = ["ΠΡΑΓΜΑΤΙΚΗ", "ΧΑΡΑΚΤΗΡΕΣ", "ΛΟΓΙΚΗ"]

const DIGIT_KEYS: Array[String] = ["0","1","2","3","4","5","6","7","8","9"]
const GREEK_KEYS: Array[String] = ["χ","ψ","α","β","Χ","(",")","'",".",","]
const OPER_KEYS:  Array[String] = ["+","-","*","/","^","=","<",">","<=",">="]

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
	_set_answer("")
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

# ── Φυσικό πληκτρολόγιο: μόνο Backspace/Enter, για δοκιμή σε υπολογιστή.
#    Στο κινητό η απάντηση γράφεται αποκλειστικά από το πληκτρολόγιο οθόνης
#    — γι' αυτό δεν δεχόμαστε γράμματα από τη συσκευή. ──────────────────────
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or _state != 2 or _input_locked:
		return
	var ke := event as InputEventKey
	if ke == null or not ke.pressed or ke.echo:
		return
	match ke.keycode:
		KEY_BACKSPACE:
			_on_backspace()
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			_on_submit()
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
# Το blacksmith.png είναι 1408×768 landscape καμβάς με ΤΕΡΑΣΤΙΑ διάφανα
# περιθώρια — ο σιδεράς καταλαμβάνει μόνο το CHAR_REGION παρακάτω. Χωρίς το
# crop, το EXPAND_FIT_WIDTH_PROPORTIONAL φούσκωνε το control σε 1760×960 και
# ο σιδεράς κατέληγε σχεδόν ολόκληρος ΕΚΤΟΣ οθόνης δεξιά (αόρατος). Ίδια
# λύση με τον γέρο του tutorial (old_man_popup.gd::CHAR_REGION).
const CHAR_REGION := Rect2(478, 12, 500, 744)

func _build_character() -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas  = load(CHAR_PATH)
	atlas.region = CHAR_REGION
	var char_rect := TextureRect.new()
	char_rect.texture      = atlas
	char_rect.position     = Vector2(470, 580)
	char_rect.size         = Vector2(510, 960)
	char_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
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
	# Αρκετό ύψος ώστε το Label (11 γραμμές × ~35px στο font 25) να χωράει στο
	# BH-130 — στα 460 κόβονταν οι 2 τελευταίες γραμμές της ομιλίας.
	const BH := 545.0

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
	msg.text = "Α! Καλωσόρισες, περιπλανώμενε!\n\nΘα χαρώ να σε βοηθήσω\nμε υλικά για το ταξίδι σου...\n\nΑλλά πρώτα λύσε τις 20\nασκήσεις μου! Θα βλέπεις\nτο πρόβλημα στον πίνακα και\nθα γράφεις την απάντηση με το\nπληκτρολόγιο του σιδηρουργείου.\nΜετά πάτα ΥΠΟΒΟΛΗ!"
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

# ── Board (Κατάσταση 2) — εκφώνηση + πεδίο απάντησης ──────────────────────
# Ο πίνακας κρατά ΜΟΝΟ την εκφώνηση και την απάντηση. Το πληκτρολόγιο μπαίνει
# ΚΑΤΩ από τον πίνακα (KB_Y), γι' αυτό ο πίνακας είναι πιο κοντός/ψηλά απ' ό,τι
# όταν είχε τα 6 πλήκτρα A-F μέσα του.
func _build_board() -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Πιο ψηλά και πιο κοντό απ' ό,τι πριν (BRD_Y 70→20, BRD_H 990→880) ώστε να
	# ελευθερωθεί χώρος για το πληκτρολόγιο από κάτω να σπάσει σε περισσότερες,
	# πιο φαρδιές (άρα πιο εύκολα πατήσιμες σε κινητό) σειρές.
	const BRD_X := 60.0
	const BRD_Y := 20.0
	const BRD_W := 960.0
	const BRD_H := 880.0

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
	# Το board.png έχει διάφανο περιθώριο γύρω από το ξύλινο πλαίσιο: το ίδιο
	# το χρυσό πλαίσιο ξεκινά στο ~19.2% του ύψους του TextureRect και τελειώνει
	# ~12.3% πριν τη βάση του (μετρημένο στο παλιό BRD_H=990 ως 190/122px) — τα
	# margins είναι κλιμακωμένα ανάλογα με το ΝΕΟ BRD_H=880 (190·0.889≈169,
	# 122·0.889≈108) ώστε να παραμείνουν ευθυγραμμισμένα με το ξύλινο πλαίσιο
	# της εικόνας. Αν αλλάξει ξανά το BRD_H, ξανά-κλιμάκωσε αναλογικά.
	pad.add_theme_constant_override("margin_left",   110)
	pad.add_theme_constant_override("margin_right",  110)
	pad.add_theme_constant_override("margin_top",    169)
	pad.add_theme_constant_override("margin_bottom", 108)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
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
	_q_label.custom_minimum_size  = Vector2(0, 350)
	_q_label.add_theme_font_size_override("font_size", 30)
	_q_label.add_theme_color_override("font_color", C_PARCH)
	_q_label.add_theme_color_override("font_shadow_color", Color(0,0,0,0.85))
	_q_label.add_theme_constant_override("shadow_offset_x", 1)
	_q_label.add_theme_constant_override("shadow_offset_y", 2)
	_q_label.add_theme_constant_override("line_spacing", 10)
	_q_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_q_label)

	col.add_child(_build_answer_field())

	_feedback = Label.new()
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	# Autowrap σαν προφύλαξη, αλλά το feedback είναι πάντα μία σύντομη γραμμή
	# ("✔ Σωστό!" / "✘ Λάθος — πάμε στην επόμενη") — η σωστή απάντηση δεν
	# αποκαλύπτεται πια, οπότε δεν χρειάζεται ύψος για πολλαπλές γραμμές.
	_feedback.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_feedback.custom_minimum_size  = Vector2(0, 55)
	_feedback.add_theme_font_size_override("font_size", 23)
	_feedback.add_theme_color_override("font_shadow_color", Color(0,0,0,0.85))
	_feedback.add_theme_constant_override("shadow_offset_x", 1)
	_feedback.add_theme_constant_override("shadow_offset_y", 2)
	_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_feedback)

	# ── Μπάρα κενό/Σβήσε/Καθαρισμός, ΠΑΝΩ από το πληκτρολόγιο ─────────────
	# Ξεχωριστά απ' τα υπόλοιπα πλήκτρα (δεν είναι κουμπιά συμπλήρωσης, είναι
	# ενέργειες πάνω στην ήδη γραμμένη απάντηση) — δικό τους πλαίσιο με
	# κόκκινο (C_CRIMSON) περίγραμμα αντί για χρυσό, ώστε να ξεχωρίζουν οπτικά.
	const EXTRA_X := 30.0
	const EXTRA_Y := BRD_Y + BRD_H + 8.0
	const EXTRA_W := 1020.0
	const EXTRA_H := 76.0

	# ── Πληκτρολόγιο / κουμπιά επιλογής, ΚΑΤΩ από τη μπάρα ────────────────
	# Τελειώνουν στο 1776, πάνω από το κουμπί "Πίσω στο Χωριό" (H-138 = 1782) —
	# όλα τα κενά γύρω (μετά το board, πριν το πληκτρολόγιο, πριν το "Πίσω")
	# σφίχτηκαν στο ελάχιστο ώστε όσο περισσότερο ύψος να πάει στις ίδιες τις
	# σειρές πλήκτρων (βλ. _build_keyboard) — ~68px ανά σειρά.
	const KB_X := 30.0
	const KB_Y := EXTRA_Y + EXTRA_H + 10.0
	const KB_W := 1020.0
	const KB_H := 782.0

	_keys.clear()

	_extra_actions = _build_extra_actions()
	_extra_actions.position = Vector2(EXTRA_X, EXTRA_Y)
	_extra_actions.size     = Vector2(EXTRA_W, EXTRA_H)
	root.add_child(_extra_actions)

	_keyboard = _build_keyboard()
	_keyboard.position = Vector2(KB_X, KB_Y)
	_keyboard.size     = Vector2(KB_W, KB_H)
	root.add_child(_keyboard)

	_choices = _build_choices()
	_choices.position = Vector2(KB_X, KB_Y)
	_choices.size     = Vector2(KB_W, KB_H)
	_choices.visible  = false
	root.add_child(_choices)

	return root

# ── Πεδίο απάντησης (readonly) ────────────────────────────────────────────
func _build_answer_field() -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 100)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color     = Color(0.060, 0.055, 0.045, 0.92)
	s.border_color = C_GOLD_D
	s.set_border_width_all(3)
	s.set_corner_radius_all(10)
	p.add_theme_stylebox_override("panel", s)

	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left",  14)
	m.add_theme_constant_override("margin_right", 14)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(m)

	_answer_label = Label.new()
	_answer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_answer_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_answer_label.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_answer_label.add_theme_font_size_override("font_size", 30)
	_answer_label.add_theme_color_override("font_color", C_GOLD_S)
	_answer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(_answer_label)

	return p

# ── Πληκτρολόγιο σιδηρουργού — μεταλλικό πλαίσιο, φιλικό για κινητό ────────
func _build_keyboard() -> Control:
	var frame := _steel_frame()

	var vcol := VBoxContainer.new()
	# separation ανάμεσα στις σειρές: αρκετό ώστε να μη γίνονται λάθος
	# πατήματα σε γειτονική σειρά, αλλά όχι παραπάνω — κάθε px εδώ είναι px
	# που δεν πάει στο ύψος του ίδιου του πλήκτρου.
	vcol.add_theme_constant_override("separation", 10)
	vcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_body(frame, 8).add_child(vcol)

	# Οι σειρές των 10 πλήκτρων (ψηφία/γράμματα/τελεστές) έσπασαν η καθεμία σε
	# 2 σειρές των 5-6 — τα πλήκτρα σχεδόν διπλασιάζουν πλάτος, πολύ πιο
	# εύκολα στο άγγιγμα σε κινητό, με το κόστος λίγο παραπάνω σειρών (γι'
	# αυτό και το KB_H μεγάλωσε παραπάνω στο _build_board).
	vcol.add_child(_key_row(DIGIT_KEYS.slice(0, 5), 30))
	vcol.add_child(_key_row(DIGIT_KEYS.slice(5, 10), 30))
	vcol.add_child(_key_row(GREEK_KEYS.slice(0, 5), 30))
	vcol.add_child(_key_row(GREEK_KEYS.slice(5, 10), 30))
	# "<>" (διάφορο) και "←" (ανάθεση) μαζί με τους υπόλοιπους τελεστές — είναι
	# επίσης σύμβολα-συμπλήρωσης, όχι ενέργειες, οπότε μένουν στο πληκτρολόγιο
	# (σε αντίθεση με το κενό/Σβήσε/Καθαρισμός, βλ. _build_extra_actions).
	vcol.add_child(_key_row(OPER_KEYS.slice(0, 6), 28))
	vcol.add_child(_key_row(OPER_KEYS.slice(6, 10) + ["<>", "←"], 28))
	vcol.add_child(_key_row(WORD_KEYS_A, 26))
	vcol.add_child(_key_row(WORD_KEYS_B, 22))
	vcol.add_child(_key_row(WORD_KEYS_C, 22))
	vcol.add_child(_build_submit_row())

	return frame

## Σειρά πλήκτρων: κάθε στοιχείο του items γίνεται ένα πλήκτρο-κουμπί.
func _key_row(items: Array, font_size: int) -> Control:
	var row := _kb_row()
	for t in items:
		var s := str(t)
		row.add_child(_make_key(s, s, font_size))
	return row

## Κενό / Σβήσε / Καθαρισμός — ενέργειες πάνω στην απάντηση, ΟΧΙ πλήκτρα
## συμπλήρωσης· γι' αυτό ζουν στη δική τους μπάρα, πάνω απ' το πληκτρολόγιο,
## με ξεχωριστό (κόκκινο) στυλ ώστε να ξεχωρίζουν αμέσως οπτικά.
func _build_extra_actions() -> Control:
	var frame := _steel_frame()
	(frame.get_theme_stylebox("panel") as StyleBoxFlat).border_color = C_CRIMSON

	var row := _kb_row()
	_frame_body(frame, 10).add_child(row)

	var space := _make_key("κενό", " ", 26)
	space.size_flags_stretch_ratio = 1.6
	_style_action_btn(space)
	row.add_child(space)

	# "Σβήσε" αντί για το σύμβολο ⌫: η γραμματοσειρά του παιχνιδιού δεν έχει
	# glyph για το U+232B και έβγαινε άδειο τετραγωνάκι στην οθόνη.
	var bs := _make_action_key("Σβήσε", 26, _on_backspace)
	bs.size_flags_stretch_ratio = 1.3
	_style_action_btn(bs)
	row.add_child(bs)

	var clr := _make_action_key("Καθαρισμός", 24, _on_clear)
	clr.size_flags_stretch_ratio = 1.8
	_style_action_btn(clr)
	row.add_child(clr)

	return frame

func _build_submit_row() -> Control:
	var row := _kb_row()
	row.add_child(_make_action_key("✔   ΥΠΟΒΟΛΗ", 30, _on_submit))
	return row

# ── Άσκηση 20: 4 κουμπιά επιλογής αντί για πληκτρολόγιο ───────────────────
func _build_choices() -> Control:
	var frame := _steel_frame()

	var vcol := VBoxContainer.new()
	vcol.add_theme_constant_override("separation", 14)
	vcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_body(frame, 20).add_child(vcol)

	var title := Label.new()
	title.text = "Διάλεξε τη σωστή απάντηση"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", C_GOLD_S)
	title.add_theme_color_override("font_shadow_color", Color(0,0,0,0.85))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vcol.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vcol.add_child(grid)

	for i in range(1, 5):
		var btn := Button.new()
		btn.text = str(i)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		_style_key_btn(btn, 56)
		btn.pressed.connect(_on_choice_pressed.bind(str(i)))
		_keys.append(btn)
		grid.add_child(btn)

	return frame

# ── Κοινά δομικά κομμάτια πληκτρολογίου / κουμπιών επιλογής ───────────────
func _steel_frame() -> Panel:
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := StyleBoxFlat.new()
	fs.bg_color     = C_STEEL_D
	fs.border_color = C_STEEL
	fs.set_border_width_all(5)
	fs.set_corner_radius_all(16)
	fs.shadow_color = Color(0, 0, 0, 0.55)
	fs.shadow_size  = 12
	frame.add_theme_stylebox_override("panel", fs)
	return frame

func _frame_body(frame: Panel, margin: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left",   margin)
	m.add_theme_constant_override("margin_right",  margin)
	m.add_theme_constant_override("margin_top",    margin)
	m.add_theme_constant_override("margin_bottom", margin)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(m)
	return m

func _kb_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	# 8→10: λίγο παραπάνω χώρος ανάμεσα στα πλήκτρα ώστε να μειωθούν τα λάθος
	# πατήματα σε γειτονικό πλήκτρο στο κινητό.
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row

## Πλήκτρο που προσθέτει κείμενο στην απάντηση.
func _make_key(label_text: String, insert_text: String, font_size: int) -> Button:
	var btn := _new_key_button(label_text, font_size)
	btn.pressed.connect(_on_char_pressed.bind(insert_text))
	return btn

## Πλήκτρο ενέργειας (⌫ / Καθαρισμός / Υποβολή).
func _make_action_key(label_text: String, font_size: int, cb: Callable) -> Button:
	var btn := _new_key_button(label_text, font_size)
	btn.pressed.connect(cb)
	return btn

func _new_key_button(label_text: String, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.clip_text = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_style_key_btn(btn, font_size)
	_keys.append(btn)
	return btn

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
	# shuffle=true: διαφορετικές 5 ασκήσεις (από τις 20) σε κάθε επίσκεψη.
	_quiz.start(true, QUESTIONS_PER_ROUND)

func _on_question_changed(index: int, total: int, question_text: String) -> void:
	if _loot_given:
		return
	_input_locked = false
	_q_label.text = question_text
	_progress.text = "Άσκηση %d / %d   •   Σκορ %d" % [index + 1, total, _quiz.get_score()]
	_feedback.text = ""
	_set_answer("")
	# Η τελευταία άσκηση είναι πολλαπλής επιλογής ("mode": "choice" στο JSON):
	# τότε το πληκτρολόγιο δίνει τη θέση του στα 4 κουμπιά 1-4.
	var is_choice := _quiz.get_current_mode() == "choice"
	_keyboard.visible      = not is_choice
	_extra_actions.visible = not is_choice
	_choices.visible       = is_choice
	_set_keyboard_enabled(true)

# ── Είσοδος από τα πλήκτρα ────────────────────────────────────────────────
const ANSWER_MAX_LEN := 60

func _on_char_pressed(text: String) -> void:
	if _input_locked or _state != 2:
		return
	if _answer_text.length() + text.length() > ANSWER_MAX_LEN:
		return
	_set_answer(_answer_text + text)

func _on_backspace() -> void:
	if _input_locked or _state != 2 or _answer_text.is_empty():
		return
	_set_answer(_answer_text.substr(0, _answer_text.length() - 1))

func _on_clear() -> void:
	if _input_locked or _state != 2:
		return
	_set_answer("")

func _on_submit() -> void:
	if _input_locked or _quiz == null or _state != 2:
		return
	if _answer_text.strip_edges().is_empty():
		return
	_answered += 1
	_quiz.submit_answer(_answer_text)

## Τα κουμπιά 1-4 της άσκησης 20 υποβάλλουν κατευθείαν.
func _on_choice_pressed(value: String) -> void:
	if _input_locked or _quiz == null or _state != 2:
		return
	_set_answer(value)
	_on_submit()

func _set_answer(text: String) -> void:
	_answer_text = text
	if not is_instance_valid(_answer_label):
		return
	if text.is_empty():
		_answer_label.text = "—"
		_answer_label.add_theme_color_override("font_color", C_GOLD_D)
	else:
		_answer_label.text = text
		_answer_label.add_theme_color_override("font_color", C_GOLD_S)

# ── Αποτέλεσμα ────────────────────────────────────────────────────────────
func _on_answer_result(correct: bool) -> void:
	_input_locked = true
	_set_keyboard_enabled(false)

	if correct:
		_feedback.add_theme_color_override("font_color", C_OK)
		_feedback.text = "✔  Σωστό!"
		_advance_later(0.9)
		return

	# Λάθος: καμία δεύτερη ευκαιρία — η σωστή απάντηση ΔΕΝ αποκαλύπτεται ποτέ
	# (το παιχνίδι είναι για εξάσκηση, η λύση πρέπει να βρεθεί, όχι να δοθεί),
	# και μία λάθος απάντηση προχωράει κατευθείαν στην επόμενη άσκηση.
	_feedback.add_theme_color_override("font_color", C_BAD)
	_feedback.text = "✘  Λάθος — πάμε στην επόμενη"
	_advance_later(1.4)

func _advance_later(sec: float) -> void:
	var t := get_tree().create_timer(sec)
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
	var total := _quiz.get_total() if _quiz else 0
	header.text = "Σωστές απαντήσεις: %d / %d\n\nΚέρδισες:" % [score, total]
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
## (υλικά όπως Σίδερο/Χαλκός, που δεν έχουν ακόμα δικό τους εικονίδιο εδώ).
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

# ── Ενεργοποίηση/απενεργοποίηση όλων των πλήκτρων ─────────────────────────
func _set_keyboard_enabled(enabled: bool) -> void:
	for btn in _keys:
		if is_instance_valid(btn):
			btn.disabled = not enabled

# ── Στυλ πλήκτρου (μεταλλικό keycap σιδηρουργείου) ──────────────────────────
func _style_key_btn(btn: Button, font_size: int = 30) -> void:
	btn.add_theme_font_size_override("font_size", font_size)
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

# ── Στυλ κουμπιού-ενέργειας (κενό/Σβήσε/Καθαρισμός — κόκκινο αντί για χρυσό
# περίγραμμα, ίδια βάση με το _style_key_btn ώστε να ξεχωρίζουν οπτικά από τα
# πλήκτρα συμπλήρωσης χωρίς να σπάνε το γενικό μεταλλικό στυλ) ────────────
func _style_action_btn(btn: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = C_IRON
	n.border_color = C_CRIMSON
	n.set_border_width_all(4)
	n.set_corner_radius_all(10)
	n.shadow_color = Color(0, 0, 0, 0.60)
	n.shadow_size = 5
	btn.add_theme_stylebox_override("normal", n)

	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = C_IRON.lightened(0.10)
	h.border_color = C_CRIMSON.lightened(0.25)
	h.shadow_color = C_CRIMSON.lightened(0.15)
	h.shadow_size = 14
	btn.add_theme_stylebox_override("hover", h)

	var pr := n.duplicate() as StyleBoxFlat
	pr.bg_color = Color(0.06, 0.055, 0.045)
	pr.border_color = C_CRIMSON.darkened(0.20)
	btn.add_theme_stylebox_override("pressed", pr)

	var dis := n.duplicate() as StyleBoxFlat
	dis.bg_color = C_IRON.darkened(0.30)
	dis.border_color = C_CRIMSON.darkened(0.45)
	btn.add_theme_stylebox_override("disabled", dis)

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
