extends Node

# Autoload singleton: κεντρική πηγή αλήθειας για τα νομίσματα/υλικά του παίκτη.
# Το LootPopup διαβάζει από εδώ για να εμφανίσει τα ποσά, και το ShopPopup
# αφαιρεί πόρους από εδώ όταν ο παίκτης αγοράζει κάτι — έτσι τα δύο popup
# μένουν συγχρονισμένα χωρίς να περνάνε δεδομένα μεταξύ τους απευθείας.

signal changed

const ORDER: Array[String] = [
	"Χρυσό", "Κασμίρ", "Βαμβάκι", "Σίδερο",
	"Σφαίρα Εξυπνάδας", "Σφαίρα Ταχύτητας", "Σφαίρα Δύναμης",
	"Αριθμητικό Κλειδί", "Λογικό Κλειδί", "Κλειδί Χαρακτήρων",
]

const COLORS := {
	"Χρυσό":            Color("f2c84b"),
	"Κασμίρ":           Color("b9863f"),
	"Βαμβάκι":          Color("f4ecd8"),
	"Σίδερο":           Color("9aa3ab"),
	"Σφαίρα Εξυπνάδας": Color("6fb7e8"),
	"Σφαίρα Ταχύτητας": Color("7ee08a"),
	"Σφαίρα Δύναμης":   Color("e2694f"),
	"Αριθμητικό Κλειδί":  Color("c9a24b"),
	"Λογικό Κλειδί":      Color("b088d8"),
	"Κλειδί Χαρακτήρων":  Color("d88c6a"),
}

const ICONS := {
	"Χρυσό":            "🪙",
	"Κασμίρ":           "🧶",
	"Βαμβάκι":          "☁",
	"Σίδερο":           "⛓",
	"Σφαίρα Εξυπνάδας": "🔮",
	"Σφαίρα Ταχύτητας": "💨",
	"Σφαίρα Δύναμης":   "💪",
	"Αριθμητικό Κλειδί":  "🔑",
	"Λογικό Κλειδί":      "🗝",
	"Κλειδί Χαρακτήρων":  "🔐",
}

# Οι Σφαίρες και τα Κλειδιά ξεκινούν από 0 — δεν τα χορηγεί ακόμα (ή καθόλου,
# στην περίπτωση των Σφαιρών) κανένα σύστημα εκτός από τα συγκεκριμένα NPC/
# side quest που τα δίνουν (βλ. cotton_popup.gd/fairy_popup.gd για Σφαίρες,
# cotton_popup.gd + Scripts/room_image_popup.gd για Κλειδιά)· απλά υπάρχουν
# έτοιμα στο Αποθήκη. Το Κασμίρ είναι ο βασικός πόρος τιμολόγησης του Armor
# Shop (βλ. Scripts/armor_inventory.gd) — ξεκινάει με μικρό starter απόθεμα,
# ίδιο μοτίβο με Βαμβάκι/Σίδερο.
var _amounts := {
	"Χρυσό":            350,
	"Κασμίρ":           8,
	"Βαμβάκι":          24,
	"Σίδερο":           30,
	"Σφαίρα Εξυπνάδας": 0,
	"Σφαίρα Ταχύτητας": 0,
	"Σφαίρα Δύναμης":   0,
	"Αριθμητικό Κλειδί":  0,
	"Λογικό Κλειδί":      0,
	"Κλειδί Χαρακτήρων":  0,
}

# Το Currency είναι 2ο στη λίστα autoload (project.godot), ΠΡΙΝ το GameData
# (3ο) — άρα στο _ready() το GameData δεν έχει φορτώσει ακόμα το save. Γι' αυτό
# η φόρτωση των αποθηκευμένων ποσών αναβάλλεται με call_deferred, ώστε να τρέξει
# αφού ολοκληρωθεί το _ready()/_load() ΟΛΩΝ των autoloads (ίδιο μοτίβο με
# Scripts/inventory_data.gd).
func _ready() -> void:
	call_deferred("_load_saved")

## Αντικαθιστά τα αρχικά ποσά με ό,τι είχε αποθηκευτεί (GameData.currencies).
## Σε ολοκαίνουργιο save δεν υπάρχει τίποτα αποθηκευμένο, οπότε κρατιούνται τα
## αρχικά ποσά — και αμέσως σώζονται ώστε το save file να αντικατοπτρίζει την
## πραγματική αρχική κατάσταση.
func _load_saved() -> void:
	var saved: Dictionary = GameData.get_saved_currencies()
	for currency in saved:
		_amounts[currency] = int(saved[currency])
	_persist()
	changed.emit()

func _persist() -> void:
	GameData.save_currencies(_amounts)

func get_amount(currency: String) -> int:
	return int(_amounts.get(currency, 0))

func can_afford(cost: Dictionary) -> bool:
	for currency in cost:
		if get_amount(currency) < int(cost[currency]):
			return false
	return true

# Αφαιρεί τα κόστη αν επαρκούν όλα, αλλιώς δεν αλλάζει τίποτα. Επιστρέφει true αν έγινε η αφαίρεση.
func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for currency in cost:
		_amounts[currency] = get_amount(currency) - int(cost[currency])
	_persist()
	changed.emit()
	return true

func add(currency: String, amount: int) -> void:
	_amounts[currency] = get_amount(currency) + amount
	_persist()
	changed.emit()
