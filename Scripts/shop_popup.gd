extends Control

# Popup "Κατάστημα": αγορά όπλων ΚΑΙ πανοπλιών. Και τα δύο έρχονται δυναμικά
# από τα WeaponInventory/ArmorInventory autoloads (Scripts/weapon_inventory.gd,
# Scripts/armor_inventory.gd) — ίδια αρχιτεκτονική και για τα δύο (κοινή βάση
# Scripts/equipment_catalog.gd). Κάθε κατηγορία έχει ξεχωριστά αγοράσιμα
# αντικείμενα (ένα ανά old_level). Το Shop ΜΟΝΟ πουλάει· η αναβάθμιση/πώληση
# γίνεται αποκλειστικά στο Inventory.

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
# ── Mobile-first μεγέθη (Android, portrait 1080×1920) ───────────────────────
# Ο καμβάς 1080 πλάτος αντιστοιχεί σε οθόνη ~1080 φυσικών pixel (xxhdpi, 3×),
# άρα το ελάχιστο άνετο touch target των 48dp = ~144px ΕΔΩ. Κάθε πατήσιμο
# στοιχείο κρατιέται στα ~116-130px (κοντά στο όριο, χωρίς να τρώει την οθόνη)
# και τα κείμενα στα 26-34 (τα παλιά 20-27 ήταν δυσανάγνωστα στο κινητό).
const HDR_H := 240.0
const TAB_H := 140.0
const BTN_H := 120.0        # ύψος κουμπιού ΑΓΟΡΑ/ΣΤΡΑΤΟΛΟΓΗΣΗ
const CARD_W := 490.0       # 2 στήλες: 30 + 490 + 20 + 490 + 30 = 1080
const CARD_H := 580.0

var _category := "weapons"

var _currency_strip: Control
var _currency_labels := {}   # currency name -> Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _tab_weapons: Button
var _tab_armor: Button
var _tab_characters: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	Currency.changed.connect(_update_currency_labels)
	WeaponInventory.changed.connect(_on_equipment_changed)
	ArmorInventory.changed.connect(_on_equipment_changed)
	# Ανανέωση της καρτέλας Χαρακτήρων όταν αλλάζει το roster (π.χ. μετά από αγορά).
	Heroes.changed.connect(_on_equipment_changed)

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

func _current_catalog() -> EquipmentCatalog:
	if _category == "weapons":
		return WeaponInventory
	return ArmorInventory

# ═══════════════════════════════════════════════════════════════
# ΚΑΤΑΣΚΕΥΗ UI
# ═══════════════════════════════════════════════════════════════
func _build() -> void:
	_build_dim()
	_build_header()
	_build_tabs()
	_build_grid_area()
	_layout_grid_area()
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

	# Κουμπί κλεισίματος — 100×100, άνετο μέγεθος δαχτύλου
	var close_btn := Button.new()
	close_btn.text     = "✕"
	close_btn.position = Vector2(20, 14)
	close_btn.size     = Vector2(100, 100)
	_style_iron(close_btn)
	close_btn.add_theme_font_size_override("font_size", 46)
	hdr.add_child(close_btn)
	close_btn.pressed.connect(_close)

	_build_currency_strip(hdr)

# Τα υλικά που αφορούν το Shop (η αγορά γίνεται αποκλειστικά σε Χαλκό — βλ.
# EquipmentCatalog.buy) ΚΑΙ το Κέρμα: δεν ξοδεύεται εδώ (μόνο σε boss retries,
# βλ. boss_popup.gd/mini_boss_popup.gd), αλλά φαίνεται ώστε ο παίκτης να ξέρει
# πόσο έχει μαζέψει χωρίς να ανοίξει την Αποθήκη. Όχι Κλειδιά — δεν αφορούν
# καθόλου το Shop. Ίδια σχετική σειρά με το Currency.ORDER.
const STRIP_CURRENCIES: Array[String] = ["Χαλκός", "Δέρμα", "Σίδερο", "Κέρμα"]

# Το νόμισμα ΚΑΘΕ τιμής του Shop (όπλα, πανοπλίες, ήρωες) — βλ.
# EquipmentCatalog.buy / Heroes.HERO_PRICE_CURRENCY. Μία σταθερά ώστε να μη
# σκορπίζεται το literal "Χαλκός" στις κάρτες.
const PRICE_CURRENCY := "Χαλκός"

func _build_currency_strip(hdr: Control) -> void:
	_currency_strip = Control.new()
	_currency_strip.position = Vector2(24, 104)
	_currency_strip.size     = Vector2(W - 48, 122)
	_currency_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(_currency_strip)

	var count: int = STRIP_CURRENCIES.size()
	var gap := 14.0
	# Με λίγα badges το ισομοιρασμένο πλάτος θα έβγαινε υπερβολικά φαρδύ —
	# περιορίζεται και η ομάδα κεντράρεται στο strip.
	var badge_w: float = minf((_currency_strip.size.x - gap * (count - 1)) / count, 220.0)
	var x0: float = (_currency_strip.size.x - (badge_w * count + gap * (count - 1))) / 2.0

	for i in range(count):
		var currency: String = STRIP_CURRENCIES[i]
		var bx: float = x0 + i * (badge_w + gap)

		var badge := Panel.new()
		badge.position = Vector2(bx, 0)
		badge.size     = Vector2(badge_w, 122)
		badge.add_theme_stylebox_override("panel", _sb(C_DARK, Currency.COLORS.get(currency, C_GOLD_D).darkened(0.2), 3, 10))
		_currency_strip.add_child(badge)

		# Εικόνα-εικονίδιο πόρου αν υπάρχει (Currency.TEXTURE_ICONS), αλλιώς
		# το παλιό text/emoji εικονίδιο.
		var icon_tex := Currency.get_icon_texture(currency)
		if icon_tex:
			var icon := TextureRect.new()
			icon.texture  = icon_tex
			# ΠΡΟΣΟΧΗ στη σειρά: το expand_mode πρέπει να οριστεί ΠΡΙΝ το
			# size — αλλιώς το minimum size της υφής (~1000px!) «κλειδώνει»
			# το size στο φυσικό μέγεθος της εικόνας και το εικονίδιο
			# ζωγραφίζεται τεράστιο πάνω από όλο το UI.
			icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.position = Vector2((badge_w - 56.0) / 2.0, 8)
			icon.size     = Vector2(56, 56)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.add_child(icon)
		else:
			_lbl(badge, str(Currency.ICONS.get(currency, "•")), Vector2(0, 8), Vector2(badge_w, 52),
				 34, Currency.COLORS.get(currency, C_GOLD), HORIZONTAL_ALIGNMENT_CENTER)

		var amount_lbl := _lbl(badge, "", Vector2(0, 66), Vector2(badge_w, 48),
			 36, C_BONE, HORIZONTAL_ALIGNMENT_CENTER, Color(0,0,0,0.85), 1, 1)
		_currency_labels[currency] = amount_lbl

	_update_currency_labels()

func _update_currency_labels() -> void:
	for currency in _currency_labels:
		(_currency_labels[currency] as Label).text = str(Currency.get_amount(currency))

## Τιμή κάρτας: αριθμός + η ΠΡΑΓΜΑΤΙΚΗ εικόνα του Χαλκού (copper.png), αντί για
## το παλιό emoji "🪙" — που είναι ΧΡΥΣΟ νόμισμα, ενώ χρυσός δεν υπάρχει πια στο
## παιχνίδι (τα πάντα τιμολογούνται σε Χαλκό). Ίδιος αγωγός εικόνας με το
## currency strip παραπάνω (Currency.get_icon_texture), ώστε το εικονίδιο της
## τιμής και το εικονίδιο του αποθέματος να είναι πάντα η ΙΔΙΑ εικόνα.
## Το emoji μένει ως fallback μόνο αν λείψει το PNG.
func _price_row(parent: Control, amount: int, pos: Vector2, sz: Vector2, font_sz: int, col: Color) -> void:
	var box := HBoxContainer.new()
	box.position  = pos
	box.size      = sz
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)

	var amount_lbl := Label.new()
	amount_lbl.text = str(amount)
	amount_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount_lbl.add_theme_font_size_override("font_size", font_sz)
	amount_lbl.add_theme_color_override("font_color", col)
	amount_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	amount_lbl.add_theme_constant_override("shadow_offset_x", 1)
	amount_lbl.add_theme_constant_override("shadow_offset_y", 1)
	amount_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(amount_lbl)

	var icon_tex := Currency.get_icon_texture(PRICE_CURRENCY)
	if icon_tex == null:
		var fallback := Label.new()
		fallback.text = str(Currency.ICONS.get(PRICE_CURRENCY, "•"))
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", font_sz)
		fallback.add_theme_color_override("font_color", col)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(fallback)
		return

	var icon := TextureRect.new()
	icon.texture = icon_tex
	# EXPAND_IGNORE_SIZE ΠΡΙΝ το custom_minimum_size: το copper.png είναι
	# 1008×1055, οπότε χωρίς αυτό το minimum size της υφής «κλειδώνει» το
	# πλαίσιο στο φυσικό μέγεθος και το εικονίδιο ζωγραφίζεται τεράστιο πάνω
	# από την κάρτα (ίδια νάρκη με το currency strip παραπάνω).
	icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(font_sz + 6, font_sz + 6)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

func _build_tabs() -> void:
	var bar := Panel.new()
	bar.position = Vector2(0, HDR_H + 6)
	bar.size     = Vector2(W, TAB_H)
	bar.add_theme_stylebox_override("panel", _sb(Color(0.048, 0.032, 0.015, 0.90), C0, 0))
	add_child(bar)

	# Τρία tabs στο πλάτος 1080 (~344 το καθένα), ύψος 116 — άνετος στόχος για
	# δάχτυλο (τα παλιά 90 ήταν μόλις ~30dp).
	_tab_weapons = _tab_button("⚔  ΟΠΛΑ", Vector2(16, 12), Vector2(344, 116))
	bar.add_child(_tab_weapons)
	_tab_weapons.pressed.connect(func(): _set_category("weapons"))

	_tab_armor = _tab_button("🛡  ΠΑΝΟΠΛΙΕΣ", Vector2(368, 12), Vector2(344, 116))
	bar.add_child(_tab_armor)
	_tab_armor.pressed.connect(func(): _set_category("armor"))

	_tab_characters = _tab_button("🧑  ΗΡΩΕΣ", Vector2(720, 12), Vector2(344, 116))
	bar.add_child(_tab_characters)
	_tab_characters.pressed.connect(func(): _set_category("characters"))

	_update_tabs()

func _build_grid_area() -> void:
	_scroll = ScrollContainer.new()
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
	_layout_grid_area()
	_refresh_grid()

func _update_tabs() -> void:
	_style_iron(_tab_weapons,    _category == "weapons")
	_style_iron(_tab_armor,      _category == "armor")
	_style_iron(_tab_characters, _category == "characters")

## Η κάτω περιοχή (grid) ξεκινάει ακριβώς κάτω από τα tabs (Όπλα/Πανοπλίες/
## Ήρωες) — δεν υπάρχει πλέον γραμμή υπο-κατηγοριών.
func _layout_grid_area() -> void:
	var top := HDR_H + TAB_H + 16
	_scroll.position = Vector2(0, top)
	_scroll.size     = Vector2(W, H - top)

func _refresh_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	if _category == "characters":
		for def in Heroes.HERO_DEFS:
			_grid.add_child(_make_hero_card(def))
		return
	var catalog := _current_catalog()
	# Όλα τα αντικείμενα όλων των κατηγοριών του καταλόγου μαζί — δεν υπάρχουν
	# πλέον υπο-κατηγορίες.
	for category in catalog.categories:
		for id in catalog.get_items_in_category(category):
			_grid.add_child(_make_equipment_card(catalog, id))

func _on_equipment_changed() -> void:
	_refresh_grid()

# ═══════════════════════════════════════════════════════════════
# ΚΑΡΤΑ ΕΞΟΠΛΙΣΜΟΥ (WeaponInventory/ArmorInventory — μόνο αγορά· η
# αναβάθμιση/πώληση γίνονται αποκλειστικά στο Inventory)
# ═══════════════════════════════════════════════════════════════
func _make_equipment_card(catalog: EquipmentCatalog, id: String) -> Control:
	var owned: bool = catalog.is_owned(id)

	var card := Panel.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	# clip_contents: τα fantasy ονόματα είναι συχνά μακριά — με το autowrap
	# παρακάτω μένουν μέσα, αλλά αν ξεφύγει κάτι κόβεται στην άκρη της κάρτας
	# αντί να ζωγραφιστεί πάνω στη διπλανή.
	card.clip_contents = true
	card.add_theme_stylebox_override("panel", _sb(C_DARK, C_GOLD_D if owned else C_GOLD_D.darkened(0.25), 3, 10))

	var icon := TextureRect.new()
	# EXPAND_IGNORE_SIZE ΠΡΙΝ το size (αλλιώς το minimum size της υφής κλειδώνει
	# το πλαίσιο στο φυσικό μέγεθος της εικόνας).
	icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(20, 16)
	icon.size     = Vector2(CARD_W - 40, 200)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_path := catalog.get_icon_path(id)
	if ResourceLoader.exists(icon_path):
		# ΙΔΙΟ auto-crop pipeline με το Inventory (Inventory.get_item_texture):
		# τα PNG εξοπλισμού είναι μεγάλος, κατά κύριο λόγο ΔΙΑΦΑΝΗΣ καμβάς, οπότε
		# η ακατέργαστη υφή εμφανιζόταν μικροσκοπική μέσα στο πλαίσιο (ιδίως οι
		# πανοπλίες). Το crop στο πραγματικό bounding box τη "γεμίζει".
		icon.texture = Inventory.get_item_texture({"avatar_overlay": icon_path})
	card.add_child(icon)

	# Όνομα — 2 γραμμές με autowrap ώστε τα μακριά ονόματα να μη ξεχειλίζουν.
	var name_lbl := _lbl(card, catalog.get_item_name(id), Vector2(16, 224), Vector2(CARD_W - 32, 84),
		 32, C_BONE, HORIZONTAL_ALIGNMENT_CENTER)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_lbl(card, "%s %s %d" % [catalog.stat_icon, catalog.stat_label, catalog.get_base_stat(id)],
		 Vector2(20, 312), Vector2(CARD_W - 40, 40), 28, C_SILVER, HORIZONTAL_ALIGNMENT_CENTER)

	if owned:
		_lbl(card, "Κατοχή — Επίπεδο %d/%d" % [catalog.get_tier(id), catalog.UPGRADE_MAX_TIER],
			 Vector2(20, 356), Vector2(CARD_W - 40, 44), 26, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_price_row(card, catalog.get_base_price(id), Vector2(20, 356), Vector2(CARD_W - 40, 44), 34, C_GOLD)

	var buy := Button.new()
	buy.position = Vector2(20, CARD_H - BTN_H - 20)
	buy.size     = Vector2(CARD_W - 40, BTN_H)
	buy.text     = "ΑΓΟΡΑΣΜΕΝΟ" if owned else "ΑΓΟΡΑ"
	buy.add_theme_font_size_override("font_size", 34)
	buy.disabled = owned
	_style_iron(buy, not owned)
	card.add_child(buy)
	if not owned:
		buy.pressed.connect(func(): _buy(catalog, id))

	return card

func _buy(catalog: EquipmentCatalog, id: String) -> void:
	if not catalog.buy(id):
		_flash_insufficient()

# ═══════════════════════════════════════════════════════════════
# ΚΑΡΤΑ ΗΡΩΑ (tab "Χαρακτήρες") — αγορά προσθέτει νέο ήρωα στο roster με
# ΤΥΧΑΙΑ stats (η λογική ζει στο Heroes.buy_hero). Κάθε ήρωας αγοράζεται
# ΜΙΑ φορά· μετά την αγορά η κάρτα δείχνει "ΣΤΡΑΤΟΛΟΓΗΘΗΚΕ" και ανενεργό
# κουμπί (ίδιο μοτίβο με την κάρτα εξοπλισμού). Η ανανέωση γίνεται μέσω του
# Heroes.changed -> _on_equipment_changed.
# ═══════════════════════════════════════════════════════════════
func _make_hero_card(def: Dictionary) -> Control:
	var owned: bool = Heroes.owns_hero_def(str(def["id"]))

	var card := Panel.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.clip_contents = true
	card.add_theme_stylebox_override("panel", _sb(C_DARK, C_GOLD_D if owned else C_GOLD_D.darkened(0.25), 3, 10))

	var icon := TextureRect.new()
	icon.position = Vector2(20, 16)
	icon.size     = Vector2(CARD_W - 40, 200)
	icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var av := GameData.get_cropped_texture(str(def["avatar"]))
	if av != null:
		icon.texture = av
	card.add_child(icon)

	var name_lbl := _lbl(card, str(def["name"]), Vector2(16, 224), Vector2(CARD_W - 32, 84),
		 32, C_BONE, HORIZONTAL_ALIGNMENT_CENTER)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Τα ΠΡΑΓΜΑΤΙΚΑ stats που θα πάρει ο παίκτης (Heroes.get_offer_stats — τα
	# ρίχνει μία φορά και τα κρατάει, οπότε δεν «χορεύουν» σε κάθε redraw και
	# η αγορά δίνει ΑΚΡΙΒΩΣ αυτά).
	var st := Heroes.get_offer_stats(str(def["id"]))
	_lbl(card, "%s %d   %s %d   %s %d   %s %d" % [
			Heroes.STAT_ICONS["HP"], int(st["HP"]),
			Heroes.STAT_ICONS["Damage"], int(st["Damage"]),
			Heroes.STAT_ICONS["Shield"], int(st["Shield"]),
			Heroes.STAT_ICONS["AttackSpeed"], int(st["AttackSpeed"])],
		 Vector2(12, 312), Vector2(CARD_W - 24, 44), 28, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	if owned:
		_lbl(card, "Στο ρόστερ σου", Vector2(20, 358), Vector2(CARD_W - 40, 44),
			 30, C_SILVER, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_price_row(card, int(def["price"]), Vector2(20, 358), Vector2(CARD_W - 40, 44), 34, C_GOLD)

	var buy := Button.new()
	buy.position = Vector2(20, CARD_H - BTN_H - 20)
	buy.size     = Vector2(CARD_W - 40, BTN_H)
	buy.text     = "ΣΤΡΑΤΟΛΟΓΗΘΗΚΕ" if owned else "ΣΤΡΑΤΟΛΟΓΗΣΗ"
	buy.add_theme_font_size_override("font_size", 30)
	buy.disabled = owned
	_style_iron(buy, not owned)
	card.add_child(buy)
	if not owned:
		buy.pressed.connect(func(): _buy_hero(str(def["id"])))

	return card

func _buy_hero(def_id: String) -> void:
	if Heroes.buy_hero(def_id) == "":
		_flash_insufficient()

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
	b.add_theme_font_size_override("font_size", 34)
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
