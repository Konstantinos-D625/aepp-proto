extends Control
class_name HeroSlotPopup

# ═══════════════════════════════════════════════════════════════════════════
# HeroSlotPopup — modal για μία party θέση (slot)
# ═══════════════════════════════════════════════════════════════════════════
# Ανοίγει πατώντας ένα ξεκλείδωτο slot στην οθόνη «Characters» (party grid).
# Εδώ ο παίκτης:
#   1. Διαλέγει ΠΟΙΟΝ ήρωα (από το roster) βάζει στη θέση, ή την αφήνει κενή.
#   2. Βλέπει τα 4 stats του ήρωα (base + buff από items).
#   3. Εξοπλίζει έως 2 items (όπλα Ή πανοπλίες) που δίνουν προσωρινό buff.
#
# Όλη η λογική/persistence ζει στο Heroes autoload· εδώ είναι ΜΟΝΟ UI. Κάθε
# ενέργεια (assign/equip) καλεί το Heroes και μετά _rebuild() για ανανέωση.

const C0       := Color(0, 0, 0, 0)
const C_DIM    := Color(0, 0, 0, 0.68)
const C_DARK   := Color(0.055, 0.038, 0.018)
const C_MID    := Color(0.095, 0.068, 0.035)
const C_IRON   := Color(0.185, 0.168, 0.140)
const C_PARCH  := Color(0.950, 0.910, 0.740)
const C_BRONZE := Color(0.435, 0.308, 0.072)
const C_GOLD   := Color(0.820, 0.645, 0.118)
const C_GOLD_S := Color(1.000, 0.920, 0.560)
const C_GOLD_D := Color(0.268, 0.192, 0.032)
const C_BONE   := Color(0.868, 0.830, 0.685)
const C_BONE_D := Color(0.470, 0.430, 0.330)
const C_OK     := Color(0.42, 0.78, 0.40)
const C_BUFF   := Color(0.46, 0.80, 0.46)

const W := 1080.0
const H := 1920.0

# Panel geometry
const PX := 60.0
const PY := 150.0
const PW := 960.0
const PH := 1560.0

var _slot := -1
var _content: Control          # καθαρίζεται/ξαναχτίζεται σε κάθε _rebuild
var _picker_overlay: Control    # ενεργό όταν διαλέγεις item

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func open(slot_index: int) -> void:
	_slot = slot_index
	visible = true
	_rebuild()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)

func _close() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.20)
	tw.tween_callback(func(): visible = false)

# ═══════════════════════════════════════════════════════════════════════════
func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_picker_overlay = null

	# Dim (κλείνει με κλικ έξω)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = C_DIM
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_close())
	add_child(dim)

	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	# Κύριο panel
	_panel(_content, Vector2(PX + 6, PY + 8), Vector2(PW, PH), Color(0,0,0,0.6), C0, 0, 10)
	_panel(_content, Vector2(PX, PY), Vector2(PW, PH), C_DARK, C_GOLD, 5, 10)
	_panel(_content, Vector2(PX + 10, PY + 10), Vector2(PW - 20, PH - 20), C0, C_GOLD_D, 2, 8)

	var hero := Heroes.get_slot_hero(_slot)

	# ── Header: τίτλος + X ──────────────────────────────────────────────
	_panel(_content, Vector2(PX + 24, PY + 24), Vector2(PW - 48, 74), C_MID, C_BRONZE, 2, 8)
	_label(_content, "ΘΕΣΗ %d" % (_slot + 1), Vector2(PX + 24, PY + 24), Vector2(PW - 48, 74),
		32, C_GOLD_S, HORIZONTAL_ALIGNMENT_CENTER, Color(0,0,0,0.9), 1, 2)
	var x_btn := Button.new()
	x_btn.text = "✕"
	x_btn.position = Vector2(PX + PW - 96, PY + 26)
	x_btn.size = Vector2(70, 70)
	x_btn.add_theme_font_size_override("font_size", 34)
	_style_btn(x_btn)
	x_btn.pressed.connect(_close)
	_content.add_child(x_btn)

	# ── Επιλογέας ήρωα (roster + «Κενή») ────────────────────────────────
	var y := PY + 118.0
	_label(_content, "Ήρωας στη θέση:", Vector2(PX + 30, y), Vector2(PW - 60, 40),
		24, C_BONE_D, HORIZONTAL_ALIGNMENT_LEFT)
	y += 48
	_build_hero_selector(y)
	y += 236

	# ── Πορτρέτο + stats (ή μήνυμα «κενή θέση») ─────────────────────────
	if hero.is_empty():
		_label(_content, "— Κενή θέση —\n\nΔιάλεξε έναν ήρωα από πάνω.",
			Vector2(PX + 40, y + 60), Vector2(PW - 80, 300), 30, C_BONE_D,
			HORIZONTAL_ALIGNMENT_CENTER)
		return

	_build_portrait_and_stats(hero, y)
	y += 470

	# ── 2 item slots ────────────────────────────────────────────────────
	_label(_content, "Αντικείμενα (προσωρινό buff):", Vector2(PX + 30, y), Vector2(PW - 60, 40),
		24, C_BONE_D, HORIZONTAL_ALIGNMENT_LEFT)
	y += 50
	var iw := (PW - 60 - 24) / 2.0
	for idx in range(Heroes.ITEMS_PER_HERO):
		_build_item_slot(hero, idx, PX + 30 + idx * (iw + 24), y, iw)

## Οριζόντια λίστα roster (κάθε ήρωας = κουμπί με avatar+όνομα) + «Κενή».
func _build_hero_selector(y: float) -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(PX + 24, y)
	scroll.size = Vector2(PW - 48, 210)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	scroll.add_child(row)

	var current := Heroes.get_slot_uid(_slot)
	# «Κενή» επιλογή
	row.add_child(_selector_card("", "Κενή", null, current == ""))
	for h in Heroes.get_roster():
		var uid: String = h["uid"]
		row.add_child(_selector_card(uid, str(h["name"]), Heroes.hero_texture(h), current == uid))

func _selector_card(uid: String, name_text: String, tex: Texture2D, selected: bool) -> Control:
	var card := Button.new()
	card.custom_minimum_size = Vector2(160, 200)
	card.flat = true
	var border := C_GOLD if selected else C_GOLD_D
	card.add_theme_stylebox_override("normal",  _sb(C_MID if selected else C_DARK, border, 3, 8))
	card.add_theme_stylebox_override("hover",   _sb(C_IRON, C_GOLD, 3, 8))
	card.add_theme_stylebox_override("pressed", _sb(C_DARK, border, 3, 8))
	card.add_theme_stylebox_override("focus",   _sb(C0, C0, 0, 0))
	card.pressed.connect(func():
		Heroes.assign_to_slot(_slot, uid)
		_rebuild())

	if tex != null:
		var art := TextureRect.new()
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture = tex
		art.position = Vector2(20, 12)
		art.size = Vector2(120, 130)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(art)
	else:
		_label(card, "∅", Vector2(0, 12), Vector2(160, 130), 60, C_BONE_D, HORIZONTAL_ALIGNMENT_CENTER)
	_label(card, name_text, Vector2(4, 150), Vector2(152, 44), 20,
		C_BONE if selected else C_BONE_D, HORIZONTAL_ALIGNMENT_CENTER)
	if selected:
		_label(card, "✔", Vector2(122, 8), Vector2(30, 30), 22, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	return card

func _build_portrait_and_stats(hero: Dictionary, y: float) -> void:
	# Portrait αριστερά
	_panel(_content, Vector2(PX + 30, y), Vector2(320, 400), C_DARK, C_BRONZE, 3, 8)
	var tex := Heroes.hero_texture(hero)
	if tex != null:
		var art := TextureRect.new()
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture = tex
		art.position = Vector2(PX + 40, y + 10)
		art.size = Vector2(300, 340)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(art)
	_label(_content, str(hero["name"]), Vector2(PX + 30, y + 352), Vector2(320, 44),
		26, C_GOLD_S, HORIZONTAL_ALIGNMENT_CENTER, Color(0,0,0,0.9), 1, 2)

	# Stats δεξιά — 4 γραμμές (label + bar + «base (+buff)»)
	var base := Heroes.get_base_stats(hero)
	var buff := Heroes.get_buff_stats(hero)
	var final := Heroes.get_final_stats(hero)
	var sx := PX + 380.0
	var sw := PW - 380.0 - 30.0
	var sy := y + 6.0
	for k in Heroes.STAT_KEYS:
		_stat_row(sx, sy, sw, k, int(base[k]), int(buff[k]), int(final[k]))
		sy += 96

## Μία γραμμή stat: εικονίδιο+όνομα, μπάρα (final/20), και «base (+buff)».
func _stat_row(x: float, y: float, w: float, key: String, base_v: int, buff_v: int, final_v: int) -> void:
	_label(_content, "%s %s" % [Heroes.STAT_ICONS[key], Heroes.STAT_LABELS[key]],
		Vector2(x, y), Vector2(w, 34), 24, C_BONE, HORIZONTAL_ALIGNMENT_LEFT)
	var val_text := str(base_v)
	if buff_v > 0:
		val_text += "  (+%d)" % buff_v
	_label(_content, val_text, Vector2(x, y), Vector2(w, 34), 24,
		C_BUFF if buff_v > 0 else C_BONE, HORIZONTAL_ALIGNMENT_RIGHT)
	# Bar background
	_panel(_content, Vector2(x, y + 42), Vector2(w, 22), Color(0,0,0,0.5), C_GOLD_D, 1, 6)
	# Bar fill (final / STAT_MAX)
	var frac: float = clampf(float(final_v) / float(Heroes.STAT_MAX), 0.0, 1.0)
	if frac > 0.0:
		var fill := ColorRect.new()
		fill.position = Vector2(x + 2, y + 44)
		fill.size = Vector2((w - 4) * frac, 18)
		fill.color = C_GOLD if buff_v == 0 else C_BUFF
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(fill)

func _build_item_slot(hero: Dictionary, idx: int, x: float, y: float, w: float) -> void:
	var item_id: String = str(hero.get("items", ["",""])[idx])
	var btn := Button.new()
	btn.position = Vector2(x, y)
	btn.size = Vector2(w, 150)
	btn.flat = true
	btn.add_theme_stylebox_override("normal",  _sb(C_DARK, C_BRONZE, 2, 8))
	btn.add_theme_stylebox_override("hover",   _sb(C_IRON, C_GOLD, 2, 8))
	btn.add_theme_stylebox_override("pressed", _sb(C_MID, C_BRONZE, 2, 8))
	btn.add_theme_stylebox_override("focus",   _sb(C0, C0, 0, 0))
	btn.pressed.connect(func(): _open_item_picker(hero, idx))
	_content.add_child(btn)

	if item_id == "":
		_label(btn, "＋\nΆδειο", Vector2(0, 0), Vector2(w, 150), 26, C_BONE_D, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var info := Heroes.item_info(item_id)
	var icon := Inventory.get_item_texture({"avatar_overlay": info.get("icon", "")})
	if icon != null:
		var art := TextureRect.new()
		# ΣΕΙΡΑ: expand_mode ΠΡΙΝ το size — αλλιώς το size κλειδώνεται στο
		# φυσικό μέγεθος της υφής (π.χ. 736×736 όπλο) και το εικονίδιο ξεχειλίζει.
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture = icon
		art.position = Vector2(10, 12)
		art.size = Vector2(120, 126)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(art)
	_label(btn, str(info.get("name", "")), Vector2(140, 18), Vector2(w - 150, 60), 22,
		C_BONE, HORIZONTAL_ALIGNMENT_LEFT)
	_label(btn, _buffs_text(info.get("buffs", {})), Vector2(140, 82), Vector2(w - 150, 56), 20,
		C_BUFF, HORIZONTAL_ALIGNMENT_LEFT)

func _buffs_text(buffs: Dictionary) -> String:
	var parts: Array[String] = []
	for k in Heroes.STAT_KEYS:
		if buffs.has(k):
			parts.append("+%d %s" % [int(buffs[k]), Heroes.STAT_LABELS[k]])
	return "\n".join(parts)

# ── Item picker overlay ─────────────────────────────────────────────────────
func _open_item_picker(hero: Dictionary, item_idx: int) -> void:
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ov)
	_picker_overlay = ov

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			ov.queue_free())
	ov.add_child(dim)

	const QX := 120.0
	const QY := 260.0
	const QW := 840.0
	const QH := 1360.0
	_panel(ov, Vector2(QX, QY), Vector2(QW, QH), C_DARK, C_GOLD, 4, 10)
	_label(ov, "Διάλεξε αντικείμενο", Vector2(QX, QY + 20), Vector2(QW, 50), 30,
		C_GOLD_S, HORIZONTAL_ALIGNMENT_CENTER)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(QX + 20, QY + 90)
	scroll.size = Vector2(QW - 40, QH - 110)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ov.add_child(scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(QW - 60, 0)
	scroll.add_child(col)

	# «Αφαίρεση» (κενό)
	col.add_child(_picker_row("", "— Αφαίρεση —", null, "", "", hero, item_idx))
	for info in Heroes.get_owned_items():
		var icon := Inventory.get_item_texture({"avatar_overlay": info.get("icon", "")})
		# Αν το item είναι ήδη εξοπλισμένο σε άλλον ήρωα, δείξε ποιον — η επιλογή
		# του εδώ θα το ΜΕΤΑΚΙΝΗΣΕΙ (κάθε item σε έναν μόνο ήρωα, βλ. Heroes.equip_item).
		var holder_uid := Heroes.hero_uid_holding_item(str(info["id"]))
		var holder_hint := ""
		if holder_uid != "" and holder_uid != str(hero["uid"]):
			holder_hint = "σε: %s" % str(Heroes.get_hero(holder_uid).get("name", ""))
		col.add_child(_picker_row(info["id"], str(info["name"]), icon, _buffs_text(info.get("buffs", {})), holder_hint, hero, item_idx))

func _picker_row(item_id: String, name_text: String, icon: Texture2D, buffs_text: String, holder_hint: String, hero: Dictionary, item_idx: int) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 130)
	btn.flat = true
	btn.add_theme_stylebox_override("normal",  _sb(C_MID, C_BRONZE, 2, 8))
	btn.add_theme_stylebox_override("hover",   _sb(C_IRON, C_GOLD, 2, 8))
	btn.add_theme_stylebox_override("pressed", _sb(C_DARK, C_BRONZE, 2, 8))
	btn.add_theme_stylebox_override("focus",   _sb(C0, C0, 0, 0))
	btn.pressed.connect(func():
		Heroes.equip_item(hero["uid"], item_idx, item_id)
		if is_instance_valid(_picker_overlay):
			_picker_overlay.queue_free()
		_rebuild())
	if icon != null:
		var art := TextureRect.new()
		# expand_mode ΠΡΙΝ το size (βλ. _build_item_slot) — αλλιώς ξεχειλίζει.
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture = icon
		art.position = Vector2(12, 8)
		art.size = Vector2(112, 112)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(art)
	_label(btn, name_text, Vector2(140, 18), Vector2(600, 50), 24, C_BONE, HORIZONTAL_ALIGNMENT_LEFT)
	if buffs_text != "":
		_label(btn, buffs_text.replace("\n", "   "), Vector2(140, 74), Vector2(400, 40), 20, C_BUFF, HORIZONTAL_ALIGNMENT_LEFT)
	if holder_hint != "":
		_label(btn, holder_hint, Vector2(540, 74), Vector2(160, 40), 19, C_BONE_D, HORIZONTAL_ALIGNMENT_RIGHT)
	return btn

# ═══════════════════════════════════════════════════════════════════════════
# PRIMITIVES
# ═══════════════════════════════════════════════════════════════════════════
func _sb(bg: Color, border: Color, bw: int, cr: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = border
	s.set_border_width_all(bw); s.set_corner_radius_all(cr)
	return s

func _panel(parent: Control, pos: Vector2, sz: Vector2, bg: Color, border: Color, bw: int, cr: int) -> void:
	var p := Panel.new()
	p.position = pos; p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _sb(bg, border, bw, cr))
	parent.add_child(p)

func _label(parent: Control, text: String, pos: Vector2, sz: Vector2, fsz: int,
			col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
			shadow: Color = Color(0,0,0,0), sx: int = 0, sy: int = 0) -> void:
	var l := Label.new()
	l.text = text; l.position = pos; l.size = sz
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", fsz)
	l.add_theme_color_override("font_color", col)
	if shadow.a > 0:
		l.add_theme_color_override("font_shadow_color", shadow)
		l.add_theme_constant_override("shadow_offset_x", sx)
		l.add_theme_constant_override("shadow_offset_y", sy)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)

func _style_btn(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal",  _sb(C_MID, C_BRONZE, 2, 8))
	btn.add_theme_stylebox_override("hover",   _sb(C_IRON, C_GOLD, 2, 8))
	btn.add_theme_stylebox_override("pressed", _sb(C_DARK, C_BRONZE, 2, 8))
	btn.add_theme_stylebox_override("focus",   _sb(C0, C0, 0, 0))
	btn.add_theme_color_override("font_color", C_GOLD_S)
	btn.add_theme_color_override("font_hover_color", C_GOLD)
