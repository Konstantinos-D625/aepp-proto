extends Node

# Autoload singleton: κεντρική πηγή αλήθειας για τα νομίσματα/υλικά του παίκτη.
# Το LootPopup διαβάζει από εδώ για να εμφανίσει τα ποσά, και το ShopPopup
# αφαιρεί πόρους από εδώ όταν ο παίκτης αγοράζει κάτι — έτσι τα δύο popup
# μένουν συγχρονισμένα χωρίς να περνάνε δεδομένα μεταξύ τους απευθείας.

signal changed

# Μετονομασία πόρων (ταιριάζει με το νέο στήσιμο των NPC — βλ. old_man_popup
# TOPICS): Χρυσό -> Χαλκός (Μεταλλωρύχος/ΟΡΥΧΕΙΟ ΧΑΛΚΟΥ), Βαμβάκι -> Δέρμα
# (Δερματού). Το Σίδερο έμεινε ίδιο (Σιδεράς/Πεταλωτής).
# Το Κέρμα αποκτιέται ΜΟΝΟ από το Ανταλλακτήριο του Νάνου (gnome_popup.gd:
# 1 Χαλκός + 1 Δέρμα + 1 Σίδερο -> 1 Κέρμα) — κανένα άλλο σύστημα δεν το
# χορηγεί ούτε το ξοδεύει (ακόμα).
# Το Κασμίρ ΑΦΑΙΡΕΘΗΚΕ (balance pass): δεν είχε καμία πηγή ούτε χρήση πουθενά
# στο παιχνίδι — ένα παλιό σχόλιο ισχυριζόταν ότι τιμολογούσε την πανοπλία,
# αλλά αυτό δεν ίσχυε ποτέ στην πράξη (η ArmorInventory τιμολογεί σε Χαλκό).
const ORDER: Array[String] = [
	"Χαλκός", "Δέρμα", "Σίδερο", "Κέρμα",
	"Αριθμητικό Κλειδί", "Λογικό Κλειδί", "Κλειδί Χαρακτήρων",
]

const COLORS := {
	"Χαλκός":           Color("e2833f"),
	"Δέρμα":            Color("9c6b45"),
	"Σίδερο":           Color("9aa3ab"),
	"Κέρμα":            Color("f2c84b"),
	"Αριθμητικό Κλειδί":  Color("c9a24b"),
	"Λογικό Κλειδί":      Color("b088d8"),
	"Κλειδί Χαρακτήρων":  Color("d88c6a"),
}

# Εικονίδια-ΕΙΚΟΝΕΣ (PNG) — όπου ορίζεται εδώ, τα UI που δείχνουν αποθέματα
# (Αποθήκη/loot_popup, strip του Shop, Ανταλλακτήριο του Νάνου) προτιμούν την
# εικόνα από τον χρωματιστό κύκλο/emoji — βλ. get_icon_texture παρακάτω.
# Πόροι χωρίς εγγραφή εδώ (Κλειδιά) συνεχίζουν να δείχνουν ό,τι έδειχναν· για
# να πάρει εικόνα ένας νέος πόρος, αρκεί μία γραμμή εδώ.
const TEXTURE_ICONS := {
	"Χαλκός": "res://Εικόνες/copper.png",
	"Δέρμα":  "res://Εικόνες/leather.png",
	"Σίδερο": "res://Εικόνες/iron.png",
	"Κέρμα":  "res://Εικόνες/coin.png",
}

## Texture εικονιδίου του πόρου, ή null αν δεν έχει οριστεί/λείπει το αρχείο.
func get_icon_texture(currency: String) -> Texture2D:
	var path: String = TEXTURE_ICONS.get(currency, "")
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null

const ICONS := {
	"Χαλκός":           "🪙",
	"Δέρμα":            "🟫",
	"Σίδερο":           "⛓",
	"Κέρμα":            "🟡",
	"Αριθμητικό Κλειδί":  "🔑",
	"Λογικό Κλειδί":      "🗝",
	"Κλειδί Χαρακτήρων":  "🔐",
}

# Τα Κλειδιά ξεκινούν από 0 — τα χορηγούν συγκεκριμένα NPC/side quest (βλ.
# cotton_popup.gd + Scripts/room_image_popup.gd για Κλειδιά)· απλά υπάρχουν
# έτοιμα στο Αποθήκη.
var _amounts := {
	"Χαλκός":           5000,
	"Δέρμα":            5000,
	"Σίδερο":           5000,
	"Κέρμα":            5000,
	"Αριθμητικό Κλειδί":  5000,
	"Λογικό Κλειδί":      5000,
	"Κλειδί Χαρακτήρων":  5000,
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
	# Μόνο για ΓΝΩΣΤΑ νομίσματα (ήδη υπάρχουν στο _amounts) — παλιά save files
	# μπορεί ακόμα να κουβαλάνε κλειδιά καταργημένων πόρων (π.χ. το Κασμίρ),
	# και χωρίς αυτόν τον έλεγχο θα «ανασταίνονταν» εδώ σε κάθε επόμενη εκκίνηση.
	for currency in saved:
		if _amounts.has(currency):
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
	changed.emit()
	_persist()
	return true

func add(currency: String, amount: int) -> void:
	_amounts[currency] = get_amount(currency) + amount
	changed.emit()
	_persist()
