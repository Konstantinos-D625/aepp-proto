extends Node

# ═══════════════════════════════════════════════════════════════════════════
# GameData (Autoload / Singleton)
# ═══════════════════════════════════════════════════════════════════════════
# Το project δεν είχε προϋπάρχον σύστημα αποθήκευσης, streak ή ασκήσεων —
# αυτό το Autoload είναι η ΠΡΩΤΗ και ΜΟΝΑΔΙΚΗ πηγή αλήθειας (single source
# of truth) για τα δεδομένα αυτά. Ακολουθεί το ίδιο μοτίβο αποθήκευσης
# (ConfigFile, "user://...") που χρησιμοποιεί ήδη το Scripts/OptionsMenu.gd
# για τις ρυθμίσεις ήχου, ώστε να μην εισάγεται δεύτερο/διαφορετικό save
# architecture στο project.
#
# ΚΑΝΟΝΑΣ ΓΙΑ ΜΕΛΛΟΝΤΙΚΗ ΕΠΕΚΤΑΣΗ:
#   - Οποιοδήποτε νέο σύστημα θέλει να ανανεώσει το streak πρέπει να καλεί
#     increment_streak() — να ΜΗΝ ξαναγράφεται λογική streak αλλού.
#   - Το Daily Quest (3 levels, βλ. daily_quest_exercises.gd) καλεί
#     record_daily_quest_result(levels_completed) ΜΙΑ φορά, στο τέλος της
#     απόπειρας (είτε επιτυχία είτε αποτυχία) — όχι ανά ερώτηση.
#   - Οποιοδήποτε νέο save-data πρέπει να προστίθεται ΕΔΩ, όχι σε νέο
#     ξεχωριστό save system.
# ═══════════════════════════════════════════════════════════════════════════

const SAVE_PATH := "user://game_data.cfg"

# Εικόνες του βασικού ήρωα ανά φύλο — η ΜΟΝΑΔΙΚΗ πηγή για όλες τις οθόνες που
# δείχνουν τον ήρωα (Χαρακτήρες, Character Edit, μάχη με Morgana). Το παλιό
# avatar.png ΔΕΝ χρησιμοποιείται πλέον πουθενά.
const HERO_BOY_PATH  := "res://Εικόνες/boy.png"
const HERO_GIRL_PATH := "res://Εικόνες/girl.png"

# Διακόπτης μόνιμης αποθήκευσης: όταν true, το _load()/_save() διαβάζουν/
# γράφουν στο δίσκο, ώστε ΟΛΑ (φύλο ήρωα, χρήματα/υλικά, κλειδιά, όπλα,
# πανοπλίες, streak, daily quest, stat bonus, boss gate, εξοπλισμός) να
# επιβιώνουν μετά το κλείσιμο του παιχνιδιού. Γύρνα το σε false ΜΟΝΟ για
# δοκιμές όπου θέλεις κάθε εκκίνηση να ξεκινάει από τα αρχικά.
const SAVE_ENABLED := true

## Εκπέμπεται κάθε φορά που αλλάζει το streak (αύξηση ή μηδενισμός λόγω
## παράλειψης ημέρας). Οποιοδήποτε UI στοιχείο (π.χ. το εικονίδιο streak στο
## HUD) πρέπει να συνδέεται εδώ αντί να κάνει polling, ώστε να ενημερώνεται
## αυτόματα.
signal streak_changed(new_streak: int)

## Εκπέμπεται όταν αλλάζει ένα «ορόσημο» προόδου (νίκη σε boss/mini boss ή
## ολοκλήρωση Daily Quest) — το Achievements autoload συνδέεται εδώ για να
## επαναξιολογεί τα επιτεύγματα χωρίς polling. Ξεχωριστό από το streak_changed
## (που αφορά ΜΟΝΟ το streak).
signal progress_changed

# ── Streak ────────────────────────────────────────────────────────────────
var streak: int = 0
var last_streak_date: String = ""              # "YYYY-MM-DD" — τελευταία μέρα που ανανεώθηκε το streak

# ── Daily Quest (3 levels: Σωστό/Λάθος -> Πολλαπλή -> Αντιστοίχιση) ────────
# Απεριόριστες προσπάθειες ΑΝΑ ΜΕΡΑ — μια αποτυχία δεν κλειδώνει τίποτα, ο
# παίκτης μπορεί να ξαναπροσπαθήσει αμέσως (βλ. daily_quest_exercises.gd:
# _restart_attempt()). Μόλις όμως πετύχει ΠΛΗΡΗ ολοκλήρωση (και των 3 levels)
# ΜΙΑ φορά μέσα στη μέρα, κλειδώνει: καμία άλλη προσπάθεια μέχρι αύριο (βλ.
# record_daily_quest_result). Γι' αυτό τα 2 πεδία παρακάτω ενημερώνονται ΜΟΝΟ
# σε επιτυχία — μια αποτυχημένη απόπειρα δεν αφήνει κανένα ίχνος, καμία
# ανάγκη να επιβιώνει ενδιάμεση πρόοδο (level/ερώτηση) μετά από επανεκκίνηση,
# ίδια λογική με το πώς τα quiz του Cotton/Miner/Blacksmith δεν κρατάνε
# ενδιάμεση πρόοδο ανάμεσα σε επισκέψεις.
var daily_quest_completed_date: String = ""     # "YYYY-MM-DD" — πότε ΠΕΤΥΧΕ πλήρως ο παίκτης (άδειο αν όχι ακόμα σήμερα)
var daily_quest_levels_completed: int = 0       # πάντα 3 όταν daily_quest_completed_date == σήμερα (αλλιώς άσχετο)

# ── Weapon inventory (WeaponInventory autoload) ──────────────────────────
# item_id -> {"owned": bool, "tier": int}. Το GameData είναι ΜΟΝΟ ο
# persistence layer εδώ· η λογική (κατάλογος όπλων, τιμές, κανόνες) ζει στο
# Scripts/weapon_inventory.gd, ακολουθώντας τον κανόνα παραπάνω ότι κάθε νέο
# save-data προστίθεται ΕΔΩ και όχι σε ξεχωριστό save system.
var weapons: Dictionary = {}

# ── Boss fight retry (boss_popup.gd) ────────────────────────────────────────
# true = ο παίκτης έχει ΗΔΗ ηττηθεί από τη Μόργκανα, οπότε κάθε νέα προσπάθεια
# κοστίζει Κέρματα (βλ. boss_popup.gd -> RETRY_COST). Καθαρίζει σε νίκη.
# ΑΝΤΙΚΑΤΕΣΤΗΣΕ το παλιό «loss gate» (snapshot των 5 παλιών stats + απαίτηση
# +1 σε καθένα), που βασιζόταν στο ΠΑΛΙΟ σύστημα στατιστικών εξοπλισμού και
# δεν ισχύει πια μετά το party/hero σύστημα (βλ. Scripts/heroes.gd).
var boss_lost_once: bool = false

# ── Νίκη κατά της Μόργκανας (κύριο boss) — μόνιμο ορόσημο προόδου ─────────────
# true μόλις νικηθεί ΜΙΑ φορά η Μόργκανα (monotonic — δεν ξαναγίνεται false).
# ΞΕΧΩΡΙΣΤΟ από το boss_lost_once (που αφορά μόνο τη χρέωση επανάληψης και
# μηδενίζεται σε κάθε νίκη): αυτό μένει μόνιμα true, ώστε το «κεφάλαιο» του
# παίκτη (Scripts/player_profile.gd get_region) και το αντίστοιχο επίτευγμα να
# ξέρουν ότι η Μόργκανα έχει νικηθεί.
var boss_defeated: bool = false

# ── Mini bosses (mini_boss_popup.gd) ────────────────────────────────────────
# boss_id -> {"defeated": bool, "lost_once": bool}. Ίδια δύο έννοιες με τη
# Μόργκανα παραπάνω, αλλά ΑΝΑ boss (ένα entry ανά boss_id του BOSS_DEFS), γιατί
# ο καλικάντζαρος και το δέντρο νικιούνται/χάνονται ξεχωριστά:
#   - "lost_once": ο παίκτης έχει ηττηθεί, οπότε κάθε νέα προσπάθεια κοστίζει
#     Κέρματα (βλ. mini_boss_popup.gd -> RETRY_COST).
#   - "defeated": το boss έχει νικηθεί ΟΡΙΣΤΙΚΑ — δεν ξαναπαίζεται ποτέ (σε
#     αντίθεση με τη Μόργκανα, όπου η νίκη απλώς μηδενίζει τη χρέωση). Έτσι η
#     ανταμοιβή του κάθε mini boss δίνεται ΜΙΑ μόνο φορά και δεν είναι farmable.
# Ένα ενιαίο Dictionary (αντί για δύο) ώστε νέο mini boss να μη χρειάζεται
# καμία αλλαγή εδώ — αρκεί το entry του στο BOSS_DEFS.
var mini_bosses: Dictionary = {}

# ── Νομίσματα/υλικά (Currency autoload, βλ. Scripts/currency_manager.gd) ─────
# currency_name -> ποσό. Το GameData είναι ΜΟΝΟ ο persistence layer· η λογική
# (κατάλογος, χρώματα, spend/add) ζει στο currency_manager.gd, ίδιο μοτίβο με
# τα όπλα (weapons παραπάνω).
var currencies: Dictionary = {}

# ── Κλειδιά παζλ κάστρου (KeyInventory autoload, βλ. Scripts/key_inventory.gd) ─
# category -> Array τιμών. Αποθηκεύεται ξεχωριστά από τα currencies ώστε να
# επιβιώνει και η πραγματική λίστα τιμών (όχι μόνο το πλήθος που φαίνεται στην
# Αποθήκη) — τα δύο μένουν συνεπή γιατί σώζονται μαζί σε κάθε add/remove κλειδιού.
var keys: Dictionary = {}

# ── Party/roster ηρώων (Heroes autoload, βλ. Scripts/heroes.gd) ──────────────
# Το GameData είναι ΜΟΝΟ ο persistence layer· όλη η λογική (roster, slots,
# stats, item buffs, αγορά ηρώων) ζει στο heroes.gd — ίδιο μοτίβο με τα
# currencies/weapons. Ένα ενιαίο Dictionary ώστε roster + slots + unlocks +
# ο μετρητής uid να σώζονται ΜΑΖΙ και να μένουν πάντα συνεπή.
var party: Dictionary = {}

# ── Επιτεύγματα (Achievements autoload, βλ. Scripts/achievements.gd) ──────────
# id επιτεύγματος -> ημερομηνία ξεκλειδώματος. Το GameData είναι ΜΟΝΟ ο
# persistence layer· ο κατάλογος + η λογική ξεκλειδώματος ζουν στο
# achievements.gd (ίδιο μοτίβο με currencies/party).
var achievements: Dictionary = {}

# ── Side quest του Κάστρου (castle_popup.gd) — μόνιμο ορόσημο ─────────────────
# true μόλις ο παίκτης φτάσει ΜΙΑ φορά στο Main Bailey (τελικό δωμάτιο) —
# monotonic, ίδιο μοτίβο με boss_defeated. Εμποδίζει να ξαναδοθεί η ανταμοιβή
# ολοκλήρωσης (50 Χαλκός/Σίδερο/Δέρμα, 150 Κέρμα, Golden Armor) σε κάθε
# επόμενη επίσκεψη στο ίδιο δωμάτιο.
var castle_completed: bool = false


func _ready() -> void:
	_load()
	_check_streak_expiry()


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — STREAK (η ΜΟΝΑΔΙΚΗ συνάρτηση ανανέωσης streak στο project)
# ═══════════════════════════════════════════════════════════════════════════

## Ανανεώνει το streak κατά 1, το πολύ μία φορά ανά ημερολογιακή ημέρα.
## ΚΑΘΕ μελλοντικό σύστημα (daily quest, δώρα, κ.λπ.) που θέλει να αυξήσει
## το streak πρέπει να καλεί αυτή τη συνάρτηση αντί να υλοποιεί δική του.
func increment_streak() -> void:
	var today := _today_string()
	if last_streak_date == today:
		return # έχει ήδη ανανεωθεί σήμερα — αποφυγή διπλής μέτρησης
	streak += 1
	last_streak_date = today
	_save()
	streak_changed.emit(streak)

## Μηδενίζει το streak αμέσως — καλείται όταν διαπιστωθεί ότι πέρασε μια
## ολόκληρη μέρα χωρίς να ολοκληρωθεί το Daily Quest (βλ. _check_streak_expiry).
## Ίδιο μοτίβο με το increment_streak() — η ΜΟΝΑΔΙΚΗ συνάρτηση μηδενισμού
## streak στο project.
func reset_streak() -> void:
	if streak == 0 and last_streak_date == "":
		return # ήδη μηδενισμένο — αποφυγή περιττού save/signal
	streak = 0
	last_streak_date = ""
	_save()
	streak_changed.emit(streak)

## Τρέχουσα τιμή streak, μετά από έλεγχο μήπως πέρασε μέρα χωρίς ολοκλήρωση
## (βλ. _check_streak_expiry). Το UI (π.χ. το εικονίδιο streak στο HUD) πρέπει
## να διαβάζει το streak ΜΕΣΩ αυτής της συνάρτησης, όχι απευθείας το πεδίο
## streak, ώστε να «πιάνει» έγκαιρα τυχόν μηδενισμό λόγω παράλειψης.
func get_streak() -> int:
	_check_streak_expiry()
	return streak

## Αν η τελευταία ανανέωση streak δεν ήταν ούτε σήμερα ούτε χθες, σημαίνει ότι
## πέρασε τουλάχιστον μία ολόκληρη ημέρα χωρίς ολοκλήρωση του Daily Quest ->
## μηδενισμός. Καλείται στο _ready() (εκκίνηση παιχνιδιού) και σε κάθε
## get_streak() (σε περίπτωση που το παιχνίδι μείνει ανοιχτό πέρα από τα
## μεσάνυχτα).
func _check_streak_expiry() -> void:
	if streak == 0 or last_streak_date == "":
		return
	var today := _today_string()
	if last_streak_date == today:
		return
	if _days_between(last_streak_date, today) > 1:
		reset_streak()

## Πλήθος ημερολογιακών ημερών ανάμεσα σε δύο ημερομηνίες "YYYY-MM-DD".
func _days_between(date_a: String, date_b: String) -> int:
	var ts_a := Time.get_unix_time_from_datetime_string(date_a + "T00:00:00")
	var ts_b := Time.get_unix_time_from_datetime_string(date_b + "T00:00:00")
	return int(round((ts_b - ts_a) / 86400.0))


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — DAILY QUEST
# ═══════════════════════════════════════════════════════════════════════════

## True αν ο παίκτης έχει ήδη ΠΕΤΥΧΕΙ πλήρως το Daily Quest ΣΗΜΕΡΑ — μόνο
## τότε κλειδώνει (καμία προσπάθεια μέχρι αύριο). Μια αποτυχημένη απόπειρα
## δεν επηρεάζει αυτή την τιμή — ο παίκτης έχει απεριόριστες προσπάθειες να
## πετύχει μέχρι να καταφέρει την πρώτη πλήρη ολοκλήρωση της ημέρας.
func is_daily_quest_completed_today() -> bool:
	return daily_quest_completed_date == _today_string()

## Πόσα levels ολοκλήρωσε πλήρως ο παίκτης στη ΝΙΚΗΦΟΡΑ απόπειρα της ημέρας
## (πάντα 3, αφού μόνο η πλήρης επιτυχία καταγράφεται). 0 αν δεν έχει πετύχει
## ακόμα σήμερα — έλεγξε πρώτα με is_daily_quest_completed_today().
func get_daily_quest_levels_completed() -> int:
	return daily_quest_levels_completed if is_daily_quest_completed_today() else 0

## Καλείται ΜΙΑ φορά, στο ΤΕΛΟΣ κάθε απόπειρας Daily Quest — είτε ο παίκτης
## απέτυχε σε κάποιο level, είτε ολοκλήρωσε και τα 3 (levels_completed = 3).
##
## Ο παίκτης έχει ΑΠΕΡΙΟΡΙΣΤΕΣ προσπάθειες ΑΝΑ ΜΕΡΑ: μια αποτυχημένη απόπειρα
## (levels_completed < 3) δεν κάνει ΑΠΟΛΥΤΩΣ ΤΙΠΟΤΑ — δεν κλειδώνει τη μέρα,
## δεν αγγίζει το streak, ώστε ο παίκτης να μπορεί να ξαναδοκιμάσει αμέσως
## (βλ. daily_quest_exercises.gd: _restart_attempt()). Μόνο η ΠΡΩΤΗ πλήρης
## επιτυχία της ημέρας (levels_completed == 3) ανανεώνει το streak ΚΑΙ
## κλειδώνει περαιτέρω προσπάθειες μέχρι αύριο. Αν περάσει ολόκληρη μέρα
## χωρίς καμία επιτυχία, το streak μηδενίζεται από το _check_streak_expiry()
## στην επόμενη σύνδεση — όχι εδώ, ανά αποτυχία.
func record_daily_quest_result(levels_completed: int) -> void:
	if levels_completed < 3:
		return
	daily_quest_completed_date = _today_string()
	daily_quest_levels_completed = 3
	increment_streak() # επαναχρησιμοποίηση της ΗΔΗ υπάρχουσας streak λογικής — ΔΕΝ δημιουργείται νέα
	_save()
	progress_changed.emit()


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — WEAPON INVENTORY (persistence μόνο· λογική στο WeaponInventory)
# ═══════════════════════════════════════════════════════════════════════════

func get_weapon_state(weapon_name: String) -> Dictionary:
	return weapons.get(weapon_name, {})

func save_weapon_state(weapon_name: String, data: Dictionary) -> void:
	weapons[weapon_name] = data
	_save()


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — EQUIPPED LOADOUT (Inventory autoload, βλ. Scripts/inventory_data.gd)
# ═══════════════════════════════════════════════════════════════════════════
# Ζητήθηκε ρητά να επιβιώνει ποιο αντικείμενο είναι εξοπλισμένο σε κάθε slot
# μεταξύ εκτελέσεων, ΑΝΕΞΑΡΤΗΤΑ από το προσωρινό SAVE_ENABLED διακόπτη
# παραπάνω (streak/daily quest/κατοχή όπλων παραμένουν σκόπιμα εκτός save
# προς το παρόν). Γι' αυτό αυτές οι δύο συναρτήσεις διαβάζουν/γράφουν ΜΟΝΟ
# το δικό τους section ("equipment") απευθείας στο ίδιο ConfigFile, χωρίς να
# περνάνε από _load()/_save() και χωρίς να αγγίζουν κανένα άλλο section.

func get_equipped_loadout() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return {}
	return config.get_value("equipment", "equipped", {})

func save_equipped_loadout(equipped: Dictionary) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH) # αγνόησε σφάλμα — μπορεί να μην υπάρχει ακόμα το αρχείο
	config.set_value("equipment", "equipped", equipped)
	config.save(SAVE_PATH)


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — BOSS FIGHT (η λογική πιθανότητας/κόστους ζει στο boss_popup.gd)
# ═══════════════════════════════════════════════════════════════════════════

## True αν ο παίκτης έχει ΗΔΗ χάσει από τη Μόργκανα — τότε κάθε νέα προσπάθεια
## χρεώνεται Κέρματα (βλ. boss_popup.gd -> RETRY_COST). Η πρώτη προσπάθεια, και
## κάθε προσπάθεια μετά από νίκη, είναι δωρεάν.
func has_lost_to_boss() -> bool:
	return boss_lost_once

## True αν ο παίκτης έχει νικήσει ΕΣΤΩ ΜΙΑ φορά τη Μόργκανα (μόνιμο ορόσημο,
## βλ. boss_defeated). Το χρησιμοποιούν το «κεφάλαιο» προόδου και τα επιτεύγματα.
func has_defeated_boss() -> bool:
	return boss_defeated

## Καλείται σε ήττα — από εδώ και πέρα η επόμενη προσπάθεια χρεώνεται.
func record_boss_loss() -> void:
	boss_lost_once = true
	_save()

## Καλείται σε νίκη — μηδενίζει τη χρέωση επανάληψης ΚΑΙ σημειώνει μόνιμα ότι
## η Μόργκανα νικήθηκε (ορόσημο προόδου -> progress_changed).
func record_boss_win() -> void:
	boss_lost_once = false
	boss_defeated = true
	_save()
	progress_changed.emit()


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — MINI BOSSES (persistence μόνο· λογική στο mini_boss_popup.gd)
# ═══════════════════════════════════════════════════════════════════════════

func _mini_boss_state(boss_id: String) -> Dictionary:
	return mini_bosses.get(boss_id, {})

## True αν το mini boss έχει ΗΔΗ νικηθεί — τότε δεν ξαναπαίζεται καθόλου
## (το popup δείχνει «ΝΙΚΗΜΕΝΟ» αντί για odds/κουμπί επίθεσης).
func is_mini_boss_defeated(boss_id: String) -> bool:
	return bool(_mini_boss_state(boss_id).get("defeated", false))

## True αν ο παίκτης έχει ΗΔΗ χάσει από αυτό το mini boss — τότε κάθε νέα
## προσπάθεια χρεώνεται Κέρματα (βλ. mini_boss_popup.gd -> RETRY_COST). Η πρώτη
## προσπάθεια είναι δωρεάν.
func has_lost_to_mini_boss(boss_id: String) -> bool:
	return bool(_mini_boss_state(boss_id).get("lost_once", false))

## Καλείται σε ήττα — από εδώ και πέρα η επόμενη προσπάθεια χρεώνεται.
func record_mini_boss_loss(boss_id: String) -> void:
	var state := _mini_boss_state(boss_id).duplicate()
	state["lost_once"] = true
	mini_bosses[boss_id] = state
	_save()

## Καλείται σε νίκη — το boss κλειδώνει ΟΡΙΣΤΙΚΑ (καμία επανάληψη, καμία
## επιπλέον ανταμοιβή).
func record_mini_boss_win(boss_id: String) -> void:
	var state := _mini_boss_state(boss_id).duplicate()
	state["defeated"] = true
	mini_bosses[boss_id] = state
	_save()
	progress_changed.emit()


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — SIDE QUEST ΚΑΣΤΡΟΥ (persistence μόνο· λογική στο castle_popup.gd)
# ═══════════════════════════════════════════════════════════════════════════

## True αν ο παίκτης έχει ήδη φτάσει στο Main Bailey (έχει πάρει την ανταμοιβή
## ολοκλήρωσης) — τότε δεν ξαναδίνεται.
func is_castle_completed() -> bool:
	return castle_completed

## Καλείται ΜΙΑ φορά, την πρώτη φορά που ο παίκτης φτάνει στο Main Bailey.
func record_castle_completed() -> void:
	castle_completed = true
	_save()
	progress_changed.emit()


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — ΕΙΚΟΝΕΣ ΗΡΩΩΝ
# ═══════════════════════════════════════════════════════════════════════════

# Cache ώστε το ακριβό crop να γίνεται μία φορά ανά εικόνα.
var _cropped_tex_cache: Dictionary = {}

## Φορτώνει μια εικόνα και την κόβει στο πραγματικό (ορατό) περιεχόμενό της με
## κατώφλι alpha (>0.25). ΔΕΝ χρησιμοποιείται το Image.get_used_rect() γιατί
## μερικές εικόνες (π.χ. boy.png) έχουν αχνά, σχεδόν-διάφανα pixel στα άκρα που
## το ξεγελούν και επιστρέφει ολόκληρο τον καμβά — τότε ο χαρακτήρας μένει μια
## μικροσκοπική λωρίδα. Το αποτέλεσμα (AtlasTexture) αποθηκεύεται σε cache.
func get_cropped_texture(path: String) -> Texture2D:
	if _cropped_tex_cache.has(path):
		return _cropped_tex_cache[path]
	var result: Texture2D = null
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		if tex != null:
			result = _crop_to_content(tex)
	_cropped_tex_cache[path] = result
	return result

func _crop_to_content(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	if img == null:
		return tex
	var w := img.get_width()
	var h := img.get_height()
	var minx := w
	var miny := h
	var maxx := -1
	var maxy := -1
	var y := 0
	while y < h:
		var x := 0
		while x < w:
			if img.get_pixel(x, y).a > 0.25:
				if x < minx: minx = x
				if y < miny: miny = y
				if x > maxx: maxx = x
				if y > maxy: maxy = y
			x += 2
		y += 2
	if maxx < minx or maxy < miny:
		return tex
	minx = maxi(minx - 2, 0)
	miny = maxi(miny - 2, 0)
	maxx = mini(maxx + 2, w - 1)
	maxy = mini(maxy + 2, h - 1)
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(minx, miny, maxx - minx + 1, maxy - miny + 1)
	return atlas


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — ΝΟΜΙΣΜΑΤΑ (persistence μόνο· λογική στο Currency)
# ═══════════════════════════════════════════════════════════════════════════

func get_saved_currencies() -> Dictionary:
	return currencies

func save_currencies(amounts: Dictionary) -> void:
	currencies = amounts.duplicate()
	_save()


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — ΚΛΕΙΔΙΑ (persistence μόνο· λογική στο KeyInventory)
# ═══════════════════════════════════════════════════════════════════════════

func get_saved_keys() -> Dictionary:
	return keys

func save_keys(all_keys: Dictionary) -> void:
	keys = all_keys.duplicate(true)
	_save()


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — PARTY/ROSTER ΗΡΩΩΝ (persistence μόνο· λογική στο Heroes)
# ═══════════════════════════════════════════════════════════════════════════

func get_saved_party() -> Dictionary:
	return party

func save_party(data: Dictionary) -> void:
	party = data.duplicate(true)
	_save()


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — ΕΠΙΤΕΥΓΜΑΤΑ (persistence μόνο· λογική στο Achievements)
# ═══════════════════════════════════════════════════════════════════════════

func get_saved_achievements() -> Dictionary:
	return achievements

func save_achievements(data: Dictionary) -> void:
	achievements = data.duplicate(true)
	_save()


# ═══════════════════════════════════════════════════════════════════════════
# SAVE SYSTEM (ConfigFile — ίδιο μοτίβο με OptionsMenu.gd)
# ═══════════════════════════════════════════════════════════════════════════

func _today_string() -> String:
	return Time.get_date_string_from_system()

func _load() -> void:
	if not SAVE_ENABLED:
		return
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	streak                      = config.get_value("streak", "count", 0)
	last_streak_date            = config.get_value("streak", "last_date", "")
	daily_quest_completed_date  = config.get_value("daily_quest", "completed_date", "")
	daily_quest_levels_completed = config.get_value("daily_quest", "levels_completed", 0)
	weapons                     = config.get_value("weapons", "state", {})
	boss_lost_once              = config.get_value("boss", "lost_once", false)
	boss_defeated               = config.get_value("boss", "defeated", false)
	mini_bosses                 = config.get_value("mini_bosses", "state", {})
	currencies                  = config.get_value("currencies", "amounts", {})
	keys                        = config.get_value("keys", "state", {})
	party                       = config.get_value("party", "data", {})
	achievements                = config.get_value("achievements", "unlocked", {})
	castle_completed            = config.get_value("castle", "completed", false)

func _save() -> void:
	if not SAVE_ENABLED:
		return
	var config := ConfigFile.new()
	config.set_value("streak", "count", streak)
	config.set_value("streak", "last_date", last_streak_date)
	config.set_value("daily_quest", "completed_date", daily_quest_completed_date)
	config.set_value("daily_quest", "levels_completed", daily_quest_levels_completed)
	config.set_value("weapons", "state", weapons)
	config.set_value("boss", "lost_once", boss_lost_once)
	config.set_value("boss", "defeated", boss_defeated)
	config.set_value("mini_bosses", "state", mini_bosses)
	config.set_value("currencies", "amounts", currencies)
	config.set_value("keys", "state", keys)
	config.set_value("party", "data", party)
	config.set_value("achievements", "unlocked", achievements)
	config.set_value("castle", "completed", castle_completed)
	config.save(SAVE_PATH)
