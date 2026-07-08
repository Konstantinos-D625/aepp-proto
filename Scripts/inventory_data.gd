extends Node

## Καθολική (autoload) κατάσταση για το equipment του παίκτη (Character Scene).
## Τα ίδια τα όπλα/πανοπλίες ζουν στα WeaponInventory/ArmorInventory autoloads
## (Scripts/weapon_inventory.gd, Scripts/armor_inventory.gd — folder-driven
## κατάλογοι με δικό τους σύστημα αγοράς/αναβάθμισης/πώλησης). Αυτό το
## autoload είναι μόνο η "γέφυρα": ξέρει ποιο slot έχει ποιο item_id
## εξοπλισμένο, και μετατρέπει κάθε item_id στο ΚΟΙΝΟ Dictionary-σχήμα
## ("name"/"avatar_overlay"/"stat_bonus") που περιμένει το Character Scene,
## ώστε αυτό να μη γνωρίζει καν σε ποιο autoload ζει το κάθε είδος εξοπλισμού.

signal equipment_changed(slot: String, item_id: String)

const CATEGORY_WEAPON := "weapon"
const CATEGORY_ARMOR := "armor"

# ── Equipment slots (Character Scene) ───────────────────────────────────────
const SLOT_HELMET := "helmet"
const SLOT_CHEST  := "chest"
const SLOT_LEGS   := "legs"
const SLOT_BOOTS  := "boots"
const SLOTS: Array[String] = [SLOT_HELMET, SLOT_CHEST, SLOT_LEGS, SLOT_BOOTS]

# Η θέση όπλου είναι ξεχωριστή από τα SLOTS (πανοπλία) — τα όπλα ζουν
# αποκλειστικά στο WeaponInventory autoload. equip()/get_equipped()/
# get_owned_by_slot() παρακάτω γεφυρώνουν το SLOT_WEAPON σε αυτό το autoload.
const SLOT_WEAPON := "weapon"

const SLOT_LABELS := {
	SLOT_HELMET: "Κράνος",
	SLOT_CHEST:  "Θώρακας",
	SLOT_LEGS:   "Παντελόνι",
	SLOT_BOOTS:  "Μπότες",
	SLOT_WEAPON: "Όπλο",
}

# Κάθε SLOT_LABELS[slot] (πανοπλία) είναι ΗΔΗ ακριβώς το όνομα κατηγορίας
# που χρησιμοποιεί το ArmorInventory (π.χ. SLOT_CHEST -> "Θώρακας") — άρα
# δεν χρειάζεται ξεχωριστό mapping, το slot->category γεφυρώνεται απευθείας
# μέσω αυτού του ήδη υπάρχοντος dictionary.

# Ένα starter κομμάτι πανοπλίας ανά slot, κατοχυρωμένο σε ένα ολοκαίνουργιο
# save (βλ. _ready). Οι ίδιες 4 τιμές με το ArmorInventory.starter_ids — δεν
# γίνεται άμεση αναφορά στο ArmorInventory εδώ γιατί τα field initializers
# όλων των autoloads τρέχουν πριν καν υπάρχουν τα άλλα autoloads ως
# αντικείμενα (βλ. σχόλιο στο equipped παρακάτω).
const ARMOR_STARTER_IDS := {
	SLOT_HELMET: "Κράνος_1",
	SLOT_CHEST:  "Θώρακας_1",
	SLOT_LEGS:   "Παντελόνι_1",
	SLOT_BOOTS:  "Μπότες_1",
}

# slot -> item_id (ή "" αν καμία θέση δεν είναι εξοπλισμένη εκεί). Όλα
# ξεκινούν "" εδώ σκόπιμα — αν έγραφαν κατευθείαν τα πραγματικά starter ids
# σε αυτό το field initializer θα έτρεχε ΠΡΙΝ καν φτιαχτούν τα
# WeaponInventory/ArmorInventory autoloads (το Inventory είναι πρώτο στη
# λίστα αυτοφόρτωσης· τα field initializers τρέχουν στη σειρά κατασκευής των
# αυτοφορτωμένων, όχι στη σειρά _ready()). Οι πραγματικές τιμές μπαίνουν στο
# _ready() παρακάτω, όπου ΟΛΑ τα autoloads υπάρχουν ήδη ως αντικείμενα.
var equipped: Dictionary = {
	SLOT_HELMET: "",
	SLOT_CHEST:  "",
	SLOT_LEGS:   "",
	SLOT_BOOTS:  "",
	SLOT_WEAPON: "",
}

func _ready() -> void:
	if equipped.get(SLOT_WEAPON, "") == "":
		equipped[SLOT_WEAPON] = WeaponInventory.STARTER_WEAPON_ID
	for slot in SLOTS:
		if equipped.get(slot, "") == "":
			equipped[slot] = ARMOR_STARTER_IDS.get(slot, "")
	# Αν ένα εξοπλισμένο αντικείμενο πουληθεί (WeaponInventory.sell /
	# ArmorInventory.sell) από το Αποθήκη, αδειάζει αυτόματα η αντίστοιχη
	# θέση εδώ αντί να μείνει "εξοπλισμένο" κάτι που δεν ανήκει πια στον
	# παίκτη — κρατάει Inventory/WeaponInventory/ArmorInventory συνεπή.
	WeaponInventory.changed.connect(_on_weapon_inventory_changed)
	ArmorInventory.changed.connect(_on_armor_inventory_changed)

func _on_weapon_inventory_changed() -> void:
	var id: String = equipped.get(SLOT_WEAPON, "")
	if id != "" and not WeaponInventory.is_owned(id):
		equipped[SLOT_WEAPON] = ""
		equipment_changed.emit(SLOT_WEAPON, "")

func _on_armor_inventory_changed() -> void:
	for slot in SLOTS:
		var id: String = equipped.get(slot, "")
		if id != "" and not ArmorInventory.is_owned(id):
			equipped[slot] = ""
			equipment_changed.emit(slot, "")

## Όλα τα αντικείμενα που έχει ο παίκτης και ταιριάζουν σε συγκεκριμένη θέση
## εξοπλισμού (π.χ. SLOT_HELMET ή SLOT_WEAPON) — χρησιμοποιείται από το
## Character Scene για να δείξει τι μπορεί να εξοπλιστεί σε κάθε θέση.
func get_owned_by_slot(slot: String) -> Array[Dictionary]:
	if slot == SLOT_WEAPON:
		return _get_owned_as_items(WeaponInventory, CATEGORY_WEAPON, "Επίθεση")
	if not SLOTS.has(slot):
		return []
	return _get_owned_as_items_for_category(ArmorInventory, SLOT_LABELS[slot], CATEGORY_ARMOR, "Άμυνα")

## Εξοπλίζει item_id στο slot (ή "" για να αδειάσει τη θέση). Αγνοεί αν το
## item δεν ανήκει στον παίκτη.
func equip(slot: String, item_id: String) -> void:
	if slot == SLOT_WEAPON:
		if item_id != "" and not WeaponInventory.is_owned(item_id):
			return
		equipped[SLOT_WEAPON] = item_id
		equipment_changed.emit(SLOT_WEAPON, item_id)
		return
	if not SLOTS.has(slot):
		return
	if item_id != "" and not ArmorInventory.is_owned(item_id):
		return
	equipped[slot] = item_id
	equipment_changed.emit(slot, item_id)

## Το εξοπλισμένο item στο slot, ή ένα άδειο Dictionary αν καμία θέση.
func get_equipped(slot: String) -> Dictionary:
	var id: String = equipped.get(slot, "")
	if id == "":
		return {}
	if slot == SLOT_WEAPON:
		return _as_item(WeaponInventory, id, CATEGORY_WEAPON, "Επίθεση")
	return _as_item(ArmorInventory, id, CATEGORY_ARMOR, "Άμυνα")

## Μετατρέπει ένα item_id ενός equipment catalog (WeaponInventory ή
## ArmorInventory, π.χ. "Σπαθί_3" ή "Θώρακας_2") στο ΚΟΙΝΟ Dictionary-σχήμα
## ("name"/"avatar_overlay"/"stat_bonus") που περιμένει το Character Scene,
## ώστε αυτό να μη γνωρίζει καν ότι όπλα/πανοπλίες ζουν σε άλλα autoloads.
## Χωρίς "avatar_overlay_region": τα PNG δεν έχουν ακόμα χειροκίνητο
## alpha-crop, οπότε εμφανίζονται ολόκληρα (best effort).
func _as_item(catalog: EquipmentCatalog, id: String, category: String, stat_name: String) -> Dictionary:
	if not catalog.is_owned(id):
		return {}
	return {
		"id": id,
		"name": catalog.get_item_name(id),
		"category": category,
		"avatar_overlay": catalog.get_icon_path(id),
		"stat_bonus": { stat_name: catalog.get_total_stat(id) },
	}

func _get_owned_as_items(catalog: EquipmentCatalog, category: String, stat_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cat in catalog.categories:
		for id in catalog.get_items_in_category(cat):
			if catalog.is_owned(id):
				result.append(_as_item(catalog, id, category, stat_name))
	return result

func _get_owned_as_items_for_category(catalog: EquipmentCatalog, only_category: String, category: String, stat_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in catalog.get_items_in_category(only_category):
		if catalog.is_owned(id):
			result.append(_as_item(catalog, id, category, stat_name))
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
