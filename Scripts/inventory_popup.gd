extends Control

const C_PARCH := Color("f3e6c4")
const C_MUTED := Color("cdbf9a")
const C_GOLD  := Color("f2c84b")
const C_EMPTY := Color(0, 0, 0, 0.35)

var _confirm_overlay: Control

const CATEGORY_CHARACTERS := "characters"
var _current_category := Inventory.CATEGORY_WEAPON

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
	# Αν κάποιο άλλο σύστημα αλλάξει τον εξοπλισμό (π.χ. auto-equip σε αγορά),
	# ξαναζωγραφίζονται οι κάρτες ώστε το Inventory να μένει συνεπές.
	Inventory.equipment_changed.connect(func(_slot, _id) -> void:
		if visible:
			_refresh()
	)

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

func _current_catalog() -> EquipmentCatalog:
	if _current_category == Inventory.CATEGORY_WEAPON:
		return WeaponInventory
	return ArmorInventory

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

	var catalog := _current_catalog()
	# Όλα τα αντικείμενα όλων των κατηγοριών του καταλόγου μαζί σε μία λίστα —
	# δεν υπάρχουν πλέον υπο-κατηγορίες. Μόνο όσα ΚΑΤΕΧΕΙ ο παίκτης (ο πλήρης
	# κατάλογος με τα ακλείδωτα φαίνεται μόνο στο Shop).
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

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	card.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = CARD_ICON_SIZE
	# EXPAND_IGNORE_SIZE: αποσυνδέει το minimum_size από το φυσικό pixel
	# μέγεθος της υφής — χωρίς αυτό, το Godot θέτει minimum_size = μέγεθος
	# της εικόνας, αγνοώντας το custom_minimum_size παραπάνω και φουσκώνοντας
	# την κάρτα πέρα από το εξωτερικό πλαίσιο του Inventory.
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path := catalog.get_icon_path(id)
	if ResourceLoader.exists(icon_path):
		icon.texture = Inventory.get_item_texture({"avatar_overlay": icon_path})
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 8)
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
	info.add_child(name_label)

	# Το "Επίπεδο x/3" έχει νόημα μόνο για καταλόγους με αναβαθμίσεις (όπλα) —
	# οι πανοπλίες (upgradable = false) δεν έχουν tiers, βλ. armor_inventory.gd.
	if catalog.upgradable:
		var tier_label := Label.new()
		tier_label.text = "Επίπεδο %d/%d" % [catalog.get_tier(id), catalog.UPGRADE_MAX_TIER]
		tier_label.add_theme_color_override("font_color", C_MUTED)
		tier_label.add_theme_font_size_override("font_size", 22)
		info.add_child(tier_label)

	var stat_row_label := Label.new()
	stat_row_label.text = "%s %s: %d" % [catalog.stat_icon, catalog.stat_label, catalog.get_total_stat(id)]
	stat_row_label.add_theme_color_override("font_color", C_GOLD)
	stat_row_label.add_theme_font_size_override("font_size", 26)
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
	card.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = CARD_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = Heroes.hero_texture(hero)
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 8)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = str(hero["name"])
	name_label.add_theme_color_override("font_color", C_PARCH)
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	info.add_child(stats_label)

	return card

func _make_upgrade_row(catalog: EquipmentCatalog, id: String) -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 8)

	var tier := catalog.get_tier(id)
	if tier >= catalog.UPGRADE_MAX_TIER:
		var max_label := Label.new()
		max_label.text = "MAX"
		max_label.add_theme_color_override("font_color", C_GOLD)
		max_label.add_theme_font_size_override("font_size", 22)
		row.add_child(max_label)
	else:
		var upgrade_btn := Button.new()
		upgrade_btn.text = "Αναβάθμιση  %d %s" % [catalog.get_upgrade_cost(tier), Currency.ICONS.get("Χαλκός", "🪙")]
		upgrade_btn.add_theme_font_size_override("font_size", 22)
		upgrade_btn.custom_minimum_size = Vector2(220, 48)
		row.add_child(upgrade_btn)
		upgrade_btn.pressed.connect(func(): catalog.upgrade(id))

	return row

## Το Inventory είναι πλέον ΜΟΝΟ προβολή: εικόνα + στατιστικά + πώληση. Καμία
## επιλογή/εξοπλισμός εδώ — ο εξοπλισμός ηρώων γίνεται αποκλειστικά στην οθόνη
## «Η Ομάδα σου» (HeroSlotPopup -> Heroes.equip_item). Έμεινε μόνο το κουμπί
## «Πούλησε».
func _make_sell_row(catalog: EquipmentCatalog, id: String) -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 8)

	var sell_btn := Button.new()
	sell_btn.text = "Πούλησε  (+%d %s)" % [catalog.get_sell_price(id), Currency.ICONS.get("Χαλκός", "🪙")]
	sell_btn.add_theme_font_size_override("font_size", 20)
	sell_btn.add_theme_color_override("font_color", Color("e2a5a5"))
	sell_btn.custom_minimum_size = Vector2(220, 44)
	row.add_child(sell_btn)
	sell_btn.pressed.connect(func(): catalog.sell(id))

	return row

func _close_confirm() -> void:
	if is_instance_valid(_confirm_overlay):
		_confirm_overlay.queue_free()
	_confirm_overlay = null

func _make_card_panel() -> PanelContainer:
	var card := PanelContainer.new()
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
