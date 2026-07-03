extends Control

const C_PARCH := Color("f3e6c4")
const C_MUTED := Color("cdbf9a")
const C_GOLD  := Color("f2c84b")
const C_EMPTY := Color(0, 0, 0, 0.35)

var _current_category := Inventory.CATEGORY_WEAPON

func _ready() -> void:
	hide()
	%WeaponsTab.pressed.connect(func(): _select_category(Inventory.CATEGORY_WEAPON))
	%ArmorTab.pressed.connect(func(): _select_category(Inventory.CATEGORY_ARMOR))
	%Dim.gui_input.connect(_on_dim_input)
	%CloseButton.pressed.connect(close_popup)
	Inventory.item_added.connect(func(_id: String) -> void:
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
	_refresh()

func _refresh() -> void:
	for c in %ItemsList.get_children():
		c.queue_free()
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

func _make_item_card(item: Dictionary) -> Control:
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
