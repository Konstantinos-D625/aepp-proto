extends "res://Scripts/equipment_catalog.gd"

## Καθολική (autoload) κατάσταση για το σύστημα όπλων.
## Υποκλάση του Scripts/equipment_catalog.gd — η κοινή λογική (κατάλογος,
## τιμολόγηση, αγορά/αναβάθμιση/πώληση, persistence, starter grant) ζει ΕΚΕΙ.
## Εδώ ορίζονται μόνο τα δεδομένα του όπλου (_configure) και οι δύο ειδικές
## φόρμουλες στατιστικού (get_base_stat/get_total_stat) που χρειάζονται το
## 1-20 clamp ώστε να ταιριάζουν με το Character stat panel — βλ.
## Scripts/armor_inventory.gd για το ανάλογο (γενικευμένο, χωρίς clamp)
## σύστημα πανοπλιών.
##
## ΑΡΧΙΤΕΚΤΟΝΙΚΗ: κάθε εικόνα Level1..Level9.png μέσα σε κάθε φάκελο
## κατηγορίας είναι ένα ξεχωριστό, μοναδικά ονομασμένο, αγοράσιμο όπλο. Το
## "old_level" (1-9, το νούμερο της εικόνας) είναι μόνιμο χαρακτηριστικό του
## όπλου. Το ξεχωριστό "tier" (1-3) είναι η αναβάθμιση που αγοράζει ο
## παίκτης ΜΕΤΑ την αγορά, μέσα από το Inventory.
##
## Για να προστεθεί νέο όπλο στο μέλλον: αντέγραψε την εικόνα μέσα στον
## φάκελο της κατηγορίας του (Όπλα/<category>/LevelN.png) και πρόσθεσε ένα
## {file, name} entry στο items[category] στη θέση N-1 — καμία άλλη αλλαγή
## λογικής δεν χρειάζεται.

# Όπλο που έχει ήδη ο παίκτης, κατοχυρωμένο, σε ένα ολοκαίνουργιο save (βλ.
# EquipmentCatalog._grant_starters_if_new_save). Χωρίς αυτό ΚΑΝΕΝΑ από τα 81
# όπλα δεν θα ήταν ιδιοκτησία στην αρχή — ο παίκτης θα ξεκινούσε άοπλος.
const STARTER_WEAPON_ID := "Μαχαίρι_1"

func _configure() -> void:
	item_dir = "res://Όπλα/"
	stat_label = "Επίθεση"
	stat_icon = "⚔"
	starter_ids = [STARTER_WEAPON_ID]

	categories = [
		"Μαχαίρι", "Σπαθί", "Σφυρί", "Σιδηρομπουνιά", "Τσεκούρι",
		"Αξίνα", "Λεπίδα", "Μαστίγιο", "Τόξο",
	]

	category_multiplier = {
		"Μαχαίρι": 1.0,
		"Σπαθί": 1.3,
		"Σφυρί": 1.6,
		"Σιδηρομπουνιά": 1.9,
		"Τσεκούρι": 2.3,
		"Αξίνα": 2.7,
		"Λεπίδα": 3.2,
		"Μαστίγιο": 3.8,
		"Τόξο": 4.5,
	}

	# Κάθε εικόνα αναλύθηκε οπτικά και πήρε ένα μοναδικό fantasy όνομα που
	# ταιριάζει με το ύφος/υλικό/αίσθημά της.
	items = {
		"Μαχαίρι": _level_files(["Nebulyn Fang", "Emerald Crescent Fang", "Amethyst Serpent Fang",
			"Sworn Heart Dagger", "Thornvine Shard", "Gilt Vine Fang",
			"Tidescale Fin Dagger", "Batwing Bloodfang", "Shattered Frostfang"]),
		"Σπαθί": _level_files(["Winterwing Longsword", "Dragoneye Warblade", "Tuskhorn Ripper",
			"Aurelian Rapier", "Sekhmet's Wingblade", "Moonveil Scimitar",
			"Frostgilded Saber", "Emberbloom Flameblade", "Prismshard Greatblade"]),
		"Σφυρί": _level_files(["Ironbound Warhammer", "Doomforged Twinhammer", "Ironspike Morningstar",
			"Thornspine Warmace", "Moonstone Morningstar", "Cinderstone Morningstar",
			"Crimson-Banded Warmace", "Voidthorn Mace", "Molten Doombringer"]),
		"Σιδηρομπουνιά": _level_files(["Starveil Glove", "Steelclaw Gauntlet", "Infernus Talon",
			"Runebound Voidglove", "Hexcore Gauntlet", "Wraithclaw Gauntlet",
			"Ionforge Fist", "Stormcore Warfists", "Sunshard Warfist"]),
		"Τσεκούρι": _level_files(["Stonehide Hatchet", "Cinderfiend Hatchet", "Trailhewn Hatchet",
			"Glyphedge Battleaxe", "Windfeather Warbind", "Sunblaze Labrys",
			"Frostrune Battleaxe", "Hellmaw Doomaxe", "Bloodrend Ravager"]),
		"Αξίνα": _level_files(["Silvermoon Sickle", "Voidmoon Reaver", "Jade Crescent Scythe",
			"Brassfire Cleaver", "Boneharvest Reaper", "Stormfiend Scythe",
			"Frostwyrm Reaper", "Glacial Howler Scythe", "Nightshade Reaper"]),
		"Λεπίδα": _level_files(["Voidcrescent Blade", "Glacial Crescentfang", "Solarforge Crescent",
			"Tideglyph Fang", "Glacient Starshard", "Amethyst Whirlstar",
			"Sunspiral Bladestar", "Frostwhirl Cyclone", "Demonhorn Talon"]),
		"Μαστίγιο": _level_files(["Oxhide Lash", "Briarcoil Lash", "Tidebind Serpentlash",
			"Dragoncoil Whip", "Nightspine Coilwhip", "Viperscale Warlash",
			"Rosebloom Lash", "Gilded Emberlash", "Venomthorn Bramblewhip"]),
		"Τόξο": _level_files(["Ashwood Hunting Bow", "Voidhorn Warbow", "Sylvan Knotbow",
			"Feathertotem Bow", "Cherryblossom Warbow", "Verdant Leafbow",
			"Silverwood Rangerbow", "Rubygold Sovereign Bow", "Emerald Windshaft"]),
	}

## Βοηθητικό μόνο για το _configure(): μετατρέπει μία απλή λίστα ονομάτων σε
## Array[{"file","name"}] με file = "Level1".."LevelN" (ίδια σύμβαση με τα
## υπάρχοντα αρχεία εικόνων Level1.png..Level9.png).
func _level_files(names: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in names.size():
		result.append({"file": "Level%d" % (i + 1), "name": names[i]})
	return result

## Βασική επίθεση (πριν τα upgrades), ΠΑΝΤΑ μέσα σε 1-20 — δύο συστατικά:
##   - level_component: το κύριο συστατικό, βήμα 2 ανά old_level μέσα στην
##     ΙΔΙΑ κατηγορία (level1=1 ... level9=17).
##   - category_bonus (0-3): μικρό μπόνους βάσει της θέσης της κατηγορίας
##     μέσα στο categories, που είναι ήδη σε αύξουσα σειρά ακρίβειας/τιμής
##     (Μαχαίρι το φθηνότερο -> Τόξο το ακριβότερο, βλ. category_multiplier).
## Έτσι η επίθεση ακολουθεί (χωρίς να είναι δέσμια της ίδιας φόρμουλας με)
## την τιμή του όπλου: το φθηνότερο όπλο του παιχνιδιού (Μαχαίρι Level1)
## κάνει 1 επίθεση, το ακριβότερο (Τόξο Level9) κάνει 20 — πριν τα upgrades.
func get_base_stat(id: String) -> int:
	var old_level := get_old_level(id)
	var level_component := 1 + (old_level - 1) * 2   # 1, 3, 5, ..., 17
	var category_rank := categories.find(get_category(id))   # 0..8, φθηνό -> ακριβό
	var category_bonus := 0
	if category_rank > 0:
		category_bonus = int(round(category_rank * 3.0 / float(categories.size() - 1)))   # 0..3
	return clampi(level_component + category_bonus, 1, 20)

## Συνολική επίθεση (βάση + upgrades), πάντα μέσα σε 1-20 — τα upgrades
## μπορούν να "σπρώξουν" ένα ήδη ισχυρό όπλο πάνω από 20, οπότε γίνεται
## clamp εδώ (soft-cap: τα upgrades σε όπλα κοντά στο ανώτατο όριο έχουν
## μικρότερο πραγματικό όφελος — σκόπιμο, όχι bug).
func get_total_stat(id: String) -> int:
	if not is_owned(id):
		return get_base_stat(id)
	return clampi(get_base_stat(id) + (get_tier(id) - 1) * UPGRADE_STAT_BONUS, 1, 20)
