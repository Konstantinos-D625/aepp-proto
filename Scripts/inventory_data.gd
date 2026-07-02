extends Node

## Καθολική (autoload) κατάσταση για το inventory του παίκτη.
## Το shop / blacksmith κ.λπ. θα καλεί Inventory.add_item("<id>") όταν
## ο παίκτης αγοράζει ή κατασκευάζει κάτι, ώστε να εμφανιστεί αυτόματα εδώ.

signal item_added(item_id: String)
signal equipment_changed(slot: String, item_id: String)

const CATEGORY_WEAPON := "weapon"
const CATEGORY_ARMOR := "armor"

# ── Equipment slots (Character Scene) ───────────────────────────────────────
# Ορθογώνιο στο category/armor παραπάνω: πανοπλίες που ανήκουν σε ΣΥΓΚΕΚΡΙΜΕΝΗ
# θέση εξοπλισμού παίρνουν επιπλέον ένα προαιρετικό "slot" πεδίο στο ITEMS
# (τα weapons και το armor_knight_shield -δεν είναι θέση σώματος- δεν έχουν).
const SLOT_HELMET := "helmet"
const SLOT_CHEST  := "chest"
const SLOT_LEGS   := "legs"
const SLOT_BOOTS  := "boots"
const SLOTS: Array[String] = [SLOT_HELMET, SLOT_CHEST, SLOT_LEGS, SLOT_BOOTS]

# Η θέση όπλου είναι ξεχωριστή από τα SLOTS (πανοπλία) — δεν ταιριάζει με
# "slot" πεδίο στο ITEMS, ταιριάζει με category == CATEGORY_WEAPON (βλ.
# _item_matches_slot). Το Character Scene τη δείχνει σε ξεχωριστό section.
const SLOT_WEAPON := "weapon"

const SLOT_LABELS := {
	SLOT_HELMET: "Κράνος",
	SLOT_CHEST:  "Θώρακας",
	SLOT_LEGS:   "Παντελόνι",
	SLOT_BOOTS:  "Μπότες",
	SLOT_WEAPON: "Όπλο",
}

const MAX_STAT := 5

const ITEMS := {
	"sword_1": {
		"name": "Σπαθί των Αρχαρίων",
		"icon": "res://Εικόνες/sword.png",
		"category": CATEGORY_WEAPON,
		"avatar_overlay": "res://Εικόνες/sword_avatar.png",
		# Περιοχή (σε pixel του πηγαίου PNG) όπου βρίσκεται το πραγματικό
		# περιεχόμενο (χωρίς το διάφανο περιθώριο) — υπολογίστηκε από το
		# bounding box του alpha channel, ώστε το layering στο Character
		# Scene να ευθυγραμμίζεται σωστά αντί να γεμίζει όλο τον καμβά.
		"avatar_overlay_region": Rect2(186, 87, 342, 233),
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
		"slot": SLOT_CHEST,
		"avatar_overlay": "res://Εικόνες/chestplate.png",
		"avatar_overlay_region": Rect2(258, 76, 156, 235),
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
		"slot": SLOT_CHEST,
		"stats": { "Δύναμη": 0, "Άμυνα": 2, "Βάρος": 2 },
	},
	"armor_iron": {
		"name": "Σιδερένια Πανοπλία",
		"icon": "res://Εικόνες/armor.png",
		"category": CATEGORY_ARMOR,
		"slot": SLOT_CHEST,
		"stats": { "Δύναμη": 0, "Άμυνα": 4, "Βάρος": 4 },
	},
	"armor_knight_shield": {
		"name": "Ασπίδα Ιππότη",
		"icon": "res://Εικόνες/armor.png",
		"category": CATEGORY_ARMOR,
		"stats": { "Δύναμη": 0, "Άμυνα": 5, "Βάρος": 3 },
	},
	# ── Θέσεις εξοπλισμού χωρίς προηγούμενη κάλυψη στο καζάνι ─────────────
	"helmet_basic": {
		"name": "Κράνος Μαθητή",
		"icon": "res://Εικόνες/armor.png",
		"category": CATEGORY_ARMOR,
		"slot": SLOT_HELMET,
		"avatar_overlay": "res://Εικόνες/helmet.png",
		"avatar_overlay_region": Rect2(259, 63, 160, 247),
		"stats": { "Δύναμη": 0, "Άμυνα": 1, "Βάρος": 1 },
	},
	"legs_basic": {
		"name": "Παντελόνι Μαθητή",
		"icon": "res://Εικόνες/armor.png",
		"category": CATEGORY_ARMOR,
		"slot": SLOT_LEGS,
		"avatar_overlay": "res://Εικόνες/leggings.png",
		"avatar_overlay_region": Rect2(275, 119, 137, 198),
		"stats": { "Δύναμη": 0, "Άμυνα": 1, "Βάρος": 1 },
	},
	"boots_basic": {
		"name": "Μπότες Μαθητή",
		"icon": "res://Εικόνες/armor.png",
		"category": CATEGORY_ARMOR,
		"slot": SLOT_BOOTS,
		"avatar_overlay": "res://Εικόνες/boots.png",
		"avatar_overlay_region": Rect2(212, 125, 248, 201),
		"stats": { "Δύναμη": 0, "Άμυνα": 1, "Βάρος": 1 },
	},
}

# Ξεκινάει με το αρχικό (κακό) σπαθί και μία βασική πανοπλία ανά θέση.
var owned_items: Array[String] = ["sword_1", "armor_1", "helmet_basic", "legs_basic", "boots_basic"]

# slot -> item_id (ή "" αν καμία θέση δεν είναι εξοπλισμένη εκεί).
var equipped: Dictionary = {
	SLOT_HELMET: "helmet_basic",
	SLOT_CHEST:  "armor_1",
	SLOT_LEGS:   "legs_basic",
	SLOT_BOOTS:  "boots_basic",
	SLOT_WEAPON: "sword_1",
}

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

## True αν το item_id ταιριάζει στη θέση slot. Το SLOT_WEAPON ταιριάζει με
## category == CATEGORY_WEAPON· οι υπόλοιπες θέσεις ταιριάζουν με το
## προαιρετικό "slot" πεδίο του ITEMS.
func _item_matches_slot(item_id: String, slot: String) -> bool:
	var data: Dictionary = ITEMS.get(item_id, {})
	if slot == SLOT_WEAPON:
		return data.get("category", "") == CATEGORY_WEAPON
	return data.get("slot", "") == slot

## Όλα τα αντικείμενα που έχει ο παίκτης και ταιριάζουν σε συγκεκριμένη θέση
## εξοπλισμού (π.χ. SLOT_HELMET ή SLOT_WEAPON) — χρησιμοποιείται από το
## Character Scene για να δείξει τι μπορεί να εξοπλιστεί σε κάθε θέση.
func get_owned_by_slot(slot: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in owned_items:
		if _item_matches_slot(id, slot):
			var entry: Dictionary = (ITEMS[id] as Dictionary).duplicate(true)
			entry["id"] = id
			result.append(entry)
	return result

## Εξοπλίζει item_id στο slot (ή "" για να αδειάσει τη θέση). Αγνοεί αν το
## item δεν ανήκει στον παίκτη ή δεν ταιριάζει σε αυτή τη θέση.
func equip(slot: String, item_id: String) -> void:
	if slot != SLOT_WEAPON and not SLOTS.has(slot):
		return
	if item_id != "":
		if not owned_items.has(item_id):
			return
		if not _item_matches_slot(item_id, slot):
			return
	equipped[slot] = item_id
	equipment_changed.emit(slot, item_id)

## Το εξοπλισμένο item στο slot, ή ένα άδειο Dictionary αν καμία θέση.
func get_equipped(slot: String) -> Dictionary:
	var id: String = equipped.get(slot, "")
	if id == "" or not ITEMS.has(id):
		return {}
	var entry: Dictionary = (ITEMS[id] as Dictionary).duplicate(true)
	entry["id"] = id
	return entry
