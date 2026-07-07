class_name CharacterEditPopup
extends Control

# Popup "Character Scene": ανοίγει από το CharacterSelect.gd όταν ο παίκτης
# επιλέγει έναν χαρακτήρα και πατάει "EDIT". Δείχνει το avatar + στατιστικά
# του χαρακτήρα (πάνω) και τις 4 θέσεις εξοπλισμού (κάτω), πατήσιμες για
# αλλαγή πανοπλίας. Τα δεδομένα εξοπλισμού/κατοχής έρχονται από το
# Inventory autoload (Scripts/inventory_data.gd) — δεν κρατάει δικό του
# αντίγραφο, ώστε να μένει συγχρονισμένο με το ShopPopup/InventoryPopup.

const AVATAR_BASE := preload("res://Εικόνες/avatar.png")

# Τα avatar.png/helmet.png/κ.λπ. είναι "προϊοντικές" φωτογραφίες αντικειμένων
# σε δικό τους καμβά 677×369 — ΔΕΝ είναι ήδη ευθυγραμμισμένα στο σκελετό του
# avatar. Το AVATAR_CROP είναι το πραγματικό περιεχόμενο (χωρίς το διάφανο
# περιθώριο) του avatar.png, υπολογισμένο από το bounding box του alpha
# channel· χρησιμοποιείται ως AtlasTexture.region ώστε να εμφανίζεται
# "γεμάτο" μέσα στο πλαίσιο αντί να κάθεται μικρό στη μέση.
const AVATAR_CROP := Rect2(269, 16, 139, 337)

# Στόχοι (Rect2) για κάθε equip-layer, σε ΤΟΠΙΚΕΣ συντεταγμένες μέσα στο
# πλαίσιο avatar (0,0 = πάνω-αριστερά της περιοχής avatar, ΜΕΤΑ το εσωτερικό
# περιθώριο του πλαισίου — δες art_pos στο _build_portrait_and_stats).
# Υπολογίστηκαν χειροκίνητα με βάση το πού πέφτει το κεφάλι/κορμός/πόδια
# του avatar.png όταν αυτό εμφανίζεται ολόκληρο (KEEP_ASPECT_CENTERED) μέσα
# στο ίδιο 348×428 πλαίσιο — βλ. σχόλιο στο _ready() για τις τιμές.
# Γεμίζεται στο _ready() (όχι const) μαζί με το _avatar_layer_order, ώστε να
# διαβάζει με ασφάλεια τα SLOT_* από το Inventory autoload.
var _avatar_layer_order: Array[String] = []
var _avatar_layer_targets: Dictionary = {}

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
var _slot_icons: Dictionary = {}     # slot -> item-image TextureRect (κάτω από το όνομα στην κάρτα)
var _avatar_layers: Dictionary = {}  # slot -> overlay TextureRect
var _picker: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_avatar_layer_order = [
		Inventory.SLOT_LEGS,
		Inventory.SLOT_BOOTS,
		Inventory.SLOT_CHEST,
		Inventory.SLOT_HELMET,
		Inventory.SLOT_WEAPON,
	]
	# Θέση/μέγεθος κάθε layer μέσα στο 348×428 πλαίσιο avatar, ώστε να
	# προσγειώνεται πάνω στο αντίστοιχο κομμάτι του σώματος (κεφάλι/κορμός/
	# πόδια) αντί να καλύπτει ολόκληρο το avatar. Το όπλο ξεχωρίζει καθώς
	# κρατιέται δίπλα στο σώμα, όχι πάνω του.
	_avatar_layer_targets = {
		Inventory.SLOT_HELMET: Rect2(100, 0,  30, 73),
		Inventory.SLOT_CHEST:  Rect2(100,  60, 159, 141),
		Inventory.SLOT_LEGS:   Rect2(112, 193, 124, 116),
		Inventory.SLOT_BOOTS:  Rect2(86,  291, 177, 137),
		Inventory.SLOT_WEAPON: Rect2(150, 30, 198, 358),
	}
	_build()
	Inventory.equipment_changed.connect(func(_slot, _id):
		_refresh_slots()
		_refresh_avatar()
		_refresh_stats()
	)

## Δημόσια μέθοδος ανοίγματος — καλείται από CharacterSelect.gd με το
## Dictionary του επιλεγμένου χαρακτήρα (ένα στοιχείο του CHAR_DATA).
func open_character(char_data: Dictionary) -> void:
	_data = char_data
	_refresh_header()
	_refresh_stats()
	_refresh_slots()
	_refresh_avatar()
	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.30)

func _close() -> void:
	_close_picker()
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

	var base_atlas := AtlasTexture.new()
	base_atlas.atlas  = AVATAR_BASE
	base_atlas.region = AVATAR_CROP

	var base := TextureRect.new()
	base.texture      = base_atlas
	base.position     = art_pos
	base.size         = art_size
	base.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pframe.add_child(base)

	# Ένα layer ανά equip slot, τοποθετημένο στη σωστή περιοχή του σώματος
	# (_avatar_layer_targets) αντί να γεμίζει όλο το πλαίσιο. Η τιμή του
	# texture (με το σωστό crop) ανανεώνεται στο _refresh_avatar() ανάλογα
	# με το τι είναι εξοπλισμένο (Inventory.get_equipped(slot)).
	for slot in _avatar_layer_order:
		var target: Rect2 = _avatar_layer_targets[slot]
		var layer := TextureRect.new()
		layer.position     = art_pos + target.position
		layer.size         = target.size
		layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pframe.add_child(layer)
		_avatar_layers[slot] = layer

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

## Ενημερώνει κάθε equip-layer του avatar με βάση το τι είναι εξοπλισμένο
## αυτή τη στιγμή στο αντίστοιχο slot. Αν το εξοπλισμένο item δεν έχει δικό
## του "avatar_overlay" (δεν έχει ετοιμαστεί ακόμα art γι' αυτό), το layer
## μένει κενό — φαίνεται απλά το βασικό σώμα από κάτω.
func _refresh_avatar() -> void:
	for slot in _avatar_layers:
		var layer: TextureRect = _avatar_layers[slot]
		layer.texture = Inventory.get_item_texture(Inventory.get_equipped(slot))

# ── Κάτω μέρος: 4 θέσεις εξοπλισμού ─────────────────────────────────────────
func _build_equipment() -> void:
	const GRID_Y := 712.0

	_lbl(self, "ΕΞΟΠΛΙΣΜΟΣ", Vector2(0, GRID_Y), Vector2(W, 40),
		28, C_GOLD_S, HORIZONTAL_ALIGNMENT_CENTER, Color(0,0,0,0.9), 1, 2)

	const CARD_Y := GRID_Y + 56.0
	const CARD_W := 490.0
	const CARD_H := 300.0
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
	const TITLE_Y := 1412.0
	const CARD_Y  := TITLE_Y + 44.0
	const CARD_H  := 220.0

	_lbl(self, "ΟΠΛΟ", Vector2(0, TITLE_Y), Vector2(W, 36),
		28, C_GOLD_S, HORIZONTAL_ALIGNMENT_CENTER, Color(0,0,0,0.9), 1, 2)

	_make_slot_card(Inventory.SLOT_WEAPON, 40.0, CARD_Y, W - 80.0, CARD_H)

## Κάρτα θέσης εξοπλισμού: όνομα θέσης + όνομα αντικειμένου από πάνω, και η
## εικόνα του αντικειμένου μεγάλη και κεντραρισμένη από κάτω (χωρίς μικρό
## πλαίσιο-εικονίδιο). Όλα τα παιδιά εδώ γίνονται add_child ΤΟΥ card, άρα οι
## θέσεις τους είναι πάντα ΤΟΠΙΚΕΣ ως προς το card (όχι ως προς το self).
func _make_slot_card(slot: String, x: float, y: float, w: float, h: float) -> void:
	var card := _add_panel(self, Vector2(x, y), Vector2(w, h), C_DARK, C_BRONZE, 3, 10)

	_lbl(card, str(Inventory.SLOT_LABELS.get(slot, slot)), Vector2(0, 14), Vector2(w, 28),
		20, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)

	var name_lbl := _lbl(card, "— Κενό —", Vector2(10, 44), Vector2(w - 20, 32),
		22, C_BONE, HORIZONTAL_ALIGNMENT_CENTER)
	_slot_name_labels[slot] = name_lbl

	const HINT_H := 26.0
	var image_y: float = 84.0
	var image_h: float = h - image_y - HINT_H - 10.0
	var icon := TextureRect.new()
	icon.position     = Vector2(24, image_y)
	icon.size         = Vector2(w - 48, image_h)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon)
	_slot_icons[slot] = icon

	_lbl(card, "πάτα για αλλαγή", Vector2(0, h - HINT_H - 6), Vector2(w, HINT_H),
		15, C_BONE_D, HORIZONTAL_ALIGNMENT_CENTER)

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
	btn.pressed.connect(func(): _open_picker(slot))

func _refresh_slots() -> void:
	for slot in _slot_name_labels:
		var equipped: Dictionary = Inventory.get_equipped(slot)
		(_slot_name_labels[slot] as Label).text = str(equipped.get("name", "— Κενό —"))
		var icon: TextureRect = _slot_icons.get(slot)
		if icon:
			# Ίδια πηγή εικόνας (Inventory.get_item_texture) με το avatar
			# από πάνω και με το Αποθήκη/InventoryPopup — bounded Rect2 στον
			# καλούντα (STRETCH_KEEP_ASPECT_CENTERED), δεν ξεχειλίζει ποτέ.
			icon.texture = Inventory.get_item_texture(equipped)

# ═══════════════════════════════════════════════════════════════
# ΕΠΙΛΟΓΕΑΣ ΕΞΟΠΛΙΣΜΟΥ (picker) — λίστα owned items για μια θέση
# ═══════════════════════════════════════════════════════════════
func _open_picker(slot: String) -> void:
	_close_picker()

	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_picker = overlay

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_picker()
	)

	const PW := 760.0
	var options: Array[Dictionary] = Inventory.get_owned_by_slot(slot)
	var ph: float = 160.0 + (options.size() + 1) * 96.0
	ph = min(ph, H - 200.0)
	var px := (W - PW) / 2.0
	var py := (H - ph) / 2.0

	var panel := _add_panel(overlay, Vector2(px, py), Vector2(PW, ph), C_DARK, C_GOLD, 4, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	_lbl(panel, "Επίλεξε: %s" % str(Inventory.SLOT_LABELS.get(slot, slot)),
		Vector2(0, 20), Vector2(PW, 44), 28, C_GOLD_S, HORIZONTAL_ALIGNMENT_CENTER)
	_cr_on(panel, Vector2(30, 70), Vector2(PW - 60, 2), C_GOLD_D)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 84)
	scroll.size     = Vector2(PW - 40, ph - 104)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)

	col.add_child(_make_picker_row("— Κενό —", "", Inventory.get_equipped(slot).is_empty()))
	for item in options:
		var equipped_now: bool = Inventory.get_equipped(slot).get("id", "") == item.get("id", "")
		col.add_child(_make_picker_row(str(item["name"]), str(item["id"]), equipped_now))

	for child in col.get_children():
		var btn := child as Button
		if btn:
			btn.pressed.connect(func():
				_equip_from_picker(slot, btn.get_meta("item_id"))
			)

func _make_picker_row(label: String, item_id: String, equipped_now: bool) -> Button:
	var btn := Button.new()
	btn.text = ("★  " if equipped_now else "") + label
	btn.custom_minimum_size = Vector2(0, 84)
	btn.set_meta("item_id", item_id)
	_style_iron(btn, equipped_now)
	btn.add_theme_font_size_override("font_size", 26)
	return btn

func _equip_from_picker(slot: String, item_id: String) -> void:
	Inventory.equip(slot, item_id)
	_close_picker()

func _close_picker() -> void:
	if is_instance_valid(_picker):
		_picker.queue_free()
	_picker = null

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
