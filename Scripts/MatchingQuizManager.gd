class_name MatchingQuizManager
extends RefCounted

## Γενικό, επαναχρησιμοποιήσιμο σύστημα ασκήσεων αντιστοίχισης (matching).
## Ίδιο πνεύμα με το QuizManager (res://Scripts/QuizManager.gd): φορτώνει
## από JSON, δεν γνωρίζει τίποτα για το UI, ειδοποιεί μέσω σημάτων. Μια
## "συνεδρία" (session) αποτελείται από πολλούς γύρους (rounds) — κάθε
## γύρος είναι μία άσκηση αντιστοίχισης 5 ζευγαριών, ίδια λογική με το πώς
## το QuizManager τραβάει ένα τυχαίο υποσύνολο ερωτήσεων ανά επίσκεψη.
##
## Μορφή JSON:
##   [ { "left": [Ν στοιχεία], "right": [Ν στοιχεία], "difficulty": 1-3 }, ... ]
## Το right[i] είναι η ΣΩΣΤΗ αντιστοίχιση του left[i] (ίδιος δείκτης στο
## αρχείο). Ο manager ανακατεύει τη δεξιά στήλη πριν την εμφανίσει.
##
## Ο αριθμός ζευγαριών ΑΝΑ ΓΥΡΟ (pair_count σε start_session, βλ. παρακάτω)
## είναι ρυθμιζόμενος, όχι σταθερός στα 5 — κάθε entry του pool μπορεί να
## έχει ΠΕΡΙΣΣΟΤΕΡΑ στοιχεία απ' όσα χρειάζεται ένας γύρος (π.χ. Daily Quest
## ζητάει pair_count=3 από το ΙΔΙΟ miner_quiz.json που έχει entries των 5),
## οπότε επιλέγεται τυχαίο υποσύνολο pair_count ζευγαριών ανά γύρο,
## διατηρώντας τη σχετική τους σειρά. Ο Miner (pair_count=5, όσα ακριβώς
## έχουν τα δικά του entries) συνεχίζει να δουλεύει ΑΚΡΙΒΩΣ όπως πριν.

signal round_ready(round_index: int, total_rounds: int, left: Array, right_shuffled: Array)
signal round_completed(round_index: int, total_rounds: int, correct_count: int, pair_total: int, earned_difficulty: int, correct_flags: Array)
signal session_completed(total_correct: int, total_pairs: int, total_earned_difficulty: int)

const LETTERS := ["α", "β", "γ", "δ", "ε"]

var _pool: Array = []
var _rounds: Array = []           # επιλεγμένες ασκήσεις για αυτή τη συνεδρία
var _round_index := -1
var _pair_count := 5              # ζευγάρια ανά γύρο για ΑΥΤΗ τη συνεδρία (βλ. start_session)

# ── Κατάσταση τρέχοντος γύρου ───────────────────────────────────────────────
var _left: Array = []
var _right_shuffled: Array = []
var _correct_letter_for_left: Array = []
var _chosen_letter_for_left: Array = []
var _difficulty := 1

# ── Σύνολα συνεδρίας ─────────────────────────────────────────────────────────
var _total_correct := 0
var _total_pairs := 0
var _total_earned := 0

func load_from_file(path: String) -> bool:
	_pool.clear()
	if not FileAccess.file_exists(path):
		push_error("MatchingQuizManager: δεν βρέθηκε το αρχείο ασκήσεων: " + path)
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("MatchingQuizManager: αδυναμία ανοίγματος: " + path)
		return false
	var txt := f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_ARRAY:
		push_error("MatchingQuizManager: μη έγκυρο JSON (αναμένεται λίστα ασκήσεων).")
		return false
	for item in data:
		if typeof(item) != TYPE_DICTIONARY or not item.has("left") or not item.has("right"):
			continue
		var left: Array = item["left"]
		var right: Array = item["right"]
		if left.size() != right.size() or left.is_empty():
			continue
		var diff := 1
		if item.has("difficulty"):
			diff = clampi(int(item["difficulty"]), 1, 3)
		_pool.append({ "left": left, "right": right, "difficulty": diff })
	return not _pool.is_empty()

## Ξεκινά μια νέα συνεδρία: διαλέγει τυχαία `rounds_count` διαφορετικές
## ασκήσεις από το pool (λιγότερες αν το pool είναι μικρότερο) και ξεκινά
## τον πρώτο γύρο (εκπέμπει round_ready).
## `pair_count`: πόσα ζευγάρια θα δείχνει ΚΑΘΕ γύρος (βλ. σχόλιο στην
## κορυφή του αρχείου) — μόνο entries με ΤΟΥΛΑΧΙΣΤΟΝ τόσα στοιχεία μπαίνουν
## στη συνεδρία.
func start_session(rounds_count: int = 3, pair_count: int = 5) -> void:
	_pair_count = max(1, pair_count)
	_rounds = _pool.filter(func(e): return (e["left"] as Array).size() >= _pair_count)
	_rounds.shuffle()
	if rounds_count > 0 and rounds_count < _rounds.size():
		_rounds = _rounds.slice(0, rounds_count)
	_round_index = -1
	_total_correct = 0
	_total_pairs = 0
	_total_earned = 0
	_advance_round()

func get_left() -> Array:
	return _left

func get_right_shuffled() -> Array:
	return _right_shuffled

func get_total_correct() -> int:
	return _total_correct

func get_total_pairs() -> int:
	return _total_pairs

func get_total_earned() -> int:
	return _total_earned

## Καταγράφει την επιλογή γράμματος για το αριστερό στοιχείο left_index
## (0-based) του ΤΡΕΧΟΝΤΟΣ γύρου — μπορεί να κληθεί με οποιαδήποτε σειρά
## (π.χ. σε drag & drop UI). Όταν όλα τα στοιχεία έχουν καταγεγραμμένη
## επιλογή, εκπέμπει round_completed.
func choose(left_index: int, letter: String) -> void:
	if left_index < 0 or left_index >= _chosen_letter_for_left.size():
		return
	_chosen_letter_for_left[left_index] = letter
	if not _chosen_letter_for_left.has(""):
		_finish_round()

## Ακυρώνει την επιλογή του left_index (γίνεται πάλι "χωρίς απάντηση").
## Χρησιμοποιείται όταν το UI επιτρέπει επανατοποθέτηση (π.χ. drag & drop
## πάνω σε ήδη κατειλημμένο στόχο) — πρέπει να καλείται ΠΡΙΝ ξαναδοθεί το
## left_index σε νέο choose(), ώστε το round_completed να μην πυροδοτηθεί
## πρόωρα με ένα "ορφανό" προηγούμενο ζευγάρι.
func clear(left_index: int) -> void:
	if left_index < 0 or left_index >= _chosen_letter_for_left.size():
		return
	_chosen_letter_for_left[left_index] = ""

## Προχωρά στον επόμενο γύρο, ή ολοκληρώνει τη συνεδρία (session_completed)
## αν δεν υπάρχει άλλος. Καλείται από το UI αφού δείξει το αποτέλεσμα του
## τρέχοντος γύρου (ίδιο μοτίβο με το QuizManager.advance()).
func advance() -> void:
	_advance_round()

func _advance_round() -> void:
	_round_index += 1
	if _round_index >= _rounds.size():
		session_completed.emit(_total_correct, _total_pairs, _total_earned)
		return

	var entry: Dictionary = _rounds[_round_index]
	var full_left: Array = entry["left"]
	var full_right: Array = entry["right"]
	_difficulty = int(entry["difficulty"])

	# Αν το entry έχει ΠΕΡΙΣΣΟΤΕΡΑ ζευγάρια απ' όσα χρειάζεται ο γύρος
	# (_pair_count), διάλεξε τυχαίο υποσύνολο — κρατώντας τη ΣΧΕΤΙΚΗ σειρά
	# τους (γι' αυτό το sort() μετά το shuffle) ώστε η αριστερή στήλη να μη
	# δείχνει τυχαία ανακατεμένη σε σχέση με το πρωτότυπο αρχείο. Αν το
	# entry έχει ΑΚΡΙΒΩΣ _pair_count στοιχεία (π.χ. ο Miner, πάντα 5=5),
	# το υποσύνολο είναι όλα τα στοιχεία, ίδια σειρά — καμία αλλαγή
	# συμπεριφοράς σε σχέση με πριν.
	var indices: Array = range(full_left.size())
	if _pair_count < indices.size():
		indices.shuffle()
		indices = indices.slice(0, _pair_count)
		indices.sort()

	_left = []
	var right_correct: Array = []   # right_correct[i] = σωστό ταίρι του _left[i]
	for i in indices:
		_left.append(full_left[i])
		right_correct.append(full_right[i])

	var order: Array = range(right_correct.size())
	order.shuffle()

	_right_shuffled = []
	_correct_letter_for_left = []
	_chosen_letter_for_left = []
	for _i in _left.size():
		_correct_letter_for_left.append("")
		_chosen_letter_for_left.append("")

	for shuffled_pos in order.size():
		var original_index: int = order[shuffled_pos]
		_right_shuffled.append(right_correct[original_index])
		_correct_letter_for_left[original_index] = LETTERS[shuffled_pos]

	round_ready.emit(_round_index, _rounds.size(), _left, _right_shuffled)

func _finish_round() -> void:
	var correct_count := 0
	var flags: Array = []
	for i in _left.size():
		var ok: bool = _chosen_letter_for_left[i] == _correct_letter_for_left[i]
		flags.append(ok)
		if ok:
			correct_count += 1
	var earned := correct_count * _difficulty
	_total_correct += correct_count
	_total_pairs += _left.size()
	_total_earned += earned
	round_completed.emit(_round_index, _rounds.size(), correct_count, _left.size(), earned, flags)
