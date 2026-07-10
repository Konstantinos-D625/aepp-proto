extends Control

# Popup "Κατάστημα": αγορά όπλων ΚΑΙ πανοπλιών. Και τα δύο έρχονται δυναμικά
# από τα WeaponInventory/ArmorInventory autoloads (Scripts/weapon_inventory.gd,
# Scripts/armor_inventory.gd) — ίδια αρχιτεκτονική και για τα δύο (κοινή βάση
# Scripts/equipment_catalog.gd). Κάθε κατηγορία έχει ξεχωριστά αγοράσιμα
# αντικείμενα (ένα ανά old_level). Το Shop ΜΟΝΟ πουλάει· η αναβάθμιση/πώληση
# γίνεται αποκλειστικά στο Inventory.

# ── Παλέτα (iron/gold — ίδιο ύφος με CharacterSelect) ─────────────────────
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

const W := 1080.0
const H := 1920.0
# Ύψη ρυθμισμένα για mobile (Android, portrait): κάθε πατήσιμο στοιχείο
# (tabs, κατηγορίες, ΑΓΟΡΑ) έχει ύψος τουλάχιστον ~72-90px ώστε να πατιέται
# άνετα με δάχτυλο — όχι μόνο με ποντίκι.
const HDR_H := 240.0
const TAB_H := 110.0
const CAT_BAR_H := 92.0

var _category := "weapons"

# Θυμάται ξεχωριστά ποια υπο-κατηγορία ήταν επιλεγμένη σε κάθε καρτέλα.
# Γεμίζεται στο _ready() (όχι εδώ ως field initializer) — τα field
# initializers μπορούν να αξιολογηθούν από το GDScript σε context όπου τα
# autoloads δεν είναι ακόμα διαθέσιμα, οδηγώντας σε άδειο WeaponInventory
# .categories/ArmorInventory.categories και "out of bounds" σε [0].
var _selected_category: Dictionary = {}

var _currency_strip: Control
var _currency_labels := {}   # currency name -> Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _tab_weapons: Button
var _tab_armor: Button
var _cat_bar: ScrollContainer
var _cat_buttons: Dictionary = {}   # category -> Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_selected_category = {
		"weapons": WeaponInventory.categories[0],
		"armor": ArmorInventory.categories[0],
	}
	_build()
	Currency.changed.connect(_update_currency_labels)
	WeaponInventory.changed.connect(_on_equipment_changed)
	ArmorInventory.changed.connect(_on_equipment_changed)

func show_popup() -> void:
	visible = true
	_update_currency_labels()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.30)

func _close() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func(): visible = false)

func _current_catalog() -> EquipmentCatalog:
	if _category == "weapons":
		return WeaponInventory
	return ArmorInventory

# ═══════════════════════════════════════════════════════════════
# ΚΑΤΑΣΚΕΥΗ UI
# ═══════════════════════════════════════════════════════════════
func _build() -> void:
	_build_dim()
	_build_header()
	_build_tabs()
	_build_category_bar()
	_build_grid_area()
	_layout_grid_area()
	_refresh_grid()

func _build_dim() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = C_BG
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close()
	)
	add_child(dim)

func _build_header() -> void:
	var hdr := Panel.new()
	hdr.position = Vector2(0, 0)
	hdr.size     = Vector2(W, HDR_H)
	hdr.add_theme_stylebox_override("panel", _sb(Color(0.048, 0.032, 0.015, 0.97), C_BRONZE, 0))
	add_child(hdr)
	_cr(hdr, Vector2(0, HDR_H - 4), Vector2(W, 4), C_GOLD)
	_cr(hdr, Vector2(0, HDR_H),     Vector2(W, 2), C_CRIMSON)

	_lbl(hdr, "⚔  ΟΠΛΟΠΩΛΕΙΟ  🛡", Vector2(0, 24), Vector2(W, 70),
		 48, C_BONE, HORIZONTAL_ALIGNMENT_CENTER, Color(0,0,0,0.92), 3, 4)

	# Κουμπί κλεισίματος — 84×84, μέγεθος δαχτύλου
	var close_btn := Button.new()
	close_btn.text     = "✕"
	close_btn.position = Vector2(20, 18)
	close_btn.size     = Vector2(84, 84)
	_style_iron(close_btn)
	close_btn.add_theme_font_size_override("font_size", 40)
	hdr.add_child(close_btn)
	close_btn.pressed.connect(_close)

	_build_currency_strip(hdr)

# Μόνο τα υλικά που αφορούν το Shop (η αγορά γίνεται αποκλειστικά σε Χρυσό —
# βλ. EquipmentCatalog.buy) — όχι Σφαίρες/Κλειδιά, που δεν χρησιμοποιούνται
# πουθενά εδώ. Ίδια σχετική σειρά με το Currency.ORDER.
const STRIP_CURRENCIES: Array[String] = ["Χρυσό", "Βαμβάκι", "Σίδερο"]

func _build_currency_strip(hdr: Control) -> void:
	_currency_strip = Control.new()
	_currency_strip.position = Vector2(24, 106)
	_currency_strip.size     = Vector2(W - 48, 108)
	_currency_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(_currency_strip)

	var count: int = STRIP_CURRENCIES.size()
	var gap := 14.0
	# Με λίγα badges το ισομοιρασμένο πλάτος θα έβγαινε υπερβολικά φαρδύ —
	# περιορίζεται και η ομάδα κεντράρεται στο strip.
	var badge_w: float = minf((_currency_strip.size.x - gap * (count - 1)) / count, 220.0)
	var x0: float = (_currency_strip.size.x - (badge_w * count + gap * (count - 1))) / 2.0

	for i in range(count):
		var currency: String = STRIP_CURRENCIES[i]
		var bx: float = x0 + i * (badge_w + gap)

		var badge := Panel.new()
		badge.position = Vector2(bx, 0)
		badge.size     = Vector2(badge_w, 108)
		badge.add_theme_stylebox_override("panel", _sb(C_DARK, Currency.COLORS.get(currency, C_GOLD_D).darkened(0.2), 3, 10))
		_currency_strip.add_child(badge)

		_lbl(badge, str(Currency.ICONS.get(currency, "•")), Vector2(0, 8), Vector2(badge_w, 44),
			 30, Currency.COLORS.get(currency, C_GOLD), HORIZONTAL_ALIGNMENT_CENTER)

		var amount_lbl := _lbl(badge, "", Vector2(0, 52), Vector2(badge_w, 40),
			 30, C_BONE, HORIZONTAL_ALIGNMENT_CENTER, Color(0,0,0,0.85), 1, 1)
		_currency_labels[currency] = amount_lbl

	_update_currency_labels()

func _update_currency_labels() -> void:
	for currency in _currency_labels:
		(_currency_labels[currency] as Label).text = str(Currency.get_amount(currency))

func _build_tabs() -> void:
	var bar := Panel.new()
	bar.position = Vector2(0, HDR_H + 6)
	bar.size     = Vector2(W, TAB_H)
	bar.add_theme_stylebox_override("panel", _sb(Color(0.048, 0.032, 0.015, 0.90), C0, 0))
	add_child(bar)

	_tab_weapons = _tab_button("⚔  ΟΠΛΑ", Vector2(40, 10), Vector2(480, 90))
	bar.add_child(_tab_weapons)
	_tab_weapons.pressed.connect(func(): _set_category("weapons"))

	_tab_armor = _tab_button("🛡  ΠΑΝΟΠΛΙΕΣ", Vector2(560, 10), Vector2(480, 90))
	bar.add_child(_tab_armor)
	_tab_armor.pressed.connect(func(): _set_category("armor"))

	_update_tabs()

## Δεύτερη γραμμή tabs — οι κατηγορίες της τρέχουσας καρτέλας (9 για Όπλα,
## 4 για Πανοπλίες). Ξαναχτίζεται ολόκληρη σε κάθε εναλλαγή καρτέλας, αφού
## οι δύο έχουν διαφορετικό σύνολο κατηγοριών.
func _build_category_bar() -> void:
	_cat_bar = ScrollContainer.new()
	_cat_bar.position = Vector2(0, HDR_H + TAB_H + 6)
	_cat_bar.size     = Vector2(W, CAT_BAR_H)
	_cat_bar.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_cat_bar)
	_rebuild_category_bar()

func _rebuild_category_bar() -> void:
	for c in _cat_bar.get_children():
		c.queue_free()
	_cat_buttons.clear()

	var catalog := _current_catalog()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_cat_bar.add_child(row)

	for category in catalog.categories:
		var btn := Button.new()
		btn.text = catalog.get_category_label(category)
		btn.custom_minimum_size = Vector2(190, CAT_BAR_H - 8)
		btn.add_theme_font_size_override("font_size", 26)
		_style_iron(btn, category == _selected_category[_category])
		row.add_child(btn)
		_cat_buttons[category] = btn
		btn.pressed.connect(func(): _select_sub_category(category))

func _build_grid_area() -> void:
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_scroll.add_child(margin)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 20)
	_grid.add_theme_constant_override("v_separation", 20)
	margin.add_child(_grid)

# ═══════════════════════════════════════════════════════════════
# ΛΟΓΙΚΗ ΚΑΤΗΓΟΡΙΩΝ / ΠΛΕΓΜΑΤΟΣ
# ═══════════════════════════════════════════════════════════════
func _set_category(cat: String) -> void:
	if _category == cat:
		return
	_category = cat
	_update_tabs()
	_rebuild_category_bar()
	_layout_grid_area()
	_refresh_grid()

func _update_tabs() -> void:
	_style_iron(_tab_weapons, _category == "weapons")
	_style_iron(_tab_armor,   _category == "armor")

## Η κάτω περιοχή (grid) ξεκινάει πάντα ακριβώς κάτω από τη γραμμή
## κατηγοριών — το ίδιο ύψος και για τις δύο καρτέλες, οπότε δεν χρειάζεται
## να αλλάζει δυναμικά.
func _layout_grid_area() -> void:
	var top := HDR_H + TAB_H + 16 + CAT_BAR_H + 10
	_scroll.position = Vector2(0, top)
	_scroll.size     = Vector2(W, H - top)

func _select_sub_category(category: String) -> void:
	if _selected_category[_category] == category:
		return
	_selected_category[_category] = category
	for cat in _cat_buttons:
		_style_iron(_cat_buttons[cat], cat == category)
	_refresh_grid()

func _refresh_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var catalog := _current_catalog()
	var category: String = _selected_category[_category]
	for id in catalog.get_items_in_category(category):
		_grid.add_child(_make_equipment_card(catalog, id))

func _on_equipment_changed() -> void:
	_refresh_grid()

# ═══════════════════════════════════════════════════════════════
# ΚΑΡΤΑ ΕΞΟΠΛΙΣΜΟΥ (WeaponInventory/ArmorInventory — μόνο αγορά· η
# αναβάθμιση/πώληση γίνονται αποκλειστικά στο Inventory)
# ═══════════════════════════════════════════════════════════════
func _make_equipment_card(catalog: EquipmentCatalog, id: String) -> Control:
	# Μεγαλύτερη κάρτα από την αρχική (320 ύψος): πιο ευανάγνωστα κείμενα και
	# κουμπί ΑΓΟΡΑ ύψους 76px — άνετος στόχος για δάχτυλο σε κινητό.
	const CW := 490.0
	const CH := 372.0

	var owned: bool = catalog.is_owned(id)

	var card := Panel.new()
	card.custom_minimum_size = Vector2(CW, CH)
	card.add_theme_stylebox_override("panel", _sb(C_DARK, C_GOLD_D if owned else C_GOLD_D.darkened(0.25), 3, 10))

	var icon := TextureRect.new()
	icon.position = Vector2(20, 16)
	icon.size     = Vector2(CW - 40, 140)
	icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_path := catalog.get_icon_path(id)
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	card.add_child(icon)

	_lbl(card, catalog.get_item_name(id), Vector2(16, 160), Vector2(CW - 32, 36),
		 25, C_BONE, HORIZONTAL_ALIGNMENT_CENTER)

	_lbl(card, "%s %s %d" % [catalog.stat_icon, catalog.stat_label, catalog.get_base_stat(id)], Vector2(20, 198), Vector2(CW - 40, 32),
		 22, C_SILVER, HORIZONTAL_ALIGNMENT_CENTER)

	if owned:
		_lbl(card, "Κατοχή — Επίπεδο %d/%d" % [catalog.get_tier(id), catalog.UPGRADE_MAX_TIER],
			 Vector2(20, 232), Vector2(CW - 40, 32), 20, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_lbl(card, "%d %s" % [catalog.get_base_price(id), Currency.ICONS.get("Χρυσό", "🪙")],
			 Vector2(20, 232), Vector2(CW - 40, 32), 25, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)

	var buy := Button.new()
	buy.position = Vector2(20, CH - 92)
	buy.size     = Vector2(CW - 40, 76)
	buy.text     = "ΑΓΟΡΑΣΜΕΝΟ" if owned else "ΑΓΟΡΑ"
	buy.add_theme_font_size_override("font_size", 27)
	buy.disabled = owned
	_style_iron(buy, not owned)
	card.add_child(buy)
	if not owned:
		buy.pressed.connect(func(): _buy(catalog, id))

	return card

func _buy(catalog: EquipmentCatalog, id: String) -> void:
	if not catalog.buy(id):
		_flash_insufficient()

func _flash_insufficient() -> void:
	var tw := create_tween()
	tw.tween_property(_currency_strip, "modulate", Color(1, 0.3, 0.3), 0.12)
	tw.tween_property(_currency_strip, "modulate", Color(1, 1, 1), 0.25)

# ═══════════════════════════════════════════════════════════════
# ΒΟΗΘΗΤΙΚΕΣ ΣΥΝΑΡΤΗΣΕΙΣ
# ═══════════════════════════════════════════════════════════════
func _tab_button(txt: String, pos: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	b.text     = txt
	b.position = pos
	b.size     = sz
	b.add_theme_font_size_override("font_size", 32)
	return b

func _sb(bg: Color, border: Color, bw: int, cr: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(cr)
	return s

func _cr(parent: Control, pos: Vector2, sz: Vector2, col: Color) -> void:
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
	btn.add_theme_stylebox_override("disabled", _sb(Color(0.10, 0.09, 0.08), C_BRONZE.darkened(0.5), 3, 6))
	btn.add_theme_stylebox_override("focus", _sb(C0, C0, 0, 0))

	btn.add_theme_color_override("font_color",          fcol)
	btn.add_theme_color_override("font_hover_color",    C_GOLD if golden else C_SILVER.lightened(0.18))
	btn.add_theme_color_override("font_pressed_color",  fcol.darkened(0.32))
	btn.add_theme_color_override("font_disabled_color", C_BRONZE)
	btn.add_theme_color_override("font_shadow_color",   Color(0,0,0,0.92))
	btn.add_theme_constant_override("shadow_offset_x", 2)
	btn.add_theme_constant_override("shadow_offset_y", 3)
