class_name QuizManager
extends RefCounted

## Γενικό, επαναχρησιμοποιήσιμο σύστημα ασκήσεων (quiz).
##
## Φορτώνει ερωτήσεις από αρχείο JSON, κρατά την τρέχουσα ερώτηση,
## ελέγχει τις απαντήσεις, περνά στην επόμενη και ειδοποιεί το UI
## μέσω σημάτων. ΔΕΝ γνωρίζει τίποτα για το UI — έτσι μπορεί να
## χρησιμοποιηθεί από οποιοδήποτε popup / NPC / σπίτι, απλώς
## δίνοντας διαφορετικό JSON, χωρίς αλλαγές στον βασικό κώδικα.
##
## Μορφή JSON:
##   [ { "question": "...", "answer": "..." }, ... ]

signal question_changed(index: int, total: int, question_text: String)
signal answer_result(correct: bool)
signal quiz_completed(correct_first_try: int, total: int)

var _pool: Array = []          # όλες οι φορτωμένες ερωτήσεις
var _questions: Array = []     # οι ερωτήσεις του τρέχοντος γύρου
var _index: int = 0
var _correct_first_try: int = 0
var _attempts_on_current: int = 0
var _earned_difficulty: int = 0   # άθροισμα δυσκολίας των σωστών απαντήσεων

## Φορτώνει τις ερωτήσεις από αρχείο JSON. Επιστρέφει true σε επιτυχία.
func load_from_file(path: String) -> bool:
	_pool.clear()
	if not FileAccess.file_exists(path):
		push_error("QuizManager: δεν βρέθηκε το αρχείο ασκήσεων: " + path)
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("QuizManager: αδυναμία ανοίγματος: " + path)
		return false
	var txt := f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_ARRAY:
		push_error("QuizManager: μη έγκυρο JSON (αναμένεται λίστα ερωτήσεων).")
		return false
	for item in data:
		if typeof(item) == TYPE_DICTIONARY and item.has("question") and item.has("answer"):
			var diff := 1
			if item.has("difficulty"):
				diff = clampi(int(item["difficulty"]), 1, 3)
			_pool.append({
				"question": str(item["question"]),
				"answer": str(item["answer"]),
				"difficulty": diff,
			})
	return not _pool.is_empty()

## Ξεκινά έναν νέο γύρο.
##  - shuffle: αν true, ανακατεύει τις ερωτήσεις (διαφορετική σειρά κάθε φορά)
##  - count:   αν > 0, κρατά μόνο τόσες ερωτήσεις (διαφορετικό υποσύνολο κάθε φορά)
func start(shuffle: bool = false, count: int = 0) -> void:
	_questions = _pool.duplicate()
	if shuffle:
		_questions.shuffle()
	if count > 0 and count < _questions.size():
		_questions = _questions.slice(0, count)
	_index = 0
	_correct_first_try = 0
	_attempts_on_current = 0
	_earned_difficulty = 0
	if _questions.is_empty():
		quiz_completed.emit(0, 0)
		return
	_emit_current()

func get_total() -> int:
	return _questions.size()

func get_current_index() -> int:
	return _index

func get_score() -> int:
	return _correct_first_try

## Άθροισμα δυσκολίας (1-3 ανά ερώτηση) όλων των σωστών απαντήσεων.
func get_earned_difficulty() -> int:
	return _earned_difficulty

## Δυσκολία (1-3) της τρέχουσας ερώτησης.
func get_current_difficulty() -> int:
	if _index < 0 or _index >= _questions.size():
		return 1
	return int(_questions[_index].get("difficulty", 1))

## Υποβολή απάντησης για την τρέχουσα ερώτηση.
## Επιστρέφει true αν είναι σωστή και εκπέμπει answer_result.
## ΔΕΝ προχωρά μόνο του — το scene καλεί advance() όποτε θέλει
## (π.χ. μετά από ~1 δευτερόλεπτο για να προλάβει να διαβαστεί το "Σωστό!").
func submit_answer(text: String) -> bool:
	if _index < 0 or _index >= _questions.size():
		return false
	var correct := _normalize(text) == _normalize(str(_questions[_index]["answer"]))
	if correct:
		if _attempts_on_current == 0:
			_correct_first_try += 1
			_earned_difficulty += int(_questions[_index].get("difficulty", 1))
	else:
		_attempts_on_current += 1
	answer_result.emit(correct)
	return correct

## Προχωρά στην επόμενη ερώτηση, ή ολοκληρώνει το quiz αν δεν υπάρχει άλλη.
func advance() -> void:
	_index += 1
	_attempts_on_current = 0
	if _index >= _questions.size():
		quiz_completed.emit(_correct_first_try, get_total())
	else:
		_emit_current()

func _emit_current() -> void:
	question_changed.emit(_index, get_total(), str(_questions[_index]["question"]))

## Κανονικοποίηση σύγκρισης:
##  - αγνοεί κενά στην αρχή/τέλος
##  - αγνοεί κεφαλαία / πεζά
##  - (για ευκολία στα ελληνικά) αγνοεί τόνους και τελικό σίγμα
func _normalize(s: String) -> String:
	var t := s.strip_edges().to_lower()
	t = t.replace("ς", "σ")
	const ACCENTED := "άέήίϊΐόύϋΰώ"
	const PLAIN := "αεηιιιουυυω"
	var out := ""
	for ch in t:
		var idx := ACCENTED.find(ch)
		if idx != -1:
			out += PLAIN[idx]
		else:
			out += ch
	return out
