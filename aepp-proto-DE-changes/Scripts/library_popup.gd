extends Control

# ── Μονοπάτια εικόνων ─────────────────────────────────────────────────────
# Η ΒΙΒΛΙΟΘΗΚΑΡΙΟΣ της περιοχής ΔΕ (σπιτάκι «ΒΙΒΛΙΟΘΗΚΗ» στο de.area.bg.png).
# Ίδια ροή με τον Αλχημιστή/Φούρναρη: σκηνή-με-NPC → μήνυμα → σκηνή-χωρίς-NPC
# + board με ασκήσεις.
#
# ⚠ ΕΥΘΥΓΡΑΜΜΙΣΗ ΤΩΝ ΔΥΟ ΕΙΚΟΝΩΝ — ΔΙΑΒΑΣΕ ΠΡΙΝ ΑΛΛΑΞΕΙΣ ΤΙΣ ΕΙΚΟΝΕΣ:
# στο φουρνάρικο και στο αλχημείο οι δύο εικόνες ήταν pixel-identical, οπότε
# αρκούσε να μπουν και οι δύο full-screen με KEEP_ASPECT_COVERED. Εδώ όχι:
#     library.bg2.png  1024×1536  (αναλογία 0.67)
#     library.bg.png    941×1672  (αναλογία 0.56)
# Είναι το ΙΔΙΟ δωμάτιο τραβηγμένο πιο μακριά και σε άλλο κάδρο. Αν έμπαιναν
# και οι δύο με COVERED, το δωμάτιο θα «πηδούσε» ~9% στο cross-fade.
#
# Λύση: η bg δεν μπαίνει full-screen· τοποθετείται με ΡΗΤΟ ορθογώνιο ώστε το
# περιεχόμενό της να πέφτει πάνω στο περιεχόμενο της bg2. Οι παράμετροι
# μετρήθηκαν αριθμητικά (ελαχιστοποίηση μέσης απόλυτης διαφοράς φωτεινότητας,
# με τη ζώνη της βιβλιοθηκάριου εξαιρεμένη):
#
#     bg2(x, y)  ≈  bg(0.9575·x + 12,  0.9575·y + 18)
#
# Αν αντικαταστήσεις κάποια από τις δύο εικόνες, οι αριθμοί ΔΕΝ ισχύουν πια.
# Αν βάλεις library.bg με ακριβώς το ίδιο κάδρο/διαστάσεις με την bg2, τότε
# ALIGN_SCALE = 1.0, ALIGN_DX = ALIGN_DY = 0.
const BG_PATH    := "res://Εικόνες/library.bg.png"    # χωρίς βιβλιοθηκάριο
const CHAR_PATH  := "res://Εικόνες/library.bg2.png"   # με τη βιβλιοθηκάριο
const BOARD_PATH := "res://Εικόνες/board.png"

# ── Παράμετροι ευθυγράμμισης ──────────────────────────────────────────────
const ALIGN_SCALE := 0.9575
const ALIGN_DX    := 12.0
const ALIGN_DY    := 18.0

# Η bg2 (1024×1536) μπαίνει με KEEP_ASPECT_COVERED σε 1080×1920: κλίμακα
# 1920/1536 = 1.25, κεντραρισμένη → ξεκινά στο x = (1080-1280)/2 = -100.
const COVER_SCALE := 1.25
const COVER_X     := -100.0

# Το ορθογώνιο της bg που την «κουμπώνει» πάνω στο κάδρο της bg2.
const BG_SCALE := COVER_SCALE / ALIGN_SCALE
const BG_POS   := Vector2(-COVER_SCALE * ALIGN_DX / ALIGN_SCALE + COVER_X,
						  -COVER_SCALE * ALIGN_DY / ALIGN_SCALE)
const BG_SIZE  := Vector2(941.0 * BG_SCALE, 1672.0 * BG_SCALE)

## Διάρκεια του dissolve bg2 → bg. Πιο αργό από τα άλλα σπίτια επίτηδες
## (βλ. σχόλιο στο _go_to_state2).
const DISSOLVE_TIME := 0.95

# ── Παλέτα (βιβλιοθήκη — βαθύ μπλε βιβλίων, χρυσό φως λαμπών) ─────────────
# Ίδια σχήματα/μεγέθη/αποστάσεις με τα αδελφά popup· αλλάζει μόνο ο τόνος
# (φούρναρης: χρυσό, αλχημιστής: βιολετί, βιβλιοθήκη: ζαφειρένιο μπλε).
const C0       := Color(0, 0, 0, 0)
const C_SAPH   := Color(0.420, 0.600, 0.960)   # ζαφειρένια πινελιά
const C_SAPH_D := Color(0.140, 0.200, 0.420)
const C_SAPH_S := Color(0.720, 0.840, 1.000)
const C_PARCH  := Color(0.968, 0.958, 0.930)   # χαρτί βιβλίου
const C_PARCH_D:= Color(0.790, 0.775, 0.740)
const C_LAMP   := Color(0.980, 0.800, 0.420)   # ζεστό φως λάμπας
const C_WOOD   := Color(0.150, 0.135, 0.185)
const C_WOOD_D := Color(0.088, 0.080, 0.120)
const C_TEXT   := Color(0.090, 0.080, 0.140)

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
# ΚΑΤΑΣΤΑΣΗ 2 — η Βιβλιοθηκάριος φεύγει, εμφανίζεται το άδειο αναγνωστήριο
# με τον πίνακα ασκήσεων
# ═══════════════════════════════════════════════════════════════════════════
func _go_to_state2() -> void:
	_state = 2
	_hint.visible = false

	# Χωρίς μαύρη μετάβαση: απλό dissolve, όπως στα υπόλοιπα σπιτάκια.
	# Επειδή οι δύο εικόνες είναι ΞΕΧΩΡΙΣΤΕΣ λήψεις (ίδιο δωμάτιο, αλλά οι
	# λεπτομέρειες στα ράφια/φώτα διαφέρουν λίγο), το dissolve είναι πιο ΑΡΓΟ
	# και ημιτονοειδές από ό,τι αλλού: έτσι διαβάζεται ως ομαλή μετάβαση και
	# όχι ως τρεμόπαιγμα. Η ευθυγράμμιση (BG_POS/BG_SIZE) κρατά τα μεγάλα
	# στοιχεία του δωματίου ακίνητα, οπότε δεν «πηδάει» τίποτα.
	_board.modulate.a = 0.0
	_board.visible    = true
	_populate_board()

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 1) πρώτα φεύγει η φούσκα
	tw.tween_property(_bubble, "modulate:a", 0.0, 0.30)
	tw.tween_callback(func(): _bubble.visible = false)
	# 2) μετά σβήνει η βιβλιοθηκάριος ενώ ανεβαίνει ο πίνακας
	tw.tween_property(_char, "modulate:a", 0.0, DISSOLVE_TIME)
	tw.parallel().tween_property(_board, "modulate:a", 1.0, DISSOLVE_TIME)
	tw.tween_callback(func(): _char.visible = false)

# ═══════════════════════════════════════════════════════════════════════════
# ΠΕΡΙΕΧΟΜΕΝΟ ΠΙΝΑΚΑ
# ═══════════════════════════════════════════════════════════════════════════
## Καλείται κάθε φορά που ο πίνακας εμφανίζεται (Κατάσταση 2), αφού πρώτα
## έχει αδειάσει από την προηγούμενη επίσκεψη.
func _populate_board() -> void:
	# ─────────────────────────────────────────────────────────────────────
	# TODO: εδώ μπαίνουν οι ασκήσεις.
	#
	# Πρόσθεσε τα Control σου στο _board_content (VBoxContainer) — στοιχίζονται
	# μόνα τους μέσα στο ξύλινο πλαίσιο, με σωστά περιθώρια:
	#
	#     _board_content.add_child(<το Control σου>)
	#
	# Έτοιμα βοηθητικά για συνεπές στυλ με τα άλλα σπιτάκια:
	#     _make_board_label(text, font_size, color)  → Label πάνω στο ξύλο
	#     _make_answer_button(text, accent)          → κουμπί απάντησης
	#
	# Πλήρες, λειτουργικό παράδειγμα σύνδεσης με τον QuizManager (φόρτωση
	# JSON, ΣΩΣΤΟ/ΛΑΘΟΣ, δείκτης προόδου, ανατροφοδότηση, οθόνη σκορ):
	# βλ. Scripts/bakery_popup.gd → _start_quiz() / _on_question_changed().
	# ─────────────────────────────────────────────────────────────────────

	# Προσωρινό placeholder ώστε ο πίνακας να μη φαίνεται χαλασμένος όσο
	# είναι άδειος — ΣΒΗΣΕ ΤΟ μόλις μπουν οι πραγματικές ασκήσεις.
	var ph := _make_board_label("[ΕΔΩ ΜΠΑΙΝΟΥΝ ΟΙ ΑΣΚΗΣΕΙΣ]", 32, C_PARCH_D)
	ph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ph.vertical_alignment  = VERTICAL_ALIGNMENT_CENTER
	_board_content.add_child(ph)

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

# ── Φόντο (άδειο αναγνωστήριο) ────────────────────────────────────────────
func _build_background() -> void:
	var tex : Texture2D = load(BG_PATH)
	var bg  := TextureRect.new()
	if tex:
		bg.texture = tex
	# ΟΧΙ full-rect/COVERED εδώ: ρητό ορθογώνιο ώστε το δωμάτιο να πέσει πάνω
	# στο δωμάτιο της bg2 και να μην «πηδήξει» στο cross-fade (βλ. σχόλιο
	# ευθυγράμμισης στην κορυφή του αρχείου).
	bg.position     = BG_POS
	bg.size         = BG_SIZE
	bg.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Ελαφρύ σκούρο overlay για ατμόσφαιρα (και για να διαβάζεται το κείμενο)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.25)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

# ── Χαρακτήρας Βιβλιοθηκάριος — full-screen layer «σκηνή με τη γυναίκα» ────
# Κουβαλάει δικό της dim overlay (ίδιο με του background) ως ΠΑΙΔΙ, ώστε η
# φωτεινότητα να είναι ίδια πριν και μετά την αλλαγή — τα παιδιά κληρονομούν
# το modulate του γονιού, οπότε σβήνουν όλα μαζί.
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

	# Η βιβλιοθηκάριος στέκεται ΚΕΝΤΡΟ μέσα στη σκηνή, οπότε η φούσκα πάει
	# δεξιά και η ουρά δείχνει κάτω, προς το κεφάλι της.
	# ΠΡΟΣΟΧΗ ΣΤΟ ΥΨΟΣ: ο κότσος της ξεκινά στο y≈462 της οθόνης (η εικόνα
	# 1024×1536 μπαίνει με KEEP_ASPECT_COVERED σε 1080×1920, άρα κλίμακα
	# 1.25 και οριζόντιο κόψιμο 80px ανά πλευρά). Η φούσκα ΠΡΕΠΕΙ να
	# τελειώνει πάνω από εκεί, αλλιώς σκεπάζει το πρόσωπό της.
	const BX := 430.0
	const BY := 30.0
	const BW := 620.0
	const BH := 380.0

	# Σκιά
	_shadow(root, Vector2(BX+8, BY+8), Vector2(BW, BH), 18)

	# Κύριο πλαίσιο — χαρτί βιβλίου με ζαφειρένιο περίγραμμα
	_styled_panel(root, Vector2(BX, BY), Vector2(BW, BH),
		C_PARCH, C_SAPH, 5, 18)
	_styled_panel(root, Vector2(BX+10, BY+10), Vector2(BW-20, BH-20),
		C0, C_SAPH_D, 2, 14)

	# Ουρά φούσκας (προς τη Βιβλιοθηκάριο — κάτω-αριστερά)
	_bubble_tail(root, BX + 50, BY + BH - 2)

	# Τίτλος NPC
	_styled_panel(root, Vector2(BX+22, BY+22), Vector2(BW-44, 58),
		C_WOOD_D, C_SAPH_D, 2, 8)
	_label(root, "📖  Η Βιβλιοθηκάριος",
		Vector2(BX+22, BY+22), Vector2(BW-44, 58),
		22, C_SAPH_S, HORIZONTAL_ALIGNMENT_CENTER,
		Color(0,0,0,0.80), 1, 2)

	# Διαχωριστής
	_cr_on(root, Vector2(BX+30, BY+86), Vector2(BW-60, 2), C_SAPH_D)

	# ΚΕΙΜΕΝΟ ΟΜΙΛΙΑΣ — άλλαξέ το ελεύθερα. ΟΡΙΟ: ~6 γραμμές των 26px (η φούσκα
	# δεν μπορεί να ψηλώσει, γιατί από κάτω αρχίζει το κεφάλι της). Κάθε "\n"
	# είναι νέα γραμμή και οι μεγάλες γραμμές σπάνε μόνες τους (autowrap).
	# Το «αν…» είναι νεύμα στη Δομή Επιλογής, το θέμα της περιοχής ΔΕ.
	var msg := Label.new()
	msg.text = "Ψιτ… ησυχία στη βιβλιοθήκη!\n\nΚάθε βιβλίο κρύβει μια απόφαση:\nαν διαλέξεις σωστά, φωτίζεται.\n\nΔοκίμασε στον πίνακα!"
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

	# Σκόνη σελίδων / λάμψη κρυστάλλων γύρω από τη φούσκα
	_page_sparkles(root, BX, BY, BW, BH)

	return root

# Τα σκαλοπάτια της ουράς κατεβαίνουν προς τα ΑΡΙΣΤΕΡΑ (εκεί, από κάτω,
# στέκεται η βιβλιοθηκάριος).
func _bubble_tail(parent: Control, tx: float, ty: float) -> void:
	_cr_on(parent, Vector2(tx,    ty),    Vector2(32, 14), C_PARCH)
	_cr_on(parent, Vector2(tx-8,  ty+12), Vector2(22, 14), C_PARCH)
	_cr_on(parent, Vector2(tx-14, ty+24), Vector2(14, 14), C_PARCH)
	_cr_on(parent, Vector2(tx-1,  ty-1),  Vector2(34,  5), C_SAPH)
	_cr_on(parent, Vector2(tx-4,  ty+2),  Vector2(5,  14), C_SAPH)

func _page_sparkles(parent: Control, bx: float, by: float, bw: float, bh: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31415
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
		# Εναλλάσσει ζαφειρένιο και ζεστό φως λάμπας
		s.bg_color = C_SAPH_S if rng.randf() > 0.4 else C_LAMP
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
	dis.border_color = C_SAPH_D.darkened(0.25)
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
	n.bg_color = C_WOOD_D; n.border_color = C_SAPH.darkened(0.15)
	n.set_border_width_all(4); n.set_corner_radius_all(10)
	n.shadow_color = Color(0,0,0,0.68); n.shadow_size = 7
	btn.add_theme_stylebox_override("normal", n)
	var h := StyleBoxFlat.new()
	h.bg_color = C_WOOD; h.border_color = C_SAPH
	h.set_border_width_all(5); h.set_corner_radius_all(10)
	h.shadow_color = C_SAPH.lightened(0.10); h.shadow_size = 16
	btn.add_theme_stylebox_override("hover", h)
	var pr := StyleBoxFlat.new()
	pr.bg_color = Color(0.025,0.040,0.075); pr.border_color = C_SAPH.darkened(0.25)
	pr.set_border_width_all(3); pr.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("pressed", pr)
	btn.add_theme_stylebox_override("focus", StyleBoxFlat.new())
	btn.add_theme_color_override("font_color",         C_SAPH_S)
	btn.add_theme_color_override("font_hover_color",   Color(1,1,1))
	btn.add_theme_color_override("font_pressed_color", C_SAPH.darkened(0.30))
	btn.add_theme_color_override("font_shadow_color",  Color(0,0,0,0.92))
	btn.add_theme_constant_override("shadow_offset_x", 2)
	btn.add_theme_constant_override("shadow_offset_y", 3)
