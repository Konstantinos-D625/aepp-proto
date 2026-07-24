extends Control

# ═══════════════════════════════════════════════════════════════════════════
# ClansPopup — συντεχνίες (Φάση 6 του online πλάνου)
# ═══════════════════════════════════════════════════════════════════════════
# Καθαρό UI πάνω από το Net autoload. Το κουμπί HUD/Sidebar/Buttons/Clan το
# ανοίγει. Σε αντίθεση με το FriendsPopup (σταθερές καρτέλες), εδώ η όψη οδηγείται
# από την ΚΑΤΑΣΤΑΣΗ ΣΥΜΜΕΤΟΧΗΣ του παίκτη (ένα clan ανά παίκτη):
#   • χωρίς σύνδεση        → gate «Σύνδεση» (όπως στο FriendsPopup).
#   • χωρίς clan           → πλαίσια «Δημιουργία» + «Αναζήτηση/περιήγηση» για ένταξη.
#   • εκκρεμές αίτημα       → πλαίσιο «το αίτημά σου εκκρεμεί» + ακύρωση.
#   • μέλος                 → κάρτα συντεχνίας + πλαίσιο μελών (πρόοδος) + αποχώρηση.
#   • αρχηγός               → τα παραπάνω + πλαίσιο εκκρεμών αιτημάτων (✓/✗), kick, διάλυση.
#
# ΕΜΦΑΝΙΣΗ (mobile game): κάθε ενότητα ζει μέσα σε ΠΛΑΙΣΙΟ (group panel — σκούρο
# φόντο, χρυσό περίγραμμα, τίτλος+διαχωριστικό), τα inputs/κουμπιά έχουν fantasy
# iron/gold στυλ (ίδιο ύφος με το ShopPopup) — αντί για «πεταμένα μαζί» κείμενα.
# Οι βοηθητικές _group/_styled_edit/_make_button/_row_card ορίζουν αυτό το ύφος
# σε ΕΝΑ σημείο, ώστε όλες οι όψεις να μένουν συνεπείς.
#
# Async populate με guard (_refresh_id) ενάντια σε επικαλυπτόμενα refresh.

## Ο παίκτης θέλει να συνδεθεί — το AuthPopup ανοίγει την οθόνη λογαριασμού.
signal login_requested
## Ο παίκτης θέλει τους Φίλους — το FriendsPopup ανοίγει (cross-link).
signal friends_requested
## Ο παίκτης θέλει τη συνομιλία της συντεχνίας — το ChatPopup ανοίγει (Φ7).
signal clan_chat_requested(clan_id: String, clan_name: String)

# ── Παλέτα (ίδια βάση με friends_popup / profile_popup / auth_popup) ──────────
const C_PARCH := Color("f3e6c4")
const C_MUTED := Color("cdbf9a")
const C_GOLD  := Color("f2c84b")
const C_GOLD_D:= Color(0.360, 0.278, 0.058)
const C_OK    := Color(0.560, 0.900, 0.460)
const C_ERR   := Color(0.92, 0.45, 0.42)
# ── Χρώματα βάθους/πλαισίων (νέα, για το framed look) ────────────────────────
const C_PANEL   := Color(0.125, 0.120, 0.165, 0.98)   # φόντο πλαισίου ομάδας
const C_CARD    := Color(0.185, 0.175, 0.225, 0.98)   # κάρτα γραμμής (μέσα στο πλαίσιο)
const C_IRON    := Color(0.175, 0.150, 0.120, 0.99)   # κουμπί (normal)
const C_IRON_H  := Color(0.245, 0.210, 0.165, 1.0)    # κουμπί (hover)
const C_INPUT   := Color(0.045, 0.045, 0.075, 0.98)   # φόντο LineEdit

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
	card.offset_left = -525.0; card.offset_top = -850.0
	card.offset_right = 525.0; card.offset_bottom = 850.0
	card.clip_contents = true
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.08, 0.08, 0.12, 0.98)
	csb.set_corner_radius_all(20)
	csb.set_border_width_all(3)
	csb.border_color = C_GOLD_D
	card.add_theme_stylebox_override("panel", csb)
	add_child(card)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 170)
	margin.add_theme_constant_override("margin_bottom", 60)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 26)
	margin.add_child(vbox)

	# ── Τίτλος + χρυσό διαχωριστικό ──
	var title := Label.new()
	title.text = "🛡  Συντεχνία"
	title.add_theme_color_override("font_color", C_GOLD)
	title.add_theme_font_size_override("font_size", 84)
	vbox.add_child(title)
	vbox.add_child(_divider(C_GOLD_D, 4))

	# ── Scrollable περιεχόμενο (γεμίζει δυναμικά ανά κατάσταση) ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 26)
	scroll.add_child(_list)

	# ── «Φίλοι» (πάνω-δεξιά, αριστερά του X) → ανοίγει το FriendsPopup (cross-link) ──
	var friends_btn := Button.new()
	friends_btn.text = "👥  Φίλοι"
	friends_btn.anchor_left = 1.0; friends_btn.anchor_right = 1.0
	friends_btn.offset_left = -600.0; friends_btn.offset_top = 24.0
	friends_btn.offset_right = -170.0; friends_btn.offset_bottom = 154.0
	friends_btn.add_theme_font_size_override("font_size", 46)
	friends_btn.add_theme_color_override("font_color", C_GOLD)
	friends_btn.pressed.connect(func():
		friends_requested.emit()
		close_popup())
	card.add_child(friends_btn)

	# ── X (πάνω-δεξιά) ──
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.anchor_left = 1.0; close_btn.anchor_right = 1.0
	close_btn.offset_left = -150.0; close_btn.offset_top = 24.0
	close_btn.offset_right = -20.0; close_btn.offset_bottom = 154.0
	close_btn.add_theme_font_size_override("font_size", 72)
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
	# ── Πλαίσιο: Δημιουργία συντεχνίας ──
	var create := _group("➕  Δημιούργησε συντεχνία")

	var name_edit := _styled_edit("όνομα συντεχνίας (3-24)…", 24)
	create.add_child(name_edit)

	var desc_edit := _styled_edit("περιγραφή (προαιρετικό)…", 120)
	create.add_child(desc_edit)

	var create_status := _hint("")
	create_status.visible = false

	var create_btn := _make_button("➕  Δημιουργία", "gold")
	create_btn.pressed.connect(func(): _on_create(name_edit, desc_edit, create_btn, create_status))
	create.add_child(create_btn)
	create.add_child(create_status)

	# ── Πλαίσιο: Βρες συντεχνία (αναζήτηση + αποτελέσματα) ──
	var search := _group("🔍  Βρες συντεχνία")

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	search.add_child(bar)

	var search_edit := _styled_edit("όνομα συντεχνίας…", 24)
	search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(search_edit)

	var go := _make_button("🔍", "iron")
	go.custom_minimum_size = Vector2(150, 104)
	bar.add_child(go)

	# Δοχείο αποτελεσμάτων (ξεχωριστό ώστε να μη σβήνει η φόρμα σε κάθε αναζήτηση).
	var results := VBoxContainer.new()
	results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results.add_theme_constant_override("separation", 20)
	search.add_child(results)

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
	var g := _group("⏳  Εκκρεμές αίτημα")
	g.add_child(_hint("Το αίτημά σου στη συντεχνία «%s» εκκρεμεί έγκριση από τον αρχηγό."
		% str(m.get("clan_name", ""))))
	var cancel := _make_button("✖  Ακύρωση αιτήματος", "danger")
	cancel.pressed.connect(func(): _on_leave(str(m.get("id", ""))))
	g.add_child(cancel)


# ═══════════════════════════════════════════════════════════════════════════
# ΟΨΗ: Η ΣΥΝΤΕΧΝΙΑ ΜΟΥ (μέλος / αρχηγός)
# ═══════════════════════════════════════════════════════════════════════════
func _show_my_clan(m: Dictionary, my_id: int) -> void:
	var clan_id := str(m.get("clan", ""))
	var am_leader := str(m.get("role", "")) == "leader"

	# ── Κάρτα ταυτότητας συντεχνίας (ασπίδα + όνομα + περιγραφή) ──
	var head_card := PanelContainer.new()
	head_card.add_theme_stylebox_override("panel", _panel_sb())
	_list.add_child(head_card)

	var head_col := VBoxContainer.new()
	head_col.add_theme_constant_override("separation", 14)
	head_card.add_child(head_col)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 18)
	head_col.add_child(name_row)

	var shield := Label.new()
	shield.text = "🛡"
	shield.add_theme_font_size_override("font_size", 68)
	shield.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(shield)

	var name_l := Label.new()
	name_l.text = str(m.get("clan_name", ""))
	name_l.add_theme_color_override("font_color", C_GOLD)
	name_l.add_theme_font_size_override("font_size", 60)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_row.add_child(name_l)

	if am_leader:
		var badge := Label.new()
		badge.text = "👑 Αρχηγός"
		badge.add_theme_color_override("font_color", C_GOLD)
		badge.add_theme_font_size_override("font_size", 34)
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_row.add_child(badge)

	head_col.add_child(_divider(C_GOLD_D, 2))

	var desc := Label.new()
	desc.name = "ClanDesc"
	desc.text = "…"
	desc.add_theme_color_override("font_color", C_MUTED)
	desc.add_theme_font_size_override("font_size", 40)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head_col.add_child(desc)
	_fill_clan_desc(desc, clan_id, my_id)

	# ── Συνομιλία συντεχνίας (Φ7) ──
	var chat_btn := _make_button("💬  Συνομιλία συντεχνίας", "gold")
	chat_btn.pressed.connect(func():
		clan_chat_requested.emit(clan_id, str(m.get("clan_name", "")))
		close_popup())
	_list.add_child(chat_btn)

	# ── Μέλη + εκκρεμή αιτήματα (φόρτωση async) ──
	var loading := _hint("Φόρτωση μελών…")
	_list.add_child(loading)
	var res := await Net.clan_members(clan_id)
	if my_id != _refresh_id:
		return
	if is_instance_valid(loading):
		loading.queue_free()
	if not res["ok"]:
		_list.add_child(_hint("Δεν ήταν δυνατή η φόρτωση των μελών."))
		return

	var items: Array = res["data"].get("items", [])
	var members := items.filter(func(r): return str(r.get("status", "")) == "member")
	var pending := items.filter(func(r): return str(r.get("status", "")) == "pending")

	# Αρχηγός: πλαίσιο εκκρεμών αιτημάτων ένταξης πρώτα (ενέργεια που θέλει προσοχή).
	if am_leader and not pending.is_empty():
		var req := _group("✉  Αιτήματα ένταξης")
		for rec in pending:
			req.add_child(_request_row(str(rec.get("username", "")), str(rec.get("id", ""))))

	# Πλαίσιο μελών (roster + η πρόοδός τους).
	var mem := _group("👥  Μέλη (%d)" % members.size())
	var me := Net.get_user_id()
	for rec in members:
		var uid := str(rec.get("user", ""))
		var row := _member_row(rec, am_leader and uid != me)
		mem.add_child(row)
		_fill_member_progress(row, uid, my_id)

	# ── Ενέργεια στο τέλος: αρχηγός → διάλυση, μέλος → αποχώρηση ──
	if am_leader:
		var disband := _make_button("💥  Διάλυση συντεχνίας", "danger")
		disband.pressed.connect(func(): _on_disband(clan_id))
		_list.add_child(disband)
	else:
		var leave := _make_button("🚪  Αποχώρηση", "danger")
		leave.pressed.connect(func(): _on_leave(str(m.get("id", ""))))
		_list.add_child(leave)


# ═══════════════════════════════════════════════════════════════════════════
# ΓΡΑΜΜΕΣ (κάρτες μέσα στα πλαίσια)
# ═══════════════════════════════════════════════════════════════════════════
func _clan_result_row(rec: Dictionary) -> PanelContainer:
	var clan_id := str(rec.get("id", ""))
	var cname := str(rec.get("name", ""))
	var card := _row_card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	card.add_child(row)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)

	# clip_text + ellipsis: clan/owner names are arbitrary-length — without a cap
	# a long one balloons `col`'s minimum width, which (ScrollContainer has
	# horizontal scroll disabled) forces the whole list wider than the card and
	# pushes the join button (and every other row's trailing controls) off-screen.
	var name_l := Label.new()
	name_l.text = cname
	name_l.add_theme_color_override("font_color", C_GOLD)
	name_l.add_theme_font_size_override("font_size", 50)
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name_l)

	var sub := Label.new()
	sub.name = "Sub"
	sub.text = "👑 %s   👥 …" % str(rec.get("owner_name", "—"))
	sub.add_theme_color_override("font_color", C_MUTED)
	sub.add_theme_font_size_override("font_size", 38)
	sub.clip_text = true
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(sub)

	var join := _make_button("Αίτημα", "iron")
	join.custom_minimum_size = Vector2(240, 112)
	join.add_theme_font_size_override("font_size", 42)
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
	row.add_theme_constant_override("separation", 24)
	card.add_child(row)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)

	var is_leader := str(rec.get("role", "")) == "leader"
	var name_l := Label.new()
	name_l.text = ("👑 " if is_leader else "") + str(rec.get("username", ""))
	name_l.add_theme_color_override("font_color", C_GOLD if is_leader else C_PARCH)
	name_l.add_theme_font_size_override("font_size", 50)
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name_l)

	var prog := Label.new()
	prog.name = "Progress"
	prog.text = "…"
	prog.add_theme_color_override("font_color", C_MUTED)
	prog.add_theme_font_size_override("font_size", 38)
	prog.clip_text = true
	prog.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(prog)

	if can_kick:
		var kick := _make_button("❌", "danger")
		kick.custom_minimum_size = Vector2(120, 108)
		kick.add_theme_font_size_override("font_size", 46)
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
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	var name_l := Label.new()
	name_l.text = uname
	name_l.add_theme_color_override("font_color", C_PARCH)
	name_l.add_theme_font_size_override("font_size", 50)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_l)

	var accept := _make_button("✓", "gold")
	accept.custom_minimum_size = Vector2(120, 108)
	accept.add_theme_font_size_override("font_size", 54)
	accept.add_theme_color_override("font_color", C_OK)
	accept.pressed.connect(func(): _on_respond(id, true))
	row.add_child(accept)

	var decline := _make_button("✗", "danger")
	decline.custom_minimum_size = Vector2(120, 108)
	decline.add_theme_font_size_override("font_size", 54)
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
	var g := _group("🔒  Συντεχνίες")
	g.add_child(_hint("Χρειάζεσαι λογαριασμό για να φτιάξεις ή να μπεις σε συντεχνία και να ανταγωνιστείς με άλλους παίκτες."))
	var btn := _make_button("🔑  Σύνδεση", "gold")
	btn.pressed.connect(func():
		login_requested.emit()
		close_popup())
	g.add_child(btn)


# ═══════════════════════════════════════════════════════════════════════════
# ΒΟΗΘΗΤΙΚΑ ΕΜΦΑΝΙΣΗΣ (το «ύφος» σε ΕΝΑ σημείο)
# ═══════════════════════════════════════════════════════════════════════════

## Ένα «πλαίσιο ομάδας»: σκούρο PanelContainer με χρυσό περίγραμμα, τίτλο (χρυσό)
## και διαχωριστικό — προστίθεται ΑΜΕΣΩΣ στο _list. Επιστρέφει το εσωτερικό VBox
## ώστε ο caller να βάλει εκεί το περιεχόμενο (inputs/κουμπιά/γραμμές).
func _group(title_text: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_sb())
	_list.add_child(panel)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 18)
	panel.add_child(inner)

	var hdr := Label.new()
	hdr.text = title_text
	hdr.add_theme_color_override("font_color", C_GOLD)
	hdr.add_theme_font_size_override("font_size", 46)
	inner.add_child(hdr)
	inner.add_child(_divider(C_GOLD_D, 3))
	return inner

## StyleBox για τα πλαίσια ομάδας / την κάρτα ταυτότητας συντεχνίας.
func _panel_sb() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_PANEL
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(3)
	sb.border_color = C_GOLD_D
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 26
	sb.content_margin_bottom = 30
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 6
	return sb

## Λεπτή οριζόντια γραμμή-διαχωριστικό (αντί για default HSeparator, που είναι
## αχνό στο σκούρο φόντο). Σε VBox απλώνεται σε όλο το πλάτος.
func _divider(col: Color, h: int = 3) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.custom_minimum_size = Vector2(0, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## LineEdit με ύφος του παιχνιδιού (σκούρο φόντο, χρυσό-σκούρο περίγραμμα που
## γίνεται χρυσό στο focus, παραγέμισμα, μεγάλη γραμματοσειρά για κινητό).
func _styled_edit(placeholder: String, max_len: int) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.max_length = max_len
	e.custom_minimum_size = Vector2(0, 104)
	e.add_theme_font_size_override("font_size", 42)
	var n := StyleBoxFlat.new()
	n.bg_color = C_INPUT
	n.set_corner_radius_all(12)
	n.set_border_width_all(2)
	n.border_color = C_GOLD_D
	n.content_margin_left = 22
	n.content_margin_right = 22
	e.add_theme_stylebox_override("normal", n)
	var f := n.duplicate()
	f.border_color = C_GOLD
	e.add_theme_stylebox_override("focus", f)
	e.add_theme_color_override("font_color", C_PARCH)
	e.add_theme_color_override("font_placeholder_color", C_MUTED.darkened(0.25))
	e.add_theme_color_override("caret_color", C_GOLD)
	return e

## Κουμπί με fantasy iron/gold ύφος (ίδια φιλοσοφία με ShopPopup._style_iron).
## kind: "gold" (πρωτεύον/θετικό), "danger" (κόκκινο), "iron" (ουδέτερο).
func _make_button(text: String, kind: String = "iron") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 124)
	b.add_theme_font_size_override("font_size", 48)

	var accent := C_GOLD
	var fcol := C_PARCH
	if kind == "gold":
		accent = C_GOLD; fcol = C_GOLD
	elif kind == "danger":
		accent = C_ERR; fcol = C_ERR

	var n := StyleBoxFlat.new()
	n.bg_color = C_IRON
	n.set_corner_radius_all(14)
	n.set_border_width_all(3)
	n.border_color = accent.darkened(0.35)
	n.content_margin_left = 20; n.content_margin_right = 20
	n.content_margin_top = 12; n.content_margin_bottom = 12
	n.shadow_color = Color(0, 0, 0, 0.5)
	n.shadow_size = 5
	b.add_theme_stylebox_override("normal", n)

	var h := n.duplicate()
	h.bg_color = C_IRON_H
	h.border_color = accent
	h.shadow_color = accent.darkened(0.2)
	h.shadow_size = 8
	b.add_theme_stylebox_override("hover", h)

	var p := n.duplicate()
	p.bg_color = Color(0.10, 0.085, 0.065, 1.0)
	b.add_theme_stylebox_override("pressed", p)

	var d := n.duplicate()
	d.bg_color = Color(0.12, 0.115, 0.11, 0.9)
	d.border_color = C_GOLD_D.darkened(0.35)
	b.add_theme_stylebox_override("disabled", d)

	var fo := StyleBoxFlat.new()
	fo.bg_color = Color(0, 0, 0, 0)
	b.add_theme_stylebox_override("focus", fo)

	b.add_theme_color_override("font_color", fcol)
	b.add_theme_color_override("font_hover_color", accent.lightened(0.18))
	b.add_theme_color_override("font_pressed_color", fcol.darkened(0.3))
	b.add_theme_color_override("font_disabled_color", C_MUTED.darkened(0.3))
	b.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	b.add_theme_constant_override("shadow_offset_x", 1)
	b.add_theme_constant_override("shadow_offset_y", 2)
	return b


# ═══════════════════════════════════════════════════════════════════════════
# ΒΟΗΘΗΤΙΚΑ (λογική)
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
	l.add_theme_font_size_override("font_size", 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

## Κάρτα γραμμής (μέσα σε πλαίσιο ομάδας): πιο ανοιχτό φόντο από το πλαίσιο ώστε
## να ξεχωρίζει, με απαλό χρυσό-σκούρο περίγραμμα.
func _row_card() -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_CARD
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = C_GOLD_D.darkened(0.1)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", sb)
	return card
