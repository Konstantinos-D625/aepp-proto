extends Control

# ═══════════════════════════════════════════════════════════════════════════
# OldManPopup — ο Γέρο-Νέστορας, ο tutorial-NPC του χωριού.
# ═══════════════════════════════════════════════════════════════════════════
# Ίδιο navigation μοτίβο με τα υπόλοιπα popups του Area1 (Cotton/Miner/
# Blacksmith): Control instanced ως αδερφός node μέσα στο Area1.tscn, το
# κουμπί (Houses/OldMan — ο ίδιος ο γέρος πάνω στον χάρτη, ΟΡΑΤΟ TextureButton
# σε αντίθεση με τα αόρατα κουμπιά-σπίτια) συνδέεται στο show_popup() μέσα
# στο Area1.tscn.
#
# ΡΟΗ TUTORIAL: ο γέρος καλωσορίζει και ρωτάει τι θες να μάθεις — μία λίστα
# θεμάτων σε scroll (βλ. TOPICS): οι 3 τεχνίτες (Μεταλλωρύχος/Δερματού/
# Πεταλωτής), τα bosses (Καλικάντζαρος/Δέντρο/Μόργκανα), το side quest του
# Κάστρου, πώς δουλεύουν οι μάχες, και ένα μικρό lore. Πατώντας ένα θέμα, το
# κείμενο της φούσκας αλλάζει σε δυο λόγια γι' αυτό· το «Ρώτα για άλλον»
# γυρνάει στη λίστα. Δεν υπάρχει «Κατάσταση 2» (board/quiz) όπως στους
# άλλους NPC — μόνο διάλογος.

# ── Μονοπάτια εικόνων ─────────────────────────────────────────────────────
const BG_PATH   := "res://Εικόνες/old-man-bg.png"
const CHAR_PATH := "res://Εικόνες/old-man.png"

# Το old-man.png είναι 1408×768 με ΤΕΡΑΣΤΙΑ διάφανα περιθώρια δεξιά-αριστερά·
# ο γέρος καταλαμβάνει μόνο το παρακάτω κομμάτι (μετρημένο από τα μη-διάφανα
# pixel, με λίγο περιθώριο). Το ΙΔΙΟ region χρησιμοποιεί και το AtlasTexture
# του κουμπιού Houses/OldMan μέσα στο Area1.tscn — αν αλλάξει η εικόνα,
# ενημέρωσε ΚΑΙ τα δύο.
const CHAR_REGION := Rect2(438, 70, 490, 660)

# ── Παλέτα (γέρος οδοιπόρος — γήινο, λαδί, περγαμηνή) ─────────────────────
const C0        := Color(0, 0, 0, 0)
const C_GOLD    := Color(0.940, 0.760, 0.160)
const C_GOLD_D  := Color(0.360, 0.278, 0.058)
const C_GOLD_S  := Color(1.000, 0.920, 0.560)
const C_PARCH   := Color(0.975, 0.950, 0.880)   # λευκό-κρεμ περγαμηνή
const C_PARCH_D := Color(0.820, 0.780, 0.640)
const C_OLIVE   := Color(0.360, 0.400, 0.220)   # λαδί μανδύας του γέρου
const C_WOOD    := Color(0.200, 0.140, 0.065)
const C_WOOD_D  := Color(0.130, 0.085, 0.035)
const C_TEXT    := Color(0.100, 0.065, 0.025)

const W := 1080.0
const H := 1920.0

# ── Θέματα συζήτησης ──────────────────────────────────────────────────────
# Οι τρεις τεχνίτες για τους οποίους μιλάει ο γέρος και η πρώτη ύλη του
# καθενός. ΠΡΟΣΟΧΗ: περιγράφουν το ΣΧΕΔΙΑΖΟΜΕΝΟ στήσιμο των NPC (Χαλκός/
# Δέρμα/Σίδερο) — όχι απαραίτητα τους σημερινούς NPC/πόρους του Area1.
const INTRO_TEXT := "Καλώς όρισες στο χωριό μας, ταξιδιώτη!\n\nΞέρω τον καθένα εδώ γύρω σαν την παλάμη μου — για ποιον θες να σου πω δυο λόγια;"

const TOPICS := [
	{
		"label": "⛏   Ο Μεταλλωρύχος",
		"text": "Ο Μεταλλωρύχος! Μέρα-νύχτα μέσα στο ορυχείο, σκάβει και βγάζει μεταλλεύματα απ' τα έγκατα της γης.\n\nΠήγαινε να τον βρεις — αν απαντήσεις σωστά στις ερωτήσεις του, θα σε ανταμείψει με Χαλκό.\n\nΠολύτιμη πρώτη ύλη για τον εξοπλισμό σου!",
	},
	{
		"label": "🧵   Η Δερματού",
		"text": "Η Δερματού! Τα χέρια της κάνουν θαύματα — μαλακώνει και ράβει τα πιο γερά δέρματα του τόπου.\n\nΑν λύσεις τις ασκήσεις της, θα σου δώσει Δέρμα.\n\nΧωρίς δέρμα δεν φτιάχνεται πανοπλία, να το θυμάσαι!",
	},
	{
		"label": "🔨   Ο Πεταλωτής",
		"text": "Ο Πεταλωτής! Απ' το αμόνι του δεν λείπει ποτέ ο ήχος του σφυριού — πεταλώνει τα άλογα όλου του χωριού.\n\nΑπάντησε στις ερωτήσεις του και θα σε ανταμείψει με Σίδερο.\n\nΤο πιο γερό υλικό για όπλα και πανοπλίες!",
	},
	{
		"label": "👺   Ο Καλικάντζαρος",
		"text": "Ο Ζούμπας! Ζει σε μια σπηλιά στην άκρη του δάσους της μάγισσας και κλέβει ό,τι βρει μπροστά του εδώ και εκατό χρόνια.\n\nΑν τον νικήσεις σε μάχη, θα σου δώσει Χαλκό, Δέρμα και Σίδερο — αλλά και κάτι πιο σπάνιο: ένα κλειδί για το Κάστρο, και μια δική του πανοπλία!\n\nΔεν είναι δύσκολος αντίπαλος — καλή πρώτη δοκιμή για την ομάδα σου.",
	},
	{
		"label": "🌳   Το Στοιχειωμένο Δέντρο",
		"text": "Ο Γερο-Ρίζας! Χίλια χρόνια στέκεται στην άλλη άκρη του δάσους, με ρίζες βαθιές σαν μυστικά.\n\nΕίναι πιο δυνατός από τον καλικάντζαρο — θα χρειαστείς μια πιο δυνατή ομάδα για να τον νικήσεις.\n\nΗ ανταμοιβή του όμως αξίζει τον κόπο: πολύ Χαλκό, Δέρμα, Σίδερο, και μια μαγική Σφαίρα που κανείς άλλος δεν έχει!",
	},
	{
		"label": "🔮   Η Μόργκανα",
		"text": "Πρόσεχε πώς μιλάς γι' αυτήν... Η Μόργκανα κυβερνάει το δάσος από το σπίτι της, βαθιά μέσα στα δέντρα.\n\nΕίναι η πιο δυνατή απ' όλους — νίκησέ την και θα ξεκλειδώσεις μια ολοκαίνουργια περιοχή!\n\nΘωράκισε καλά την ομάδα σου πριν τολμήσεις να χτυπήσεις την πόρτα της.",
	},
	{
		"label": "🏰   Το Κάστρο",
		"text": "Ψηλά πάνω απ' το χωριό στέκει ένα παλιό, εγκαταλειμμένο Κάστρο — δέκα δωμάτια γεμάτα κλειδωμένες πύλες.\n\nΓια να περάσεις κάθε πύλη χρειάζεσαι τα σωστά κλειδιά. Ψάξε καλά μέσα σε κάθε δωμάτιο — κρύβουν κι άλλα κλειδιά!\n\nΦτάσε ως το τέλος και θα βρεις μερικά από τα καλύτερα δώρα όλου του παιχνιδιού.",
	},
	{
		"label": "⚔   Πώς παλεύεις τα τέρατα",
		"text": "Θες να μάθεις πώς κρίνεται μια μάχη; Είναι απλό: κάθε ήρωάς σου έχει 4 στατιστικά — Ζωή, Ζημιά, Ασπίδα, Ταχύτητα.\n\nΌσο πιο δυνατή η ομάδα σου (ο μέσος όρος όλων των ηρώων στον σχηματισμό σου) σε σχέση με το τέρας, τόσο μεγαλύτερη η πιθανότητα νίκης!\n\nΕξόπλισε όπλα και πανοπλίες στους ήρωές σου απ' το Οπλοπωλείο για να τους δυναμώσεις πριν από κάθε μάχη.",
	},
	{
		"label": "📜   Ένας παλιός θρύλος",
		"text": "Λένε πως πριν από πολλά χρόνια, αυτό το δάσος ήταν γεμάτο φως.\n\nΜια νύχτα όμως, η Μόργκανα ήρθε απ' τα βουνά και το σκοτάδι απλώθηκε ανάμεσα στα δέντρα. Τα ζώα του δάσους άλλαξαν... κάποια έγιναν τέρατα.\n\nΛένε ακόμα πως όποιος καταφέρει να τη νικήσει, θα ξαναφέρει το φως. Ποιος ξέρει... ίσως να είσαι εσύ αυτός ο ήρωας.",
	},
]

# ── Αναφορές UI (γεμίζουν στο _build_bubble) ──────────────────────────────
var _msg            : Label
var _options_scroll : ScrollContainer
var _options_box    : VBoxContainer
var _topic_back     : Button

# ═══════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_build()

func show_popup() -> void:
	visible = true
	_show_intro()   # πάντα από την αρχή σε κάθε επίσκεψη
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.45)

func _close() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.30)
	tw.tween_callback(func(): visible = false)

# ═══════════════════════════════════════════════════════════════════════════
# ΚΑΤΑΣΚΕΥΗ UI
# ═══════════════════════════════════════════════════════════════════════════
func _build() -> void:
	_build_background()
	_build_character()
	_build_bubble()
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
	# Ελαφρύ overlay για να διαβάζεται η φούσκα πάνω στο φωτεινό λιβάδι
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.22)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

# ── Ο γέρος (δεξιά, κομμένος στο CHAR_REGION ώστε να μην «κουβαλάει» τα
# διάφανα περιθώρια του PNG μέσα στο κεντράρισμα) ──────────────────────────
func _build_character() -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas  = load(CHAR_PATH)
	atlas.region = CHAR_REGION
	var char_rect := TextureRect.new()
	char_rect.texture      = atlas
	char_rect.position     = Vector2(540, 840)
	char_rect.size         = Vector2(500, 740)
	char_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	char_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	char_rect.flip_h       = true   # κοιτάει προς τα δεξιά (ίδια φορά με το κουμπί του στον χάρτη)
	char_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(char_rect)

# ── Φούσκα ομιλίας (αριστερά, ουρά προς τον γέρο κάτω-δεξιά) ───────────────
# Η φούσκα έχει δύο «όψεις» που εναλλάσσονται με show/hide (όχι rebuild):
#   intro : INTRO_TEXT + 3 κουμπιά-θέματα (_options_box)
#   topic : κείμενο τεχνίτη + κουμπί «Ρώτα για άλλον» (_topic_back)
func _build_bubble() -> void:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	const BX := 32.0
	const BY := 200.0
	const BW := 600.0
	const BH := 640.0

	# Σκιά
	_shadow(root, Vector2(BX + 8, BY + 8), Vector2(BW, BH), 18)

	# Κύριο πλαίσιο — περγαμηνή με χρυσό περίγραμμα, ίδιο ύφος με τους NPC
	_styled_panel(root, Vector2(BX, BY), Vector2(BW, BH),
		C_PARCH, C_GOLD, 5, 18)
	_styled_panel(root, Vector2(BX + 10, BY + 10), Vector2(BW - 20, BH - 20),
		C0, C_GOLD_D, 2, 14)

	# Ουρά φούσκας (προς τον γέρο — κάτω-δεξιά)
	_bubble_tail(root, BX + BW - 48, BY + BH - 2)

	# Τίτλος NPC
	_styled_panel(root, Vector2(BX + 22, BY + 22), Vector2(BW - 44, 58),
		C_WOOD_D, C_GOLD_D, 2, 8)
	_label(root, "🧭  Ο Γέρο-Νέστορας",
		Vector2(BX + 22, BY + 22), Vector2(BW - 44, 58),
		22, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER,
		Color(0, 0, 0, 0.80), 1, 2)

	# Διαχωριστής
	_cr_on(root, Vector2(BX + 30, BY + 86), Vector2(BW - 60, 2), C_GOLD_D)

	# Κείμενο ομιλίας — καταλαμβάνει όλο το εσωτερικό· στην intro όψη τα
	# κουμπιά-θέματα κάθονται στο κάτω μισό (το INTRO_TEXT είναι αρκετά
	# σύντομο ώστε να μην φτάνει ποτέ μέχρι εκεί).
	_msg = Label.new()
	_msg.position           = Vector2(BX + 28, BY + 100)
	_msg.size               = Vector2(BW - 56, BH - 130)
	_msg.autowrap_mode      = TextServer.AUTOWRAP_WORD_SMART
	_msg.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_msg.add_theme_font_size_override("font_size", 26)
	_msg.add_theme_color_override("font_color", C_TEXT)
	_msg.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.30))
	_msg.add_theme_constant_override("shadow_offset_x", 0)
	_msg.add_theme_constant_override("shadow_offset_y", 1)
	_msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_msg)

	# Κουμπιά-θέματα (intro όψη) — μεγέθη δαχτύλου για κινητό (ύψος 84). Πλέον
	# 9 θέματα (πάνω από όσα χωράνε στο σταθερό ύψος της φούσκας) — μέσα σε
	# ScrollContainer, ΙΔΙΟ footprint (θέση/μέγεθος) με το παλιό VBoxContainer
	# ώστε να μην αλλάζει το layout της φούσκας.
	_options_scroll = ScrollContainer.new()
	_options_scroll.position = Vector2(BX + 30, BY + BH - 312)
	_options_scroll.size     = Vector2(BW - 60, 276)
	_options_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_options_scroll)
	_options_box = VBoxContainer.new()
	_options_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options_box.add_theme_constant_override("separation", 12)
	_options_scroll.add_child(_options_box)
	for i in TOPICS.size():
		var btn := Button.new()
		btn.text = TOPICS[i]["label"]
		btn.custom_minimum_size = Vector2(0, 84)
		btn.add_theme_font_size_override("font_size", 26)
		_style_back_btn(btn)   # ίδιο ξύλο/χρυσό στυλ με το «Πίσω στο Χωριό»
		btn.pressed.connect(_show_topic.bind(i))
		_options_box.add_child(btn)

	# «Ρώτα για άλλον» (topic όψη) — γυρνάει στις επιλογές
	_topic_back = Button.new()
	_topic_back.text     = "◄   Ρώτα για άλλον"
	_topic_back.position = Vector2(BX + 30, BY + BH - 114)
	_topic_back.size     = Vector2(BW - 60, 84)
	_topic_back.add_theme_font_size_override("font_size", 26)
	_style_back_btn(_topic_back)
	_topic_back.pressed.connect(_show_intro)
	add_child(_topic_back)

	_show_intro()

# ── Εναλλαγή όψεων φούσκας ────────────────────────────────────────────────
func _show_intro() -> void:
	_msg.text = INTRO_TEXT
	_options_scroll.visible = true
	_topic_back.visible     = false

func _show_topic(index: int) -> void:
	_msg.text = TOPICS[index]["text"]
	_options_scroll.visible = false
	_topic_back.visible     = true

func _bubble_tail(parent: Control, tx: float, ty: float) -> void:
	_cr_on(parent, Vector2(tx,      ty),      Vector2(32, 14), C_PARCH)
	_cr_on(parent, Vector2(tx + 8,  ty + 12), Vector2(22, 14), C_PARCH)
	_cr_on(parent, Vector2(tx + 16, ty + 24), Vector2(14, 14), C_PARCH)
	_cr_on(parent, Vector2(tx - 1,  ty - 1),  Vector2(34,  5), C_GOLD)
	_cr_on(parent, Vector2(tx + 31, ty + 2),  Vector2(5,  14), C_GOLD)

# ── Κουμπί Πίσω ───────────────────────────────────────────────────────────
func _build_back_button() -> void:
	_shadow_plain(Vector2(W / 2 - 195, H - 134), Vector2(390, 84))
	var btn := Button.new()
	btn.text     = "◄   Πίσω στο Χωριό"
	btn.position = Vector2(W / 2 - 195, H - 138)
	btn.size     = Vector2(390, 84)
	btn.add_theme_font_size_override("font_size", 30)
	_style_back_btn(btn)
	add_child(btn)
	btn.pressed.connect(_close)

# ═══════════════════════════════════════════════════════════════════════════
# ΒΟΗΘΗΤΙΚΕΣ ΣΥΝΑΡΤΗΣΕΙΣ (ίδιο μοτίβο με cotton_popup.gd κ.λπ.)
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
	s.bg_color = Color(0, 0, 0, 0.55)
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
			shadow: Color = Color(0, 0, 0, 0), sx: int = 0, sy: int = 0) -> Label:
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
	n.shadow_color = Color(0, 0, 0, 0.68); n.shadow_size = 7
	btn.add_theme_stylebox_override("normal", n)
	var h := StyleBoxFlat.new()
	h.bg_color = C_WOOD; h.border_color = C_GOLD
	h.set_border_width_all(5); h.set_corner_radius_all(10)
	h.shadow_color = C_GOLD.lightened(0.10); h.shadow_size = 16
	btn.add_theme_stylebox_override("hover", h)
	var pr := StyleBoxFlat.new()
	pr.bg_color = Color(0.055, 0.028, 0.008); pr.border_color = C_GOLD.darkened(0.25)
	pr.set_border_width_all(3); pr.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("pressed", pr)
	btn.add_theme_stylebox_override("focus", StyleBoxFlat.new())
	btn.add_theme_color_override("font_color",         C_GOLD)
	btn.add_theme_color_override("font_hover_color",   C_GOLD_S)
	btn.add_theme_color_override("font_pressed_color", C_GOLD.darkened(0.30))
	btn.add_theme_color_override("font_shadow_color",  Color(0, 0, 0, 0.92))
	btn.add_theme_constant_override("shadow_offset_x", 2)
	btn.add_theme_constant_override("shadow_offset_y", 3)
