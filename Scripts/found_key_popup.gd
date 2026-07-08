extends Control

# Μικρό popup που εμφανίζεται όταν ο παίκτης βρει ένα κλειδί μέσα σε ένα
# δωμάτιο (π.χ. Armory, Kitchen) — αριθμητικό, λογικό Αληθής/Ψευδής, ή
# χαρακτήρα (και τα τρία μέσα από το KeyInventory, βλ.
# CATEGORY_NUMERIC/CATEGORY_LOGICAL/CATEGORY_CHARACTER).

func _ready() -> void:
	hide()
	%Dim.gui_input.connect(_on_dim_input)
	%OkButton.pressed.connect(close_popup)

func open_numeric(value: int) -> void:
	%Label.text = "Βρήκες ένα Κλειδί με τιμή: %d" % value
	show()

func open_logical(value: bool) -> void:
	%Label.text = "Βρήκες ένα Λογικό Κλειδί: %s" % ("ΑΛΗΘΗΣ" if value else "ΨΕΥΔΗΣ")
	show()

func open_character(value: String) -> void:
	%Label.text = "Βρήκες ένα Κλειδί Χαρακτήρων: '%s'" % value
	show()

func close_popup() -> void:
	hide()

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_popup()
