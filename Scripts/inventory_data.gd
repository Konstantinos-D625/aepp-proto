extends Node

## Καθολική (autoload) κατάσταση για το inventory του παίκτη.
## Το shop / blacksmith κ.λπ. θα καλεί Inventory.add_item("<id>") όταν
## ο παίκτης αγοράζει ή κατασκευάζει κάτι, ώστε να εμφανιστεί αυτόματα εδώ.

signal item_added(item_id: String)

const CATEGORY_WEAPON := "weapon"
const CATEGORY_ARMOR := "armor"

const MAX_STAT := 5

const ITEMS := {
	"sword_1": {
		"name": "Σπαθί των Αρχαρίων",
		"icon": "res://Εικόνες/sword.png",
		"category": CATEGORY_WEAPON,
		"stats": {
			"Δύναμη": 1,
			"Άμυνα": 1,
			"Βάρος": 4,
		},
	},
	"armor_1": {
		"name": "Πανοπλία των Αρχαρίων",
		"icon": "res://Εικόνες/armor.png",
		"category": CATEGORY_ARMOR,
		"stats": {
			"Δύναμη": 0,
			"Άμυνα": 1,
			"Βάρος": 4,
		},
	},
	# ── Αγοράσιμα από το ShopPopup (Scripts/shop_popup.gd) ────────────────
	"sword_student": {
		"name": "Ξίφος Μαθητή",
		"icon": "res://Εικόνες/sword.png",
		"category": CATEGORY_WEAPON,
		"stats": { "Δύναμη": 2, "Άμυνα": 0, "Βάρος": 2 },
	},
	"sword_double": {
		"name": "Δίκοπο Σπαθί",
		"icon": "res://Εικόνες/sword.png",
		"category": CATEGORY_WEAPON,
		"stats": { "Δύναμη": 3, "Άμυνα": 0, "Βάρος": 3 },
	},
	"axe_war": {
		"name": "Πέλεκυς Πολέμου",
		"icon": "res://Εικόνες/sword.png",
		"category": CATEGORY_WEAPON,
		"stats": { "Δύναμη": 5, "Άμυνα": 0, "Βάρος": 5 },
	},
	"armor_leather": {
		"name": "Δερμάτινη Πανοπλία",
		"icon": "res://Εικόνες/armor.png",
		"category": CATEGORY_ARMOR,
		"stats": { "Δύναμη": 0, "Άμυνα": 2, "Βάρος": 2 },
	},
	"armor_iron": {
		"name": "Σιδερένια Πανοπλία",
		"icon": "res://Εικόνες/armor.png",
		"category": CATEGORY_ARMOR,
		"stats": { "Δύναμη": 0, "Άμυνα": 4, "Βάρος": 4 },
	},
	"armor_knight_shield": {
		"name": "Ασπίδα Ιππότη",
		"icon": "res://Εικόνες/armor.png",
		"category": CATEGORY_ARMOR,
		"stats": { "Δύναμη": 0, "Άμυνα": 5, "Βάρος": 3 },
	},
}

# Ξεκινάει με το αρχικό (κακό) σπαθί και την αρχική (κακή) πανοπλία.
var owned_items: Array[String] = ["sword_1", "armor_1"]

func add_item(item_id: String) -> void:
	if not ITEMS.has(item_id):
		push_warning("Inventory: άγνωστο item id '%s'" % item_id)
		return
	if owned_items.has(item_id):
		return
	owned_items.append(item_id)
	item_added.emit(item_id)

func get_owned_by_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in owned_items:
		var data: Dictionary = ITEMS[id]
		if data["category"] == category:
			var entry := data.duplicate(true)
			entry["id"] = id
			result.append(entry)
	return result
