extends Control

# ═══════════════════════════════════════════════════════════════════════════
# FriendsPopup — φίλοι & αιτήματα (Φάση 5 του online πλάνου)
# ═══════════════════════════════════════════════════════════════════════════
# Καθαρό UI πάνω από το Net autoload. Το κουμπί HUD/Sidebar/Buttons/Friends το
# ανοίγει. Τρεις καρτέλες:
#   • «Φίλοι»       — εγώ + οι αποδεκτές φιλίες μου σε ΜΙΑ κατάταξη (leaderboard),
#                     ταξινομημένη κατά ισχύ ομάδας (party_power)· κουμπί αφαίρεσης.
#   • «Αιτήματα»    — εισερχόμενα (Αποδοχή/Απόρριψη) + εξερχόμενα εκκρεμή (Ακύρωση).
#   • «Αναζήτηση»   — βρες παίκτη με username → «Πρόσθεσε» (στέλνει αίτημα).
#
# ΑΠΑΙΤΕΙ ΣΥΝΔΕΣΗ: αν ο παίκτης δεν έχει λογαριασμό, δείχνει gate με κουμπί που
# εκπέμπει login_requested (το πιάνει το AuthPopup, όπως στο ProfilePopup).
#
# Ίδιο ύφος κάρτας/παλέτα/fade με ProfilePopup & AuthPopup. Όλα τα δεδομένα
# έρχονται από το Net (async): φορτώνουμε με guard (_refresh_id) ώστε γρήγορες
# εναλλαγές καρτέλας να μη «σκάνε» παλιά αποτελέσματα πάνω σε νέα.

## Ο παίκτης θέλει να συνδεθεί — το AuthPopup ανοίγει την οθόνη λογαριασμού.
signal login_requested
## Ο παίκτης θέλει τη Συντεχνία — το ClansPopup ανοίγει (Φάση 6, cross-link).
signal clan_requested
## Ο παίκτης θέλει DM με έναν φίλο — το ChatPopup ανοίγει (Φ7).
signal dm_requested(user_id: String, username: String)

# ── Παλέτα (ίδια με profile_popup / auth_popup) ──────────────────────────────
const C_PARCH := Color("f3e6c4")
const C_MUTED := Color("cdbf9a")
const C_GOLD  := Color("f2c84b")
const C_GOLD_D:= Color(0.360, 0.278, 0.058)
const C_OK    := Color(0.560, 0.900, 0.460)
const C_ERR   := Color(0.92, 0.45, 0.42)
const C_LOCK  := Color(0.45, 0.42, 0.36)

var _tab := "friends"          # "friends" | "requests" | "search"
## Αυξάνεται σε κάθε _refresh — τα async populate ελέγχουν ότι δεν ξεπεράστηκαν.
var _refresh_id := 0

var _list: VBoxContainer
var _friends_btn: Button
var _requests_btn: Button
var _search_btn: Button
var _search_bar: HBoxContainer
var _search_edit: LineEdit


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_build()
	# Συγχρονίσου με την κατάσταση σύνδεσης: αν αλλάξει ενώ είμαστε ανοιχτοί,
	# ξαναφτιάξε (π.χ. ο παίκτης μόλις συνδέθηκε από το gate).
	Net.auth_changed.connect(_on_auth_changed)


func open() -> void:
	visible = true
	_tab = "friends"
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
	title.text = "👥  Φίλοι"
	title.add_theme_color_override("font_color", C_GOLD)
	title.add_theme_font_size_override("font_size", 46)
	vbox.add_child(title)

	# ── Tabs ──
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	vbox.add_child(tabs)
	_friends_btn  = _make_tab("🤝  Φίλοι", "friends")
	_requests_btn = _make_tab("✉  Αιτήματα", "requests")
	_search_btn   = _make_tab("🔍  Αναζήτηση", "search")
	tabs.add_child(_friends_btn)
	tabs.add_child(_requests_btn)
	tabs.add_child(_search_btn)

	# ── Μπάρα αναζήτησης (ορατή μόνο στην καρτέλα «Αναζήτηση») ──
	_search_bar = HBoxContainer.new()
	_search_bar.add_theme_constant_override("separation", 10)
	_search_bar.visible = false
	vbox.add_child(_search_bar)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "όνομα χρήστη…"
	_search_edit.custom_minimum_size = Vector2(0, 66)
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.add_theme_font_size_override("font_size", 28)
	_search_edit.text_submitted.connect(func(_t): _do_search())
	_search_bar.add_child(_search_edit)

	var go := Button.new()
	go.text = "🔍"
	go.custom_minimum_size = Vector2(90, 66)
	go.add_theme_font_size_override("font_size", 28)
	go.pressed.connect(_do_search)
	_search_bar.add_child(go)

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

	# ── «Συντεχνία» (πάνω-δεξιά, αριστερά του X) → ανοίγει το ClansPopup (Φ6) ──
	var clan_btn := Button.new()
	clan_btn.text = "🛡  Συντεχνία"
	clan_btn.anchor_left = 1.0; clan_btn.anchor_right = 1.0
	clan_btn.offset_left = -318.0; clan_btn.offset_top = 22.0
	clan_btn.offset_right = -96.0; clan_btn.offset_bottom = 74.0
	clan_btn.add_theme_font_size_override("font_size", 24)
	clan_btn.add_theme_color_override("font_color", C_GOLD)
	clan_btn.pressed.connect(func():
		clan_requested.emit()
		close_popup())
	card.add_child(clan_btn)

	# ── X (πάνω-δεξιά) ──
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
	b.custom_minimum_size = Vector2(0, 70)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(func(): _select_tab(id))
	return b

func _select_tab(id: String) -> void:
	_tab = id
	_refresh()

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_popup()


# ═══════════════════════════════════════════════════════════════════════════
# ΠΕΡΙΕΧΟΜΕΝΟ (async — με guard ενάντια σε επικαλυπτόμενα refresh)
# ═══════════════════════════════════════════════════════════════════════════
func _refresh() -> void:
	_refresh_id += 1
	var my_id := _refresh_id
	_friends_btn.button_pressed = _tab == "friends"
	_requests_btn.button_pressed = _tab == "requests"
	_search_btn.button_pressed = _tab == "search"
	_search_bar.visible = _tab == "search" and Net.is_logged_in()
	_clear_list()

	# Gate: χωρίς λογαριασμό δεν υπάρχουν φίλοι.
	if not Net.is_logged_in():
		_show_login_gate()
		return

	if _tab == "search":
		# Η αναζήτηση ενεργοποιείται από το κουμπί — ξεκίνα με οδηγία.
		_list.add_child(_hint("Γράψε το όνομα ενός φίλου και πάτησε 🔍"))
		return

	_list.add_child(_hint("Φόρτωση…"))
	var res := await Net.list_friendships()
	if my_id != _refresh_id:
		return   # ο χρήστης άλλαξε καρτέλα στο μεταξύ
	_clear_list()
	if not res["ok"]:
		_list.add_child(_hint("Δεν ήταν δυνατή η σύνδεση με τον διακομιστή."))
		return
	var items: Array = res["data"].get("items", [])
	if _tab == "friends":
		await _populate_friends(items, my_id)
	else:
		_populate_requests(items)

## Λίστα-κατάταξη: εγώ + οι αποδεκτοί φίλοι, ταξινομημένοι φθίνουσα κατά ισχύ
## ομάδας (party_power). Η δική μου ισχύς υπολογίζεται τοπικά (μέσω PlayerProfile/
## Heroes) — των φίλων έρχεται από το δημόσιο profile τους στον server (ήδη
## συγχρονισμένο μέσω push_profile()).
func _populate_friends(items: Array, my_id: int) -> void:
	var me := Net.get_user_id()
	var accepted := items.filter(func(r): return str(r.get("status", "")) == "accepted")
	var my_profile := PlayerProfile.build_public_profile()
	var entries: Array[Dictionary] = [{
		"name": Net.get_username(),
		"power": float(my_profile.get("party_power", 0.0)),
		"region_label": str(my_profile.get("region_label", "—")),
		"streak": int(my_profile.get("streak", 0)),
		"is_me": true,
		"rec": {},
	}]
	for rec in accepted:
		var other_id := _other_user(rec, me)
		var other_name := _other_name(rec, me)
		var res := await Net.fetch_profile(other_id)
		if my_id != _refresh_id:
			return   # ο χρήστης άλλαξε καρτέλα στο μεταξύ
		var power := 0.0
		var region_label := "—"
		var streak := 0
		if res["ok"]:
			var profs: Array = res["data"].get("items", [])
			if not profs.is_empty():
				var p: Dictionary = profs[0]
				power = float(p.get("party_power", 0.0))
				region_label = str(p.get("region_label", "—"))
				streak = int(p.get("streak", 0))
		entries.append({
			"name": other_name, "power": power, "region_label": region_label,
			"streak": streak, "is_me": false, "rec": rec,
		})

	if my_id != _refresh_id:
		return
	entries.sort_custom(func(a, b): return a["power"] > b["power"])
	_clear_list()
	for i in entries.size():
		_list.add_child(_friend_row(i + 1, entries[i]))
	if accepted.is_empty():
		_list.add_child(_hint("Δεν έχεις φίλους ακόμα. Δοκίμασε την Αναζήτηση!"))

## Εισερχόμενα αιτήματα (Αποδοχή/Απόρριψη) + εξερχόμενα εκκρεμή (Ακύρωση).
func _populate_requests(items: Array) -> void:
	var me := Net.get_user_id()
	var incoming := items.filter(func(r):
		return str(r.get("status", "")) == "pending" and str(r.get("addressee", "")) == me)
	var outgoing := items.filter(func(r):
		return str(r.get("status", "")) == "pending" and str(r.get("requester", "")) == me)

	if incoming.is_empty() and outgoing.is_empty():
		_list.add_child(_hint("Κανένα εκκρεμές αίτημα."))
		return

	if not incoming.is_empty():
		_list.add_child(_section_label("— Εισερχόμενα —"))
		for rec in incoming:
			_list.add_child(_incoming_row(str(rec.get("requester_name", "")), str(rec.get("id", ""))))
	if not outgoing.is_empty():
		_list.add_child(_section_label("— Εξερχόμενα (εκκρεμούν) —"))
		for rec in outgoing:
			_list.add_child(_outgoing_row(str(rec.get("addressee_name", "")), str(rec.get("id", ""))))


# ═══════════════════════════════════════════════════════════════════════════
# ΑΝΑΖΗΤΗΣΗ
# ═══════════════════════════════════════════════════════════════════════════
func _do_search() -> void:
	if not Net.is_logged_in():
		return
	_refresh_id += 1
	var my_id := _refresh_id
	var query := _search_edit.text.strip_edges()
	_clear_list()
	if query.length() < 2:
		_list.add_child(_hint("Γράψε τουλάχιστον 2 χαρακτήρες."))
		return
	_list.add_child(_hint("Αναζήτηση…"))

	# Παράλληλα: αποτελέσματα + οι υπάρχουσες σχέσεις (για σωστή κατάσταση κουμπιού).
	var res := await Net.search_users(query)
	var rel := await Net.list_friendships()
	if my_id != _refresh_id:
		return
	_clear_list()
	if not res["ok"]:
		_list.add_child(_hint("Η αναζήτηση απέτυχε."))
		return
	var me := Net.get_user_id()
	var related := _related_ids(rel)
	var results: Array = res["data"].get("items", [])
	var shown := 0
	for rec in results:
		var uid := str(rec.get("user", ""))
		if uid == "" or uid == me:
			continue   # μη δείχνεις τον εαυτό σου
		_list.add_child(_search_row(rec, related.get(uid, "")))
		shown += 1
	if shown == 0:
		_list.add_child(_hint("Κανένας παίκτης δεν βρέθηκε."))


# ═══════════════════════════════════════════════════════════════════════════
# ΓΡΑΜΜΕΣ
# ═══════════════════════════════════════════════════════════════════════════
## Μία γραμμή της κατάταξης «Φίλοι»: θέση, όνομα (+ «(Εσύ)» στη δική σου),
## ισχύ ομάδας, και υπο-γραμμή κεφαλαίου/σερί. Τα κουμπιά 💬/❌ εμφανίζονται
## μόνο σε γραμμές φίλων (όχι στη δική σου).
func _friend_row(rank: int, entry: Dictionary) -> PanelContainer:
	var card := _row_card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var rank_l := Label.new()
	rank_l.text = _rank_label(rank)
	rank_l.custom_minimum_size = Vector2(64, 0)
	rank_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_l.add_theme_color_override("font_color", C_GOLD if rank <= 3 else C_MUTED)
	rank_l.add_theme_font_size_override("font_size", 30)
	row.add_child(rank_l)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	var is_me: bool = entry["is_me"]
	var uname: String = entry["name"]

	var name_l := Label.new()
	name_l.text = (uname + "  (Εσύ)") if is_me else uname
	name_l.add_theme_color_override("font_color", C_OK if is_me else C_GOLD)
	name_l.add_theme_font_size_override("font_size", 30)
	col.add_child(name_l)

	var sub := Label.new()
	sub.text = "🗺 %s   🔥 %d" % [str(entry.get("region_label", "—")), int(entry.get("streak", 0))]
	sub.add_theme_color_override("font_color", C_MUTED)
	sub.add_theme_font_size_override("font_size", 22)
	col.add_child(sub)

	var power_l := Label.new()
	power_l.text = "💪 %.1f" % float(entry["power"])
	power_l.custom_minimum_size = Vector2(100, 0)
	power_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	power_l.add_theme_color_override("font_color", C_GOLD)
	power_l.add_theme_font_size_override("font_size", 26)
	row.add_child(power_l)

	if not is_me:
		var rec: Dictionary = entry["rec"]
		var me := Net.get_user_id()
		var other_id := _other_user(rec, me)

		var chat := Button.new()
		chat.text = "💬"
		chat.custom_minimum_size = Vector2(70, 64)
		chat.add_theme_font_size_override("font_size", 26)
		chat.pressed.connect(func():
			dm_requested.emit(other_id, uname)
			close_popup())
		row.add_child(chat)

		var remove := Button.new()
		remove.text = "❌"
		remove.custom_minimum_size = Vector2(70, 64)
		remove.add_theme_font_size_override("font_size", 26)
		remove.pressed.connect(func(): _on_remove(str(rec.get("id", ""))))
		row.add_child(remove)

	return card

func _rank_label(rank: int) -> String:
	return "#%d" % rank

func _incoming_row(uname: String, id: String) -> PanelContainer:
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

func _outgoing_row(uname: String, id: String) -> PanelContainer:
	var card := _row_card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var name_l := Label.new()
	name_l.text = uname
	name_l.add_theme_color_override("font_color", C_MUTED)
	name_l.add_theme_font_size_override("font_size", 28)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)

	var pend := Label.new()
	pend.text = "εκκρεμεί"
	pend.add_theme_color_override("font_color", C_MUTED)
	pend.add_theme_font_size_override("font_size", 22)
	row.add_child(pend)

	var cancel := Button.new()
	cancel.text = "❌"
	cancel.custom_minimum_size = Vector2(70, 64)
	cancel.add_theme_font_size_override("font_size", 26)
	cancel.pressed.connect(func(): _on_remove(id))
	row.add_child(cancel)
	return card

func _search_row(rec: Dictionary, relation: String) -> PanelContainer:
	# relation: "" = καμία, "accepted" = ήδη φίλος, "pending" = εκκρεμεί αίτημα.
	var uid := str(rec.get("user", ""))
	var uname := str(rec.get("username", ""))
	var card := _row_card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	var name_l := Label.new()
	name_l.text = uname
	name_l.add_theme_color_override("font_color", C_GOLD)
	name_l.add_theme_font_size_override("font_size", 28)
	col.add_child(name_l)

	var sub := Label.new()
	sub.text = "🗺 %s   🔥 %d" % [str(rec.get("region_label", "—")), int(rec.get("streak", 0))]
	sub.add_theme_color_override("font_color", C_MUTED)
	sub.add_theme_font_size_override("font_size", 22)
	col.add_child(sub)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 64)
	btn.add_theme_font_size_override("font_size", 24)
	if relation == "accepted":
		btn.text = "Φίλος ✓"
		btn.disabled = true
		btn.add_theme_color_override("font_color_disabled", C_OK)
	elif relation == "pending":
		btn.text = "Εκκρεμεί"
		btn.disabled = true
	else:
		btn.text = "➕ Πρόσθεσε"
		btn.pressed.connect(func(): _on_add(uid, uname, btn))
	row.add_child(btn)
	return card


# ═══════════════════════════════════════════════════════════════════════════
# ΕΝΕΡΓΕΙΕΣ
# ═══════════════════════════════════════════════════════════════════════════
func _on_add(uid: String, uname: String, btn: Button) -> void:
	btn.disabled = true
	btn.text = "…"
	var res := await Net.send_friend_request(uid, uname)
	if not is_instance_valid(btn):
		return
	if res["ok"]:
		btn.text = "Στάλθηκε ✓"
		btn.add_theme_color_override("font_color_disabled", C_OK)
	else:
		btn.text = "Σφάλμα"
		btn.disabled = false

func _on_respond(id: String, accept: bool) -> void:
	await Net.respond_friend_request(id, accept)
	_refresh()

func _on_remove(id: String) -> void:
	await Net.remove_friend(id)
	_refresh()


# ═══════════════════════════════════════════════════════════════════════════
# GATE (χωρίς λογαριασμό)
# ═══════════════════════════════════════════════════════════════════════════
func _show_login_gate() -> void:
	_list.add_child(_hint("Χρειάζεσαι λογαριασμό για να προσθέσεις φίλους και να συγκρίνεις την πρόοδό σου."))
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

## Ο user id της «άλλης» πλευράς μιας σχέσης (όχι εγώ).
func _other_user(rec: Dictionary, me: String) -> String:
	var req := str(rec.get("requester", ""))
	return str(rec.get("addressee", "")) if req == me else req

func _other_name(rec: Dictionary, me: String) -> String:
	var req := str(rec.get("requester", ""))
	return str(rec.get("addressee_name", "")) if req == me else str(rec.get("requester_name", ""))

## Χάρτης user_id → κατάσταση σχέσης ("accepted"|"pending") για τα search results.
func _related_ids(rel: Dictionary) -> Dictionary:
	var out := {}
	if not rel.get("ok", false):
		return out
	var me := Net.get_user_id()
	for rec in rel["data"].get("items", []):
		out[_other_user(rec, me)] = str(rec.get("status", ""))
	return out

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
