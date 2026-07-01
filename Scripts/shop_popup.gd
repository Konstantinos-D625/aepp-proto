extends Control

# Popup "Κατάστημα": αγορά όπλων και πανοπλιών με τα νομίσματα/υλικά του
# παίκτη (Χρυσό, Κασμίρ, Βαμβάκι, Σίδερο). Οι πόροι αφαιρούνται μέσω του
# Currency autoload, οπότε το LootPopup βλέπει αμέσως τα νέα ποσά.

const WEAPONS: Array[Dictionary] = [
	{ "id": "sword_student", "name": "Ξίφος Μαθητή",    "desc": "+5 Επίθεση",  "cost": {"Σίδερο": 5,  "Χρυσό": 20},               "icon": "⚔" },
	{ "id": "sword_double",  "name": "Δίκοπο Σπαθί",    "desc": "+12 Επίθεση", "cost": {"Σίδερο": 12, "Χρυσό": 60},               "icon": "⚔" },
	{ "id": "axe_war",       "name": "Πέλεκυς Πολέμου", "desc": "+20 Επίθεση", "cost": {"Σίδερο": 20, "Κασμίρ": 3, "Χρυσό": 120}, "icon": "🪓" },
]

const ARMOR: Array[Dictionary] = [
	{ "id": "armor_leather",      "name": "Δερμάτινη Πανοπλία", "desc": "+8 Άμυνα",  "cost": {"Βαμβάκι": 10, "Χρυσό": 15},              "icon": "🛡" },
	{ "id": "armor_iron",         "name": "Σιδερένια Πανοπλία", "desc": "+18 Άμυνα", "cost": {"Σίδερο": 15, "Χρυσό": 50},               "icon": "🛡" },
	{ "id": "armor_knight_shield","name": "Ασπίδα Ιππότη",      "desc": "+25 Άμυνα", "cost": {"Σίδερο": 10, "Κασμίρ": 5, "Χρυσό": 80},  "icon": "🛡" },
]

# ── Παλέτα (iron/gold — ίδιο ύφος με CharacterSelect) ─────────────────────
const C0       := Color(0, 0, 0, 0)
const C_BG     := Color(0.032, 0.022, 0.010, 0.82)
const C_DARK   := Color(0.055, 0.038, 0.018)
const C_MID    := Color(0.095, 0.068, 0.035)
const C_IRON   := Color(0.185, 0.168, 0.140)
const C_IRON_L := Color(0.265, 0.242, 0.208)
const C_SILVER := Color(0.572, 0.548, 0.510)
const C_BRONZE := Color(0.435, 0.308, 0.072)
const C_GOLD   := Color(0.820, 0.645, 0.118)
const C_GOLD_D := Color(0.268, 0.192, 0.032)
const C_CRIMSON:= Color(0.455, 0.030, 0.030)
const C_BONE   := Color(0.868, 0.830, 0.685)

const W := 1080.0
const H := 1920.0
const HDR_H := 240.0
const TAB_H := 96.0

var _category := "weapons"

var _currency_strip: Control
var _currency_labels := {}   # currency name -> Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _tab_weapons: Button
var _tab_armor: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	Currency.changed.connect(_update_currency_labels)

func show_popup() -> void:
	visible = true
	_update_currency_labels()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.30)

func _close() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func(): visible = false)

# ═══════════════════════════════════════════════════════════════
# ΚΑΤΑΣΚΕΥΗ UI
# ═══════════════════════════════════════════════════════════════
func _build() -> void:
	_build_dim()
	_build_header()
	_build_tabs()
	_build_grid_area()
	_refresh_grid()

func _build_dim() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = C_BG
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close()
	)
	add_child(dim)

func _build_header() -> void:
	var hdr := Panel.new()
	hdr.position = Vector2(0, 0)
	hdr.size     = Vector2(W, HDR_H)
	hdr.add_theme_stylebox_override("panel", _sb(Color(0.048, 0.032, 0.015, 0.97), C_BRONZE, 0))
	add_child(hdr)
	_cr(hdr, Vector2(0, HDR_H - 4), Vector2(W, 4), C_GOLD)
	_cr(hdr, Vector2(0, HDR_H),     Vector2(W, 2), C_CRIMSON)

	_lbl(hdr, "⚔  ΟΠΛΟΠΩΛΕΙΟ  🛡", Vector2(0, 24), Vector2(W, 70),
		 48, C_BONE, HORIZONTAL_ALIGNMENT_CENTER, Color(0,0,0,0.92), 3, 4)

	# Κουμπί κλεισίματος
	var close_btn := Button.new()
	close_btn.text     = "✕"
	close_btn.position = Vector2(24, 26)
	close_btn.size     = Vector2(64, 64)
	_style_iron(close_btn)
	close_btn.add_theme_font_size_override("font_size", 32)
	hdr.add_child(close_btn)
	close_btn.pressed.connect(_close)

	_build_currency_strip(hdr)

func _build_currency_strip(hdr: Control) -> void:
	_currency_strip = Control.new()
	_currency_strip.position = Vector2(24, 106)
	_currency_strip.size     = Vector2(W - 48, 108)
	_currency_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(_currency_strip)

	var count: int = Currency.ORDER.size()
	var gap := 14.0
	var badge_w: float = (_currency_strip.size.x - gap * (count - 1)) / count

	for i in range(count):
		var currency: String = Currency.ORDER[i]
		var bx: float = i * (badge_w + gap)

		var badge := Panel.new()
		badge.position = Vector2(bx, 0)
		badge.size     = Vector2(badge_w, 108)
		badge.add_theme_stylebox_override("panel", _sb(C_DARK, Currency.COLORS.get(currency, C_GOLD_D).darkened(0.2), 3, 10))
		_currency_strip.add_child(badge)

		_lbl(badge, str(Currency.ICONS.get(currency, "•")), Vector2(0, 8), Vector2(badge_w, 40),
			 26, Currency.COLORS.get(currency, C_GOLD), HORIZONTAL_ALIGNMENT_CENTER)

		var amount_lbl := _lbl(badge, "", Vector2(0, 46), Vector2(badge_w, 34),
			 26, C_BONE, HORIZONTAL_ALIGNMENT_CENTER, Color(0,0,0,0.85), 1, 1)
		_currency_labels[currency] = amount_lbl

	_update_currency_labels()

func _update_currency_labels() -> void:
	for currency in _currency_labels:
		(_currency_labels[currency] as Label).text = str(Currency.get_amount(currency))

func _build_tabs() -> void:
	var bar := Panel.new()
	bar.position = Vector2(0, HDR_H + 6)
	bar.size     = Vector2(W, TAB_H)
	bar.add_theme_stylebox_override("panel", _sb(Color(0.048, 0.032, 0.015, 0.90), C0, 0))
	add_child(bar)

	_tab_weapons = _tab_button("⚔  ΟΠΛΑ", Vector2(40, 10), Vector2(480, 76))
	bar.add_child(_tab_weapons)
	_tab_weapons.pressed.connect(func(): _set_category("weapons"))

	_tab_armor = _tab_button("🛡  ΠΑΝΟΠΛΙΕΣ", Vector2(560, 10), Vector2(480, 76))
	bar.add_child(_tab_armor)
	_tab_armor.pressed.connect(func(): _set_category("armor"))

	_update_tabs()

func _build_grid_area() -> void:
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, HDR_H + TAB_H + 16)
	_scroll.size     = Vector2(W, H - HDR_H - TAB_H - 16)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_scroll.add_child(margin)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 20)
	_grid.add_theme_constant_override("v_separation", 20)
	margin.add_child(_grid)

# ═══════════════════════════════════════════════════════════════
# ΛΟΓΙΚΗ ΚΑΤΗΓΟΡΙΩΝ / ΠΛΕΓΜΑΤΟΣ
# ═══════════════════════════════════════════════════════════════
func _set_category(cat: String) -> void:
	if _category == cat:
		return
	_category = cat
	_update_tabs()
	_refresh_grid()

func _update_tabs() -> void:
	_style_iron(_tab_weapons, _category == "weapons")
	_style_iron(_tab_armor,   _category == "armor")

func _refresh_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var items: Array[Dictionary] = WEAPONS if _category == "weapons" else ARMOR
	for item in items:
		_grid.add_child(_make_item_card(item))

# ═══════════════════════════════════════════════════════════════
# ΚΑΡΤΑ ΑΝΤΙΚΕΙΜΕΝΟΥ
# ═══════════════════════════════════════════════════════════════
func _make_item_card(item: Dictionary) -> Control:
	const CW := 490.0
	const CH := 320.0

	var card := Panel.new()
	card.custom_minimum_size = Vector2(CW, CH)
	card.add_theme_stylebox_override("panel", _sb(C_DARK, C_GOLD_D, 3, 10))

	# Εικονίδιο
	var icon_bg := Panel.new()
	icon_bg.position = Vector2(20, 20)
	icon_bg.size     = Vector2(90, 90)
	icon_bg.add_theme_stylebox_override("panel", _sb(C_MID, C_BRONZE, 2, 45))
	card.add_child(icon_bg)
	_lbl(icon_bg, str(item["icon"]), Vector2(0, 0), Vector2(90, 90),
		 44, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)

	# Όνομα
	_lbl(card, str(item["name"]), Vector2(122, 20), Vector2(CW - 140, 40),
		 26, C_BONE, HORIZONTAL_ALIGNMENT_LEFT)
	# Στατιστικό
	_lbl(card, str(item["desc"]), Vector2(122, 60), Vector2(CW - 140, 32),
		 20, C_SILVER, HORIZONTAL_ALIGNMENT_LEFT)

	# Διαχωριστής
	_cr(card, Vector2(20, 128), Vector2(CW - 40, 2), C_BRONZE.darkened(0.3))

	# Κόστος (ένα ή περισσότερα νομίσματα)
	var cost: Dictionary = item["cost"]
	var parts: Array[String] = []
	for currency in Currency.ORDER:
		if cost.has(currency):
			parts.append("%s %d" % [Currency.ICONS.get(currency, "•"), int(cost[currency])])
	_lbl(card, "   ".join(parts), Vector2(20, 146), Vector2(CW - 40, 40),
		 24, C_GOLD, HORIZONTAL_ALIGNMENT_LEFT)

	# Κουμπί αγοράς
	var owned: bool = Inventory.owned_items.has(str(item["id"]))
	var buy := Button.new()
	buy.position = Vector2(20, CH - 76)
	buy.size     = Vector2(CW - 40, 56)
	buy.text     = "ΑΓΟΡΑΣΜΕΝΟ" if owned else "ΑΓΟΡΑ"
	buy.disabled = owned
	_style_iron(buy, not owned)
	card.add_child(buy)
	if not owned:
		buy.pressed.connect(func(): _buy_item(item, buy))

	return card

func _buy_item(item: Dictionary, buy_btn: Button) -> void:
	var cost: Dictionary = item["cost"]
	if not Currency.spend(cost):
		_flash_insufficient()
		return
	Inventory.add_item(str(item["id"]))
	buy_btn.text     = "ΑΓΟΡΑΣΜΕΝΟ"
	buy_btn.disabled = true
	_style_iron(buy_btn, false)

func _flash_insufficient() -> void:
	var tw := create_tween()
	tw.tween_property(_currency_strip, "modulate", Color(1, 0.3, 0.3), 0.12)
	tw.tween_property(_currency_strip, "modulate", Color(1, 1, 1), 0.25)

# ═══════════════════════════════════════════════════════════════
# ΒΟΗΘΗΤΙΚΕΣ ΣΥΝΑΡΤΗΣΕΙΣ
# ═══════════════════════════════════════════════════════════════
func _tab_button(txt: String, pos: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	b.text     = txt
	b.position = pos
	b.size     = sz
	b.add_theme_font_size_override("font_size", 32)
	return b

func _sb(bg: Color, border: Color, bw: int, cr: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(cr)
	return s

func _cr(parent: Control, pos: Vector2, sz: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.position = pos
	r.size     = sz
	r.color    = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)

func _lbl(parent: Control, text: String, pos: Vector2, sz: Vector2, font_sz: int,
		  col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
		  shadow: Color = Color(0,0,0,0), sx: int = 0, sy: int = 0) -> Label:
	var l := Label.new()
	l.text     = text
	l.position = pos
	l.size     = sz
	l.horizontal_alignment = align
	l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_sz)
	l.add_theme_color_override("font_color", col)
	if shadow.a > 0:
		l.add_theme_color_override("font_shadow_color", shadow)
		l.add_theme_constant_override("shadow_offset_x", sx)
		l.add_theme_constant_override("shadow_offset_y", sy)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _style_iron(btn: Button, golden: bool = false) -> void:
	var trim  := C_GOLD if golden else C_SILVER
	var fcol  := C_GOLD if golden else C_BONE

	var n := _sb(C_IRON, trim.darkened(0.22), 4, 6)
	n.shadow_color = Color(0,0,0,0.72)
	n.shadow_size  = 6
	btn.add_theme_stylebox_override("normal", n)

	var h := _sb(C_IRON_L, trim, 5, 6)
	h.shadow_color = trim.lightened(0.08)
	h.shadow_size  = 12
	btn.add_theme_stylebox_override("hover", h)

	btn.add_theme_stylebox_override("pressed", _sb(Color(0.06, 0.04, 0.02), trim.darkened(0.28), 3, 6))
	btn.add_theme_stylebox_override("disabled", _sb(Color(0.10, 0.09, 0.08), C_BRONZE.darkened(0.5), 3, 6))
	btn.add_theme_stylebox_override("focus", _sb(C0, C0, 0, 0))

	btn.add_theme_color_override("font_color",          fcol)
	btn.add_theme_color_override("font_hover_color",    C_GOLD if golden else C_SILVER.lightened(0.18))
	btn.add_theme_color_override("font_pressed_color",  fcol.darkened(0.32))
	btn.add_theme_color_override("font_disabled_color", C_BRONZE)
	btn.add_theme_color_override("font_shadow_color",   Color(0,0,0,0.92))
	btn.add_theme_constant_override("shadow_offset_x", 2)
	btn.add_theme_constant_override("shadow_offset_y", 3)
