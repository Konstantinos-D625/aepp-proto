extends Node

# ═══════════════════════════════════════════════════════════════════════════
# Achievements (Autoload) — σύστημα επιτευγμάτων
# ═══════════════════════════════════════════════════════════════════════════
# Φάση 0 της online επέκτασης (accounts/friends/clans): τα επιτεύγματα είναι
# ένα από τα κομμάτια «προόδου» που θα κοινοποιούνται δημόσια στους φίλους
# (βλ. Scripts/player_profile.gd -> build_public_profile). Δουλεύει 100%
# offline — ΚΑΝΕΝΑΣ server δεν χρειάζεται εδώ.
#
# ΛΟΓΙΚΗ: κάθε επίτευγμα έχει μια συνθήκη που ΠΑΡΑΓΕΤΑΙ από την ήδη αποθηκευμένη
# κατάσταση του παιχνιδιού (boss defeats, roster, εξοπλισμός, streak). Το
# check_all() σαρώνει τα ανεξέλεγκτα επιτεύγματα και ξεκλειδώνει όσα πληρούνται.
# Είναι MONOTONIC: μόλις ξεκλειδώσει ένα, μένει ξεκλειδωμένο ακόμα κι αν η
# κατάσταση αλλάξει (π.χ. πέσει το streak) — γι' αυτό το ξεκλείδωμα ΑΠΟΘΗΚΕΥΕΤΑΙ
# (δεν υπολογίζεται εκ νέου κάθε φορά).
#
# ΕΝΕΡΓΟΠΟΙΗΣΗ: αντί για polling, το autoload συνδέεται στα ΥΠΑΡΧΟΝΤΑ signals που
# σηματοδοτούν αλλαγή προόδου (GameData.progress_changed/streak_changed,
# Heroes.changed, Weapon/ArmorInventory.changed) και ξανα-ελέγχει. Έτσι δεν
# χρειάστηκε καμία αλλαγή στα boss/quiz scenes.
#
# PERSISTENCE: μέσω GameData (get_saved_achievements/save_achievements) — ίδιο
# μοτίβο με Currency/Heroes/KeyInventory. Autoload ΤΕΛΕΥΤΑΙΟ (μετά τα Heroes/
# Weapon/ArmorInventory που διαβάζει), με call_deferred ώστε να έχουν φορτώσει.
#
# ΕΠΕΚΤΑΣΙΜΟΤΗΤΑ: νέο επίτευγμα = ένα entry στο DEFS + ένα case στο _is_met().

## Εκπέμπεται μία φορά, τη στιγμή που ξεκλειδώνει κάθε νέο επίτευγμα — για
## μελλοντικό toast/ειδοποίηση στο UI (δεν χρησιμοποιείται ακόμα).
signal achievement_unlocked(id: String)

const DEFS: Array[Dictionary] = [
	{"id": "first_gear",    "name": "Πρώτος Εξοπλισμός",     "icon": "🛡", "desc": "Αγόρασες το πρώτο σου όπλο ή πανοπλία από το Shop."},
	{"id": "first_hero",    "name": "Νέος Σύντροφος",        "icon": "🤝", "desc": "Στρατολόγησες τον πρώτο σου ήρωα από το Shop."},
	{"id": "full_party",    "name": "Πλήρης Ομάδα",          "icon": "⚔", "desc": "Γέμισες και τις δύο θέσεις της ενεργής ομάδας σου."},
	{"id": "goblin_slain",  "name": "Ο Καλικάντζαρος Έπεσε", "icon": "👺", "desc": "Νίκησες τον Ζούμπα και ξεκλείδωσες το Κάστρο."},
	{"id": "tree_slain",    "name": "Άρχοντας του Δάσους",   "icon": "🌳", "desc": "Νίκησες το Στοιχειωμένο Δέντρο."},
	{"id": "morgana_slain", "name": "Η Μάγισσα Νικήθηκε",    "icon": "🔮", "desc": "Νίκησες τη Μόργκανα."},
	{"id": "streak_3",      "name": "Σταθερή Μελέτη",        "icon": "🔥", "desc": "Έφτασες σε σερί (streak) 3 ημερών."},
	{"id": "streak_7",      "name": "Βδομάδα Αφοσίωσης",     "icon": "🔥", "desc": "Έφτασες σε σερί (streak) 7 ημερών."},
	{"id": "streak_30",     "name": "Μήνας Πρωταθλητή",      "icon": "🏆", "desc": "Έφτασες σε σερί (streak) 30 ημερών."},
]

# id επιτεύγματος -> ημερομηνία ξεκλειδώματος ("YYYY-MM-DD")
var _unlocked: Dictionary = {}


func _ready() -> void:
	# Αναβολή ώστε GameData/Heroes/Weapon/ArmorInventory να έχουν φορτώσει το
	# save τους (ίδιο μοτίβο με Heroes/Currency autoloads).
	call_deferred("_load_and_bind")

func _load_and_bind() -> void:
	_unlocked = GameData.get_saved_achievements().duplicate(true)
	GameData.progress_changed.connect(check_all)
	GameData.streak_changed.connect(_on_streak_changed)
	Heroes.changed.connect(check_all)
	WeaponInventory.changed.connect(check_all)
	ArmorInventory.changed.connect(check_all)
	check_all()

func _on_streak_changed(_new_streak: int) -> void:
	check_all()


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API
# ═══════════════════════════════════════════════════════════════════════════

## Τα ids όσων επιτευγμάτων έχουν ξεκλειδωθεί (για το δημόσιο προφίλ / UI).
func get_unlocked_ids() -> Array:
	return _unlocked.keys()

func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)

func unlocked_count() -> int:
	return _unlocked.size()

func total_count() -> int:
	return DEFS.size()

## Όλος ο κατάλογος με flag/ημερομηνία ξεκλειδώματος — έτοιμο για μελλοντική
## οθόνη επιτευγμάτων (μία εγγραφή ανά DEF, με "unlocked": bool + "date").
func get_all() -> Array:
	var out: Array = []
	for d in DEFS:
		var e: Dictionary = d.duplicate()
		var id := str(d["id"])
		e["unlocked"] = _unlocked.has(id)
		e["date"] = str(_unlocked.get(id, ""))
		out.append(e)
	return out


# ═══════════════════════════════════════════════════════════════════════════
# ΞΕΚΛΕΙΔΩΜΑ
# ═══════════════════════════════════════════════════════════════════════════

## Σαρώνει όλα τα μη-ξεκλειδωμένα επιτεύγματα και ξεκλειδώνει όσα πληρούνται
## ΤΩΡΑ. Idempotent + monotonic — ασφαλές να καλείται όσο συχνά θέλει κανείς.
func check_all() -> void:
	var newly: Array[String] = []
	for d in DEFS:
		var id := str(d["id"])
		if _unlocked.has(id):
			continue
		if _is_met(id):
			_unlocked[id] = Time.get_date_string_from_system()
			newly.append(id)
	if not newly.is_empty():
		GameData.save_achievements(_unlocked)
		for id in newly:
			achievement_unlocked.emit(id)

func _is_met(id: String) -> bool:
	match id:
		"first_gear":    return _owns_any_gear()
		"first_hero":    return _recruited_any_hero()
		"full_party":    return Heroes.get_active_party().size() >= 2
		"goblin_slain":  return GameData.is_mini_boss_defeated("goblin")
		"tree_slain":    return GameData.is_mini_boss_defeated("tree")
		"morgana_slain": return GameData.has_defeated_boss()
		"streak_3":      return GameData.get_streak() >= 3
		"streak_7":      return GameData.get_streak() >= 7
		"streak_30":     return GameData.get_streak() >= 30
	return false


# ═══════════════════════════════════════════════════════════════════════════
# ΒΟΗΘΗΤΙΚΑ (παράγουν συνθήκες από την ΥΠΑΡΧΟΥΣΑ αποθηκευμένη κατάσταση)
# ═══════════════════════════════════════════════════════════════════════════

## True αν ο παίκτης κατέχει έστω ένα όπλο ή πανοπλία (δεν υπάρχει πια starter
## εξοπλισμός — όλα αγοράζονται/κερδίζονται, βλ. weapon/armor_inventory.gd).
func _owns_any_gear() -> bool:
	for cat in [WeaponInventory, ArmorInventory]:
		for category in cat.categories:
			for id in cat.get_items_in_category(category):
				if cat.is_owned(id):
					return true
	return false

## True αν ο παίκτης έχει στρατολογήσει έστω έναν αγοράσιμο ήρωα του καταλόγου
## (giant/knight/frog) — ο starter (def_id "starter") ΔΕΝ μετράει.
func _recruited_any_hero() -> bool:
	for d in Heroes.HERO_DEFS:
		if Heroes.owns_hero_def(str(d["id"])):
			return true
	return false
