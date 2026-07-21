extends Control

# Μικρό popup που εμφανίζεται όταν ο παίκτης βρει ένα κλειδί μέσα σε ένα
# δωμάτιο (π.χ. Armory, Kitchen) — αριθμητικό, λογικό Αληθής/Ψευδής, ή
# χαρακτήρα (και τα τρία μέσα από το KeyInventory, βλ.
# CATEGORY_NUMERIC/CATEGORY_LOGICAL/CATEGORY_CHARACTER).

# Το KeyImage δείχνει πάντα το εικονίδιο κλειδιού (κλειδι.png, ορισμένο στο
# .tscn) ΕΚΤΟΣ από το open_item(), όπου δείχνει την πραγματική εικόνα του
# αντικειμένου — _default_key_tex κρατά το αρχικό ώστε τα open_numeric/
# open_logical/open_character να μπορούν να το επαναφέρουν αν το προηγούμενο
# άνοιγμα του popup ήταν open_item().
var _default_key_tex: Texture2D

func _ready() -> void:
	hide()
	_default_key_tex = %KeyImage.texture
	%Dim.gui_input.connect(_on_dim_input)
	%OkButton.pressed.connect(close_popup)

func open_numeric(value: int) -> void:
	%KeyImage.texture = _default_key_tex
	%Label.text = "Βρήκες ένα Κλειδί με τιμή: %d" % value
	show()

func open_logical(value: bool) -> void:
	%KeyImage.texture = _default_key_tex
	%Label.text = "Βρήκες ένα Λογικό Κλειδί: %s" % ("ΑΛΗΘΗΣ" if value else "ΨΕΥΔΗΣ")
	show()

func open_character(value: String) -> void:
	%KeyImage.texture = _default_key_tex
	%Label.text = "Βρήκες ένα Κλειδί Χαρακτήρων: '%s'" % value
	show()

## Ίδιο popup, για κρυμμένα σημεία που δίνουν ολόκληρο αντικείμενο εξοπλισμού
## αντί για κλειδί (π.χ. το golden_sword στο Chapel, βλ. room_image_popup.gd).
## icon_tex: η πραγματική εικόνα του αντικειμένου — αν λείψει (null), μένει
## το προεπιλεγμένο εικονίδιο κλειδιού αντί να δείξει άδειο TextureRect.
func open_item(item_name: String, icon_tex: Texture2D = null) -> void:
	%KeyImage.texture = icon_tex if icon_tex != null else _default_key_tex
	%Label.text = "Βρήκες: %s!" % item_name
	show()

func close_popup() -> void:
	hide()

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_popup()
