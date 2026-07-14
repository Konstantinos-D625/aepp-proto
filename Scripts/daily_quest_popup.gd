extends Control

# ═══════════════════════════════════════════════════════════════════════════
# Daily Quest — Popup πρόσκλησης
# ═══════════════════════════════════════════════════════════════════════════
# Εμφανίζεται όταν ο παίκτης πατάει το εικονίδιο "Daily Quest" στο sidebar
# (HUD/Sidebar/DailyQuest). Ακολουθεί το ίδιο μοτίβο Dim+Board με το
# LootPopup/MapPopup ώστε να είναι οπτικά συνεπές με το υπόλοιπο UI.
#
# Όλη η πραγματική λογική streak / save βρίσκεται στο Autoload "GameData"
# (res://Scripts/GameData.gd) — αυτό το script δεν κρατάει δικά του
# δεδομένα, απλώς τον ενημερώνει.

signal go_pressed

const C_GREEN       := Color(0.165, 0.420, 0.145)
const C_GREEN_HOVER := Color(0.225, 0.530, 0.195)
const C_GREEN_PRESS := Color(0.110, 0.300, 0.095)
const C_GREEN_DIS   := Color(0.120, 0.150, 0.115)
const C_GOLD        := Color(0.940, 0.760, 0.160)
const C_BONE        := Color(0.868, 0.830, 0.685)

@onready var _title_label: Label  = %TitleLabel
@onready var _desc_label: Label   = %DescriptionLabel
@onready var _status_label: Label = %StatusLabel
@onready var _go_button: Button   = %GoButton


func _ready() -> void:
	hide()
	_style_go_button(_go_button)
	%Dim.gui_input.connect(_on_dim_input)


## Δημόσια μέθοδος ανοίγματος — καλείται από το κουμπί DailyQuest στο HUD.
func open() -> void:
	_refresh_state()
	show()

## Alias, ώστε να μπορεί να συνδεθεί με το ίδιο όνομα ("show_popup") που
## χρησιμοποιούν τα υπόλοιπα popups του χωριού (Blacksmith/Miner/Cotton),
## αν χρειαστεί ποτέ συνέπεια ονοματολογίας.
func show_popup() -> void:
	open()

func close_popup() -> void:
	hide()

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_popup()


func _refresh_state() -> void:
	_title_label.text = "Έτοιμος να ανανεώσεις το streak σου;"

	if GameData.is_daily_quest_completed_today():
		_desc_label.text      = "Ολοκλήρωσες το Daily Quest για σήμερα!"
		_status_label.text    = "✓ Ολοκληρωμένο — έλα ξανά αύριο"
		_status_label.visible = true
		_go_button.text       = "ΟΛΟΚΛΗΡΩΘΗΚΕ"
		_go_button.disabled   = true
	else:
		_desc_label.text      = "3 επίπεδα ασκήσεων — δοκίμασε όσες φορές θέλεις μέχρι να τα καταφέρεις!"
		_status_label.visible = false
		_go_button.text       = "ΠΑΜΕ"
		_go_button.disabled   = false


func _on_go_pressed() -> void:
	if GameData.is_daily_quest_completed_today():
		return
	close_popup()
	go_pressed.emit()


# ═══════════════════════════════════════════════════════════════════════════
# ΣΤΥΛ ΚΟΥΜΠΙΟΥ "ΠΑΜΕ" — μεγάλο πράσινο κουμπί, στην ίδια γλώσσα σχεδίασης
# (χρυσά περιγράμματα/σκιές) με τα υπόλοιπα κουμπιά του project
# (βλ. _style_iron σε CharacterSelect.gd, _style_back_btn στα popups).
# ═══════════════════════════════════════════════════════════════════════════
func _style_go_button(btn: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color     = C_GREEN
	n.border_color = C_GOLD.darkened(0.22)
	n.set_border_width_all(4)
	n.set_corner_radius_all(14)
	n.shadow_color = Color(0, 0, 0, 0.70)
	n.shadow_size  = 8
	btn.add_theme_stylebox_override("normal", n)

	var h := StyleBoxFlat.new()
	h.bg_color     = C_GREEN_HOVER
	h.border_color = C_GOLD
	h.set_border_width_all(5)
	h.set_corner_radius_all(14)
	h.shadow_color = C_GOLD.lightened(0.10)
	h.shadow_size  = 16
	btn.add_theme_stylebox_override("hover", h)

	var p := StyleBoxFlat.new()
	p.bg_color     = C_GREEN_PRESS
	p.border_color = C_GOLD.darkened(0.30)
	p.set_border_width_all(3)
	p.set_corner_radius_all(14)
	btn.add_theme_stylebox_override("pressed", p)

	var d := StyleBoxFlat.new()
	d.bg_color     = C_GREEN_DIS
	d.border_color = C_GOLD.darkened(0.55)
	d.set_border_width_all(3)
	d.set_corner_radius_all(14)
	btn.add_theme_stylebox_override("disabled", d)

	btn.add_theme_stylebox_override("focus", StyleBoxFlat.new())
	btn.add_theme_color_override("font_color",           C_BONE)
	btn.add_theme_color_override("font_hover_color",      C_GOLD)
	btn.add_theme_color_override("font_pressed_color",    C_BONE.darkened(0.30))
	btn.add_theme_color_override("font_disabled_color",   C_BONE.darkened(0.55))
	btn.add_theme_color_override("font_shadow_color",     Color(0, 0, 0, 0.92))
	btn.add_theme_constant_override("shadow_offset_x", 2)
	btn.add_theme_constant_override("shadow_offset_y", 3)
