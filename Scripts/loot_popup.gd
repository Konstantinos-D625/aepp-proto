extends Control

# Popup "Αποθήκη": δείχνει τα υλικά και τα χρήματα του παίκτη.
# Οι τιμές είναι προσωρινές (placeholder) — συνδέονται με πραγματικό inventory αργότερα.

const MATERIALS := [
	{ "name": "Βαμβάκι", "amount": 24, "color": Color("f4ecd8") },
	{ "name": "Μαλλί", "amount": 12, "color": Color("cdb38b") },
	{ "name": "Μετάξι", "amount": 3, "color": Color("e6a8c6") },
	{ "name": "Κασμίρ", "amount": 1, "color": Color("b9863f") },
]

const MONEY := [
	{ "name": "Χάλκινα νομίσματα", "amount": 350, "color": Color("c87f3a") },
	{ "name": "Ασημένια νομίσματα", "amount": 48, "color": Color("cdd1d4") },
	{ "name": "Χρυσά νομίσματα", "amount": 7, "color": Color("f2c84b") },
	{ "name": "Διαμάντια", "amount": 2, "color": Color("7fdfff") },
]

func _ready() -> void:
	hide()
	_populate(%MaterialsList, MATERIALS)
	_populate(%MoneyList, MONEY)
	%Dim.gui_input.connect(_on_dim_input)
	%CloseButton.pressed.connect(close_popup)

func open() -> void:
	show()

func close_popup() -> void:
	hide()

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_popup()

func _populate(list: VBoxContainer, items: Array) -> void:
	for c in list.get_children():
		c.queue_free()
	for item in items:
		list.add_child(_make_row(item))

func _make_row(item: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size = Vector2(0, 58)

	var token := Panel.new()
	token.custom_minimum_size = Vector2(42, 42)
	token.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = item["color"]
	sb.set_corner_radius_all(21)
	sb.set_border_width_all(3)
	sb.border_color = Color(0, 0, 0, 0.4)
	token.add_theme_stylebox_override("panel", sb)
	row.add_child(token)

	var name_label := Label.new()
	name_label.text = item["name"]
	name_label.add_theme_color_override("font_color", Color("f3e6c4"))
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var amount_label := Label.new()
	amount_label.text = str(int(item["amount"]))
	amount_label.add_theme_color_override("font_color", Color("ffd77a"))
	amount_label.add_theme_font_size_override("font_size", 32)
	amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(amount_label)

	return row
