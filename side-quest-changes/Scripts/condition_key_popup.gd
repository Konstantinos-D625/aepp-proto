extends Control

# Popup "συνθήκης εισόδου": δείχνει τη συνθήκη (π.χ. "k <= 8", ή σύνθετες
# συνθήκες με πολλά ΚΑΙ, πιθανόν σε διαφορετικές κατηγορίες κλειδιών) και
# τις κατηγορίες κλειδιών που έχει ο παίκτης (KeyInventory autoload). Ο
# παίκτης σέρνει (drag and drop) ένα κλειδί πάνω στο KeyDropZone:
#   - Αν το κλειδί ικανοποιεί ΚΑΠΟΙΟ ανεκπλήρωτο clause της συνθήκης (ίδια
#     κατηγορία ΚΑΙ τιμή μέσα στο [min, max] του clause) -> το κλειδί
#     καταναλώνεται, το clause γίνεται satisfied. Όταν ΟΛΑ τα clauses
#     γίνουν satisfied -> ανοίγει η πόρτα (key_accepted).
#   - Αλλιώς -> το κλειδί σπάει (αφαιρείται) και δείχνει μήνυμα λάθους, το
#     popup μένει ανοιχτό για να δοκιμάσει άλλο κλειδί.
#
# Κάθε clause: {"category": String, "min": int, "max": int}. Η τιμή ενός
# κλειδιού μετατρέπεται πάντα σε int πριν συγκριθεί με [min, max] του clause
# (βλ. _as_int): false -> 0, true -> 1, χαρακτήρας -> ο Unicode κωδικός του
# πρώτου γράμματός του — ώστε η ΙΔΙΑ σύγκριση εύρους να καλύπτει αριθμητικά,
# λογικά, ΚΑΙ κλειδιά χαρακτήρων χωρίς ξεχωριστή λογική ανά τύπο.

signal key_accepted

var _clauses: Array = []   # Array of {"category": String, "min": int, "max": int, "satisfied": bool}
var _selected_category := ""

func _ready() -> void:
	hide()
	%Dim.gui_input.connect(_on_dim_input)
	%CloseButton.pressed.connect(close_popup)
	%DropZone.key_dropped.connect(_on_key_dropped)
	KeyInventory.changed.connect(_refresh_categories)

## clauses: Array από Dictionaries {"category": String, "min": int, "max": int}
## — ΕΝΑ ανά κλειδί που χρειάζεται η συνθήκη· χρειάζονται ΟΛΑ (λογικό ΚΑΙ),
## ένα-ένα, με drag and drop. π.χ. για "k <= 8": [{"category": "Αριθμητικό
## Κλειδί", "min": -2147483648, "max": 8}]. Για σύνθετη συνθήκη με keys από
## διαφορετικές κατηγορίες (π.χ. Chapel: αριθμητικό > 5 ΚΑΙ χαρακτήρας = 'Κ')
## απλά προστίθενται 2 διαφορετικά clauses.
func open_for(condition_text: String, clauses: Array) -> void:
	_clauses = []
	for c in clauses:
		_clauses.append({
			"category": str(c["category"]),
			"min": int(c["min"]),
			"max": int(c["max"]),
			"satisfied": false,
		})
	%ConditionLabel.text = _label_for(condition_text)
	%FeedbackLabel.hide()
	_selected_category = ""
	_refresh_categories()
	show()

func _label_for(condition_text: String) -> String:
	if _clauses.size() <= 1:
		return condition_text
	return "%s   (χρειάζονται %d κλειδιά)" % [condition_text, _clauses.size()]

func close_popup() -> void:
	hide()

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_popup()

func _refresh_categories() -> void:
	for c in %CategoryRow.get_children():
		c.queue_free()
	var categories: Array = KeyInventory.get_categories()
	if categories.is_empty():
		%FeedbackLabel.text = "Δεν έχεις κανένα κλειδί ακόμα."
		%FeedbackLabel.show()
		_clear_keys()
		return
	for cat in categories:
		var btn := Button.new()
		btn.text = cat
		btn.pressed.connect(_on_category_selected.bind(cat))
		%CategoryRow.add_child(btn)
	if _selected_category == "" or not categories.has(_selected_category):
		_selected_category = categories[0]
	_refresh_keys()

func _on_category_selected(cat: String) -> void:
	_selected_category = cat
	_refresh_keys()

func _refresh_keys() -> void:
	_clear_keys()
	for v in KeyInventory.get_keys(_selected_category):
		var token := Button.new()
		token.set_script(preload("res://Scripts/key_token.gd"))
		token.text = _token_label(v)
		token.value = v
		token.category = _selected_category
		token.custom_minimum_size = Vector2(90, 90)
		token.add_theme_font_size_override("font_size", 28)
		%KeysGrid.add_child(token)

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

func _on_key_dropped(value, category: String) -> void:
	KeyInventory.remove_key(category, value)
	var numeric_value := _as_int(value)
	var matched: Dictionary = {}
	for c in _clauses:
		if not c["satisfied"] and c["category"] == category and numeric_value >= c["min"] and numeric_value <= c["max"]:
			matched = c
			break
	if not matched.is_empty():
		matched["satisfied"] = true
		if _all_satisfied():
			%FeedbackLabel.hide()
			close_popup()
			key_accepted.emit()
		else:
			var done: int = _clauses.filter(func(c): return c["satisfied"]).size()
			%FeedbackLabel.text = "Σωστό! (%d/%d κλειδιά) — ρίξε κι άλλο." % [done, _clauses.size()]
			%FeedbackLabel.show()
			_refresh_categories()
	else:
		%FeedbackLabel.text = "Λάθος! Η τιμή %s δεν ικανοποιεί καμία από τις υπόλοιπες συνθήκες — το κλειδί έσπασε." % _token_label(value)
		%FeedbackLabel.show()
		_refresh_categories()

func _all_satisfied() -> bool:
	for c in _clauses:
		if not c["satisfied"]:
			return false
	return true
