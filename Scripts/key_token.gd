extends Button

# Ένα σέρσιμο (draggable) κλειδί με συγκεκριμένη τιμή — ακέραιη (αριθμητικό
# κλειδί) ή bool (λογικό κλειδί, Αληθής/Ψευδής). Χρησιμοποιείται μέσα στο
# ConditionKeyPopup — ο παίκτης το σέρνει πάνω στο KeyDropZone για να
# ελεγχθεί η τιμή του έναντι της συνθήκης εισόδου. Το value ΔΕΝ έχει τύπο
# int για να μη χαθεί/μετατραπεί η αρχική τιμή bool ενός λογικού κλειδιού.
var value
var category: String = ""

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Button.new()
	preview.text = text   # ίδιο κείμενο με το token (π.χ. "ΨΕΥΔΗΣ", όχι str(value))
	preview.custom_minimum_size = Vector2(90, 90)
	set_drag_preview(preview)
	return {"value": value, "category": category}
