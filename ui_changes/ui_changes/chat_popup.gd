extends Control

# ═══════════════════════════════════════════════════════════════════════════
# ChatPopup — συνομιλία (Φάση 7). ΕΝΑ επαναχρησιμοποιήσιμο popup για:
#   • clan chat  → open_clan(clan_id, τίτλος)
#   • DM φίλου   → open_dm(user_id, τίτλος)
# ═══════════════════════════════════════════════════════════════════════════
# Καθαρό UI πάνω από το Net. Το ClansPopup (κουμπί «💬 Συνομιλία» στη δική μου
# συντεχνία) και το FriendsPopup (💬 ανά φίλο) το ανοίγουν μέσω σημάτων.
#
# ΕΜΦΑΝΙΣΗ (mobile chat): κάθε μήνυμα είναι μια «φούσκα» (bubble) — δικά μου δεξιά
# με χρυσό-ζεστό φόντο, των άλλων αριστερά με ουδέτερο φόντο, με μικρή «ουρά» στην
# κάτω γωνία. Το input/κουμπί αποστολής έχουν το fantasy iron/gold ύφος των
# υπόλοιπων social popups (βλ. clans_popup.gd). Το πλάτος κάθε φούσκας μετριέται
# από το κείμενο (μέχρι ένα max), ώστε τα μικρά μηνύματα να είναι μικρές φούσκες
# και τα μεγάλα να αναδιπλώνονται — όχι μία επίπεδη στήλη κειμένου.
#
# ΑΝΑΝΕΩΣΗ = ADAPTIVE POLLING (Φ8): ρωτά τα νεότερα μηνύματα (`created >= last`) και
# προσθέτει όσα δεν έχουμε ξαναδεί (dedup ανά id). Ο ρυθμός ΠΡΟΣΑΡΜΟΖΕΤΑΙ:
#   • γρήγορος (POLL_FAST) όταν το παράθυρο είναι ανοιχτό & το παιχνίδι εστιασμένο·
#   • επιβραδύνεται σταδιακά (ώς POLL_IDLE_MAX) όσο η συνομιλία μένει σιωπηλή·
#   • πέφτει σε αργό ρυθμό (POLL_UNFOCUSED) όταν ο παίκτης κάνει alt-tab·
#   • «ζωντανεύει» άμεσα σε γραφή/αποστολή/άφιξη μηνύματος/επιστροφή εστίασης.
# Έτσι παίρνουμε ~αίσθηση realtime όσο μιλάς, με ελάχιστη κίνηση/μπαταρία σε idle.
# (SSE realtime = μελλοντική επιλογή· δεν χρειάζεται αλλαγή UI.)
#
# Οι κανόνες πρόσβασης είναι ΣΤΟΝ SERVER (επαληθεύτηκαν με αρνητικά tests): clan chat
# μόνο για μέλη, DM μόνο για τα δύο μέρη. Εδώ δεν υπάρχει έλεγχος ασφαλείας.

## Ο παίκτης θέλει να συνδεθεί (gate — δεν συμβαίνει από κανονική είσοδο, αλλά ασφαλές).
signal login_requested

# ── Παλέτα (ίδια με τα υπόλοιπα popups) ──────────────────────────────────────
const C_PARCH := Color("f3e6c4")
const C_MUTED := Color("cdbf9a")
const C_GOLD  := Color("f2c84b")
const C_GOLD_D:= Color(0.360, 0.278, 0.058)
const C_ERR   := Color(0.92, 0.45, 0.42)
# ── Χρώματα φουσκών ──────────────────────────────────────────────────────────
const C_BUBBLE_ME    := Color(0.300, 0.238, 0.095, 0.97)   # δικό μου (ζεστό χρυσό-καφέ)
const C_BUBBLE_OTHER := Color(0.155, 0.150, 0.200, 0.97)   # άλλου (ουδέτερο σκούρο)
const C_TXT_ME       := Color("fff2d2")                     # κείμενο δικού μου μηνύματος
const C_IRON         := Color(0.175, 0.150, 0.120, 0.99)
const C_IRON_H       := Color(0.245, 0.210, 0.165, 1.0)
const C_INPUT        := Color(0.045, 0.045, 0.075, 0.98)

## Adaptive polling (Φ8) — όρια ρυθμού ανανέωσης:
const POLL_FAST := 3.0        # ενεργή, εστιασμένη συνομιλία
const POLL_IDLE_MAX := 20.0   # ανώτατο· εκεί φτάνει σταδιακά όσο επικρατεί σιωπή
const POLL_UNFOCUSED := 15.0  # ο παίκτης έκανε alt-tab (το παιχνίδι έχασε εστίαση)
const IDLE_BACKOFF := 1.6     # πολλαπλασιαστής επιβράδυνσης ανά «άδειο» poll
const MAX_LEN := 500

# ── Μεγέθη UI (mobile, portrait — συνεπή με clans/friends popups) ─────────────
const TITLE_FONT := 60
const MSG_FONT := 38
const NAME_FONT := 30
const HINT_FONT := 40
## Ανώτατο πλάτος κειμένου μέσα σε φούσκα (η φούσκα προσθέτει padding από πάνω).
## Πάνω από αυτό, το κείμενο αναδιπλώνεται· κάτω, η φούσκα «μαζεύει» στο κείμενο.
const MAX_TEXT_W := 620.0

var _scope := "clan"          # "clan" | "dm"
var _clan_id := ""
var _other_id := ""
var _my_id := ""
## Αυξάνεται σε κάθε open/close — τα async fetch/poll ελέγχουν ότι δεν ξεπεράστηκαν.
var _session := 0
var _last_created := ""
var _seen := {}               # id -> true (dedup)
## Τρέχον διάστημα polling (κινείται μεταξύ POLL_FAST και POLL_IDLE_MAX).
var _poll_interval := POLL_FAST
## Είναι το παράθυρο του παιχνιδιού εστιασμένο; (ενημερώνεται από _notification)
var _app_focused := true

var _title_label: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _input: LineEdit
var _send_btn: Button
var _timer: Timer


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_build()
	# One-shot: ξαναπρογραμματίζεται μόνος του με το ΤΡΕΧΟΝ (προσαρμοσμένο) διάστημα
	# αφού ολοκληρωθεί κάθε poll — έτσι ο ρυθμός αλλάζει δυναμικά (βλ. _reschedule_poll).
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_poll_timer)
	add_child(_timer)


## Το παιχνίδι έχασε/ξανακέρδισε την εστίαση (alt-tab). Επηρεάζει τον ρυθμό polling.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_app_focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_app_focused = true
		_bump_activity()   # επέστρεψε ο παίκτης → φρέσκαρε αμέσως με γρήγορο ρυθμό


# ═══════════════════════════════════════════════════════════════════════════
# ΕΙΣΟΔΟΙ
# ═══════════════════════════════════════════════════════════════════════════
func open_clan(clan_id: String, title: String) -> void:
	_scope = "clan"
	_clan_id = clan_id
	_other_id = ""
	_start("💬  " + title)

func open_dm(user_id: String, title: String) -> void:
	_scope = "dm"
	_other_id = user_id
	_clan_id = ""
	_start("💬  " + title)

func _start(title: String) -> void:
	_session += 1
	_my_id = Net.get_user_id()
	_last_created = ""
	_seen = {}
	_title_label.text = title
	_clear_list()
	_input.text = ""
	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)

	if not Net.is_logged_in():
		_show_login_gate()
		return
	_input.editable = true
	_send_btn.disabled = false
	_poll_interval = POLL_FAST
	_app_focused = DisplayServer.window_is_focused()
	_load_initial()
	_reschedule_poll()

func close_popup() -> void:
	_session += 1          # ακύρωσε τυχόν εκκρεμή fetch/poll
	_timer.stop()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func(): visible = false)


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
	margin.add_theme_constant_override("margin_left", 55)
	margin.add_theme_constant_override("margin_right", 55)
	margin.add_theme_constant_override("margin_top", 170)
	margin.add_theme_constant_override("margin_bottom", 55)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	margin.add_child(vbox)

	# ── Τίτλος (💬 όνομα συντεχνίας/φίλου) — clip ώστε μακρύ όνομα να μη ξεχειλίζει ──
	_title_label = Label.new()
	_title_label.text = "💬  Συνομιλία"
	_title_label.add_theme_color_override("font_color", C_GOLD)
	_title_label.add_theme_font_size_override("font_size", TITLE_FONT)
	_title_label.clip_text = true
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(_title_label)

	vbox.add_child(_divider(C_GOLD_D, 4))

	# ── Μηνύματα (scroll) ──
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 18)
	_scroll.add_child(_list)

	# ── Είσοδος (LineEdit + Αποστολή) ──
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 16)
	vbox.add_child(input_row)

	_input = _styled_edit("μήνυμα…")
	_input.max_length = MAX_LEN
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.text_submitted.connect(func(_t): _on_send())
	# Ο παίκτης άρχισε να γράφει → η συνομιλία είναι «ζωντανή», γρήγορο poll.
	_input.focus_entered.connect(_bump_activity)
	input_row.add_child(_input)

	_send_btn = _make_button("➤", "gold")
	_send_btn.custom_minimum_size = Vector2(150, 104)
	_send_btn.add_theme_font_size_override("font_size", 50)
	_send_btn.pressed.connect(_on_send)
	input_row.add_child(_send_btn)

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
# ΦΟΡΤΩΜΑ / POLLING
# ═══════════════════════════════════════════════════════════════════════════
func _load_initial() -> void:
	var my_sess := _session
	var res := await _fetch("")
	if my_sess != _session:
		return
	_clear_list()
	if not res["ok"]:
		_list.add_child(_hint("Δεν ήταν δυνατή η φόρτωση της συνομιλίας."))
		return
	var items: Array = res["data"].get("items", [])
	if items.is_empty():
		_list.add_child(_hint("Κανένα μήνυμα ακόμα. Πες το πρώτο!"))
	for rec in items:
		_append_message(rec)
	_scroll_to_bottom()

## Ο timer χτύπησε: κάνε ένα poll και μετά ξαναπρογραμμάτισε με το νέο διάστημα.
func _on_poll_timer() -> void:
	await _poll()
	_reschedule_poll()

## Ξεκινά ξανά τον one-shot timer με το τρέχον διάστημα (αργότερο αν έχασε εστίαση).
## Ασφαλές να κληθεί ελεύθερα — δεν προγραμματίζει αν το popup είναι κλειστό/αποσυνδεδεμένο.
func _reschedule_poll() -> void:
	if not visible or not Net.is_logged_in():
		return
	var interval := _poll_interval
	if not _app_focused:
		interval = maxf(interval, POLL_UNFOCUSED)
	_timer.start(interval)

## «Ζωντανεύει» τη συνομιλία: επαναφέρει γρήγορο ρυθμό και κάνει άμεσο poll.
## Καλείται σε γραφή/αποστολή και όταν το παιχνίδι ξανακερδίζει εστίαση.
func _bump_activity() -> void:
	_poll_interval = POLL_FAST
	if visible and Net.is_logged_in():
		_timer.start(POLL_FAST)

func _poll() -> void:
	if not visible or not Net.is_logged_in():
		return
	var my_sess := _session
	var res := await _fetch(_last_created)
	if my_sess != _session or not res["ok"]:
		return
	var added := false
	for rec in res["data"].get("items", []):
		if _append_message(rec):
			added = true
	if added:
		_scroll_to_bottom()
		_poll_interval = POLL_FAST                                    # δραστηριότητα → επιτάχυνε
	else:
		_poll_interval = minf(_poll_interval * IDLE_BACKOFF, POLL_IDLE_MAX)  # σιωπή → επιβράδυνε

func _fetch(since: String) -> Dictionary:
	if _scope == "clan":
		return await Net.fetch_clan_messages(_clan_id, since)
	return await Net.fetch_dm_messages(_other_id, since)

## Προσθέτει ένα μήνυμα (ως φούσκα) αν δεν το έχουμε ξαναδεί. Επιστρέφει true αν προστέθηκε.
func _append_message(rec: Dictionary) -> bool:
	var id := str(rec.get("id", ""))
	if id == "" or _seen.has(id):
		return false
	# Αν υπάρχει hint («κανένα μήνυμα»), καθάρισέ το με το πρώτο πραγματικό.
	if _seen.is_empty() and _list.get_child_count() == 1 and _list.get_child(0) is Label:
		_clear_list()
	_seen[id] = true
	var created := str(rec.get("created", ""))
	if created > _last_created:
		_last_created = created

	var own := str(rec.get("sender", "")) == _my_id
	var text := str(rec.get("text", ""))
	var sender_name := str(rec.get("sender_name", ""))

	# Γραμμή πλήρους πλάτους· η φούσκα ευθυγραμμίζεται δεξιά (δικό μου) ή αριστερά
	# (άλλου) με έναν ελαστικό spacer στην αντίθετη πλευρά.
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_FILL
	row.add_theme_constant_override("separation", 0)

	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", _bubble_sb(own))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	bubble.add_child(col)

	# clan chat: όνομα αποστολέα πάνω από το μήνυμα (μόνο για τους άλλους).
	if _scope == "clan" and not own and sender_name != "":
		var nm := Label.new()
		nm.text = sender_name
		nm.add_theme_color_override("font_color", C_GOLD)
		nm.add_theme_font_size_override("font_size", NAME_FONT)
		col.add_child(nm)

	var msg := Label.new()
	msg.text = text
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", MSG_FONT)
	msg.add_theme_color_override("font_color", C_TXT_ME if own else C_PARCH)
	# Πλάτος φούσκας = πλάτος κειμένου (μονής γραμμής), με ανώτατο όριο· έτσι τα
	# μικρά μηνύματα δίνουν μικρές φούσκες και τα μεγάλα αναδιπλώνονται στο max.
	msg.custom_minimum_size = Vector2(minf(_measure_width(text, MSG_FONT), MAX_TEXT_W), 0)
	col.add_child(msg)

	if own:
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)
		row.add_child(bubble)
	else:
		row.add_child(bubble)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)

	_list.add_child(row)
	return true


# ═══════════════════════════════════════════════════════════════════════════
# ΑΠΟΣΤΟΛΗ
# ═══════════════════════════════════════════════════════════════════════════
func _on_send() -> void:
	if not Net.is_logged_in():
		return
	var text := _input.text.strip_edges()
	if text == "":
		return
	_input.text = ""
	_bump_activity()   # στέλνω → η συνομιλία είναι ενεργή, γρήγορος ρυθμός ανανέωσης
	var my_sess := _session
	var res: Dictionary
	if _scope == "clan":
		res = await Net.send_clan_message(_clan_id, text)
	else:
		res = await Net.send_dm(_other_id, "", text)
	if my_sess != _session:
		return
	if res["ok"]:
		# Αισιόδοξη εμφάνιση: πρόσθεσε το δικό μας μήνυμα άμεσα (dedup με το poll).
		if _append_message(res["data"]):
			_scroll_to_bottom()
	else:
		# Επανάφερε το κείμενο ώστε να μη χαθεί.
		_input.text = text


# ═══════════════════════════════════════════════════════════════════════════
# GATE / ΒΟΗΘΗΤΙΚΑ
# ═══════════════════════════════════════════════════════════════════════════
func _show_login_gate() -> void:
	_input.editable = false
	_send_btn.disabled = true
	_clear_list()
	_list.add_child(_hint("Χρειάζεσαι λογαριασμό για να συνομιλήσεις."))
	var btn := _make_button("🔑  Σύνδεση", "gold")
	btn.pressed.connect(func():
		login_requested.emit()
		close_popup())
	_list.add_child(btn)

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func _clear_list() -> void:
	for c in _list.get_children():
		c.queue_free()

func _hint(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", C_MUTED)
	l.add_theme_font_size_override("font_size", HINT_FONT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


# ═══════════════════════════════════════════════════════════════════════════
# ΒΟΗΘΗΤΙΚΑ ΕΜΦΑΝΙΣΗΣ (το «ύφος» σε ΕΝΑ σημείο — ίδια φιλοσοφία με clans_popup)
# ═══════════════════════════════════════════════════════════════════════════

## Το πλάτος (px) που θα έπιανε το κείμενο σε ΜΙΑ γραμμή — για να «κόψουμε» τη
## φούσκα στο κείμενο (μέχρι το MAX_TEXT_W). Χρησιμοποιεί την προεπιλεγμένη
## γραμματοσειρά του theme, ίδια με αυτή που ζωγραφίζουν τα Labels.
func _measure_width(text: String, font_size: int) -> float:
	var font := get_theme_default_font()
	if font == null:
		return MAX_TEXT_W
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

## StyleBox φούσκας: ζεστό χρυσό-καφέ για τα δικά μου, ουδέτερο σκούρο για τους
## άλλους, με μικρή «ουρά» (πιο κοφτή γωνία) στην κάτω πλευρά ανάλογα την πλευρά.
func _bubble_sb(own: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BUBBLE_ME if own else C_BUBBLE_OTHER
	sb.border_color = C_GOLD_D if own else Color(0, 0, 0, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(22)
	if own:
		sb.corner_radius_bottom_right = 5     # ουρά δεξιά
	else:
		sb.corner_radius_bottom_left = 5      # ουρά αριστερά
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	return sb

## Λεπτή οριζόντια γραμμή-διαχωριστικό (αντί για αχνό default HSeparator).
func _divider(col: Color, h: int = 3) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.custom_minimum_size = Vector2(0, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## LineEdit με ύφος του παιχνιδιού (σκούρο φόντο, χρυσό-σκούρο περίγραμμα που
## γίνεται χρυσό στο focus, παραγέμισμα, μεγάλη γραμματοσειρά για κινητό).
func _styled_edit(placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
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

## Κουμπί με fantasy iron/gold ύφος (ίδια φιλοσοφία με ClansPopup._make_button).
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
