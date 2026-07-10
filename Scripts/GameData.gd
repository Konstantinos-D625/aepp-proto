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
# καθόλου το δίσκο — κάθε εκκίνηση ξεκινάει πάντα από τα αρχικά (streak,
# daily quest, ΚΑΙ όπλα, αφού όλα περνάνε από το ίδιο save file). Γύρνα το σε
# true για να ξαναενεργοποιηθεί η μόνιμη αποθήκευση.
const SAVE_ENABLED := false

# ── Streak ────────────────────────────────────────────────────────────────
var streak: int = 0
var last_streak_date: String = ""              # "YYYY-MM-DD"

# ── Daily Quest (3 levels: Σωστό/Λάθος -> Πολλαπλή -> Αντιστοίχιση) ────────
# Μία απόπειρα/μέρα, καμία 2η ευκαιρία — πρώτο λάθος = χάνεις το quest ΓΙΑ ΤΗ
# ΜΕΡΑ. Γι' αυτό αρκούν 2 μόνο πεδία: ΠΟΤΕ έγινε η τελευταία απόπειρα (gate
# για "1 φορά/μέρα") και ΠΟΣΑ levels ολοκλήρωσε πλήρως πριν σταματήσει —
# καμία ανάγκη να επιβιώνει ενδιάμεση πρόοδο (level/ερώτηση) μετά από
# επανεκκίνηση, ίδια λογική με το πώς τα quiz του Cotton/Miner/Blacksmith
# δεν κρατάνε ενδιάμεση πρόοδο ανάμεσα σε επισκέψεις.
var daily_quest_completed_date: String = ""     # "YYYY-MM-DD" — πότε παίχτηκε ΣΗΜΕΡΑ (πέτυχε Ή απέτυχε)
var daily_quest_levels_completed: int = 0       # 0-3, μόνο για τη μέρα του daily_quest_completed_date

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


# ═══════════════════════════════════════════════════════════════════════════
# ΔΗΜΟΣΙΟ API — DAILY QUEST
# ═══════════════════════════════════════════════════════════════════════════

## True αν έχει ήδη γίνει απόπειρα Daily Quest ΣΗΜΕΡΑ (πέτυχε Ή απέτυχε —
## και στις δύο περιπτώσεις δεν ξαναπαίζεται μέχρι αύριο).
func is_daily_quest_completed_today() -> bool:
	return daily_quest_completed_date == _today_string()

## Πόσα levels ολοκλήρωσε πλήρως ο παίκτης στη σημερινή απόπειρα (0-3).
## Άσχετο/παλιό (0) αν δεν έχει παίξει καθόλου σήμερα — έλεγξε πρώτα με
## is_daily_quest_completed_today().
func get_daily_quest_levels_completed() -> int:
	return daily_quest_levels_completed if is_daily_quest_completed_today() else 0

## Καλείται ΜΙΑ φορά, στο ΤΕΛΟΣ της σημερινής απόπειρας Daily Quest — είτε
## ο παίκτης απέτυχε σε κάποιο level (levels_completed = πόσα ολοκλήρωσε
## ΠΡΙΝ αποτύχει), είτε ολοκλήρωσε και τα 3 (levels_completed = 3). Το
## reward logic (Currency.add κ.λπ.) ζει στο daily_quest_exercises.gd — εδώ
## καταγράφεται μόνο η κατάσταση + το streak.
## Το streak ανανεώνεται ΜΟΝΟ σε πλήρη επιτυχία (levels_completed == 3),
## όχι σε μερική ολοκλήρωση.
func record_daily_quest_result(levels_completed: int) -> void:
	daily_quest_completed_date = _today_string()
	daily_quest_levels_completed = clampi(levels_completed, 0, 3)
	if daily_quest_levels_completed >= 3:
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
	streak                      = config.get_value("streak", "count", 0)
	last_streak_date            = config.get_value("streak", "last_date", "")
	daily_quest_completed_date  = config.get_value("daily_quest", "completed_date", "")
	daily_quest_levels_completed = config.get_value("daily_quest", "levels_completed", 0)
	weapons                     = config.get_value("weapons", "state", {})
	stat_bonus                  = config.get_value("stats", "bonus", {})
	boss_loss_stats             = config.get_value("boss", "loss_stats", {})

func _save() -> void:
	if not SAVE_ENABLED:
		return
	var config := ConfigFile.new()
	config.set_value("streak", "count", streak)
	config.set_value("streak", "last_date", last_streak_date)
	config.set_value("daily_quest", "completed_date", daily_quest_completed_date)
	config.set_value("daily_quest", "levels_completed", daily_quest_levels_completed)
	config.set_value("weapons", "state", weapons)
	config.set_value("stats", "bonus", stat_bonus)
	config.set_value("boss", "loss_stats", boss_loss_stats)
	config.save(SAVE_PATH)
