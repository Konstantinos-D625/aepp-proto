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
# USERNAME (Φάση 3 auth): το ίδιο το popup ακούει το Net.auth_changed και
# ενημερώνει το εμφανιζόμενο όνομα. Ο caller μπορεί επίσης να καλέσει ρητά
# set_username(...). Ένα κουμπί «Σύνδεση/Αποσύνδεση» στην κεφαλίδα εκπέμπει το
# login_requested (το πιάνει το AuthPopup) ή κάνει Net.logout().
#
# Δουλεύει 100% offline — διαβάζει μόνο από τα τοπικά autoloads (PlayerProfile/
# Achievements). Ίδιο navigation μοτίβο (show_popup/close_popup + fade) και ίδιο
# ύφος κάρτας (σκούρο panel + χρυσό) με το InventoryPopup.

const EMBLEM_PATH := "res://Εικόνες/profile.png"
const STATS_ICON_PATH := "res://Εικόνες/stats.png"
const LOCK_ICON_PATH := "res://Εικόνες/lock.png"
const KEY_ICON_PATH := "res://Εικόνες/key.png"

## Ο παίκτης πάτησε «Σύνδεση» — το AuthPopup ανοίγει την οθόνη λογαριασμού.
signal login_requested

# ── Παλέτα (ίδιο ύφος με inventory_popup.gd) ─────────────────────────────────
const C_PARCH := Color("f3e6c4")
const C_MUTED := Color("cdbf9a")
const C_GOLD  := Color("f2c84b")
const C_GOLD_D:= Color(0.360, 0.278, 0.058)
const C_OK    := Color(0.560, 0.900, 0.460)
const C_LOCK  := Color(0.45, 0.42, 0.36)
const C_ERR   := Color(0.92, 0.45, 0.42)   # ζώνη κινδύνου (διαγραφή λογαριασμού)

# username: γεμίζει από το σύστημα λογαριασμών (Φάση 3). Placeholder ως τότε.
var _username := "Ταξιδιώτης"
var _tab := "stats"            # "stats" | "achievements"

var _list: VBoxContainer
var _stats_btn: Button
var _ach_btn: Button
var _name_label: Label
var _account_btn: Button

# ── GDPR: overlay επιβεβαίωσης διαγραφής λογαριασμού (Φάση 8) ─────────────────
var _delete_overlay: Control
var _delete_input: LineEdit
var _delete_confirm_btn: Button
var _delete_status: Label
var _deleting := false


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_build()
	# Φάση 3: το popup συγχρονίζεται μόνο του με την κατάσταση σύνδεσης.
	Net.auth_changed.connect(_on_auth_changed)
	if Net.is_logged_in():
		set_username(Net.get_username())

## Θέτει το εμφανιζόμενο username (καλείται και εσωτερικά από το Net.auth_changed).
func set_username(name: String) -> void:
	_username = name if name != "" else "Ταξιδιώτης"
	if is_instance_valid(_name_label):
		_name_label.text = _username

func _on_auth_changed(logged_in: bool) -> void:
	set_username(Net.get_username() if logged_in else "")
	_refresh_account_btn()

func show_popup() -> void:
	visible = true
	_refresh_account_btn()
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

	# ── Κουμπί λογαριασμού (Σύνδεση / Αποσύνδεση) ──
	_account_btn = Button.new()
	_account_btn.custom_minimum_size = Vector2(0, 60)
	_account_btn.add_theme_font_size_override("font_size", 24)
	_account_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_account_btn.pressed.connect(_on_account_pressed)
	name_col.add_child(_account_btn)
	_refresh_account_btn()

	# ── Tabs ──
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 14)
	vbox.add_child(tabs)
	_stats_btn = _make_tab("Στοιχεία", "stats", STATS_ICON_PATH)
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

	# GDPR: το overlay επιβεβαίωσης μπαίνει ΤΕΛΕΥΤΑΙΟ ώστε να ζωγραφίζεται πάνω απ' όλα.
	_build_delete_overlay()


# ═══════════════════════════════════════════════════════════════════════════
# GDPR — overlay επιβεβαίωσης διαγραφής λογαριασμού (Φάση 8)
# ═══════════════════════════════════════════════════════════════════════════
# Μη αναστρέψιμη ενέργεια: ζητά να πληκτρολογηθεί ξανά το username πριν ενεργοποιηθεί
# το κουμπί διαγραφής. Καλεί Net.delete_account() (cascade στον server + reset τοπικά).
func _build_delete_overlay() -> void:
	_delete_overlay = Control.new()
	_delete_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_delete_overlay.visible = false
	_delete_overlay.mouse_filter = MOUSE_FILTER_STOP
	add_child(_delete_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.78)
	dim.mouse_filter = MOUSE_FILTER_STOP
	_delete_overlay.add_child(dim)

	var card := Panel.new()
	card.anchor_left = 0.5; card.anchor_top = 0.5
	card.anchor_right = 0.5; card.anchor_bottom = 0.5
	card.offset_left = -400.0; card.offset_top = -300.0
	card.offset_right = 400.0; card.offset_bottom = 300.0
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.14, 0.07, 0.07, 0.99)   # σκούρο κόκκινο = ζώνη κινδύνου
	csb.set_corner_radius_all(16)
	csb.set_border_width_all(3)
	csb.border_color = C_ERR
	card.add_theme_stylebox_override("panel", csb)
	_delete_overlay.add_child(card)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	card.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "⚠  Διαγραφή λογαριασμού"
	title.add_theme_color_override("font_color", C_ERR)
	title.add_theme_font_size_override("font_size", 40)
	vb.add_child(title)

	var warn := Label.new()
	warn.text = ("Η ενέργεια είναι ΟΡΙΣΤΙΚΗ και δεν αναιρείται.\n\n"
		+ "Θα σβηστούν από τον server: το προφίλ σου, το αποθηκευμένο παιχνίδι στο "
		+ "cloud, οι φίλοι, η συμμετοχή σε συντεχνία και ΟΛΑ τα μηνύματά σου. "
		+ "Η τοπική πρόοδος θα μηδενιστεί και θα ξεκινήσεις από την αρχή.")
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warn.add_theme_color_override("font_color", C_PARCH)
	warn.add_theme_font_size_override("font_size", 24)
	vb.add_child(warn)

	var prompt := Label.new()
	prompt.text = "Για επιβεβαίωση, πληκτρολόγησε το όνομά σου:"
	prompt.add_theme_color_override("font_color", C_MUTED)
	prompt.add_theme_font_size_override("font_size", 22)
	vb.add_child(prompt)

	_delete_input = LineEdit.new()
	_delete_input.placeholder_text = "username"
	_delete_input.custom_minimum_size = Vector2(0, 64)
	_delete_input.add_theme_font_size_override("font_size", 28)
	_delete_input.text_changed.connect(func(_t): _refresh_delete_btn())
	vb.add_child(_delete_input)

	_delete_status = Label.new()
	_delete_status.text = ""
	_delete_status.add_theme_color_override("font_color", C_ERR)
	_delete_status.add_theme_font_size_override("font_size", 22)
	_delete_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_delete_status)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vb.add_child(btn_row)

	var cancel := Button.new()
	cancel.text = "Άκυρο"
	cancel.custom_minimum_size = Vector2(160, 64)
	cancel.add_theme_font_size_override("font_size", 26)
	cancel.pressed.connect(_close_delete_overlay)
	btn_row.add_child(cancel)

	_delete_confirm_btn = Button.new()
	_delete_confirm_btn.text = "Διαγραφή οριστικά"
	_delete_confirm_btn.custom_minimum_size = Vector2(260, 64)
	_delete_confirm_btn.add_theme_font_size_override("font_size", 26)
	_delete_confirm_btn.add_theme_color_override("font_color", C_ERR)
	_delete_confirm_btn.disabled = true
	_delete_confirm_btn.pressed.connect(_on_delete_confirmed)
	btn_row.add_child(_delete_confirm_btn)


func _open_delete_overlay() -> void:
	if not Net.is_logged_in():
		return
	_delete_input.text = ""
	_delete_status.text = ""
	_deleting = false
	_refresh_delete_btn()
	_delete_overlay.visible = true
	_delete_input.grab_focus()

func _close_delete_overlay() -> void:
	if _deleting:
		return
	_delete_overlay.visible = false

## Το κουμπί διαγραφής ενεργοποιείται μόνο όταν το κείμενο ταιριάζει με το username
## (case-insensitive) — «γραφειοκρατικό» φρένο ενάντια σε κατά λάθος διαγραφή.
func _refresh_delete_btn() -> void:
	var typed := _delete_input.text.strip_edges().to_lower()
	_delete_confirm_btn.disabled = _deleting or typed == "" or typed != _username.to_lower()

func _on_delete_confirmed() -> void:
	if _deleting or not Net.is_logged_in():
		return
	_deleting = true
	_delete_confirm_btn.disabled = true
	_delete_status.add_theme_color_override("font_color", C_MUTED)
	_delete_status.text = "Διαγραφή…"
	var res := await Net.delete_account()
	# Επιτυχία: το Net.delete_account() κάνει logout+reset και αλλάζει scene — αυτό το
	# popup παύει να υπάρχει, οπότε δεν χρειάζεται άλλη ενέργεια εδώ.
	if not res["ok"]:
		_deleting = false
		_delete_status.add_theme_color_override("font_color", C_ERR)
		_delete_status.text = "Η διαγραφή απέτυχε. Έλεγξε τη σύνδεση και δοκίμασε ξανά."
		_refresh_delete_btn()


func _make_tab(text: String, id: String, icon_path: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 72)
	b.add_theme_font_size_override("font_size", 30)
	if icon_path != "" and ResourceLoader.exists(icon_path):
		b.icon = load(icon_path)
		b.expand_icon = true
	b.pressed.connect(func(): _select_tab(id))
	return b

func _select_tab(id: String) -> void:
	_tab = id
	_refresh()

## Ενημερώνει το κείμενο/χρώμα του κουμπιού λογαριασμού βάσει κατάστασης Net.
func _refresh_account_btn() -> void:
	if not is_instance_valid(_account_btn):
		return
	if Net.is_logged_in():
		_account_btn.icon = null
		_account_btn.text = "🚪  Αποσύνδεση"
		_account_btn.add_theme_color_override("font_color", C_MUTED)
	else:
		if ResourceLoader.exists(KEY_ICON_PATH):
			_account_btn.icon = load(KEY_ICON_PATH)
			_account_btn.expand_icon = true
			_account_btn.text = "Σύνδεση"
		else:
			_account_btn.icon = null
			_account_btn.text = "🔑  Σύνδεση"
		_account_btn.add_theme_color_override("font_color", C_GOLD)

func _on_account_pressed() -> void:
	if Net.is_logged_in():
		Net.logout()   # το auth_changed(false) θα ενημερώσει το UI
	else:
		login_requested.emit()
		close_popup()

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
	_list.add_child(_stat_row("chapter", "Κεφάλαιο", str(p["region_label"])))
	_list.add_child(_stat_row("streak", "Σερί (streak)", "%d ημέρες" % int(p["streak"])))
	_list.add_child(_stat_row("team_power", "Ισχύς Ομάδας", "%.1f / 20" % float(p["party_power"])))
	_list.add_child(_stat_row("characters", "Ήρωες", str(int(p["roster_size"]))))
	_list.add_child(_stat_row("weapons", "Εξοπλισμός", str(int(p["gear_owned"]))))
	_list.add_child(_stat_row("achievements", "Επιτεύγματα",
		"%d / %d" % [int(p["achievements_count"]), int(p["achievements_total"])]))

	_list.add_child(_section_label("— Κατακτήσεις —"))
	_list.add_child(_bool_row("goblin", "Ζούμπας ο Καλικάντζαρος", bool(p["goblin_defeated"])))
	_list.add_child(_bool_row("tree", "Στοιχειωμένο Δέντρο", bool(p["tree_defeated"])))
	_list.add_child(_bool_row("witch", "Μόργκανα η Μάγισσα", bool(p["morgana_defeated"])))

	# GDPR (Φάση 8): σημείωση απορρήτου + διαγραφή λογαριασμού — μόνο αν είσαι συνδεδεμένος.
	if Net.is_logged_in():
		_list.add_child(_section_label("— Απόρρητο & Λογαριασμός —"))
		var note := Label.new()
		note.text = ("Αποθηκεύουμε μόνο το όνομά σου, την πρόοδο του παιχνιδιού και τα "
			+ "μηνύματά σου — ΚΑΝΕΝΑ email. Μπορείς να διαγράψεις τα πάντα όποτε θέλεις.")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_color_override("font_color", C_MUTED)
		note.add_theme_font_size_override("font_size", 20)
		_list.add_child(note)

		var del_btn := Button.new()
		del_btn.text = "🗑  Διαγραφή λογαριασμού"
		del_btn.custom_minimum_size = Vector2(0, 66)
		del_btn.add_theme_font_size_override("font_size", 26)
		del_btn.add_theme_color_override("font_color", C_ERR)
		del_btn.pressed.connect(_open_delete_overlay)
		_list.add_child(del_btn)

func _populate_achievements() -> void:
	for a in Achievements.get_all():
		_list.add_child(_ach_row(a))


# ═══════════════════════════════════════════════════════════════════════════
# ΓΡΑΜΜΕΣ / ΒΟΗΘΗΤΙΚΑ
# ═══════════════════════════════════════════════════════════════════════════
## `icon_key`: κλειδί στο PlayerProfile.STAT_TEXTURE_ICONS/STAT_EMOJI_ICONS
## (π.χ. "chapter", "streak") — δείχνει την ΠΡΑΓΜΑΤΙΚΗ εικόνα αν υπάρχει το
## αρχείο, αλλιώς πέφτει πίσω στο emoji.
func _stat_row(icon_key: String, label: String, value: String, value_color: Color = C_GOLD) -> Control:
	var card := _row_card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var icon_tex := PlayerProfile.get_stat_icon_texture(icon_key)
	if icon_tex:
		var ic := TextureRect.new()
		ic.texture = icon_tex
		# EXPAND_IGNORE_SIZE ΠΡΙΝ το custom_minimum_size — ίδια παγίδα με
		# παντού αλλού (Currency/Heroes εικονίδια): αλλιώς το minimum size
		# της υφής κλειδώνει το πλαίσιο στο φυσικό μέγεθος.
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(40, 40)
		row.add_child(ic)
	else:
		var ic := Label.new()
		ic.text = str(PlayerProfile.STAT_EMOJI_ICONS.get(icon_key, "•"))
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

func _bool_row(icon_key: String, label: String, done: bool) -> Control:
	return _stat_row(icon_key, label, "Νικήθηκε ✓" if done else "Εκκρεμεί", C_OK if done else C_MUTED)

func _ach_row(a: Dictionary) -> Control:
	var unlocked: bool = bool(a.get("unlocked", false))
	var card := _row_card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	if not unlocked and ResourceLoader.exists(LOCK_ICON_PATH):
		var lock_icon := TextureRect.new()
		lock_icon.texture = load(LOCK_ICON_PATH)
		lock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock_icon.custom_minimum_size = Vector2(58, 0)
		row.add_child(lock_icon)
	else:
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
