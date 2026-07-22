extends Control

# ═══════════════════════════════════════════════════════════════════════════
# ChatPopup — συνομιλία (Φάση 7). ΕΝΑ επαναχρησιμοποιήσιμο popup για:
#   • clan chat  → open_clan(clan_id, τίτλος)
#   • DM φίλου   → open_dm(user_id, τίτλος)
# ═══════════════════════════════════════════════════════════════════════════
# Καθαρό UI πάνω από το Net. Το ClansPopup (κουμπί «💬 Συνομιλία» στη δική μου
# συντεχνία) και το FriendsPopup (💬 ανά φίλο) το ανοίγουν μέσω σημάτων.
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

## Adaptive polling (Φ8) — όρια ρυθμού ανανέωσης:
const POLL_FAST := 3.0        # ενεργή, εστιασμένη συνομιλία
const POLL_IDLE_MAX := 20.0   # ανώτατο· εκεί φτάνει σταδιακά όσο επικρατεί σιωπή
const POLL_UNFOCUSED := 15.0  # ο παίκτης έκανε alt-tab (το παιχνίδι έχασε εστίαση)
const IDLE_BACKOFF := 1.6     # πολλαπλασιαστής επιβράδυνσης ανά «άδειο» poll
const MAX_LEN := 500

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
	card.offset_left = -440.0; card.offset_top = -640.0
	card.offset_right = 440.0; card.offset_bottom = 640.0
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
	margin.add_theme_constant_override("margin_left", 46)
	margin.add_theme_constant_override("margin_right", 46)
	margin.add_theme_constant_override("margin_top", 44)
	margin.add_theme_constant_override("margin_bottom", 40)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# ── Τίτλος ──
	_title_label = Label.new()
	_title_label.text = "💬  Συνομιλία"
	_title_label.add_theme_color_override("font_color", C_GOLD)
	_title_label.add_theme_font_size_override("font_size", 40)
	vbox.add_child(_title_label)

	vbox.add_child(HSeparator.new())

	# ── Μηνύματα (scroll) ──
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	_scroll.add_child(_list)

	# ── Είσοδος (LineEdit + Αποστολή) ──
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 10)
	vbox.add_child(input_row)

	_input = LineEdit.new()
	_input.placeholder_text = "μήνυμα…"
	_input.max_length = MAX_LEN
	_input.custom_minimum_size = Vector2(0, 70)
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.add_theme_font_size_override("font_size", 28)
	_input.text_submitted.connect(func(_t): _on_send())
	# Ο παίκτης άρχισε να γράφει → η συνομιλία είναι «ζωντανή», γρήγορο poll.
	_input.focus_entered.connect(_bump_activity)
	input_row.add_child(_input)

	_send_btn = Button.new()
	_send_btn.text = "➤"
	_send_btn.custom_minimum_size = Vector2(100, 70)
	_send_btn.add_theme_font_size_override("font_size", 32)
	_send_btn.add_theme_color_override("font_color", C_GOLD)
	_send_btn.pressed.connect(_on_send)
	input_row.add_child(_send_btn)

	# ── X (πάνω-δεξιά) ──
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.anchor_left = 1.0; close_btn.anchor_right = 1.0
	close_btn.offset_left = -76.0; close_btn.offset_top = 14.0
	close_btn.offset_right = -18.0; close_btn.offset_bottom = 72.0
	close_btn.add_theme_font_size_override("font_size", 36)
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

## Προσθέτει ένα μήνυμα αν δεν το έχουμε ξαναδεί. Επιστρέφει true αν προστέθηκε.
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

	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 1)

	# clan chat: δείξε το όνομα του άλλου πάνω από το μήνυμα.
	if _scope == "clan" and not own:
		var nm := Label.new()
		nm.text = str(rec.get("sender_name", ""))
		nm.add_theme_color_override("font_color", C_GOLD)
		nm.add_theme_font_size_override("font_size", 20)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(nm)

	var msg := Label.new()
	msg.text = text
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 27)
	msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if own:
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		msg.add_theme_color_override("font_color", C_GOLD)
	else:
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		msg.add_theme_color_override("font_color", C_PARCH)
	row.add_child(msg)

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
	var btn := Button.new()
	btn.text = "🔑  Σύνδεση"
	btn.custom_minimum_size = Vector2(0, 80)
	btn.add_theme_font_size_override("font_size", 30)
	btn.add_theme_color_override("font_color", C_GOLD)
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
	l.add_theme_font_size_override("font_size", 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
