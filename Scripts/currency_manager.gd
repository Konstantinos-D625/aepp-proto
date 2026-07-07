extends Node

# Autoload singleton: κεντρική πηγή αλήθειας για τα νομίσματα/υλικά του παίκτη.
# Το LootPopup διαβάζει από εδώ για να εμφανίσει τα ποσά, και το ShopPopup
# αφαιρεί πόρους από εδώ όταν ο παίκτης αγοράζει κάτι — έτσι τα δύο popup
# μένουν συγχρονισμένα χωρίς να περνάνε δεδομένα μεταξύ τους απευθείας.

signal changed

const ORDER: Array[String] = [
	"Χρυσό", "Βαμβάκι", "Σίδερο",
	"Σφαίρα Εξυπνάδας", "Σφαίρα Ταχύτητας", "Σφαίρα Δύναμης",
]

const COLORS := {
	"Χρυσό":            Color("f2c84b"),
	"Βαμβάκι":          Color("f4ecd8"),
	"Σίδερο":           Color("9aa3ab"),
	"Σφαίρα Εξυπνάδας": Color("6fb7e8"),
	"Σφαίρα Ταχύτητας": Color("7ee08a"),
	"Σφαίρα Δύναμης":   Color("e2694f"),
}

const ICONS := {
	"Χρυσό":            "🪙",
	"Βαμβάκι":          "☁",
	"Σίδερο":           "⛓",
	"Σφαίρα Εξυπνάδας": "🔮",
	"Σφαίρα Ταχύτητας": "💨",
	"Σφαίρα Δύναμης":   "💪",
}

# Οι Σφαίρες ξεκινούν από 0 — δεν τις χορηγεί ακόμα κανένα σύστημα (καμία
# άσκηση/quest δεν τις ανταμείβει προς το παρόν)· απλά υπάρχουν έτοιμες στο
# Αποθήκη ώστε να μπορεί να προστεθεί αργότερα ο τρόπος απόκτησής τους χωρίς
# αλλαγή εδώ.
var _amounts := {
	"Χρυσό":            350,
	"Βαμβάκι":          24,
	"Σίδερο":           30,
	"Σφαίρα Εξυπνάδας": 0,
	"Σφαίρα Ταχύτητας": 0,
	"Σφαίρα Δύναμης":   0,
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
