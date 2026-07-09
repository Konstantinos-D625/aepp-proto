extends Node
class_name EquipmentCatalog

## Κοινή βάση για folder-driven, αγοράσιμο εξοπλισμό — όπλα, πανοπλίες, και
## οποιαδήποτε μελλοντική κατηγορία εξοπλισμού. Το Scripts/weapon_inventory.gd
## και το Scripts/armor_inventory.gd είναι ΥΠΟΚΛΑΣΕΙΣ αυτού του script (μέσω
## `extends "res://Scripts/equipment_catalog.gd"`) — γεμίζουν μόνο τα δικά
## τους δεδομένα μέσα από την _configure(). ΟΛΗ η υπόλοιπη λογική (κατάλογος,
## τιμολόγηση, αγορά/αναβάθμιση/πώληση, persistence, starter grant) είναι
## κοινή και ζει ΜΙΑ φορά εδώ — καμία υποκλάση δεν την ξαναγράφει.
##
## Οι υποκλάσεις μπορούν προαιρετικά να υπερφορτώσουν το get_base_stat()/
## get_total_stat() αν χρειάζονται δική τους φόρμουλα στατιστικού (βλ.
## weapon_inventory.gd, που τη χρειάζεται στην κλίμακα 1-20 για να ταιριάζει
## με το Character stat panel) — η προεπιλογή (old_level × 10) καλύπτει ήδη
## το armor_inventory.gd χωρίς καμία υπερφόρτωση.
##
## Για να προστεθεί νέο όπλο/πανοπλία στο μέλλον: αντέγραψε την εικόνα μέσα
## στον φάκελο της κατηγορίας της και πρόσθεσε ένα {file, name} entry στο
## items[category] της αντίστοιχης υποκλάσης — καμία άλλη αλλαγή λογικής.

signal changed

var item_dir: String = ""
var categories: Array[String] = []
var category_multiplier: Dictionary = {}
var category_labels: Dictionary = {}     # προαιρετικό override εμφάνισης (π.χ. πληθυντικός τύπος)
var items: Dictionary = {}               # category -> Array[{"file": String, "name": String}]
var stat_label: String = "Επίθεση"
var stat_icon: String = "⚔"
var starter_ids: Array[String] = []      # ιδιοκτησία εξ αρχής σε ολοκαίνουργιο save
# false = ο κατάλογος ΔΕΝ έχει καθόλου σύστημα αναβάθμισης (βλ. armor_inventory.gd):
# το can_upgrade()/upgrade() αρνούνται πάντα, και το Inventory UI κρύβει το
# "Επίπεδο x/3" + κουμπί Αναβάθμισης. Το tier παραμένει 1 μετά την αγορά.
var upgradable: bool = true

const UPGRADE_MAX_TIER := 3
const UPGRADE_STAT_BONUS := 2

# item_id ("<category>_<old_level>") -> {"owned": bool, "tier": int}
var _state: Dictionary = {}


func _ready() -> void:
	_configure()
	for category in categories:
		for old_level in range(1, _level_count(category) + 1):
			var id := _make_id(category, old_level)
			var saved: Dictionary = GameData.get_weapon_state(id)
			_state[id] = saved if not saved.is_empty() else {"owned": false, "tier": 0}
	_grant_starters_if_new_save()

## Υπερφορτώνεται από κάθε υποκλάση για να ορίσει τα δικά της
## item_dir/categories/category_multiplier/items/stat_label/starter_ids.
func _configure() -> void:
	pass

## Σε ένα ολοκαίνουργιο save (καμία αποθηκευμένη κατάσταση ποτέ για το id),
## δίνει αυτόματα ιδιοκτησία+tier 1 — μιμείται ό,τι έκανε ήδη το
## weapon_inventory.gd (STARTER_WEAPON_ID) πριν τη γενίκευση.
func _grant_starters_if_new_save() -> void:
	for id in starter_ids:
		if GameData.get_weapon_state(id).is_empty():
			_state[id] = {"owned": true, "tier": 1}
			_persist(id)

func _make_id(category: String, old_level: int) -> String:
	return "%s_%d" % [category, old_level]

func _level_count(category: String) -> int:
	return (items.get(category, []) as Array).size()


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — ΚΑΤΑΛΟΓΟΣ / ΣΤΑΤΙΚΑ ΔΕΔΟΜΕΝΑ
# ═══════════════════════════════════════════════════════════════════════════

## Όλα τα item ids μιας κατηγορίας, με σταθερή σειρά old_level 1..N.
func get_items_in_category(category: String) -> Array[String]:
	var ids: Array[String] = []
	for old_level in range(1, _level_count(category) + 1):
		ids.append(_make_id(category, old_level))
	return ids

func get_category_label(category: String) -> String:
	return category_labels.get(category, category)

func get_category(id: String) -> String:
	return id.substr(0, id.rfind("_"))

func get_old_level(id: String) -> int:
	return int(id.substr(id.rfind("_") + 1))

func get_item_name(id: String) -> String:
	var entry: Dictionary = items[get_category(id)][get_old_level(id) - 1]
	return entry["name"]

func get_icon_path(id: String) -> String:
	var entry: Dictionary = items[get_category(id)][get_old_level(id) - 1]
	return "%s%s/%s.png" % [item_dir, get_category(id), entry["file"]]

## Εσωτερική "ισχύς" ανά old_level (old_level × 10) — η κοινή βάση πάνω στην
## οποία υπολογίζονται τόσο η προεπιλεγμένη φόρμουλα στατιστικού όσο και η
## τιμή αγοράς.
func _price_power(old_level: int) -> int:
	return old_level * 10

## Πολλαπλασιαστής τιμής βάσει old_level· επεκτείνει γραμμικά τη σχέση
## base ×1.0 / ×1.6 / ×2.6 (old_level 1/2/3) ώστε να καλύπτει και τα
## υπόλοιπα old_level.
func _level_price_multiplier(old_level: int) -> float:
	var n := float(old_level - 1)
	return 1.0 + 0.2 * n * n + 0.4 * n

## Τιμή αγοράς στο Shop (κατηγορία × old_level, χωρίς upgrades).
func get_base_price(id: String) -> int:
	var category := get_category(id)
	var old_level := get_old_level(id)
	var mult: float = category_multiplier.get(category, 1.0)
	return int(round(_price_power(old_level) * mult * _level_price_multiplier(old_level)))

## Κόστος αναβάθμισης 1→2 = 20, 2→3 = 30 (σταθερό, ίδιο για όλα τα αντικείμενα).
func get_upgrade_cost(tier: int) -> int:
	return 20 if tier == 1 else 30

func _upgrade_refund(tier: int) -> int:
	if tier >= 3:
		return 20 + 30
	if tier == 2:
		return 20
	return 0

## Βασικό στατιστικό πριν τα upgrades. Προεπιλογή: old_level × 10.
func get_base_stat(id: String) -> int:
	return _price_power(get_old_level(id))


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — ΚΑΤΑΣΤΑΣΗ ΙΔΙΟΚΤΗΣΙΑΣ / ΑΝΑΒΑΘΜΙΣΗΣ
# ═══════════════════════════════════════════════════════════════════════════

func is_owned(id: String) -> bool:
	return bool(_state.get(id, {}).get("owned", false))

func get_tier(id: String) -> int:
	return int(_state.get(id, {}).get("tier", 0))

## Συνολικό στατιστικό (βάση + upgrades).
func get_total_stat(id: String) -> int:
	if not is_owned(id):
		return get_base_stat(id)
	return get_base_stat(id) + (get_tier(id) - 1) * UPGRADE_STAT_BONUS

func can_upgrade(id: String) -> bool:
	return upgradable and is_owned(id) and get_tier(id) < UPGRADE_MAX_TIER

## Τιμή πώλησης: 50% της αρχικής τιμής αγοράς + επιστροφή όλων των coins
## που ξοδεύτηκαν σε upgrades.
func get_sell_price(id: String) -> int:
	return int(round(get_base_price(id) * 0.5)) + _upgrade_refund(get_tier(id))


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — MUTATIONS
# ═══════════════════════════════════════════════════════════════════════════

## Αγορά αντικειμένου — καλείται ΜΟΝΟ από το Shop.
func buy(id: String) -> bool:
	if is_owned(id):
		return false
	if not Currency.spend({"Χρυσό": get_base_price(id)}):
		return false
	_state[id] = {"owned": true, "tier": 1}
	_persist(id)
	changed.emit()
	return true

## Αναβάθμιση επιπέδου (1→2→3) — καλείται ΜΟΝΟ από το Inventory.
func upgrade(id: String) -> bool:
	if not can_upgrade(id):
		return false
	if not Currency.spend({"Χρυσό": get_upgrade_cost(get_tier(id))}):
		return false
	var entry: Dictionary = _state[id]
	entry["tier"] = int(entry["tier"]) + 1
	_state[id] = entry
	_persist(id)
	changed.emit()
	return true

## Πώληση αντικειμένου — καλείται ΜΟΝΟ από το Inventory. Το αντικείμενο
## ξανακλειδώνεται (πρέπει να ξανα-αγοραστεί από το Shop για να αποκτηθεί ξανά).
func sell(id: String) -> bool:
	if not is_owned(id):
		return false
	var refund := get_sell_price(id)
	_state[id] = {"owned": false, "tier": 0}
	_persist(id)
	Currency.add("Χρυσό", refund)
	changed.emit()
	return true

func _persist(id: String) -> void:
	GameData.save_weapon_state(id, _state[id])
