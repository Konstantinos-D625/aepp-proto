extends Control

# ═══════════════════════════════════════════════════════════════════════════
# ProfilePopup — η οθόνη προφίλ του παίκτη (κουμπί profile.png στο HUD)
# ═══════════════════════════════════════════════════════════════════════════
# Αντικατέστησε το παλιό κουμπί/οθόνη «Αποθήκη» (LootPopup) στην πάνω-αριστερή
# γωνία του HUD. Δείχνει τα ΔΗΜΟΣΙΑ στοιχεία προόδου του παίκτη (τα ίδια που θα
# κοινοποιούνται αργότερα στους φίλους — βλ. PlayerProfile.build_public_profile)
# σε δύο υποκατηγορίες (tabs):
#   • «Στοιχεία»     — κεφάλαιο/περιοχή, σερί, ισχύς ομάδας, ήρωες, εξοπλισμός,
#                      και ποιους boss έχει νικήσει.
#   • «Επιτεύγματα»  — ο κατάλογος Achievements.get_all() με ξεκλείδωτα/κλειδωμένα.
#
# USERNAME: δεν υπάρχει ακόμα σύστημα λογαριασμών (Φάση 3 του online πλάνου) —
# προς το παρόν δείχνει placeholder. Μόλις μπει το auth, ο caller καλεί απλώς
# set_username(<το όνομα του account>) και το UI ενημερώνεται.
#
# Δουλεύει 100% offline — διαβάζει μόνο από τα τοπικά autoloads (PlayerProfile/
# Achievements). Ίδιο navigation μοτίβο (show_popup/close_popup + fade) και ίδιο
# ύφος κάρτας (σκούρο panel + χρυσό) με το InventoryPopup.

const EMBLEM_PATH := "res://Εικόνες/profile.png"

# ── Παλέτα (ίδιο ύφος με inventory_popup.gd) ─────────────────────────────────
const C_PARCH := Color("f3e6c4")
const C_MUTED := Color("cdbf9a")
const C_GOLD  := Color("f2c84b")
const C_GOLD_D:= Color(0.360, 0.278, 0.058)
const C_OK    := Color(0.560, 0.900, 0.460)
const C_LOCK  := Color(0.45, 0.42, 0.36)

# username: γεμίζει από το σύστημα λογαριασμών (Φάση 3). Placeholder ως τότε.
var _username := "Ταξιδιώτης"
var _tab := "stats"            # "stats" | "achievements"

var _list: VBoxContainer
var _stats_btn: Button
var _ach_btn: Button
var _name_label: Label


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_build()

## Μελλοντικό hook (Φάση 3 auth): θέτει το εμφανιζόμενο username.
func set_username(name: String) -> void:
	_username = name if name != "" else "Ταξιδιώτης"
	if is_instance_valid(_name_label):
		_name_label.text = _username

func show_popup() -> void:
	visible = true
	_refresh()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)

func close_popup() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func(): visible = false)


# ═══════════════════════════════════════════════════════════════════════════
# ΚΑΤΑΣΚΕΥΗ UI (χτίζεται ΜΙΑ φορά· το περιεχόμενο ξαναγεμίζει στο _refresh)
# ═══════════════════════════════════════════════════════════════════════════
func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var card := Panel.new()
	card.anchor_left = 0.5; card.anchor_top = 0.5
	card.anchor_right = 0.5; card.anchor_bottom = 0.5
	card.offset_left = -440.0; card.offset_top = -600.0
	card.offset_right = 440.0; card.offset_bottom = 600.0
	card.clip_contents = true
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.08, 0.08, 0.12, 0.97)
	csb.set_corner_radius_all(16)
	csb.set_border_width_all(3)
	csb.border_color = C_GOLD_D
	card.add_theme_stylebox_override("panel", csb)
	add_child(card)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_top", 46)
	margin.add_theme_constant_override("margin_bottom", 44)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	# ── Header: έμβλημα (profile.png) + username ──
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 22)
	vbox.add_child(header)

	var emblem := TextureRect.new()
	emblem.custom_minimum_size = Vector2(160, 160)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(EMBLEM_PATH):
		emblem.texture = load(EMBLEM_PATH)
	header.add_child(emblem)

	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_col.add_theme_constant_override("separation", 4)
	header.add_child(name_col)

	_name_label = Label.new()
	_name_label.text = _username
	_name_label.add_theme_color_override("font_color", C_GOLD)
	_name_label.add_theme_font_size_override("font_size", 46)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_col.add_child(_name_label)

	var sub := Label.new()
	sub.text = "Το προφίλ σου"
	sub.add_theme_color_override("font_color", C_MUTED)
	sub.add_theme_font_size_override("font_size", 26)
	name_col.add_child(sub)

	# ── Tabs ──
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 14)
	vbox.add_child(tabs)
	_stats_btn = _make_tab("📊  Στοιχεία", "stats")
	_ach_btn   = _make_tab("🏆  Επιτεύγματα", "achievements")
	tabs.add_child(_stats_btn)
	tabs.add_child(_ach_btn)

	vbox.add_child(HSeparator.new())

	# ── Scrollable περιεχόμενο ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)

	# ── Κουμπί κλεισίματος (πάνω-δεξιά της κάρτας) ──
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.anchor_left = 1.0; close_btn.anchor_right = 1.0
	close_btn.offset_left = -78.0; close_btn.offset_top = 16.0
	close_btn.offset_right = -18.0; close_btn.offset_bottom = 76.0
	close_btn.add_theme_font_size_override("font_size", 38)
	close_btn.pressed.connect(close_popup)
	card.add_child(close_btn)


func _make_tab(text: String, id: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 72)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(func(): _select_tab(id))
	return b

func _select_tab(id: String) -> void:
	_tab = id
	_refresh()

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_popup()


# ═══════════════════════════════════════════════════════════════════════════
# ΠΕΡΙΕΧΟΜΕΝΟ
# ═══════════════════════════════════════════════════════════════════════════
func _refresh() -> void:
	_stats_btn.button_pressed = _tab == "stats"
	_ach_btn.button_pressed = _tab == "achievements"
	for c in _list.get_children():
		c.queue_free()
	if _tab == "stats":
		_populate_stats()
	else:
		_populate_achievements()

func _populate_stats() -> void:
	# ΜΟΝΑΔΙΚΗ πηγή: το ίδιο δημόσιο προφίλ που θα στέλνεται στον server (Φάση 4).
	var p := PlayerProfile.build_public_profile()
	_list.add_child(_stat_row("🗺", "Κεφάλαιο", str(p["region_label"])))
	_list.add_child(_stat_row("🔥", "Σερί (streak)", "%d ημέρες" % int(p["streak"])))
	_list.add_child(_stat_row("💪", "Ισχύς Ομάδας", "%.1f / 20" % float(p["party_power"])))
	_list.add_child(_stat_row("🧑", "Ήρωες", str(int(p["roster_size"]))))
	_list.add_child(_stat_row("⚔", "Εξοπλισμός", str(int(p["gear_owned"]))))
	_list.add_child(_stat_row("🏆", "Επιτεύγματα",
		"%d / %d" % [int(p["achievements_count"]), int(p["achievements_total"])]))

	_list.add_child(_section_label("— Κατακτήσεις —"))
	_list.add_child(_bool_row("👺", "Ζούμπας ο Καλικάντζαρος", bool(p["goblin_defeated"])))
	_list.add_child(_bool_row("🌳", "Στοιχειωμένο Δέντρο", bool(p["tree_defeated"])))
	_list.add_child(_bool_row("🔮", "Μόργκανα η Μάγισσα", bool(p["morgana_defeated"])))

func _populate_achievements() -> void:
	for a in Achievements.get_all():
		_list.add_child(_ach_row(a))


# ═══════════════════════════════════════════════════════════════════════════
# ΓΡΑΜΜΕΣ / ΒΟΗΘΗΤΙΚΑ
# ═══════════════════════════════════════════════════════════════════════════
func _stat_row(icon: String, label: String, value: String, value_color: Color = C_GOLD) -> Control:
	var card := _row_card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var ic := Label.new()
	ic.text = icon
	ic.add_theme_font_size_override("font_size", 30)
	ic.custom_minimum_size = Vector2(46, 0)
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(ic)

	var l := Label.new()
	l.text = label
	l.add_theme_color_override("font_color", C_PARCH)
	l.add_theme_font_size_override("font_size", 28)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)

	var v := Label.new()
	v.text = value
	v.add_theme_color_override("font_color", value_color)
	v.add_theme_font_size_override("font_size", 28)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	return card

func _bool_row(icon: String, label: String, done: bool) -> Control:
	return _stat_row(icon, label, "Νικήθηκε ✓" if done else "Εκκρεμεί", C_OK if done else C_MUTED)

func _ach_row(a: Dictionary) -> Control:
	var unlocked: bool = bool(a.get("unlocked", false))
	var card := _row_card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	var icon := Label.new()
	icon.text = str(a.get("icon", "🏆")) if unlocked else "🔒"
	icon.add_theme_font_size_override("font_size", 40)
	icon.custom_minimum_size = Vector2(58, 0)
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(icon)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	var name_l := Label.new()
	name_l.text = str(a.get("name", ""))
	name_l.add_theme_color_override("font_color", C_GOLD if unlocked else C_LOCK)
	name_l.add_theme_font_size_override("font_size", 28)
	col.add_child(name_l)

	var desc_l := Label.new()
	desc_l.text = str(a.get("desc", ""))
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_l.add_theme_color_override("font_color", C_MUTED if unlocked else C_LOCK.darkened(0.1))
	desc_l.add_theme_font_size_override("font_size", 20)
	col.add_child(desc_l)

	card.modulate.a = 1.0 if unlocked else 0.6
	return card

func _row_card() -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.22)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	sb.border_color = Color(0, 0, 0, 0.35)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sb)
	return card

func _section_label(text: String) -> Control:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", C_MUTED)
	l.add_theme_font_size_override("font_size", 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
