extends Control

# Popup χάρτη: δείχνει τον χάρτη (map1.png) χωρισμένο σε 6 περιοχές.
# Με κλικ πάνω σε μια περιοχή, ο παίκτης μεταφέρεται στην αντίστοιχη σκηνή.
# Προς το παρόν μόνο η Area1 (ΔΑ - δομή ακολουθίας) έχει υλοποιηθεί,
# οπότε όλες οι περιοχές οδηγούν προσωρινά στην Area1.
#
# Σχεδιάζεται ως ξεχωριστή σκηνή (όπως το LootPopup) ώστε να γίνεται
# instance σε κάθε περιοχή: σύνδεσε το κουμπί Map (pressed) -> MapPopup.open.
const AREA1_SCENE := "res://Scenes/Area1.tscn"


# Περιοχή χάρτη -> σκηνή προορισμού.
# Άλλαξε τα paths όταν υλοποιηθούν οι υπόλοιπες περιοχές (Area2..Area6).
const REGION_SCENES := {
	"ΔΑ": AREA1_SCENE,   # Δομή Ακολουθίας   -> Area1 (υλοποιημένη)
	"ΔΕ": AREA1_SCENE,   # Δομή Επιλογής     -> TODO Area2
	"ΕΠ": AREA1_SCENE,   # Δομή Επανάληψης   -> TODO Area3
	"ΠΙΝ": AREA1_SCENE,  # Πίνακες           -> TODO Area4
	"ΥΠ": AREA1_SCENE,   # Υποπρογράμματα    -> TODO Area5
	"ΕΚ": AREA1_SCENE,   # Έλεγχος/Εκσφαλμ.  -> TODO Area6
}

# Νοητό πλέγμα 3 στηλών x 2 γραμμών πάνω στον χάρτη (κανονικοποιημένες θέσεις 0..1).
# Πάνω σειρά:  ΔΑ | ΔΕ | ΕΠ
# Κάτω σειρά:  ΠΙΝ | ΥΠ | ΕΚ
const REGION_GRID := [["ΔΑ", "ΔΕ", "ΕΠ"], ["ΠΙΝ", "ΥΠ", "ΕΚ"]]
const COL_SPLIT_1 := 0.40   # όριο 1ης/2ης στήλης
const COL_SPLIT_2 := 0.66   # όριο 2ης/3ης στήλης
const ROW_SPLIT := 0.50     # όριο πάνω/κάτω σειράς

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
	var col := 0
	if u >= COL_SPLIT_2:
		col = 2
	elif u >= COL_SPLIT_1:
		col = 1
	var row := 0 if v < ROW_SPLIT else 1
	return REGION_GRID[row][col]

func _go_to_region(region: String) -> void:
	var scene_path: String = REGION_SCENES.get(region, AREA1_SCENE)
	print("Χάρτης: επιλέχθηκε περιοχή ", region, " -> ", scene_path)
	close_popup()
	get_tree().change_scene_to_file(scene_path)
