extends Control

# Popup "συνθήκης εισόδου": δείχνει τη συνθήκη (π.χ. "k <= 8", ή σύνθετες
# συνθήκες με πολλά ΚΑΙ/Ή, πιθανόν σε διαφορετικές κατηγορίες κλειδιών) και
# ΟΛΑ τα κλειδιά που κατέχει ο παίκτης μαζί, από όλες τις κατηγορίες
# (KeyInventory autoload) — χωρίς tabs επιλογής κατηγορίας, βλ. _refresh_keys.
# Ο παίκτης σέρνει (drag and drop) ένα κλειδί πάνω στο KeyDropZone:
#   - Αν το κλειδί ικανοποιεί ΚΑΠΟΙΟ ανεκπλήρωτο clause της συνθήκης (βλ.
#     _clause_matches παρακάτω για τους τύπους clause) -> το κλειδί
#     καταναλώνεται, το clause γίνεται satisfied.
#   - mode "AND" (προεπιλογή): η πόρτα ανοίγει (key_accepted) όταν ΟΛΑ τα
#     clauses γίνουν satisfied.
#   - mode "OR": η πόρτα ανοίγει μόλις ΕΝΑ clause γίνει satisfied.
#   - Αλλιώς (το κλειδί δεν ικανοποιεί/προωθεί κανένα ανεκπλήρωτο clause) ->
#     το κλειδί σπάει (αφαιρείται) και δείχνει μήνυμα λάθους, το popup μένει
#     ανοιχτό για να δοκιμάσει άλλο κλειδί.
#
# Κάθε clause είναι {"category": String, ...} + προαιρετικό "type" (default
# "range"):
#   - "range" (προεπιλογή, βλ. και παλιό σχήμα χωρίς "type"): {"min": int,
#     "max": int} — ικανοποιείται από ΕΝΑ κλειδί με τιμή μέσα στο [min, max].
#     Η τιμή ενός κλειδιού μετατρέπεται πάντα σε int πριν τη σύγκριση (βλ.
#     _as_int): false -> 0, true -> 1, χαρακτήρας -> ο Unicode κωδικός του
#     πρώτου γράμματός του — ώστε η ΙΔΙΑ σύγκριση εύρους να καλύπτει
#     αριθμητικά, λογικά, ΚΑΙ κλειδιά χαρακτήρων χωρίς ξεχωριστή λογική.
#   - "mod": {"modulus": int, "remainder": int} — ικανοποιείται από ΕΝΑ
#     αριθμητικό κλειδί με value % modulus == remainder.
#   - "sum": {"target": int} — ικανοποιείται από ΔΥΟ κλειδιά της ΙΔΙΑΣ
#     κατηγορίας που το άθροισμά τους φτάνει ΑΚΡΙΒΩΣ το target. Το πρώτο
#     κλειδί που δεν ξεπερνάει το target μπαίνει σε "αναμονή" (banked) αντί
#     να σπάσει — βλ. _on_key_dropped/_try_sum_clause.

signal key_accepted

# Χρώματα μηνύματος ανατροφοδότησης (βλ. _on_key_dropped) — πράσινο για σωστό
# κλειδί/μερική πρόοδο, κόκκινο ΜΟΝΟ όταν σπάει κλειδί. Το FeedbackLabel έχει
# σταθερό κόκκινο font_color στο .tscn (ίδια απόχρωση με C_BAD εδώ) — γι' αυτό
# χρειάζεται ρητό override σε κάθε περίπτωση, όχι μόνο στο λάθος.
const C_OK  := Color(0.42, 0.78, 0.40)
const C_BAD := Color(0.86, 0.28, 0.24)

var _clauses: Array = []   # Array of {"category", "type", ..., "satisfied": bool}
var _mode := "AND"         # "AND" (όλα τα clauses) ή "OR" (αρκεί ένα)

# room_id -> Array (ίδιο σχήμα με _clauses) — η πρόοδος clauses που έχει ήδη
# ικανοποιηθεί σε μια ΠΡΟΗΓΟΥΜΕΝΗ επίσκεψη στο ΙΔΙΟ gate, πριν κλειστεί το
# popup χωρίς να ολοκληρωθεί η συνθήκη. Χωρίς αυτό, κάθε open_for() έχτιζε
# πάντα ΚΑΙΝΟΥΡΓΙΑ clauses (όλα satisfied=false) — αν ο παίκτης είχε ήδη
# ρίξει ένα κλειδί (που καταναλώνεται αμέσως, βλ. _on_key_dropped) και μετά
# έκλεινε το popup πριν βρει το δεύτερο, η πρόοδος χανόταν ΚΑΙ το κλειδί ήταν
# ήδη φαγωμένο — αδιέξοδο (βλ. συζήτηση bug). Καθαρίζεται μόλις η συνθήκη
# ολοκληρωθεί πλήρως (βλ. _on_key_dropped) αφού το gate δεν ξαναζητείται.
var _saved_clauses: Dictionary = {}
var _current_room_id := ""

func _ready() -> void:
	hide()
	%Dim.gui_input.connect(_on_dim_input)
	%CloseButton.pressed.connect(close_popup)
	%DropZone.key_dropped.connect(_on_key_dropped)
	KeyInventory.changed.connect(_refresh_keys)

## clauses: Array από Dictionaries — βλ. σχόλιο στην κορυφή του αρχείου για
## τους 3 τύπους ("range"/"mod"/"sum"). Ένα clause ανά κλειδί που χρειάζεται
## η συνθήκη (εκτός από "sum", που χρειάζεται 2 κλειδιά ΓΙΑ ΤΟ ΙΔΙΟ clause).
## π.χ. για "k <= 8": [{"category": "Αριθμητικό Κλειδί", "min":
## -2147483648, "max": 8}]. Για σύνθετη συνθήκη με keys από διαφορετικές
## κατηγορίες (π.χ. Chapel: αριθμητικό > 5 ΚΑΙ χαρακτήρας = 'Κ') απλά
## προστίθενται 2 διαφορετικά clauses.
## mode: "AND" (προεπιλογή, χρειάζονται ΟΛΑ τα clauses) ή "OR" (αρκεί ΕΝΑ).
## room_id: κλειδί για την αποθηκευμένη πρόοδο (βλ. _saved_clauses) — ίδιο
## room_id σε ξαναπάτημα του ΙΔΙΟΥ gate συνεχίζει από εκεί που έμεινε αντί να
## ξαναρχίσει από το μηδέν.
func open_for(condition_text: String, clauses: Array, mode: String = "AND", room_id: String = "") -> void:
	_mode = mode
	_current_room_id = room_id
	if room_id != "" and _saved_clauses.has(room_id):
		_clauses = (_saved_clauses[room_id] as Array).duplicate(true)
	else:
		_clauses = []
		for c in clauses:
			var type: String = str(c.get("type", "range"))
			var clause := {
				"category": str(c["category"]),
				"type": type,
				"satisfied": false,
			}
			match type:
				"mod":
					clause["modulus"] = int(c["modulus"])
					clause["remainder"] = int(c["remainder"])
				"sum":
					clause["target"] = int(c["target"])
					clause["partial_sum"] = 0
					clause["partial_count"] = 0
				_:
					clause["min"] = int(c["min"])
					clause["max"] = int(c["max"])
			_clauses.append(clause)
	%ConditionLabel.text = _label_for(condition_text)
	%FeedbackLabel.hide()
	_refresh_keys()
	show()

func _label_for(condition_text: String) -> String:
	if _clauses.size() <= 1:
		return condition_text
	if _mode == "OR":
		return "%s   (αρκεί 1 από %d κλειδιά)" % [condition_text, _clauses.size()]
	return "%s   (χρειάζονται %d κλειδιά)" % [condition_text, _clauses.size()]

func close_popup() -> void:
	hide()

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_popup()

## Δείχνει ΟΛΑ τα κλειδιά του παίκτη μαζί, από ΟΛΕΣ τις κατηγορίες — δεν
## χρειάζεται πια να διαλέξει πρώτα κατηγορία (πριν, tabs + ένα KeysGrid ανά
## επιλεγμένη κατηγορία). Η κατηγορία κάθε token ξεχωρίζει ΜΟΝΟ από το
## χρωματιστό περίγραμμά του (βλ. _make_key_token) — π.χ. ένα Κλειδί
## Χαρακτήρων με τιμή "7" και ένα Αριθμητικό Κλειδί με τιμή 7 θα ήταν αλλιώς
## πανομοιότυπα στην οθόνη.
func _refresh_keys() -> void:
	_clear_keys()
	var categories: Array = KeyInventory.get_categories()
	if categories.is_empty():
		%FeedbackLabel.text = "Δεν έχεις κανένα κλειδί ακόμα."
		%FeedbackLabel.show()
		return
	for cat in categories:
		for v in KeyInventory.get_keys(cat):
			%KeysGrid.add_child(_make_key_token(v, cat))

func _make_key_token(v, cat: String) -> Button:
	var token := Button.new()
	token.set_script(preload("res://Scripts/key_token.gd"))
	token.text = _token_label(v)
	token.value = v
	token.category = cat
	token.custom_minimum_size = Vector2(90, 90)
	token.add_theme_font_size_override("font_size", 28)

	# Χρωματιστό περίγραμμα ανά κατηγορία (ίδια χρώματα με Currency.COLORS,
	# βλ. currency_manager.gd) — δεύτερο, πιο άμεσο οπτικό στοιχείο πέρα από
	# το εικονίδιο, ώστε να ξεχωρίζουν με μια ματιά μέσα στο ενιαίο πλέγμα.
	var tint: Color = Currency.COLORS.get(cat, Color(0.94, 0.76, 0.16))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.09, 0.05, 0.92)
	normal.border_color = tint
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(10)
	token.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.18, 0.13, 0.07, 0.92)
	hover.border_color = tint.lightened(0.2)
	token.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.06, 0.045, 0.025, 0.92)
	token.add_theme_stylebox_override("pressed", pressed)
	token.add_theme_stylebox_override("focus", StyleBoxFlat.new())
	return token

func _token_label(v) -> String:
	if typeof(v) == TYPE_BOOL:
		return "ΑΛΗΘΗΣ" if v else "ΨΕΥΔΗΣ"
	return str(v)

func _clear_keys() -> void:
	for c in %KeysGrid.get_children():
		c.queue_free()

## Μετατρέπει την τιμή ενός κλειδιού σε int για σύγκριση με [min, max] ενός
## clause — false -> 0, true -> 1, χαρακτήρας -> ο Unicode κωδικός του
## πρώτου γράμματός του, αριθμός -> ο ίδιος.
func _as_int(value) -> int:
	match typeof(value):
		TYPE_BOOL:
			return 1 if value else 0
		TYPE_STRING:
			return value.unicode_at(0) if value.length() > 0 else 0
		_:
			return int(value)

## Ελέγχει αν το (category, numeric_value) που μόλις έριξε ο παίκτης
## προωθεί ΑΥΤΟ το clause — "satisfied" (το ολοκληρώνει τώρα), "partial"
## (μόνο για "sum": έγκυρη μερική πρόοδος, δεν ξεπερνάει το target ακόμα),
## ή "no_match" (άσχετο/λάθος για αυτό το clause).
func _clause_matches(c: Dictionary, category: String, numeric_value: int) -> String:
	if c["satisfied"] or c["category"] != category:
		return "no_match"
	match str(c["type"]):
		"mod":
			if numeric_value % int(c["modulus"]) == int(c["remainder"]):
				return "satisfied"
			return "no_match"
		"sum":
			var new_sum: int = int(c["partial_sum"]) + numeric_value
			if new_sum == int(c["target"]) and int(c["partial_count"]) + 1 >= 2:
				return "satisfied"
			if new_sum < int(c["target"]):
				return "partial"
			return "no_match"
		_:
			if numeric_value >= int(c["min"]) and numeric_value <= int(c["max"]):
				return "satisfied"
			return "no_match"

func _on_key_dropped(value, category: String) -> void:
	KeyInventory.remove_key(category, value)
	var numeric_value := _as_int(value)

	# Πρώτο πέρασμα: υπάρχει clause που ΟΛΟΚΛΗΡΩΝΕΤΑΙ με αυτό το κλειδί;
	# Δεύτερο πέρασμα (μόνο αν όχι): υπάρχει "sum" clause που δέχεται μερική
	# πρόοδο (banked, όχι σπασμένο κλειδί) χωρίς να ξεπερνάει το target;
	var satisfied_clause: Dictionary = {}
	var partial_clause: Dictionary = {}
	for c in _clauses:
		var result := _clause_matches(c, category, numeric_value)
		if result == "satisfied":
			satisfied_clause = c
			break
		elif result == "partial" and partial_clause.is_empty():
			partial_clause = c

	if not satisfied_clause.is_empty():
		if str(satisfied_clause["type"]) == "sum":
			satisfied_clause["partial_sum"] = int(satisfied_clause["partial_sum"]) + numeric_value
			satisfied_clause["partial_count"] = int(satisfied_clause["partial_count"]) + 1
		satisfied_clause["satisfied"] = true
		if _mode == "OR" or _all_satisfied():
			_saved_clauses.erase(_current_room_id)   # ολοκληρώθηκε — δεν ξαναχρειάζεται
			%FeedbackLabel.hide()
			close_popup()
			key_accepted.emit()
		else:
			_save_progress()
			var done: int = _clauses.filter(func(c): return c["satisfied"]).size()
			%FeedbackLabel.add_theme_color_override("font_color", C_OK)
			%FeedbackLabel.text = "Σωστό! (%d/%d κλειδιά) — ρίξε κι άλλο." % [done, _clauses.size()]
			%FeedbackLabel.show()
			_refresh_keys()
	elif not partial_clause.is_empty():
		partial_clause["partial_sum"] = int(partial_clause["partial_sum"]) + numeric_value
		partial_clause["partial_count"] = int(partial_clause["partial_count"]) + 1
		_save_progress()
		%FeedbackLabel.add_theme_color_override("font_color", C_OK)
		%FeedbackLabel.text = "Καλή αρχή! Κράτησε το %s — ρίξε κι άλλο κλειδί για να ολοκληρώσεις το άθροισμα." % _token_label(value)
		%FeedbackLabel.show()
		_refresh_keys()
	else:
		%FeedbackLabel.add_theme_color_override("font_color", C_BAD)
		%FeedbackLabel.text = "Λάθος! Η τιμή %s δεν ικανοποιεί καμία από τις υπόλοιπες συνθήκες — το κλειδί έσπασε." % _token_label(value)
		%FeedbackLabel.show()
		_refresh_keys()

func _all_satisfied() -> bool:
	for c in _clauses:
		if not c["satisfied"]:
			return false
	return true

## Θυμάται την τρέχουσα (ημιτελή) πρόοδο clauses γι' αυτό το room_id, ώστε αν
## ο παίκτης κλείσει το popup τώρα (πάτημα Χ/Dim) και το ξανανοίξει αργότερα
## (π.χ. αφού βρει το επόμενο κλειδί), να συνεχίσει από εδώ αντί να ξαναρχίσει
## από το μηδέν — βλ. σχόλιο στο _saved_clauses παραπάνω.
func _save_progress() -> void:
	if _current_room_id != "":
		_saved_clauses[_current_room_id] = _clauses.duplicate(true)
