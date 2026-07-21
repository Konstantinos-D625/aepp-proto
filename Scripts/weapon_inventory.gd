extends "res://Scripts/equipment_catalog.gd"

## Καθολική (autoload) κατάσταση για το σύστημα όπλων.
## Υποκλάση του Scripts/equipment_catalog.gd — η κοινή λογική (κατάλογος,
## τιμολόγηση, αγορά/πώληση, persistence, starter grant, στατιστικά μέσω
## get_item_buffs) ζει ΕΚΕΙ. Εδώ ορίζονται ΜΟΝΟ τα δεδομένα κάθε όπλου
## (_configure) — βλ. Scripts/armor_inventory.gd για το ανάλογο σύστημα
## πανοπλιών.
##
## ΑΡΧΙΤΕΚΤΟΝΙΚΗ: κάθε εικόνα Level1..Level9.png μέσα σε κάθε φάκελο
## κατηγορίας είναι ένα ξεχωριστό, μοναδικά ονομασμένο, αγοράσιμο όπλο. Το
## "old_level" (1-9, το νούμερο της εικόνας) είναι μόνιμο χαρακτηριστικό του
## όπλου. ΔΕΝ αναβαθμίζονται (upgradable = false, όπως και οι πανοπλίες) —
## το tier μένει πάντα 1 μετά την αγορά.
##
## Για να αλλάξεις τα στατιστικά ενός όπλου: άλλαξε ΑΠΕΥΘΕΙΑΣ τους αριθμούς
## στο "buffs" του entry του παρακάτω (Damage/AttackSpeed) — καμία φόρμουλα.
## Για να αλλάξεις την ΤΙΜΗ ενός όπλου: ίδιο πράγμα, στο "price" του entry
## του (Χαλκός/Κέρμα) — ούτε αυτό βγαίνει από φόρμουλα/category_multiplier
## πια.
## Για να προστεθεί νέο όπλο στο μέλλον: αντέγραψε την εικόνα μέσα στον
## φάκελο της κατηγορίας του (Όπλα/<category>/LevelN.png) και πρόσθεσε ένα
## {file, name, buffs, price} entry στο items[category] στη θέση N-1 — καμία
## άλλη αλλαγή λογικής δεν χρειάζεται.

func _configure() -> void:
	item_dir = "res://Όπλα/"
	stat_label = "Επίθεση"
	stat_icon = "⚔"
	primary_stat_key = "Damage"
	# Κανένα starter όπλο — ο παίκτης ξεκινά άοπλος, ΟΛΑ αγοράζονται από το
	# Shop (starter_ids μένει άδειο, βλ. equipment_catalog.gd).
	# Τα όπλα ΔΕΝ αναβαθμίζονται (μόνο αγορά/πώληση) — ίδιο μοτίβο με τις
	# πανοπλίες (armor_inventory.gd). Το Inventory UI κρύβει αυτόματα το
	# "Επίπεδο x/3"/κουμπί Αναβάθμισης όταν upgradable = false.
	upgradable = false

	categories = [
		"Μαχαίρι", "Σπαθί", "Σφυρί", "Σιδηρομπουνιά", "Τσεκούρι",
		"Αξίνα", "Λεπίδα", "Μαστίγιο", "Τόξο", "Σφαίρα",
	]

	# Κάθε όπλο: "file" (όνομα εικόνας μέσα στον φάκελο της κατηγορίας),
	# "name" (fantasy όνομα), "buffs" (stats ΠΟΥ ΔΙΝΕΙ ΟΤΑΝ ΕΞΟΠΛΙΣΤΕΙ —
	# Damage + AttackSpeed), "price" (κόστος αγοράς — Χαλκός + Κέρμα). Όλα
	# χειροκίνητα ανά όπλο, ΚΑΜΙΑ φόρμουλα/category_multiplier. Κρατιέται ΕΝΑ
	# όπλο (Level1) ανά κατηγορία — για να προστεθούν κι άλλα αργότερα,
	# ξαναβάλε επιπλέον entries εδώ και τα αντίστοιχα LevelN.png στον φάκελο
	# της κατηγορίας.
	#
	# "Σφαίρα" (Σφαίρα_1) είναι εξαίρεση: τρόπαιο από το δέντρο-boss (βλ.
	# mini_boss_popup.gd BOSS_DEFS["tree"]["weapon_reward"] + boss_fight.gd::
	# _conclude_fight, EquipmentCatalog.grant). "hidden": true = ΔΕΝ
	# αγοράζεται/εμφανίζεται στο Shop (βλ. EquipmentCatalog.is_shop_hidden/
	# buy), παίρνεται ΜΟΝΟ νικώντας το δέντρο· μόλις αποκτηθεί, φαίνεται
	# κανονικά στο Inventory (το "price" μένει ορισμένο για αναφορά/αν
	# αφαιρεθεί ποτέ το "hidden").
	items = {
		"Μαχαίρι": [
			{"file": "Level1", "name": "Nebulyn Fang", "buffs": {"Damage": 1, "AttackSpeed": 3}, "price": {"Δέρμα": 15, "Κέρμα": 2}},
		],
		"Σπαθί": [
			{"file": "Level1", "name": "Winterwing Longsword", "buffs": {"Damage": 2, "AttackSpeed": 2}, "price": {"Χαλκός": 20, "Κέρμα": 2}},
			# "Σπαθί_2" (golden_sword) — κρυμμένο σημείο "?" μέσα στο Chapel του
			# side quest του Κάστρου (βλ. castle_popup.gd CHAPEL_SPOTS["Shelf"]),
			# δίνεται με WeaponInventory.grant() (βλ. room_image_popup.gd
			# _on_spot_pressed). ΙΔΙΟ μοτίβο "hidden" με το Tree Magic Sphere.
			{"file": "golden_sword", "name": "Kingsblade of Dawn", "buffs": {"Damage": 8, "AttackSpeed": 7}, "price": {"Χαλκός": 75, "Κέρμα": 8}, "hidden": true},
		],
		"Σφυρί": [
			{"file": "Level1", "name": "Ironbound Warhammer", "buffs": {"Damage": 4, "AttackSpeed": 2}, "price": {"Δέρμα": 24, "Κέρμα": 2}},
		],
		"Σιδηρομπουνιά": [
			{"file": "Level1", "name": "Starveil Glove", "buffs": {"Damage": 3, "AttackSpeed": 3}, "price": {"Σίδερο": 29, "Κέρμα": 3}},
		],
		"Τσεκούρι": [
			{"file": "Level1", "name": "Stonehide Hatchet", "buffs": {"Damage": 5, "AttackSpeed": 1}, "price": {"Χαλκός": 35, "Σίδερο": 15, "Κέρμα": 4}},
		],
		"Αξίνα": [
			{"file": "Level1", "name": "Silvermoon Sickle", "buffs": {"Damage": 4, "AttackSpeed": 2}, "price": {"Χαλκός": 41, "Δέρμα": 10, "Κέρμα": 4}},
		],
		"Λεπίδα": [
			{"file": "Level1", "name": "Voidcrescent Blade", "buffs": {"Damage": 2, "AttackSpeed": 6}, "price": {"Χαλκός": 48, "Κέρμα": 5}},
		],
		"Μαστίγιο": [
			{"file": "Level1", "name": "Oxhide Lash", "buffs": {"Damage": 5, "AttackSpeed": 4}, "price": {"Χαλκός": 57, "Κέρμα": 6}},
		],
		"Τόξο": [
			{"file": "Level1", "name": "Ashwood Hunting Bow", "buffs": {"Damage": 3, "AttackSpeed": 8}, "price": {"Χαλκός": 68, "Δέρμα": 20, "Κέρμα": 7}},
		],
		"Σφαίρα": [
			{"file": "tree_magic_sphere", "name": "Tree Magic Sphere", "buffs": {"Damage": 5, "AttackSpeed": 9}, "price": {"Χαλκός": 63, "Σίδερο": 25, "Κέρμα": 6}, "hidden": true},
		],
	}
