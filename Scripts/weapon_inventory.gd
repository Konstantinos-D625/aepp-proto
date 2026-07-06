extends Node

## Καθολική (autoload) κατάσταση για το σύστημα όπλων.
## Μοναδική πηγή αλήθειας: το Inventory, το Weapon Shop, και το save system
## διαβάζουν/γράφουν όλα ΕΔΩ — καμία διπλή μεταβλητή κατάστασης αλλού.
##
## ΑΡΧΙΤΕΚΤΟΝΙΚΗ: κάθε εικόνα Level1..Level9.png μέσα σε κάθε φάκελο
## κατηγορίας είναι ΤΩΡΑ ένα ξεχωριστό, μοναδικά ονομασμένο, αγοράσιμο όπλο
## (όχι πλέον 9 διαδοχικά levels του ΙΔΙΟΥ όπλου). Το "old_level" (1-9, το
## νούμερο της εικόνας) είναι μόνιμο χαρακτηριστικό του όπλου και καθορίζει
## τη βασική του επίθεση/τιμή. Το ξεχωριστό "tier" (1-3) είναι η αναβάθμιση
## που αγοράζει ο παίκτης ΜΕΤΑ την αγορά, μέσα από το Inventory.
##
## Για να προστεθεί νέο όπλο στο μέλλον: αντέγραψε την εικόνα μέσα στον
## φάκελο της κατηγορίας του (WEAPONS_DIR/<category>/LevelN.png) και πρόσθεσε
## ένα όνομα στο WEAPON_NAMES[category] στη θέση N-1 — καμία άλλη αλλαγή
## λογικής δεν χρειάζεται.

signal changed

const WEAPONS_DIR := "res://Όπλα/"

# Σταθερή, ενιαία σειρά κατηγοριών — την χρησιμοποιούν όλα τα UI (Inventory,
# Weapon Shop) ώστε η ιεραρχία να είναι ίδια παντού και για όλους.
const CATEGORIES: Array[String] = [
	"Μαχαίρι", "Σπαθί", "Σφυρί", "Σιδηρομπουνιά", "Τσεκούρι",
	"Αξίνα", "Λεπίδα", "Μαστίγιο", "Τόξο",
]

const CATEGORY_MULTIPLIER := {
	"Μαχαίρι": 1.0,
	"Σπαθί": 1.3,
	"Σφυρί": 1.6,
	"Σιδηρομπουνιά": 1.9,
	"Τσεκούρι": 2.3,
	"Αξίνα": 2.7,
	"Λεπίδα": 3.2,
	"Μαστίγιο": 3.8,
	"Τόξο": 4.5,
}

const OLD_LEVELS := 9          # πλήθος εικόνων/όπλων ανά κατηγορία (Level1..Level9)
const UPGRADE_MAX_TIER := 3    # νέο upgrade system (Inventory): 1..3
const UPGRADE_ATTACK_BONUS := 2

# Όπλο που έχει ήδη ο παίκτης, κατοχυρωμένο, σε ένα ολοκαίνουργιο save (βλ.
# _grant_starter_weapon_if_new_save). Χωρίς αυτό ΚΑΝΕΝΑ από τα 81 όπλα δεν θα
# ήταν ιδιοκτησία στην αρχή — ο παίκτης θα ξεκινούσε άοπλος.
const STARTER_WEAPON_ID := "Μαχαίρι_1"

# Κάθε εικόνα αναλύθηκε οπτικά και πήρε ένα μοναδικό fantasy όνομα που
# ταιριάζει με το ύφος/υλικό/αίσθημά της (βλ. περιγραφή παράδοσης).
const WEAPON_NAMES := {
	"Μαχαίρι": [
		"Nebulyn Fang", "Emerald Crescent Fang", "Amethyst Serpent Fang",
		"Sworn Heart Dagger", "Thornvine Shard", "Gilt Vine Fang",
		"Tidescale Fin Dagger", "Batwing Bloodfang", "Shattered Frostfang",
	],
	"Σπαθί": [
		"Winterwing Longsword", "Dragoneye Warblade", "Tuskhorn Ripper",
		"Aurelian Rapier", "Sekhmet's Wingblade", "Moonveil Scimitar",
		"Frostgilded Saber", "Emberbloom Flameblade", "Prismshard Greatblade",
	],
	"Σφυρί": [
		"Ironbound Warhammer", "Doomforged Twinhammer", "Ironspike Morningstar",
		"Thornspine Warmace", "Moonstone Morningstar", "Cinderstone Morningstar",
		"Crimson-Banded Warmace", "Voidthorn Mace", "Molten Doombringer",
	],
	"Σιδηρομπουνιά": [
		"Starveil Glove", "Steelclaw Gauntlet", "Infernus Talon",
		"Runebound Voidglove", "Hexcore Gauntlet", "Wraithclaw Gauntlet",
		"Ionforge Fist", "Stormcore Warfists", "Sunshard Warfist",
	],
	"Τσεκούρι": [
		"Stonehide Hatchet", "Cinderfiend Hatchet", "Trailhewn Hatchet",
		"Glyphedge Battleaxe", "Windfeather Warbind", "Sunblaze Labrys",
		"Frostrune Battleaxe", "Hellmaw Doomaxe", "Bloodrend Ravager",
	],
	"Αξίνα": [
		"Silvermoon Sickle", "Voidmoon Reaver", "Jade Crescent Scythe",
		"Brassfire Cleaver", "Boneharvest Reaper", "Stormfiend Scythe",
		"Frostwyrm Reaper", "Glacial Howler Scythe", "Nightshade Reaper",
	],
	"Λεπίδα": [
		"Voidcrescent Blade", "Glacial Crescentfang", "Solarforge Crescent",
		"Tideglyph Fang", "Glacient Starshard", "Amethyst Whirlstar",
		"Sunspiral Bladestar", "Frostwhirl Cyclone", "Demonhorn Talon",
	],
	"Μαστίγιο": [
		"Oxhide Lash", "Briarcoil Lash", "Tidebind Serpentlash",
		"Dragoncoil Whip", "Nightspine Coilwhip", "Viperscale Warlash",
		"Rosebloom Lash", "Gilded Emberlash", "Venomthorn Bramblewhip",
	],
	"Τόξο": [
		"Ashwood Hunting Bow", "Voidhorn Warbow", "Sylvan Knotbow",
		"Feathertotem Bow", "Cherryblossom Warbow", "Verdant Leafbow",
		"Silverwood Rangerbow", "Rubygold Sovereign Bow", "Emerald Windshaft",
	],
}

# item_id ("<category>_<old_level>") -> {"owned": bool, "tier": int}
var _state: Dictionary = {}


func _ready() -> void:
	for category in CATEGORIES:
		for old_level in range(1, OLD_LEVELS + 1):
			var id := _make_id(category, old_level)
			var saved: Dictionary = GameData.get_weapon_state(id)
			_state[id] = saved if not saved.is_empty() else {"owned": false, "tier": 0}
	_grant_starter_weapon_if_new_save()

## Σε ένα ολοκαίνουργιο save (καμία αποθηκευμένη κατάσταση ποτέ για το
## STARTER_WEAPON_ID) δίνει αυτόματα αυτό το όπλο, ιδιοκτησία+tier 1, ώστε ο
## παίκτης να μην ξεκινάει άοπλος. Αν το πούλησε αργότερα, η αποθηκευμένη
## κατάσταση (owned=false) δεν είναι πια κενή, οπότε δεν ξαναδίνεται.
func _grant_starter_weapon_if_new_save() -> void:
	if GameData.get_weapon_state(STARTER_WEAPON_ID).is_empty():
		_state[STARTER_WEAPON_ID] = {"owned": true, "tier": 1}
		_persist(STARTER_WEAPON_ID)


func _make_id(category: String, old_level: int) -> String:
	return "%s_%d" % [category, old_level]


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — ΚΑΤΑΛΟΓΟΣ / ΣΤΑΤΙΚΑ ΔΕΔΟΜΕΝΑ ΟΠΛΟΥ
# ═══════════════════════════════════════════════════════════════════════════

## Όλα τα item ids μιας κατηγορίας, με σταθερή σειρά old_level 1..9.
func get_items_in_category(category: String) -> Array[String]:
	var ids: Array[String] = []
	for old_level in range(1, OLD_LEVELS + 1):
		ids.append(_make_id(category, old_level))
	return ids

func get_category(id: String) -> String:
	return id.substr(0, id.rfind("_"))

func get_old_level(id: String) -> int:
	return int(id.substr(id.rfind("_") + 1))

func get_weapon_name(id: String) -> String:
	var category := get_category(id)
	var old_level := get_old_level(id)
	return WEAPON_NAMES.get(category, [])[old_level - 1]

func get_icon_path(id: String) -> String:
	return "%s%s/Level%d.png" % [WEAPONS_DIR, get_category(id), get_old_level(id)]

## Βασική επίθεση (πριν τα upgrades), ΠΑΝΤΑ μέσα σε 1-20 — δύο συστατικά:
##   - level_component: το κύριο συστατικό, βήμα 2 ανά old_level μέσα στην
##     ΙΔΙΑ κατηγορία (level1=1 ... level9=17).
##   - category_bonus (0-3): μικρό μπόνους βάσει της θέσης της κατηγορίας
##     μέσα στο CATEGORIES, που είναι ήδη σε αύξουσα σειρά ακρίβειας/τιμής
##     (Μαχαίρι το φθηνότερο -> Τόξο το ακριβότερο, βλ. CATEGORY_MULTIPLIER).
## Έτσι η επίθεση ακολουθεί (χωρίς να είναι δέσμια της ίδιας φόρμουλας με)
## την τιμή του όπλου: το φθηνότερο όπλο του παιχνιδιού (Μαχαίρι Level1)
## κάνει 1 επίθεση, το ακριβότερο (Τόξο Level9) κάνει 20 — πριν τα upgrades.
func get_base_attack(id: String) -> int:
	var old_level := get_old_level(id)
	var level_component := 1 + (old_level - 1) * 2   # 1, 3, 5, ..., 17
	var category_rank := CATEGORIES.find(get_category(id))   # 0..8, φθηνό -> ακριβό
	var category_bonus := 0
	if category_rank > 0:
		category_bonus = int(round(category_rank * 3.0 / float(CATEGORIES.size() - 1)))   # 0..3
	return clampi(level_component + category_bonus, 1, 20)

## Πολλαπλασιαστής τιμής βάσει old_level· επεκτείνει γραμμικά την ενότητα
## "Level-based base pricing" του brief (base ×1.0 / ×1.6 / ×2.6 για τα
## πρώτα 3 old_levels) ώστε να καλύπτει και τα old_level 4-9.
func _level_price_multiplier(old_level: int) -> float:
	var n := float(old_level - 1)
	return 1.0 + 0.2 * n * n + 0.4 * n

## Εσωτερική "ισχύς τιμής" ανά old_level (old_level × 10) — ΔΕΝ είναι πια η
## εμφανιζόμενη επίθεση (βλ. get_base_attack παραπάνω), είναι μόνο η βάση
## πάνω στην οποία υπολογίζεται η τιμή αγοράς, όπως πριν την αναδιάταξη των
## στατιστικών όπλων· κρατά τις τιμές του Shop αμετάβλητες.
func _price_power(old_level: int) -> int:
	return old_level * 10

## Τιμή αγοράς στο Weapon Shop (κατηγορία × old_level, χωρίς upgrades).
func get_base_price(id: String) -> int:
	var category := get_category(id)
	var old_level := get_old_level(id)
	var mult: float = CATEGORY_MULTIPLIER.get(category, 1.0)
	return int(round(_price_power(old_level) * mult * _level_price_multiplier(old_level)))

## Κόστος αναβάθμισης 1→2 = 20, 2→3 = 30 (σταθερό, ίδιο για όλα τα όπλα).
func get_upgrade_cost(tier: int) -> int:
	return 20 if tier == 1 else 30

func _upgrade_refund(tier: int) -> int:
	if tier >= 3:
		return 20 + 30
	if tier == 2:
		return 20
	return 0


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — ΚΑΤΑΣΤΑΣΗ ΙΔΙΟΚΤΗΣΙΑΣ / ΑΝΑΒΑΘΜΙΣΗΣ
# ═══════════════════════════════════════════════════════════════════════════

func is_owned(id: String) -> bool:
	return bool(_state.get(id, {}).get("owned", false))

func get_tier(id: String) -> int:
	return int(_state.get(id, {}).get("tier", 0))

## Συνολική επίθεση (βάση + upgrades), πάντα μέσα σε 1-20 — τα upgrades
## μπορούν να "σπρώξουν" ένα ήδη ισχυρό όπλο πάνω από 20, οπότε γίνεται
## clamp εδώ (soft-cap: τα upgrades σε όπλα κοντά στο ανώτατο όριο έχουν
## μικρότερο πραγματικό όφελος — σκόπιμο, όχι bug).
func get_total_attack(id: String) -> int:
	if not is_owned(id):
		return get_base_attack(id)
	return clampi(get_base_attack(id) + (get_tier(id) - 1) * UPGRADE_ATTACK_BONUS, 1, 20)

func can_upgrade(id: String) -> bool:
	return is_owned(id) and get_tier(id) < UPGRADE_MAX_TIER

## Τιμή πώλησης: 50% της αρχικής τιμής αγοράς + επιστροφή όλων των coins
## που ξοδεύτηκαν σε upgrades.
func get_sell_price(id: String) -> int:
	return int(round(get_base_price(id) * 0.5)) + _upgrade_refund(get_tier(id))


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — MUTATIONS
# ═══════════════════════════════════════════════════════════════════════════

## Αγορά όπλου — καλείται ΜΟΝΟ από το Weapon Shop.
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

## Πώληση όπλου — καλείται ΜΟΝΟ από το Inventory. Το όπλο ξανακλειδώνεται
## (πρέπει να ξανα-αγοραστεί από το Shop για να αποκτηθεί ξανά).
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
