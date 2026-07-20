extends Node

# ═══════════════════════════════════════════════════════════════════════════
# Heroes (Autoload) — party/team σύστημα ηρώων
# ═══════════════════════════════════════════════════════════════════════════
# Η ΜΟΝΑΔΙΚΗ πηγή αλήθειας για το νέο party σύστημα (αντικαθιστά το παλιό
# single-character progression). Χωρίζει δύο έννοιες:
#
#   ROSTER  = οι ήρωες που ΚΑΤΕΧΕΙ ο παίκτης (starter + όσους αγοράσει). Κάθε
#             ήρωας έχει δικά του base stats + έως 2 items.
#   SLOTS   = 6 θέσεις σχηματισμού· κάθε μία κρατά ένα uid ήρωα (ή κενό). Τα 2
#             πρώτα ξεκλείδωτα, τα 4 υπόλοιπα κλειδωμένα (μελλοντικό unlock).
#
# Persistence μέσω GameData (ένα ενιαίο "party" dict), ίδιο μοτίβο με
# Currency/KeyInventory. Autoload ΜΕΤΑ τα GameData/WeaponInventory/
# ArmorInventory (το item-buff query τα χρειάζεται) — η φόρτωση αναβάλλεται
# με call_deferred ώστε να έχουν φορτώσει όλα τα άλλα autoloads.
#
# ΕΠΕΚΤΑΣΙΜΟΤΗΤΑ (σχεδιασμένο εξαρχής):
#   - Stats: πρόσθεσε κλειδί στο STAT_KEYS -> auto-persist (base_stats είναι
#     dict με κλειδί το stat).
#   - Slots: άλλαξε NUM_SLOTS / DEFAULT_UNLOCKED.
#   - Rarity/items: κάθε ήρωας έχει πεδίο "rarity" (αχρησιμοποίητο τώρα)· όλη
#     η μετατροπή item->buff ζει ΜΟΝΟ στο item_stat_buffs() — μελλοντικό
#     σύστημα σπανιότητας μπαίνει εκεί χωρίς να αγγίξει UI.

signal changed

# ── Stats ───────────────────────────────────────────────────────────────────
const STAT_KEYS: Array[String] = ["HP", "Damage", "Shield", "AttackSpeed"]
const STAT_LABELS := {
	"HP": "Ζωή", "Damage": "Ζημιά", "Shield": "Ασπίδα", "AttackSpeed": "Ταχύτητα",
}
const STAT_ICONS := {
	"HP": "❤", "Damage": "⚔", "Shield": "🛡", "AttackSpeed": "⚡",
}
const STAT_MIN := 1
const STAT_MAX := 20

# ── Slots ─────────────────────────────────────────────────────────────────
const NUM_SLOTS := 6
const DEFAULT_UNLOCKED: Array = [true, true, false, false, false, false]
const ITEMS_PER_HERO := 2

# ── Καταλογος αγοράσιμων ηρώων (Shop -> tab "Χαρακτήρες") ────────────────────
# Νέος ήρωας = ένα entry εδώ (id/όνομα/εικόνα/τιμή/stats) — τίποτα άλλο.
#
# Τα "base_stats" είναι ΧΕΙΡΟΚΙΝΗΤΑ και ΣΤΑΘΕΡΑ (ίδιο μοτίβο με το χειροκίνητο
# "stat" της armor, βλ. armor_inventory.gd) — ΔΕΝ τυχαιοποιούνται πια, ώστε ο
# χαρακτήρας κάθε ήρωα να έχει νόημα (π.χ. ο Γίγαντας πάντα μεγάλη ζωή/αργός,
# ο Τοξότης πάντα γρήγορος/εύθραυστος) και η τιμή να αντιστοιχεί σε πραγματική
# ισχύ (το άθροισμα των 4 stats μεγαλώνει μαζί με την τιμή: 22/33/44).
#
# Η "price" είναι Dictionary νόμισμα->ποσό (ίδιο σχήμα με ό,τι δέχεται
# Currency.spend). Χαλκός/Δέρμα/Σίδερο βγαίνουν ΟΛΑ από quiz NPC με ΤΗΝ ΙΔΙΑ
# φόρμουλα ανταμοιβής (BASE=2 + Σδυσκολία, βλ. miner_popup.gd/cotton_popup.gd/
# blacksmith_popup.gd) — άρα είναι ΙΣΑΞΙΑ σε δυσκολία απόκτησης. Οι ήρωες
# κοστίζουν το ΙΔΙΟ ποσό και στα τρία (όχι μόνο Χαλκός + λίγο από ένα ακόμα),
# ώστε ο παίκτης να ΑΝΑΓΚΑΖΕΤΑΙ να λύσει εξίσου ασκήσεις και στους 3
# NPC/κατηγορίες (Μεταλλωρύχος/Δερματού/Σιδεράς) για να αγοράσει έναν ήρωα —
# όχι μόνο να φαρμάρει έναν από τους τρεις. Κέρμα (sink, βλ.
# currency_manager.gd) πάνω σε αυτό, σκαλωμένο με την τιμή/ισχύ του ήρωα.
const HERO_DEFS: Array[Dictionary] = [
	{
		"id": "giant", "name": "Βράχος ο Γίγαντας", "avatar": "res://Εικόνες/giant.png",
		"price": {"Χαλκός": 100, "Δέρμα": 100, "Σίδερο": 100, "Κέρμα": 3},
		"base_stats": {"HP": 13, "Damage": 2, "Shield": 5, "AttackSpeed": 2},
	},
	{
		"id": "knight", "name": "Σερ Ατρόμητος", "avatar": "res://Εικόνες/knight.png",
		"price": {"Χαλκός": 200, "Δέρμα": 200, "Σίδερο": 200, "Κέρμα": 5},
		"base_stats": {"HP": 8, "Damage": 10, "Shield": 9, "AttackSpeed": 6},
	},
	{
		"id": "frog", "name": "Βρεκεκέξ ο Τοξότης", "avatar": "res://Εικόνες/archer_frog.png",
		"price": {"Χαλκός": 300, "Δέρμα": 300, "Σίδερο": 300, "Κέρμα": 8},
		"base_stats": {"HP": 4, "Damage": 18, "Shield": 2, "AttackSpeed": 20},
	},
]

# ── Κατάσταση (φορτώνεται από GameData) ─────────────────────────────────────
var _roster: Array = []            # Array[hero dict] — βλ. _make_hero για σχήμα
var _slots: Array = []             # Array[NUM_SLOTS] από uid ("" = κενό)
var _slots_unlocked: Array = []    # Array[NUM_SLOTS] από bool
var _next_uid := 0


func _ready() -> void:
	call_deferred("_load_saved")

func _load_saved() -> void:
	var data: Dictionary = GameData.get_saved_party()
	_roster         = data.get("roster", []).duplicate(true)
	_slots          = data.get("slots", []).duplicate(true)
	_slots_unlocked = data.get("slots_unlocked", []).duplicate(true)
	_next_uid       = int(data.get("next_uid", 0))
	# Γέμισμα/διόρθωση μεγεθών ώστε να είναι πάντα NUM_SLOTS (future-proof αν
	# αλλάξει το NUM_SLOTS ανάμεσα σε εκδόσεις).
	while _slots.size() < NUM_SLOTS: _slots.append("")
	if _slots_unlocked.size() < NUM_SLOTS:
		for i in range(_slots_unlocked.size(), NUM_SLOTS):
			_slots_unlocked.append(bool(DEFAULT_UNLOCKED[i]) if i < DEFAULT_UNLOCKED.size() else false)
	_ensure_starter_hero()
	_persist()
	changed.emit()

## Δημόσιο: καλείται από το GenderSelect ΜΟΛΙΣ επιλεγεί φύλο, ώστε ο starter
## ήρωας να δημιουργηθεί ΤΗΝ ΙΔΙΑ στιγμή (το Heroes autoload έχει ήδη φορτώσει
## πριν επιλεγεί φύλο στην πρώτη εκκίνηση, οπότε δεν αρκεί μόνο το _load_saved).
## Idempotent — δεν κάνει τίποτα αν υπάρχει ήδη ήρωας.
func ensure_starter_hero() -> void:
	if _roster.is_empty():
		_ensure_starter_hero()
		_persist()
		changed.emit()

## Πρώτη εκκίνηση με επιλεγμένο φύλο αλλά κενό roster: ο χαρακτήρας που
## διάλεξε ο παίκτης (boy/girl) γίνεται ο ΠΡΩΤΟΣ ήρωας, με ΟΛΑ τα stats = 1,
## και μπαίνει στη θέση 0. Idempotent — τρέχει μία μόνο φορά.
func _ensure_starter_hero() -> void:
	if not _roster.is_empty():
		return
	if not GameData.has_hero_gender():
		return
	var avatar := GameData.HERO_BOY_PATH if GameData.get_hero_gender() == "boy" else GameData.HERO_GIRL_PATH
	var hero_name := "Άλντρικ" if GameData.get_hero_gender() == "boy" else "Λύρα"
	var base := {}
	for k in STAT_KEYS:
		base[k] = 1
	var hero := _make_hero("starter", hero_name, avatar, base)
	_roster.append(hero)
	_slots[0] = hero["uid"]

func _make_hero(def_id: String, hero_name: String, avatar: String, base_stats: Dictionary) -> Dictionary:
	var uid := "hero_%d" % _next_uid
	_next_uid += 1
	var items: Array = []
	for _i in range(ITEMS_PER_HERO):
		items.append("")
	return {
		"uid": uid,
		"def_id": def_id,
		"name": hero_name,
		"avatar": avatar,
		"base_stats": base_stats.duplicate(),
		"items": items,
		"rarity": "common",   # future-proof, αχρησιμοποίητο
	}

func _persist() -> void:
	GameData.save_party({
		"roster": _roster,
		"slots": _slots,
		"slots_unlocked": _slots_unlocked,
		"next_uid": _next_uid,
	})


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — ROSTER
# ═══════════════════════════════════════════════════════════════════════════

func get_roster() -> Array:
	return _roster

func get_hero(uid: String) -> Dictionary:
	for h in _roster:
		if h["uid"] == uid:
			return h
	return {}

## True αν ο παίκτης κατέχει ήδη τον ήρωα του καταλόγου με αυτό το def_id.
## Κάθε αγοράσιμος ήρωας μπορεί να αγοραστεί ΜΟΝΟ μία φορά — βλ. buy_hero.
func owns_hero_def(def_id: String) -> bool:
	for h in _roster:
		if str(h.get("def_id", "")) == def_id:
			return true
	return false

## Τα ΣΤΑΘΕΡΑ base stats ενός αγοράσιμου ήρωα του καταλόγου (HERO_DEFS) — ίδια
## σε κάθε save/παρτίδα, ώστε το Shop να δείχνει ΑΚΡΙΒΩΣ αυτά που θα πάρει ο
## παίκτης.
func get_hero_stats(def_id: String) -> Dictionary:
	return (_hero_def(def_id).get("base_stats", {}) as Dictionary).duplicate()

## Αγορά ήρωα από τον κατάλογο (Shop). Παίρνει ΑΚΡΙΒΩΣ τα σταθερά stats του
## καταλόγου (get_hero_stats). Κάθε ήρωας αγοράζεται ΜΙΑ φορά — αν κατέχεται
## ήδη, η αγορά αποτυγχάνει (χωρίς χρέωση). Επιστρέφει το uid του νέου ήρωα,
## ή "" σε αποτυχία.
func buy_hero(def_id: String) -> String:
	var def := _hero_def(def_id)
	if def.is_empty():
		return ""
	if owns_hero_def(def_id):
		return ""
	var base := get_hero_stats(def_id)
	if not Currency.spend(def["price"] as Dictionary):
		return ""
	var hero := _make_hero(def_id, def["name"], def["avatar"], base)
	_roster.append(hero)
	_persist()
	changed.emit()
	return hero["uid"]

func _hero_def(def_id: String) -> Dictionary:
	for d in HERO_DEFS:
		if d["id"] == def_id:
			return d
	return {}


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — SLOTS
# ═══════════════════════════════════════════════════════════════════════════

func get_slot_uid(i: int) -> String:
	return str(_slots[i]) if i >= 0 and i < _slots.size() else ""

func get_slot_hero(i: int) -> Dictionary:
	var uid := get_slot_uid(i)
	return get_hero(uid) if uid != "" else {}

func is_slot_unlocked(i: int) -> bool:
	return i >= 0 and i < _slots_unlocked.size() and bool(_slots_unlocked[i])

## Αναθέτει έναν ήρωα σε μια θέση. Ένας ήρωας μπορεί να είναι σε ΜΙΑ θέση —
## αν είναι ήδη αλλού, αφαιρείται από εκεί. uid == "" -> αδειάζει τη θέση.
func assign_to_slot(i: int, uid: String) -> void:
	if not is_slot_unlocked(i):
		return
	if uid != "":
		for j in range(_slots.size()):
			if _slots[j] == uid:
				_slots[j] = ""
	_slots[i] = uid
	_persist()
	changed.emit()

func clear_slot(i: int) -> void:
	assign_to_slot(i, "")


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — ITEMS & STATS
# ═══════════════════════════════════════════════════════════════════════════

## Εξοπλίζει item (weapon Ή armor id) στη θέση item_idx (0..ITEMS_PER_HERO-1)
## του ήρωα. item_id == "" -> αδειάζει. Αγνοεί αν το item δεν ανήκει.
## Κάθε item μπορεί να είναι εξοπλισμένο σε ΜΙΑ μόνο θέση, σε ΕΝΑΝ μόνο ήρωα —
## αν είναι ήδη αλλού (ίδιος ή άλλος ήρωας), αφαιρείται από εκεί πρώτα (ίδιο
## μοτίβο με το assign_to_slot για τους ήρωες στα slots).
func equip_item(uid: String, item_idx: int, item_id: String) -> void:
	var hero := get_hero(uid)
	if hero.is_empty() or item_idx < 0 or item_idx >= ITEMS_PER_HERO:
		return
	if item_id != "":
		var cat := _catalog_for(item_id)
		if cat == null or not cat.is_owned(item_id):
			return
		_unequip_item_everywhere(item_id)
	hero["items"][item_idx] = item_id
	_persist()
	changed.emit()

## Αφαιρεί ένα item id από ΚΑΘΕ θέση κάθε ήρωα στο roster (το κρατά μοναδικό
## πριν ανατεθεί σε νέα θέση — βλ. equip_item).
func _unequip_item_everywhere(item_id: String) -> void:
	for h in _roster:
		var items: Array = h.get("items", [])
		for i in range(items.size()):
			if str(items[i]) == item_id:
				items[i] = ""

## Το uid του ήρωα που έχει εξοπλισμένο αυτό το item (σε οποιαδήποτε θέση), ή
## "" αν κανείς. Χρήσιμο στο UI για να δείχνει «σε ποιον ήρωα» είναι ήδη.
func hero_uid_holding_item(item_id: String) -> String:
	if item_id == "":
		return ""
	for h in _roster:
		for it in h.get("items", []):
			if str(it) == item_id:
				return str(h["uid"])
	return ""

## Ποιο catalog (WeaponInventory/ArmorInventory) ανήκει ένα item id, ή null.
func _catalog_for(item_id: String) -> EquipmentCatalog:
	var cut := item_id.rfind("_")
	if cut < 0:
		return null
	var cat := item_id.substr(0, cut)
	if WeaponInventory.categories.has(cat):
		return WeaponInventory
	if ArmorInventory.categories.has(cat):
		return ArmorInventory
	return null

## Η ΜΟΝΑΔΙΚΗ μετατροπή item -> stat buff ΠΟΥ ΜΕΤΡΑΕΙ στην πραγματική ισχύ
## ενός εξοπλισμένου ήρωα (get_buff_stats/get_final_stats) — επιστρέφει {} αν
## το item δεν ανήκει (ακόμα) στον παίκτη. Τα ίδια τα buffs είναι ΧΕΙΡΟΚΙΝΗΤΑ
## ανά αντικείμενο (πεδίο "buffs" στο items[category] του weapon/
## armor_inventory.gd) — βλ. EquipmentCatalog.get_item_buffs.
func item_stat_buffs(item_id: String) -> Dictionary:
	var cat := _catalog_for(item_id)
	if cat == null or not cat.is_owned(item_id):
		return {}
	return cat.get_item_buffs(item_id)

## ΓΙΑ ΕΜΦΑΝΙΣΗ ΜΟΝΟ (Shop/Inventory) — ίδιο με το item_stat_buffs() αλλά δεν
## απαιτεί ιδιοκτησία, ώστε το Shop να δείχνει τα stats ΚΑΙ σε αντικείμενα
## πριν την αγορά.
func display_item_buffs(item_id: String) -> Dictionary:
	var cat := _catalog_for(item_id)
	if cat == null:
		return {}
	return cat.get_item_buffs(item_id)

## Πληροφορίες εμφάνισης ενός item id (για τον επιλογέα/κάρτες).
func item_info(item_id: String) -> Dictionary:
	var cat := _catalog_for(item_id)
	if cat == null:
		return {}
	return {
		"id": item_id,
		"name": cat.get_item_name(item_id),
		"icon": cat.get_icon_path(item_id),
		"buffs": item_stat_buffs(item_id),
		"is_weapon": cat == WeaponInventory,
	}

## Όλα τα items (όπλα + πανοπλίες) που κατέχει ο παίκτης — για τον επιλογέα
## items μέσα στο HeroSlotPopup.
func get_owned_items() -> Array:
	var result: Array = []
	for cat in [WeaponInventory, ArmorInventory]:
		for category in cat.categories:
			for id in cat.get_items_in_category(category):
				if cat.is_owned(id):
					result.append(item_info(id))
	return result

## Base stats του ήρωα (χωρίς items), με 0 fallback ανά stat.
func get_base_stats(hero: Dictionary) -> Dictionary:
	var out := {}
	for k in STAT_KEYS:
		out[k] = int(hero.get("base_stats", {}).get(k, STAT_MIN))
	return out

## Άθροισμα των buffs απ' όλα τα εξοπλισμένα items του ήρωα, ανά stat.
func get_buff_stats(hero: Dictionary) -> Dictionary:
	var out := {}
	for k in STAT_KEYS:
		out[k] = 0
	for item_id in hero.get("items", []):
		if str(item_id) == "":
			continue
		for k in item_stat_buffs(item_id):
			out[k] = int(out.get(k, 0)) + int(item_stat_buffs(item_id)[k])
	return out

## Τελικά stats = clamp(base + buffs, STAT_MIN, STAT_MAX).
func get_final_stats(hero: Dictionary) -> Dictionary:
	var base := get_base_stats(hero)
	var buff := get_buff_stats(hero)
	var out := {}
	for k in STAT_KEYS:
		out[k] = clampi(int(base[k]) + int(buff[k]), STAT_MIN, STAT_MAX)
	return out

## Η εικόνα ενός ήρωα, κομμένη στο περιεχόμενό της (κοινή πηγή GameData —
## ίδιος alpha-crop με boy/girl). Επιστρέφει null αν λείπει.
func hero_texture(hero: Dictionary) -> Texture2D:
	return GameData.get_cropped_texture(str(hero.get("avatar", "")))


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — ΛΟΓΙΚΗ ΜΑΧΗΣ (κοινή για ΟΛΑ τα boss: Μόργκανα + mini bosses)
# ═══════════════════════════════════════════════════════════════════════════
# Ζει ΕΔΩ (και όχι σε κάποιο boss popup) ώστε κάθε boss να χρησιμοποιεί ΤΗΝ ΙΔΙΑ
# καμπύλη/μέσο όρο — αλλάζει μόνο το στατιστικό του boss. Νέο boss = ένα ακόμα
# entry στο BOSS_DEFS του mini_boss_popup.gd, καμία αλλαγή εδώ.

## Οι ήρωες που βρίσκονται ΤΩΡΑ σε ενεργή θέση της ομάδας (party slots).
func get_active_party() -> Array:
	var out: Array = []
	for i in range(NUM_SLOTS):
		if not is_slot_unlocked(i):
			continue
		var hero := get_slot_hero(i)
		if not hero.is_empty():
			out.append(hero)
	return out

## Ο ΣΥΝΟΛΙΚΟΣ μέσος όρος ΟΛΩΝ των stats ΟΛΩΝ των ενεργών ηρώων μαζί: άθροισμα
## κάθε stat κάθε ήρωα / (πλήθος ηρώων × πλήθος stats) — ΕΝΑΣ ενιαίος μέσος
## όρος, όχι ένας ανά ήρωα. Χρησιμοποιεί τα ΤΕΛΙΚΑ stats (base + buffs items).
## 0.0 σε άδεια ομάδα.
func get_party_average_stat() -> float:
	var heroes := get_active_party()
	if heroes.is_empty():
		return 0.0
	var total := 0
	for hero in heroes:
		var stats := get_final_stats(hero)
		for key in STAT_KEYS:
			total += int(stats[key])
	return float(total) / float(heroes.size() * STAT_KEYS.size())

## Πιθανότητα νίκης της ομάδας απέναντι σε boss με στατιστικό boss_stat.
## Ασύμμετρη καμπύλη 2 κομματιών, με 3 σταθερά σημεία:
##   μέσος όρος 1 -> 0%,  μέσος όρος == boss_stat -> 50%,  20 -> 100%
##   [1, boss_stat]  : ΤΕΤΡΑΓΩΝΙΚΗ (αργή στην αρχή — θέλει πραγματικό grind)
##   [boss_stat, 20] : γραμμική (η πρόοδος ανταμείβεται πιο ομαλά)
## Όσο ΜΙΚΡΟΤΕΡΟ το boss_stat, τόσο ΕΥΚΟΛΟΤΕΡΟ το boss (το 50% έρχεται νωρίτερα):
## καλικάντζαρος 5, δέντρο 10, Μόργκανα 15. Με boss_stat = 15 δίνει ΑΚΡΙΒΩΣ την
## αρχική καμπύλη της Μόργκανας — καμία αλλαγή στη δυσκολία της.
func win_probability(party_avg: float, boss_stat: int) -> float:
	# +0.001 στο κάτω όριο: αποτρέπει διαίρεση με 0 αν κάποιο boss πάρει stat 1.
	var b: float = clampf(float(boss_stat), float(STAT_MIN) + 0.001, float(STAT_MAX))
	var avg: float = clampf(party_avg, float(STAT_MIN), float(STAT_MAX))
	if avg <= b:
		var t: float = (avg - 1.0) / (b - 1.0)
		return 0.5 * t * t
	var t2: float = (avg - b) / (float(STAT_MAX) - b)
	return 0.5 + 0.5 * t2
