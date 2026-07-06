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

# Η θέση όπλου είναι ξεχωριστή από τα SLOTS (πανοπλία) και ΔΕΝ αντλεί από το
# ITEMS παρακάτω — τα όπλα ζουν αποκλειστικά στο WeaponInventory autoload
# (Scripts/weapon_inventory.gd, 9 κατηγορίες × 9 επίπεδα = 81 όπλα, με δικό
# του σύστημα αγοράς/αναβάθμισης/πώλησης). Το equip()/get_equipped()/
# get_owned_by_slot() παρακάτω γεφυρώνουν το SLOT_WEAPON σε αυτό το autoload
# ώστε το Character Scene να το βλέπει με το ίδιο Dictionary-σχήμα
# ("name"/"avatar_overlay"/"stat_bonus") που έχουν τα κανονικά ITEMS.
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
# Κάθε κομμάτι πανοπλίας -> Άμυνα 1 (default, θα ρυθμιστεί ανά αντικείμενο
# αργότερα). Η Επίθεση ΔΕΝ ορίζεται εδώ πια — έρχεται από
# WeaponInventory.get_total_attack() του εξοπλισμένου όπλου (1-20, ήδη στην
# ίδια κλίμακα με το clamp 0-20 του CharacterEditPopup._refresh_stats — βλ.
# _weapon_as_item παρακάτω και weapon_inventory.gd/get_base_attack).
const ITEMS := {
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
	# (θώρακας) αντί για το παλιό γενικό armor.png.
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

# Ξεκινάει με μία βασική πανοπλία ανά θέση. Το όπλο ΔΕΝ είναι εδώ — βλ.
# WeaponInventory.STARTER_WEAPON_ID (χορηγείται αυτόματα εκεί σε νέο save).
var owned_items: Array[String] = ["armor_1", "helmet_basic", "legs_basic", "boots_basic"]

# slot -> item_id (ή "" αν καμία θέση δεν είναι εξοπλισμένη εκεί). Το
# SLOT_WEAPON ξεκινάει "" εδώ σκόπιμα — αν έγραφε κατευθείαν
# WeaponInventory.STARTER_WEAPON_ID σε αυτό το field initializer θα έτρεχε
# ΠΡΙΝ καν φτιαχτεί το WeaponInventory autoload (το Inventory είναι πρώτο στη
# λίστα αυτοφόρτωσης· τα field initializers τρέχουν στη σειρά κατασκευής των
# αυτοφορτωμένων, όχι στη σειρά _ready()). Η πραγματική τιμή μπαίνει στο
# _ready() παρακάτω, όπου ΟΛΑ τα autoloads υπάρχουν ήδη ως αντικείμενα.
var equipped: Dictionary = {
	SLOT_HELMET: "helmet_basic",
	SLOT_CHEST:  "armor_1",
	SLOT_LEGS:   "legs_basic",
	SLOT_BOOTS:  "boots_basic",
	SLOT_WEAPON: "",
}

func _ready() -> void:
	if equipped.get(SLOT_WEAPON, "") == "":
		equipped[SLOT_WEAPON] = WeaponInventory.STARTER_WEAPON_ID
	# Αν το εξοπλισμένο όπλο πουληθεί (WeaponInventory.sell) από το Αποθήκη,
	# αδειάζει αυτόματα η θέση εδώ αντί να μείνει "εξοπλισμένο" ένα όπλο που
	# δεν ανήκει πια στον παίκτη — κρατάει Inventory/WeaponInventory συνεπή.
	WeaponInventory.changed.connect(_on_weapon_inventory_changed)

func _on_weapon_inventory_changed() -> void:
	var id: String = equipped.get(SLOT_WEAPON, "")
	if id != "" and not WeaponInventory.is_owned(id):
		equipped[SLOT_WEAPON] = ""
		equipment_changed.emit(SLOT_WEAPON, "")

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

## True αν το item_id ταιριάζει στη θέση slot. Καλείται μόνο για τις θέσεις
## πανοπλίας (SLOT_WEAPON γεφυρώνεται ξεχωριστά στο WeaponInventory παρακάτω)
## — ταιριάζει με το προαιρετικό "slot" πεδίο του ITEMS.
func _item_matches_slot(item_id: String, slot: String) -> bool:
	var data: Dictionary = ITEMS.get(item_id, {})
	return data.get("slot", "") == slot

## Όλα τα αντικείμενα που έχει ο παίκτης και ταιριάζουν σε συγκεκριμένη θέση
## εξοπλισμού (π.χ. SLOT_HELMET ή SLOT_WEAPON) — χρησιμοποιείται από το
## Character Scene για να δείξει τι μπορεί να εξοπλιστεί σε κάθε θέση.
func get_owned_by_slot(slot: String) -> Array[Dictionary]:
	if slot == SLOT_WEAPON:
		return _get_owned_weapons_as_items()
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
	if slot == SLOT_WEAPON:
		if item_id != "" and not WeaponInventory.is_owned(item_id):
			return
		equipped[SLOT_WEAPON] = item_id
		equipment_changed.emit(SLOT_WEAPON, item_id)
		return
	if not SLOTS.has(slot):
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
	if id == "":
		return {}
	if slot == SLOT_WEAPON:
		return _weapon_as_item(id)
	if not ITEMS.has(id):
		return {}
	var entry: Dictionary = (ITEMS[id] as Dictionary).duplicate(true)
	entry["id"] = id
	return entry

## Μετατρέπει ένα item_id του WeaponInventory (π.χ. "Σπαθί_3") στο ίδιο
## Dictionary-σχήμα ("name"/"avatar_overlay"/"stat_bonus") που έχουν τα
## κανονικά ITEMS, ώστε το Character Scene να μη γνωρίζει καν ότι τα όπλα
## ζουν σε άλλο autoload. Χωρίς "avatar_overlay_region": τα νέα PNG δεν έχουν
## ακόμα χειροκίνητο alpha-crop, οπότε εμφανίζονται ολόκληρα (best effort).
func _weapon_as_item(id: String) -> Dictionary:
	if not WeaponInventory.is_owned(id):
		return {}
	return {
		"id": id,
		"name": WeaponInventory.get_weapon_name(id),
		"category": CATEGORY_WEAPON,
		"avatar_overlay": WeaponInventory.get_icon_path(id),
		"stat_bonus": { "Επίθεση": WeaponInventory.get_total_attack(id) },
	}

func _get_owned_weapons_as_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for category in WeaponInventory.CATEGORIES:
		for id in WeaponInventory.get_items_in_category(category):
			if WeaponInventory.is_owned(id):
				result.append(_weapon_as_item(id))
	return result

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
