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

const LOCK_TEX := preload("res://Εικόνες/lock.png")
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

# Το mini boss που κρατά το bootstrap κλειδί του side quest (τιμή 8 — βλ.
# Scripts/mini_boss_popup.gd -> BOSS_DEFS["goblin"]["key_reward"]). Η Armory
# είναι η μοναδική πύλη χωρίς δικά της κλειδιά ήδη μέσα στο κάστρο, οπότε
# όσο δεν έχει νικηθεί ο καλικάντζαρος δεν υπάρχει ΚΑΝΕΝΑΣ τρόπος να ανοίξει
# καμία πύλη — το κάστρο μένει ΚΛΕΙΔΩΜΕΝΟ (βλ. open()/_build_locked_panel()).
const GOBLIN_BOSS_ID := "goblin"

# ── Παλέτα οθόνης «κλειδωμένου» κάστρου (ίδια γραμμή χρυσό/ξύλο/περγαμηνή με
# τα υπόλοιπα popups του project, π.χ. mini_boss_popup.gd) ────────────────
const C0        := Color(0, 0, 0, 0)
const C_GOLD    := Color(0.940, 0.760, 0.160)
const C_GOLD_D  := Color(0.360, 0.278, 0.058)
const C_GOLD_S  := Color(1.000, 0.920, 0.560)
const C_PARCH   := Color(0.900, 0.880, 0.820)
const C_WOOD    := Color(0.200, 0.120, 0.052)
const C_WOOD_D  := Color(0.130, 0.075, 0.028)

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
# Ράφι κάτω-δεξιά, χωρίς επικάλυψη με τα 3 παραπάνω — ΚΑΤΑ ΠΡΟΣΕΓΓΙΣΗ θέση,
# δεν έχει επιβεβαιωθεί οπτικά πάνω στο chapel.png· προσάρμοσέ το αν χρειαστεί.
const CHAPEL_SHELF_RECT := Rect2(850, 1200, 200, 220)

# Το "golden_sword" (Σπαθί_2, βλ. weapon_inventory.gd) δεν είναι στο Shop —
# παίρνεται ΜΟΝΟ πατώντας αυτό το κρυμμένο σημείο "?" στο Chapel, ΙΔΙΟ μοτίβο
# hint-mark με τα κλειδιά (βλ. room_image_popup.gd::_add_hint_mark).
const GOLDEN_SWORD_ID := "Σπαθί_2"

const CHAPEL_SPOTS := {
	"Chest": {"id": "chapel_altar", "rect": CHAPEL_ALTAR_RECT, "value": 6, "category": CATEGORY_NUMERIC},
	"Grindstone": {"id": "chapel_pulpit", "rect": CHAPEL_PULPIT_RECT, "value": 14, "category": CATEGORY_NUMERIC},
	"Basket": {"id": "chapel_window", "rect": CHAPEL_WINDOW_RECT, "value": true, "category": CATEGORY_LOGICAL},
	"Shelf": {"id": "chapel_golden_sword", "rect": CHAPEL_SHELF_RECT, "item_id": GOLDEN_SWORD_ID, "item_catalog": "weapon"},
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

# ── Ανταμοιβή ολοκλήρωσης του side quest — δίνεται ΜΙΑ φορά, την πρώτη φορά
# που ο παίκτης φτάνει στο Main Bailey (τελικό δωμάτιο, βλ. _enter_room/
# _grant_completion_reward). Το "golden_armour" (Θώρακας_3, βλ.
# armor_inventory.gd) δεν είναι στο Shop — παίρνεται ΜΟΝΟ έτσι.
const GOLDEN_ARMOR_ID := "Θώρακας_3"
const COMPLETION_REWARD_CURRENCY := {
	"Χαλκός": 50,
	"Σίδερο": 50,
	"Δέρμα": 50,
	"Κέρμα": 150,
}

# Περιοχές που μπαίνουν με το παζλ συνθήκης (ConditionKeyPopup) αντί για το
# παλιό ExercisePopup+Currency.
#   mode: "AND" (προεπιλογή, χρειάζονται ΟΛΑ τα clauses) ή "OR" (αρκεί ΕΝΑ).
#   clauses: λίστα από απαιτήσεις-κλειδιών, βλ. Scripts/condition_key_popup.gd
#     για την πλήρη περιγραφή των τύπων "range" (προεπιλογή)/"mod"/"sum".
#
# Όλες οι εκφωνήσεις παρακάτω χρησιμοποιούν το γενικό "KEY" ως όνομα
# μεταβλητής (αντί για x/y/ch/k/n/a/b/char/digit/flag/grade/bonus, ό,τι
# υπήρχε πριν σε κάθε δωμάτιο) — πιο σαφές για τον παίκτη ότι κάθε "KEY" είναι
# ΕΝΑ κλειδί που πρέπει να ρίξει, χωρίς να χρειάζεται να μαντέψει τι σημαίνει
# κάθε διαφορετικό γράμμα. Όταν μια συνθήκη χρειάζεται 2 ΔΙΑΦΟΡΕΤΙΚΑ κλειδιά
# (π.χ. ένα "sum" clause), εμφανίζεται ως "KEY + KEY" — κάθε εμφάνιση είναι
# ένα ξεχωριστό κλειδί που ρίχνεται ένα-ένα, όχι η ίδια τιμή δύο φορές.
#
# Kitchen "KEY >= 3 ΚΑΙ KEY <= 5": 2 ΙΔΙΑ range clauses (χρειάζονται 2
# αριθμητικά κλειδιά μέσα σε [3, 5], ένα-ένα).
#
# Library "(ΑΛΗΘΗΣ ΚΑΙ KEY) Ή ΨΕΥΔΗΣ = ΨΕΥΔΗΣ": ΑΛΗΘΗΣ ΚΑΙ KEY ισούται με
# KEY, και KEY Ή ΨΕΥΔΗΣ ισούται επίσης με KEY, άρα η συνθήκη απλοποιείται σε
# KEY = ΨΕΥΔΗΣ.
#
# Chapel "(KEY > 5) ΚΑΙ (KEY = 'Κ')": 2 ΔΙΑΦΟΡΕΤΙΚΑ clauses σε 2 διαφορετικές
# κατηγορίες — ένα αριθμητικό κλειδί > 5 ΚΑΙ ένα κλειδί χαρακτήρων 'Κ'
# (βλ. LIBRARY_SPOTS για το πού βρίσκονται αυτά τα δύο κλειδιά).
#
# Cellar — Συνθήκη 1 "((KEY + KEY) = 20) Ή (KEY = ΑΛΗΘΗΣ)": mode OR — "sum"
# clause (2 αριθμητικά κλειδιά που το άθροισμά τους φτάνει ακριβώς 20, π.χ.
# 6+14) Ή ένα λογικό κλειδί Αληθής (βλ. CHAPEL_SPOTS — Λύση 1: 6, 14, Αληθής).
# ΔΙΟΡΘΩΘΗΚΕ: πριν έλειπε το "= ΑΛΗΘΗΣ" (έλεγε απλώς "Ή flag", ημιτελής
# πρόταση).
#
# Great Hall — Συνθήκη 2 "(KEY MOD 2 = 0) ΚΑΙ (KEY = ΑΛΗΘΗΣ)": mode AND —
# ένα αριθμητικό κλειδί άρτιο ΚΑΙ ένα λογικό κλειδί Αληθής (βλ. CELLAR_SPOTS
# — Λύση 2: 8, Αληθής).
#
# Dungeons — Συνθήκη 3 "(KEY >= 18) Ή (KEY = ΑΛΗΘΗΣ)": mode OR — ένα
# αριθμητικό κλειδί >= 18 Ή ένα λογικό κλειδί Αληθής (βλ. GREAT_HALL_SPOTS —
# Λύση 3: 19, Ψευδής — αρκεί το 19, το bonus=Ψευδής δεν χρειάζεται εδώ).
# ΔΙΟΡΘΩΘΗΚΕ: πριν έλεγε "= TRUE" (αγγλικά) αντί για "= ΑΛΗΘΗΣ", ασυνεπές με
# όλες τις άλλες εκφωνήσεις.
const CONDITIONS := {
	"armory": {
		"text": "KEY <= 8",
		"clauses": [{"category": CATEGORY_NUMERIC, "min": NO_LOWER_BOUND, "max": 8}],
	},
	"kitchen": {
		"text": "KEY >= 3 ΚΑΙ KEY <= 5",
		"clauses": [
			{"category": CATEGORY_NUMERIC, "min": 3, "max": 5},
			{"category": CATEGORY_NUMERIC, "min": 3, "max": 5},
		],
	},
	"library": {
		"text": "(ΑΛΗΘΗΣ ΚΑΙ KEY) Ή ΨΕΥΔΗΣ = ΨΕΥΔΗΣ",
		"clauses": [{"category": CATEGORY_LOGICAL, "min": 0, "max": 0}],
	},
	"chapel": {
		"text": "(KEY > 5) ΚΑΙ (KEY = 'Κ')",
		"clauses": [
			{"category": CATEGORY_NUMERIC, "min": 6, "max": NO_UPPER_BOUND},
			{"category": CATEGORY_CHARACTER, "min": CHAR_K_CODE, "max": CHAR_K_CODE},
		],
	},
	"cellar": {
		"text": "((KEY + KEY) = 20) Ή (KEY = ΑΛΗΘΗΣ)",
		"mode": "OR",
		"clauses": [
			{"category": CATEGORY_NUMERIC, "type": "sum", "target": 20},
			{"category": CATEGORY_LOGICAL, "min": 1, "max": 1},
		],
	},
	"great_hall": {
		"text": "(KEY MOD 2 = 0) ΚΑΙ (KEY = ΑΛΗΘΗΣ)",
		"clauses": [
			{"category": CATEGORY_NUMERIC, "type": "mod", "modulus": 2, "remainder": 0},
			{"category": CATEGORY_LOGICAL, "min": 1, "max": 1},
		],
	},
	"dungeons": {
		"text": "(KEY >= 18) Ή (KEY = ΑΛΗΘΗΣ)",
		"mode": "OR",
		"clauses": [
			{"category": CATEGORY_NUMERIC, "min": 18, "max": NO_UPPER_BOUND},
			{"category": CATEGORY_LOGICAL, "min": 1, "max": 1},
		],
	},

	# Νέα Συνθήκη 1 "(KEY + KEY = 20) ΚΑΙ ('A' <= KEY <= 'Z')": mode AND —
	# "sum" clause (2 αριθμητικά κλειδιά που αθροίζουν ακριβώς 20, π.χ. 12+8)
	# ΚΑΙ ένα κλειδί χαρακτήρων στο ['A','Z'] (βλ. DUNGEONS_SPOTS — Νέα Λύση 1:
	# 12, 8, 'M').
	"kings_chamber": {
		"text": "(KEY + KEY = 20) ΚΑΙ ('A' <= KEY <= 'Z')",
		"clauses": [
			{"category": CATEGORY_NUMERIC, "type": "sum", "target": 20},
			{"category": CATEGORY_CHARACTER, "min": CHAR_A_CODE, "max": CHAR_Z_CODE},
		],
	},

	# Νέα Συνθήκη 2 "(KEY > 50) ΚΑΙ (KEY > 0)" (η "Ή vip" εναλλακτική της
	# εκφώνησης δεν χρειάζεται εδώ αφού η Λύση ικανοποιεί το KEY>50 απευθείας,
	# βλ. KINGS_CHAMBER_SPOTS — Νέα Λύση 2: 60, 1): mode AND — 2 αριθμητικά
	# κλειδιά, ένα > 50 ΚΑΙ ένα > 0.
	"throne_room": {
		"text": "(KEY > 50) ΚΑΙ (KEY > 0)",
		"clauses": [
			{"category": CATEGORY_NUMERIC, "min": 51, "max": NO_UPPER_BOUND},
			{"category": CATEGORY_NUMERIC, "min": 1, "max": NO_UPPER_BOUND},
		],
	},

	# Νέα Συνθήκη 3 "ΟΧΙ(KEY) ΚΑΙ ('0' <= KEY <= '9')": mode AND — ένα
	# λογικό κλειδί Ψευδής (ΟΧΙ(KEY) = KEY ΨΕΥΔΗΣ) ΚΑΙ ένα κλειδί χαρακτήρων
	# ψηφίο ['0','9'] (βλ. THRONE_ROOM_SPOTS — Νέα Λύση 3: Ψευδής, '7').
	# Τελευταίο δωμάτιο της "ανοδικής" αλυσίδας — δεν δίνει άλλα κλειδιά.
	"main_bailey": {
		"text": "ΟΧΙ(KEY) ΚΑΙ ('0' <= KEY <= '9')",
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

# Χτίζονται ΜΙΑ φορά στο _ready() (ίδιο μοτίβο "χτίσε μία φορά, toggle
# visibility" με τα υπόλοιπα popups του project) — βλ. _build_locked_panel()/
# _build_completed_panel().
var _locked_panel: Control
var _completed_panel: Control

func _ready() -> void:
	hide()
	%Dim.gui_input.connect(_on_dim_input)
	%ConditionKeyPopup.key_accepted.connect(_on_condition_key_accepted)
	_locked_panel = _build_locked_panel()
	_completed_panel = _build_completed_panel()

## Το κάστρο μένει ΚΛΕΙΔΩΜΕΝΟ (κρυμμένος ο χάρτης, μήνυμα + hint αντ' αυτού)
## μέχρι να βρεθεί το bootstrap κλειδί — δηλαδή μέχρι να νικηθεί ο
## καλικάντζαρος (βλ. GOBLIN_BOSS_ID). Ελέγχεται ΚΑΘΕ φορά που ανοίγει το
## popup, όχι μόνο μία φορά, ώστε να ξεκλειδώνει αμέσως μόλις πετύχει η νίκη.
## Μόλις ολοκληρωθεί ΟΛΟ το side quest (GameData.is_castle_completed· βλ.
## main_bailey/_grant_completion_reward), ο χάρτης του κάστρου αντικαθίσταται
## ΜΟΝΙΜΑ από την οθόνη "Ολοκληρώθηκε" — δεν υπάρχει τίποτα άλλο να κάνει εκεί
## ο παίκτης (main_bailey ήταν το τελικό δωμάτιο, χωρίς κρυμμένα κλειδιά).
func open() -> void:
	var has_key := GameData.is_mini_boss_defeated(GOBLIN_BOSS_ID)
	var completed := GameData.is_castle_completed()
	%CastleImage.visible = has_key and not completed
	_locked_panel.visible = not has_key and not completed
	_completed_panel.visible = completed
	show()

func close_popup() -> void:
	hide()

## Οθόνη «κλειδωμένου» κάστρου — εμφανίζεται ΑΝΤΙ για τον χάρτη του κάστρου
## όσο δεν υπάρχει το bootstrap κλειδί (βλ. open()). Σκόπιμα ΔΕΝ κλείνει με
## τάπισμα στο σκοτεινό φόντο (σε αντίθεση με το Dim αλλού στο project) —
## είναι ενημερωτικό μήνυμα, όχι επιλογή, οπότε το μόνο κουμπί είναι το
## ρητό «Κλείσιμο».
func _build_locked_panel() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	const BX := 90.0
	const BY := 560.0
	const BW := 900.0
	const BH := 760.0

	var shadow := Panel.new()
	shadow.position = Vector2(BX + 8, BY + 8)
	shadow.size     = Vector2(BW, BH)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow_style := StyleBoxFlat.new()
	shadow_style.bg_color = Color(0, 0, 0, 0.55)
	shadow_style.set_corner_radius_all(18)
	shadow.add_theme_stylebox_override("panel", shadow_style)
	root.add_child(shadow)

	var panel := Panel.new()
	panel.position = Vector2(BX, BY)
	panel.size     = Vector2(BW, BH)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = C_WOOD
	panel_style.border_color = C_GOLD_D
	panel_style.set_border_width_all(5)
	panel_style.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(panel)

	var inner := Panel.new()
	inner.position = Vector2(BX + 10, BY + 10)
	inner.size     = Vector2(BW - 20, BH - 20)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = C0
	inner_style.border_color = C_GOLD_D.darkened(0.3)
	inner_style.set_border_width_all(2)
	inner_style.set_corner_radius_all(14)
	inner.add_theme_stylebox_override("panel", inner_style)
	root.add_child(inner)

	var icon := TextureRect.new()
	icon.texture = LOCK_TEX
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(BX, BY + 50)
	icon.size     = Vector2(BW, 130)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)

	var title := Label.new()
	title.text = "Το Κάστρο είναι Κλειδωμένο"
	title.position = Vector2(BX + 40, BY + 210)
	title.size     = Vector2(BW - 80, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", C_GOLD)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)

	# Το hint δείχνει καθαρά στον καλικάντζαρο (GOBLIN_BOSS_ID) χωρίς να είναι
	# απλή εντολή — «λένε πως...» ταιριάζει με το ύφος διαλόγου των NPC.
	var msg := Label.new()
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.text = "Η πύλη της Οπλοθήκης χρειάζεται ένα κλειδί για να ανοίξει — και δεν έχεις βρει κανένα ακόμα.\n\nΛένε πως ο καλικάντζαρος που κρύβεται στη σπηλιά του δάσους φυλάει κάτι τέτοιο..."
	msg.position = Vector2(BX + 60, BY + 300)
	msg.size     = Vector2(BW - 120, 300)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment   = VERTICAL_ALIGNMENT_TOP
	msg.add_theme_font_size_override("font_size", 28)
	msg.add_theme_color_override("font_color", C_PARCH)
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(msg)

	var close_btn := Button.new()
	close_btn.text = "✕  Κλείσιμο"
	close_btn.position = Vector2(BX + BW / 2.0 - 170, BY + BH - 130)
	close_btn.size     = Vector2(340, 96)
	close_btn.add_theme_font_size_override("font_size", 30)
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = C_WOOD_D
	normal_style.border_color = C_GOLD.darkened(0.15)
	normal_style.set_border_width_all(4)
	normal_style.set_corner_radius_all(10)
	normal_style.shadow_color = Color(0, 0, 0, 0.68)
	normal_style.shadow_size = 7
	close_btn.add_theme_stylebox_override("normal", normal_style)
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = C_WOOD
	hover_style.border_color = C_GOLD
	hover_style.set_border_width_all(5)
	hover_style.set_corner_radius_all(10)
	close_btn.add_theme_stylebox_override("hover", hover_style)
	close_btn.add_theme_stylebox_override("focus", StyleBoxFlat.new())
	close_btn.add_theme_color_override("font_color", C_GOLD)
	close_btn.add_theme_color_override("font_hover_color", C_GOLD_S)
	close_btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.92))
	close_btn.add_theme_constant_override("shadow_offset_x", 2)
	close_btn.add_theme_constant_override("shadow_offset_y", 3)
	close_btn.pressed.connect(close_popup)
	root.add_child(close_btn)

	root.visible = false
	return root

## Οθόνη «ολοκληρωμένου» κάστρου — εμφανίζεται ΑΝΤΙ για τον χάρτη του κάστρου
## μόλις ο παίκτης έχει ήδη πάρει την ανταμοιβή ολοκλήρωσης (βλ. open()). Ίδιο
## μοτίβο/στυλ με _build_locked_panel(), διαφορετικό εικονίδιο/μήνυμα.
func _build_completed_panel() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	const BX := 90.0
	const BY := 560.0
	const BW := 900.0
	const BH := 760.0

	var shadow := Panel.new()
	shadow.position = Vector2(BX + 8, BY + 8)
	shadow.size     = Vector2(BW, BH)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow_style := StyleBoxFlat.new()
	shadow_style.bg_color = Color(0, 0, 0, 0.55)
	shadow_style.set_corner_radius_all(18)
	shadow.add_theme_stylebox_override("panel", shadow_style)
	root.add_child(shadow)

	var panel := Panel.new()
	panel.position = Vector2(BX, BY)
	panel.size     = Vector2(BW, BH)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = C_WOOD
	panel_style.border_color = C_GOLD
	panel_style.set_border_width_all(5)
	panel_style.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(panel)

	var inner := Panel.new()
	inner.position = Vector2(BX + 10, BY + 10)
	inner.size     = Vector2(BW - 20, BH - 20)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = C0
	inner_style.border_color = C_GOLD_D.darkened(0.3)
	inner_style.set_border_width_all(2)
	inner_style.set_corner_radius_all(14)
	inner.add_theme_stylebox_override("panel", inner_style)
	root.add_child(inner)

	var icon := Label.new()
	icon.text = "🏆"
	icon.position = Vector2(BX, BY + 50)
	icon.size     = Vector2(BW, 130)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 96)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)

	var title := Label.new()
	title.text = "Το Κάστρο Ολοκληρώθηκε!"
	title.position = Vector2(BX + 40, BY + 210)
	title.size     = Vector2(BW - 80, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", C_GOLD)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)

	var msg := Label.new()
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.text = "Πέρασες όλα τα δωμάτια του Κάστρου και πήρες ήδη την ανταμοιβή ολοκλήρωσης — Χαλκός, Σίδερο, Δέρμα, Κέρμα, και η Χρυσή Πανοπλία περιμένουν στην Αποθήκη σου.\n\nΔεν έχει μείνει τίποτα άλλο να κάνεις εδώ."
	msg.position = Vector2(BX + 60, BY + 300)
	msg.size     = Vector2(BW - 120, 300)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment   = VERTICAL_ALIGNMENT_TOP
	msg.add_theme_font_size_override("font_size", 28)
	msg.add_theme_color_override("font_color", C_PARCH)
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(msg)

	var close_btn := Button.new()
	close_btn.text = "✕  Κλείσιμο"
	close_btn.position = Vector2(BX + BW / 2.0 - 170, BY + BH - 130)
	close_btn.size     = Vector2(340, 96)
	close_btn.add_theme_font_size_override("font_size", 30)
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = C_WOOD_D
	normal_style.border_color = C_GOLD.darkened(0.15)
	normal_style.set_border_width_all(4)
	normal_style.set_corner_radius_all(10)
	normal_style.shadow_color = Color(0, 0, 0, 0.68)
	normal_style.shadow_size = 7
	close_btn.add_theme_stylebox_override("normal", normal_style)
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = C_WOOD
	hover_style.border_color = C_GOLD
	hover_style.set_border_width_all(5)
	hover_style.set_corner_radius_all(10)
	close_btn.add_theme_stylebox_override("hover", hover_style)
	close_btn.add_theme_stylebox_override("focus", StyleBoxFlat.new())
	close_btn.add_theme_color_override("font_color", C_GOLD)
	close_btn.add_theme_color_override("font_hover_color", C_GOLD_S)
	close_btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.92))
	close_btn.add_theme_constant_override("shadow_offset_x", 2)
	close_btn.add_theme_constant_override("shadow_offset_y", 3)
	close_btn.pressed.connect(close_popup)
	root.add_child(close_btn)

	root.visible = false
	return root

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
		%ConditionKeyPopup.open_for(str(cfg["text"]), cfg["clauses"], str(cfg.get("mode", "AND")), room_id)
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
	if room_id == "main_bailey":
		_grant_completion_reward()
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

## Ανταμοιβή ολοκλήρωσης όλου του side quest — ΜΙΑ μόνο φορά συνολικά (βλ.
## GameData.is_castle_completed/record_castle_completed), ανεξάρτητα από
## πόσες φορές ξαναμπαίνει ο παίκτης στο Main Bailey μετά.
func _grant_completion_reward() -> void:
	if GameData.is_castle_completed():
		return
	for currency in COMPLETION_REWARD_CURRENCY:
		Currency.add(currency, int(COMPLETION_REWARD_CURRENCY[currency]))
	ArmorInventory.grant(GOLDEN_ARMOR_ID)
	GameData.record_castle_completed()
	_show_congrats_overlay()

## Εμφανίζεται ΜΙΑ φορά, πάνω από την εικόνα του Main Bailey, την ΠΡΩΤΗ φορά
## που ο παίκτης ολοκληρώνει το side quest (βλ. _grant_completion_reward) —
## διαφορετικό από το _build_completed_panel(), που δείχνεται σε ΕΠΟΜΕΝΑ
## ανοίγματα του Κάστρου αντί για τον χάρτη. Φτιάχνεται φρέσκο κάθε φορά
## (όχι "χτίσε μία φορά, toggle visibility") αφού δεν ξαναχρειάζεται ποτέ.
func _show_congrats_overlay() -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	const BX := 90.0
	const BY := 460.0
	const BW := 900.0
	const BH := 960.0

	var shadow := Panel.new()
	shadow.position = Vector2(BX + 8, BY + 8)
	shadow.size     = Vector2(BW, BH)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow_style := StyleBoxFlat.new()
	shadow_style.bg_color = Color(0, 0, 0, 0.55)
	shadow_style.set_corner_radius_all(18)
	shadow.add_theme_stylebox_override("panel", shadow_style)
	overlay.add_child(shadow)

	var panel := Panel.new()
	panel.position = Vector2(BX, BY)
	panel.size     = Vector2(BW, BH)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = C_WOOD
	panel_style.border_color = C_GOLD
	panel_style.set_border_width_all(5)
	panel_style.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", panel_style)
	overlay.add_child(panel)

	var inner := Panel.new()
	inner.position = Vector2(BX + 10, BY + 10)
	inner.size     = Vector2(BW - 20, BH - 20)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = C0
	inner_style.border_color = C_GOLD_D.darkened(0.3)
	inner_style.set_border_width_all(2)
	inner_style.set_corner_radius_all(14)
	inner.add_theme_stylebox_override("panel", inner_style)
	overlay.add_child(inner)

	var icon := Label.new()
	icon.text = "🎉"
	icon.position = Vector2(BX, BY + 40)
	icon.size     = Vector2(BW, 130)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 96)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(icon)

	var title := Label.new()
	title.text = "Συγχαρητήρια!"
	title.position = Vector2(BX + 40, BY + 190)
	title.size     = Vector2(BW - 80, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", C_GOLD)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(title)

	var msg := Label.new()
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.text = "Πέρασες όλα τα δωμάτια του Κάστρου!"
	msg.position = Vector2(BX + 60, BY + 270)
	msg.size     = Vector2(BW - 120, 60)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 28)
	msg.add_theme_color_override("font_color", C_PARCH)
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(msg)

	var reward_title := Label.new()
	reward_title.text = "Κέρδισες:"
	reward_title.position = Vector2(BX + 60, BY + 350)
	reward_title.size     = Vector2(BW - 120, 44)
	reward_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_title.add_theme_font_size_override("font_size", 26)
	reward_title.add_theme_color_override("font_color", C_GOLD_D)
	reward_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(reward_title)

	var reward_lines: Array[String] = []
	for currency in COMPLETION_REWARD_CURRENCY:
		reward_lines.append("+%d %s" % [int(COMPLETION_REWARD_CURRENCY[currency]), currency])
	reward_lines.append("+ %s" % ArmorInventory.get_item_name(GOLDEN_ARMOR_ID))

	var reward_list := Label.new()
	reward_list.text = "\n".join(reward_lines)
	reward_list.position = Vector2(BX + 60, BY + 400)
	reward_list.size     = Vector2(BW - 120, 300)
	reward_list.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_list.vertical_alignment   = VERTICAL_ALIGNMENT_TOP
	reward_list.add_theme_font_size_override("font_size", 30)
	reward_list.add_theme_color_override("font_color", C_PARCH)
	reward_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(reward_list)

	var ok_btn := Button.new()
	ok_btn.text = "✔  Ωραία!"
	ok_btn.position = Vector2(BX + BW / 2.0 - 170, BY + BH - 130)
	ok_btn.size     = Vector2(340, 96)
	ok_btn.add_theme_font_size_override("font_size", 30)
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = C_WOOD_D
	normal_style.border_color = C_GOLD.darkened(0.15)
	normal_style.set_border_width_all(4)
	normal_style.set_corner_radius_all(10)
	normal_style.shadow_color = Color(0, 0, 0, 0.68)
	normal_style.shadow_size = 7
	ok_btn.add_theme_stylebox_override("normal", normal_style)
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = C_WOOD
	hover_style.border_color = C_GOLD
	hover_style.set_border_width_all(5)
	hover_style.set_corner_radius_all(10)
	ok_btn.add_theme_stylebox_override("hover", hover_style)
	ok_btn.add_theme_stylebox_override("focus", StyleBoxFlat.new())
	ok_btn.add_theme_color_override("font_color", C_GOLD)
	ok_btn.add_theme_color_override("font_hover_color", C_GOLD_S)
	ok_btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.92))
	ok_btn.add_theme_constant_override("shadow_offset_x", 2)
	ok_btn.add_theme_constant_override("shadow_offset_y", 3)
	ok_btn.pressed.connect(overlay.queue_free)
	overlay.add_child(ok_btn)
