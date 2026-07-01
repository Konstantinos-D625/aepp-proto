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
#   - Οποιαδήποτε πραγματική άσκηση (όταν προστεθεί) πρέπει να καλεί
#     record_daily_quest_correct_answer() στη σωστή απάντηση και να ΜΗΝ
#     καλεί τίποτα στη λάθος απάντηση.
#   - Οποιοδήποτε νέο save-data πρέπει να προστίθεται ΕΔΩ, όχι σε νέο
#     ξεχωριστό save system.
# ═══════════════════════════════════════════════════════════════════════════

const SAVE_PATH := "user://game_data.cfg"
const DAILY_QUEST_REQUIRED_CORRECT := 3

# ── Streak ────────────────────────────────────────────────────────────────
var streak: int = 0
var last_streak_date: String = ""              # "YYYY-MM-DD"

# ── Daily Quest ───────────────────────────────────────────────────────────
var daily_quest_correct_count: int = 0
var daily_quest_completed: bool = false
var daily_quest_completed_date: String = ""     # "YYYY-MM-DD"
var daily_quest_session_date: String = ""       # "YYYY-MM-DD" — πότε ξεκίνησε η τρέχουσα μέτρηση


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

## True αν το Daily Quest έχει ήδη ολοκληρωθεί ΣΗΜΕΡΑ (η ολοκλήρωση μιας
## προηγούμενης ημέρας δεν "μετράει" ξανά).
func is_daily_quest_completed_today() -> bool:
	return daily_quest_completed and daily_quest_completed_date == _today_string()

## Καλείται όταν ο παίκτης μπαίνει στην οθόνη ασκήσεων (μετά το "ΠΑΜΕ").
## Ξεκινάει (ή συνεχίζει, αν ο παίκτης έχει ήδη μερικές σωστές σήμερα)
## την παρακολούθηση σωστών απαντήσεων για ΣΗΜΕΡΑ.
func begin_daily_quest_session() -> void:
	if is_daily_quest_completed_today():
		return
	var today := _today_string()
	if daily_quest_session_date != today:
		# Νέα ημέρα -> μηδενισμός μετρητή (η μέτρηση αφορά μόνο τη σημερινή απόπειρα)
		daily_quest_correct_count = 0
		daily_quest_session_date = today
		_save()

## Καλείται ΜΟΝΟ για ΣΩΣΤΗ απάντηση μέσα στο Daily Quest.
## Οι λανθασμένες απαντήσεις αγνοούνται — δεν πρέπει καν να καλούν αυτή
## τη συνάρτηση.
func record_daily_quest_correct_answer() -> void:
	if is_daily_quest_completed_today():
		return
	daily_quest_correct_count += 1
	if daily_quest_correct_count >= DAILY_QUEST_REQUIRED_CORRECT:
		_complete_daily_quest()
	else:
		_save()

func _complete_daily_quest() -> void:
	daily_quest_completed = true
	daily_quest_completed_date = _today_string()
	increment_streak() # επαναχρησιμοποίηση της ΗΔΗ υπάρχουσας streak λογικής — ΔΕΝ δημιουργείται νέα
	_save()


# ═══════════════════════════════════════════════════════════════════════════
# SAVE SYSTEM (ConfigFile — ίδιο μοτίβο με OptionsMenu.gd)
# ═══════════════════════════════════════════════════════════════════════════

func _today_string() -> String:
	return Time.get_date_string_from_system()

func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	streak                      = config.get_value("streak", "count", 0)
	last_streak_date            = config.get_value("streak", "last_date", "")
	daily_quest_correct_count   = config.get_value("daily_quest", "correct_count", 0)
	daily_quest_completed       = config.get_value("daily_quest", "completed", false)
	daily_quest_completed_date  = config.get_value("daily_quest", "completed_date", "")
	daily_quest_session_date    = config.get_value("daily_quest", "session_date", "")

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("streak", "count", streak)
	config.set_value("streak", "last_date", last_streak_date)
	config.set_value("daily_quest", "correct_count", daily_quest_correct_count)
	config.set_value("daily_quest", "completed", daily_quest_completed)
	config.set_value("daily_quest", "completed_date", daily_quest_completed_date)
	config.set_value("daily_quest", "session_date", daily_quest_session_date)
	config.save(SAVE_PATH)
