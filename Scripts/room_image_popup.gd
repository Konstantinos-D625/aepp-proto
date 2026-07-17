extends Control

# Γενικό popup: δείχνει μια εικόνα δωματίου (Armory, Chapel, Library, Kitchen, ...)
# πάνω από το CastlePopup. Καλείται με open_with(texture, spots).
#
# spots: Dictionary btn_name -> {"id": String, "rect": Rect2, "value":
# int/bool/String, "category": String (KeyInventory.CATEGORY_*)}. btn_name
# είναι ένα από τα 4 γενικά κουμπιά-κρυψώνες της σκηνής (Chest/Grindstone/
# Basket/Shelf) — ο ΡΟΛΟΣ τους (τι είδος κλειδί δίνουν, πού βρίσκονται)
# ορίζεται ΚΑΘΕ φορά από το δωμάτιο που τα καλεί (βλ. Scripts/castle_popup.gd),
# ΟΧΙ από το όνομά τους· π.χ. το ίδιο κουμπί "Chest" δίνει το κλειδί του
# σεντουκιού στο Armory αλλά ένα εντελώς διαφορετικό (τιμή/κατηγορία/θέση)
# στο Library. Ό,τι κουμπί δεν έχει entry στο spots μένει κρυμμένο.
#
# Κάθε σημείο δίνει το κλειδί του ΜΙΑ ΜΟΝΟ φορά συνολικά (όχι ανά επίσκεψη) —
# βλ. _collected, keyed by spot["id"] (ΟΧΙ btn.name — αφού το ίδιο κουμπί
# ξαναχρησιμοποιείται από διαφορετικά δωμάτια, το id είναι αυτό που κάνει
# τα σημεία μοναδικά, βλ. Scripts/castle_popup.gd). Το RoomImagePopup
# instance είναι μόνιμο (δεν καταστρέφεται ανάμεσα σε επισκέψεις), οπότε το
# _collected διατηρείται φυσικά σε όλο το παιχνίδι χωρίς να χρειάζεται
# save/load εδώ.

var _collected: Dictionary = {}   # spot id -> true αν έχει ήδη μαζευτεί

func _ready() -> void:
	hide()
	%Dim.gui_input.connect(_on_dim_input)
	%CloseButton.pressed.connect(close_popup)
	%Chest.pressed.connect(_on_spot_pressed.bind(%Chest))
	%Grindstone.pressed.connect(_on_spot_pressed.bind(%Grindstone))
	%Basket.pressed.connect(_on_spot_pressed.bind(%Basket))
	%Shelf.pressed.connect(_on_spot_pressed.bind(%Shelf))

func open_with(tex: Texture2D, spots: Dictionary = {}) -> void:
	%RoomImage.texture = tex
	_setup_spot(%Chest, spots.get("Chest"))
	_setup_spot(%Grindstone, spots.get("Grindstone"))
	_setup_spot(%Basket, spots.get("Basket"))
	_setup_spot(%Shelf, spots.get("Shelf"))
	show()

func close_popup() -> void:
	hide()

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_popup()

func _setup_spot(btn: Button, spot) -> void:
	if spot == null or _collected.get(spot["id"], false):
		btn.visible = false
		return
	var rect: Rect2 = spot["rect"]
	btn.offset_left = rect.position.x
	btn.offset_top = rect.position.y
	btn.offset_right = rect.position.x + rect.size.x
	btn.offset_bottom = rect.position.y + rect.size.y
	btn.set_meta("spot_id", spot["id"])
	btn.set_meta("key_value", spot["value"])
	btn.set_meta("key_category", spot["category"])
	btn.visible = true
	_add_hint_mark(btn)

## Ένα ζωντανό (pulsing) "?" πάνω σε κάθε κρυμμένο/αόρατο κουμπί-κλειδί, ώστε
## ο παίκτης να ξέρει ΠΟΥ να πατήσει αντί να δοκιμάζει τυχαία σημεία στην
## εικόνα. mouse_filter = IGNORE ώστε το κλικ να φτάνει πάντα στο Button.
func _add_hint_mark(btn: Button) -> void:
	if btn.has_node("HintMark"):
		return
	var mark := Label.new()
	mark.name = "HintMark"
	mark.text = "?"
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", 72)
	mark.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	mark.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	mark.add_theme_constant_override("shadow_offset_x", 2)
	mark.add_theme_constant_override("shadow_offset_y", 2)
	btn.add_child(mark)

	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(mark, "modulate:a", 0.25, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(mark, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

func _on_spot_pressed(btn: Button) -> void:
	var value = btn.get_meta("key_value")
	var category: String = btn.get_meta("key_category")
	KeyInventory.add_key(value, category)
	match category:
		KeyInventory.CATEGORY_LOGICAL:
			%FoundKeyPopup.open_logical(value)
		KeyInventory.CATEGORY_CHARACTER:
			%FoundKeyPopup.open_character(value)
		_:
			%FoundKeyPopup.open_numeric(value)
	_collect(btn)

## Σημαδεύει το σημείο ως ήδη μαζεμένο και το κρύβει αμέσως (δεν δίνει ξανά
## κλειδί, ούτε σε αυτή ούτε σε επόμενη επίσκεψη).
func _collect(btn: Button) -> void:
	_collected[btn.get_meta("spot_id")] = true
	btn.visible = false
