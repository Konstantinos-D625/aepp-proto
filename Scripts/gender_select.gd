extends Control

# ═══════════════════════════════════════════════════════════════════════════
# GenderSelect — η ΠΡΩΤΗ οθόνη του παιχνιδιού
# ═══════════════════════════════════════════════════════════════════════════
# Στην πρώτη εκκίνηση ο παίκτης επιλέγει αν ο βασικός του ήρωας θα είναι αγόρι
# ή κορίτσι — με τις εικόνες boy.png/girl.png ΟΡΑΤΕΣ, ώστε να ξέρει πώς φαίνεται
# ο καθένας. Η επιλογή αποθηκεύεται μόνιμα (GameData.set_hero_gender) και ΑΜΕΣΩΣ
# μετά φορτώνεται η πρώτη περιοχή (Area1).
#
# Σε ΚΑΘΕ επόμενη εκκίνηση, αφού το φύλο έχει ήδη επιλεγεί, αυτή η οθόνη
# παρακάμπτεται εντελώς και μπαίνει κατευθείαν στο Area1.
#
# Είναι η ΝΕΑ main scene (project.godot -> run/main_scene). Έτσι το φύλο είναι
# γνωστό ΠΡΙΝ φορτωθεί το Area1, οπότε το CharacterSelect χτίζει τον σωστό
# χαρακτήρα από την πρώτη στιγμή, χωρίς χρονισμούς/ανανεώσεις.

const AREA1_PATH := "res://Scenes/Area1.tscn"
const BOY_PATH   := "res://Εικόνες/boy.png"
const GIRL_PATH  := "res://Εικόνες/girl.png"

# ── Palette (ίδιο ύφος με CharacterSelect.gd) ───────────────────────────────
const C0       := Color(0, 0, 0, 0)
const C_BG     := Color(0.032, 0.022, 0.010)
const C_DARK   := Color(0.055, 0.038, 0.018)
const C_MID    := Color(0.095, 0.068, 0.035)
const C_IRON   := Color(0.185, 0.168, 0.140)
const C_IRON_L := Color(0.265, 0.242, 0.208)
const C_BRONZE := Color(0.435, 0.308, 0.072)
const C_GOLD   := Color(0.820, 0.645, 0.118)
const C_GOLD_D := Color(0.268, 0.192, 0.032)
const C_CRIMSON:= Color(0.455, 0.030, 0.030)
const C_BONE   := Color(0.868, 0.830, 0.685)
const C_BONE_D := Color(0.415, 0.378, 0.290)
const C_BLUE   := Color(0.38, 0.64, 0.98)          # subtle μπλε ένδειξη επιλογής

# ── Layout (1080 × 1920) ────────────────────────────────────────────────────
const W  := 1080.0
const MX := 50.0
const GX := 40.0
const CARD_W := (W - MX * 2.0 - GX) / 2.0    # ≈ 470
const CARD_Y := 470.0
const CARD_H := 980.0
const PLATE_H := 92.0
const ART_INSET := 14.0

var _selected := ""                 # "" / "boy" / "girl"
var _cards: Dictionary = {}         # gender -> {"root": Control, "ring": Panel}
var _start_btn: Button


func _ready() -> void:
	if GameData.has_hero_gender():
		# Επιστρέφων παίκτης — κατευθείαν στην περιοχή. Η αλλαγή scene μέσα στο
		# _ready της τρέχουσας scene πρέπει να αναβληθεί.
		call_deferred("_go_to_area")
		return
	_build()
	# Fade-in
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.35)


func _build() -> void:
	_background()
	_header()
	_card("boy",  "ΑΓΟΡΙ",   BOY_PATH,  Color(0.10, 0.20, 0.34), MX)
	_card("girl", "ΚΟΡΙΤΣΙ", GIRL_PATH, Color(0.32, 0.08, 0.22), MX + CARD_W + GX)
	_start_button()


# ═══════════════════════════════════════════════════════════════════════════
# BACKGROUND
# ═══════════════════════════════════════════════════════════════════════════

func _background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = C_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Vignettes (πάνω/κάτω/πλαϊνά) — ίδιο ατμοσφαιρικό ύφος με CharacterSelect
	_rect(self, Vector2(0, 1560), Vector2(1080, 360), Color(0, 0, 0, 0.70))
	_rect(self, Vector2(0, 0),    Vector2(1080, 220), Color(0, 0, 0, 0.42))
	_rect(self, Vector2(0, 0),    Vector2(70, 1920),  Color(0, 0, 0, 0.30))
	_rect(self, Vector2(1010, 0), Vector2(70, 1920),  Color(0, 0, 0, 0.30))


# ═══════════════════════════════════════════════════════════════════════════
# HEADER
# ═══════════════════════════════════════════════════════════════════════════

func _header() -> void:
	# Title banner
	const BX := 140.0
	const BW := 800.0
	const BY := 150.0
	const BH := 132.0
	_panel(self, Vector2(BX + 4, BY + 4), Vector2(BW, BH), Color(0, 0, 0, 0.65), C0, 0, 6)
	_panel(self, Vector2(BX, BY), Vector2(BW, BH), Color(0.065, 0.044, 0.020), C_GOLD, 4, 6)
	_panel(self, Vector2(BX + 6, BY + 6), Vector2(BW - 12, BH - 12), C0, C_GOLD_D, 1, 3)
	_label(self, "ΔΙΑΛΕΞΕ ΤΟΝ ΗΡΩΑ ΣΟΥ", Vector2(BX, BY), Vector2(BW, BH),
		56, C_BONE, HORIZONTAL_ALIGNMENT_CENTER, Color(0, 0, 0, 0.95), 3, 4)

	# Subtitle
	_label(self, "Θα είναι το φύλο του βασικού σου χαρακτήρα",
		Vector2(0, 300), Vector2(1080, 54), 30, C_BRONZE.lightened(0.10),
		HORIZONTAL_ALIGNMENT_CENTER)

	# Ornament line
	var line := ColorRect.new()
	line.position = Vector2(140, 388)
	line.size = Vector2(800, 2)
	line.color = C_BRONZE.darkened(0.25)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)


# ═══════════════════════════════════════════════════════════════════════════
# CARDS
# ═══════════════════════════════════════════════════════════════════════════

func _card(gender: String, title: String, tex_path: String, tint: Color, x: float) -> void:
	# Container ώστε ολόκληρη η κάρτα να μπορεί να θαμπώσει (modulate) όταν δεν
	# είναι επιλεγμένη — τα παιδιά μπαίνουν σε ΤΟΠΙΚΕΣ συντεταγμένες.
	var root := Control.new()
	root.position = Vector2(x, CARD_Y)
	root.size = Vector2(CARD_W, CARD_H)
	add_child(root)

	var art_h := CARD_H - PLATE_H - ART_INSET

	# Shadow
	_panel(root, Vector2(6, 8), Vector2(CARD_W, CARD_H), Color(0, 0, 0, 0.75), C0, 0, 6)
	# Main frame
	_panel(root, Vector2(0, 0), Vector2(CARD_W, CARD_H), C_DARK, C_GOLD_D, 6, 8)
	# Art background (tinted)
	_panel(root, Vector2(ART_INSET, ART_INSET), Vector2(CARD_W - ART_INSET * 2, art_h),
		tint.darkened(0.35), C0, 0, 4)

	# Portrait image (ή placeholder αν δεν έχει γίνει ακόμα import από τον editor)
	var tex := _load_tex(tex_path)
	if tex != null:
		var art := TextureRect.new()
		art.texture = tex
		art.position = Vector2(ART_INSET, ART_INSET)
		art.size = Vector2(CARD_W - ART_INSET * 2, art_h)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(art)
	else:
		_label(root, "?", Vector2(ART_INSET, ART_INSET),
			Vector2(CARD_W - ART_INSET * 2, art_h), 120, C_BONE_D,
			HORIZONTAL_ALIGNMENT_CENTER)

	# Name plate
	var py := CARD_H - PLATE_H
	_panel(root, Vector2(0, py), Vector2(CARD_W, PLATE_H), C_DARK, C_BRONZE, 0, 6)
	_rect(root, Vector2(0, py), Vector2(CARD_W, 4), C_GOLD_D)
	_label(root, title, Vector2(0, py), Vector2(CARD_W, PLATE_H), 42, C_BONE,
		HORIZONTAL_ALIGNMENT_CENTER, Color(0, 0, 0, 0.95), 2, 3)

	# Selection ring (κρυμμένο μέχρι να επιλεγεί) — subtle μπλε λεπτό περίγραμμα
	# με απαλή αχνή λάμψη, ώστε να ΜΗΝ «πλημμυρίζει» με χρώμα τον χαρακτήρα.
	var ring := Panel.new()
	ring.position = Vector2(-4, -4)
	ring.size = Vector2(CARD_W + 8, CARD_H + 8)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.visible = false
	var rs := _style(C0, C_BLUE, 4, 9)
	rs.shadow_color = Color(C_BLUE.r, C_BLUE.g, C_BLUE.b, 0.28)
	rs.shadow_size = 9
	ring.add_theme_stylebox_override("panel", rs)
	root.add_child(ring)

	# Πατήσιμο κουμπί πάνω απ' όλα
	var btn := Button.new()
	btn.position = Vector2(0, 0)
	btn.size = Vector2(CARD_W, CARD_H)
	btn.flat = true
	btn.add_theme_stylebox_override("normal",  _style(C0, C0, 0, 8))
	btn.add_theme_stylebox_override("hover",   _style(Color(1, 1, 1, 0.06), C0, 0, 8))
	btn.add_theme_stylebox_override("pressed", _style(C0, C0, 0, 8))
	btn.add_theme_stylebox_override("focus",   _style(C0, C0, 0, 8))
	btn.pressed.connect(func(): _select(gender))
	root.add_child(btn)

	# Ξεκίνα θαμπωμένη — γίνεται φωτεινή μόλις επιλεγεί
	root.modulate = Color(0.62, 0.62, 0.62, 1.0)
	_cards[gender] = {"root": root, "ring": ring}


func _select(gender: String) -> void:
	_selected = gender
	for g in _cards:
		var sel: bool = (g == gender)
		(_cards[g]["ring"] as Panel).visible = sel
		(_cards[g]["root"] as Control).modulate = Color(1, 1, 1, 1) if sel else Color(0.5, 0.5, 0.5, 1)
	_set_start_enabled(true)


# ═══════════════════════════════════════════════════════════════════════════
# START BUTTON
# ═══════════════════════════════════════════════════════════════════════════

func _start_button() -> void:
	const SW := 720.0
	const SH := 152.0
	const SX := (W - SW) / 2.0
	const SY := 1590.0
	_start_btn = Button.new()
	_start_btn.text = "ΞΕΚΙΝΑ ΤΗΝ ΠΕΡΙΠΕΤΕΙΑ"
	_start_btn.position = Vector2(SX, SY)
	_start_btn.size = Vector2(SW, SH)
	_start_btn.add_theme_font_size_override("font_size", 46)
	_start_btn.pressed.connect(_on_start)
	add_child(_start_btn)
	_set_start_enabled(false)

	# Βοηθητικό μήνυμα κάτω από το κουμπί όσο δεν έχει γίνει επιλογή
	_label(self, "Πάτησε πάνω σε έναν χαρακτήρα για να τον διαλέξεις",
		Vector2(0, SY + SH + 20), Vector2(1080, 46), 26, C_BONE_D,
		HORIZONTAL_ALIGNMENT_CENTER)


func _set_start_enabled(enabled: bool) -> void:
	_start_btn.disabled = not enabled
	var trim := C_GOLD if enabled else C_GOLD_D
	var fcol := C_GOLD if enabled else C_BONE_D
	var n := _style(C_IRON if enabled else C_DARK, trim.darkened(0.15), 4, 6)
	n.shadow_color = Color(0, 0, 0, 0.72)
	n.shadow_size = 8
	_start_btn.add_theme_stylebox_override("normal", n)
	_start_btn.add_theme_stylebox_override("disabled", _style(C_DARK, C_GOLD_D.darkened(0.2), 3, 6))
	_start_btn.add_theme_stylebox_override("hover", _style(C_IRON_L, C_GOLD, 5, 6))
	_start_btn.add_theme_stylebox_override("pressed", _style(Color(0.06, 0.04, 0.02), C_GOLD_D, 3, 6))
	_start_btn.add_theme_stylebox_override("focus", _style(C0, C0, 0, 0))
	_start_btn.add_theme_color_override("font_color", fcol)
	_start_btn.add_theme_color_override("font_disabled_color", C_BONE_D.darkened(0.2))
	_start_btn.add_theme_color_override("font_hover_color", C_GOLD)
	_start_btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_start_btn.add_theme_constant_override("shadow_offset_x", 2)
	_start_btn.add_theme_constant_override("shadow_offset_y", 3)


func _on_start() -> void:
	if _selected == "":
		return
	GameData.set_hero_gender(_selected)
	# Ο χαρακτήρας που μόλις διάλεξε γίνεται ο πρώτος ήρωας (party σύστημα) —
	# δημιουργείται ΤΩΡΑ (το Heroes autoload φόρτωσε πριν επιλεγεί φύλο).
	Heroes.ensure_starter_hero()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(_go_to_area)


func _go_to_area() -> void:
	get_tree().change_scene_to_file(AREA1_PATH)


# ═══════════════════════════════════════════════════════════════════════════
# PRIMITIVES
# ═══════════════════════════════════════════════════════════════════════════

func _load_tex(path: String) -> Texture2D:
	# Η φόρτωση + το crop στο πραγματικό περιεχόμενο (οι boy.png/girl.png έχουν
	# μεγάλο διάφανο περιθώριο) ζουν κεντρικά στο GameData.get_cropped_texture,
	# ώστε ΟΛΕΣ οι οθόνες να δείχνουν την ίδια εικόνα ήρωα. Επιστρέφει null αν
	# λείπει η εικόνα (τότε δείχνουμε placeholder αντί να σπάσει η σκηνή).
	return GameData.get_cropped_texture(path)


func _style(bg: Color, border: Color, bw: int, cr: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.corner_radius_top_left     = cr
	s.corner_radius_top_right    = cr
	s.corner_radius_bottom_right = cr
	s.corner_radius_bottom_left  = cr
	return s


func _panel(parent: Control, pos: Vector2, sz: Vector2, bg: Color, border: Color, bw: int, cr: int) -> void:
	var p := Panel.new()
	p.position = pos
	p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _style(bg, border, bw, cr))
	parent.add_child(p)


func _rect(parent: Control, pos: Vector2, sz: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.position = pos
	r.size = sz
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)


func _label(parent: Control, text: String, pos: Vector2, sz: Vector2, font_sz: int,
		col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
		shadow: Color = Color(0, 0, 0, 0), sx: int = 0, sy: int = 0) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_sz)
	l.add_theme_color_override("font_color", col)
	if shadow.a > 0:
		l.add_theme_color_override("font_shadow_color", shadow)
		l.add_theme_constant_override("shadow_offset_x", sx)
		l.add_theme_constant_override("shadow_offset_y", sy)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
