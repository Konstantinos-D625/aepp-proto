extends Node

# ═══════════════════════════════════════════════════════════════════════════
# PlayerProfile (Autoload) — «περιοχή/κεφάλαιο» + δημόσιο προφίλ προόδου
# ═══════════════════════════════════════════════════════════════════════════
# Φάση 0 της online επέκτασης. Δύο ρόλοι, και οι δύο 100% offline (χωρίς server):
#   1. get_region()           — σε ποιο «κεφάλαιο» βρίσκεται ο παίκτης, ΠΑΡΑΓΟΜΕΝΟ
#                               από τα αποθηκευμένα ορόσημα (boss defeats).
#   2. build_public_profile() — μαζεύει ΟΛΑ τα δημόσια (κοινοποιήσιμα) στοιχεία
#                               προόδου σε ένα JSON-έτοιμο Dictionary. Αυτό είναι
#                               ΑΚΡΙΒΩΣ το payload που θα στέλνει αργότερα το Net
#                               autoload στον server (Φάση 4), ώστε οι φίλοι να
#                               βλέπουν την πρόοδό μας.
#
# ΤΙ ΕΙΝΑΙ ΔΗΜΟΣΙΟ: σκόπιμα ΜΟΝΟ ένα «στιγμιότυπο» επίδοσης (περιοχή, streak,
# επιτεύγματα, ισχύς ομάδας, πλήθος ηρώων/εξοπλισμού) — ΟΧΙ το πλήρες save
# (νομίσματα, κλειδιά, ποιο ακριβώς item είναι εξοπλισμένο). Το πλήρες save μένει
# τοπικό (υβριδικό μοντέλο).
#
# Autoload ΤΕΛΕΥΤΑΙΟ (διαβάζει GameData/Heroes/Achievements/Weapon-ArmorInventory)
# — δεν έχει δικό του persistence, όλα υπολογίζονται on-demand.

## Τα «κεφάλαια» προόδου, από το αρχικό προς το τελικό. Νέο κεφάλαιο = ένα entry
## εδώ + ένας έλεγχος στο get_region().
const REGION_VILLAGE := {"id": "village",     "label": "Το Χωριό"}
const REGION_FOREST  := {"id": "forest",      "label": "Το Δάσος της Μάγισσας"}
const REGION_DEEP    := {"id": "deep_forest", "label": "Τα Βάθη του Δάσους"}
const REGION_MORGANA := {"id": "morgana",     "label": "Ο Πύργος της Μόργκανας"}

## Εικόνες (PNG) για τις γραμμές στοιχείων του προφίλ — δείχνονται στο
## ProfilePopup (καρτέλα «Στοιχεία») ΚΑΙ στο FriendsPopup (κατάταξη φίλων, μόνο
## chapter/streak/team_power εκεί). Ίδιο μοτίβο με Currency.TEXTURE_ICONS/
## Heroes.STAT_TEXTURE_ICONS: προτιμάται η εικόνα, με emoji fallback αν λείψει
## το αρχείο (βλ. get_stat_icon_texture).
const STAT_TEXTURE_ICONS := {
	"chapter":      "res://Εικόνες/chapter_icon.png",
	"streak":       "res://Εικόνες/streak_icon.png",
	"team_power":   "res://Εικόνες/team_power_icon.png",
	"characters":   "res://Εικόνες/characters_icon.png",
	"weapons":      "res://Εικόνες/weapons_icon.png",
	"achievements": "res://Εικόνες/achievements_icon.png",
	"goblin":       "res://Εικόνες/goblin_icon.png",
	"tree":         "res://Εικόνες/tree_icon.png",
	"witch":        "res://Εικόνες/witch_icon.png",
}
const STAT_EMOJI_ICONS := {
	"chapter": "🗺", "streak": "🔥", "team_power": "💪", "characters": "🧑",
	"weapons": "⚔", "achievements": "🏆", "goblin": "👺", "tree": "🌳", "witch": "🔮",
}

## Texture εικονιδίου μιας γραμμής προφίλ, ή null αν δεν έχει οριστεί/λείπει το
## αρχείο — τα UI που δείχνουν στοιχεία πέφτουν τότε πίσω στο emoji
## (STAT_EMOJI_ICONS).
func get_stat_icon_texture(key: String) -> Texture2D:
	var path: String = STAT_TEXTURE_ICONS.get(key, "")
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null


## Το τρέχον «κεφάλαιο» — το ΜΑΚΡΙΝΟΤΕΡΟ ορόσημο που έχει περάσει ο παίκτης.
## Νίκη Μόργκανας > νίκη δέντρου > νίκη καλικάντζαρου (ξεκλείδωμα κάστρου) >
## αρχή. Παράγεται ΑΠΟΚΛΕΙΣΤΙΚΑ από αποθηκευμένα flags του GameData.
func get_region() -> Dictionary:
	if GameData.has_defeated_boss():
		return REGION_MORGANA
	if GameData.is_mini_boss_defeated("tree"):
		return REGION_DEEP
	if GameData.is_mini_boss_defeated("goblin"):
		return REGION_FOREST
	return REGION_VILLAGE


## Το δημόσιο στιγμιότυπο προόδου — το payload που θα κοινοποιείται στους φίλους.
## Όλα τα πεδία είναι απλοί τύποι (JSON-serializable), ώστε να στέλνεται αυτούσιο
## στον server (Φάση 4) χωρίς μετατροπές.
func build_public_profile() -> Dictionary:
	var region := get_region()
	return {
		"region_id": region["id"],
		"region_label": region["label"],
		"streak": GameData.get_streak(),
		"achievements": Achievements.get_unlocked_ids(),
		"achievements_count": Achievements.unlocked_count(),
		"achievements_total": Achievements.total_count(),
		"party_power": snappedf(Heroes.get_party_average_stat(), 0.1),
		"roster_size": Heroes.get_roster().size(),
		"gear_owned": _owned_gear_count(),
		"goblin_defeated": GameData.is_mini_boss_defeated("goblin"),
		"tree_defeated": GameData.is_mini_boss_defeated("tree"),
		"morgana_defeated": GameData.has_defeated_boss(),
		"last_active": Time.get_datetime_string_from_system(true),
	}


## Πλήθος αντικειμένων (όπλα + πανοπλίες) που κατέχει ο παίκτης — ένα ακόμα
## «σήμα προόδου» τώρα που δεν υπάρχει starter εξοπλισμός (όλα κερδίζονται).
func _owned_gear_count() -> int:
	var n := 0
	for cat in [WeaponInventory, ArmorInventory]:
		for category in cat.categories:
			for id in cat.get_items_in_category(category):
				if cat.is_owned(id):
					n += 1
	return n
