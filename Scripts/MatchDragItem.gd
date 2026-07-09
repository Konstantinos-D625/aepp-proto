class_name MatchDragItem
extends PanelContainer

## Μικρό, επαναχρησιμοποιήσιμο drag & drop στοιχείο για ασκήσεις
## αντιστοίχισης (π.χ. miner_popup.gd). Ένα instance μπορεί να είναι "πηγή"
## (σέρνεται) ή "στόχος" (δέχεται ό,τι σέρνεται πάνω του), ανάλογα με τα
## flags is_source/is_target — το ίδιο script καλύπτει και τους δύο ρόλους
## ώστε να μοιράζονται το ίδιο οπτικό στυλ (PanelContainer + StyleBox).
##
## Δεν γνωρίζει τίποτα για τη λογική της αντιστοίχισης· απλώς μεταφέρει
## το payload μέσω του built-in drag-and-drop συστήματος του Godot και
## ειδοποιεί τον στόχο μέσω σήματος.

signal dropped_on(payload: Variant)

var payload: Variant = null   # ό,τι "κουβαλάει" όταν είναι πηγή (π.χ. index)
var is_source := false
var is_target := false
var locked := false           # πηγή που έχει ήδη τοποθετηθεί -> δεν σέρνεται
var preview_text := ""

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not is_source or locked or payload == null:
		return null
	var wrap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.13, 0.10, 0.94)
	sb.border_color = Color(0.940, 0.760, 0.160)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	# Λίγο μεγαλύτερο από παλιά (12/8, font 22) — σε οθόνη αφής το preview
	# κρύβεται εν μέρει κάτω από το δάχτυλο, οπότε πρέπει να διαβάζεται.
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	wrap.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = preview_text
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	wrap.add_child(lbl)
	set_drag_preview(wrap)
	return payload

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return is_target and data != null

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	dropped_on.emit(data)
