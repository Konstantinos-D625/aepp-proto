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
## Μορφή JSON — μία απάντηση (παλιά μορφή, εξακολουθεί να δουλεύει):
##   [ { "question": "...", "answer": "...", "difficulty": 1 }, ... ]
##
## Μορφή JSON — πολλές αποδεκτές γραφές + κανόνες ελέγχου:
##   [ {
##       "question": "...",
##       "answers": ["χ >= 10", "10 <= χ"],   # δεκτή οποιαδήποτε από αυτές
##       "answer_display": "χ >= 10",         # τι δείχνουμε ως σωστή απάντηση
##       "difficulty": 1,
##       "mode": "choice",                    # προαιρετικό, για το UI
##       "rule": "...", "params": { ... }     # προαιρετικός ειδικός έλεγχος
##     }, ... ]
##
## Κανόνες (rule) — τρέχουν ΜΟΝΟ αν καμία γραφή του "answers" δεν ταίριαξε:
##   "numeric"  params:{ "value": 1.3333, "tolerance": 0.01 }
##              Δέχεται ισοδύναμες αριθμητικές γραφές: 1.33 / 1,33 / 4/3.
##   "tokens"   params:{ "groups": [["^"], [">", "<>"], ...] }
##              Η απάντηση πρέπει να περιέχει ≥1 στοιχείο από ΚΑΘΕ ομάδα,
##              σε οποιαδήποτε σειρά (π.χ. "ανάφερε έναν τελεστή κάθε είδους").
##   "sequence" params:{ "groups": [["ΛΟΓΙΚΗ"], ["ΧΑΡΑΚΤΗΡΕΣ", "ΧΑΡΑΚΤΗΡΑΣ"]] }
##              Ίδιο με το "tokens", αλλά ΜΕ ΤΗ ΣΕΙΡΑ (π.χ. "τύπος του α,
##              μετά τύπος του β") — έτσι το "ΛΟΓΙΚΗ" σκέτο δεν περνά ως
##              απάντηση δύο μεταβλητών.
##   "range2"   params:{ "min": 1, "max": 10 }
##              Περιμένει 4 αριθμούς: οι 2 πρώτοι μέσα στο [min,max] και
##              διαφορετικοί μεταξύ τους, οι 2 επόμενοι εκτός και επίσης
##              διαφορετικοί μεταξύ τους.
##
## Πολλαπλή επιλογή: πρόσθεσε "options": ["...","..."] και "answer": "<σωστή>".
## Το UI παίρνει τις επιλογές με get_current_options() και χτίζει ένα κουμπί ανά
## επιλογή· η υποβολή γίνεται με το ΚΕΙΜΕΝΟ της επιλογής (ελέγχεται όπως answer).

signal question_changed(index: int, total: int, question_text: String)
signal answer_result(correct: bool)
signal quiz_completed(correct_first_try: int, total: int)

var _pool: Array = []          # όλες οι φορτωμένες ερωτήσεις
var _questions: Array = []     # οι ερωτήσεις του τρέχοντος γύρου
var _index: int = 0
var _correct_first_try: int = 0
var _attempts_on_current: int = 0
var _earned_difficulty: int = 0   # άθροισμα δυσκολίας των σωστών απαντήσεων
var _num_re: RegEx = null         # lazy — βλ. _extract_numbers()

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
		if typeof(item) != TYPE_DICTIONARY or not item.has("question"):
			continue

		# "answers": [...] (νέα μορφή) ή "answer": "..." (παλιά μορφή)
		var answers: Array = []
		if item.has("answers") and typeof(item["answers"]) == TYPE_ARRAY:
			for a in item["answers"]:
				answers.append(str(a))
		elif item.has("answer"):
			answers.append(str(item["answer"]))

		var rule := str(item.get("rule", ""))
		# Χωρίς αποδεκτή γραφή ΚΑΙ χωρίς κανόνα, η ερώτηση δεν απαντιέται ποτέ.
		if answers.is_empty() and rule == "":
			continue

		var diff := 1
		if item.has("difficulty"):
			diff = clampi(int(item["difficulty"]), 1, 3)

		var display := str(item.get("answer_display", ""))
		if display == "" and not answers.is_empty():
			display = str(answers[0])

		var params: Dictionary = {}
		if item.has("params") and typeof(item["params"]) == TYPE_DICTIONARY:
			params = item["params"]

		# Πολλαπλή επιλογή: οι επιλογές που θα δείξει το UI (κενό αν δεν είναι MC).
		var options: Array = []
		if item.has("options") and typeof(item["options"]) == TYPE_ARRAY:
			for o in item["options"]:
				options.append(str(o))

		_pool.append({
			"question": str(item["question"]),
			"answers": answers,
			"display": display,
			"difficulty": diff,
			"rule": rule,
			"params": params,
			"mode": str(item.get("mode", "")),
			"options": options,
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
	if not _has_current():
		return 1
	return int(_questions[_index].get("difficulty", 1))

## Πόσες ΛΑΘΟΣ απαντήσεις έχουν δοθεί στην τρέχουσα ερώτηση.
## Το UI το χρησιμοποιεί για να αποφασίσει πότε να αποκαλύψει τη λύση.
func get_attempts() -> int:
	return _attempts_on_current

## Η σωστή απάντηση σε μορφή για εμφάνιση (μετά από αποτυχημένες προσπάθειες).
func get_current_answer_display() -> String:
	if not _has_current():
		return ""
	return str(_questions[_index].get("display", ""))

## Προαιρετική ένδειξη για το UI (π.χ. "choice" → κουμπιά αντί πληκτρολόγιο).
func get_current_mode() -> String:
	if not _has_current():
		return ""
	return str(_questions[_index].get("mode", ""))

## Οι επιλογές πολλαπλής επιλογής της τρέχουσας ερώτησης (κενό αν δεν είναι MC).
## Το UI χτίζει ένα κουμπί ανά επιλογή και υποβάλλει το κείμενό της.
func get_current_options() -> Array:
	if not _has_current():
		return []
	return _questions[_index].get("options", [])

## Υποβολή απάντησης για την τρέχουσα ερώτηση.
## Επιστρέφει true αν είναι σωστή και εκπέμπει answer_result.
## ΔΕΝ προχωρά μόνο του — το scene καλεί advance() όποτε θέλει
## (π.χ. μετά από ~1 δευτερόλεπτο για να προλάβει να διαβαστεί το "Σωστό!").
func submit_answer(text: String) -> bool:
	if not _has_current():
		return false
	var correct := _check(text, _questions[_index])
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

func _has_current() -> bool:
	return _index >= 0 and _index < _questions.size()

func _emit_current() -> void:
	question_changed.emit(_index, get_total(), str(_questions[_index]["question"]))

# ═══════════════════════════════════════════════════════════════════════════
# ΕΛΕΓΧΟΣ ΑΠΑΝΤΗΣΗΣ
# ═══════════════════════════════════════════════════════════════════════════

func _check(text: String, q: Dictionary) -> bool:
	var n := _normalize(text)
	if n == "":
		return false
	for a in q.get("answers", []):
		if n == _normalize(str(a)):
			return true
	match str(q.get("rule", "")):
		"numeric":  return _check_numeric(n, q)
		"tokens":   return _check_tokens(n, q)
		"sequence": return _check_sequence(n, q)
		# ΟΧΙ το n: η κανονικοποίηση σβήνει τα κενά, οπότε το "1 10 0 11" θα
		# γινόταν ένας αριθμός (110011) αντί για τέσσερις.
		"range2":   return _check_range2(text, q)
	return false

## Ισοδύναμες αριθμητικές γραφές: 1.33 ≡ 1,33 ≡ 4/3.
func _check_numeric(n: String, q: Dictionary) -> bool:
	var params: Dictionary = q.get("params", {})
	if not params.has("value"):
		return false
	var v := _parse_number(n)
	if is_nan(v):
		return false
	var tol := float(params.get("tolerance", 0.01))
	return absf(v - float(params["value"])) <= tol

## Δέχεται "1.33", "1,33" και κλάσματα "4/3".
func _parse_number(s: String) -> float:
	var t := s.replace(",", ".")
	if t.count("/") == 1:
		var parts := t.split("/")
		if parts[0].is_valid_float() and parts[1].is_valid_float() \
				and not is_zero_approx(float(parts[1])):
			return float(parts[0]) / float(parts[1])
		return NAN
	if t.is_valid_float():
		return float(t)
	return NAN

## Κάθε ομάδα πρέπει να εκπροσωπείται, σε οποιαδήποτε σειρά.
func _check_tokens(n: String, q: Dictionary) -> bool:
	var groups: Array = q.get("params", {}).get("groups", [])
	if groups.is_empty():
		return false
	for g in groups:
		var hit := false
		for alt in g:
			var na := _normalize(str(alt))
			if na != "" and n.find(na) != -1:
				hit = true
				break
		if not hit:
			return false
	return true

## Ίδιο με το _check_tokens, αλλά κάθε ομάδα πρέπει να βρεθεί ΜΕΤΑ την
## προηγούμενη — ώστε μία λέξη να μη μετράει για δύο ομάδες ταυτόχρονα.
func _check_sequence(n: String, q: Dictionary) -> bool:
	var groups: Array = q.get("params", {}).get("groups", [])
	if groups.is_empty():
		return false
	var from := 0
	for g in groups:
		var best := -1
		var best_len := 0
		for alt in g:
			var na := _normalize(str(alt))
			if na == "":
				continue
			var idx := n.find(na, from)
			if idx != -1 and (best == -1 or idx < best):
				best = idx
				best_len = na.length()
		if best == -1:
			return false
		from = best + best_len
	return true

## 4 αριθμοί: οι 2 πρώτοι μέσα στο [min,max], οι 2 επόμενοι εκτός.
## Δέχεται το ΑΚΑΤΕΡΓΑΣΤΟ κείμενο του παίκτη (βλ. σχόλιο στο _check).
func _check_range2(text: String, q: Dictionary) -> bool:
	var params: Dictionary = q.get("params", {})
	if not (params.has("min") and params.has("max")):
		return false
	var lo := float(params["min"])
	var hi := float(params["max"])
	var nums := _extract_numbers(text)
	if nums.size() < 4:
		return false
	var a_in := nums[0] >= lo and nums[0] <= hi
	var b_in := nums[1] >= lo and nums[1] <= hi
	var c_in := nums[2] >= lo and nums[2] <= hi
	var d_in := nums[3] >= lo and nums[3] <= hi
	if not (a_in and b_in and not c_in and not d_in):
		return false
	# "2 τιμές" σημαίνει δύο ΔΙΑΦΟΡΕΤΙΚΕΣ, όχι η ίδια γραμμένη δύο φορές.
	return not is_equal_approx(nums[0], nums[1]) and not is_equal_approx(nums[2], nums[3])

## Το κόμμα εδώ είναι ΧΩΡΙΣΤΙΚΟ ("3,7" → 3 και 7), όχι υποδιαστολή — αλλιώς
## μια λίστα τιμών θα διαβαζόταν ως ένας δεκαδικός.
func _extract_numbers(s: String) -> Array[float]:
	if _num_re == null:
		_num_re = RegEx.new()
		_num_re.compile("-?\\d+(?:\\.\\d+)?")
	var out: Array[float] = []
	for m in _num_re.search_all(s):
		out.append(float(m.get_string()))
	return out

## Κανονικοποίηση σύγκρισης:
##  - αγνοεί ΟΛΑ τα κενά (και ανάμεσα στους χαρακτήρες: "χ >= 10" ≡ "χ>=10")
##  - αγνοεί κεφαλαία / πεζά
##  - (για ευκολία στα ελληνικά) αγνοεί τόνους και τελικό σίγμα
func _normalize(s: String) -> String:
	var t := s.to_lower()
	t = t.replace(" ", "").replace("\t", "").replace("\n", "").replace("\r", "")
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
