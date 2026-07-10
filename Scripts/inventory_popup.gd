extends Control

const C_PARCH := Color("f3e6c4")
const C_MUTED := Color("cdbf9a")
const C_GOLD  := Color("f2c84b")
const C_EMPTY := Color(0, 0, 0, 0.35)
const C_SELECT     := Color("3aa652")   # Select — πράσινο
const C_SELECT_HL  := Color("46c463")
const C_SELECTED    := Color("5a5a5a")  # Selected — γκρι
const C_SELECTED_HL := Color("6c6c6c")

var _confirm_overlay: Control

# ── "Κλειδωμένη" λειτουργία (άνοιγμα από το Character Editor) ──────────────
# Το ΙΔΙΟ panel ξαναχρησιμοποιείται (όχι δεύτερη υλοποίηση) αλλά περιορίζει
# την πλοήγηση κατηγορίας όσο είναι κλειδωμένο — βλ. open_locked_to_weapons/
# open_locked_to_armor_category/_apply_lock_ui παρακάτω.
var _return_target: Node        # αν έχει τιμή, το Χ/click-outside επιστρέφει εδώ αντί να κλείνει απλά
var _lock_tabs := false         # true -> κρύβει το Όπλα/Πανοπλίες tab switch
var _lock_subcategory := false  # true -> κρύβει ΚΑΙ το category bar (μία μόνο κατηγορία πανοπλίας)

var _current_category := Inventory.CATEGORY_WEAPON

# Θυμάται ξεχωριστά ποια υπο-κατηγορία ήταν επιλεγμένη σε κάθε καρτέλα
# (Όπλα/Πανοπλίες), ώστε η επιλογή να μη χάνεται όταν ο παίκτης εναλλάσσει.
# Γεμίζεται στο _ready() (όχι εδώ ως field initializer) — τα field
# initializers μπορούν να αξιολογηθούν από το GDScript σε context όπου τα
# autoloads δεν είναι ακόμα διαθέσιμα, οδηγώντας σε άδειο WeaponInventory
# .categories/ArmorInventory.categories και "out of bounds" σε [0].
var _selected_category: Dictionary = {}
var _category_bar: Control
var _category_buttons: Dictionary = {}   # κατηγορία -> Button (της τρέχουσας καρτέλας)

func _ready() -> void:
	hide()
	# Μοναδικό instance στο παιχνίδι — ο Character Editor το εντοπίζει μέσω
	# group αντί για hardcoded σχετικό μονοπάτι στο scene tree (είναι σε
	# διαφορετικό κλαδί: Area1/InventoryPopup vs Area1/CharacterSelect/
	# CharacterEditPopup), ώστε να ανοίγει το ΙΔΙΟ panel χωρίς δεύτερη υλοποίηση.
	add_to_group("inventory_popup")
	_selected_category = {
		Inventory.CATEGORY_WEAPON: WeaponInventory.categories[0],
		Inventory.CATEGORY_ARMOR: ArmorInventory.categories[0],
	}
	%WeaponsTab.pressed.connect(func(): _select_category(Inventory.CATEGORY_WEAPON))
	%ArmorTab.pressed.connect(func(): _select_category(Inventory.CATEGORY_ARMOR))
	%Dim.gui_input.connect(_on_dim_input)
	%CloseButton.pressed.connect(close_popup)
	_build_category_bar_container()
	_rebuild_category_bar()
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
	# Το equip/unequip (κουμπί Select/Selected εδώ, ή ο επιλογέας του
	# Character Editor) πρέπει επίσης να ξαναζωγραφίζει τις κάρτες ώστε το
	# κουμπί να αλλάζει κατάσταση άμεσα, όποια οθόνη κι αν το προκάλεσε.
	Inventory.equipment_changed.connect(func(_slot, _id) -> void:
		if visible:
			_refresh()
	)

func open() -> void:
	_return_target = null
	_lock_tabs = false
	_lock_subcategory = false
	_select_category(Inventory.CATEGORY_WEAPON)
	_apply_lock_ui()
	show()

## Ανοίγει το ΙΔΙΟ Inventory panel κλειδωμένο στα Όπλα — ελεύθερη εναλλαγή
## ΜΕΤΑΞΥ κατηγοριών όπλων (Μαχαίρι/Σπαθί/…) επιτρέπεται, αλλά όχι μετάβαση
## στις Πανοπλίες (το tab switch κρύβεται). Καλείται από το CharacterEditPopup
## όταν πατηθεί το Weapon slot· `preferred_category` προεπιλέγει την καρτέλα
## του ήδη εξοπλισμένου όπλου (αν υπάρχει), αλλιώς μένει η προεπιλογή.
func open_locked_to_weapons(return_to: Node, preferred_category: String = "") -> void:
	_return_target = return_to
	_lock_tabs = true
	_lock_subcategory = false
	_select_category(Inventory.CATEGORY_WEAPON)
	if preferred_category != "":
		_select_sub_category(preferred_category)
	_apply_lock_ui()
	show()

## Ανοίγει το ΙΔΙΟ Inventory panel κλειδωμένο σε ΜΙΑ συγκεκριμένη κατηγορία
## πανοπλίας (π.χ. μόνο Κράνη) — καμία εναλλαγή κατηγορίας δεν επιτρέπεται,
## ούτε προς άλλη πανοπλία ούτε προς Όπλα (το category bar ΚΑΙ το tab switch
## κρύβονται εντελώς). Καλείται από το CharacterEditPopup όταν πατηθεί
## Helmet/Chest Armor/Pants/Boots — `category` είναι ήδη ακριβώς η τιμή που
## καταλαβαίνει το ArmorInventory (βλ. Inventory.SLOT_LABELS).
func open_locked_to_armor_category(category: String, return_to: Node) -> void:
	_return_target = return_to
	_lock_tabs = true
	_lock_subcategory = true
	_select_category(Inventory.CATEGORY_ARMOR)
	_select_sub_category(category)
	_apply_lock_ui()
	show()

func _apply_lock_ui() -> void:
	var tabs_row: Control = %WeaponsTab.get_parent()
	tabs_row.visible = not _lock_tabs
	_category_bar.visible = not _lock_subcategory

## Κοινό σημείο κλεισίματος (κουμπί Χ ΚΑΙ click έξω από την κάρτα) — αν το
## panel ανοίχτηκε κλειδωμένο από το Character Editor (_return_target),
## επιστρέφει ΑΚΡΙΒΩΣ εκεί αντί να κλείνει απλά στο κενό (ζητήθηκε ρητά: το
## Χ πρέπει να γυρνάει στο Characters → Edit, όχι στο Inventory/χωριό).
func close_popup() -> void:
	_close_confirm()
	hide()
	var target := _return_target
	_return_target = null
	_lock_tabs = false
	_lock_subcategory = false
	_apply_lock_ui()
	if is_instance_valid(target) and target.has_method("_resume_after_inventory"):
		target.call("_resume_after_inventory")

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
	_rebuild_category_bar()
	_refresh()

# ═══════════════════════════════════════════════════════════════════════════
# ΚΑΤΗΓΟΡΙΕΣ ΕΞΟΠΛΙΣΜΟΥ (tab bar — 9 για Όπλα, 4 για Πανοπλίες)
# ═══════════════════════════════════════════════════════════════════════════

func _build_category_bar_container() -> void:
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 64)
	_category_bar = scroll

	# Εισάγεται στο VBox της υπάρχουσας σκηνής, ακριβώς μετά το Tabs (Όπλα/Πανοπλίες).
	var tabs_node: Control = %WeaponsTab.get_parent()
	var vbox: Control = tabs_node.get_parent()
	var tabs_index := tabs_node.get_index()
	vbox.add_child(scroll)
	vbox.move_child(scroll, tabs_index + 1)

## Ξαναχτίζει τα κουμπιά κατηγορίας για την ΤΡΕΧΟΥΣΑ καρτέλα (Όπλα/Πανοπλίες)
## — οι δύο καρτέλες έχουν διαφορετικό σύνολο κατηγοριών, οπότε δεν αρκεί να
## κρυφτούν/εμφανιστούν τα ίδια κουμπιά, χτίζονται από την αρχή.
func _rebuild_category_bar() -> void:
	for c in _category_bar.get_children():
		c.queue_free()
	_category_buttons.clear()

	var catalog := _current_catalog()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_category_bar.add_child(row)

	for category in catalog.categories:
		var btn := Button.new()
		btn.text = catalog.get_category_label(category)
		btn.toggle_mode = true
		btn.button_pressed = category == _selected_category[_current_category]
		btn.add_theme_font_size_override("font_size", 20)
		row.add_child(btn)
		_category_buttons[category] = btn
		btn.pressed.connect(func(): _select_sub_category(category))

func _select_sub_category(category: String) -> void:
	_selected_category[_current_category] = category
	for cat in _category_buttons:
		(_category_buttons[cat] as Button).button_pressed = cat == category
	_refresh()

# ═══════════════════════════════════════════════════════════════════════════
# REFRESH
# ═══════════════════════════════════════════════════════════════════════════

func _refresh() -> void:
	for c in %ItemsList.get_children():
		c.queue_free()

	var catalog := _current_catalog()
	var category: String = _selected_category[_current_category]
	# Μόνο όσα ΚΑΤΕΧΕΙ ο παίκτης — τα υπόλοιπα δεν εμφανίζονται καθόλου
	# (ολόκληρος ο κατάλογος, με τα ακλείδωτα, φαίνεται μόνο στο Shop).
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
		upgrade_btn.text = "Αναβάθμιση  %d %s" % [catalog.get_upgrade_cost(tier), Currency.ICONS.get("Χρυσό", "🪙")]
		upgrade_btn.add_theme_font_size_override("font_size", 22)
		upgrade_btn.custom_minimum_size = Vector2(220, 48)
		row.add_child(upgrade_btn)
		upgrade_btn.pressed.connect(func(): catalog.upgrade(id))

	return row

func _make_sell_row(catalog: EquipmentCatalog, id: String) -> Control:
	# HFlowContainer αντί για HBoxContainer: αν τα δύο κουμπιά (Πούλησε +
	# Select/Selected) δεν χωράνε δίπλα-δίπλα στο διαθέσιμο πλάτος της
	# κάρτας, "σπάνε" σε δεύτερη γραμμή αντί να σπρώχνουν την κάρτα να
	# ξεχειλίσει έξω από το εξωτερικό πλαίσιο του Inventory.
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 8)

	var sell_btn := Button.new()
	sell_btn.text = "Πούλησε  (+%d %s)" % [catalog.get_sell_price(id), Currency.ICONS.get("Χρυσό", "🪙")]
	sell_btn.add_theme_font_size_override("font_size", 20)
	sell_btn.add_theme_color_override("font_color", Color("e2a5a5"))
	sell_btn.custom_minimum_size = Vector2(220, 44)
	row.add_child(sell_btn)
	sell_btn.pressed.connect(func(): catalog.sell(id))

	row.add_child(_make_select_button(catalog, id))

	return row

## Κουμπί "Select"/"Selected" δίπλα στο "Πούλησε" — πράσινο+"Select" αν το
## αντικείμενο ΔΕΝ είναι εξοπλισμένο (πατώντας το εξοπλίζεται αμέσως, καμία
## επιβεβαίωση δεν χρειάζεται για equip· βλ. Inventory.equip για τον κανόνα
## "μόνο ένα ανά slot/όπλο συνολικά" — αντικαθιστά αυτόματα το προηγούμενο).
## Γκρι+"Selected" αν ΕΙΝΑΙ εξοπλισμένο — πατώντας το ανοίγει modal
## επιβεβαίωσης αποεπιλογής αντί να αποεπιλέγει αμέσως.
func _make_select_button(catalog: EquipmentCatalog, id: String) -> Button:
	var slot := Inventory.get_slot_for(catalog, id)
	var is_selected: bool = slot != "" and Inventory.equipped.get(slot, "") == id

	var btn := Button.new()
	btn.text = "Selected" if is_selected else "Select"
	btn.custom_minimum_size = Vector2(240, 52)   # λίγο μεγαλύτερο από το Sell (220×44)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color("ffffff"))
	btn.add_theme_color_override("font_hover_color", Color("ffffff"))

	var normal := StyleBoxFlat.new()
	normal.bg_color = C_SELECTED if is_selected else C_SELECT
	normal.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = C_SELECTED_HL if is_selected else C_SELECT_HL
	hover.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

	if is_selected:
		btn.pressed.connect(func(): _show_unequip_confirm(slot))
	else:
		btn.pressed.connect(func(): Inventory.equip(slot, id))

	return btn

# ═══════════════════════════════════════════════════════════════════════════
# ΕΠΙΒΕΒΑΙΩΣΗ ΑΠΟΕΠΙΛΟΓΗΣ (unequip) — modal στο κέντρο της οθόνης
# ═══════════════════════════════════════════════════════════════════════════
func _show_unequip_confirm(slot: String) -> void:
	_close_confirm()

	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_confirm_overlay = overlay

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_confirm()
	)

	var panel := Panel.new()
	panel.anchor_left = 0.5; panel.anchor_top = 0.5
	panel.anchor_right = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -300; panel.offset_top = -170
	panel.offset_right = 300; panel.offset_bottom = 170
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.12, 0.98)
	sb.border_color = C_GOLD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 28)
	margin.add_child(col)

	var msg := Label.new()
	msg.text = "Θέλετε να προχωρήσετε στην αποεπιλογή του αντικειμένου;"
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	msg.custom_minimum_size = Vector2(0, 140)
	msg.add_theme_font_size_override("font_size", 26)
	msg.add_theme_color_override("font_color", C_PARCH)
	col.add_child(msg)

	var confirm_btn := Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(0, 60)
	confirm_btn.add_theme_font_size_override("font_size", 24)
	confirm_btn.add_theme_color_override("font_color", Color("ffffff"))
	confirm_btn.add_theme_color_override("font_hover_color", Color("ffffff"))
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color("8a2b2b")
	csb.set_corner_radius_all(10)
	confirm_btn.add_theme_stylebox_override("normal", csb)
	var csb_h := StyleBoxFlat.new()
	csb_h.bg_color = Color("a53434")
	csb_h.set_corner_radius_all(10)
	confirm_btn.add_theme_stylebox_override("hover", csb_h)
	confirm_btn.add_theme_stylebox_override("pressed", csb_h)
	col.add_child(confirm_btn)
	confirm_btn.pressed.connect(func():
		Inventory.equip(slot, "")
		_close_confirm()
	)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.add_theme_color_override("font_color", C_PARCH)
	close_btn.anchor_left = 1.0; close_btn.anchor_right = 1.0
	close_btn.anchor_top = 0.0; close_btn.anchor_bottom = 0.0
	close_btn.offset_left = -54; close_btn.offset_top = 10
	close_btn.offset_right = -12; close_btn.offset_bottom = 52
	panel.add_child(close_btn)
	close_btn.pressed.connect(_close_confirm)

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
