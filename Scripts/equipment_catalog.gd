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
## Τα ΠΡΑΓΜΑΤΙΚΑ stats ΚΑΙ η τιμή κάθε αντικειμένου είναι ΧΕΙΡΟΚΙΝΗΤΑ — πεδία
## "buffs" (βλ. get_item_buffs) και "price" (βλ. get_purchase_cost) σε κάθε
## entry του items[category], π.χ. {"file": "Level1", "name": "...",
## "buffs": {"Damage": 3, "AttackSpeed": 1}, "price": {"Χαλκός": 24, "Κέρμα": 2}}
## για ένα όπλο. ΚΑΜΙΑ φόρμουλα/πολλαπλασιαστής — για να αλλάξεις τα stats ή
## την τιμή ενός συγκεκριμένου αντικειμένου, άλλαξε ΑΠΕΥΘΕΙΑΣ τους αριθμούς
## στο weapon_inventory.gd/armor_inventory.gd.
##
## Για να προστεθεί νέο όπλο/πανοπλία στο μέλλον: αντέγραψε την εικόνα μέσα
## στον φάκελο της κατηγορίας της και πρόσθεσε ένα {file, name, buffs, price}
## entry στο items[category] της αντίστοιχης υποκλάσης — καμία άλλη αλλαγή
## λογικής.

signal changed
## Εκπέμπεται ΜΟΝΟ σε επιτυχή αγορά (όχι upgrade/sell) — το Inventory
## autoload (Scripts/inventory_data.gd) το ακούει για να εξοπλίζει αυτόματα
## την πρώτη αγορά που γεμίζει μια άδεια θέση (όπλο ή συγκεκριμένη κατηγορία
## πανοπλίας). Ξεχωριστό από το "changed" γιατί εκείνο δεν κουβαλάει ποιο id
## άλλαξε, οπότε δεν αρκεί για να αποφασιστεί αν πρέπει να γίνει auto-equip.
signal item_bought(id: String)

var item_dir: String = ""
var categories: Array[String] = []
var category_labels: Dictionary = {}     # προαιρετικό override εμφάνισης (π.χ. πληθυντικός τύπος)
var items: Dictionary = {}               # category -> Array[{"file", "name", "buffs": {STAT_KEY: int}, "price": {ΝΟΜΙΣΜΑ: int}}]
var stat_label: String = "Επίθεση"
var stat_icon: String = "⚔"
var primary_stat_key: String = "Damage"  # ποιο κλειδί του "buffs" είναι το πρωτεύον στατιστικό (π.χ. "Shield" για armor)
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
	_load_state()
	_grant_starters_if_new_save()
	# Φάση 4 (cloud restore): ξαναδιάβασε την ιδιοκτησία/tier όταν αντικατασταθεί
	# το save — αλλιώς το _state θα έμενε με το παλιό (προ-restore) στη μνήμη.
	GameData.save_reloaded.connect(_on_save_reloaded)

func _load_state() -> void:
	for category in categories:
		for old_level in range(1, _level_count(category) + 1):
			var id := _make_id(category, old_level)
			var saved: Dictionary = GameData.get_weapon_state(id)
			_state[id] = saved if not saved.is_empty() else {"owned": false, "tier": 0}

func _on_save_reloaded() -> void:
	_load_state()
	_grant_starters_if_new_save()
	changed.emit()

## Υπερφορτώνεται από κάθε υποκλάση για να ορίσει τα δικά της
## item_dir/categories/items/stat_label/starter_ids.
func _configure() -> void:
	pass

## Σε ένα ολοκαίνουργιο save (καμία αποθηκευμένη κατάσταση ποτέ για το id),
## δίνει αυτόματα ιδιοκτησία+tier 1 σε κάθε id του starter_ids. Καμία υποκλάση
## το χρησιμοποιεί πλέον (weapon/armor_inventory.gd έχουν starter_ids άδειο —
## ο παίκτης ξεκινά χωρίς εξοπλισμό, όλα αγοράζονται από το Shop) — μένει εδώ
## ως γενική, έτοιμη υποδομή για μελλοντική κατηγορία εξοπλισμού.
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

## ΟΛΑ τα stats (buffs) που δίνει ένα αντικείμενο όταν εξοπλιστεί — χειροκίνητο
## πεδίο "buffs" στο entry του (π.χ. {"Damage": 3, "AttackSpeed": 1} για ένα
## όπλο, {"Shield": 2, "HP": 1} για μία πανοπλία). Η ΜΟΝΑΔΙΚΗ πηγή αλήθειας —
## καμία φόρμουλα/πολλαπλασιαστής από πίσω. Χρησιμοποιείται και από το Shop/
## Inventory (μέσω Heroes.display_item_buffs/item_stat_buffs) ΚΑΙ από το
## get_base_stat παρακάτω (το πρωτεύον stat της κάρτας).
func get_item_buffs(id: String) -> Dictionary:
	var entry: Dictionary = items[get_category(id)][get_old_level(id) - 1]
	return (entry.get("buffs", {}) as Dictionary).duplicate()

## ΟΛΟ το κόστος αγοράς ενός αντικειμένου (π.χ. {"Χαλκός": 24, "Κέρμα": 2}) —
## χειροκίνητο πεδίο "price" στο entry του (ίδιο σχήμα με το
## Heroes.HERO_DEFS[...]["price"]). Η ΜΟΝΑΔΙΚΗ πηγή αλήθειας — καμία φόρμουλα/
## πολλαπλασιαστής από πίσω. Για να αλλάξεις την τιμή ενός αντικειμένου,
## άλλαξε ΑΠΕΥΘΕΙΑΣ τους αριθμούς στο weapon_inventory.gd/armor_inventory.gd.
func get_purchase_cost(id: String) -> Dictionary:
	var entry: Dictionary = items[get_category(id)][get_old_level(id) - 1]
	return (entry.get("price", {}) as Dictionary).duplicate()

## True αν το αντικείμενο είναι ΑΠΟΚΡΥΜΜΕΝΟ από το Shop — π.χ. τρόπαιο boss
## (βλ. "Bad Goblin Armor" στο armor_inventory.gd, "Tree Magic Sphere" στο
## weapon_inventory.gd): παραμένει πλήρως λειτουργικό (is_owned/grant/equip/
## εμφάνιση στο Inventory), απλά ΔΕΝ αγοράζεται ούτε εμφανίζεται στη λίστα
## του Shop — μόνο EquipmentCatalog.grant() (π.χ. από boss_fight.gd) το δίνει.
## Χειροκίνητο πεδίο "hidden" στο entry του items[category], false αν λείπει.
func is_shop_hidden(id: String) -> bool:
	var entry: Dictionary = items[get_category(id)][get_old_level(id) - 1]
	return bool(entry.get("hidden", false))

## Κόστος αναβάθμισης 1→2 = 20, 2→3 = 30 (σταθερό, ίδιο για όλα τα αντικείμενα).
func get_upgrade_cost(tier: int) -> int:
	return 20 if tier == 1 else 30

func _upgrade_refund(tier: int) -> int:
	if tier >= 3:
		return 20 + 30
	if tier == 2:
		return 20
	return 0

## Το πρωτεύον στατιστικό της κάρτας (Επίθεση για όπλα, Άμυνα για πανοπλίες)
## — διαβάζεται από το χειροκίνητο "buffs" dict του αντικειμένου, στο κλειδί
## primary_stat_key (βλ. get_item_buffs).
func get_base_stat(id: String) -> int:
	return int(get_item_buffs(id).get(primary_stat_key, 0))


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

## Επιστροφή πώλησης: 50% ΚΑΘΕ νομίσματος της τιμής αγοράς (στρογγυλεμένο) —
## π.χ. αν η τιμή είναι {"Χαλκός": 30, "Σίδερο": 10}, η επιστροφή είναι
## {"Χαλκός": 15, "Σίδερο": 5}. Ό,τι νόμισμα κι αν έχει το "price" ενός
## αντικειμένου (βλ. get_purchase_cost) επιστρέφεται αναλογικά, όχι μόνο
## Χαλκός. Το Χαλκός παίρνει επιπλέον ό,τι ξοδεύτηκε σε upgrades (πάντα 0
## πλέον — κανένας κατάλογος δεν είναι upgradable — μένει για συμβατότητα).
func get_sell_refund(id: String) -> Dictionary:
	var refund := {}
	for currency in get_purchase_cost(id):
		refund[currency] = int(round(int(get_purchase_cost(id)[currency]) * 0.5))
	var upgrade_refund := _upgrade_refund(get_tier(id))
	if upgrade_refund > 0:
		refund["Χαλκός"] = int(refund.get("Χαλκός", 0)) + upgrade_refund
	return refund


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — MUTATIONS
# ═══════════════════════════════════════════════════════════════════════════

## Αγορά αντικειμένου — καλείται ΜΟΝΟ από το Shop. Τα κρυμμένα (is_shop_hidden)
## τρόπαια boss ΔΕΝ αγοράζονται ποτέ, ακόμα κι αν κληθεί απευθείας — μόνο
## το grant() (βλ. boss_fight.gd) δίνει ιδιοκτησία σε αυτά.
func buy(id: String) -> bool:
	if is_owned(id) or is_shop_hidden(id):
		return false
	if not Currency.spend(get_purchase_cost(id)):
		return false
	_state[id] = {"owned": true, "tier": 1}
	_persist(id)
	changed.emit()
	item_bought.emit(id)
	return true

## Ιδιοκτησία ΧΩΡΙΣ χρέωση — ίδιο αποτέλεσμα με buy() αλλά χωρίς Currency.spend
## (π.χ. δωρεάν ανταμοιβή boss, βλ. boss_fight.gd::_conclude_fight για τον
## καλικάντζαρο). False αν ήδη ανήκει (idempotent — ασφαλές να καλείται ξανά).
func grant(id: String) -> bool:
	if is_owned(id):
		return false
	_state[id] = {"owned": true, "tier": 1}
	_persist(id)
	changed.emit()
	item_bought.emit(id)
	return true

## Αναβάθμιση επιπέδου (1→2→3) — καλείται ΜΟΝΟ από το Inventory.
func upgrade(id: String) -> bool:
	if not can_upgrade(id):
		return false
	if not Currency.spend({"Χαλκός": get_upgrade_cost(get_tier(id))}):
		return false
	var entry: Dictionary = _state[id]
	entry["tier"] = int(entry["tier"]) + 1
	_state[id] = entry
	_persist(id)
	changed.emit()
	return true

## Πώληση αντικειμένου — καλείται ΜΟΝΟ από το Inventory. Το αντικείμενο
## ξανακλειδώνεται (πρέπει να ξανα-αγοραστεί από το Shop για να αποκτηθεί ξανά).
## Επιστρέφει ΚΑΘΕ νόμισμα που ξοδεύτηκε στην αγορά (βλ. get_sell_refund),
## όχι μόνο Χαλκός.
func sell(id: String) -> bool:
	if not is_owned(id):
		return false
	var refund := get_sell_refund(id)
	_state[id] = {"owned": false, "tier": 0}
	_persist(id)
	for currency in refund:
		Currency.add(currency, int(refund[currency]))
	changed.emit()
	return true

func _persist(id: String) -> void:
	GameData.save_weapon_state(id, _state[id])
