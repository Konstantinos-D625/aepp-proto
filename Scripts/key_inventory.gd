extends Node

# Autoload: "τσάντα κλειδιών" του παίκτη για το παζλ συνθήκης στις πύλες του
# κάστρου (π.χ. Armory: k <= 8, Kitchen: k >= 3 ΚΑΙ k <= 5). Κάθε κλειδί έχει
# μια τιμή (ακέραιη για τα αριθμητικά, bool για τα λογικά) και ανήκει σε μία
# από τις κατηγορίες κλειδιών του Currency — ΑΚΡΙΒΩΣ τα ίδια ονόματα με αυτά
# που βλέπει ο παίκτης στην Αποθήκη/LootPopup (βλ. Scripts/currency_manager.gd),
# ώστε κάθε κλειδί που μαζεύει να φαίνεται και εκεί. Κάθε add_key/remove_key
# ενημερώνει και το Currency, ίδια πηγή αλήθειας με την Αποθήκη.
#
# Ο παίκτης σέρνει ένα κλειδί πάνω στη συνθήκη· αν η τιμή ΔΕΝ την ικανοποιεί,
# το κλειδί σπάει (αφαιρείται). Αν την ικανοποιεί, ανοίγει η πόρτα και το
# κλειδί καταναλώνεται επίσης (χρησιμοποιήθηκε).

signal changed

const CATEGORY_NUMERIC   := "Αριθμητικό Κλειδί"
const CATEGORY_LOGICAL   := "Λογικό Κλειδί"
const CATEGORY_CHARACTER := "Κλειδί Χαρακτήρων"

var _keys: Dictionary = {
	CATEGORY_NUMERIC: [],
	CATEGORY_LOGICAL: [],
	CATEGORY_CHARACTER: [],
}

# Το KeyInventory είναι μετά το GameData στη λίστα autoload, οπότε το save έχει
# ήδη φορτωθεί εδώ. Φορτώνουμε τις αποθηκευμένες λίστες κλειδιών ΑΠΕΥΘΕΙΑΣ, ΧΩΡΙΣ
# να καλέσουμε Currency.add — το πλήθος στην Αποθήκη επαναφέρεται ξεχωριστά από
# το ίδιο το Currency (GameData.currencies), ώστε να μη διπλομετρηθεί.
func _ready() -> void:
	_load_keys()
	# Φάση 4 (cloud restore): ξαναδιάβασε τα κλειδιά όταν αντικατασταθεί το save.
	GameData.save_reloaded.connect(_on_save_reloaded)

func _load_keys() -> void:
	var saved: Dictionary = GameData.get_saved_keys()
	if not saved.is_empty():
		_keys = saved.duplicate(true)
	else:
		_keys = {
			CATEGORY_NUMERIC: [],
			CATEGORY_LOGICAL: [],
			CATEGORY_CHARACTER: [],
		}

func _on_save_reloaded() -> void:
	_load_keys()
	changed.emit()

func _persist() -> void:
	GameData.save_keys(_keys)

## Μόνο οι κατηγορίες από τις οποίες ο παίκτης κατέχει τουλάχιστον ένα κλειδί.
func get_categories() -> Array:
	var result: Array = []
	for cat in _keys:
		if not (_keys[cat] as Array).is_empty():
			result.append(cat)
	return result

func get_keys(category: String) -> Array:
	return (_keys.get(category, []) as Array).duplicate()

func add_key(value, category: String = CATEGORY_NUMERIC) -> void:
	if not _keys.has(category):
		_keys[category] = []
	(_keys[category] as Array).append(value)
	Currency.add(category, 1)
	_persist()
	changed.emit()

## Αφαιρεί ΜΙΑ εμφάνιση της τιμής από την κατηγορία (κλειδί καταναλώθηκε ή έσπασε).
func remove_key(category: String, value) -> void:
	if not _keys.has(category):
		return
	(_keys[category] as Array).erase(value)
	Currency.spend({category: 1})
	_persist()
	changed.emit()
