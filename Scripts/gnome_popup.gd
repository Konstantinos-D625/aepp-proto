extends Control

# ═══════════════════════════════════════════════════════════════════════════
# GnomePopup — «Το Ανταλλακτήριο του Νάνου», κρυμμένο στο δάσος της μάγισσας.
# ═══════════════════════════════════════════════════════════════════════════
# Κατάσταση 1: ο νάνος στον πάγκο του μιλάει (bubble). Κατάσταση 2: αντί για
# quiz, δείχνει ΜΙΑ σταθερή ανταλλαγή — 1 Χαλκός + 1 Δέρμα + 1 Σίδερο ->
# 1 Κέρμα. Επαναλαμβάνεται όσες φορές θέλει ο παίκτης σε μία επίσκεψη (όσο
# φτάνουν τα υλικά), ίδια φιλοσοφία με τις ανταλλαγές της νεράιδας
# (fairy_popup.gd) — ΟΧΙ one-shot loot σαν τους NPC του χωριού.
#
# Το Κέρμα είναι νέο νόμισμα (βλ. currency_manager.gd) και το Ανταλλακτήριο
# είναι Η ΜΟΝΑΔΙΚΗ πηγή του σε όλο το παιχνίδι.
#
# ΕΙΚΟΝΕΣ — ίδιο scene-pair μοτίβο με Δερματού/miner/νεράιδα: το gnome.png
# είναι ΟΛΟΚΛΗΡΗ σκηνή (ο νάνος στον πάγκο του) και το gnome-bg.png η ΙΔΙΑ
# σκηνή με τον πάγκο ΑΔΕΙΟ. Το _build_character στήνει ΔΕΥΤΕΡΟ full-screen
# layer πάνω από το BG_PATH: στην Κατάσταση 2 το fade out του _char «αδειάζει»
# τον πάγκο.
#
# Ίδιο navigation μοτίβο με FairyButton -> FairyPopup: ανοίγει από ΚΩΔΙΚΑ
# (Scripts/witch_map_popup.gd, %GnomeHouseButton), όχι από εύθραυστο
# connection στο Area1.tscn.

const BG_PATH    := "res://Εικόνες/gnome-bg.png"
const CHAR_PATH  := "res://Εικόνες/gnome.png"
const BOARD_PATH := "res://Εικόνες/board.png"

# Η μοναδική ανταλλαγή: όλα τα κόστη μαζί -> REWARD_AMOUNT Κέρμα. Αν ποτέ
# χρειαστούν κι άλλες συνταγές, γίνεται Array από dicts σαν το TRADES της
# fairy_popup.gd.
const TRADE_COST := { "Χαλκός": 1, "Δέρμα": 1, "Σίδερο": 1 }
const REWARD_CURRENCY := "Κέρμα"
const REWARD_AMOUNT   := 1

# ── Παλέτα (μαγικό δάσος — ίδιο ύφος με fairy_popup.gd, πράσινος τόνος) ─────
const C0        := Color(0, 0, 0, 0)
const C_GOLD    := Color(0.940, 0.760, 0.160)
const C_GOLD_D  := Color(0.360, 0.278, 0.058)
const C_GOLD_S  := Color(1.000, 0.920, 0.560)
const C_PARCH   := Color(0.880, 0.920, 0.860)
const C_PARCH_D := Color(0.680, 0.740, 0.660)
const C_WOOD    := Color(0.200, 0.120, 0.052)
const C_WOOD_D  := Color(0.130, 0.075, 0.028)
const C_TEXT    := Color(0.110, 0.070, 0.030)
const C_MAGIC   := Color(0.180, 0.520, 0.320)   # σμαραγδί — το πράσινο του δάσους
const C_OK      := Color(0.560, 0.900, 0.460)
const C_DISABLED:= Color(0.360, 0.360, 0.330)

const W := 1080.0
const H := 1920.0

# ── Κατάσταση ─────────────────────────────────────────────────────────────
var _state := 0   # 1 = ο νάνος μιλάει, 2 = board με την ανταλλαγή
var _char   : TextureRect
var _bubble : Control
var _board  : Control
var _hint   : Label
var _feedback : Label
var _cost_labels: Dictionary = {}        # currency -> Label («Έχεις: N»)
var _cost_amount_labels: Dictionary = {} # currency -> Label («N × Χαλκός 🪙»)
var _coins_label: Label
var _trade_btn  : Button

# ── Επιλογέας ποσότητας (πόσα Κέρματα σε ΜΙΑ ανταλλαγή) ────────────────────
# Κρατιέται ΠΑΝΤΑ μέσα στο [1, _max_affordable()] (ή 0 όταν δεν φτάνουν τα
# υλικά ούτε για μία) — κάθε είσοδος (κουμπιά -/+, πληκτρολόγηση) περνάει
# από το _set_qty, που κάνει το clamp και ενημερώνει κουμπιά/κείμενα.
var _qty       := 1
var _qty_edit  : LineEdit
var _minus_btn : Button
var _plus_btn  : Button

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_build()
	gui_input.connect(_on_gui_input)
	Currency.changed.connect(_refresh_trade)

func show_popup() -> void:
	visible   = true
	_state    = 1
	_qty      = 1   # κάθε επίσκεψη ξεκινάει από 1 (θα ξανα-clamp-αριστεί στο _refresh_trade)
	_char.visible      = true
	_char.modulate.a   = 1.0
	_bubble.visible    = true
	_bubble.modulate.a = 1.0
	_board.visible     = false
	_hint.visible      = true
	if _feedback: _feedback.text = ""
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
# ΚΑΤΑΣΤΑΣΗ 2 — ο νάνος «φεύγει» (fade στον άδειο πάγκο), board με ανταλλαγή
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
		_refresh_trade()
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
	# Ψυχρό, μαγικό σκοτάδι — ίδιο με fairy_popup.gd (ίδιο δάσος)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.0, 0.08, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

# ── Χαρακτήρας νάνος — full-screen layer «σκηνή με τον νάνο» ─────────────────
# ΙΔΙΟ expand/stretch με το _build_background ώστε οι δύο εικόνες (με/χωρίς
# τον νάνο) να κάθονται pixel-πάνω-σε-pixel — αλλιώς το fade της Κατάστασης 2
# θα «κουνούσε» τον πάγκο. Κουβαλάει και δικό του dim overlay (ίδιο με του
# background) ως ΠΑΙΔΙ, ώστε η φωτεινότητα να είναι ίδια πριν και μετά το
# fade. (Ίδια λύση με cotton_popup.gd/miner_popup.gd/fairy_popup.gd.)
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
	dim.color = Color(0.05, 0.0, 0.08, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	char_rect.add_child(dim)
	return char_rect

# ── Φούσκα ομιλίας — ψηλά, πάνω από το κεφάλι του νάνου (στέκεται στο
# κέντρο της σκηνής)· η ουρά δείχνει κάτω-δεξιά προς το μέρος του ───────────
func _build_bubble() -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	const BX := 32.0
	const BY := 36.0
	const BW := 580.0
	const BH := 470.0

	_shadow(root, Vector2(BX+8, BY+8), Vector2(BW, BH), 18)

	_styled_panel(root, Vector2(BX, BY), Vector2(BW, BH),
		C_PARCH, C_MAGIC, 5, 18)
	_styled_panel(root, Vector2(BX+10, BY+10), Vector2(BW-20, BH-20),
		C0, C_MAGIC.darkened(0.35), 2, 14)

	_bubble_tail(root, BX + BW - 48, BY + BH - 2)

	_styled_panel(root, Vector2(BX+22, BY+22), Vector2(BW-44, 58),
		C_WOOD_D, C_MAGIC.darkened(0.3), 2, 8)
	_label(root, "🍄  Ο Νάνος Ανταλλάκτης",
		Vector2(BX+22, BY+22), Vector2(BW-44, 58),
		22, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER,
		Color(0,0,0,0.80), 1, 2)

	_cr_on(root, Vector2(BX+30, BY+86), Vector2(BW-60, 2), C_MAGIC.darkened(0.3))

	var msg := Label.new()
	msg.text = "Χε χε... πλησίασε, ταξιδιώτη!\n\nΣτο σκοτεινό δάσος τα υλικά σου\nδεν αξίζουν πολλά... Τα Κέρματά μου\nόμως; Αυτά είναι θησαυρός!\n\nΦέρε μου 1 Χαλκό, 1 Δέρμα και\n1 Σίδερο — και ένα λαμπερό Κέρμα\nθα γίνει δικό σου!"
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

	return root

func _bubble_tail(parent: Control, tx: float, ty: float) -> void:
	_cr_on(parent, Vector2(tx,    ty),    Vector2(32, 14), C_PARCH)
	_cr_on(parent, Vector2(tx+8,  ty+12), Vector2(22, 14), C_PARCH)
	_cr_on(parent, Vector2(tx+16, ty+24), Vector2(14, 14), C_PARCH)
	_cr_on(parent, Vector2(tx-1,  ty-1),  Vector2(34, 5),  C_MAGIC)
	_cr_on(parent, Vector2(tx+31, ty+2),  Vector2(5, 14),  C_MAGIC)

# ── Board (Κατάσταση 2) — η ανταλλαγή ────────────────────────────────────────
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
	# fairy_popup.gd/miner_popup.gd — 340 το κατεβάζει μέσα στο ορατό ξύλο.
	pad.add_theme_constant_override("margin_top",    340)
	pad.add_theme_constant_override("margin_bottom", 130)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)

	var title := Label.new()
	title.text = "🟡  Το Ανταλλακτήριο του Νάνου"
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

	# Το «τιμολόγιο»: μία γραμμή ανά υλικό κόστους, με το πόσα έχει ο παίκτης
	# δίπλα — ενημερώνονται ζωντανά στο _refresh_trade. Οι τιμές κόστους στις
	# κάρτες πολλαπλασιάζονται με την επιλεγμένη ποσότητα (βλ. _set_qty).
	for currency in TRADE_COST:
		col.add_child(_make_cost_row(currency, int(TRADE_COST[currency])))

	# Επιλογέας ποσότητας:  [−]  [πεδίο πληκτρολόγησης]  [+]
	col.add_child(_make_qty_row())

	# Το κουμπί της ανταλλαγής — μέγεθος δαχτύλου (κινητό), ενεργό μόνο όταν
	# φτάνουν τα υλικά για την επιλεγμένη ποσότητα.
	_trade_btn = Button.new()
	_trade_btn.text = "Ανταλλαγή  →  +1 Κέρμα  🟡"
	_trade_btn.custom_minimum_size = Vector2(0, 96)
	_trade_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_trade_btn(_trade_btn)
	_trade_btn.pressed.connect(_on_trade_pressed)
	col.add_child(_trade_btn)

	# Πόσα Κέρματα έχει ήδη — label + εικόνα κέρματος δίπλα (coin.png)
	var coins_row := HBoxContainer.new()
	coins_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coins_row.add_theme_constant_override("separation", 10)
	coins_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(coins_row)

	_coins_label = Label.new()
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coins_label.add_theme_font_size_override("font_size", 26)
	_coins_label.add_theme_color_override("font_color", C_GOLD)
	_coins_label.add_theme_color_override("font_shadow_color", Color(0,0,0,0.85))
	_coins_label.add_theme_constant_override("shadow_offset_x", 1)
	_coins_label.add_theme_constant_override("shadow_offset_y", 2)
	_coins_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coins_row.add_child(_coins_label)

	var coin_icon_tex := Currency.get_icon_texture(REWARD_CURRENCY)
	if coin_icon_tex:
		var coin_icon := TextureRect.new()
		coin_icon.texture = coin_icon_tex
		coin_icon.custom_minimum_size = Vector2(44, 44)
		coin_icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coins_row.add_child(coin_icon)

	# Ανατροφοδότηση («✔ Πήρες 1 Κέρμα!» / «Δεν έχεις αρκετά υλικά...»)
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

## Μία γραμμή «τιμολογίου»: αριστερά το κόστος (π.χ. «1 × Χαλκός 🪙»),
## δεξιά το «Έχεις: N». Ίδιο card ύφος με το _make_trade_row της νεράιδας.
func _make_cost_row(currency: String, amount: int) -> Control:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(0, 96)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color     = C_WOOD_D
	card_sb.border_color = C_MAGIC.darkened(0.2)
	card_sb.set_border_width_all(2)
	card_sb.set_corner_radius_all(12)
	card.add_theme_stylebox_override("panel", card_sb)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left  = 24
	row.offset_right = -24
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	# Εικόνα-εικονίδιο πόρου (copper/iron/leather.png — Currency.TEXTURE_ICONS)
	var icon_tex := Currency.get_icon_texture(currency)
	if icon_tex:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(56, 56)
		icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)

	var cost_lbl := Label.new()
	cost_lbl.text = "%d ×  %s" % [amount, currency]
	cost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 26)
	cost_lbl.add_theme_color_override("font_color", C_PARCH)
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cost_lbl)
	_cost_amount_labels[currency] = cost_lbl

	var owned_lbl := Label.new()
	owned_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	owned_lbl.add_theme_font_size_override("font_size", 22)
	owned_lbl.add_theme_color_override("font_color", C_PARCH_D)
	owned_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(owned_lbl)
	_cost_labels[currency] = owned_lbl

	return card

## Γραμμή επιλογής ποσότητας:  [−]  [LineEdit]  [+]  — όλα σε μέγεθος
## δαχτύλου (κινητό). Το πεδίο δέχεται ΜΟΝΟ ψηφία (φιλτράρεται ζωντανά στο
## _on_qty_text_changed) και ό,τι ξεπερνάει το μέγιστο εφικτό κόβεται
## αυτόματα εκεί — τότε το [+] μένει απενεργοποιημένο.
func _make_qty_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_minus_btn = Button.new()
	_minus_btn.text = "−"
	_minus_btn.custom_minimum_size = Vector2(96, 96)
	_style_trade_btn(_minus_btn)
	_minus_btn.add_theme_font_size_override("font_size", 44)
	_minus_btn.pressed.connect(func(): _set_qty(_qty - 1))
	row.add_child(_minus_btn)

	_qty_edit = LineEdit.new()
	_qty_edit.text = "1"
	_qty_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qty_edit.custom_minimum_size = Vector2(220, 96)
	_qty_edit.max_length = 4
	# Αριθμητικό πληκτρολόγιο στο Android — το πεδίο δέχεται μόνο ποσότητες.
	_qty_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_qty_edit.add_theme_font_size_override("font_size", 36)
	_qty_edit.add_theme_color_override("font_color", C_GOLD_S)
	_qty_edit.add_theme_color_override("caret_color", C_GOLD)
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_WOOD_D
	sb.border_color = C_MAGIC.darkened(0.2)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(8)
	_qty_edit.add_theme_stylebox_override("normal", sb)
	var sbf := sb.duplicate() as StyleBoxFlat
	sbf.border_color = C_GOLD
	_qty_edit.add_theme_stylebox_override("focus", sbf)
	_qty_edit.text_changed.connect(_on_qty_text_changed)
	_qty_edit.text_submitted.connect(func(_t: String): _commit_typed_qty())
	_qty_edit.focus_exited.connect(_commit_typed_qty)
	row.add_child(_qty_edit)

	_plus_btn = Button.new()
	_plus_btn.text = "+"
	_plus_btn.custom_minimum_size = Vector2(96, 96)
	_style_trade_btn(_plus_btn)
	_plus_btn.add_theme_font_size_override("font_size", 44)
	_plus_btn.pressed.connect(func(): _set_qty(_qty + 1))
	row.add_child(_plus_btn)

	return row

# ── Λογική ανταλλαγής ────────────────────────────────────────────────────────

## Πόσες ανταλλαγές βγαίνουν με τα τωρινά υλικά — ο ελάχιστος λόγος
## απόθεμα/κόστος ανάμεσα σε ΟΛΑ τα υλικά της συνταγής.
func _max_affordable() -> int:
	var max_trades := 999999
	for currency in TRADE_COST:
		max_trades = mini(max_trades, Currency.get_amount(currency) / int(TRADE_COST[currency]))
	return max_trades

## Η ΜΟΝΗ πόρτα αλλαγής ποσότητας: clamp στο [1, μέγιστο εφικτό] (0 όταν δεν
## βγαίνει ούτε μία) και ενημέρωση όλου του σχετικού UI — κουμπιά -/+, πεδίο,
## κείμενο κουμπιού ανταλλαγής, τιμές κόστους στις κάρτες.
func _set_qty(value: int) -> void:
	var max_q := _max_affordable()
	_qty = clampi(value, 1, max_q) if max_q > 0 else 0
	if _qty_edit and _qty_edit.text != str(_qty):
		_qty_edit.text = str(_qty)
		_qty_edit.caret_column = _qty_edit.text.length()
	if _minus_btn: _minus_btn.disabled = _qty <= 1
	if _plus_btn:  _plus_btn.disabled  = _qty >= max_q
	if _trade_btn:
		_trade_btn.disabled = _qty < 1
		var reward := _qty * REWARD_AMOUNT
		_trade_btn.text = "Ανταλλαγή  →  +%d %s  🟡" % [maxi(reward, 1), _coin_word(maxi(reward, 1))]
	# Οι κάρτες κόστους δείχνουν το ΣΥΝΟΛΙΚΟ κόστος της επιλεγμένης ποσότητας.
	for currency in TRADE_COST:
		if _cost_amount_labels.has(currency):
			(_cost_amount_labels[currency] as Label).text = "%d ×  %s" % [maxi(_qty, 1) * int(TRADE_COST[currency]), currency]

func _coin_word(amount: int) -> String:
	return "Κέρμα" if amount == 1 else "Κέρματα"

## Ζωντανό φίλτρο πληκτρολόγησης: μόνο ψηφία, και ό,τι ξεπερνάει το μέγιστο
## εφικτό γίνεται αμέσως το μέγιστο («μετατρέπεται αυτόματα στον μεγαλύτερο
## δυνατό αριθμό»). Κενό πεδίο επιτρέπεται προσωρινά όσο γράφει ο παίκτης —
## οριστικοποιείται στο _commit_typed_qty (Enter ή κλικ αλλού).
func _on_qty_text_changed(new_text: String) -> void:
	var filtered := ""
	for c in new_text:
		if c >= "0" and c <= "9":
			filtered += c
	if filtered.is_empty():
		if filtered != new_text:
			_qty_edit.text = ""
		return
	var typed := int(filtered)
	var max_q := _max_affordable()
	var clamped: int = clampi(typed, 1, max_q) if max_q > 0 else 0
	_qty = clamped
	if str(clamped) != new_text:
		_qty_edit.text = str(clamped)
		_qty_edit.caret_column = _qty_edit.text.length()
	_set_qty(clamped)

func _commit_typed_qty() -> void:
	_set_qty(int(_qty_edit.text) if not _qty_edit.text.is_empty() else 1)

func _refresh_trade() -> void:
	for currency in TRADE_COST:
		if _cost_labels.has(currency):
			(_cost_labels[currency] as Label).text = "Έχεις: %d" % Currency.get_amount(currency)
	if _coins_label:
		_coins_label.text = "Τα Κέρματά σου: %d" % Currency.get_amount(REWARD_CURRENCY)
	# Ξανα-clamp της ποσότητας — τα αποθέματα μπορεί να άλλαξαν (π.χ. μετά
	# από ανταλλαγή, ή αγορά στο Shop όσο ήταν ανοιχτό το popup).
	_set_qty(_qty if _qty > 0 else 1)

func _on_trade_pressed() -> void:
	if _qty < 1:
		return
	# ΠΡΟΣΟΧΗ: η ποσότητα αντιγράφεται σε τοπική ΠΡΙΝ το spend — το
	# Currency.spend εκπέμπει `changed`, που τρέχει ΣΥΓΧΡΟΝΩΣ το
	# _refresh_trade και ξανα-clamp-άρει το _qty με τα ΝΕΑ (μειωμένα)
	# αποθέματα. Χωρίς το αντίγραφο, η ανταμοιβή υπολογιζόταν με το ήδη
	# μηδενισμένο _qty και ο παίκτης έχανε τα Κέρματα.
	var qty := _qty
	var cost := {}
	for currency in TRADE_COST:
		cost[currency] = int(TRADE_COST[currency]) * qty
	if not Currency.spend(cost):
		return
	var reward := REWARD_AMOUNT * qty
	Currency.add(REWARD_CURRENCY, reward)
	_feedback.text = "✔  Πήρες %d %s!" % [reward, _coin_word(reward)]
	_refresh_trade()

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
# ΒΟΗΘΗΤΙΚΕΣ ΣΥΝΑΡΤΗΣΕΙΣ (ίδιο μοτίβο με fairy_popup.gd)
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
	btn.add_theme_font_size_override("font_size", 28)
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
