extends Control

const C_PARCH := Color("f3e6c4")
const C_MUTED := Color("cdbf9a")
const C_GOLD  := Color("f2c84b")
const C_EMPTY := Color(0, 0, 0, 0.35)

var _current_category := Inventory.CATEGORY_WEAPON
var _selected_weapon_category: String = WeaponInventory.CATEGORIES[0]
var _category_bar: Control
var _category_buttons: Dictionary = {}   # weapon category -> Button

func _ready() -> void:
	hide()
	%WeaponsTab.pressed.connect(func(): _select_category(Inventory.CATEGORY_WEAPON))
	%ArmorTab.pressed.connect(func(): _select_category(Inventory.CATEGORY_ARMOR))
	%Dim.gui_input.connect(_on_dim_input)
	%CloseButton.pressed.connect(close_popup)
	_build_weapon_category_bar()
	Inventory.item_added.connect(func(_id: String) -> void:
		if visible:
			_refresh()
	)
	# Το WeaponInventory είναι η μοναδική πηγή αλήθειας για τα όπλα — κάθε
	# αλλαγή του (αγορά/αναβάθμιση/πώληση) ξαναζωγραφίζει αμέσως το Inventory
	# όσο είναι ανοιχτό (και το Weapon Shop, αν είναι κι αυτό ανοιχτό).
	WeaponInventory.changed.connect(func() -> void:
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

func _select_category(category: String) -> void:
	_current_category = category
	%WeaponsTab.button_pressed = category == Inventory.CATEGORY_WEAPON
	%ArmorTab.button_pressed = category == Inventory.CATEGORY_ARMOR
	_category_bar.visible = category == Inventory.CATEGORY_WEAPON
	_refresh()

# ═══════════════════════════════════════════════════════════════════════════
# ΚΑΤΗΓΟΡΙΕΣ ΟΠΛΩΝ (tab bar: μαχαίρι < σπαθί < ... < τόξο)
# ═══════════════════════════════════════════════════════════════════════════

func _build_weapon_category_bar() -> void:
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 64)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	scroll.add_child(row)

	for category in WeaponInventory.CATEGORIES:
		var btn := Button.new()
		btn.text = category
		btn.toggle_mode = true
		btn.button_pressed = category == _selected_weapon_category
		btn.add_theme_font_size_override("font_size", 20)
		row.add_child(btn)
		_category_buttons[category] = btn
		btn.pressed.connect(func(): _select_weapon_category(category))

	_category_bar = scroll

	# Εισάγεται στο VBox της υπάρχουσας σκηνής, ακριβώς μετά το Tabs (Όπλα/Πανοπλίες).
	var tabs_node: Control = %WeaponsTab.get_parent()
	var vbox: Control = tabs_node.get_parent()
	var tabs_index := tabs_node.get_index()
	vbox.add_child(scroll)
	vbox.move_child(scroll, tabs_index + 1)

func _select_weapon_category(category: String) -> void:
	_selected_weapon_category = category
	for cat in _category_buttons:
		(_category_buttons[cat] as Button).button_pressed = cat == category
	_refresh()

# ═══════════════════════════════════════════════════════════════════════════
# REFRESH
# ═══════════════════════════════════════════════════════════════════════════

func _refresh() -> void:
	for c in %ItemsList.get_children():
		c.queue_free()

	if _current_category == Inventory.CATEGORY_WEAPON:
		for id in WeaponInventory.get_items_in_category(_selected_weapon_category):
			%ItemsList.add_child(_make_weapon_card(id))
		return

	var items := Inventory.get_owned_by_category(_current_category)
	if items.is_empty():
		var lbl := Label.new()
		lbl.text = "Δεν υπάρχουν αντικείμενα ακόμα."
		lbl.add_theme_color_override("font_color", C_MUTED)
		lbl.add_theme_font_size_override("font_size", 28)
		%ItemsList.add_child(lbl)
		return
	for item in items:
		%ItemsList.add_child(_make_item_card(item))

# ═══════════════════════════════════════════════════════════════════════════
# ΚΑΡΤΕΣ ΟΠΛΩΝ (WeaponInventory autoload — αγορά μόνο από Shop,
# αναβάθμιση/πώληση μόνο εδώ στο Inventory)
# ═══════════════════════════════════════════════════════════════════════════

func _make_weapon_card(id: String) -> Control:
	var card := _make_card_panel()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	card.add_child(row)

	if not WeaponInventory.is_owned(id):
		row.add_child(_make_locked_placeholder())

		var locked_info := VBoxContainer.new()
		locked_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		locked_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		locked_info.add_theme_constant_override("separation", 8)
		row.add_child(locked_info)

		var locked_label := Label.new()
		locked_label.text = "Κλειδωμένο"
		locked_label.add_theme_color_override("font_color", C_MUTED)
		locked_label.add_theme_font_size_override("font_size", 32)
		locked_info.add_child(locked_label)

		var hint_label := Label.new()
		hint_label.text = "Αγόρασέ το από το Κατάστημα Όπλων."
		hint_label.add_theme_color_override("font_color", C_MUTED)
		hint_label.add_theme_font_size_override("font_size", 20)
		locked_info.add_child(hint_label)

		return card

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(150, 150)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path := WeaponInventory.get_icon_path(id)
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 8)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = WeaponInventory.get_weapon_name(id)
	name_label.add_theme_color_override("font_color", C_PARCH)
	name_label.add_theme_font_size_override("font_size", 32)
	info.add_child(name_label)

	var tier_label := Label.new()
	tier_label.text = "Επίπεδο %d/%d" % [WeaponInventory.get_tier(id), WeaponInventory.UPGRADE_MAX_TIER]
	tier_label.add_theme_color_override("font_color", C_MUTED)
	tier_label.add_theme_font_size_override("font_size", 22)
	info.add_child(tier_label)

	var attack_label := Label.new()
	attack_label.text = "⚔ Επίθεση: %d" % WeaponInventory.get_total_attack(id)
	attack_label.add_theme_color_override("font_color", C_GOLD)
	attack_label.add_theme_font_size_override("font_size", 26)
	info.add_child(attack_label)

	info.add_child(_make_upgrade_row(id))
	info.add_child(_make_sell_row(id))

	return card

func _make_locked_placeholder() -> Control:
	var box := Panel.new()
	box.custom_minimum_size = Vector2(150, 150)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(0, 0, 0, 0.6)
	sb.set_border_width_all(1)
	box.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = "🔒"
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 48)
	box.add_child(lbl)

	return box

func _make_upgrade_row(id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var tier := WeaponInventory.get_tier(id)
	if tier >= WeaponInventory.UPGRADE_MAX_TIER:
		var max_label := Label.new()
		max_label.text = "MAX"
		max_label.add_theme_color_override("font_color", C_GOLD)
		max_label.add_theme_font_size_override("font_size", 22)
		row.add_child(max_label)
	else:
		var upgrade_btn := Button.new()
		upgrade_btn.text = "Αναβάθμιση  %d %s" % [WeaponInventory.get_upgrade_cost(tier), Currency.ICONS.get("Χρυσό", "🪙")]
		upgrade_btn.add_theme_font_size_override("font_size", 22)
		upgrade_btn.custom_minimum_size = Vector2(220, 48)
		row.add_child(upgrade_btn)
		upgrade_btn.pressed.connect(func(): WeaponInventory.upgrade(id))

	return row

func _make_sell_row(id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var sell_btn := Button.new()
	sell_btn.text = "Πούλησε  (+%d %s)" % [WeaponInventory.get_sell_price(id), Currency.ICONS.get("Χρυσό", "🪙")]
	sell_btn.add_theme_font_size_override("font_size", 20)
	sell_btn.add_theme_color_override("font_color", Color("e2a5a5"))
	sell_btn.custom_minimum_size = Vector2(220, 44)
	row.add_child(sell_btn)
	sell_btn.pressed.connect(func(): WeaponInventory.sell(id))

	return row

# ═══════════════════════════════════════════════════════════════════════════
# ΚΑΡΤΕΣ ΓΕΝΙΚΟΥ INVENTORY (armor — αμετάβλητη λογική)
# ═══════════════════════════════════════════════════════════════════════════

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

func _make_item_card(item: Dictionary) -> Control:
	var card := _make_card_panel()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	card.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(150, 150)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Ίδια πηγή εικόνας με το Character Scene (Inventory.get_item_texture) —
	# ώστε το ίδιο αντικείμενο να δείχνει πάντα την ίδια εικόνα παντού.
	icon.texture = Inventory.get_item_texture(item)
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 8)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = item["name"]
	name_label.add_theme_color_override("font_color", C_PARCH)
	name_label.add_theme_font_size_override("font_size", 34)
	info.add_child(name_label)

	var stats: Dictionary = item["stats"]
	for stat_name in stats:
		info.add_child(_make_stat_row(stat_name, stats[stat_name]))

	return card

func _make_stat_row(stat_name: String, value: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = stat_name
	label.custom_minimum_size = Vector2(120, 0)
	label.add_theme_color_override("font_color", C_MUTED)
	label.add_theme_font_size_override("font_size", 24)
	row.add_child(label)

	for i in range(Inventory.MAX_STAT):
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(24, 24)
		var sb := StyleBoxFlat.new()
		sb.bg_color = C_GOLD if i < value else C_EMPTY
		sb.set_corner_radius_all(4)
		sb.border_color = Color(0, 0, 0, 0.4)
		sb.set_border_width_all(1)
		pip.add_theme_stylebox_override("panel", sb)
		row.add_child(pip)

	return row
