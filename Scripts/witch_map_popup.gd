extends Control

# Popup "Μονοπάτι στο Δάσος": ενδιάμεση οθόνη ανάμεσα στο χωριό (Area1) και
# το boss fight της μάγισσας. Παλιότερα το Houses/House5 στο Area1.tscn
# πήγαινε ΚΑΤΕΥΘΕΙΑΝ στο BossPopup· τώρα πηγαίνει εδώ πρώτα (αόρατο κουμπί
# πάνω στο δάσος του κεντρικού map), και το πραγματικό σπίτι της μάγισσας
# (WitchHouseButton, ίδιο witchHouse.png με πριν) ζει μέσα σε αυτή την οθόνη
# και οδηγεί αυτός στο BossPopup.
#
# Ίδιο navigation μοτίβο με όλα τα υπόλοιπα popups του Area1 (Cotton/Miner/
# Blacksmith/Shop/Boss): Control instanced ως αδερφός node μέσα στο
# Area1.tscn, εμφανίζεται/κρύβεται με show_popup()/close_popup() + fade
# tween, όχι πραγματικό change_scene_to_file (αυτό χρησιμοποιείται μόνο στο
# map_popup.gd για μετάβαση ΜΕΤΑΞΥ περιοχών, όχι για υπο-τοποθεσίες μέσα σε
# μία περιοχή).
#
# ΠΡΟΣΟΧΗ — WitchHouseButton -> BossPopup.show_popup(): αυτή η σύνδεση
# συνδέεται ΕΔΩ, ΣΕ ΚΩΔΙΚΑ (_ready παρακάτω), ΟΧΙ ως connection στο
# Area1.tscn. Μια δοκιμασμένη cross-scene σύνδεση εκεί (από κόμβο ΜΕΣΑ σε
# αυτό το instanced sub-scene προς sibling του Area1) αποδείχτηκε εύθραυστη
# — η Godot την πετούσε επανειλημμένα σε κάθε σοβαρή επεξεργασία/save του
# Area1.tscn. Η σύνδεση σε κώδικα δεν εξαρτάται από metadata του .tscn, άρα
# δεν μπορεί να χαθεί με τον ίδιο τρόπο.
const C_WOOD    := Color(0.200, 0.120, 0.052)
const C_GOLD    := Color(0.940, 0.760, 0.160)
const C_GOLD_S  := Color(1.000, 0.920, 0.560)

func _ready() -> void:
	hide()
	_style_back_button(%BackButton)
	%WitchHouseButton.pressed.connect(_on_witch_house_pressed)
	%GnomeHouseButton.pressed.connect(_on_gnome_button_pressed)
	%GoblinButton.pressed.connect(_on_mini_boss_pressed.bind("goblin"))
	%TreeButton.pressed.connect(_on_mini_boss_pressed.bind("tree"))

## ΡΟΗ: πατώντας το σπίτι ανοίγει ΠΡΩΤΑ το BossPopup με τον εισαγωγικό διάλογο
## (η μάγισσα μέσα στο σπίτι της προκαλεί τον ταξιδιώτη). Από εκεί, με ένα κλικ
## εμφανίζεται η πιθανότητα νίκης + κουμπί «Επίθεση», που τελικά ξεκινάει το
## animated BossFight (βλ. boss_popup.gd -> _launch_fight). Έτσι η ζαριά/odds
## προηγείται της ζωντανής μάχης.
## Ο γονιός (Area1) έχει το BossPopup ως άμεσο sibling — βλ. σχόλιο πιο πάνω
## για το γιατί η σύνδεση γίνεται εδώ αντί για connection στο Area1.tscn.
func _on_witch_house_pressed() -> void:
	var boss := get_parent().get_node_or_null("BossPopup")
	if boss:
		boss.show_popup()

## Ίδιο μοτίβο — το Ανταλλακτήριο του Νάνου (GnomePopup, sibling του Area1):
## 1 Χαλκός + 1 Δέρμα + 1 Σίδερο -> 1 Κέρμα, βλ. Scripts/gnome_popup.gd.
func _on_gnome_button_pressed() -> void:
	var gnome := get_parent().get_node_or_null("GnomePopup")
	if gnome:
		gnome.show_popup()

## Τα δύο mini bosses του δάσους (σπηλιά καλικάντζαρου κάτω-αριστερά,
## στοιχειωμένο δέντρο πάνω-δεξιά — τα κουμπιά είναι ΑΟΡΑΤΑ πάνω στο art του
## χάρτη, ίδιο μοτίβο με τη μάγισσα/νάνο). ΕΝΑ κοινό popup εξυπηρετεί και τα
## δύο — ξεχωρίζουν από το boss_id (βλ. mini_boss_popup.gd BOSS_DEFS).
func _on_mini_boss_pressed(boss_id: String) -> void:
	var mini := get_parent().get_node_or_null("MiniBossPopup")
	if mini:
		mini.show_popup(boss_id)

func show_popup() -> void:
	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.35)

func close_popup() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func(): visible = false)

func _on_back_pressed() -> void:
	close_popup()

## Ίδιο ύφος (ξύλο/χρυσό) με το _style_back_btn των cotton_popup.gd /
## miner_popup.gd / blacksmith_popup.gd, ώστε το κουμπί επιστροφής να δείχνει
## συνεπές σε όλα τα popups του χωριού.
func _style_back_button(btn: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = C_WOOD; n.border_color = C_GOLD.darkened(0.15)
	n.set_border_width_all(4); n.set_corner_radius_all(10)
	n.shadow_color = Color(0, 0, 0, 0.68); n.shadow_size = 7
	btn.add_theme_stylebox_override("normal", n)

	var h := StyleBoxFlat.new()
	h.bg_color = C_WOOD.lightened(0.06); h.border_color = C_GOLD
	h.set_border_width_all(5); h.set_corner_radius_all(10)
	h.shadow_color = C_GOLD.lightened(0.10); h.shadow_size = 16
	btn.add_theme_stylebox_override("hover", h)

	var pr := StyleBoxFlat.new()
	pr.bg_color = Color(0.055, 0.028, 0.008); pr.border_color = C_GOLD.darkened(0.25)
	pr.set_border_width_all(3); pr.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("pressed", pr)
	btn.add_theme_stylebox_override("focus", StyleBoxFlat.new())

	btn.add_theme_color_override("font_color",         C_GOLD)
	btn.add_theme_color_override("font_hover_color",   C_GOLD_S)
	btn.add_theme_color_override("font_pressed_color", C_GOLD.darkened(0.30))
	btn.add_theme_color_override("font_shadow_color",  Color(0, 0, 0, 0.92))
	btn.add_theme_constant_override("shadow_offset_x", 2)
	btn.add_theme_constant_override("shadow_offset_y", 3)
