extends Control

# Popup κάστρου: ανοίγει από το κουμπί SideQuest.
#
# Armory/Kitchen/Library/Chapel/Cellar/GreatHall/Dungeons: πύλη με συνθήκη
# (ConditionKeyPopup) — ο παίκτης επιλέγει κατηγορία κλειδιών και σέρνει
# (drag and drop) ένα-ένα πάνω στην πύλη. Κάθε συνθήκη είναι mode "AND"
# (χρειάζονται ΟΛΑ τα clauses) ή "OR" (αρκεί ΕΝΑ), βλ. CONDITIONS παρακάτω.
# Αν ένα κλειδί δεν ικανοποιεί κανένα ανεκπλήρωτο clause, σπάει και
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
#
# Αλυσίδα του "εκτεταμένου" side quest (βλ. Συνθήκες_και_Λύσεις.pdf):
# Chapel (μπαίνεις με x>5 ΚΑΙ ch='Κ', βλ. LIBRARY_SPOTS) -> μέσα δίνει τα
# κλειδιά της Λύσης 1 (6, 14, Αληθής) -> Cellar (Συνθήκη 1: (x+y=20) Ή flag)
# -> μέσα δίνει τα κλειδιά της Λύσης 2 (8, Αληθής) -> Great Hall (Συνθήκη 2:
# (n MOD 2 = 0) ΚΑΙ flag) -> μέσα δίνει τα κλειδιά της Λύσης 3 (19, Ψευδής)
# -> Dungeons (Συνθήκη 3: (grade >= 18) Ή bonus).
#
# Η αλυσίδα συνεχίζεται "ανοδικά" στον χάρτη (βλ. Νέες_Συνθήκες_και_Λύσεις.pdf):
# Dungeons -> μέσα δίνει τα κλειδιά της Νέας Λύσης 1 (12, 8, 'M') ->
# King's Chamber (Νέα Συνθήκη 1: (a+b=20) ΚΑΙ 'A'<=char<='Z') -> μέσα δίνει
# τα κλειδιά της Νέας Λύσης 2 (60, 1) -> Throne Room (Νέα Συνθήκη 2: x>50
# ΚΑΙ k>0) -> μέσα δίνει τα κλειδιά της Νέας Λύσης 3 (Ψευδής, '7') ->
# Main Bailey (Νέα Συνθήκη 3: ΟΧΙ(key) ΚΑΙ '0'<=digit<='9') — τελικό δωμάτιο.

const ARMORY_TEX := preload("res://Εικόνες/armory.png")
const CHAPEL_TEX := preload("res://Εικόνες/chapel.png")
const LIBRARY_TEX := preload("res://Εικόνες/library.png")
const KITCHEN_TEX := preload("res://Εικόνες/kitchen.png")
const CELLAR_TEX := preload("res://Εικόνες/cellar.png")
const GREAT_HALL_TEX := preload("res://Εικόνες/great_hall.png")
const DUNGEONS_TEX := preload("res://Εικόνες/dungeons.png")
const THRONE_ROOM_TEX := preload("res://Εικόνες/throne_room.png")
const KINGS_CHAMBER_TEX := preload("res://Εικόνες/kings_chamber.png")
const MAIN_BAILEY_TEX := preload("res://Εικόνες/main_bailey.png")

const ROOM_TEXTURES := {
	"armory": ARMORY_TEX,
	"chapel": CHAPEL_TEX,
	"library": LIBRARY_TEX,
	"kitchen": KITCHEN_TEX,
	"cellar": CELLAR_TEX,
	"great_hall": GREAT_HALL_TEX,
	"dungeons": DUNGEONS_TEX,
	"throne_room": THRONE_ROOM_TEX,
	"kings_chamber": KINGS_CHAMBER_TEX,
	"main_bailey": MAIN_BAILEY_TEX,
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

# Λατινικά όρια 'A'-'Ζ' και ψηφία '0'-'9' — για τις συνθήκες της "ανοδικής"
# αλυσίδας Dungeons -> King's Chamber -> Throne Room -> Main Bailey παρακάτω.
const CHAR_A_CODE := 65
const CHAR_Z_CODE := 90
const CHAR_ZERO_CODE := 48
const CHAR_NINE_CODE := 57

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

# ── Chapel: βωμός (τιμή 6) + άμβωνας (τιμή 14), αριθμητικά· δεξί παράθυρο
# (Αληθής), λογικό — μαζί αποτελούν τη Λύση 1 (βλ. CONDITIONS/"cellar") ────
const CHAPEL_ALTAR_RECT := Rect2(400, 810, 270, 140)
const CHAPEL_PULPIT_RECT := Rect2(0, 1100, 150, 220)
const CHAPEL_WINDOW_RECT := Rect2(830, 380, 210, 230)

const CHAPEL_SPOTS := {
	"Chest": {"id": "chapel_altar", "rect": CHAPEL_ALTAR_RECT, "value": 6, "category": CATEGORY_NUMERIC},
	"Grindstone": {"id": "chapel_pulpit", "rect": CHAPEL_PULPIT_RECT, "value": 14, "category": CATEGORY_NUMERIC},
	"Basket": {"id": "chapel_window", "rect": CHAPEL_WINDOW_RECT, "value": true, "category": CATEGORY_LOGICAL},
}

# ── Cellar: το χειρόγραφο πάνω στο χαλί (τιμή 8, αριθμητικός) + το κιβώτιο
# δίπλα στο πέρασμα (Αληθής, λογικό) — μαζί η Λύση 2 (βλ. CONDITIONS/
# "great_hall") ─────────────────────────────────────────────────────────────
const CELLAR_SCROLL_RECT := Rect2(482, 1382, 161, 154)
const CELLAR_CRATE_RECT := Rect2(568, 883, 107, 192)

const CELLAR_SPOTS := {
	"Chest": {"id": "cellar_scroll", "rect": CELLAR_SCROLL_RECT, "value": 8, "category": CATEGORY_NUMERIC},
	"Grindstone": {"id": "cellar_crate", "rect": CELLAR_CRATE_RECT, "value": true, "category": CATEGORY_LOGICAL},
}

# ── Great Hall: το μετάλλιο στο πάτωμα (τιμή 19, αριθμητικός) + το σημείωμα
# στο τραπέζι (Ψευδής, λογικό) — μαζί η Λύση 3 (βλ. CONDITIONS/"dungeons") ──
const GREAT_HALL_MEDAL_RECT := Rect2(54, 1498, 139, 192)
const GREAT_HALL_NOTE_RECT := Rect2(910, 1459, 140, 173)

const GREAT_HALL_SPOTS := {
	"Chest": {"id": "great_hall_medal", "rect": GREAT_HALL_MEDAL_RECT, "value": 19, "category": CATEGORY_NUMERIC},
	"Grindstone": {"id": "great_hall_note", "rect": GREAT_HALL_NOTE_RECT, "value": false, "category": CATEGORY_LOGICAL},
}

# ── "Ανοδική" αλυσίδα (βλ. Νέες_Συνθήκες_και_Λύσεις.pdf) — συνέχεια της
# παραπάνω αλυσίδας ΠΕΡΑ από τα Dungeons, αυτή τη φορά ανεβαίνοντας στον
# χάρτη: Dungeons -> μέσα δίνει τα κλειδιά της Νέας Λύσης 1 (12, 8, 'M') ->
# King's Chamber (Νέα Συνθήκη 1: (a+b=20) ΚΑΙ ('A'<=char<='Z')) -> μέσα
# δίνει τα κλειδιά της Νέας Λύσης 2 (60, 1) -> Throne Room (Νέα Συνθήκη 2:
# (x>50) ΚΑΙ (k>0)) -> μέσα δίνει τα κλειδιά της Νέας Λύσης 3 (Ψευδής, '7')
# -> Main Bailey (Νέα Συνθήκη 3: ΟΧΙ(key) ΚΑΙ ('0'<=digit<='9')) — τελικό
# δωμάτιο, χωρίς άλλα κρυμμένα κλειδιά.
#
# Dungeons: το μάτσο κλειδιά πάνω στον πάγκο (τιμή 12) + η κρεμαστή ποδιά
# δίπλα (τιμή 8), αριθμητικά· το τυλιγμένο χειρόγραφο στο ράφι (χαρακτήρας
# 'M'), χαρακτήρας.
const DUNGEONS_DESK_RECT := Rect2(640, 1010, 130, 200)
const DUNGEONS_APRON_RECT := Rect2(775, 950, 73, 314)
const DUNGEONS_SCROLL_RECT := Rect2(290, 500, 110, 70)

const DUNGEONS_SPOTS := {
	"Chest": {"id": "dungeons_keys", "rect": DUNGEONS_DESK_RECT, "value": 12, "category": CATEGORY_NUMERIC},
	"Grindstone": {"id": "dungeons_apron", "rect": DUNGEONS_APRON_RECT, "value": 8, "category": CATEGORY_NUMERIC},
	"Basket": {"id": "dungeons_scroll", "rect": DUNGEONS_SCROLL_RECT, "value": "M", "category": CATEGORY_CHARACTER},
}

# King's Chamber: το ανοιχτό κοσμηματοθήκη-σεντούκι (τιμή 60) + το γραφείο
# με το βιβλίο (τιμή 1), αριθμητικά.
const KINGS_CHAMBER_CHEST_RECT := Rect2(450, 960, 190, 160)
const KINGS_CHAMBER_DESK_RECT := Rect2(660, 960, 188, 260)

const KINGS_CHAMBER_SPOTS := {
	"Chest": {"id": "kings_chamber_chest", "rect": KINGS_CHAMBER_CHEST_RECT, "value": 60, "category": CATEGORY_NUMERIC},
	"Grindstone": {"id": "kings_chamber_desk", "rect": KINGS_CHAMBER_DESK_RECT, "value": 1, "category": CATEGORY_NUMERIC},
}

# Throne Room: το σεντούκι με το στέμμα (Ψευδής), λογικό + το χειρόγραφο με
# το φτερό (χαρακτήρας '7'), χαρακτήρας.
const THRONE_ROOM_CHEST_RECT := Rect2(445, 955, 195, 150)
const THRONE_ROOM_SCROLL_RECT := Rect2(640, 950, 208, 260)

const THRONE_ROOM_SPOTS := {
	"Chest": {"id": "throne_room_chest", "rect": THRONE_ROOM_CHEST_RECT, "value": false, "category": CATEGORY_LOGICAL},
	"Grindstone": {"id": "throne_room_scroll", "rect": THRONE_ROOM_SCROLL_RECT, "value": "7", "category": CATEGORY_CHARACTER},
}

# Εικόνα άσκησης ανά περιοχή (μόνο για τις περιοχές που ΔΕΝ έχουν συνθήκη
# κλειδιού). load() αντί για preload() ώστε να μην σκάει η σκηνή αν λείπει.
const EXERCISE_PATHS := {}

const KEY_CURRENCY := "Κλειδιά"
const KEY_COST := 1

# Περιοχές που μπαίνουν με το παζλ συνθήκης (ConditionKeyPopup) αντί για το
# παλιό ExercisePopup+Currency.
#   mode: "AND" (προεπιλογή, χρειάζονται ΟΛΑ τα clauses) ή "OR" (αρκεί ΕΝΑ).
#   clauses: λίστα από απαιτήσεις-κλειδιών, βλ. Scripts/condition_key_popup.gd
#     για την πλήρη περιγραφή των τύπων "range" (προεπιλογή)/"mod"/"sum".
#
# Kitchen "k >= 3 ΚΑΙ k <= 5": 2 ΙΔΙΑ range clauses (χρειάζονται 2 αριθμητικά
# κλειδιά μέσα σε [3, 5], ένα-ένα).
#
# Library "(ΑΛΗΘΗΣ ΚΑΙ key) Ή ΨΕΥΔΗΣ = ΨΕΥΔΗΣ": ΑΛΗΘΗΣ ΚΑΙ key ισούται με
# key, και key Ή ΨΕΥΔΗΣ ισούται επίσης με key, άρα η συνθήκη απλοποιείται σε
# key = ΨΕΥΔΗΣ.
#
# Chapel "(x > 5) ΚΑΙ (ch = 'Κ')": 2 ΔΙΑΦΟΡΕΤΙΚΑ clauses σε 2 διαφορετικές
# κατηγορίες — ένα αριθμητικό κλειδί > 5 ΚΑΙ ένα κλειδί χαρακτήρων 'Κ'
# (βλ. LIBRARY_SPOTS για το πού βρίσκονται αυτά τα δύο κλειδιά).
#
# Cellar — Συνθήκη 1 "((x + y) = 20) Ή flag": mode OR — "sum" clause (2
# αριθμητικά κλειδιά που το άθροισμά τους φτάνει ακριβώς 20, π.χ. 6+14) Ή
# ένα λογικό κλειδί Αληθής (βλ. CHAPEL_SPOTS — Λύση 1: 6, 14, Αληθής).
#
# Great Hall — Συνθήκη 2 "(n MOD 2 = 0) ΚΑΙ (flag = ΑΛΗΘΗΣ)": mode AND —
# ένα αριθμητικό κλειδί άρτιο ΚΑΙ ένα λογικό κλειδί Αληθής (βλ. CELLAR_SPOTS
# — Λύση 2: 8, Αληθής).
#
# Dungeons — Συνθήκη 3 "(grade >= 18) Ή (bonus = TRUE)": mode OR — ένα
# αριθμητικό κλειδί >= 18 Ή ένα λογικό κλειδί Αληθής (βλ. GREAT_HALL_SPOTS —
# Λύση 3: 19, Ψευδής — αρκεί το 19, το bonus=Ψευδής δεν χρειάζεται εδώ).
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
	"cellar": {
		"text": "((x + y) = 20) Ή flag",
		"mode": "OR",
		"clauses": [
			{"category": CATEGORY_NUMERIC, "type": "sum", "target": 20},
			{"category": CATEGORY_LOGICAL, "min": 1, "max": 1},
		],
	},
	"great_hall": {
		"text": "(n MOD 2 = 0) ΚΑΙ (flag = ΑΛΗΘΗΣ)",
		"clauses": [
			{"category": CATEGORY_NUMERIC, "type": "mod", "modulus": 2, "remainder": 0},
			{"category": CATEGORY_LOGICAL, "min": 1, "max": 1},
		],
	},
	"dungeons": {
		"text": "(grade >= 18) Ή (bonus = TRUE)",
		"mode": "OR",
		"clauses": [
			{"category": CATEGORY_NUMERIC, "min": 18, "max": NO_UPPER_BOUND},
			{"category": CATEGORY_LOGICAL, "min": 1, "max": 1},
		],
	},

	# Νέα Συνθήκη 1 "(a + b = 20) ΚΑΙ ('A' <= char <= 'Z')": mode AND — "sum"
	# clause (2 αριθμητικά κλειδιά που αθροίζουν ακριβώς 20, π.χ. 12+8) ΚΑΙ
	# ένα κλειδί χαρακτήρων στο ['A','Z'] (βλ. DUNGEONS_SPOTS — Νέα Λύση 1:
	# 12, 8, 'M').
	"kings_chamber": {
		"text": "(a + b = 20) ΚΑΙ ('A' <= char <= 'Z')",
		"clauses": [
			{"category": CATEGORY_NUMERIC, "type": "sum", "target": 20},
			{"category": CATEGORY_CHARACTER, "min": CHAR_A_CODE, "max": CHAR_Z_CODE},
		],
	},

	# Νέα Συνθήκη 2 "(x > 50) ΚΑΙ (k > 0)" (η "Ή vip" εναλλακτική της
	# εκφώνησης δεν χρειάζεται εδώ αφού η Λύση ικανοποιεί το x>50 απευθείας,
	# βλ. KINGS_CHAMBER_SPOTS — Νέα Λύση 2: 60, 1): mode AND — 2 αριθμητικά
	# κλειδιά, ένα > 50 ΚΑΙ ένα > 0.
	"throne_room": {
		"text": "(x > 50) ΚΑΙ (k > 0)",
		"clauses": [
			{"category": CATEGORY_NUMERIC, "min": 51, "max": NO_UPPER_BOUND},
			{"category": CATEGORY_NUMERIC, "min": 1, "max": NO_UPPER_BOUND},
		],
	},

	# Νέα Συνθήκη 3 "ΟΧΙ(key) ΚΑΙ ('0' <= digit <= '9')": mode AND — ένα
	# λογικό κλειδί Ψευδής (ΟΧΙ(key) = key ΨΕΥΔΗΣ) ΚΑΙ ένα κλειδί χαρακτήρων
	# ψηφίο ['0','9'] (βλ. THRONE_ROOM_SPOTS — Νέα Λύση 3: Ψευδής, '7').
	# Τελευταίο δωμάτιο της "ανοδικής" αλυσίδας — δεν δίνει άλλα κλειδιά.
	"main_bailey": {
		"text": "ΟΧΙ(key) ΚΑΙ ('0' <= digit <= '9')",
		"clauses": [
			{"category": CATEGORY_LOGICAL, "min": 0, "max": 0},
			{"category": CATEGORY_CHARACTER, "min": CHAR_ZERO_CODE, "max": CHAR_NINE_CODE},
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

func _on_cellar_pressed() -> void:
	_open_gate("cellar")

func _on_great_hall_pressed() -> void:
	_open_gate("great_hall")

func _on_dungeons_pressed() -> void:
	_open_gate("dungeons")

func _on_main_bailey_pressed() -> void:
	_open_gate("main_bailey")

func _on_throne_room_pressed() -> void:
	_open_gate("throne_room")

func _on_kings_chamber_pressed() -> void:
	_open_gate("kings_chamber")

func _open_gate(room_id: String) -> void:
	_pending_room = room_id
	if _unlocked_rooms.get(room_id, false):
		_enter_room(room_id)
		return
	if CONDITIONS.has(room_id):
		var cfg: Dictionary = CONDITIONS[room_id]
		%ConditionKeyPopup.open_for(str(cfg["text"]), cfg["clauses"], str(cfg.get("mode", "AND")))
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
		"chapel":
			%RoomImagePopup.open_with(tex, CHAPEL_SPOTS)
		"cellar":
			%RoomImagePopup.open_with(tex, CELLAR_SPOTS)
		"great_hall":
			%RoomImagePopup.open_with(tex, GREAT_HALL_SPOTS)
		"dungeons":
			%RoomImagePopup.open_with(tex, DUNGEONS_SPOTS)
		"kings_chamber":
			%RoomImagePopup.open_with(tex, KINGS_CHAMBER_SPOTS)
		"throne_room":
			%RoomImagePopup.open_with(tex, THRONE_ROOM_SPOTS)
		_:
			%RoomImagePopup.open_with(tex)
