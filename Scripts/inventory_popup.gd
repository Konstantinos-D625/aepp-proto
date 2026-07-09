extends Control

const C_PARCH := Color("f3e6c4")
const C_MUTED := Color("cdbf9a")
const C_GOLD  := Color("f2c84b")
const C_EMPTY := Color(0, 0, 0, 0.35)

var _current_category := Inventory.CATEGORY_WEAPON

# Θυμάται ξεχωριστά ποια υπο-κατηγορία ήταν επιλεγμένη σε κάθε καρτέλα
# (Όπλα/Πανοπλίες), ώστε η επιλογή να μη χάνεται όταν ο παίκτης εναλλάσσει.
# Γεμίζεται στο _ready() (όχι εδώ ως field initializer) — τα field
# initializers μπορούν να αξιολογηθούν από το GDScript σε context όπου τα
# autoloads δεν είναι ακόμα διαθέσιμα, οδηγώντας σε άδειο WeaponInventory
# .categories/ArmorInventory.categories και "out of bounds" σε [0].
var _selected_category: Dictionary = {}
var _category_bar: Control
var _category_buttons: Dictionary = {}   # κατηγορία -> Button (της τρέχουσας καρτέλας)

func _ready() -> void:
	hide()
	_selected_category = {
		Inventory.CATEGORY_WEAPON: WeaponInventory.categories[0],
		Inventory.CATEGORY_ARMOR: ArmorInventory.categories[0],
	}
	%WeaponsTab.pressed.connect(func(): _select_category(Inventory.CATEGORY_WEAPON))
	%ArmorTab.pressed.connect(func(): _select_category(Inventory.CATEGORY_ARMOR))
	%Dim.gui_input.connect(_on_dim_input)
	%CloseButton.pressed.connect(close_popup)
	_build_category_bar_container()
	_rebuild_category_bar()
	# Ο WeaponInventory/ArmorInventory είναι η μοναδική πηγή αλήθειας για τον
	# εξοπλισμό — κάθε αλλαγή τους (αγορά/αναβάθμιση/πώληση) ξαναζωγραφίζει
	# αμέσως το Inventory όσο είναι ανοιχτό (και το Shop, αν είναι κι αυτό ανοιχτό).
	WeaponInventory.changed.connect(func() -> void:
		if visible:
			_refresh()
	)
	ArmorInventory.changed.connect(func() -> void:
		if visible:
			_refresh()
	)

func open() -> void:
	_select_category(Inventory.CATEGORY_WEAPON)
	show()

func close_popup() -> void:
	hide()

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_popup()

func _current_catalog() -> EquipmentCatalog:
	if _current_category == Inventory.CATEGORY_WEAPON:
		return WeaponInventory
	return ArmorInventory

func _select_category(category: String) -> void:
	_current_category = category
	%WeaponsTab.button_pressed = category == Inventory.CATEGORY_WEAPON
	%ArmorTab.button_pressed = category == Inventory.CATEGORY_ARMOR
	_rebuild_category_bar()
	_refresh()

# ═══════════════════════════════════════════════════════════════════════════
# ΚΑΤΗΓΟΡΙΕΣ ΕΞΟΠΛΙΣΜΟΥ (tab bar — 9 για Όπλα, 4 για Πανοπλίες)
# ═══════════════════════════════════════════════════════════════════════════

func _build_category_bar_container() -> void:
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 64)
	_category_bar = scroll

	# Εισάγεται στο VBox της υπάρχουσας σκηνής, ακριβώς μετά το Tabs (Όπλα/Πανοπλίες).
	var tabs_node: Control = %WeaponsTab.get_parent()
	var vbox: Control = tabs_node.get_parent()
	var tabs_index := tabs_node.get_index()
	vbox.add_child(scroll)
	vbox.move_child(scroll, tabs_index + 1)

## Ξαναχτίζει τα κουμπιά κατηγορίας για την ΤΡΕΧΟΥΣΑ καρτέλα (Όπλα/Πανοπλίες)
## — οι δύο καρτέλες έχουν διαφορετικό σύνολο κατηγοριών, οπότε δεν αρκεί να
## κρυφτούν/εμφανιστούν τα ίδια κουμπιά, χτίζονται από την αρχή.
func _rebuild_category_bar() -> void:
	for c in _category_bar.get_children():
		c.queue_free()
	_category_buttons.clear()

	var catalog := _current_catalog()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_category_bar.add_child(row)

	for category in catalog.categories:
		var btn := Button.new()
		btn.text = catalog.get_category_label(category)
		btn.toggle_mode = true
		btn.button_pressed = category == _selected_category[_current_category]
		btn.add_theme_font_size_override("font_size", 20)
		row.add_child(btn)
		_category_buttons[category] = btn
		btn.pressed.connect(func(): _select_sub_category(category))

func _select_sub_category(category: String) -> void:
	_selected_category[_current_category] = category
	for cat in _category_buttons:
		(_category_buttons[cat] as Button).button_pressed = cat == category
	_refresh()

# ═══════════════════════════════════════════════════════════════════════════
# REFRESH
# ═══════════════════════════════════════════════════════════════════════════

func _refresh() -> void:
	for c in %ItemsList.get_children():
		c.queue_free()

	var catalog := _current_catalog()
	var category: String = _selected_category[_current_category]
	# Μόνο όσα ΚΑΤΕΧΕΙ ο παίκτης — τα υπόλοιπα δεν εμφανίζονται καθόλου
	# (ολόκληρος ο κατάλογος, με τα ακλείδωτα, φαίνεται μόνο στο Shop).
	for id in catalog.get_items_in_category(category):
		if catalog.is_owned(id):
			%ItemsList.add_child(_make_equipment_card(catalog, id))

# ═══════════════════════════════════════════════════════════════════════════
# ΚΑΡΤΕΣ ΕΞΟΠΛΙΣΜΟΥ (WeaponInventory/ArmorInventory — αγορά μόνο από Shop,
# αναβάθμιση/πώληση μόνο εδώ στο Inventory)
# ═══════════════════════════════════════════════════════════════════════════

func _make_equipment_card(catalog: EquipmentCatalog, id: String) -> Control:
	var card := _make_card_panel()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	card.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(150, 150)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path := catalog.get_icon_path(id)
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 8)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = catalog.get_item_name(id)
	name_label.add_theme_color_override("font_color", C_PARCH)
	name_label.add_theme_font_size_override("font_size", 32)
	info.add_child(name_label)

	# Το "Επίπεδο x/3" έχει νόημα μόνο για καταλόγους με αναβαθμίσεις (όπλα) —
	# οι πανοπλίες (upgradable = false) δεν έχουν tiers, βλ. armor_inventory.gd.
	if catalog.upgradable:
		var tier_label := Label.new()
		tier_label.text = "Επίπεδο %d/%d" % [catalog.get_tier(id), catalog.UPGRADE_MAX_TIER]
		tier_label.add_theme_color_override("font_color", C_MUTED)
		tier_label.add_theme_font_size_override("font_size", 22)
		info.add_child(tier_label)

	var stat_row_label := Label.new()
	stat_row_label.text = "%s %s: %d" % [catalog.stat_icon, catalog.stat_label, catalog.get_total_stat(id)]
	stat_row_label.add_theme_color_override("font_color", C_GOLD)
	stat_row_label.add_theme_font_size_override("font_size", 26)
	info.add_child(stat_row_label)

	if catalog.upgradable:
		info.add_child(_make_upgrade_row(catalog, id))
	info.add_child(_make_sell_row(catalog, id))

	return card

func _make_upgrade_row(catalog: EquipmentCatalog, id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var tier := catalog.get_tier(id)
	if tier >= catalog.UPGRADE_MAX_TIER:
		var max_label := Label.new()
		max_label.text = "MAX"
		max_label.add_theme_color_override("font_color", C_GOLD)
		max_label.add_theme_font_size_override("font_size", 22)
		row.add_child(max_label)
	else:
		var upgrade_btn := Button.new()
		upgrade_btn.text = "Αναβάθμιση  %d %s" % [catalog.get_upgrade_cost(tier), Currency.ICONS.get("Χρυσό", "🪙")]
		upgrade_btn.add_theme_font_size_override("font_size", 22)
		upgrade_btn.custom_minimum_size = Vector2(220, 48)
		row.add_child(upgrade_btn)
		upgrade_btn.pressed.connect(func(): catalog.upgrade(id))

	return row

func _make_sell_row(catalog: EquipmentCatalog, id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var sell_btn := Button.new()
	sell_btn.text = "Πούλησε  (+%d %s)" % [catalog.get_sell_price(id), Currency.ICONS.get("Χρυσό", "🪙")]
	sell_btn.add_theme_font_size_override("font_size", 20)
	sell_btn.add_theme_color_override("font_color", Color("e2a5a5"))
	sell_btn.custom_minimum_size = Vector2(220, 44)
	row.add_child(sell_btn)
	sell_btn.pressed.connect(func(): catalog.sell(id))

	return row

func _make_card_panel() -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.22)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	sb.border_color = Color(0, 0, 0, 0.35)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", sb)
	return card
