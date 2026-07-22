extends Control

# ═══════════════════════════════════════════════════════════════════════════
# ClansPopup — συντεχνίες (Φάση 6 του online πλάνου)
# ═══════════════════════════════════════════════════════════════════════════
# Καθαρό UI πάνω από το Net autoload. Το κουμπί HUD/Sidebar/Buttons/Clan το
# ανοίγει. Σε αντίθεση με το FriendsPopup (σταθερές καρτέλες), εδώ η όψη οδηγείται
# από την ΚΑΤΑΣΤΑΣΗ ΣΥΜΜΕΤΟΧΗΣ του παίκτη (ένα clan ανά παίκτη):
#   • χωρίς σύνδεση        → gate «Σύνδεση» (όπως στο FriendsPopup).
#   • χωρίς clan           → φόρμα «Δημιουργία» + «Αναζήτηση/περιήγηση» για ένταξη.
#   • εκκρεμές αίτημα       → «το αίτημά σου εκκρεμεί» + ακύρωση.
#   • μέλος                 → κεφαλίδα clan + roster (πρόοδος κάθε μέλους) + αποχώρηση.
#   • αρχηγός               → τα παραπάνω + εκκρεμή αιτήματα (✓/✗), kick, διάλυση.
#
# Η πρόοδος κάθε μέλους (κεφάλαιο/σερί) δείχνει τον ανταγωνισμό μέσα στη συντεχνία —
# ο ρητός στόχος του online πλάνου (κίνητρο). Ίδιο ύφος κάρτας/παλέτα/fade με
# ProfilePopup/AuthPopup/FriendsPopup. Async populate με guard (_refresh_id).

## Ο παίκτης θέλει να συνδεθεί — το AuthPopup ανοίγει την οθόνη λογαριασμού.
signal login_requested
## Ο παίκτης θέλει τους Φίλους — το FriendsPopup ανοίγει (cross-link).
signal friends_requested
## Ο παίκτης θέλει τη συνομιλία της συντεχνίας — το ChatPopup ανοίγει (Φ7).
signal clan_chat_requested(clan_id: String, clan_name: String)

# ── Παλέτα (ίδια με friends_popup / profile_popup / auth_popup) ───────────────
const C_PARCH := Color("f3e6c4")
const C_MUTED := Color("cdbf9a")
const C_GOLD  := Color("f2c84b")
const C_GOLD_D:= Color(0.360, 0.278, 0.058)
const C_OK    := Color(0.560, 0.900, 0.460)
const C_ERR   := Color(0.92, 0.45, 0.42)

## Αυξάνεται σε κάθε _refresh — τα async populate ελέγχουν ότι δεν ξεπεράστηκαν.
var _refresh_id := 0

var _list: VBoxContainer


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_build()
	# Αν αλλάξει η κατάσταση σύνδεσης ενώ είμαστε ανοιχτοί, ξαναφτιάξε.
	Net.auth_changed.connect(_on_auth_changed)


func open() -> void:
	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)
	_refresh()

func close_popup() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func(): visible = false)

func _on_auth_changed(_logged_in: bool) -> void:
	if visible:
		_refresh()


# ═══════════════════════════════════════════════════════════════════════════
# ΚΑΤΑΣΚΕΥΗ UI (μία φορά)
# ═══════════════════════════════════════════════════════════════════════════
func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = MOUSE_FILTER_STOP
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
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# ── Τίτλος ──
	var title := Label.new()
	title.text = "🛡  Συντεχνία"
	title.add_theme_color_override("font_color", C_GOLD)
	title.add_theme_font_size_override("font_size", 46)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# ── Scrollable περιεχόμενο (γεμίζει δυναμικά ανά κατάσταση) ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)

	# ── «Φίλοι» (πάνω-δεξιά, αριστερά του X) → ανοίγει το FriendsPopup (cross-link) ──
	var friends_btn := Button.new()
	friends_btn.text = "👥  Φίλοι"
	friends_btn.anchor_left = 1.0; friends_btn.anchor_right = 1.0
	friends_btn.offset_left = -288.0; friends_btn.offset_top = 22.0
	friends_btn.offset_right = -96.0; friends_btn.offset_bottom = 74.0
	friends_btn.add_theme_font_size_override("font_size", 24)
	friends_btn.add_theme_color_override("font_color", C_GOLD)
	friends_btn.pressed.connect(func():
		friends_requested.emit()
		close_popup())
	card.add_child(friends_btn)

	# ── X (πάνω-δεξιά) ──
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.anchor_left = 1.0; close_btn.anchor_right = 1.0
	close_btn.offset_left = -78.0; close_btn.offset_top = 16.0
	close_btn.offset_right = -18.0; close_btn.offset_bottom = 76.0
	close_btn.add_theme_font_size_override("font_size", 38)
	close_btn.pressed.connect(close_popup)
	card.add_child(close_btn)


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_popup()


# ═══════════════════════════════════════════════════════════════════════════
# ΚΕΝΤΡΙΚΗ ΔΡΟΜΟΛΟΓΗΣΗ (async — με guard ενάντια σε επικαλυπτόμενα refresh)
# ═══════════════════════════════════════════════════════════════════════════
func _refresh() -> void:
	_refresh_id += 1
	var my_id := _refresh_id
	_clear_list()

	# Gate: χωρίς λογαριασμό δεν υπάρχουν συντεχνίες.
	if not Net.is_logged_in():
		_show_login_gate()
		return

	_list.add_child(_hint("Φόρτωση…"))
	var res := await Net.my_membership()
	if my_id != _refresh_id:
		return
	_clear_list()
	if not res["ok"]:
		_list.add_child(_hint("Δεν ήταν δυνατή η σύνδεση με τον διακομιστή."))
		return

	var m: Dictionary = res["membership"]
	if m.is_empty():
		_show_no_clan()                   # χωρίς clan → δημιουργία/ένταξη
	elif str(m.get("status", "")) == "pending":
		_show_pending(m)                  # εκκρεμές αίτημα ένταξης
	else:
		_show_my_clan(m, my_id)           # μέλος/αρχηγός


# ═══════════════════════════════════════════════════════════════════════════
# ΟΨΗ: ΧΩΡΙΣ CLAN — δημιουργία + περιήγηση/αναζήτηση για ένταξη
# ═══════════════════════════════════════════════════════════════════════════
func _show_no_clan() -> void:
	# ── Δημιουργία συντεχνίας ──
	_list.add_child(_section_label("— Δημιούργησε συντεχνία —"))

	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "όνομα συντεχνίας (3-24)…"
	name_edit.custom_minimum_size = Vector2(0, 62)
	name_edit.max_length = 24
	name_edit.add_theme_font_size_override("font_size", 26)
	_list.add_child(name_edit)

	var desc_edit := LineEdit.new()
	desc_edit.placeholder_text = "περιγραφή (προαιρετικό)…"
	desc_edit.custom_minimum_size = Vector2(0, 62)
	desc_edit.max_length = 120
	desc_edit.add_theme_font_size_override("font_size", 26)
	_list.add_child(desc_edit)

	var create_status := _hint("")
	create_status.visible = false

	var create_btn := Button.new()
	create_btn.text = "➕  Δημιουργία"
	create_btn.custom_minimum_size = Vector2(0, 74)
	create_btn.add_theme_font_size_override("font_size", 28)
	create_btn.add_theme_color_override("font_color", C_GOLD)
	create_btn.pressed.connect(func(): _on_create(name_edit, desc_edit, create_btn, create_status))
	_list.add_child(create_btn)
	_list.add_child(create_status)

	_list.add_child(HSeparator.new())

	# ── Περιήγηση / αναζήτηση για ένταξη ──
	_list.add_child(_section_label("— Βρες συντεχνία —"))

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	_list.add_child(bar)

	var search_edit := LineEdit.new()
	search_edit.placeholder_text = "όνομα συντεχνίας…"
	search_edit.custom_minimum_size = Vector2(0, 62)
	search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_edit.add_theme_font_size_override("font_size", 26)
	bar.add_child(search_edit)

	var go := Button.new()
	go.text = "🔍"
	go.custom_minimum_size = Vector2(90, 62)
	go.add_theme_font_size_override("font_size", 28)
	bar.add_child(go)

	# Δοχείο αποτελεσμάτων (ξεχωριστό ώστε να μη σβήνει η φόρμα σε κάθε αναζήτηση).
	var results := VBoxContainer.new()
	results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results.add_theme_constant_override("separation", 12)
	_list.add_child(results)

	var do_search := func(): _browse_clans(search_edit.text, results)
	go.pressed.connect(do_search)
	search_edit.text_submitted.connect(func(_t): do_search.call())

	# Αρχική περιήγηση: οι πιο πρόσφατες συντεχνίες.
	_browse_clans("", results)

## Γεμίζει το δοχείο αποτελεσμάτων με συντεχνίες (search ή browse).
func _browse_clans(query: String, results: VBoxContainer) -> void:
	_refresh_id += 1
	var my_id := _refresh_id
	for c in results.get_children():
		c.queue_free()
	results.add_child(_hint("Φόρτωση…"))
	var res := await Net.search_clans(query)
	if my_id != _refresh_id or not is_instance_valid(results):
		return
	for c in results.get_children():
		c.queue_free()
	if not res["ok"]:
		results.add_child(_hint("Η αναζήτηση απέτυχε."))
		return
	var items: Array = res["data"].get("items", [])
	if items.is_empty():
		results.add_child(_hint("Καμία συντεχνία. Δημιούργησε την πρώτη!"))
		return
	for rec in items:
		var row := _clan_result_row(rec)
		results.add_child(row)
		_fill_member_count(row, str(rec.get("id", "")), my_id)


# ═══════════════════════════════════════════════════════════════════════════
# ΟΨΗ: ΕΚΚΡΕΜΕΣ ΑΙΤΗΜΑ
# ═══════════════════════════════════════════════════════════════════════════
func _show_pending(m: Dictionary) -> void:
	_list.add_child(_hint("Το αίτημά σου στη συντεχνία «%s» εκκρεμεί έγκριση από τον αρχηγό."
		% str(m.get("clan_name", ""))))
	var cancel := Button.new()
	cancel.text = "✖  Ακύρωση αιτήματος"
	cancel.custom_minimum_size = Vector2(0, 76)
	cancel.add_theme_font_size_override("font_size", 28)
	cancel.add_theme_color_override("font_color", C_ERR)
	cancel.pressed.connect(func(): _on_leave(str(m.get("id", ""))))
	_list.add_child(cancel)


# ═══════════════════════════════════════════════════════════════════════════
# ΟΨΗ: Η ΣΥΝΤΕΧΝΙΑ ΜΟΥ (μέλος / αρχηγός)
# ═══════════════════════════════════════════════════════════════════════════
func _show_my_clan(m: Dictionary, my_id: int) -> void:
	var clan_id := str(m.get("clan", ""))
	var am_leader := str(m.get("role", "")) == "leader"

	# ── Κεφαλίδα ──
	var head := Label.new()
	head.text = "🛡  %s" % str(m.get("clan_name", ""))
	head.add_theme_color_override("font_color", C_GOLD)
	head.add_theme_font_size_override("font_size", 34)
	_list.add_child(head)

	var desc := Label.new()
	desc.name = "ClanDesc"
	desc.text = ""
	desc.add_theme_color_override("font_color", C_MUTED)
	desc.add_theme_font_size_override("font_size", 24)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(desc)
	_fill_clan_desc(desc, clan_id, my_id)

	# ── Συνομιλία συντεχνίας (Φ7) ──
	var chat_btn := Button.new()
	chat_btn.text = "💬  Συνομιλία συντεχνίας"
	chat_btn.custom_minimum_size = Vector2(0, 72)
	chat_btn.add_theme_font_size_override("font_size", 27)
	chat_btn.add_theme_color_override("font_color", C_GOLD)
	chat_btn.pressed.connect(func():
		clan_chat_requested.emit(clan_id, str(m.get("clan_name", "")))
		close_popup())
	_list.add_child(chat_btn)

	_list.add_child(HSeparator.new())

	# ── Μέλη + εκκρεμή αιτήματα ──
	_list.add_child(_hint("Φόρτωση μελών…"))
	var res := await Net.clan_members(clan_id)
	if my_id != _refresh_id:
		return
	# Κράτα την κεφαλίδα (τα 3 πρώτα παιδιά: head, desc, separator)· καθάρισε το «Φόρτωση…».
	if _list.get_child_count() > 3:
		_list.get_child(_list.get_child_count() - 1).queue_free()
	if not res["ok"]:
		_list.add_child(_hint("Δεν ήταν δυνατή η φόρτωση των μελών."))
		return

	var items: Array = res["data"].get("items", [])
	var members := items.filter(func(r): return str(r.get("status", "")) == "member")
	var pending := items.filter(func(r): return str(r.get("status", "")) == "pending")

	# Αρχηγός: εκκρεμή αιτήματα ένταξης πρώτα (ενέργεια που θέλει προσοχή).
	if am_leader and not pending.is_empty():
		_list.add_child(_section_label("— Αιτήματα ένταξης —"))
		for rec in pending:
			_list.add_child(_request_row(str(rec.get("username", "")), str(rec.get("id", ""))))

	# Roster (τα μέλη + η πρόοδός τους).
	_list.add_child(_section_label("— Μέλη (%d) —" % members.size()))
	var me := Net.get_user_id()
	for rec in members:
		var uid := str(rec.get("user", ""))
		var row := _member_row(rec, am_leader and uid != me)
		_list.add_child(row)
		_fill_member_progress(row, uid, my_id)

	_list.add_child(HSeparator.new())

	# ── Ενέργεια στο τέλος: αρχηγός → διάλυση, μέλος → αποχώρηση ──
	if am_leader:
		var disband := Button.new()
		disband.text = "💥  Διάλυση συντεχνίας"
		disband.custom_minimum_size = Vector2(0, 76)
		disband.add_theme_font_size_override("font_size", 28)
		disband.add_theme_color_override("font_color", C_ERR)
		disband.pressed.connect(func(): _on_disband(clan_id))
		_list.add_child(disband)
	else:
		var leave := Button.new()
		leave.text = "🚪  Αποχώρηση"
		leave.custom_minimum_size = Vector2(0, 76)
		leave.add_theme_font_size_override("font_size", 28)
		leave.add_theme_color_override("font_color", C_ERR)
		leave.pressed.connect(func(): _on_leave(str(m.get("id", ""))))
		_list.add_child(leave)


# ═══════════════════════════════════════════════════════════════════════════
# ΓΡΑΜΜΕΣ
# ═══════════════════════════════════════════════════════════════════════════
func _clan_result_row(rec: Dictionary) -> PanelContainer:
	var clan_id := str(rec.get("id", ""))
	var cname := str(rec.get("name", ""))
	var card := _row_card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	var name_l := Label.new()
	name_l.text = cname
	name_l.add_theme_color_override("font_color", C_GOLD)
	name_l.add_theme_font_size_override("font_size", 28)
	col.add_child(name_l)

	var sub := Label.new()
	sub.name = "Sub"
	sub.text = "👑 %s   👥 …" % str(rec.get("owner_name", "—"))
	sub.add_theme_color_override("font_color", C_MUTED)
	sub.add_theme_font_size_override("font_size", 22)
	col.add_child(sub)

	var join := Button.new()
	join.text = "Αίτημα"
	join.custom_minimum_size = Vector2(150, 64)
	join.add_theme_font_size_override("font_size", 24)
	join.pressed.connect(func(): _on_request_join(clan_id, cname, join))
	row.add_child(join)
	return card

## Συμπληρώνει τον αριθμό μελών μιας συντεχνίας ασύγχρονα (δεν μπλοκάρει τη λίστα).
func _fill_member_count(row: PanelContainer, clan_id: String, my_id: int) -> void:
	var res := await Net.clan_members(clan_id)
	if my_id != _refresh_id or not is_instance_valid(row):
		return
	var sub: Label = row.find_child("Sub", true, false)
	if sub == null:
		return
	var count := 0
	if res["ok"]:
		for r in res["data"].get("items", []):
			if str(r.get("status", "")) == "member":
				count += 1
	var owner := sub.text.split("   ")[0]
	sub.text = "%s   👥 %d" % [owner, count]

func _member_row(rec: Dictionary, can_kick: bool) -> PanelContainer:
	var card := _row_card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	var is_leader := str(rec.get("role", "")) == "leader"
	var name_l := Label.new()
	name_l.text = ("👑 " if is_leader else "") + str(rec.get("username", ""))
	name_l.add_theme_color_override("font_color", C_GOLD if is_leader else C_PARCH)
	name_l.add_theme_font_size_override("font_size", 28)
	col.add_child(name_l)

	var prog := Label.new()
	prog.name = "Progress"
	prog.text = "…"
	prog.add_theme_color_override("font_color", C_MUTED)
	prog.add_theme_font_size_override("font_size", 22)
	col.add_child(prog)

	if can_kick:
		var kick := Button.new()
		kick.text = "❌"
		kick.custom_minimum_size = Vector2(70, 64)
		kick.add_theme_font_size_override("font_size", 26)
		kick.pressed.connect(func(): _on_leave(str(rec.get("id", ""))))
		row.add_child(kick)
	return card

func _fill_member_progress(row: PanelContainer, uid: String, my_id: int) -> void:
	var res := await Net.fetch_profile(uid)
	if my_id != _refresh_id or not is_instance_valid(row):
		return
	var prog: Label = row.find_child("Progress", true, false)
	if prog == null:
		return
	if res["ok"]:
		var items: Array = res["data"].get("items", [])
		if not items.is_empty():
			var p: Dictionary = items[0]
			prog.text = "🗺 %s   🔥 %d" % [str(p.get("region_label", "—")), int(p.get("streak", 0))]
			return
	prog.text = "—"

func _request_row(uname: String, id: String) -> PanelContainer:
	var card := _row_card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var name_l := Label.new()
	name_l.text = uname
	name_l.add_theme_color_override("font_color", C_PARCH)
	name_l.add_theme_font_size_override("font_size", 28)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)

	var accept := Button.new()
	accept.text = "✓"
	accept.custom_minimum_size = Vector2(70, 64)
	accept.add_theme_font_size_override("font_size", 30)
	accept.add_theme_color_override("font_color", C_OK)
	accept.pressed.connect(func(): _on_respond(id, true))
	row.add_child(accept)

	var decline := Button.new()
	decline.text = "✗"
	decline.custom_minimum_size = Vector2(70, 64)
	decline.add_theme_font_size_override("font_size", 30)
	decline.add_theme_color_override("font_color", C_ERR)
	decline.pressed.connect(func(): _on_respond(id, false))
	row.add_child(decline)
	return card

## Γεμίζει την περιγραφή της συντεχνίας μου (fetch_clan) ασύγχρονα.
func _fill_clan_desc(desc: Label, clan_id: String, my_id: int) -> void:
	var res := await Net.fetch_clan(clan_id)
	if my_id != _refresh_id or not is_instance_valid(desc):
		return
	if res["ok"]:
		var d := str(res["data"].get("description", ""))
		desc.text = d if d != "" else "—"


# ═══════════════════════════════════════════════════════════════════════════
# ΕΝΕΡΓΕΙΕΣ
# ═══════════════════════════════════════════════════════════════════════════
func _on_create(name_edit: LineEdit, desc_edit: LineEdit, btn: Button, status: Label) -> void:
	var cname := name_edit.text.strip_edges()
	if cname.length() < 3:
		status.text = "Το όνομα χρειάζεται τουλάχιστον 3 χαρακτήρες."
		status.add_theme_color_override("font_color", C_ERR)
		status.visible = true
		return
	btn.disabled = true
	btn.text = "…"
	var res := await Net.create_clan(cname, desc_edit.text.strip_edges())
	if not is_instance_valid(self):
		return
	if res["ok"]:
		_refresh()   # τώρα είμαι αρχηγός → δείξε τη συντεχνία μου
	else:
		btn.disabled = false
		btn.text = "➕  Δημιουργία"
		status.text = _clan_error(res["error"])
		status.add_theme_color_override("font_color", C_ERR)
		status.visible = true

func _on_request_join(clan_id: String, clan_name: String, btn: Button) -> void:
	btn.disabled = true
	btn.text = "…"
	var res := await Net.request_join_clan(clan_id, clan_name)
	if not is_instance_valid(btn):
		return
	if res["ok"]:
		# Έχω πλέον εκκρεμές αίτημα → ξαναφόρτωσε στην όψη «εκκρεμές».
		_refresh()
	else:
		btn.disabled = false
		btn.text = "Αίτημα"

func _on_respond(id: String, accept: bool) -> void:
	await Net.respond_join_request(id, accept)
	_refresh()

func _on_leave(id: String) -> void:
	await Net.leave_clan(id)
	_refresh()

func _on_disband(clan_id: String) -> void:
	await Net.disband_clan(clan_id)
	_refresh()


# ═══════════════════════════════════════════════════════════════════════════
# GATE (χωρίς λογαριασμό)
# ═══════════════════════════════════════════════════════════════════════════
func _show_login_gate() -> void:
	_list.add_child(_hint("Χρειάζεσαι λογαριασμό για να φτιάξεις ή να μπεις σε συντεχνία και να ανταγωνιστείς με άλλους παίκτες."))
	var btn := Button.new()
	btn.text = "🔑  Σύνδεση"
	btn.custom_minimum_size = Vector2(0, 80)
	btn.add_theme_font_size_override("font_size", 30)
	btn.add_theme_color_override("font_color", C_GOLD)
	btn.pressed.connect(func():
		login_requested.emit()
		close_popup())
	_list.add_child(btn)


# ═══════════════════════════════════════════════════════════════════════════
# ΒΟΗΘΗΤΙΚΑ
# ═══════════════════════════════════════════════════════════════════════════
func _clear_list() -> void:
	for c in _list.get_children():
		c.queue_free()

## Μεταφράζει συχνά σφάλματα server σε φιλικά ελληνικά (π.χ. διπλό όνομα).
func _clan_error(err: String) -> String:
	var e := err.to_lower()
	if e.contains("unique") or e.contains("valid") or e.contains("already"):
		return "Αυτό το όνομα υπάρχει ήδη. Δοκίμασε άλλο."
	return "Δεν ήταν δυνατή η δημιουργία. Δοκίμασε ξανά."

func _hint(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", C_MUTED)
	l.add_theme_font_size_override("font_size", 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", C_MUTED)
	l.add_theme_font_size_override("font_size", 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

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
