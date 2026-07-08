extends Control

# Popup "Άσκηση": για δωμάτια του κάστρου που ΔΕΝ έχουν συνθήκη κλειδιού
# (βλ. CONDITIONS στο Scripts/castle_popup.gd) — δείχνει είτε την εικόνα
# άσκησης της περιοχής (αν υπάρχει, βλ. EXERCISE_PATHS) είτε ένα placeholder
# μήνυμα. Το κουμπί "Είσοδος" ζητάει το κόστος σε Κλειδιά (Currency,
# KEY_COST) — αν δεν φτάνουν, δείχνει μήνυμα λάθους αντί να προχωρήσει.
#
# ΣΗΜΕΙΩΣΗ: αυτή τη στιγμή ΟΛΑ τα δωμάτια (Armory/Kitchen/Library/Chapel)
# έχουν συνθήκη κλειδιού (CONDITIONS), οπότε αυτό το popup δεν
# ενεργοποιείται ποτέ στην πράξη — υπάρχει έτοιμο για μελλοντικές περιοχές
# χωρίς συνθήκη.

signal continue_pressed

func _ready() -> void:
	hide()
	%Dim.gui_input.connect(_on_dim_input)
	%CloseButton.pressed.connect(close_popup)
	%ContinueButton.pressed.connect(_on_continue_pressed)

## tex == null -> δείχνει το placeholder μήνυμα αντί για εικόνα.
func open_with(tex: Texture2D) -> void:
	%NoKeyLabel.hide()
	if tex:
		%ExerciseImage.texture = tex
		%ExerciseImage.show()
		%Placeholder.hide()
	else:
		%ExerciseImage.hide()
		%Placeholder.show()
	show()

func close_popup() -> void:
	hide()

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_popup()

func _on_continue_pressed() -> void:
	continue_pressed.emit()

## Καλείται από το castle_popup.gd όταν δεν φτάνουν τα Κλειδιά για είσοδο.
func show_no_key_message() -> void:
	%NoKeyLabel.show()
