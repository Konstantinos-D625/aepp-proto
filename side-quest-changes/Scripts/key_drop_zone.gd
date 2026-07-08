extends Panel

# Ζώνη-στόχος όπου ο παίκτης αφήνει (drop) ένα KeyToken για να ελεγχθεί η
# τιμή του έναντι της συνθήκης εισόδου της πύλης (βλ. ConditionKeyPopup).
# Το value ΔΕΝ μετατρέπεται σε int εδώ — διατηρεί τον αρχικό του τύπο
# (int για αριθμητικά κλειδιά, bool για λογικά).

signal key_dropped(value, category: String)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("value")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	key_dropped.emit(data["value"], str(data["category"]))
