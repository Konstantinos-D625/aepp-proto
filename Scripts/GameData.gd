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

# ΠΡΟΣΩΡΙΝΟ διακόπτης δοκιμών: όταν false, το _load()/_save() δεν αγγίζουν
# καθόλου το δίσκο — κάθε εκκίνηση ξεκινάει πάντα από τα αρχικά (daily quest
# ΚΑΙ όπλα, αφού όλα περνάνε από το ίδιο save file). Γύρνα το σε true για να
# ξαναενεργοποιηθεί η μόνιμη αποθήκευση. Το streak ΔΕΝ περνάει από αυτόν τον
# διακόπτη — βλ. _load_streak()/_save_streak() παρακάτω.
const SAVE_ENABLED := false

## Εκπέμπεται κάθε φορά που αλλάζει το streak (αύξηση, μηδενισμός λόγω
## αποτυχίας, ή μηδενισμός λόγω παράλειψης ημέρας). Οποιοδήποτε UI στοιχείο
## (π.χ. το εικονίδιο streak στο HUD) πρέπει να συνδέεται εδώ αντί να κάνει
## polling, ώστε να ενημερώνεται αυτόματα.
signal streak_changed(new_streak: int)

# ── Streak ────────────────────────────────────────────────────────────────
var streak: int = 0
var last_streak_date: String = ""              # "YYYY-MM-DD" — τελευταία μέρα που ανανεώθηκε το streak

# ── Daily Quest (3 levels: Σωστό/Λάθος -> Πολλαπλή -> Αντιστοίχιση) ────────
# Απεριόριστες προσπάθειες ΑΝΑ ΜΕΡΑ — μια αποτυχία δεν κλειδώνει τίποτα, ο
# παίκτης μπορεί να ξαναπροσπαθήσει αμέσως. Μόλις όμως πετύχει ΠΛΗΡΗ
# ολοκλήρωση (και των 3 levels) ΜΙΑ φορά μέσα στη μέρα, κλειδώνει: καμία
# άλλη προσπάθεια μέχρι αύριο (βλ. record_daily_quest_result). Γι' αυτό τα 2
# πεδία παρακάτω ενημερώνονται ΜΟΝΟ σε επιτυχία — μια αποτυχημένη απόπειρα
# δεν αφήνει κανένα ίχνος, καμία ανάγκη να επιβιώνει ενδιάμεση πρόοδο
# (level/ερώτηση) μετά από επανεκκίνηση, ίδια λογική με το πώς τα quiz του
# Cotton/Miner/Blacksmith δεν κρατάνε ενδιάμεση πρόοδο ανάμεσα σε επισκέψεις.
var daily_quest_completed_date: String = ""     # "YYYY-MM-DD" — πότε ΠΕΤΥΧΕ πλήρως ο παίκτης (άδειο αν όχι ακόμα σήμερα)
var daily_quest_levels_completed: int = 0       # πάντα 3 όταν daily_quest_completed_date == σήμερα (αλλιώς άσχετο)

# ── Weapon inventory (WeaponInventory autoload) ──────────────────────────
# item_id -> {"owned": bool, "tier": int}. Το GameData είναι ΜΟΝΟ ο
# persistence layer εδώ· η λογική (κατάλογος όπλων, τιμές, κανόνες) ζει στο
# Scripts/weapon_inventory.gd, ακολουθώντας τον κανόνα παραπάνω ότι κάθε νέο
# save-data προστίθεται ΕΔΩ και όχι σε ξεχωριστό save system.
var weapons: Dictionary = {}

# ── Μόνιμο stat bonus (FairyPopup, μελλοντικά ίσως κι άλλες πηγές) ──────────
# stat_name -> μόνιμο bonus, ΕΚΤΟΣ εξοπλισμού (βλ. Inventory.get_equipped_
# stat_bonus για το bonus εξοπλισμού — τα δύο αθροίζονται στο
# CharacterEditPopup._refresh_stats). Η μοναδική πηγή προς το παρόν είναι η
# Νεράιδα (Scripts/fairy_popup.gd): 1 Μαγική Σφαίρα -> +1 στο αντίστοιχο stat.
var stat_bonus: Dictionary = {}

# ── Boss fight «loss gate» (boss_popup.gd) ──────────────────────────────────
# stat_name -> τιμή του stat ΤΗ ΣΤΙΓΜΗ της τελευταίας ήττας. Άδειο Dictionary
# = καμία καταγεγραμμένη ήττα, ελεύθερη προσπάθεια. Μετά από ήττα, ΚΑΘΕ ένα
# από τα 5 stats πρέπει να ανέβει τουλάχιστον +1 πάνω από αυτή την τιμή πριν
# επιτραπεί ξανά προσπάθεια — βλ. can_attempt_boss().
var boss_loss_stats: Dictionary = {}


func _ready() -> void:
	_load()
	_load_streak()
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
	_save_streak()
	streak_changed.emit(streak)

## Μηδενίζει το streak αμέσως — καλείται είτε σε αποτυχία του Daily Quest
## (λάθος απάντηση), είτε όταν διαπιστωθεί ότι πέρασε μια ολόκληρη μέρα χωρίς
## να ολοκληρωθεί (βλ. _check_streak_expiry). Ίδιο μοτίβο με το
## increment_streak() — η ΜΟΝΑΔΙΚΗ συνάρτηση μηδενισμού streak στο project.
func reset_streak() -> void:
	if streak == 0 and last_streak_date == "":
		return # ήδη μηδενισμένο — απόφυγή περιττού save/signal
	streak = 0
	last_streak_date = ""
	_save_streak()
	streak_changed.emit(streak)

## Τρέχουσα τιμή streak, μετά από έλεγχο μήπως πέρασε μέρα χωρίς ολοκλήρωση
## (βλ. _check_streak_expiry). Το UI (π.χ. το εικονίδιο streak στο HUD)
## πρέπει να διαβάζει το streak ΜΕΣΩ αυτής της συνάρτησης, όχι απευθείας το
## πεδίο streak, ώστε να «πιάνει» έγκαιρα τυχόν μηδενισμό λόγω παράλειψης.
func get_streak() -> int:
	_check_streak_expiry()
	return streak

## Αν η τελευταία ανανέωση streak δεν ήταν ούτε σήμερα ούτε χθες, σημαίνει
## ότι πέρασε τουλάχιστον μία ολόκληρη ημέρα χωρίς ολοκλήρωση του Daily
## Quest -> μηδενισμός. Καλείται στο _ready() (εκκίνηση παιχνιδιού) και σε
## κάθε get_streak() (σε περίπτωση που το παιχνίδι μείνει ανοιχτό πέρα από
## τα μεσάνυχτα).
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
## (πάντα 3, αφού μόνο η πλήρης επιτυχία καταγράφεται). 0 αν δεν έχει
## πετύχει ακόμα σήμερα — έλεγξε πρώτα με is_daily_quest_completed_today().
func get_daily_quest_levels_completed() -> int:
	return daily_quest_levels_completed if is_daily_quest_completed_today() else 0

## Καλείται ΜΙΑ φορά, στο ΤΕΛΟΣ κάθε απόπειρας Daily Quest — είτε ο παίκτης
## απέτυχε σε κάποιο level, είτε ολοκλήρωσε και τα 3 (levels_completed = 3).
## Το reward logic (Currency.add κ.λπ.) ζει στο daily_quest_exercises.gd —
## εδώ καταγράφεται μόνο η κατάσταση + το streak.
##
## Ο παίκτης έχει ΑΠΕΡΙΟΡΙΣΤΕΣ προσπάθειες ΑΝΑ ΜΕΡΑ: μια αποτυχημένη
## απόπειρα (levels_completed < 3) δεν κάνει ΑΠΟΛΥΤΩΣ ΤΙΠΟΤΑ — δεν κλειδώνει
## τη μέρα, δεν αγγίζει το streak, ώστε ο παίκτης να μπορεί να ξαναδοκιμάσει
## αμέσως. Μόνο η ΠΡΩΤΗ πλήρης επιτυχία της ημέρας (levels_completed == 3)
## ανανεώνει το streak ΚΑΙ κλειδώνει περαιτέρω προσπάθειες μέχρι αύριο. Αν
## περάσει ολόκληρη μέρα χωρίς καμία επιτυχία, το streak μηδενίζεται από το
## _check_streak_expiry() στην επόμενη σύνδεση — όχι εδώ, ανά αποτυχία.
func record_daily_quest_result(levels_completed: int) -> void:
	if levels_completed < 3:
		return
	daily_quest_completed_date = _today_string()
	daily_quest_levels_completed = 3
	increment_streak() # επαναχρησιμοποίηση της ΗΔΗ υπάρχουσας streak λογικής — ΔΕΝ δημιουργείται νέα
	_save()


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
# παραπάνω (daily quest/κατοχή όπλων παραμένουν σκόπιμα εκτός save προς το
# παρόν — το streak έχει το δικό του ανάλογο bypass, βλ. _load_streak()/
# _save_streak() στο τέλος του αρχείου). Γι' αυτό αυτές οι δύο συναρτήσεις
# διαβάζουν/γράφουν ΜΟΝΟ
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
# ΔΗΜΟΣΙΟ API — ΜΟΝΙΜΟ STAT BONUS (π.χ. ανταλλαγές στη Νεράιδα)
# ═══════════════════════════════════════════════════════════════════════════

func get_stat_bonus(stat_name: String) -> int:
	return int(stat_bonus.get(stat_name, 0))

func add_stat_bonus(stat_name: String, amount: int) -> void:
	stat_bonus[stat_name] = get_stat_bonus(stat_name) + amount
	_save()


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — BOSS FIGHT LOSS GATE (λογική πιθανότητας ζει στο boss_popup.gd)
# ═══════════════════════════════════════════════════════════════════════════

const MAX_STAT := 20   # ίδιο ανώτατο όριο με το clamp του CharacterEditPopup

## True αν επιτρέπεται προσπάθεια ΤΩΡΑ: είτε καμία προηγούμενη ήττα, είτε
## ΚΑΘΕ ένα από τα current_stats είναι τουλάχιστον +1 πάνω από την τιμή που
## είχε τη στιγμή της τελευταίας ήττας (πρέπει να έχεις κάνει grind σε ΟΛΑ,
## όχι μόνο σε ένα) — ΕΚΤΟΣ αν το stat ήταν ήδη στο MAX_STAT τη στιγμή της
## ήττας, οπότε δεν μπορεί να ανέβει άλλο· τότε αρκεί να ΠΑΡΑΜΕΙΝΕΙ στο
## ανώτατο, όχι να το ξεπεράσει (αλλιώς θα ήταν μόνιμο, αδιάβατο κλείδωμα).
func can_attempt_boss(current_stats: Dictionary) -> bool:
	if boss_loss_stats.is_empty():
		return true
	for stat_name in boss_loss_stats:
		var required: int = mini(int(boss_loss_stats[stat_name]) + 1, MAX_STAT)
		if int(current_stats.get(stat_name, 0)) < required:
			return false
	return true

## Καλείται σε ήττα — αποθηκεύει τα stats ΤΗ ΣΤΙΓΜΗ της ήττας ως το νέο
## "κατώφλι" που πρέπει να ξεπεραστεί (βλ. can_attempt_boss).
func record_boss_loss(current_stats: Dictionary) -> void:
	boss_loss_stats = current_stats.duplicate()
	_save()

## Καλείται σε νίκη — καθαρίζει το gate (ελεύθερη προσπάθεια στο μέλλον, π.χ.
## αν ξαναπροσπαθήσει αργότερα για οποιονδήποτε λόγο).
func record_boss_win() -> void:
	boss_loss_stats = {}
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
	daily_quest_completed_date  = config.get_value("daily_quest", "completed_date", "")
	daily_quest_levels_completed = config.get_value("daily_quest", "levels_completed", 0)
	weapons                     = config.get_value("weapons", "state", {})
	stat_bonus                  = config.get_value("stats", "bonus", {})
	boss_loss_stats             = config.get_value("boss", "loss_stats", {})

func _save() -> void:
	if not SAVE_ENABLED:
		return
	var config := ConfigFile.new()
	config.set_value("daily_quest", "completed_date", daily_quest_completed_date)
	config.set_value("daily_quest", "levels_completed", daily_quest_levels_completed)
	config.set_value("weapons", "state", weapons)
	config.set_value("stats", "bonus", stat_bonus)
	config.set_value("boss", "loss_stats", boss_loss_stats)
	config.save(SAVE_PATH)

# ── Streak persistence (πάντα ενεργή, ΑΝΕΞΑΡΤΗΤΑ από SAVE_ENABLED) ─────────
# Ζητήθηκε ρητά να επιβιώνει το streak μεταξύ εκτελέσεων, ίδιο μοτίβο με το
# get_equipped_loadout()/save_equipped_loadout() παραπάνω: διαβάζει/γράφει
# ΜΟΝΟ το δικό του section ("streak") απευθείας στο ConfigFile, χωρίς να
# περνάει από _load()/_save() και χωρίς να αγγίζει daily_quest/weapons/κλπ.
func _load_streak() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	streak           = config.get_value("streak", "count", 0)
	last_streak_date = config.get_value("streak", "last_date", "")

func _save_streak() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH) # αγνόησε σφάλμα — μπορεί να μην υπάρχει ακόμα το αρχείο
	config.set_value("streak", "count", streak)
	config.set_value("streak", "last_date", last_streak_date)
	config.save(SAVE_PATH)
