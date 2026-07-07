extends Node

# Autoload singleton: κεντρική πηγή αλήθειας για τα νομίσματα/υλικά του παίκτη.
# Το LootPopup διαβάζει από εδώ για να εμφανίσει τα ποσά, και το ShopPopup
# αφαιρεί πόρους από εδώ όταν ο παίκτης αγοράζει κάτι — έτσι τα δύο popup
# μένουν συγχρονισμένα χωρίς να περνάνε δεδομένα μεταξύ τους απευθείας.

signal changed

const ORDER: Array[String] = ["Χρυσό", "Κασμίρ", "Βαμβάκι", "Σίδερο"]

const COLORS := {
	"Χρυσό":   Color("f2c84b"),
	"Κασμίρ":  Color("b9863f"),
	"Βαμβάκι": Color("f4ecd8"),
	"Σίδερο":  Color("9aa3ab"),
}

const ICONS := {
	"Χρυσό":   "🪙",
	"Κασμίρ":  "🧶",
	"Βαμβάκι": "☁",
	"Σίδερο":  "⛓",
}

var _amounts := {
	"Χρυσό":   350,
	"Κασμίρ":  8,
	"Βαμβάκι": 24,
	"Σίδερο":  30,
}

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
	changed.emit()
	return true

func add(currency: String, amount: int) -> void:
	_amounts[currency] = get_amount(currency) + amount
	changed.emit()
