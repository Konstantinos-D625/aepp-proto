extends Control

# Popup χάρτη: δείχνει τον χάρτη ("map vertical (2).png") χωρισμένο σε 6
# περιοχές. Με κλικ πάνω σε μια περιοχή, ο παίκτης μεταφέρεται στην αντίστοιχη
# σκηνή. Υλοποιημένες: ΔΑ (Area1), ΔΕ (Area2), ΕΠ (Area3) — οι υπόλοιπες
# οδηγούν προσωρινά στην Area1.
#
# Σχεδιάζεται ως ξεχωριστή σκηνή (όπως το LootPopup) ώστε να γίνεται
# instance σε κάθε περιοχή: σύνδεσε το κουμπί Map (pressed) -> MapPopup.open.
const AREA1_SCENE := "res://Scenes/Area1.tscn"
const AREA2_SCENE := "res://Scenes/Area2.tscn"
const AREA3_SCENE := "res://Scenes/Area3.tscn"


# Περιοχή χάρτη -> σκηνή προορισμού.
# Άλλαξε τα paths όταν υλοποιηθούν οι υπόλοιπες περιοχές (Area4..Area6).
const REGION_SCENES := {
	"ΔΑ": AREA1_SCENE,   # Δομή Ακολουθίας   -> Area1 (bg1.png)
	"ΔΕ": AREA2_SCENE,   # Δομή Επιλογής     -> Area2 (de.area.bg.png)
	"ΕΠ": AREA3_SCENE,   # Δομή Επανάληψης   -> Area3 (ep.area.bg.png)
	"ΠΙΝ": AREA1_SCENE,  # Πίνακες           -> TODO Area4
	"ΥΠ": AREA1_SCENE,   # Υποπρογράμματα    -> TODO Area5
	"ΕΚ": AREA1_SCENE,   # Έλεγχος/Εκσφαλμ.  -> TODO Area6
}

# Κάθε περιοχή έχει ένα "άγκυρα" σημείο (κανονικοποιημένες συντεταγμένες 0..1
# πάνω στην εικόνα χάρτη, x=δεξιά, y=κάτω) τοποθετημένο εκεί που βρίσκεται ο
# δικός της οικισμός/τίτλος στο art. Το κλικ πηγαίνει στην περιοχή με το
# πλησιέστερο άγκυρα σημείο. Αυτό αντικατέστησε ένα παλιότερο άκαμπτο πλέγμα
# 3 στηλών x 2 γραμμών (με σταθερά όρια στηλών/γραμμής) που υπέθετε ότι οι 6
# περιοχές κάθονται σε ορθογώνιο πλέγμα — δεν ισχύει πια με τον νέο χάρτη
# (π.χ. η ΕΚ κάθεται πιο αριστερά από τη ΔΕ, παρότι είναι σε άλλη "στήλη"),
# οπότε ένα απλό όριο x δεν μπορεί να τις ξεχωρίσει σωστά και τις δύο.
const REGION_ANCHORS := {
	"ΔΑ":  Vector2(0.376, 0.173),
	"ΔΕ":  Vector2(0.667, 0.242),
	"ΕΠ":  Vector2(0.898, 0.471),
	"ΠΙΝ": Vector2(0.244, 0.775),
	"ΥΠ":  Vector2(0.500, 0.488),
	"ΕΚ":  Vector2(0.635, 0.627),
}

func _ready() -> void:
	hide()
	%Dim.gui_input.connect(_on_dim_input)
	%MapImage.gui_input.connect(_on_map_input)

func open() -> void:
	show()

func close_popup() -> void:
	hide()

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_popup()

func _on_map_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var img_size: Vector2 = %MapImage.size
		if img_size.x <= 0.0 or img_size.y <= 0.0:
			return
		var u: float = mb.position.x / img_size.x
		var v: float = mb.position.y / img_size.y
		_go_to_region(_region_at(u, v))

func _region_at(u: float, v: float) -> String:
	var click := Vector2(u, v)
	var best_region := ""
	var best_dist := INF
	for region in REGION_ANCHORS:
		var d: float = click.distance_squared_to(REGION_ANCHORS[region])
		if d < best_dist:
			best_dist = d
			best_region = region
	return best_region

func _go_to_region(region: String) -> void:
	var scene_path: String = REGION_SCENES.get(region, AREA1_SCENE)
	print("Χάρτης: επιλέχθηκε περιοχή ", region, " -> ", scene_path)
	close_popup()
	get_tree().change_scene_to_file(scene_path)
