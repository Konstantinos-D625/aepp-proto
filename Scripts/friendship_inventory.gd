extends "res://Scripts/equipment_catalog.gd"

## Καθολική (autoload) κατάσταση για τα «Αντικείμενα Φιλίας» — αγοράζονται
## ΜΟΝΟ με Κέρμα Φιλίας στην καρτέλα «🤝 ΦΙΛΙΑΣ» του Shop.
## Υποκλάση του Scripts/equipment_catalog.gd — ίδια αρχιτεκτονική με το
## Scripts/weapon_inventory.gd/armor_inventory.gd (κατάλογος, τιμολόγηση,
## αγορά/πώληση, persistence), γενικευμένη εκεί. Εδώ ορίζονται ΜΟΝΟ τα
## δεδομένα κάθε αντικειμένου (_configure).
##
## Εξοπλίζονται ΚΑΝΟΝΙΚΑ σε ήρωα, ακριβώς όπως όπλα/πανοπλίες — τα 2 γενικά
## item slots ενός ήρωα (Heroes.ITEMS_PER_HERO) δεν κάνουν καμία διάκριση
## τύπου, οπότε ένα αντικείμενο φιλίας μπορεί να καταλάβει οποιοδήποτε από
## τα δύο (βλ. Heroes.get_owned_items/_catalog_for/equip_item). Εμφανίζονται
## επίσης στην καρτέλα «Όπλα» του Inventory μαζί με τα κανονικά όπλα (βλ.
## inventory_popup.gd::_current_catalogs).
##
## Για να προστεθεί νέο αντικείμενο φιλίας στο μέλλον: αντέγραψε την εικόνα
## μέσα σε νέο φάκελο κατηγορίας (Αντικείμενα Φιλίας/<category>/<αρχείο>.png)
## και πρόσθεσε ένα {file, name, buffs, price} entry στο items[category].

func _configure() -> void:
	item_dir = "res://Αντικείμενα Φιλίας/"
	stat_label = "Φιλία"
	stat_icon = "🤝"
	primary_stat_key = "HP"
	# Κανένα upgrade σύστημα (όπως και τα υπόλοιπα καταλόγια πλέον) — μόνο
	# αγορά/πώληση, το tier μένει 1 μετά την αγορά.
	upgradable = false

	categories = ["Ραβδί", "Γάντι", "Μανδύας"]

	items = {
		"Ραβδί": [
			{"file": "friendship_wand", "name": "Ραβδί της Φιλίας",
				"buffs": {"Damage": 2, "AttackSpeed": 3}, "price": {"Κέρμα Φιλίας": 25}},
		],
		"Γάντι": [
			{"file": "friendship_glove", "name": "Γάντι της Φιλίας",
				"buffs": {"Shield": 5, "AttackSpeed": 3}, "price": {"Κέρμα Φιλίας": 50}},
		],
		"Μανδύας": [
			{"file": "friendship_cloak", "name": "Μανδύας της Φιλίας",
				"buffs": {"HP": 7, "Shield": 6}, "price": {"Κέρμα Φιλίας": 100}},
		],
	}
