class_name CharacterEditPopup
extends Control

# Popup "Character Scene": ανοίγει από το CharacterSelect.gd όταν ο παίκτης
# επιλέγει έναν χαρακτήρα και πατάει "EDIT". Δείχνει το avatar + στατιστικά
# του χαρακτήρα (πάνω) και τις 4 θέσεις εξοπλισμού (κάτω), πατήσιμες για
# αλλαγή πανοπλίας. Τα δεδομένα εξοπλισμού/κατοχής έρχονται από το
# Inventory autoload (Scripts/inventory_data.gd) — δεν κρατάει δικό του
# αντίγραφο, ώστε να μένει συγχρονισμένο με το ShopPopup/InventoryPopup.

# Ο ήρωας που φαίνεται εδώ είναι ΠΑΝΤΑ ο βασικός ήρωας του παίκτη (μόνο αυτός
# είναι ξεκλείδωτος/επεξεργάσιμος). Η εικόνα του (boy.png/girl.png ανάλογα με το
# φύλο, κομμένη στο περιεχόμενο) έρχεται κεντρικά από GameData.get_hero_texture —
# το παλιό avatar.png ΔΕΝ χρησιμοποιείται πλέον. Ο εξοπλισμός αλλάζει από τις
# κάρτες πιο κάτω και ενημερώνει τα στατιστικά· ΔΕΝ επικαλύπτεται πάνω στη φιγούρα
# (τα PNG του εξοπλισμού είναι σε άλλο στυλ/αναλογίες από τη φιγούρα του ήρωα).

# ── Παλέτα (ίδιο ύφος με CharacterSelect.gd) ────────────────────────────────
const C0       := Color(0, 0, 0, 0)
const C_BG     := Color(0.032, 0.022, 0.010, 0.82)
const C_DARK   := Color(0.055, 0.038, 0.018)
const C_MID    := Color(0.095, 0.068, 0.035)
const C_IRON   := Color(0.185, 0.168, 0.140)
const C_IRON_L := Color(0.265, 0.242, 0.208)
const C_SILVER := Color(0.572, 0.548, 0.510)
const C_BRONZE := Color(0.435, 0.308, 0.072)
const C_GOLD   := Color(0.820, 0.645, 0.118)
const C_GOLD_D := Color(0.268, 0.192, 0.032)
const C_CRIMSON:= Color(0.455, 0.030, 0.030)
const C_BONE   := Color(0.868, 0.830, 0.685)
const C_BONE_D := Color(0.415, 0.378, 0.290)
const C_GOLD_S := Color(1.000, 0.920, 0.560)

const W := 1080.0
const H := 1920.0

var _data: Dictionary = {}
var _stat_labels: Dictionary = {}    # stat name -> value Label
var _slot_name_labels: Dictionary = {} # slot -> equipped-name Label
var _slot_stat_labels: Dictionary = {} # slot -> equipped stat-bonus Label ("Άμυνα +12")
var _slot_icons: Dictionary = {}     # slot -> item-image TextureRect (κάτω από το όνομα στην κάρτα)
# Αγγλικές ετικέτες κατηγορίας ΜΟΝΟ για την κορυφή της κάρτας εξοπλισμού
# (ζητήθηκε ρητά "Helmet"/"Chest Armor"/"Pants"/"Boots"/"Weapon") — δεν
# αντικαθιστά το Inventory.SLOT_LABELS (Ελληνικά), που εξακολουθεί να
# χρησιμοποιείται όπου αλλού χρειάζεται. Γεμίζεται στο _ready() (όχι const)
# ώστε να διαβάζει με ασφάλεια τα SLOT_* από το Inventory autoload.
var _slot_display_label: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_slot_display_label = {
		Inventory.SLOT_HELMET: "Helmet",
		Inventory.SLOT_CHEST:  "Chest Armor",
		Inventory.SLOT_LEGS:   "Pants",
		Inventory.SLOT_BOOTS:  "Boots",
		Inventory.SLOT_WEAPON: "Weapon",
	}
	_build()
	var _do_refresh := func():
		_refresh_slots()
		_refresh_stats()
	Inventory.equipment_changed.connect(func(_slot, _id): _do_refresh.call())
	# ΚΑΙ σε upgrade/sell (WeaponInventory/ArmorInventory.changed) — ένα
	# upgrade στο ήδη εξοπλισμένο αντικείμενο ΔΕΝ αλλάζει ποιο item_id είναι
	# εξοπλισμένο (άρα equipment_changed δεν πυροδοτείται), αλλά αλλάζει την
	# ΤΙΜΗ του στατιστικού που πρέπει να φανεί εδώ (π.χ. αναβάθμισε κάποιος
	# το εξοπλισμένο του όπλο μέσα από το κλειδωμένο Inventory panel και
	# επέστρεψε — η νέα Επίθεση πρέπει να φαίνεται αμέσως, όχι στην επόμενη
	# αλλαγή εξοπλισμού). Ασφαλές να τρέχει άσχετα με ποιο item άλλαξε: το
	# refresh απλά ξαναδιαβάζει τις τρέχουσες τιμές, καμία υπόθεση δεν κάνει.
	WeaponInventory.changed.connect(func(): _do_refresh.call())
	ArmorInventory.changed.connect(func(): _do_refresh.call())

## Δημόσια μέθοδος ανοίγματος — καλείται από CharacterSelect.gd με το
## Dictionary του επιλεγμένου χαρακτήρα (ένα στοιχείο του CHAR_DATA).
func open_character(char_data: Dictionary) -> void:
	_data = char_data
	_refresh_header()
	_refresh_stats()
	_refresh_slots()
	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.30)

func _close() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func(): visible = false)

# ═══════════════════════════════════════════════════════════════
# ΚΑΤΑΣΚΕΥΗ UI
# ═══════════════════════════════════════════════════════════════
var _name_label: Label
var _class_label: Label

func _build() -> void:
	_build_dim()
	_build_header()
	_build_portrait_and_stats()
	_build_equipment()
	_build_weapon()
	_build_back_button()

func _build_dim() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = C_BG
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

func _build_header() -> void:
	const HDR_H := 190.0
	_add_panel(self, Vector2(0, 0), Vector2(W, HDR_H), Color(0.048, 0.032, 0.015, 0.97), C_BRONZE, 0, 0)
	_cr(Vector2(0, HDR_H - 4), Vector2(W, 4), C_GOLD)
	_cr(Vector2(0, HDR_H),     Vector2(W, 2), C_CRIMSON)

	var back := Button.new()
	back.text     = "◄  ΠΙΣΩ"
	back.position = Vector2(30, 60)
	back.size     = Vector2(200, 84)
	_style_iron(back)
	back.add_theme_font_size_override("font_size", 30)
	add_child(back)
	back.pressed.connect(_close)

	_name_label = _lbl(self, "", Vector2(0, 34), Vector2(W, 60),
		42, C_BONE, HORIZONTAL_ALIGNMENT_CENTER, Color(0,0,0,0.9), 2, 3)
	_class_label = _lbl(self, "", Vector2(0, 94), Vector2(W, 40),
		24, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)

func _refresh_header() -> void:
	_name_label.text  = str(_data.get("name", ""))
	_class_label.text = str(_data.get("class", ""))

# ── Πάνω μέρος: avatar (πολλαπλά equip-layers) + στατιστικά ────────────────
func _build_portrait_and_stats() -> void:
	const TOP_Y := 210.0
	const SEC_H := 460.0

	# Πλαίσιο avatar
	var pframe := _add_panel(self, Vector2(40, TOP_Y), Vector2(380, SEC_H), C_DARK, C_GOLD_D, 4, 12)
	# ΠΡΟΣΟΧΗ: όλα τα παρακάτω TextureRect γίνονται add_child ΤΟΥ pframe, άρα
	# το .position τους είναι ΤΟΠΙΚΟ ως προς το pframe (όχι ως προς το self).
	# Το εσωτερικό περιθώριο είναι 16px — γι' αυτό ξεκινάει από (16,16) και
	# όχι από την απόλυτη θέση του pframe μέσα στο popup.
	var art_pos  := Vector2(16, 16)
	var art_size := Vector2(380 - 32, SEC_H - 32)

	# Η φιγούρα του βασικού ήρωα (boy.png/girl.png ανάλογα με το φύλο, κομμένη),
	# από την κοινή πηγή GameData.get_hero_texture — ίδια εικόνα με τους
	# Χαρακτήρες και τη μάχη με τη Morgana. EXPAND_IGNORE_SIZE ώστε το .size να
	# μην αγνοηθεί (αλλιώς το Godot θέτει minimum_size = φυσικό μέγεθος υφής και
	# το TextureRect ξεχειλίζει πέρα από το πλαίσιό του).
	var base := TextureRect.new()
	base.texture      = GameData.get_hero_texture()
	base.position     = art_pos
	base.size         = art_size
	base.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	base.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pframe.add_child(base)

	# Πλαίσιο στατιστικών
	var sframe := _add_panel(self, Vector2(440, TOP_Y), Vector2(600, SEC_H), C_DARK, C_GOLD_D, 4, 12)
	_lbl(sframe, "ΣΤΑΤΙΣΤΙΚΑ", Vector2(0, 16), Vector2(600, 40),
		26, C_GOLD_S, HORIZONTAL_ALIGNMENT_CENTER)
	_cr_on(sframe, Vector2(30, 62), Vector2(540, 2), C_GOLD_D)

	const STAT_ORDER := ["Άμυνα", "Επίθεση", "Ταχύτητα", "Εξυπνάδα", "Δύναμη"]
	var row_y := 82.0
	var row_h := (SEC_H - 82.0 - 20.0) / STAT_ORDER.size()
	for stat_name in STAT_ORDER:
		_lbl(sframe, stat_name, Vector2(36, row_y), Vector2(360, row_h),
			26, C_BONE, HORIZONTAL_ALIGNMENT_LEFT)
		var val := _lbl(sframe, "0", Vector2(600 - 160, row_y), Vector2(120, row_h),
			28, C_GOLD, HORIZONTAL_ALIGNMENT_RIGHT, Color(0,0,0,0.9), 1, 2)
		_stat_labels[stat_name] = val
		row_y += row_h

## Κάθε στατιστικό = βάση χαρακτήρα (πάντα 0 προς το παρόν, βλ.
## CharacterSelect.CHAR_DATA) + άθροισμα του "stat_bonus" απ' όλα τα
## εξοπλισμένα αντικείμενα (Inventory.get_equipped_stat_bonus — π.χ. η
## Επίθεση ανεβαίνει μόνο από το εξοπλισμένο όπλο, η Άμυνα από κάθε κομμάτι
## πανοπλίας) + το ΜΟΝΙΜΟ bonus από ανταλλαγές Μαγικών Σφαιρών στη Νεράιδα
## (GameData.get_stat_bonus — βλ. Scripts/fairy_popup.gd). Πάντα μέσα σε
## 0-20, ό,τι κι αν προκύψει αθροιστικά.
func _refresh_stats() -> void:
	var base_stats: Dictionary = _data.get("stats", {})
	for stat_name in _stat_labels:
		var base: int = int(base_stats.get(stat_name, 0))
		var bonus: int = Inventory.get_equipped_stat_bonus(stat_name) + GameData.get_stat_bonus(stat_name)
		var total: int = clampi(base + bonus, 0, 20)
		(_stat_labels[stat_name] as Label).text = str(total)

# ── Κάτω μέρος: 4 θέσεις εξοπλισμού ─────────────────────────────────────────
func _build_equipment() -> void:
	const GRID_Y := 712.0

	_lbl(self, "ΕΞΟΠΛΙΣΜΟΣ", Vector2(0, GRID_Y), Vector2(W, 40),
		28, C_GOLD_S, HORIZONTAL_ALIGNMENT_CENTER, Color(0,0,0,0.9), 1, 2)

	const CARD_Y := GRID_Y + 56.0
	const CARD_W := 490.0
	const CARD_H := 320.0
	const GAP := 20.0

	var order := Inventory.SLOTS
	for i in order.size():
		var slot: String = order[i]
		var col := i % 2
		var row := int(i / 2.0)
		var x := 40.0 + col * (CARD_W + GAP)
		var y := CARD_Y + row * (CARD_H + GAP)
		_make_slot_card(slot, x, y, CARD_W, CARD_H)

# ── Κάτω μέρος: επιλογή όπλου (ξεχωριστό section, κάτω από την πανοπλία) ────
func _build_weapon() -> void:
	const TITLE_Y := 1458.0
	const CARD_Y  := TITLE_Y + 44.0
	const CARD_H  := 250.0

	_lbl(self, "ΟΠΛΟ", Vector2(0, TITLE_Y), Vector2(W, 36),
		28, C_GOLD_S, HORIZONTAL_ALIGNMENT_CENTER, Color(0,0,0,0.9), 1, 2)

	_make_slot_card(Inventory.SLOT_WEAPON, 40.0, CARD_Y, W - 80.0, CARD_H)

## Κάρτα θέσης εξοπλισμού — πατήσιμη: ανοίγει το ΙΔΙΟ Inventory panel
## (InventoryPopup), κλειδωμένο στη σχετική κατηγορία, βλ. _on_slot_tapped.
## Καμία δεύτερη υλοποίηση επιλογέα εδώ πια — το equip/unequip/upgrade/sell
## γίνονται πάντα μέσα από το πραγματικό Inventory UI. Σταθερή κάθετη διάταξη:
##   1. πάνω μέρος — όνομα κατηγορίας (πάντα, π.χ. "Helmet"/"Weapon")
##   2. κέντρο     — εικόνα του επιλεγμένου αντικειμένου
##   3. όνομα      — το πραγματικό όνομα του επιλεγμένου αντικειμένου (ή
##                   "Not Selected" αν η θέση είναι άδεια)
##   4. στατιστικό — π.χ. "Άμυνα +12"/"Επίθεση +25" (κενό αν άδεια θέση)
## Όλα τα παιδιά εδώ γίνονται add_child ΤΟΥ card, άρα οι θέσεις τους είναι
## πάντα ΤΟΠΙΚΕΣ ως προς το card (όχι ως προς το self).
func _make_slot_card(slot: String, x: float, y: float, w: float, h: float) -> void:
	var card := _add_panel(self, Vector2(x, y), Vector2(w, h), C_DARK, C_BRONZE, 3, 10)

	_lbl(card, str(_slot_display_label.get(slot, slot)), Vector2(0, 14), Vector2(w, 28),
		20, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)

	const NAME_H := 32.0
	const STAT_H := 26.0
	const BOTTOM_PAD := 14.0
	var image_y: float = 48.0
	var image_h: float = h - image_y - NAME_H - STAT_H - BOTTOM_PAD
	var icon := TextureRect.new()
	icon.position     = Vector2(24, image_y)
	icon.size         = Vector2(w - 48, image_h)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# EXPAND_IGNORE_SIZE — βλ. αναλυτικό σχόλιο στο _build_portrait_and_stats:
	# χωρίς αυτό το TextureRect μεγαλώνει όσο η ίδια η εικόνα αντί να μένει
	# μέσα στο πλαίσιο που του ορίζουμε.
	icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon)
	_slot_icons[slot] = icon

	var name_lbl := _lbl(card, "Not Selected", Vector2(10, image_y + image_h + 4), Vector2(w - 20, NAME_H),
		22, C_BONE, HORIZONTAL_ALIGNMENT_CENTER)
	_slot_name_labels[slot] = name_lbl

	# Μόνο το στατιστικό εδώ — καμία ένδειξη Selected/Not Selected πια σε
	# αυτό το σημείο (αυτές ζουν αποκλειστικά στο κουμπί του Inventory).
	var stat_lbl := _lbl(card, "", Vector2(10, image_y + image_h + 4 + NAME_H), Vector2(w - 20, STAT_H),
		20, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_slot_stat_labels[slot] = stat_lbl

	var btn := Button.new()
	btn.position = Vector2(0, 0)
	btn.size     = Vector2(w, h)
	var ts := _sb(C0, C0, 0, 10)
	var hs := _sb(Color(0.82, 0.65, 0.12, 0.10), C0, 0, 10)
	btn.add_theme_stylebox_override("normal",  ts)
	btn.add_theme_stylebox_override("hover",   hs)
	btn.add_theme_stylebox_override("pressed", ts)
	btn.add_theme_stylebox_override("focus",   ts)
	card.add_child(btn)
	btn.pressed.connect(func(): _on_slot_tapped(slot))

## Ανοίγει το ΙΔΙΟ InventoryPopup (εντοπίζεται μέσω group, βλ.
## inventory_popup.gd::_ready — είναι σε άλλο κλαδί του scene tree, παιδί
## του Area1 root, όχι του CharacterSelect/CharacterEditPopup) κλειδωμένο
## στη σχετική κατηγορία. Το Character Editor κρύβεται όσο είναι ανοιχτό —
## βλ. _resume_after_inventory για την επιστροφή.
func _on_slot_tapped(slot: String) -> void:
	var inv := get_tree().get_first_node_in_group("inventory_popup")
	if inv == null:
		return
	visible = false
	if slot == Inventory.SLOT_WEAPON:
		var equipped: Dictionary = Inventory.get_equipped(slot)
		var preferred := ""
		if not equipped.is_empty():
			preferred = WeaponInventory.get_category(str(equipped.get("id", "")))
		inv.call("open_locked_to_weapons", self, preferred)
	else:
		inv.call("open_locked_to_armor_category", str(Inventory.SLOT_LABELS.get(slot, slot)), self)

## Καλείται από το InventoryPopup (μέσω close_popup -> _return_target) όταν
## ο χρήστης πατήσει Χ εκεί — γυρνάει ΑΚΡΙΒΩΣ στο Character Editor. Καμία
## χειροκίνητη ανανέωση δεν χρειάζεται εδώ: το _refresh_slots/_refresh_stats
## τρέχουν ήδη ΣΥΝΕΧΕΙΑ στο παρασκήνιο σε κάθε
## Inventory.equipment_changed (βλ. _ready), ό,τι κι αν έγινε (equip/
## unequip/sell/upgrade) όσο ήταν κρυμμένο το Character Editor.
func _resume_after_inventory() -> void:
	visible = true

func _refresh_slots() -> void:
	for slot in _slot_name_labels:
		var equipped: Dictionary = Inventory.get_equipped(slot)
		(_slot_name_labels[slot] as Label).text = str(equipped.get("name", "Not Selected"))
		var stat_lbl: Label = _slot_stat_labels.get(slot)
		if stat_lbl:
			var bonus: Dictionary = equipped.get("stat_bonus", {})
			if bonus.is_empty():
				stat_lbl.text = ""
			else:
				var stat_name: String = bonus.keys()[0]
				stat_lbl.text = "%s +%d" % [stat_name, int(bonus[stat_name])]
		var icon: TextureRect = _slot_icons.get(slot)
		if icon:
			# Ίδια πηγή εικόνας (Inventory.get_item_texture) με το avatar
			# από πάνω και με το Αποθήκη/InventoryPopup — bounded Rect2 στον
			# καλούντα (STRETCH_KEEP_ASPECT_CENTERED), δεν ξεχειλίζει ποτέ.
			icon.texture = Inventory.get_item_texture(equipped)

# ── Κουμπί Πίσω (κάτω, ίδιο ύφος με τα υπόλοιπα popups) ────────────────────
func _build_back_button() -> void:
	var btn := Button.new()
	btn.text     = "◄   Πίσω στους Χαρακτήρες"
	btn.position = Vector2(W/2 - 220, H - 138)
	btn.size     = Vector2(440, 84)
	btn.add_theme_font_size_override("font_size", 28)
	_style_iron(btn, true)
	add_child(btn)
	btn.pressed.connect(_close)

# ═══════════════════════════════════════════════════════════════
# ΒΟΗΘΗΤΙΚΕΣ ΣΥΝΑΡΤΗΣΕΙΣ
# ═══════════════════════════════════════════════════════════════
func _sb(bg: Color, border: Color, bw: int, cr: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(cr)
	return s

func _add_panel(parent: Control, pos: Vector2, sz: Vector2, bg: Color, border: Color, bw: int, cr: int) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size     = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _sb(bg, border, bw, cr))
	parent.add_child(p)
	return p

func _cr(pos: Vector2, sz: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.position = pos
	r.size     = sz
	r.color    = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)

func _cr_on(parent: Control, pos: Vector2, sz: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.position = pos
	r.size     = sz
	r.color    = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)

func _lbl(parent: Control, text: String, pos: Vector2, sz: Vector2, font_sz: int,
		  col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
		  shadow: Color = Color(0,0,0,0), sx: int = 0, sy: int = 0) -> Label:
	var l := Label.new()
	l.text     = text
	l.position = pos
	l.size     = sz
	l.horizontal_alignment = align
	l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_sz)
	l.add_theme_color_override("font_color", col)
	if shadow.a > 0:
		l.add_theme_color_override("font_shadow_color", shadow)
		l.add_theme_constant_override("shadow_offset_x", sx)
		l.add_theme_constant_override("shadow_offset_y", sy)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _style_iron(btn: Button, golden: bool = false) -> void:
	var trim  := C_GOLD if golden else C_SILVER
	var fcol  := C_GOLD if golden else C_BONE

	var n := _sb(C_IRON, trim.darkened(0.22), 4, 6)
	n.shadow_color = Color(0,0,0,0.72)
	n.shadow_size  = 6
	btn.add_theme_stylebox_override("normal", n)

	var h := _sb(C_IRON_L, trim, 5, 6)
	h.shadow_color = trim.lightened(0.08)
	h.shadow_size  = 12
	btn.add_theme_stylebox_override("hover", h)

	btn.add_theme_stylebox_override("pressed", _sb(Color(0.06, 0.04, 0.02), trim.darkened(0.28), 3, 6))
	btn.add_theme_stylebox_override("focus", _sb(C0, C0, 0, 0))

	btn.add_theme_color_override("font_color",         fcol)
	btn.add_theme_color_override("font_hover_color",   C_GOLD if golden else C_SILVER.lightened(0.18))
	btn.add_theme_color_override("font_pressed_color", fcol.darkened(0.32))
	btn.add_theme_color_override("font_shadow_color",  Color(0,0,0,0.92))
	btn.add_theme_constant_override("shadow_offset_x", 2)
	btn.add_theme_constant_override("shadow_offset_y", 3)
