extends Control

# ═══════════════════════════════════════════════════════════════════════════
# MiniBossPopup — τα «μικρά» boss του δάσους της μάγισσας
# ═══════════════════════════════════════════════════════════════════════════
# ΕΝΑ script/scene για ΟΛΑ τα mini bosses: ο καλικάντζαρος (κάτω-αριστερά στον
# witch map) και το στοιχειωμένο δέντρο (πάνω-δεξιά). Ξεχωρίζουν ΜΟΝΟ από τα
# δεδομένα του BOSS_DEFS παρακάτω — νέο mini boss = ένα ακόμα entry εκεί + ένα
# κουμπί στο WitchMapPopup.tscn, καμία νέα λογική.
#
# ── ΡΟΗ (ίδιο μοτίβο με boss_popup.gd της Μόργκανας) ─────────────────────────
# Κατάσταση 1: το τέρας μιλάει (εικόνα + φούσκα διαλόγου).
# Κατάσταση 2: με ένα κλικ εμφανίζεται στο board είτε «άδεια ομάδα», είτε
#              «ΝΙΚΗΜΕΝΟ» (αν το boss έχει ήδη νικηθεί), είτε τα ΟΡΑΤΑ odds
#              νίκης + κουμπί «Επίθεση».
# Κατάσταση 3: το κουμπί «Επίθεση» ΔΕΝ κάνει πλέον roll εδώ — ΞΕΚΙΝΑΕΙ την
#              animated μάχη (BossFight, ίδιο μοτίβο με τη Μόργκανα): το boss
#              δεξιά με τα animations του (goblin/tree_animation), οι ήρωες
#              αριστερά. Το roll, η ανταμοιβή, η καταγραφή και το αποτέλεσμα
#              ζουν πλέον ΕΚΕΙ (boss_fight.gd).
#
# ── ΛΟΓΙΚΗ ΜΑΧΗΣ ────────────────────────────────────────────────────────────
# ΙΔΙΑ με τη Μόργκανα, κεντρικά στο Heroes autoload: ο συνολικός μέσος όρος των
# stats της ενεργής ομάδας (Heroes.get_party_average_stat) μπαίνει στην ίδια
# καμπύλη (Heroes.win_probability) — αλλάζει ΜΟΝΟ το στατιστικό του boss, που
# είναι και το σημείο του 50%. Άρα: καλικάντζαρος (5) ευκολότερος από το δέντρο
# (10), που είναι ευκολότερο από τη Μόργκανα (15).
#
# ── ΝΙΚΗ / ΚΟΣΤΟΣ ΕΠΑΝΑΛΗΨΗΣ ────────────────────────────────────────────────
# Σε ΝΙΚΗ δίνεται η ανταμοιβή (Dictionary νόμισμα->ποσό — Χαλκός/Δέρμα/Σίδερο/
# Κέρμα, βλ. BOSS_DEFS[...]["reward"] παρακάτω) μέσω του ΥΠΑΡΧΟΝΤΟΣ Currency
# autoload, και το boss κλειδώνει ΟΡΙΣΤΙΚΑ (GameData.record_mini_boss_win):
# κάθε επόμενη επίσκεψη δείχνει «ΝΙΚΗΜΕΝΟ» χωρίς κουμπί επίθεσης. Έτσι η
# ανταμοιβή δίνεται ΜΙΑ φορά — πριν, με απεριόριστες δωρεάν επαναλήψεις, ήταν
# farmable. Χαλκός/Δέρμα/Σίδερο δίνονται ΚΑΙ στα δύο mini boss ΙΣΑ ΜΕΤΑΞΥ ΤΟΥΣ
# (ίδια αξία — τα τρία αυτά υλικά βγαίνουν από ΤΗΝ ΙΔΙΑ δυσκολία quiz ανά NPC,
# βλ. σχόλιο στο heroes.gd HERO_DEFS), με το δέντρο (πιο δύσκολο) να δίνει
# περισσότερο από τον καλικάντζαρο.
#
# Ο καλικάντζαρος ΕΠΙΠΛΕΟΝ δίνει, ΜΟΝΟ στην πρώτη νίκη, το bootstrap κλειδί
# του side quest του κάστρου (βλ. BOSS_DEFS["goblin"]["key_reward"] — παλιά
# το έδινε η Δερματού, απεριόριστα farmable, βλ. cotton_popup.gd) ΚΑΙ το
# "Bad Goblin Armor" δωρεάν (βλ. BOSS_DEFS["goblin"]["armor_reward"] +
# EquipmentCatalog.grant στο boss_fight.gd) — γι' αυτό η νομισματική
# ανταμοιβή του είναι μικρότερη από το μισό του δέντρου, ώστε η ΣΥΝΟΛΙΚΗ αξία
# να μείνει balanced απέναντι στο δέντρο (δυσκολότερο, καμία άλλη ανταμοιβή).
# Το δέντρο, συμμετρικά, δίνει ΜΟΝΟ στην πρώτη νίκη τη "Tree Magic Sphere"
# δωρεάν (βλ. BOSS_DEFS["tree"]["weapon_reward"]).
#
# Η πρώτη προσπάθεια είναι δωρεάν. Μετά από ήττα (GameData.record_mini_boss_loss)
# ΚΑΘΕ νέα προσπάθεια κοστίζει RETRY_COST Κέρματα — ίδιο μοτίβο/νόμισμα με τη
# Μόργκανα (βλ. boss_popup.gd), απλώς φθηνότερα (100 αντί για 200), και ΑΝΑ boss
# (ο καλικάντζαρος και το δέντρο μετράνε ξεχωριστά). Αν δεν φτάνουν τα Κέρματα,
# το κουμπί επίθεσης απενεργοποιείται και εμφανίζεται μήνυμα.

const BOARD_PATH := "res://Εικόνες/board.png"

# Κόστος επανάληψης μετά από ήττα — χρησιμοποιεί το ΥΠΑΡΧΟΝ σύστημα νομισμάτων
# (Currency autoload), ίδιο νόμισμα με τη Μόργκανα. Το Κέρμα έρχεται ΜΟΝΟ από το
# Ανταλλακτήριο του Νάνου (βλ. gnome_popup.gd).
const RETRY_COST := 100
const RETRY_CURRENCY := "Κέρμα"

# Ίδιο literal με KeyInventory.CATEGORY_NUMERIC — ίδιο μοτίβο με το τοπικό
# CATEGORY_NUMERIC του castle_popup.gd, ώστε το BOSS_DEFS παρακάτω να μην
# εξαρτάται από τη σειρά αυτοφόρτωσης του KeyInventory autoload.
const KEY_CATEGORY_NUMERIC := "Αριθμητικό Κλειδί"

# Κάθε mini boss: όνομα, εικόνες, το crop της εικόνας του (τα PNG είναι cut-out
# σε μεγάλο ΔΙΑΦΑΝΟ καμβά — μετρημένο από τα μη-διάφανα pixel, ίδιο μοτίβο με
# boss_popup.gd/blacksmith_popup.gd), στατιστικό (= σημείο 50%), ανταμοιβή νίκης
# και διάλογος.
const BOSS_DEFS := {
	"goblin": {
		"name": "Ζούμπας ο Καλικάντζαρος",
		"icon": "👺",
		"char": "res://Εικόνες/bad_goblin.png",
		"char_region": Rect2(494, 32, 401, 701),
		"bg": "res://Εικόνες/bad_goblin_bg.png",
		"stat": 5,
		# Ίσα Χαλκός/Δέρμα/Σίδερο (ισάξια υλικά, βλ. σχόλιο κορυφής) + λίγο
		# Κέρμα. Μικρότερο από το αντίστοιχο του δέντρου παρακάτω — μαζί με το
		# key_reward + armor_reward (αποκλειστικό τρόπαιο, ΔΕΝ αγοράζεται από
		# το Shop, βλ. εκεί) η συνολική αξία της νίκης είναι ήδη αρκετή ώστε
		# να μείνει balanced απέναντι στο δέντρο (δυσκολότερο, καμία άλλη
		# ανταμοιβή εκτός από τη σφαίρα).
		"reward": {"Χαλκός": 20, "Δέρμα": 20, "Σίδερο": 20, "Κέρμα": 3},
		# Το bootstrap κλειδί του side quest του κάστρου (Armory, "k <= 8" —
		# βλ. Scripts/castle_popup.gd) — δινόταν παλιά (απεριόριστα farmable)
		# από τη Δερματού· τώρα δίνεται ΜΙΑ φορά, εδώ, στην πρώτη νίκη πάνω
		# στον καλικάντζαρο (ταιριάζει με το "μία φορά συνολικά" της νίκης —
		# βλ. _do_fight). Μόνο ο καλικάντζαρος έχει αυτό το πεδίο· κανένα
		# άλλο mini boss δεν δίνει κλειδί.
		"key_reward": {"value": 8, "category": KEY_CATEGORY_NUMERIC},
		# Τρόπαιο ΑΠΟΚΛΕΙΣΤΙΚΟ: το "Bad Goblin Armor" (βλ. armor_inventory.gd,
		# Θώρακας_2, "hidden": true) χαρίζεται ΧΩΡΙΣ χρέωση στην πρώτη νίκη
		# (EquipmentCatalog.grant, βλ. boss_fight.gd::_conclude_fight) — είναι
		# η ΜΟΝΗ πηγή του, ΔΕΝ αγοράζεται από το Shop.
		"armor_reward": "Θώρακας_2",
		"dialogue": "Χι χι χι... ποιος τολμάει;\n\nΑυτή η σπηλιά είναι ΔΙΚΗ μου!\nΕδώ και εκατό χρόνια κλέβω\nό,τι περνάει από το μονοπάτι!\n\nΆντε, δείξε μου τι αξίζεις!",
		"taunt_win":  "Άουτς! Πάρ' τα και άσε με ήσυχο!",
		"taunt_lose": "Χα! Γύρνα σπίτι σου, αδύναμε!",
	},
	"tree": {
		"name": "Γερο-Ρίζας το Στοιχειωμένο Δέντρο",
		"icon": "🌳",
		"char": "res://Εικόνες/bad_tree.png",
		"char_region": Rect2(140, 8, 861, 1423),
		"bg": "res://Εικόνες/bad_tree_bg.png",
		"stat": 10,
		# Μεγαλύτερο από τον καλικάντζαρο (βλ. σχόλιο εκεί) — το δέντρο είναι
		# δυσκολότερο (stat 10) και δεν έχει άλλη ανταμοιβή εκτός από τη
		# σφαίρα (αποκλειστικό τρόπαιο, ΔΕΝ αγοράζεται από το Shop, βλ. εκεί),
		# οπότε δικαιολογείται η μεγαλύτερη καθαρή αξία σε νομίσματα.
		"reward": {"Χαλκός": 50, "Δέρμα": 50, "Σίδερο": 50, "Κέρμα": 5},
		# Τρόπαιο ΑΠΟΚΛΕΙΣΤΙΚΟ: η "Tree Magic Sphere" (βλ. weapon_inventory.gd,
		# Σφαίρα_1, "hidden": true) χαρίζεται ΧΩΡΙΣ χρέωση στην πρώτη νίκη
		# (EquipmentCatalog.grant, βλ. boss_fight.gd::_conclude_fight) — είναι
		# η ΜΟΝΗ πηγή της, ΔΕΝ αγοράζεται από το Shop.
		"weapon_reward": "Σφαίρα_1",
		"dialogue": "Γρρρ... ποιος ταράζει τις ρίζες μου;\n\nΧίλια χρόνια στέκομαι εδώ\nκαι τα κλαδιά μου έχουν λυγίσει\nπιο γενναίους από σένα...\n\nΈλα κοντά, αν τολμάς!",
		"taunt_win":  "Οι ρίζες μου... υποκλίνονται. Πάρε τον θησαυρό μου.",
		"taunt_lose": "Τα κλαδιά μου σε πέταξαν σαν φύλλο!",
	},
}

# ── Παλέτα (ίδια γραμμή με boss_popup.gd) ──────────────────────────────────
const C0       := Color(0, 0, 0, 0)
const C_GOLD   := Color(0.940, 0.760, 0.160)
const C_GOLD_D := Color(0.360, 0.278, 0.058)
const C_GOLD_S := Color(1.000, 0.920, 0.560)
const C_PARCH  := Color(0.900, 0.880, 0.820)
const C_PARCH_D:= Color(0.720, 0.700, 0.640)
const C_WOOD   := Color(0.200, 0.120, 0.052)
const C_WOOD_D := Color(0.130, 0.075, 0.028)
const C_TEXT   := Color(0.110, 0.070, 0.030)
const C_CRIMSON:= Color(0.580, 0.058, 0.058)
const C_FOREST := Color(0.180, 0.420, 0.160)   # πράσινο δάσους — ξεχωρίζει από το μωβ της Μόργκανας
const C_OK     := Color(0.560, 0.900, 0.460)

const W := 1080.0
const H := 1920.0

var _boss_id := ""
var _state := 0      # 1 = διάλογος, 2 = board (odds/αποτέλεσμα)
var _bg     : TextureRect
var _char   : TextureRect
var _bubble : Control
var _board  : Control
var _hint   : Label

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_build()
	gui_input.connect(_on_gui_input)

func _def() -> Dictionary:
	return BOSS_DEFS.get(_boss_id, {})

## Καλείται από το witch_map_popup.gd με "goblin" ή "tree".
func show_popup(boss_id: String) -> void:
	if not BOSS_DEFS.has(boss_id):
		return
	_boss_id = boss_id
	visible  = true
	_state   = 1
	_apply_boss_visuals()
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

func _on_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _state == 1:
		_go_to_state2()
	accept_event()

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
# ΚΑΤΑΣΚΕΥΗ UI (χτίζεται ΜΙΑ φορά· το _apply_boss_visuals αλλάζει ό,τι διαφέρει
# ανά boss, ώστε το ΙΔΙΟ instance να εξυπηρετεί και τα δύο)
# ═══════════════════════════════════════════════════════════════════════════
func _build() -> void:
	_bg     = _build_background()
	_char   = _build_character()
	_bubble = _build_bubble()
	_board  = _build_board()
	_board.visible = false
	_hint   = _build_hint()
	_build_back_button()

## Ό,τι αλλάζει ανά boss: φόντο, εικόνα+crop, όνομα και κείμενο διαλόγου.
func _apply_boss_visuals() -> void:
	var d := _def()
	if ResourceLoader.exists(str(d["bg"])):
		_bg.texture = load(str(d["bg"]))
	var atlas := AtlasTexture.new()
	atlas.atlas  = load(str(d["char"]))
	atlas.region = d["char_region"]
	_char.texture = atlas
	(_bubble.get_node("Name") as Label).text = "%s  %s" % [d["icon"], d["name"]]
	(_bubble.get_node("Msg") as Label).text  = str(d["dialogue"])

func _build_background() -> TextureRect:
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.05, 0.02, 0.40)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	return bg

## Το texture/region μπαίνει στο _apply_boss_visuals. EXPAND_IGNORE_SIZE ΠΡΙΝ το
## size (αλλιώς το minimum size της υφής κλειδώνει το πλαίσιο και η φιγούρα
## ξεχειλίζει εκτός οθόνης — βλ. ίδιο σχόλιο σε boss_popup.gd).
func _build_character() -> TextureRect:
	var c := TextureRect.new()
	c.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	c.position     = Vector2(300, 620)
	c.size         = Vector2(500, 920)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c

func _build_bubble() -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	const BX := 32.0
	const BY := 130.0
	const BW := 580.0
	const BH := 470.0

	_shadow(root, Vector2(BX+8, BY+8), Vector2(BW, BH), 18)
	_styled_panel(root, Vector2(BX, BY), Vector2(BW, BH), C_PARCH, C_FOREST, 5, 18)
	_styled_panel(root, Vector2(BX+10, BY+10), Vector2(BW-20, BH-20), C0, C_FOREST.darkened(0.35), 2, 14)
	_bubble_tail(root, BX + BW - 48, BY + BH - 2)

	_styled_panel(root, Vector2(BX+22, BY+22), Vector2(BW-44, 58), C_WOOD_D, C_FOREST.darkened(0.3), 2, 8)
	var name_lbl := _label(root, "", Vector2(BX+22, BY+22), Vector2(BW-44, 58),
		22, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, Color(0,0,0,0.80), 1, 2)
	name_lbl.name = "Name"

	_cr_on(root, Vector2(BX+30, BY+86), Vector2(BW-60, 2), C_FOREST.darkened(0.3))

	var msg := Label.new()
	msg.name = "Msg"
	# ΣΕΙΡΑ: autowrap ΠΡΙΝ το size — αλλιώς το Label κλειδώνει στο πλήρες πλάτος
	# του κειμένου και ξεχειλίζει έξω από τη φούσκα.
	msg.autowrap_mode      = TextServer.AUTOWRAP_WORD_SMART
	msg.position           = Vector2(BX+28, BY+96)
	msg.size               = Vector2(BW-56, BH-130)
	msg.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	msg.add_theme_font_size_override("font_size", 26)
	msg.add_theme_color_override("font_color", C_TEXT)
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(msg)
	return root

func _bubble_tail(parent: Control, tx: float, ty: float) -> void:
	_cr_on(parent, Vector2(tx,    ty),    Vector2(32, 14), C_PARCH)
	_cr_on(parent, Vector2(tx+8,  ty+12), Vector2(22, 14), C_PARCH)
	_cr_on(parent, Vector2(tx+16, ty+24), Vector2(14, 14), C_PARCH)
	_cr_on(parent, Vector2(tx-1,  ty-1),  Vector2(34, 5),  C_FOREST)

func _build_board() -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Πιο συμπαγής πλάκα από της Μόργκανας: τα mini bosses δείχνουν λιγότερα
	# (χωρίς κόστος επανάληψης/λίστες), οπότε ένα ψηλό board άφηνε μεγάλο κενό.
	const BRD_X := 60.0
	const BRD_Y := 420.0
	const BRD_W := 960.0
	const BRD_H := 880.0

	var brd := TextureRect.new()
	brd.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	brd.stretch_mode = TextureRect.STRETCH_SCALE
	var brd_tex : Texture2D = load(BOARD_PATH) if ResourceLoader.exists(BOARD_PATH) else null
	if brd_tex:
		# Το board.png (441×565) έχει διάφανα περιθώρια — το ξύλο ζει στο
		# x 16-424, y 84-512 (opaque bbox από το alpha, ΙΔΙΑ μέτρηση με το
		# board του boss_popup.gd/miner_popup.gd). Χωρίς αυτό το crop, το
		# TextureRect τεντώνει ΟΛΟΚΛΗΡΟ τον καμβά (μαζί με το διάφανο περιθώριο)
		# μέσα στο BRD_W×BRD_H, οπότε ένα σταθερό offset σαν το παλιό +130
		# κατέληγε να "πατάει" στο χρυσό γείσο του πλαισίου αντί να είναι μέσα
		# στο ξύλο — αυτό ήταν το "πέφτει λίγο πιο πάνω" bug.
		var atlas := AtlasTexture.new()
		atlas.atlas  = brd_tex
		atlas.region = Rect2(16, 84, 409, 429)
		brd.texture = atlas
	brd.position     = Vector2(BRD_X, BRD_Y)
	brd.size         = Vector2(BRD_W, BRD_H)
	brd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(brd)

	# Με το board πλέον cropped, το BRD_W×BRD_H αντιστοιχεί ακριβώς στο ορατό
	# ξύλο (γωνία-σε-γωνία) — το ResultBox χρειάζεται μόνο ένα μικρό εσωτερικό
	# περιθώριο ώστε να μην πατάει στο χρυσό γείσο. ~9% συμμετρικό περιθώριο
	# πάνω/κάτω (ίδια αναλογία με το +120/1320 του boss_popup.gd) = 80px εδώ.
	# Ύψος 560: όσο ακριβώς χρειάζεται η ΜΕΓΑΛΥΤΕΡΗ όψη (αποτέλεσμα νίκης:
	# εικονίδιο + τίτλος + ατάκα + ανταμοιβή + κουμπί ≈ 490) — έτσι δεν μένει
	# μεγάλο κενό κουτί, και το ξύλο του board φαίνεται γύρω σαν πλαίσιο.
	var box := Panel.new()
	box.name     = "ResultBox"
	box.position = Vector2(BRD_X + 80.0, BRD_Y + 80.0)
	box.size     = Vector2(BRD_W - 160.0, 560.0)
	root.add_child(box)
	return root

func _clear_result_box() -> Panel:
	var box := _board.get_node("ResultBox") as Panel
	for c in box.get_children():
		c.queue_free()
	return box

# ═══════════════════════════════════════════════════════════════════════════
# ΛΟΓΙΚΗ ΜΑΧΗΣ
# ═══════════════════════════════════════════════════════════════════════════
func _show_challenge() -> void:
	# Ο έλεγχος «νικημένο» προηγείται ΟΛΩΝ: ένα ήδη νικημένο boss δεν ξαναπαίζεται
	# ποτέ, ακόμα κι αν στο μεταξύ αδειάσει η ομάδα.
	if GameData.is_mini_boss_defeated(_boss_id):
		_show_defeated()
		return
	if Heroes.get_active_party().is_empty():
		_show_no_party()
		return
	_show_odds()

## Το boss έχει ήδη νικηθεί — καμία νέα προσπάθεια, καμία επιπλέον ανταμοιβή.
## Μόνο το κουμπί «Πίσω στο Δάσος» (χτισμένο μόνιμα, βλ. _build_back_button).
func _show_defeated() -> void:
	var d := _def()
	var box := _styled_box(Color(0.06, 0.18, 0.08, 0.90), C_GOLD)

	_label(box, "🏆", Vector2(0, 60), Vector2(box.size.x, 110),
		84, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_label(box, "ΝΙΚΗΜΕΝΟ!", Vector2(0, 180), Vector2(box.size.x, 70),
		52, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, Color(0,0,0,0.9), 2, 3)

	var msg := Label.new()
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.text = "Έχεις ήδη νικήσει %s.\n\nΟ θησαυρός του είναι δικός σου — δεν έχει τίποτα άλλο να σου δώσει." % d["name"]
	msg.position = Vector2(50, 270)
	msg.size     = Vector2(box.size.x - 100, 180)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 26)
	msg.add_theme_color_override("font_color", C_PARCH_D)
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(msg)

func _show_no_party() -> void:
	var box := _styled_box(Color(0.16, 0.08, 0.04, 0.85), C_CRIMSON)
	_label(box, "Η ομάδα σου είναι άδεια!", Vector2(0, 70), Vector2(box.size.x, 60),
		36, C_CRIMSON.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER)
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "Πήγαινε στους «Χαρακτήρες» και βάλε τουλάχιστον έναν ήρωα σε μια θέση της ομάδας πριν πολεμήσεις."
	hint.position = Vector2(50, 160)
	hint.size     = Vector2(box.size.x - 100, 140)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 26)
	hint.add_theme_color_override("font_color", C_PARCH_D)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(hint)

func _show_odds() -> void:
	var d := _def()
	var box := _styled_box(Color(0.06, 0.12, 0.06, 0.88), C_FOREST.lightened(0.2))

	var avg := Heroes.get_party_average_stat()
	var probability := Heroes.win_probability(avg, int(d["stat"]))

	_label(box, "Πιθανότητα Νίκης", Vector2(0, 30), Vector2(box.size.x, 44),
		28, C_PARCH_D, HORIZONTAL_ALIGNMENT_CENTER)
	_label(box, "%d%%" % int(round(probability * 100.0)), Vector2(0, 74), Vector2(box.size.x, 100),
		80, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, Color(0,0,0,0.9), 2, 3)
	_label(box, "Μέσος όρος ομάδας: %.1f / 20   —   %s: %d" % [avg, d["name"], int(d["stat"])],
		Vector2(20, 182), Vector2(box.size.x - 40, 40), 22, C_PARCH_D, HORIZONTAL_ALIGNMENT_CENTER)

	# ── Κόστος επανάληψης (μόνο αν έχει ήδη χάσει από ΑΥΤΟ το boss) ──────────
	var must_pay := GameData.has_lost_to_mini_boss(_boss_id)
	var coins := Currency.get_amount(RETRY_CURRENCY)
	var can_pay := coins >= RETRY_COST

	if must_pay:
		var cost_lbl := Label.new()
		cost_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cost_lbl.text = "Σε νίκησε ήδη!\nΝέα προσπάθεια: %d %s   —   έχεις %d" % [
			RETRY_COST, RETRY_CURRENCY, coins]
		cost_lbl.position = Vector2(30, 226)
		cost_lbl.size     = Vector2(box.size.x - 60, 66)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_font_size_override("font_size", 23)
		cost_lbl.add_theme_color_override("font_color", C_GOLD if can_pay else C_CRIMSON.lightened(0.35))
		cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(cost_lbl)

	var attack := Button.new()
	attack.text = "⚔  Επίθεση (%d %s)" % [RETRY_COST, RETRY_CURRENCY] if must_pay else "⚔  Επίθεση"
	attack.position = Vector2(box.size.x / 2.0 - 190, 300)
	attack.size     = Vector2(380, 100)
	attack.add_theme_font_size_override("font_size", 30)
	_style_attack_btn(attack)
	attack.disabled = must_pay and not can_pay
	box.add_child(attack)
	if not attack.disabled:
		attack.pressed.connect(func(): _do_fight(probability, must_pay))

## Η χρέωση γίνεται ΜΟΝΟ τη στιγμή της επίθεσης — αν αποτύχει (π.χ. τα Κέρματα
## ξοδεύτηκαν αλλού στο μεταξύ), ξαναχτίζεται η οθόνη με το μήνυμα ανεπάρκειας
## (ίδιο μοτίβο με boss_popup.gd). Μετά ξεκινάει η ANIMATED μάχη — το roll, η
## ανταμοιβή σε Χαλκό (+ κλειδί goblin), η καταγραφή win/loss και το overlay
## αποτελέσματος ζουν πλέον στο boss_fight.gd (κοινά με τη Μόργκανα).
func _do_fight(probability: float, must_pay: bool) -> void:
	if must_pay and not Currency.spend({RETRY_CURRENCY: RETRY_COST}):
		_show_odds()
		return
	_launch_fight(probability)

## Ξεκινάει το animated BossFight (sibling στο Area1) περνώντας την πιθανότητα
## νίκης ΚΑΙ το boss id ("goblin"/"tree") — το BossFight στήνει το σωστό
## σκηνικό/animations από αυτό. Το popup κλείνει καθώς ανοίγει η μάχη (ίδιο
## μοτίβο με boss_popup.gd::_launch_fight).
func _launch_fight(probability: float) -> void:
	var fight := get_parent().get_node_or_null("BossFight")
	if fight:
		fight.show_popup(probability, _boss_id)
		fight.move_to_front()
	_close()

## Κοινό στήσιμο του κουτιού αποτελέσματος (φόντο/περίγραμμα ανά κατάσταση).
func _styled_box(bg: Color, border: Color) -> Panel:
	var box := _clear_result_box()
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = border
	s.set_border_width_all(3); s.set_corner_radius_all(8)
	box.add_theme_stylebox_override("panel", s)
	return box

# ═══════════════════════════════════════════════════════════════════════════
# HINT / BACK / ΒΟΗΘΗΤΙΚΑ
# ═══════════════════════════════════════════════════════════════════════════
func _build_hint() -> Label:
	var l := _label(self, "✦  Πάτα οπουδήποτε για να συνεχίσεις  ✦",
		Vector2(0, H - 190), Vector2(W, 50), 24, C_PARCH_D, HORIZONTAL_ALIGNMENT_CENTER,
		Color(0,0,0,0.90), 1, 2)
	var tw := l.create_tween()
	tw.set_loops()
	tw.tween_property(l, "modulate:a", 0.25, 1.0)
	tw.tween_property(l, "modulate:a", 1.00, 1.0)
	return l

func _build_back_button() -> void:
	var btn := Button.new()
	btn.text     = "◄   Πίσω στο Δάσος"
	btn.position = Vector2(W/2 - 195, H - 138)
	btn.size     = Vector2(390, 84)
	btn.add_theme_font_size_override("font_size", 30)
	_style_back_btn(btn)
	add_child(btn)
	btn.pressed.connect(_close)

func _styled_panel(parent: Control, pos: Vector2, sz: Vector2, bg: Color, border: Color, bw: int, cr: int) -> void:
	var p := Panel.new()
	p.position = pos; p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = border
	s.set_border_width_all(bw); s.set_corner_radius_all(cr)
	p.add_theme_stylebox_override("panel", s)
	parent.add_child(p)

func _shadow(parent: Control, pos: Vector2, sz: Vector2, cr: int) -> void:
	var p := Panel.new()
	p.position = pos; p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0.55); s.set_corner_radius_all(cr)
	s.shadow_color = Color(0, 0, 0, 0.40); s.shadow_size = 20
	p.add_theme_stylebox_override("panel", s)
	parent.add_child(p)

func _cr_on(parent: Control, pos: Vector2, sz: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.position = pos; r.size = sz; r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)

func _label(parent: Control, text: String, pos: Vector2, sz: Vector2, fsz: int,
			col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
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

func _style_attack_btn(btn: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = C_FOREST.darkened(0.25); n.border_color = C_GOLD.darkened(0.15)
	n.set_border_width_all(4); n.set_corner_radius_all(12)
	n.shadow_color = Color(0,0,0,0.65); n.shadow_size = 8
	btn.add_theme_stylebox_override("normal", n)

	# Απενεργοποιημένο (δεν φτάνουν τα Κέρματα): ΠΡΕΠΕΙ να οριστεί ρητά — χωρίς
	# αυτό το Godot πέφτει στο προεπιλεγμένο theme, που πάνω στο σκούρο panel
	# εξαφανίζει το πλαίσιο και το κουμπί μοιάζει με σκέτο κείμενο (βλ. ίδιο
	# σχόλιο στο boss_popup.gd).
	var dis := StyleBoxFlat.new()
	dis.bg_color = Color(0.16, 0.18, 0.16, 0.85); dis.border_color = C_PARCH_D.darkened(0.45)
	dis.set_border_width_all(3); dis.set_corner_radius_all(12)
	btn.add_theme_stylebox_override("disabled", dis)
	btn.add_theme_color_override("font_disabled_color", C_PARCH_D.darkened(0.25))

	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = C_FOREST.lightened(0.10); h.border_color = C_GOLD
	btn.add_theme_stylebox_override("hover", h)
	var pr := n.duplicate() as StyleBoxFlat
	pr.bg_color = C_FOREST.darkened(0.45)
	btn.add_theme_stylebox_override("pressed", pr)
	btn.add_theme_stylebox_override("focus", StyleBoxFlat.new())
	btn.add_theme_color_override("font_color",       C_GOLD_S)
	btn.add_theme_color_override("font_hover_color", C_GOLD)
	btn.add_theme_color_override("font_shadow_color", Color(0,0,0,0.9))
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
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("focus", StyleBoxFlat.new())
	btn.add_theme_color_override("font_color",       C_GOLD)
	btn.add_theme_color_override("font_hover_color", C_GOLD_S)
	btn.add_theme_color_override("font_shadow_color", Color(0,0,0,0.92))
	btn.add_theme_constant_override("shadow_offset_x", 2)
	btn.add_theme_constant_override("shadow_offset_y", 3)
