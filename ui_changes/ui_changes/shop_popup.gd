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
var _tab_friendship: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	Currency.changed.connect(_update_currency_labels)
	WeaponInventory.changed.connect(_on_equipment_changed)
	ArmorInventory.changed.connect(_on_equipment_changed)
	FriendshipInventory.changed.connect(_on_equipment_changed)
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
	if _category == "friendship":
		return FriendshipInventory
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

	# Κουμπί κλεισίματος — ΠΑΝΩ-ΔΕΞΙΑ γωνία (αίτημα χρήστη). 88×88 στο y=12..100 ώστε
	# να «καθαρίζει» κατακόρυφα το currency strip που ξεκινά στο y=104 παρακάτω.
	var close_btn := Button.new()
	close_btn.text     = "✕"
	close_btn.position = Vector2(W - 108, 12)
	close_btn.size     = Vector2(88, 88)
	_style_iron(close_btn)
	close_btn.add_theme_font_size_override("font_size", 44)
	hdr.add_child(close_btn)
	close_btn.pressed.connect(_close)

	_build_currency_strip(hdr)

# Τα υλικά που αφορούν το Shop — όλα ξοδεύονται πλέον εδώ (Χαλκός+Κέρμα σε
# ΚΑΘΕ αγορά· Δέρμα/Σίδερο στους ήρωες, βλ. EquipmentCatalog.get_purchase_cost
# / Heroes.HERO_DEFS), οπότε φαίνονται όλα στο strip ώστε ο παίκτης να ξέρει
# πόσο έχει μαζέψει χωρίς να ανοίξει την Αποθήκη. Όχι Κλειδιά — δεν αφορούν
# καθόλου το Shop. Ίδια σχετική σειρά με το Currency.ORDER.
const STRIP_CURRENCIES: Array[String] = ["Χαλκός", "Δέρμα", "Σίδερο", "Κέρμα", "Κέρμα Φιλίας"]

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

## Γραμμή τιμής κάρτας: ένα "chip" (αριθμός + εικονίδιο) ανά νόμισμα του cost
## (π.χ. {"Χαλκός": 300, "Κέρμα": 3, "Σίδερο": 15}), σε σειρά Currency.ORDER,
## μέσα στο ίδιο HBox — ώστε οι κάρτες να δείχνουν όλα τα κόστη μιας αγοράς
## μαζί (εξοπλισμός: Χαλκός+Κέρμα· ήρωες: Χαλκός+Κέρμα+υλικό). Χρησιμοποιεί
## την ΠΡΑΓΜΑΤΙΚΗ εικόνα κάθε νομίσματος (Currency.get_icon_texture, ίδιος
## αγωγός με το currency strip παραπάνω) με emoji ως fallback αν λείψει το PNG.
func _price_row(parent: Control, cost: Dictionary, pos: Vector2, sz: Vector2, font_sz: int, col: Color) -> void:
	var box := HBoxContainer.new()
	box.position  = pos
	box.size      = sz
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)

	for currency in Currency.ORDER:
		if cost.has(currency):
			_price_chip(box, currency, int(cost[currency]), font_sz, col)

func _price_chip(box: HBoxContainer, currency: String, amount: int, font_sz: int, col: Color) -> void:
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

	var icon_tex := Currency.get_icon_texture(currency)
	if icon_tex == null:
		var fallback := Label.new()
		fallback.text = str(Currency.ICONS.get(currency, "•"))
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

## Γραμμή στατιστικών (εικόνα+αριθμός ανά stat, π.χ. {"Damage": 13,
## "AttackSpeed": 5} -> [attack_icon] 13   [speed_icon] 5), σε σειρά
## Heroes.STAT_KEYS — ίδιο μοτίβο με _price_row/_price_chip, αλλά πάνω από τα
## στατιστικά ενός ήρωα/αντικειμένου αντί για νομίσματα. Χρησιμοποιεί την
## ΠΡΑΓΜΑΤΙΚΗ εικόνα κάθε στατιστικού (Heroes.get_stat_icon_texture) με emoji
## ως fallback αν λείψει το PNG. Το `stats` dict καθορίζει ποια/πόσα φαίνονται
## (π.χ. buffs αντικειμένου με 1-2 κλειδιά, ή τα πλήρη 4 stats ενός ήρωα).
func _stat_row(parent: Control, stats: Dictionary, pos: Vector2, sz: Vector2, font_sz: int, col: Color) -> void:
	var box := HBoxContainer.new()
	box.position  = pos
	box.size      = sz
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)

	for key in Heroes.STAT_KEYS:
		if stats.has(key):
			_stat_chip(box, key, int(stats[key]), font_sz, col)

func _stat_chip(box: HBoxContainer, key: String, value: int, font_sz: int, col: Color) -> void:
	var icon_tex := Heroes.get_stat_icon_texture(key)
	if icon_tex == null:
		var fallback := Label.new()
		fallback.text = str(Heroes.STAT_ICONS.get(key, "•"))
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", font_sz)
		fallback.add_theme_color_override("font_color", col)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(fallback)
	else:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		# EXPAND_IGNORE_SIZE ΠΡΙΝ το custom_minimum_size — ίδια παγίδα με τα
		# νομίσματα (βλ. _price_chip): αλλιώς το minimum size της υφής
		# κλειδώνει το πλαίσιο στο φυσικό μέγεθος.
		icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(font_sz + 6, font_sz + 6)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)

	var val_lbl := Label.new()
	val_lbl.text = str(value)
	val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_size_override("font_size", font_sz)
	val_lbl.add_theme_color_override("font_color", col)
	val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(val_lbl)

func _build_tabs() -> void:
	var bar := Panel.new()
	bar.position = Vector2(0, HDR_H + 6)
	bar.size     = Vector2(W, TAB_H)
	bar.add_theme_stylebox_override("panel", _sb(Color(0.048, 0.032, 0.015, 0.90), C0, 0))
	add_child(bar)

	# Τέσσερα tabs μοιρασμένα ΙΣΑ στο πλάτος με ΜΙΚΡΟ κενό (gap) μεταξύ τους, ώστε
	# το κείμενο κάθε tab (ιδίως το φαρδύ «ΠΑΝΟΠΛΙΕΣ») να ΜΗΝ ξεχειλίζει και να
	# πέφτει πάνω στο διπλανό. Το clip_text στο _tab_button είναι το δίχτυ
	# ασφαλείας· η μειωμένη γραμματοσειρά (βλ. _tab_button) εξασφαλίζει ότι
	# χωράει πλήρως χωρίς περικοπή.
	var side := 12.0
	var gap := 10.0            # «πολύ μικρό κενό»
	var tab_h := 116.0         # άνετος στόχος για δάχτυλο
	var tab_y := (TAB_H - tab_h) / 2.0
	var tab_w := (W - 2.0 * side - 3.0 * gap) / 4.0
	var tab_x := func(i: int) -> float: return side + i * (tab_w + gap)

	_tab_weapons = _tab_button("⚔  ΟΠΛΑ", Vector2(tab_x.call(0), tab_y), Vector2(tab_w, tab_h))
	bar.add_child(_tab_weapons)
	_tab_weapons.pressed.connect(func(): _set_category("weapons"))

	_tab_armor = _tab_button("🛡  ΠΑΝΟΠΛΙΕΣ", Vector2(tab_x.call(1), tab_y), Vector2(tab_w, tab_h))
	bar.add_child(_tab_armor)
	_tab_armor.pressed.connect(func(): _set_category("armor"))

	_tab_characters = _tab_button("🧑  ΗΡΩΕΣ", Vector2(tab_x.call(2), tab_y), Vector2(tab_w, tab_h))
	bar.add_child(_tab_characters)
	_tab_characters.pressed.connect(func(): _set_category("characters"))

	_tab_friendship = _tab_button("🤝  ΦΙΛΙΑΣ", Vector2(tab_x.call(3), tab_y), Vector2(tab_w, tab_h))
	bar.add_child(_tab_friendship)
	_tab_friendship.pressed.connect(func(): _set_category("friendship"))

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
	# IGNORE: πλαίσιο-layout χωρίς δικό του input, αλλιώς (default STOP) θα
	# σταματούσε το drag ΠΡΙΝ φτάσει στο ScrollContainer από πάνω — και το
	# scroll θα δούλευε μόνο αν άγγιζες ακριβώς έξω από κάθε κάρτα.
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(margin)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 20)
	_grid.add_theme_constant_override("v_separation", 20)
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_style_iron(_tab_friendship, _category == "friendship")

## Η κάτω περιοχή (grid) ξεκινάει ακριβώς κάτω από τα tabs (Όπλα/Πανοπλίες/
## Ήρωες/Φιλίας) — δεν υπάρχει πλέον γραμμή υπο-κατηγοριών.
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
	# πλέον υπο-κατηγορίες. Τα αποκλειστικά τρόπαια boss (is_shop_hidden, π.χ.
	# Bad Goblin Armor/Tree Magic Sphere) ΔΕΝ εμφανίζονται εδώ — παίρνονται
	# ΜΟΝΟ νικώντας το αντίστοιχο boss (βλ. boss_fight.gd). Ίδιος βρόχος και
	# για την καρτέλα «Φιλίας» (FriendshipInventory) — καμία ειδική περίπτωση.
	for category in catalog.categories:
		for id in catalog.get_items_in_category(category):
			if catalog.is_shop_hidden(id):
				continue
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
	# IGNORE: η κάρτα δεν έχει δικό της click (μόνο το "buy" παρακάτω) — έτσι
	# ένα drag πάνω στο φόντο της κάρτας φτάνει κατευθείαν στο ScrollContainer
	# αντί να «κολλάει» εδώ (mobile scroll).
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	# ΟΛΑ τα stats που δίνει το αντικείμενο όταν εξοπλιστεί (όχι μόνο το
	# πρωτεύον Επίθεση/Άμυνα του καταλόγου) — π.χ. ένα όπλο δείχνει Damage ΚΑΙ
	# AttackSpeed αν δίνει και τα δύο. Βλ. Heroes.display_item_buffs.
	_stat_row(card, Heroes.display_item_buffs(id),
		 Vector2(20, 312), Vector2(CARD_W - 40, 40), 28, C_SILVER)

	# Χωρίς αναβαθμίσεις (κανένα catalog δεν είναι πλέον upgradable) δεν έχει
	# νόημα να δείχνεται "Επίπεδο x/3" — απλό "Κατοχή".
	if owned:
		_lbl(card, "Κατοχή", Vector2(20, 356), Vector2(CARD_W - 40, 44),
			 26, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)

	# Το κουμπί δείχνει την τιμή αντί για "ΑΓΟΡΑ" όσο δεν έχει αγοραστεί (βλ.
	# _price_row παρακάτω, μπαίνει ΜΕΣΑ στο κουμπί) — μόλις αγοραστεί, δείχνει
	# "ΑΓΟΡΑΣΜΕΝΟ" όπως πριν.
	var buy := Button.new()
	buy.position = Vector2(20, CARD_H - BTN_H - 20)
	buy.size     = Vector2(CARD_W - 40, BTN_H)
	buy.text     = "ΑΓΟΡΑΣΜΕΝΟ" if owned else ""
	buy.add_theme_font_size_override("font_size", 34)
	buy.disabled = owned
	# PASS αντί για το προεπιλεγμένο STOP: το κουμπί συνεχίζει να πατιέται
	# κανονικά, αλλά ένα drag πάνω του φτάνει ΚΑΙ στο ScrollContainer (mobile
	# scroll που ξεκινάει πάνω σε κουμπί).
	buy.mouse_filter = Control.MOUSE_FILTER_PASS
	_style_iron(buy, not owned)
	card.add_child(buy)
	if not owned:
		_price_row(buy, catalog.get_purchase_cost(id), Vector2.ZERO, buy.size, 34, C_GOLD)
		buy.pressed.connect(func(): _buy(catalog, id))

	return card

func _buy(catalog: EquipmentCatalog, id: String) -> void:
	if not catalog.buy(id):
		_flash_insufficient()

# ═══════════════════════════════════════════════════════════════
# ΚΑΡΤΑ ΗΡΩΑ (tab "Χαρακτήρες") — αγορά προσθέτει νέο ήρωα στο roster με τα
# ΣΤΑΘΕΡΑ stats του HERO_DEFS (η λογική ζει στο Heroes.buy_hero). Κάθε ήρωας αγοράζεται
# ΜΙΑ φορά· μετά την αγορά η κάρτα δείχνει "ΣΤΡΑΤΟΛΟΓΗΘΗΚΕ" και ανενεργό
# κουμπί (ίδιο μοτίβο με την κάρτα εξοπλισμού). Η ανανέωση γίνεται μέσω του
# Heroes.changed -> _on_equipment_changed.
# ═══════════════════════════════════════════════════════════════
func _make_hero_card(def: Dictionary) -> Control:
	var owned: bool = Heroes.owns_hero_def(str(def["id"]))

	var card := Panel.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.clip_contents = true
	# IGNORE: βλ. σχόλιο στο _make_equipment_card — αλλιώς μπλοκάρει το mobile
	# scroll του πλέγματος όποτε το drag ξεκινάει πάνω στην κάρτα.
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	# Τα ΣΤΑΘΕΡΑ stats που θα πάρει ο παίκτης (Heroes.get_hero_stats — ίδια
	# πάντα, βλ. HERO_DEFS, οπότε η αγορά δίνει ΑΚΡΙΒΩΣ αυτά).
	var st := Heroes.get_hero_stats(str(def["id"]))
	_stat_row(card, st, Vector2(12, 312), Vector2(CARD_W - 24, 44), 28, C_GOLD)
	if owned:
		_lbl(card, "Στο ρόστερ σου", Vector2(20, 358), Vector2(CARD_W - 40, 44),
			 30, C_SILVER, HORIZONTAL_ALIGNMENT_CENTER)

	# Το κουμπί δείχνει την τιμή αντί για "ΣΤΡΑΤΟΛΟΓΗΣΗ" όσο δεν έχει αγοραστεί
	# (βλ. _price_row παρακάτω, μπαίνει ΜΕΣΑ στο κουμπί) — μόλις αγοραστεί,
	# δείχνει "ΣΤΡΑΤΟΛΟΓΗΘΗΚΕ" όπως πριν. Μικρότερη γραμματοσειρά (28) γιατί οι
	# ήρωες έχουν έως 3 νομίσματα (Χαλκός+Κέρμα+υλικό) αντί για 1.
	var buy := Button.new()
	buy.position = Vector2(20, CARD_H - BTN_H - 20)
	buy.size     = Vector2(CARD_W - 40, BTN_H)
	buy.text     = "ΣΤΡΑΤΟΛΟΓΗΘΗΚΕ" if owned else ""
	buy.add_theme_font_size_override("font_size", 30)
	buy.disabled = owned
	buy.mouse_filter = Control.MOUSE_FILTER_PASS
	_style_iron(buy, not owned)
	card.add_child(buy)
	if not owned:
		_price_row(buy, def["price"] as Dictionary, Vector2.ZERO, buy.size, 28, C_GOLD)
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
	# 30 (όχι 34): στο φάρδος ενός tab (~256px) το «🛡  ΠΑΝΟΠΛΙΕΣ» ξεχείλιζε στο 34
	# και έπεφτε πάνω στο «ΗΡΩΕΣ». clip_text = δίχτυ ασφαλείας ώστε ό,τι κι αν γίνει
	# το κείμενο να μένει ΜΕΣΑ στο κουμπί και να μην ακουμπά το διπλανό.
	b.add_theme_font_size_override("font_size", 30)
	b.clip_text = true
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
