extends Control

const C_PARCH := Color("f3e6c4")
const C_MUTED := Color("cdbf9a")
const C_GOLD  := Color("f2c84b")
const C_EMPTY := Color(0, 0, 0, 0.35)

var _confirm_overlay: Control

const CATEGORY_CHARACTERS := "characters"

# Το νόμισμα κάθε τιμής της Αποθήκης (αναβάθμιση/πώληση) — βλ.
# EquipmentCatalog.upgrade/sell. Ίδια σταθερά με το shop_popup.gd.
const PRICE_CURRENCY := "Χαλκός"

# Νομίσματα/υλικά που δείχνει το strip στην κορυφή του Inventory — αντικατέστησαν
# την παλιά «Αποθήκη»/LootPopup (ό,τι έδειχνε το loot φαίνεται τώρα εδώ, ίδιο
# μοτίβο με το currency strip του Shop). Ίδιο σύνολο με το Shop.
const STRIP_CURRENCIES: Array[String] = ["Χαλκός", "Δέρμα", "Σίδερο", "Κέρμα", "Κέρμα Φιλίας"]

var _current_category := Inventory.CATEGORY_WEAPON
var _currency_amount_labels: Dictionary = {}   # currency -> Label (ποσό)

func _ready() -> void:
	hide()
	# Μοναδικό instance στο παιχνίδι — ο Character Editor το εντοπίζει μέσω
	# group αντί για hardcoded σχετικό μονοπάτι στο scene tree (είναι σε
	# διαφορετικό κλαδί: Area1/InventoryPopup vs Area1/CharacterSelect/
	# CharacterEditPopup), ώστε να ανοίγει το ΙΔΙΟ panel χωρίς δεύτερη υλοποίηση.
	add_to_group("inventory_popup")   # μοναδικό instance — εντοπίζεται μέσω group
	%WeaponsTab.pressed.connect(func(): _select_category(Inventory.CATEGORY_WEAPON))
	%ArmorTab.pressed.connect(func(): _select_category(Inventory.CATEGORY_ARMOR))
	%CharactersTab.pressed.connect(func(): _select_category(CATEGORY_CHARACTERS))
	# Το roster μπορεί να αλλάξει όσο είναι ανοιχτό το Inventory (π.χ. αγορά
	# ήρωα δεν γίνεται εδώ, αλλά κρατάμε συνέπεια αν αλλάξει εξοπλισμός ήρωα).
	Heroes.changed.connect(func() -> void:
		if visible and _current_category == CATEGORY_CHARACTERS:
			_refresh())
	%Dim.gui_input.connect(_on_dim_input)
	%CloseButton.pressed.connect(close_popup)
	# Ο WeaponInventory/ArmorInventory είναι η μοναδική πηγή αλήθειας για τον
	# εξοπλισμό — κάθε αλλαγή τους (αγορά/αναβάθμιση/πώληση) ξαναζωγραφίζει
	# αμέσως το Inventory όσο είναι ανοιχτό (και το Shop, αν είναι κι αυτό ανοιχτό).
	WeaponInventory.changed.connect(func() -> void:
		if visible:
			_refresh()
	)
	ArmorInventory.changed.connect(func() -> void:
		if visible:
			_refresh()
	)
	FriendshipInventory.changed.connect(func() -> void:
		if visible:
			_refresh()
	)
	# Αν κάποιο άλλο σύστημα αλλάξει τον εξοπλισμό (π.χ. auto-equip σε αγορά),
	# ξαναζωγραφίζονται οι κάρτες ώστε το Inventory να μένει συνεπές.
	Inventory.equipment_changed.connect(func(_slot, _id) -> void:
		if visible:
			_refresh()
	)
	# Νομίσματα/υλικά στην κορυφή (η παλιά «Αποθήκη»): ζωντανή ενημέρωση όταν
	# ξοδεύονται/κερδίζονται πόροι οπουδήποτε, ίδια πηγή με το Shop (Currency).
	Currency.changed.connect(_update_currency_strip)
	_build_currency_strip()

func open() -> void:
	_select_category(Inventory.CATEGORY_WEAPON)
	show()

## Κοινό σημείο κλεισίματος (κουμπί Χ ΚΑΙ click έξω από την κάρτα).
func close_popup() -> void:
	_close_confirm()
	hide()

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_popup()


# ═══════════════════════════════════════════════════════════════════════════
# CURRENCY STRIP (η παλιά «Αποθήκη»/LootPopup — τώρα ενσωματωμένη εδώ, ίδιο
# μοτίβο με το currency strip του Shop)
# ═══════════════════════════════════════════════════════════════════════════

## Χτίζεται ΜΙΑ φορά και μπαίνει στην κορυφή της κάρτας (μετά τον τίτλο, πριν τα
## tabs) — 4 badges (εικονίδιο + ποσό) για Χαλκός/Δέρμα/Σίδερο/Κέρμα.
func _build_currency_strip() -> void:
	var vbox := $Card/Margin/VBox as VBoxContainer
	var strip := HBoxContainer.new()
	strip.name = "CurrencyStrip"
	strip.add_theme_constant_override("separation", 12)
	vbox.add_child(strip)
	vbox.move_child(strip, 1)   # ακριβώς κάτω από τον τίτλο «Εξοπλισμός»
	for currency in STRIP_CURRENCIES:
		strip.add_child(_make_currency_badge(currency))
	_update_currency_strip()

func _make_currency_badge(currency: String) -> Control:
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(0, 72)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.28)
	sb.border_color = Currency.COLORS.get(currency, C_GOLD).darkened(0.15)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	badge.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	badge.add_child(row)

	# Εικόνα-εικονίδιο αν υπάρχει (copper/iron/leather/coin.png, Currency.
	# TEXTURE_ICONS)· αλλιώς το text/emoji fallback.
	var icon_tex := Currency.get_icon_texture(currency)
	if icon_tex:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		# expand_mode ΠΡΙΝ το size (τα PNG είναι ~1000px — αλλιώς κλειδώνει το
		# minimum size στο φυσικό μέγεθος και ξεχειλίζει, βλ. shop_popup.gd).
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(40, 40)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
	else:
		var e := Label.new()
		e.text = str(Currency.ICONS.get(currency, "•"))
		e.add_theme_font_size_override("font_size", 30)
		row.add_child(e)

	var amount := Label.new()
	amount.text = str(Currency.get_amount(currency))
	amount.add_theme_color_override("font_color", C_PARCH)
	amount.add_theme_font_size_override("font_size", 30)
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(amount)
	_currency_amount_labels[currency] = amount
	return badge

func _update_currency_strip() -> void:
	for currency in _currency_amount_labels:
		var lbl = _currency_amount_labels[currency]
		if is_instance_valid(lbl):
			(lbl as Label).text = str(Currency.get_amount(currency))

## Η καρτέλα «Όπλα» δείχνει ΚΑΙ τα Αντικείμενα Φιλίας μαζί με τα κανονικά
## όπλα (ζητήθηκε ρητά) — γι' αυτό επιστρέφει λίστα καταλόγων, όχι έναν.
func _current_catalogs() -> Array[EquipmentCatalog]:
	if _current_category == Inventory.CATEGORY_WEAPON:
		return [WeaponInventory, FriendshipInventory]
	return [ArmorInventory]

func _select_category(category: String) -> void:
	_current_category = category
	%WeaponsTab.button_pressed = category == Inventory.CATEGORY_WEAPON
	%ArmorTab.button_pressed = category == Inventory.CATEGORY_ARMOR
	%CharactersTab.button_pressed = category == CATEGORY_CHARACTERS
	_refresh()

# ═══════════════════════════════════════════════════════════════════════════
# REFRESH
# ═══════════════════════════════════════════════════════════════════════════

func _refresh() -> void:
	for c in %ItemsList.get_children():
		c.queue_free()

	# Καρτέλα «Ήρωες»: δείχνει το roster (όσους ήρωες κατέχει ο παίκτης) —
	# read-only, ανεξάρτητα από το αν είναι σε party θέση.
	if _current_category == CATEGORY_CHARACTERS:
		var roster := Heroes.get_roster()
		if roster.is_empty():
			var empty := Label.new()
			empty.text = "Δεν έχεις ήρωες ακόμα.\nΣτρατολόγησε από το Οπλοπωλείο!"
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.add_theme_font_size_override("font_size", 30)
			empty.add_theme_color_override("font_color", C_MUTED)
			%ItemsList.add_child(empty)
		else:
			for hero in roster:
				%ItemsList.add_child(_make_hero_row(hero))
		return

	# Όλα τα αντικείμενα όλων των κατηγοριών (ενδεχομένως >1 κατάλογος στο
	# «Όπλα», βλ. _current_catalogs) μαζί σε μία λίστα — δεν υπάρχουν πλέον
	# υπο-κατηγορίες. Μόνο όσα ΚΑΤΕΧΕΙ ο παίκτης (ο πλήρης κατάλογος με τα
	# ακλείδωτα φαίνεται μόνο στο Shop).
	for catalog in _current_catalogs():
		for category in catalog.categories:
			for id in catalog.get_items_in_category(category):
				if catalog.is_owned(id):
					%ItemsList.add_child(_make_equipment_card(catalog, id))

# ═══════════════════════════════════════════════════════════════════════════
# ΚΑΡΤΕΣ ΕΞΟΠΛΙΣΜΟΥ (WeaponInventory/ArmorInventory — αγορά μόνο από Shop,
# αναβάθμιση/πώληση μόνο εδώ στο Inventory)
# ═══════════════════════════════════════════════════════════════════════════

## Οριζόντια διάταξη (εικόνα αριστερά σε σταθερό τετράγωνο πλαίσιο, στήλη
## πληροφοριών δεξιά) — το ΙΔΙΟ πλαίσιο/layout όπως πριν, ΔΕΝ αλλάζει.
## Αυτό που άλλαξε είναι η ΠΗΓΗ της εικόνας: πριν φορτωνόταν η ακατέργαστη
## υφή (load(icon_path) — μεγάλος, ως επί το πλείστον διάφανος καμβάς, π.χ.
## 677×369 για πανοπλία), οπότε μέσα στο 220×220 πλαίσιο το ίδιο το
## αντικείμενο φαινόταν μικροσκοπικό. Τώρα περνάει από το ΙΔΙΟ auto-crop
## pipeline (Inventory.get_item_texture, βλ. inventory_data.gd) που ήδη
## χρησιμοποιεί το Character Editor — κόβει αυτόματα το πραγματικό
## bounding-box των μη-διάφανων pixel, οπότε το αντικείμενο "γεμίζει" το
## ΙΔΙΟ πλαίσιο πολύ περισσότερο, παραμένοντας πάντα ολόκληρο (contain-fit,
## καμία περικοπή/παραμόρφωση).
const CARD_ICON_SIZE := Vector2(220, 220)

func _make_equipment_card(catalog: EquipmentCatalog, id: String) -> Control:
	var card := _make_card_panel()

	# Όλα τα Controls εδώ μέσα (row/icon/info/labels) είναι απλά εικόνα/κείμενο
	# χωρίς δικό τους click — IGNORE σε όλα ώστε ένα drag να φτάνει πάντα στο
	# ScrollContainer από πάνω, ό,τι σημείο της κάρτας κι αν αγγίξεις (mobile
	# scroll). Μόνο τα πραγματικά κουμπιά (Αναβάθμιση/Πούλησε) μένουν PASS.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = CARD_ICON_SIZE
	# EXPAND_IGNORE_SIZE: αποσυνδέει το minimum_size από το φυσικό pixel
	# μέγεθος της υφής — χωρίς αυτό, το Godot θέτει minimum_size = μέγεθος
	# της εικόνας, αγνοώντας το custom_minimum_size παραπάνω και φουσκώνοντας
	# την κάρτα πέρα από το εξωτερικό πλαίσιο του Inventory.
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_path := catalog.get_icon_path(id)
	if ResourceLoader.exists(icon_path):
		icon.texture = Inventory.get_item_texture({"avatar_overlay": icon_path})
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 8)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = catalog.get_item_name(id)
	name_label.add_theme_color_override("font_color", C_PARCH)
	name_label.add_theme_font_size_override("font_size", 32)
	# Χωρίς autowrap, ένα μεγάλο fantasy όνομα (συχνά στην πανοπλία, π.χ.
	# "Seraphic Radiance Plate") επιβάλλει στο Label το πλήρες πλάτος του
	# κειμένου ως ελάχιστο μέγεθος — που σπρώχνει ολόκληρη τη σειρά/κάρτα
	# πλατύτερη από το διαθέσιμο πλάτος. Το εξωτερικό Card panel κάνει πλέον
	# clip (βλ. InventoryPopup.tscn), οπότε χωρίς autowrap το κείμενο θα
	# κοβόταν στην άκρη αντί να ξεχειλίζει ορατά.
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_label)

	# Το "Επίπεδο x/3" έχει νόημα μόνο για καταλόγους με αναβαθμίσεις (όπλα) —
	# οι πανοπλίες (upgradable = false) δεν έχουν tiers, βλ. armor_inventory.gd.
	if catalog.upgradable:
		var tier_label := Label.new()
		tier_label.text = "Επίπεδο %d/%d" % [catalog.get_tier(id), catalog.UPGRADE_MAX_TIER]
		tier_label.add_theme_color_override("font_color", C_MUTED)
		tier_label.add_theme_font_size_override("font_size", 22)
		tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(tier_label)

	# ΟΛΑ τα stats που δίνει το αντικείμενο εξοπλισμένο (όχι μόνο το πρωτεύον
	# Επίθεση/Άμυνα του καταλόγου) — βλ. Heroes.display_item_buffs.
	var stat_row_label := Label.new()
	stat_row_label.text = _stat_line(Heroes.display_item_buffs(id))
	stat_row_label.add_theme_color_override("font_color", C_GOLD)
	stat_row_label.add_theme_font_size_override("font_size", 26)
	stat_row_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(stat_row_label)

	if catalog.upgradable:
		info.add_child(_make_upgrade_row(catalog, id))
	info.add_child(_make_sell_row(catalog, id))

	return card

## Κάρτα ήρωα του roster (καρτέλα «Ήρωες») — εικόνα + όνομα + 4 stats. Read-only
## (η ανάθεση σε θέση / ο εξοπλισμός γίνεται στην οθόνη «Η Ομάδα σου»).
func _make_hero_row(hero: Dictionary) -> Control:
	var card := _make_card_panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = CARD_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = Heroes.hero_texture(hero)
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 8)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = str(hero["name"])
	name_label.add_theme_color_override("font_color", C_PARCH)
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_label)

	var fin := Heroes.get_final_stats(hero)
	var stats_label := Label.new()
	stats_label.text = "%s %d   %s %d   %s %d   %s %d" % [
		Heroes.STAT_ICONS["HP"], fin["HP"],
		Heroes.STAT_ICONS["Damage"], fin["Damage"],
		Heroes.STAT_ICONS["Shield"], fin["Shield"],
		Heroes.STAT_ICONS["AttackSpeed"], fin["AttackSpeed"]]
	stats_label.add_theme_color_override("font_color", C_GOLD)
	stats_label.add_theme_font_size_override("font_size", 26)
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(stats_label)

	return card

func _make_upgrade_row(catalog: EquipmentCatalog, id: String) -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tier := catalog.get_tier(id)
	if tier >= catalog.UPGRADE_MAX_TIER:
		var max_label := Label.new()
		max_label.text = "MAX"
		max_label.add_theme_color_override("font_color", C_GOLD)
		max_label.add_theme_font_size_override("font_size", 22)
		max_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(max_label)
	else:
		var upgrade_btn := Button.new()
		upgrade_btn.text = "Αναβάθμιση  %d" % catalog.get_upgrade_cost(tier)
		upgrade_btn.add_theme_font_size_override("font_size", 22)
		upgrade_btn.custom_minimum_size = Vector2(220, 48)
		# PASS αντί για STOP: πατιέται κανονικά, αλλά αφήνει ένα drag πάνω του
		# να φτάσει ΚΑΙ στο ScrollContainer (mobile scroll).
		upgrade_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		_set_price_icon(upgrade_btn)
		row.add_child(upgrade_btn)
		upgrade_btn.pressed.connect(func(): catalog.upgrade(id))

	return row

## Το Inventory είναι πλέον ΜΟΝΟ προβολή: εικόνα + στατιστικά + πώληση. Καμία
## επιλογή/εξοπλισμός εδώ — ο εξοπλισμός ηρώων γίνεται αποκλειστικά στην οθόνη
## «Η Ομάδα σου» (HeroSlotPopup -> Heroes.equip_item). Έμεινε μόνο το κουμπί
## «Πούλησε» + η επιστροφή, ΕΝΑ chip (ποσό+εικονίδιο) ανά νόμισμα — η τιμή
## ενός αντικειμένου μπορεί να έχει πάνω από ένα νόμισμα (βλ.
## EquipmentCatalog.get_sell_refund), όχι μόνο Χαλκός.
func _make_sell_row(catalog: EquipmentCatalog, id: String) -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sell_btn := Button.new()
	sell_btn.text = "Πούλησε"
	sell_btn.add_theme_font_size_override("font_size", 20)
	sell_btn.add_theme_color_override("font_color", Color("e2a5a5"))
	sell_btn.custom_minimum_size = Vector2(120, 44)
	sell_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(sell_btn)
	sell_btn.pressed.connect(func(): catalog.sell(id))

	var refund := catalog.get_sell_refund(id)
	for currency in Currency.ORDER:
		if refund.has(currency):
			row.add_child(_refund_chip(currency, int(refund[currency])))

	return row

## Ένα chip (+ποσό εικονίδιο) για ένα νόμισμα επιστροφής πώλησης — ίδιο ύφος
## με τα price chips του shop_popup.gd, αλλά μικρό Control αντί για overlay
## πάνω σε κουμπί (εδώ το κουμπί «Πούλησε» έχει σταθερό, μικρό κείμενο).
func _refund_chip(currency: String, amount: int) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lbl := Label.new()
	lbl.text = "+%d" % amount
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color("e2a5a5"))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lbl)

	var tex := Currency.get_icon_texture(currency)
	if tex == null:
		var fallback := Label.new()
		fallback.text = str(Currency.ICONS.get(currency, ""))
		fallback.add_theme_font_size_override("font_size", 20)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(fallback)
		return box

	var icon := TextureRect.new()
	icon.texture = tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(24, 24)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	return box

## Μία γραμμή κειμένου με ΟΛΑ τα stats ενός buffs Dictionary (π.χ. {"Damage":
## 13, "AttackSpeed": 5} -> "⚔ 13   ⚡ 5"), σε σειρά Heroes.STAT_KEYS — ίδιο
## helper με το shop_popup.gd (δεν υπάρχει κοινό UI-utils module, κάθε popup
## κρατά τα δικά του μικρά format helpers, ίδιο μοτίβο με το υπόλοιπο codebase).
func _stat_line(buffs: Dictionary) -> String:
	var parts: Array = []
	for key in Heroes.STAT_KEYS:
		if buffs.has(key):
			parts.append("%s %d" % [Heroes.STAT_ICONS[key], int(buffs[key])])
	return "   ".join(parts)

## Βάζει την ΠΡΑΓΜΑΤΙΚΗ εικόνα του Χαλκού (copper.png) δίπλα στο κείμενο του
## κουμπιού, αντί για το παλιό emoji "🪙" — που είναι ΧΡΥΣΟ νόμισμα, ενώ χρυσός
## δεν υπάρχει πια στο παιχνίδι (αγορά/αναβάθμιση/πώληση γίνονται όλα σε Χαλκό).
## Ίδια πηγή εικόνας με το Shop/Αποθήκη (Currency.get_icon_texture).
## expand_icon: το copper.png είναι 1008×1055 — χωρίς αυτό το κουμπί θα «φούσκωνε»
## στο φυσικό μέγεθος της υφής. Αν λείψει το PNG, το κουμπί μένει σκέτο κείμενο.
func _set_price_icon(btn: Button) -> void:
	var tex := Currency.get_icon_texture(PRICE_CURRENCY)
	if tex == null:
		btn.text += " %s" % Currency.ICONS.get(PRICE_CURRENCY, "")
		return
	btn.icon = tex
	btn.expand_icon = true

func _close_confirm() -> void:
	if is_instance_valid(_confirm_overlay):
		_confirm_overlay.queue_free()
	_confirm_overlay = null

func _make_card_panel() -> PanelContainer:
	var card := PanelContainer.new()
	# IGNORE: η κάρτα δεν έχει δικό της click — αλλιώς (default STOP) ένα drag
	# πάνω της δεν φτάνει ποτέ στο ScrollContainer από πάνω (mobile scroll).
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.22)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	sb.border_color = Color(0, 0, 0, 0.35)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", sb)
	return card
