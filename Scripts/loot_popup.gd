extends Control

# Popup "Αποθήκη": δείχνει τα νομίσματα/υλικά του παίκτη.
# Τα ποσά έρχονται από το Currency autoload, οπότε ενημερώνονται αυτόματα
# όταν ξοδεύονται πόροι αλλού (π.χ. στο ShopPopup).

const MONEY_KEYS: Array[String]     = ["Χρυσό"]
const MATERIAL_KEYS: Array[String]  = ["Κασμίρ", "Βαμβάκι", "Σίδερο"]

func _ready() -> void:
	hide()
	Currency.changed.connect(_refresh)
	_refresh()
	%Dim.gui_input.connect(_on_dim_input)
	%CloseButton.pressed.connect(close_popup)

func open() -> void:
	_refresh()
	show()

func close_popup() -> void:
	hide()

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_popup()

func _refresh() -> void:
	_populate(%MaterialsList, MATERIAL_KEYS)
	_populate(%MoneyList, MONEY_KEYS)

func _populate(list: VBoxContainer, currencies: Array[String]) -> void:
	for c in list.get_children():
		c.queue_free()
	for currency in currencies:
		list.add_child(_make_row(currency))

func _make_row(currency: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size = Vector2(0, 58)

	var token := Panel.new()
	token.custom_minimum_size = Vector2(42, 42)
	token.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Currency.COLORS.get(currency, Color.WHITE)
	sb.set_corner_radius_all(21)
	sb.set_border_width_all(3)
	sb.border_color = Color(0, 0, 0, 0.4)
	token.add_theme_stylebox_override("panel", sb)
	row.add_child(token)

	var name_label := Label.new()
	name_label.text = currency
	name_label.add_theme_color_override("font_color", Color("f3e6c4"))
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var amount_label := Label.new()
	amount_label.text = str(Currency.get_amount(currency))
	amount_label.add_theme_color_override("font_color", Color("ffd77a"))
	amount_label.add_theme_font_size_override("font_size", 32)
	amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(amount_label)

	return row
