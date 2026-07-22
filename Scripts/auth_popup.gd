extends Control

# ═══════════════════════════════════════════════════════════════════════════
# AuthPopup — οθόνη σύνδεσης / εγγραφής (Φάση 3 του online πλάνου)
# ═══════════════════════════════════════════════════════════════════════════
# Το ΜΟΝΑΔΙΚΟ σημείο επαφής του παίκτη με το σύστημα λογαριασμών. Καθαρό UI
# πάνω από το Net autoload — δεν ξέρει τίποτα για REST/tokens, μόνο καλεί
# Net.login()/Net.register() και ακούει το Net.auth_changed.
#
# ΡΟΗ (κλειδωμένη UX, βλ. social-server-plan):
#   • ΕΚΚΙΝΗΣΗ: αν υπάρχει αποθηκευμένο session → σιωπηλό Net.refresh_auth()
#     (κανένα popup). Αλλιώς, αν ο παίκτης ΔΕΝ έχει διαλέξει offline → δείξε το
#     popup μία φορά.
#   • «Παίξε offline» = ΚΑΜΙΑ κλήση server· κλείνει· Net.choose_offline() ώστε
#     να μην ξαναρωτήσει. Η σύνδεση μένει διαθέσιμη από την οθόνη προφίλ.
#   • Επιτυχής σύνδεση/εγγραφή → Net.auth_changed(true) → κλείνει αυτόματα.
#
# Η ΠΡΟΒΟΛΗ του username στο προφίλ γίνεται από το ίδιο το ProfilePopup (ακούει
# κι εκείνο το Net.auth_changed) — εδώ απλώς οδηγούμε τη ροή auth.

const C_PARCH := Color("f3e6c4")
const C_MUTED := Color("cdbf9a")
const C_GOLD  := Color("f2c84b")
const C_GOLD_D := Color(0.360, 0.278, 0.058)
const C_ERR   := Color(0.92, 0.45, 0.42)
const C_OK    := Color(0.560, 0.900, 0.460)

var _mode := "login"                 # "login" | "register"
var _is_startup_prompt := false      # true όταν εμφανίζεται μόνο του στην εκκίνηση
var _busy := false                   # αποτρέπει διπλά αιτήματα

var _title: Label
var _login_tab: Button
var _register_tab: Button
var _user_edit: LineEdit
var _pass_edit: LineEdit
var _action_btn: Button
var _offline_btn: Button
var _close_btn: Button
var _status: Label


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_build()
	Net.auth_changed.connect(_on_auth_changed)
	# Οδήγησε την εκκίνηση αφού στηθεί όλο το δέντρο (ώστε το ProfilePopup να
	# προλάβει κι αυτό να συνδεθεί στο Net.auth_changed).
	call_deferred("_startup")


# ═══════════════════════════════════════════════════════════════════════════
# ΕΚΚΙΝΗΣΗ / ΡΟΗ ΕΜΦΑΝΙΣΗΣ
# ═══════════════════════════════════════════════════════════════════════════
func _startup() -> void:
	# 1) Υπάρχει token από προηγούμενη φορά → σιωπηλή επικύρωση (χωρίς popup).
	if Net.has_saved_session():
		await Net.refresh_auth()   # εκπέμπει auth_changed· σε αποτυχία κάνει logout()
	# 2) Αν ακόμη δεν είμαστε συνδεδεμένοι και δεν έχει επιλεγεί offline → ρώτα μία φορά.
	if Net.should_prompt_auth():
		open_startup_prompt()

## Εμφάνιση στην πρώτη εκκίνηση: δείχνει το κουμπί «Παίξε offline» και το X
## λειτουργεί ως offline (ώστε να μην ξαναενοχλήσει).
func open_startup_prompt() -> void:
	_is_startup_prompt = true
	_show()

## Εμφάνιση από την οθόνη προφίλ (ο παίκτης πάτησε «Σύνδεση»): απλό κλείσιμο,
## χωρίς κουμπί offline.
func open_from_profile() -> void:
	_is_startup_prompt = false
	_show()

func _show() -> void:
	_set_mode("login")
	_user_edit.text = ""
	_pass_edit.text = ""
	_set_status("")
	_offline_btn.visible = _is_startup_prompt
	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)
	_user_edit.grab_focus()

func close_popup() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func(): visible = false)


# ═══════════════════════════════════════════════════════════════════════════
# ΣΗΜΑΤΑ Net
# ═══════════════════════════════════════════════════════════════════════════
func _on_auth_changed(logged_in: bool) -> void:
	if logged_in and visible:
		_set_status("Καλωσόρισες, %s!" % Net.get_username(), C_OK)
		# Μικρή καθυστέρηση ώστε να προλάβει να διαβαστεί το μήνυμα.
		var t := get_tree().create_timer(0.6)
		await t.timeout
		if visible:
			close_popup()


# ═══════════════════════════════════════════════════════════════════════════
# ΕΝΕΡΓΕΙΕΣ ΚΟΥΜΠΙΩΝ
# ═══════════════════════════════════════════════════════════════════════════
func _on_action_pressed() -> void:
	if _busy:
		return
	var username := _user_edit.text.strip_edges()
	var password := _pass_edit.text
	var err := _validate(username, password)
	if err != "":
		_set_status(err, C_ERR)
		return

	_set_busy(true)
	if _mode == "register":
		_set_status("Δημιουργία λογαριασμού…", C_MUTED)
		var reg := await Net.register(username, password)
		if not reg["ok"]:
			_set_status(_friendly_error(reg), C_ERR)
			_set_busy(false)
			return
	_set_status("Σύνδεση…", C_MUTED)
	var res := await Net.login(username, password)
	if not res["ok"]:
		_set_status(_friendly_error(res), C_ERR)
		_set_busy(false)
		return
	# Επιτυχία: το _on_auth_changed αναλαμβάνει το κλείσιμο.
	_set_busy(false)

func _on_offline_pressed() -> void:
	Net.choose_offline()
	close_popup()

func _on_close_pressed() -> void:
	# Στην πρώτη εκκίνηση, το κλείσιμο ισοδυναμεί με «offline» ώστε να μην
	# ξαναρωτήσουμε. Όταν ανοίγει από το προφίλ, απλώς κλείνει.
	if _is_startup_prompt:
		Net.choose_offline()
	close_popup()


# ═══════════════════════════════════════════════════════════════════════════
# VALIDATION / ΜΗΝΥΜΑΤΑ
# ═══════════════════════════════════════════════════════════════════════════
func _validate(username: String, password: String) -> String:
	if username.length() < 3 or username.length() > 20:
		return "Το όνομα χρήστη πρέπει να έχει 3–20 χαρακτήρες."
	var re := RegEx.new()
	re.compile("^[a-zA-Z0-9_]+$")
	if re.search(username) == null:
		return "Μόνο λατινικά γράμματα, αριθμοί και _ επιτρέπονται."
	if password.length() < 8:
		return "Ο κωδικός πρέπει να έχει τουλάχιστον 8 χαρακτήρες."
	return ""

## Μετατρέπει τα σφάλματα του server σε φιλικά ελληνικά μηνύματα.
func _friendly_error(res: Dictionary) -> String:
	var status := int(res.get("status", 0))
	if status == 0:
		return "Δεν βρέθηκε ο διακομιστής. Έλεγξε τη σύνδεσή σου."
	if _mode == "register" and status == 400:
		return "Το όνομα χρήστη χρησιμοποιείται ήδη."
	if _mode == "login" and (status == 400 or status == 403):
		return "Λάθος όνομα χρήστη ή κωδικός."
	return "Κάτι πήγε στραβά (σφάλμα %d)." % status


# ═══════════════════════════════════════════════════════════════════════════
# ΚΑΤΑΣΚΕΥΗ UI (μία φορά)
# ═══════════════════════════════════════════════════════════════════════════
func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = MOUSE_FILTER_STOP  # μπλοκάρει το gameplay από πίσω
	add_child(dim)

	var card := Panel.new()
	card.anchor_left = 0.5; card.anchor_top = 0.5
	card.anchor_right = 0.5; card.anchor_bottom = 0.5
	card.offset_left = -420.0; card.offset_top = -520.0
	card.offset_right = 420.0; card.offset_bottom = 520.0
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
	margin.add_theme_constant_override("margin_left", 54)
	margin.add_theme_constant_override("margin_right", 54)
	margin.add_theme_constant_override("margin_top", 54)
	margin.add_theme_constant_override("margin_bottom", 54)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	margin.add_child(vbox)

	# ── Τίτλος ──
	_title = Label.new()
	_title.text = "Σύνδεση"
	_title.add_theme_color_override("font_color", C_GOLD)
	_title.add_theme_font_size_override("font_size", 48)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title)

	var sub := Label.new()
	sub.text = "Σύνδεσου για να κρατήσεις την πρόοδό σου και να δεις φίλους."
	sub.add_theme_color_override("font_color", C_MUTED)
	sub.add_theme_font_size_override("font_size", 24)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(sub)

	# ── Tabs σύνδεση / εγγραφή ──
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 14)
	vbox.add_child(tabs)
	_login_tab = _make_tab("Σύνδεση", "login")
	_register_tab = _make_tab("Εγγραφή", "register")
	tabs.add_child(_login_tab)
	tabs.add_child(_register_tab)

	vbox.add_child(HSeparator.new())

	# ── Πεδία ──
	vbox.add_child(_field_label("Όνομα χρήστη"))
	_user_edit = _make_edit(false, "π.χ. Konstantinos_D")
	vbox.add_child(_user_edit)

	vbox.add_child(_field_label("Κωδικός"))
	_pass_edit = _make_edit(true, "τουλάχιστον 8 χαρακτήρες")
	_pass_edit.text_submitted.connect(func(_t): _on_action_pressed())
	vbox.add_child(_pass_edit)

	# ── Μήνυμα κατάστασης ──
	_status = Label.new()
	_status.text = ""
	_status.add_theme_font_size_override("font_size", 24)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 34)
	vbox.add_child(_status)

	# ── Κύριο κουμπί δράσης ──
	_action_btn = Button.new()
	_action_btn.text = "Σύνδεση"
	_action_btn.custom_minimum_size = Vector2(0, 84)
	_action_btn.add_theme_font_size_override("font_size", 32)
	_action_btn.pressed.connect(_on_action_pressed)
	vbox.add_child(_action_btn)

	# ── «Παίξε offline» ──
	_offline_btn = Button.new()
	_offline_btn.text = "Παίξε offline"
	_offline_btn.custom_minimum_size = Vector2(0, 72)
	_offline_btn.add_theme_font_size_override("font_size", 28)
	_offline_btn.flat = true
	_offline_btn.add_theme_color_override("font_color", C_MUTED)
	_offline_btn.pressed.connect(_on_offline_pressed)
	vbox.add_child(_offline_btn)

	# ── X (πάνω-δεξιά) ──
	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.anchor_left = 1.0; _close_btn.anchor_right = 1.0
	_close_btn.offset_left = -74.0; _close_btn.offset_top = 16.0
	_close_btn.offset_right = -16.0; _close_btn.offset_bottom = 74.0
	_close_btn.add_theme_font_size_override("font_size", 36)
	_close_btn.pressed.connect(_on_close_pressed)
	card.add_child(_close_btn)


func _make_tab(text: String, id: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 72)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(func(): _set_mode(id))
	return b

func _make_edit(secret: bool, placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.secret = secret
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(0, 72)
	e.add_theme_font_size_override("font_size", 30)
	e.add_theme_constant_override("minimum_character_width", 0)
	return e

func _field_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", C_PARCH)
	l.add_theme_font_size_override("font_size", 24)
	return l


# ═══════════════════════════════════════════════════════════════════════════
# ΚΑΤΑΣΤΑΣΗ
# ═══════════════════════════════════════════════════════════════════════════
func _set_mode(id: String) -> void:
	_mode = id
	_login_tab.button_pressed = id == "login"
	_register_tab.button_pressed = id == "register"
	if id == "register":
		_title.text = "Εγγραφή"
		_action_btn.text = "Δημιουργία λογαριασμού"
	else:
		_title.text = "Σύνδεση"
		_action_btn.text = "Σύνδεση"
	_set_status("")

func _set_status(text: String, color: Color = C_MUTED) -> void:
	if not is_instance_valid(_status):
		return
	_status.text = text
	_status.add_theme_color_override("font_color", color)

func _set_busy(busy: bool) -> void:
	_busy = busy
	_action_btn.disabled = busy
	_login_tab.disabled = busy
	_register_tab.disabled = busy
