extends Control

# Popup "Boss Fight": η μάγισσα προκαλεί τον παίκτη σε μάχη. Είναι το ΠΡΩΤΟ
# popup που ανοίγει πατώντας το σπίτι της μάγισσας (witch_map_popup.gd).
# Κατάσταση 1: η μάγισσα μιλάει μπροστά από το εσωτερικό του μαγαζιού της
# (εισαγωγικός διάλογος «Τολμηρέ ταξιδιώτη...»).
# Κατάσταση 2: με ένα κλικ, η μάγισσα φεύγει, το background παραμένει, και πάνω
# στο board.png εμφανίζεται είτε "δεν είσαι έτοιμος ακόμα" (loss gate, βλ.
# παρακάτω) είτε τα ΟΡΑΤΑ odds νίκης + κουμπί «Επίθεση».
# Το κουμπί «Επίθεση» ΔΕΝ κάνει πλέον roll εδώ — ΞΕΚΙΝΑΕΙ το animated BossFight
# (_launch_fight). Το roll νίκης/ήττας + το GameData recording + το αποτέλεσμα
# έχουν μεταφερθεί ΕΚΕΙ (boss_fight.gd), ώστε η ζωντανή μάχη να «παίζει» για
# λίγα δευτερόλεπτα πριν κριθεί το αποτέλεσμα με βάση την παρακάτω πιθανότητα.
#
# ── ΛΟΓΙΚΗ ΜΑΧΗΣ ────────────────────────────────────────────────────────────
# Πιθανότητα νίκης = συνάρτηση του ΣΥΝΟΛΙΚΟΥ ΜΕΣΟΥ ΟΡΟΥ των stats ΟΛΗΣ της
# ενεργής ομάδας: αθροίζονται ΟΛΑ τα stats (HP/Damage/Shield/AttackSpeed, βλ.
# Heroes.STAT_KEYS) ΟΛΩΝ των ηρώων που βρίσκονται σε party θέση και διαιρούνται
# με (πλήθος ηρώων × πλήθος stats) — ΕΝΑΣ ενιαίος μέσος όρος, όχι ένας ανά
# ήρωα. Περιλαμβάνει τα προσωρινά buffs των items (Heroes.get_final_stats).
#
# Ασύμμετρη καμπύλη σε 2 κομμάτια, με 3 σταθερά σημεία (μέσος όρος 1 -> 0%,
# 15 -> 50%, 20 -> 100%) — ΑΜΕΤΑΒΛΗΤΗ:
#   - [1,15]: ΤΕΤΡΑΓΩΝΙΚΗ (αργή στην αρχή) — σκόπιμα «σκληρή» ώστε μέτρια
#     stats να ΜΗΝ δίνουν αξιοπρεπή πιθανότητα· χρειάζεται πραγματικό grind.
#   - [15,20]: γραμμική — μετά το «μισό δρόμο» η πρόοδος ανταμείβεται πιο
#     ομαλά/γρήγορα.
# Επειδή είναι ΜΕΣΟΣ ΟΡΟΣ όλης της ομάδας, ένας δυνατός ήρωας δίπλα σε αδύναμους
# ΔΕΝ αρκεί — χρειάζεται συνολικά δυνατή ομάδα.
#
# ΠΑΛΙΟ (αφαιρέθηκε): ο μέσος όρος έβγαινε από τα 5 στατιστικά εξοπλισμού
# (Επίθεση/Άμυνα/Δύναμη/Εξυπνάδα/Ταχύτητα μέσω Inventory.get_equipped_stat_bonus),
# που δεν ισχύουν πια μετά το party/hero σύστημα (Scripts/heroes.gd).
#
# ── ΚΟΣΤΟΣ ΕΠΑΝΑΛΗΨΗΣ ───────────────────────────────────────────────────────
# Η πρώτη προσπάθεια είναι δωρεάν. Μετά από ήττα (GameData.record_boss_loss),
# ΚΑΘΕ νέα προσπάθεια κοστίζει RETRY_COST Κέρματα (το νόμισμα του Νάνου, βλ.
# Scripts/gnome_popup.gd) — αν δεν φτάνουν, το κουμπί επίθεσης απενεργοποιείται
# και εμφανίζεται μήνυμα. Σε νίκη το κόστος μηδενίζεται (record_boss_win).
# ΑΝΤΙΚΑΤΕΣΤΗΣΕ το παλιό «loss gate» (+1 σε ΚΑΘΕ ένα από τα 5 παλιά stats).

const BG_PATH    := "res://Εικόνες/witchhouse_inside.png"
const CHAR_PATH  := "res://Εικόνες/witch.png"
const BOARD_PATH := "res://Εικόνες/board.png"

# Κόστος επανάληψης μετά από ήττα — χρησιμοποιεί το ΥΠΑΡΧΟΝ σύστημα νομισμάτων
# (Currency autoload)· καμία νέα υλοποίηση νομίσματος.
const RETRY_COST := 200
const RETRY_CURRENCY := "Κέρμα"

# Το στατιστικό της Μόργκανας: ο μέσος όρος της ομάδας που δίνει 50% πιθανότητα
# (βλ. Heroes.win_probability). Τα mini bosses είναι ευκολότερα με μικρότερο
# στατιστικό — καλικάντζαρος 5, δέντρο 10 (βλ. mini_boss_popup.gd).
const MORGANA_STAT := 15

# ── Παλέτα ────────────────────────────────────────────────────────────────
const C0       := Color(0, 0, 0, 0)
const C_GOLD   := Color(0.940, 0.760, 0.160)
const C_GOLD_D := Color(0.360, 0.278, 0.058)
const C_GOLD_S := Color(1.000, 0.920, 0.560)
const C_PARCH  := Color(0.900, 0.860, 0.940)   # ψυχρή, μαγική περγαμηνή
const C_PARCH_D:= Color(0.720, 0.680, 0.760)
const C_WOOD   := Color(0.200, 0.120, 0.052)
const C_WOOD_D := Color(0.130, 0.075, 0.028)
const C_TEXT   := Color(0.110, 0.070, 0.030)
const C_CRIMSON:= Color(0.580, 0.058, 0.058)
const C_MAGIC  := Color(0.420, 0.140, 0.640)
const C_OK     := Color(0.560, 0.900, 0.460)

const W := 1080.0
const H := 1920.0

# ── Κατάσταση ─────────────────────────────────────────────────────────────
var _state  := 0   # 1 = μάγισσα μιλάει, 2 = board (πύλη/odds/αποτέλεσμα)
var _char   : TextureRect
var _bubble : Control
var _board  : Control
var _hint   : Label

# ═══════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_build()
	gui_input.connect(_on_gui_input)

# Καλείται από το Houses/House5 pressed signal
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
# ΚΑΤΑΣΤΑΣΗ 2 — η μάγισσα φεύγει, το board εμφανίζεται (πύλη ή odds+επίθεση)
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
		_show_challenge()
		var tw2 := create_tween()
		tw2.tween_property(_board, "modulate:a", 1.0, 0.55)
	)

# ═══════════════════════════════════════════════════════════════════════════
# ΛΟΓΙΚΗ ΜΑΧΗΣ — βλ. αναλυτικό σχόλιο στην κορυφή του αρχείου
# ═══════════════════════════════════════════════════════════════════════════

## Ο μέσος όρος της ομάδας και η καμπύλη πιθανότητας ζουν ΚΕΝΤΡΙΚΑ στο Heroes
## autoload (Heroes.get_party_average_stat / Heroes.win_probability), ώστε να
## τα μοιράζονται ΟΛΑ τα boss — η Μόργκανα εδώ και τα mini bosses (βλ.
## Scripts/mini_boss_popup.gd). Το μόνο που ξεχωρίζει κάθε boss είναι το
## στατιστικό του: με MORGANA_STAT = 15 η καμπύλη είναι ΑΚΡΙΒΩΣ η αρχική
## (μέσος όρος 15 -> 50%).
func _show_challenge() -> void:
	var heroes := Heroes.get_active_party()
	if heroes.is_empty():
		_show_no_party()
		return
	_show_odds(heroes)

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
	# Ψυχρό, μαγικό σκοτάδι
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.0, 0.08, 0.42)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

# ── Χαρακτήρας μάγισσα ────────────────────────────────────────────────────
# Το (νέο) witch.png είναι 1408×768 landscape καμβάς με τεράστια διάφανα
# περιθώρια — η μάγισσα καταλαμβάνει μόνο το CHAR_REGION παρακάτω. Χωρίς το
# crop, το EXPAND_FIT_WIDTH_PROPORTIONAL φούσκωνε το control σε ~1833×1000
# και η μάγισσα κατέληγε σχεδόν ολόκληρη ΕΚΤΟΣ οθόνης δεξιά (αόρατη). Ίδια
# λύση με blacksmith_popup.gd/old_man_popup.gd (βλ. CHAR_REGION εκεί).
# ΠΡΟΣΟΧΗ: το ίδιο witch.png είναι και το idle frame του boss_fight.gd — αν
# αλλάξει ξανά η εικόνα, ενημέρωσε το region εδώ (μετρημένο από τα
# μη-διάφανα pixel: x 492-954, y 120-730, με μικρό περιθώριο).
const CHAR_REGION := Rect2(486, 112, 476, 646)

func _build_character() -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas  = load(CHAR_PATH)
	atlas.region = CHAR_REGION
	var char_rect := TextureRect.new()
	char_rect.texture      = atlas
	char_rect.position     = Vector2(280, 540)
	char_rect.size         = Vector2(540, 1000)
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
	_label(root, "🔮  Μόργκανα η Μάγισσα",
		Vector2(BX+22, BY+22), Vector2(BW-44, 58),
		22, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER,
		Color(0,0,0,0.80), 1, 2)

	_cr_on(root, Vector2(BX+30, BY+86), Vector2(BW-60, 2), C_MAGIC.darkened(0.3))

	var msg := Label.new()
	msg.text = "Τολμηρέ ταξιδιώτη...\n\nΈφτασες μέχρι εδώ, αλλά η δύναμή\nμου δεν έχει αντίπαλο!\n\nΘα πρέπει να πολεμήσουμε\nγια να αποδείξεις\nπως αξίζεις να προχωρήσεις!"
	msg.position         = Vector2(BX+28, BY+96)
	msg.size             = Vector2(BW-56, BH-130)
	msg.autowrap_mode    = TextServer.AUTOWRAP_WORD_SMART
	msg.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	msg.add_theme_font_size_override("font_size", 27)
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
	rng.seed = 51015
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

# ── Board (Κατάσταση 2) — αποτέλεσμα μάχης ────────────────────────────────
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
		# Το board.png (441×565) έχει διάφανα περιθώρια — το ξύλο ζει στο
		# x 16-424, y 84-512 (opaque bbox από το alpha, ίδια μέτρηση με το
		# board του miner_popup.gd). Χωρίς crop, το ορατό ξύλο ξεκινούσε στο
		# y≈416 της οθόνης ενώ το ResultBox στο y=340 — το πλαίσιο ξεχείλωνε
		# πάνω από το board. Με το crop, το ξύλο γεμίζει ΟΛΟ το BRD_W×BRD_H
		# και το ResultBox (με τα +80/+120 εσωτερικά περιθώρια) χωράει μέσα.
		var atlas := AtlasTexture.new()
		atlas.atlas  = brd_tex
		atlas.region = Rect2(16, 84, 409, 429)
		brd.texture = atlas
	brd.position     = Vector2(BRD_X, BRD_Y)
	brd.size         = Vector2(BRD_W, BRD_H)
	brd.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	brd.stretch_mode = TextureRect.STRETCH_SCALE
	brd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(brd)

	# Περιοχή αποτελέσματος στο εσωτερικό του board
	const RES_X := BRD_X + 80.0
	const RES_Y := BRD_Y + 120.0
	const RES_W := BRD_W - 160.0
	const RES_H := BRD_H - 240.0

	var result_box := Panel.new()
	result_box.name     = "ResultBox"
	result_box.position = Vector2(RES_X, RES_Y)
	result_box.size     = Vector2(RES_W, RES_H)
	result_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(result_box)

	return root

func _clear_result_box() -> Panel:
	var box := _board.get_node("ResultBox") as Panel
	for c in box.get_children():
		c.queue_free()
	return box

## Καμία ενεργή ομάδα — χωρίς ήρωες σε θέσεις δεν υπάρχουν stats να μετρήσουν,
## οπότε δεν επιτρέπεται προσπάθεια.
func _show_no_party() -> void:
	var box := _clear_result_box()
	var s := StyleBoxFlat.new()
	s.bg_color     = Color(0.16, 0.08, 0.04, 0.85)
	s.border_color = C_CRIMSON
	s.set_border_width_all(3)
	s.set_corner_radius_all(8)
	box.add_theme_stylebox_override("panel", s)

	var title := Label.new()
	title.text = "Η ομάδα σου είναι άδεια!"
	title.position = Vector2(0, 80)
	title.size     = Vector2(box.size.x, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", C_CRIMSON.lightened(0.3))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)

	var hint := Label.new()
	# ΣΕΙΡΑ: autowrap ΠΡΙΝ το size — αλλιώς το Label κλειδώνει το minimum size
	# στο πλήρες πλάτος του κειμένου (χωρίς αναδίπλωση) και το .size αγνοείται,
	# οπότε το κείμενο ξεχειλίζει έξω από το πλαίσιο.
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "Πήγαινε στους «Χαρακτήρες» και βάλε τουλάχιστον έναν ήρωα σε μια θέση της ομάδας πριν αντιμετωπίσεις τη Μόργκανα."
	hint.position = Vector2(50, 170)
	hint.size     = Vector2(box.size.x - 100, 140)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 26)
	hint.add_theme_color_override("font_color", C_PARCH_D)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(hint)

## Δείχνει την ΟΡΑΤΗ πιθανότητα νίκης (από τον μέσο όρο της ομάδας) + κουμπί
## «Επίθεση» — το roll γίνεται ΜΟΝΟ όταν το πατήσει ο παίκτης. Αν ο παίκτης
## έχει ήδη ηττηθεί, η προσπάθεια χρεώνεται RETRY_COST Κέρματα.
func _show_odds(heroes: Array) -> void:
	var box := _clear_result_box()
	var s := StyleBoxFlat.new()
	s.bg_color     = Color(0.10, 0.06, 0.14, 0.85)
	s.border_color = C_MAGIC.lightened(0.2)
	s.set_border_width_all(3)
	s.set_corner_radius_all(8)
	box.add_theme_stylebox_override("panel", s)

	var avg := Heroes.get_party_average_stat()
	var probability := Heroes.win_probability(avg, MORGANA_STAT)
	var pct := int(round(probability * 100.0))

	var title := Label.new()
	title.text = "Πιθανότητα Νίκης"
	title.position = Vector2(0, 30)
	title.size     = Vector2(box.size.x, 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", C_PARCH_D)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)

	var pct_label := Label.new()
	pct_label.text = "%d%%" % pct
	pct_label.position = Vector2(0, 74)
	pct_label.size     = Vector2(box.size.x, 100)
	pct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pct_label.add_theme_font_size_override("font_size", 80)
	pct_label.add_theme_color_override("font_color", C_GOLD)
	pct_label.add_theme_color_override("font_shadow_color", Color(0,0,0,0.9))
	pct_label.add_theme_constant_override("shadow_offset_x", 2)
	pct_label.add_theme_constant_override("shadow_offset_y", 3)
	pct_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pct_label)

	# Από πού βγήκε το ποσοστό — αντικαθιστά την παλιά λίστα των 5 stats.
	var avg_label := Label.new()
	avg_label.text = "Μέσος όρος ομάδας: %.1f / 20   (%d %s)" % [
		avg, heroes.size(), "ήρωας" if heroes.size() == 1 else "ήρωες"]
	avg_label.position = Vector2(0, 182)
	avg_label.size     = Vector2(box.size.x, 40)
	avg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avg_label.add_theme_font_size_override("font_size", 24)
	avg_label.add_theme_color_override("font_color", C_PARCH_D)
	avg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(avg_label)

	# ── Κόστος επανάληψης (μόνο αν έχει ήδη χάσει) ───────────────────────────
	var must_pay := GameData.has_lost_to_boss()
	var coins := Currency.get_amount(RETRY_CURRENCY)
	var can_pay := coins >= RETRY_COST

	if must_pay:
		var cost_label := Label.new()
		cost_label.text = "Η Μόργκανα σε νίκησε ήδη!\nΝέα προσπάθεια: %d %s   —   έχεις %d" % [
			RETRY_COST, RETRY_CURRENCY, coins]
		cost_label.position = Vector2(30, 226)
		cost_label.size     = Vector2(box.size.x - 60, 66)
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.add_theme_font_size_override("font_size", 23)
		cost_label.add_theme_color_override("font_color", C_GOLD if can_pay else C_CRIMSON.lightened(0.35))
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(cost_label)

	var attack_btn := Button.new()
	attack_btn.text = "⚔  Επίθεση (%d %s)" % [RETRY_COST, RETRY_CURRENCY] if must_pay else "⚔  Επίθεση"
	attack_btn.position = Vector2(box.size.x / 2.0 - 190, 300)
	attack_btn.size     = Vector2(380, 100)
	attack_btn.add_theme_font_size_override("font_size", 28)
	_style_attack_btn(attack_btn)
	attack_btn.disabled = must_pay and not can_pay
	box.add_child(attack_btn)
	if not attack_btn.disabled:
		attack_btn.pressed.connect(func():
			# Η χρέωση γίνεται ΜΟΝΟ τη στιγμή της επίθεσης, μέσω του υπάρχοντος
			# Currency — αν αποτύχει (π.χ. ξοδεύτηκαν αλλού στο μεταξύ),
			# ξαναχτίζεται η οθόνη με το μήνυμα ανεπάρκειας αντί να ξεκινήσει.
			if must_pay and not Currency.spend({RETRY_CURRENCY: RETRY_COST}):
				_show_odds(heroes)
				return
			_launch_fight(probability))

## Ξεκινάει το animated BossFight (sibling στο Area1). Περνάει ΜΟΝΟ την
## πιθανότητα νίκης: η ζωντανή μάχη «παίζει» για λίγα δευτερόλεπτα και ΜΕΤΑ
## κρίνει νίκη/ήττα με βάση αυτήν — το roll, το GameData recording
## (record_boss_win/loss) και το αποτέλεσμα γίνονται ΕΚΕΙ (boss_fight.gd).
## Το BossPopup κλείνει καθώς ανοίγει η μάχη.
func _launch_fight(probability: float) -> void:
	var fight := get_parent().get_node_or_null("BossFight")
	if fight:
		fight.show_popup(probability, "witch")
		fight.move_to_front()
	_close()

func _style_attack_btn(btn: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = C_MAGIC.darkened(0.35); n.border_color = C_GOLD.darkened(0.15)
	n.set_border_width_all(4); n.set_corner_radius_all(12)
	n.shadow_color = Color(0,0,0,0.65); n.shadow_size = 8
	btn.add_theme_stylebox_override("normal", n)

	# Απενεργοποιημένο (δεν φτάνουν τα Κέρματα): ΠΡΕΠΕΙ να οριστεί ρητά —
	# χωρίς αυτό το Godot πέφτει στο προεπιλεγμένο theme, που πάνω στο σκούρο
	# panel εξαφανίζει τελείως το πλαίσιο και το κουμπί μοιάζει με σκέτο κείμενο.
	var dis := StyleBoxFlat.new()
	dis.bg_color = Color(0.16, 0.14, 0.18, 0.85); dis.border_color = C_PARCH_D.darkened(0.45)
	dis.set_border_width_all(3); dis.set_corner_radius_all(12)
	btn.add_theme_stylebox_override("disabled", dis)
	btn.add_theme_color_override("font_disabled_color", C_PARCH_D.darkened(0.25))

	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = C_MAGIC.darkened(0.1); h.border_color = C_GOLD
	h.shadow_color = C_GOLD.lightened(0.10); h.shadow_size = 16
	btn.add_theme_stylebox_override("hover", h)

	var pr := n.duplicate() as StyleBoxFlat
	pr.bg_color = C_MAGIC.darkened(0.5); pr.border_color = C_GOLD.darkened(0.25)
	btn.add_theme_stylebox_override("pressed", pr)
	btn.add_theme_stylebox_override("focus", StyleBoxFlat.new())

	btn.add_theme_color_override("font_color", C_GOLD_S)
	btn.add_theme_color_override("font_hover_color", C_GOLD)
	btn.add_theme_color_override("font_pressed_color", C_GOLD.darkened(0.3))
	btn.add_theme_color_override("font_shadow_color", Color(0,0,0,0.9))
	btn.add_theme_constant_override("shadow_offset_x", 2)
	btn.add_theme_constant_override("shadow_offset_y", 3)

# ── Hint "Πάτα για να συνεχίσεις" ─────────────────────────────────────────
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
