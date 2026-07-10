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
	# ΠΡΟΣΟΧΗ σειρά αυτοφόρτωσης: το Inventory είναι ΠΡΩΤΟ στη λίστα autoload
	# (project.godot), άρα το _ready() του τρέχει πριν καν προστεθούν τα
	# WeaponInventory/ArmorInventory autoloads — αν καλούνταν εδώ απευθείας,
	# is_owned() θα έβλεπε ΑΚΟΜΑ άδεια κατάσταση ιδιοκτησίας (δεν έχει τρέξει
	# το δικό τους _ready() που τη φορτώνει από το GameData) και θα απέρριπτε
	# ΚΑΘΕ μη-κενό αποθηκευμένο slot. call_deferred το αναβάλλει για μετά
	# την ολοκλήρωση του _ready() όλων των autoloads.
	call_deferred("_apply_saved_loadout")
	# Αν ένα εξοπλισμένο αντικείμενο πουληθεί (WeaponInventory.sell /
	# ArmorInventory.sell) από το Αποθήκη, αδειάζει αυτόματα η αντίστοιχη
	# θέση εδώ αντί να μείνει "εξοπλισμένο" κάτι που δεν ανήκει πια στον
	# παίκτη — κρατάει Inventory/WeaponInventory/ArmorInventory συνεπή.
	WeaponInventory.changed.connect(_on_weapon_inventory_changed)
	ArmorInventory.changed.connect(_on_armor_inventory_changed)
	# Αυτόματος εξοπλισμός στην πρώτη αγορά που γεμίζει μια άδεια θέση (όπλο ή
	# συγκεκριμένη κατηγορία πανοπλίας) — βλ. _on_weapon_bought/_on_armor_bought.
	WeaponInventory.item_bought.connect(_on_weapon_bought)
	ArmorInventory.item_bought.connect(_on_armor_bought)

## Αντικαθιστά τα starter defaults με ό,τι είχε αποθηκευτεί προηγουμένως
## (GameData.get_equipped_loadout / save_equipped_loadout πιο κάτω) — μόνο
## για slots όπου το αποθηκευμένο item_id ανήκει ΑΚΟΜΑ στον παίκτη, ώστε ένα
## αντικείμενο που πουλήθηκε ανάμεσα σε δύο εκτελέσεις να μην ξαναεμφανιστεί
## σαν εξοπλισμένο.
func _apply_saved_loadout() -> void:
	var saved: Dictionary = GameData.get_equipped_loadout()
	for slot in saved:
		var id: String = str(saved[slot])
		if slot == SLOT_WEAPON:
			if id == "" or WeaponInventory.is_owned(id):
				equipped[SLOT_WEAPON] = id
		elif SLOTS.has(slot):
			if id == "" or ArmorInventory.is_owned(id):
				equipped[slot] = id

func _persist_equipped() -> void:
	GameData.save_equipped_loadout(equipped.duplicate())

func _on_weapon_inventory_changed() -> void:
	var id: String = equipped.get(SLOT_WEAPON, "")
	if id != "" and not WeaponInventory.is_owned(id):
		equipped[SLOT_WEAPON] = ""
		equipment_changed.emit(SLOT_WEAPON, "")
		_persist_equipped()

func _on_armor_inventory_changed() -> void:
	for slot in SLOTS:
		var id: String = equipped.get(slot, "")
		if id != "" and not ArmorInventory.is_owned(id):
			equipped[slot] = ""
			equipment_changed.emit(slot, "")
			_persist_equipped()

## Αν αγοραστεί ένα όπλο ενώ καμία θέση όπλου δεν είναι ήδη εξοπλισμένη
## (π.χ. μετά από πώληση του προηγούμενου, ή σε ένα ολοκαίνουργιο save χωρίς
## ακόμα starter), εξοπλίζεται αμέσως — καμία επανεκκίνηση δεν χρειάζεται.
func _on_weapon_bought(id: String) -> void:
	if equipped.get(SLOT_WEAPON, "") == "":
		equip(SLOT_WEAPON, id)

## Ίδια λογική με το _on_weapon_bought, ανά κατηγορία πανοπλίας: αν αγοραστεί
## π.χ. ένα Κράνος ενώ η θέση SLOT_HELMET είναι άδεια, εξοπλίζεται αμέσως.
func _on_armor_bought(id: String) -> void:
	var category := ArmorInventory.get_category(id)
	for slot in SLOTS:
		if SLOT_LABELS[slot] == category and equipped.get(slot, "") == "":
			equip(slot, id)
			return

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
		_persist_equipped()
		return
	if not SLOTS.has(slot):
		return
	if item_id != "" and not ArmorInventory.is_owned(item_id):
		return
	equipped[slot] = item_id
	equipment_changed.emit(slot, item_id)
	_persist_equipped()

## Σε ποιο equip slot ανήκει ένα item_id ενός catalog — WeaponInventory είναι
## πάντα SLOT_WEAPON, ArmorInventory γεφυρώνεται στο slot της κατηγορίας του
## (βλ. SLOT_LABELS). Χρησιμοποιείται από το Αποθήκη/InventoryPopup για το
## κουμπί Select/Selected, ώστε να μη χρειάζεται να ξέρει τίποτα για slots.
func get_slot_for(catalog: EquipmentCatalog, id: String) -> String:
	if catalog == WeaponInventory:
		return SLOT_WEAPON
	if catalog == ArmorInventory:
		var category := catalog.get_category(id)
		for slot in SLOTS:
			if SLOT_LABELS[slot] == category:
				return slot
	return ""

## True αν το id είναι ΑΥΤΗ τη στιγμή εξοπλισμένο στο slot του.
func is_item_equipped(catalog: EquipmentCatalog, id: String) -> bool:
	var slot := get_slot_for(catalog, id)
	return slot != "" and equipped.get(slot, "") == id

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

## Cache: εικόνα path -> Rect2 του πραγματικού (μη-διάφανου) περιεχομένου
## της, βλ. _auto_crop_rect παρακάτω. Υπολογίζεται μία φορά ανά path.
var _crop_rect_cache: Dictionary = {}

## Η εικόνα ενός αντικειμένου, κομμένη (μέσω AtlasTexture) στο πραγματικό της
## περιεχόμενο με βάση "avatar_overlay"/"avatar_overlay_region". ΜΙΑ κοινή
## πηγή για όλες τις οθόνες που δείχνουν αντικείμενα (Character Scene,
## Αποθήκη/InventoryPopup), ώστε να δείχνουν πάντα την ίδια εικόνα.
##
## Τα PNG των όπλων/πανοπλιών είναι "προϊοντικές φωτογραφίες" σε μεγάλο,
## κατά κύριο λόγο διάφανο καμβά — χωρίς crop, ένα TextureRect με
## KEEP_ASPECT_CENTERED τα σμικραίνει ολόκληρα (μαζί με το διάφανο περιθώριο)
## μέσα στο μικρό πλαίσιο-στόχο του, οπότε το ίδιο το αντικείμενο καταλήγει
## μικροσκοπικό/κακοκεντραρισμένο μέσα στο πλαίσιο — αυτό ήταν η πραγματική
## αιτία του προβλήματος στο Character Editor. Αντί να χρειάζεται χειροκίνητο
## "avatar_overlay_region" ανά αντικείμενο (105 εικόνες), το crop υπολογίζεται
## ΑΥΤΟΜΑΤΑ από το πραγματικό bounding box των μη-διάφανων pixel της κάθε
## εικόνας (Image.get_used_rect()) — "avatar_overlay_region" παραμένει
## διαθέσιμο ως προαιρετική χειροκίνητη υπερίσχυση αν χρειαστεί ποτέ.
func get_item_texture(item: Dictionary) -> Texture2D:
	var path: String = str(item.get("avatar_overlay", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	if tex == null:
		return null
	var region: Rect2 = item.get("avatar_overlay_region", Rect2())
	if region.size == Vector2.ZERO:
		region = _auto_crop_rect(path, tex)
	if region.size == Vector2.ZERO:
		return tex
	var atlas := AtlasTexture.new()
	atlas.atlas  = tex
	atlas.region = region
	return atlas

func _auto_crop_rect(path: String, tex: Texture2D) -> Rect2:
	if _crop_rect_cache.has(path):
		return _crop_rect_cache[path]
	var rect := Rect2()
	var img := tex.get_image()
	if img != null:
		var used: Rect2i = img.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			rect = Rect2(used)
	_crop_rect_cache[path] = rect
	return rect
