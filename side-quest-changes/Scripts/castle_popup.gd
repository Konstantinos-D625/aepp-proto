extends Control

# Popup κάστρου: ανοίγει από το κουμπί SideQuest.
#
# Armory/Kitchen/Library/Chapel: πύλη με συνθήκη (ConditionKeyPopup) — ο
# παίκτης επιλέγει κατηγορία κλειδιών και σέρνει (drag and drop) ένα-ένα
# πάνω στην πύλη. Κάθε συνθήκη είναι μια λίστα από "clauses" (βλ. CONDITIONS
# παρακάτω) — χρειάζονται ΟΛΑ (λογικό ΚΑΙ), το καθένα με το δικό του σωστό
# κλειδί. Αν ένα κλειδί δεν ικανοποιεί κανένα ανεκπλήρωτο clause, σπάει και
# ξαναδοκιμάζει. Μόλις ανοίξει μια πύλη μία φορά (βλ. _unlocked_rooms), οι
# επόμενες είσοδοι πάνε κατευθείαν στο δωμάτιο, χωρίς να ξαναζητείται η
# συνθήκη.
#
# Μέσα σε κάθε δωμάτιο υπάρχουν μέχρι 4 κρυμμένα σημεία (κοινά κουμπιά
# Chest/Grindstone/Basket/Shelf, βλ. RoomImagePopup) που δίνουν κλειδιά· ο
# ΡΟΛΟΣ τους (τιμή/κατηγορία/θέση) ορίζεται εδώ, ανά δωμάτιο (βλ. *_SPOTS
# παρακάτω) — κάθε σημείο δίνει το κλειδί του μία μόνο φορά συνολικά. Το
# "id" κάθε spot ΠΡΕΠΕΙ να είναι μοναδικό σε ΟΛΟ το παιχνίδι (όχι μόνο μέσα
# στο δωμάτιο) — το RoomImagePopup instance (και τα κουμπιά Chest/Grindstone/
# Basket/Shelf) είναι κοινό/μόνιμο για όλα τα δωμάτια, οπότε αν δύο δωμάτια
# ξαναχρησιμοποιούσαν το ίδιο id θα "μοιράζονταν" κατά λάθος το ίδιο
# already-collected flag.

const ARMORY_TEX := preload("res://Εικόνες/armory.png")
const CHAPEL_TEX := preload("res://Εικόνες/chapel.png")
const LIBRARY_TEX := preload("res://Εικόνες/library.png")
const KITCHEN_TEX := preload("res://Εικόνες/kitchen.png")

const ROOM_TEXTURES := {
	"armory": ARMORY_TEX,
	"chapel": CHAPEL_TEX,
	"library": LIBRARY_TEX,
	"kitchen": KITCHEN_TEX,
}

const CATEGORY_NUMERIC   := "Αριθμητικό Κλειδί"
const CATEGORY_LOGICAL   := "Λογικό Κλειδί"
const CATEGORY_CHARACTER := "Κλειδί Χαρακτήρων"

# Δεν υπάρχει κάτω/άνω όριο για συνθήκες τύπου "k <= X" / "x > Y".
const NO_LOWER_BOUND := -2147483648
const NO_UPPER_BOUND := 2147483647

# Unicode κωδικός του 'Κ' (Ελληνικό κεφαλαίο Κάππα, U+039A) — για τη
# συνθήκη του Chapel (ch = 'Κ'), βλ. CONDITIONS παρακάτω.
const CHAR_K_CODE := 922

# ── Armory: σεντούκι (τιμή 4) + τροχιστική πέτρα (τιμή 3), αριθμητικά ──────
const ARMORY_CHEST_RECT := Rect2(125, 890, 335, 270)
const ARMORY_GRINDSTONE_RECT := Rect2(814, 1019, 223, 209)

const ARMORY_SPOTS := {
	"Chest": {"id": "armory_chest", "rect": ARMORY_CHEST_RECT, "value": 4, "category": CATEGORY_NUMERIC},
	"Grindstone": {"id": "armory_grindstone", "rect": ARMORY_GRINDSTONE_RECT, "value": 3, "category": CATEGORY_NUMERIC},
}

# ── Kitchen: καλάθια (Αληθής) + ράφι (Ψευδής), λογικά ──────────────────────
const KITCHEN_BASKET_RECT := Rect2(660, 1333, 265, 119)
const KITCHEN_SHELF_RECT := Rect2(88, 614, 279, 251)

const KITCHEN_SPOTS := {
	"Basket": {"id": "kitchen_basket", "rect": KITCHEN_BASKET_RECT, "value": true, "category": CATEGORY_LOGICAL},
	"Shelf": {"id": "kitchen_shelf", "rect": KITCHEN_SHELF_RECT, "value": false, "category": CATEGORY_LOGICAL},
}

# ── Library: το τυλιγμένο χειρόγραφο πάνω στο τραπέζι (τιμή 7 — αριθμητικός,
# > 5) + η μικρή βιβλιοθήκη αριστερά (χαρακτήρας 'Κ') ──────────────────────
const LIBRARY_SCROLL_RECT := Rect2(536, 760, 140, 120)
const LIBRARY_BOOKSHELF_RECT := Rect2(10, 760, 110, 280)

const LIBRARY_SPOTS := {
	"Chest": {"id": "library_scroll", "rect": LIBRARY_SCROLL_RECT, "value": 7, "category": CATEGORY_NUMERIC},
	"Grindstone": {"id": "library_bookshelf", "rect": LIBRARY_BOOKSHELF_RECT, "value": "Κ", "category": CATEGORY_CHARACTER},
}

# Εικόνα άσκησης ανά περιοχή (μόνο για τις περιοχές που ΔΕΝ έχουν συνθήκη
# κλειδιού). load() αντί για preload() ώστε να μην σκάει η σκηνή αν λείπει.
const EXERCISE_PATHS := {}

const KEY_CURRENCY := "Κλειδιά"
const KEY_COST := 1

# Περιοχές που μπαίνουν με το παζλ συνθήκης (ConditionKeyPopup) αντί για το
# παλιό ExercisePopup+Currency. clauses: λίστα από {"category", "min", "max"}
# — ΕΝΑ ανά κλειδί που χρειάζεται η συνθήκη (χρειάζονται ΟΛΑ, λογικό ΚΑΙ).
# Η τιμή ενός κλειδιού μετατρέπεται σε int πριν συγκριθεί με [min, max]:
# false -> 0, true -> 1, χαρακτήρας -> ο Unicode κωδικός του (βλ.
# ConditionKeyPopup._as_int).
#
# Kitchen "k >= 3 ΚΑΙ k <= 5": 2 ΙΔΙΑ clauses (χρειάζονται 2 αριθμητικά
# κλειδιά μέσα σε [3, 5], ένα-ένα).
#
# Library "(ΑΛΗΘΗΣ ΚΑΙ key) Ή ΨΕΥΔΗΣ = ΨΕΥΔΗΣ": ΑΛΗΘΗΣ ΚΑΙ key ισούται με
# key, και key Ή ΨΕΥΔΗΣ ισούται επίσης με key, άρα η συνθήκη απλοποιείται σε
# key = ΨΕΥΔΗΣ.
#
# Chapel "(x > 5) ΚΑΙ (ch = 'Κ')": 2 ΔΙΑΦΟΡΕΤΙΚΑ clauses σε 2 διαφορετικές
# κατηγορίες — ένα αριθμητικό κλειδί > 5 ΚΑΙ ένα κλειδί χαρακτήρων 'Κ'
# (βλ. LIBRARY_SPOTS για το πού βρίσκονται αυτά τα δύο κλειδιά).
const CONDITIONS := {
	"armory": {
		"text": "k <= 8",
		"clauses": [{"category": CATEGORY_NUMERIC, "min": NO_LOWER_BOUND, "max": 8}],
	},
	"kitchen": {
		"text": "k >= 3 ΚΑΙ k <= 5",
		"clauses": [
			{"category": CATEGORY_NUMERIC, "min": 3, "max": 5},
			{"category": CATEGORY_NUMERIC, "min": 3, "max": 5},
		],
	},
	"library": {
		"text": "(ΑΛΗΘΗΣ ΚΑΙ key) Ή ΨΕΥΔΗΣ = ΨΕΥΔΗΣ",
		"clauses": [{"category": CATEGORY_LOGICAL, "min": 0, "max": 0}],
	},
	"chapel": {
		"text": "(x > 5) ΚΑΙ (ch = 'Κ')",
		"clauses": [
			{"category": CATEGORY_NUMERIC, "min": 6, "max": NO_UPPER_BOUND},
			{"category": CATEGORY_CHARACTER, "min": CHAR_K_CODE, "max": CHAR_K_CODE},
		],
	},
}

var _pending_room := ""

# Δωμάτια των οποίων η πύλη έχει ήδη ανοίξει μία φορά — δεν ξαναζητείται η
# συνθήκη σε επόμενη είσοδο, πάει κατευθείαν στο δωμάτιο.
var _unlocked_rooms: Dictionary = {}

func _ready() -> void:
	hide()
	%Dim.gui_input.connect(_on_dim_input)
	%ConditionKeyPopup.key_accepted.connect(_on_condition_key_accepted)

func open() -> void:
	show()

func close_popup() -> void:
	hide()

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_popup()

func _on_armory_pressed() -> void:
	_open_gate("armory")

func _on_chapel_pressed() -> void:
	_open_gate("chapel")

func _on_library_pressed() -> void:
	_open_gate("library")

func _on_kitchen_pressed() -> void:
	_open_gate("kitchen")

func _open_gate(room_id: String) -> void:
	_pending_room = room_id
	if _unlocked_rooms.get(room_id, false):
		_enter_room(room_id)
		return
	if CONDITIONS.has(room_id):
		var cfg: Dictionary = CONDITIONS[room_id]
		%ConditionKeyPopup.open_for(str(cfg["text"]), cfg["clauses"])
	else:
		%ExercisePopup.open_with(_load_exercise_texture(room_id))

func _load_exercise_texture(room_id: String) -> Texture2D:
	var path: String = EXERCISE_PATHS.get(room_id, "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path)

func _on_condition_key_accepted() -> void:
	_unlocked_rooms[_pending_room] = true
	_enter_room(_pending_room)

func _on_exercise_continue() -> void:
	if Currency.get_amount(KEY_CURRENCY) >= KEY_COST:
		Currency.spend({KEY_CURRENCY: KEY_COST})
		%ExercisePopup.close_popup()
		_enter_room(_pending_room)
	else:
		%ExercisePopup.show_no_key_message()

func _enter_room(room_id: String) -> void:
	var tex: Texture2D = ROOM_TEXTURES.get(room_id)
	if tex == null:
		return
	match room_id:
		"armory":
			%RoomImagePopup.open_with(tex, ARMORY_SPOTS)
		"kitchen":
			%RoomImagePopup.open_with(tex, KITCHEN_SPOTS)
		"library":
			%RoomImagePopup.open_with(tex, LIBRARY_SPOTS)
		_:
			%RoomImagePopup.open_with(tex)
