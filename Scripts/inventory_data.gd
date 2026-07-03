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

# ── Character-stat μπόνους (Character Scene) ────────────────────────────────
# Κάθε χαρακτήρας ξεκινάει από 0 σε όλα (βλ. CharacterSelect.CHAR_DATA) — το
# "stat_bonus" εδώ είναι το πόσο ανεβάζει το ΣΥΓΚΕΚΡΙΜΕΝΟ στατιστικό του
# χαρακτήρα ΟΤΑΝ το item είναι εξοπλισμένο (άσχετο από το παλιότερο "stats"
# πεδίο πιο κάτω, που είναι quality-δείκτης για το Αποθήκη/InventoryPopup).
# Όπλα -> μόνο Επίθεση (1-20)· κάθε κομμάτι πανοπλίας -> Άμυνα (1-5). Προς το
# παρόν όλα δίνουν 1 (είναι τα αρχικά/default) — θα ρυθμιστούν ανά αντικείμενο
# αργότερα.
const ITEMS := {
	"sword_1": {
		"name": "Σπαθί των Αρχαρίων",
		"category": CATEGORY_WEAPON,
		"avatar_overlay": "res://Εικόνες/sword_avatar.png",
		# Περιοχή (σε pixel του πηγαίου PNG) όπου βρίσκεται το πραγματικό
		# περιεχόμενο (χωρίς το διάφανο περιθώριο) — υπολογίστηκε από το
		# bounding box του alpha channel, ώστε το layering στο Character
		# Scene (και η εικόνα στο Αποθήκη/InventoryPopup) να ευθυγραμμίζεται
		# σωστά αντί να γεμίζει όλο τον καμβά.
		"avatar_overlay_region": Rect2(186, 87, 342, 233),
		"stat_bonus": { "Επίθεση": 1 },
		"stats": {
			"Δύναμη": 1,
			"Άμυνα": 1,
			"Βάρος": 4,
		},
	},
	"armor_1": {
		"name": "Πανοπλία των Αρχαρίων",
		"category": CATEGORY_ARMOR,
		"slot": SLOT_CHEST,
		"avatar_overlay": "res://Εικόνες/chestplate.png",
		"avatar_overlay_region": Rect2(265, 78, 147, 158),
		"stat_bonus": { "Άμυνα": 1 },
		"stats": {
			"Δύναμη": 0,
			"Άμυνα": 1,
			"Βάρος": 4,
		},
	},
	# ── Αγοράσιμα από το ShopPopup (Scripts/shop_popup.gd) — δεν έχουν ακόμα
	# δικό τους art, οπότε δανείζονται προσωρινά την εικόνα του ίδιου είδους
	# (ξίφος/θώρακας) αντί για το παλιό γενικό sword.png/armor.png.
	"sword_student": {
		"name": "Ξίφος Μαθητή",
		"category": CATEGORY_WEAPON,
		"avatar_overlay": "res://Εικόνες/sword_avatar.png",
		"avatar_overlay_region": Rect2(186, 87, 342, 233),
		"stat_bonus": { "Επίθεση": 1 },
		"stats": { "Δύναμη": 2, "Άμυνα": 0, "Βάρος": 2 },
	},
	"sword_double": {
		"name": "Δίκοπο Σπαθί",
		"category": CATEGORY_WEAPON,
		"avatar_overlay": "res://Εικόνες/sword_avatar.png",
		"avatar_overlay_region": Rect2(186, 87, 342, 233),
		"stat_bonus": { "Επίθεση": 1 },
		"stats": { "Δύναμη": 3, "Άμυνα": 0, "Βάρος": 3 },
	},
	"axe_war": {
		"name": "Πέλεκυς Πολέμου",
		"category": CATEGORY_WEAPON,
		"avatar_overlay": "res://Εικόνες/sword_avatar.png",
		"avatar_overlay_region": Rect2(186, 87, 342, 233),
		"stat_bonus": { "Επίθεση": 1 },
		"stats": { "Δύναμη": 5, "Άμυνα": 0, "Βάρος": 5 },
	},
	"armor_leather": {
		"name": "Δερμάτινη Πανοπλία",
		"category": CATEGORY_ARMOR,
		"slot": SLOT_CHEST,
		"avatar_overlay": "res://Εικόνες/chestplate.png",
		"avatar_overlay_region": Rect2(265, 78, 147, 158),
		"stat_bonus": { "Άμυνα": 1 },
		"stats": { "Δύναμη": 0, "Άμυνα": 2, "Βάρος": 2 },
	},
	"armor_iron": {
		"name": "Σιδερένια Πανοπλία",
		"category": CATEGORY_ARMOR,
		"slot": SLOT_CHEST,
		"avatar_overlay": "res://Εικόνες/chestplate.png",
		"avatar_overlay_region": Rect2(265, 78, 147, 158),
		"stat_bonus": { "Άμυνα": 1 },
		"stats": { "Δύναμη": 0, "Άμυνα": 4, "Βάρος": 4 },
	},
	"armor_knight_shield": {
		"name": "Ασπίδα Ιππότη",
		"category": CATEGORY_ARMOR,
		"avatar_overlay": "res://Εικόνες/chestplate.png",
		"avatar_overlay_region": Rect2(265, 78, 147, 158),
		"stat_bonus": { "Άμυνα": 1 },
		"stats": { "Δύναμη": 0, "Άμυνα": 5, "Βάρος": 3 },
	},
	# ── Θέσεις εξοπλισμού χωρίς προηγούμενη κάλυψη στο καζάνι ─────────────
	"helmet_basic": {
		"name": "Κράνος Μαθητή",
		"category": CATEGORY_ARMOR,
		"slot": SLOT_HELMET,
		"avatar_overlay": "res://Εικόνες/helmet.png",
		"avatar_overlay_region": Rect2(265, 74, 148, 217),
		"stat_bonus": { "Άμυνα": 1 },
		"stats": { "Δύναμη": 0, "Άμυνα": 1, "Βάρος": 1 },
	},
	"legs_basic": {
		"name": "Παντελόνι Μαθητή",
		"category": CATEGORY_ARMOR,
		"slot": SLOT_LEGS,
		"avatar_overlay": "res://Εικόνες/leggings.png",
		"avatar_overlay_region": Rect2(294, 168, 90, 168),
		"stat_bonus": { "Άμυνα": 1 },
		"stats": { "Δύναμη": 0, "Άμυνα": 1, "Βάρος": 1 },
	},
	"boots_basic": {
		"name": "Μπότες Μαθητή",
		"category": CATEGORY_ARMOR,
		"slot": SLOT_BOOTS,
		"avatar_overlay": "res://Εικόνες/boots.png",
		"avatar_overlay_region": Rect2(234, 178, 218, 157),
		"stat_bonus": { "Άμυνα": 1 },
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

## Άθροισμα του "stat_bonus"[stat_name] απ' όλα τα εξοπλισμένα αντικείμενα
## (όλα τα SLOTS + SLOT_WEAPON) — π.χ. πόσο ανεβάζει η Επίθεση από το
## εξοπλισμένο όπλο, ή η Άμυνα από όλα τα κομμάτια πανοπλίας μαζί.
func get_equipped_stat_bonus(stat_name: String) -> int:
	var total := 0
	for slot in equipped:
		var bonus: Dictionary = get_equipped(slot).get("stat_bonus", {})
		total += int(bonus.get(stat_name, 0))
	return total

## Η εικόνα ενός αντικειμένου, κομμένη (μέσω AtlasTexture) στο πραγματικό της
## περιεχόμενο με βάση "avatar_overlay"/"avatar_overlay_region". ΜΙΑ κοινή
## πηγή για όλες τις οθόνες που δείχνουν αντικείμενα (Character Scene,
## Αποθήκη/InventoryPopup), ώστε να δείχνουν πάντα την ίδια εικόνα.
func get_item_texture(item: Dictionary) -> Texture2D:
	var path: String = str(item.get("avatar_overlay", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	var region: Rect2 = item.get("avatar_overlay_region", Rect2())
	if tex == null or region.size == Vector2.ZERO:
		return tex
	var atlas := AtlasTexture.new()
	atlas.atlas  = tex
	atlas.region = region
	return atlas
