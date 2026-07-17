class_name BattleAnimations
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# BattleAnimations — κοινό σύστημα μαχητικών animations (boss + ήρωες)
# ═══════════════════════════════════════════════════════════════════════════
# Χτίζει SpriteFrames ΣΕ ΚΩΔΙΚΑ (AtlasTexture ανά frame, ίδιο «όλα σε κώδικα»
# ύφος με τα υπόλοιπα scripts) από τα spritesheets των συναδέλφων στον φάκελο
# res://Animations/. Το χρησιμοποιεί το boss_fight.gd και για τα boss (goblin/
# tree/witch, δεξιά) και για τους ήρωες (knight/frog/giant, αριστερά).
#
# ── ΓΙΑΤΙ ΧΡΕΙΑΖΕΤΑΙ ΚΑΝΟΝΙΚΟΠΟΙΗΣΗ ─────────────────────────────────────────
# Τα sheets είναι ΑΝΟΜΟΙΟΜΟΡΦΑ: μία ακολουθία επίθεσης απλώνεται σε πολλά
# αρχεία με ΔΙΑΦΟΡΕΤΙΚΟ μέγεθος κελιού ανά αρχείο (π.χ. witch attack: 600×600
# στα 3 πρώτα, 619×847 στο τελευταίο· goblin: κελιά 512 έως 956 πλάτος γιατί
# κάποια frames έχουν και το ιπτάμενο στιλέτο). Αν απλώς κόβαμε κελιά, η
# φιγούρα θα «χοροπηδούσε» σε κάθε αλλαγή αρχείου. Λύση: κάθε frame παίρνει
# AtlasTexture.margin ώστε ΟΛΑ τα frames ενός animation να ζουν σε ΕΝΑ κοινό
# εικονικό καμβά, με:
#   - τη ΓΡΑΜΜΗ ΠΟΔΙΩΝ (alpha scan του 1ου κελιού κάθε αρχείου) ευθυγραμμισμένη
#     ανάμεσα στα αρχεία — τα πόδια πατάνε πάντα στο ίδιο σημείο, και
#   - οριζόντια στοίχιση "center" (προεπιλογή) ή "left" (για sheets όπου το
#     σώμα μένει αριστερά και το εφέ πετάει δεξιά — goblin/witch attack).
#
# ── ΑΓΚΥΡΩΣΗ ΣΤΗ ΣΚΗΝΗ (class Fighter) ──────────────────────────────────────
# Ο Fighter (AnimatedSprite2D) τοποθετείται με place(x, ground_y, ύψος, flip):
#   - κλίμακα από το ΥΨΟΣ ΣΩΜΑΤΟΣ (κορυφή→πόδια του 1ου κελιού), όχι από το
#     ύψος καμβά — έτσι ΕΝΑ target ύψος δουλεύει για idle ΚΑΙ επίθεση παρότι
#     έχουν διαφορετικό framing,
#   - τα πόδια αγκυρώνονται στο (x, ground_y) και το ΚΕΝΤΡΟ ΣΩΜΑΤΟΣ στο x,
#     οπότε αλλαγή animation δεν μετακινεί τη φιγούρα,
#   - flip: όλα τα sheets κοιτάνε ΔΕΞΙΑ, άρα οι ήρωες (αριστερά) παίζουν ως
#     έχουν και τα boss (δεξιά) παίρνουν face_left=true.
#
# Τα SpriteFrames χτίζονται ΜΙΑ φορά ανά μαχητή και κρατιούνται σε static
# cache (το alpha scan διαβάζει εικόνες — δεν θέλουμε να ξανατρέχει σε κάθε
# άνοιγμα μάχης).

# ── Ορισμοί μαχητών ─────────────────────────────────────────────────────────
# Κάθε αρχείο: path + πλέγμα (cols×rows, ανάγνωση αριστερά→δεξιά, πάνω→κάτω).
# "count" = πόσα κελιά κρατάμε από το αρχείο (προεπιλογή: όλα) — έτσι το idle
# είναι το 1ο κελί του πρώτου sheet, ίδιο σώμα με την επίθεση, χωρίς «σκίρτημα».
const DEFS := {
	# ── Boss: Γερο-Ρίζας το Στοιχειωμένο Δέντρο (24 frames, 2×2 ανά αρχείο) ──
	"tree": {
		"anims": {
			"idle": {"fps": 1.0, "loop": true, "files": [
				{"path": "res://Animations/tree_animation/1_6.png", "cols": 2, "rows": 2, "count": 1},
			]},
			"attack": {"fps": 10.0, "loop": false, "files": [
				{"path": "res://Animations/tree_animation/1_6.png", "cols": 2, "rows": 2},
				{"path": "res://Animations/tree_animation/2_6.png", "cols": 2, "rows": 2},
				{"path": "res://Animations/tree_animation/3_6.png", "cols": 2, "rows": 2},
				{"path": "res://Animations/tree_animation/4_6.png", "cols": 2, "rows": 2},
				{"path": "res://Animations/tree_animation/5_6.png", "cols": 2, "rows": 2},
				{"path": "res://Animations/tree_animation/6_6.png", "cols": 2, "rows": 2},
			]},
		},
	},
	# ── Boss: Ζούμπας ο Καλικάντζαρος (24 frames — ρίχνει στιλέτο) ───────────
	# "left": στα φαρδιά κελιά (4.png, 956px) ο γκόμπλιν μένει αριστερά και το
	# στιλέτο πετάει δεξιά — η αριστερή στοίχιση κρατάει το σώμα ακίνητο.
	"goblin": {
		"anims": {
			"idle": {"fps": 1.0, "loop": true, "files": [
				{"path": "res://Animations/goblin_animation/1.png", "cols": 4, "count": 1},
			]},
			"attack": {"fps": 11.0, "loop": false, "align": "left", "files": [
				{"path": "res://Animations/goblin_animation/1.png", "cols": 4},
				{"path": "res://Animations/goblin_animation/2.png", "cols": 4},
				{"path": "res://Animations/goblin_animation/3.png", "cols": 4},
				{"path": "res://Animations/goblin_animation/4.png", "cols": 4},
				{"path": "res://Animations/goblin_animation/5.png", "cols": 4},
				{"path": "res://Animations/goblin_animation/6.png", "cols": 4},
			]},
		},
	},
	# ── Boss: Μόργκανα η Μάγισσα ─────────────────────────────────────────────
	# idle = το στατικό witch.png (ίδια εικόνα με το BossPopup — συνέχεια όψης).
	# attack = μωβ κεραυνός από το ραβδί (η βολή είναι ΨΗΜΕΝΗ στα frames 8-11).
	# shield = μαγική φούσκα προστασίας.
	"witch": {
		"anims": {
			"idle": {"fps": 1.0, "loop": true, "files": [
				{"path": "res://Εικόνες/witch.png", "cols": 1},
			]},
			"attack": {"fps": 9.0, "loop": false, "align": "left", "files": [
				{"path": "res://Animations/witch_animation/attack/attack 1.png", "cols": 4},
				{"path": "res://Animations/witch_animation/attack/attack 2.png", "cols": 4},
				{"path": "res://Animations/witch_animation/attack/attack 3.png", "cols": 4},
				{"path": "res://Animations/witch_animation/attack/attack 4.png", "cols": 3},
			]},
			"shield": {"fps": 9.0, "loop": false, "files": [
				{"path": "res://Animations/witch_animation/shield/witch 1.png", "cols": 4},
				{"path": "res://Animations/witch_animation/shield/witch 2.png", "cols": 4},
				{"path": "res://Animations/witch_animation/shield/witch 3.png", "cols": 3},
				{"path": "res://Animations/witch_animation/shield/witch 4.png", "cols": 4},
			]},
		},
	},
	# ── Ήρωας: Σερ Ατρόμητος (ιππότης) ──────────────────────────────────────
	# idle = k1.png (στάση)· attack = sheet_a/b/c (ύψωση → σπαθιά → επαναφορά).
	# Το master_frame.png είναι συμπυκνωμένη σύνοψη των ίδιων πόζων — δεν
	# χρειάζεται στο runtime.
	"knight": {
		"anims": {
			"idle": {"fps": 1.0, "loop": true, "files": [
				{"path": "res://Animations/knight_animation/k1.png", "cols": 1},
			]},
			"attack": {"fps": 12.0, "loop": false, "files": [
				{"path": "res://Animations/knight_animation/sheet_a.png", "cols": 4},
				{"path": "res://Animations/knight_animation/sheet_b.png", "cols": 4},
				{"path": "res://Animations/knight_animation/sheet_c.png", "cols": 4},
			]},
		},
	},
	# ── Ήρωας: Βρεκεκέξ ο Τοξότης (def_id "frog", 24 frames — ρίχνει βέλος) ──
	"frog": {
		"anims": {
			"idle": {"fps": 1.0, "loop": true, "files": [
				{"path": "res://Animations/archer_animation/fr1_4.png", "cols": 4, "count": 1},
			]},
			"attack": {"fps": 13.0, "loop": false, "files": [
				{"path": "res://Animations/archer_animation/fr1_4.png", "cols": 4},
				{"path": "res://Animations/archer_animation/fr5_8.png", "cols": 4},
				{"path": "res://Animations/archer_animation/fr9_12.png", "cols": 4},
				{"path": "res://Animations/archer_animation/fr13_16.png", "cols": 4},
				{"path": "res://Animations/archer_animation/fr17_20.png", "cols": 4},
				{"path": "res://Animations/archer_animation/fr21_24.png", "cols": 4},
			]},
		},
	},
	# ── Ήρωας: Βράχος ο Γίγαντας ─────────────────────────────────────────────
	# Το sheet 1 είναι κύκλος βαδίσματος — δεν ταιριάζει σε μάχη επί τόπου,
	# οπότε η επίθεση ξεκινά από το sheet 2 (όρθιος → γροθιές → γροθοκόπημα
	# εδάφους με σκόνη → επαναφορά).
	"giant": {
		"anims": {
			"idle": {"fps": 1.0, "loop": true, "files": [
				{"path": "res://Animations/giant_animation/sprite sheet 2.png", "cols": 4, "count": 1},
			]},
			"attack": {"fps": 12.0, "loop": false, "files": [
				{"path": "res://Animations/giant_animation/sprite sheet 2.png", "cols": 4},
				{"path": "res://Animations/giant_animation/sprite sheet 3.png", "cols": 4},
				{"path": "res://Animations/giant_animation/sprite sheet 4.png", "cols": 4},
				{"path": "res://Animations/giant_animation/sprite sheet 5.png", "cols": 4},
				{"path": "res://Animations/giant_animation/sprite sheet 6.png", "cols": 4},
				{"path": "res://Animations/giant_animation/sprite sheet 7.png", "cols": 4},
			]},
		},
	},
}

# Alpha scan: πόσο αδιαφανές μετράει ως «στέρεο» (0-255) και πόσα στέρεα
# δείγματα χρειάζεται μια γραμμή/στήλη — ώστε αραιές καπνιές/λάμψεις να μην
# μετράνε ως πόδια/άκρη σώματος (ίδια λογική με το παλιό _detect_foot του
# boss_fight.gd, γενικευμένη και στους 2 άξονες).
const SOLID_ALPHA := 178
const MIN_RUN := 6
const SCAN_STEP := 2

# SpriteFrames + μετρικές ανά μαχητή — χτίζονται ΜΙΑ φορά (το alpha scan
# διαβάζει pixels), μετά μοιράζονται σε κάθε Fighter instance.
static var _cache: Dictionary = {}


## Επιστρέφει {"frames": SpriteFrames, "meta": {anim: {cell_w, cell_h, foot,
## body_top, body_cx}}} για τον μαχητή — από το cache αν έχει ήδη χτιστεί.
static func get_bundle(fighter_id: String) -> Dictionary:
	if _cache.has(fighter_id):
		return _cache[fighter_id]
	var bundle := _build(fighter_id)
	_cache[fighter_id] = bundle
	return bundle


static func _build(fighter_id: String) -> Dictionary:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	var meta := {}
	var def: Dictionary = DEFS.get(fighter_id, {})
	for anim_name in def.get("anims", {}):
		var anim: Dictionary = def["anims"][anim_name]
		var align_left: bool = str(anim.get("align", "center")) == "left"

		# ── Πέρασμα 1: φόρτωση + μετρικές 1ου κελιού κάθε αρχείου ───────────
		var infos: Array = []
		for file_def in anim["files"]:
			var tex: Texture2D = load(str(file_def["path"]))
			if tex == null:
				# Χωρίς import (πρώτο άνοιγμα) το load αποτυγχάνει — προειδοποίηση
				# αντί για crash. Άνοιξε μία φορά τον Godot editor για import.
				push_warning("BattleAnimations: αδυναμία φόρτωσης %s — άνοιξε τον editor για import." % file_def["path"])
				continue
			var cols: int = int(file_def.get("cols", 1))
			var rows: int = int(file_def.get("rows", 1))
			var cw: float = float(tex.get_width()) / float(cols)
			var ch: float = float(tex.get_height()) / float(rows)
			var bounds := _solid_bounds(tex, int(round(cw)), int(round(ch)))
			infos.append({
				"tex": tex, "cols": cols, "rows": rows,
				"count": int(file_def.get("count", cols * rows)),
				"cw": cw, "ch": ch,
				"foot": bounds.position.y + bounds.size.y,
				"top": bounds.position.y,
				"left": bounds.position.x,
				"right": bounds.position.x + bounds.size.x,
			})
		if infos.is_empty():
			continue

		# ── Πέρασμα 2: κοινός εικονικός καμβάς του animation ─────────────────
		# Πόδια ευθυγραμμισμένα στο virtual_foot· οριζόντια "left" (κοινή
		# αριστερή άκρη σώματος) ή "center" (κεντραρισμένα κελιά).
		var virtual_foot := 0.0
		var virtual_left := 0.0
		for info in infos:
			virtual_foot = maxf(virtual_foot, float(info["foot"]))
			virtual_left = maxf(virtual_left, float(info["left"]))
		var virtual_h := 0.0
		var virtual_w := 0.0
		for info in infos:
			info["pad_y"] = virtual_foot - float(info["foot"])
			virtual_h = maxf(virtual_h, float(info["pad_y"]) + float(info["ch"]))
			if align_left:
				info["pad_x"] = virtual_left - float(info["left"])
				virtual_w = maxf(virtual_w, float(info["pad_x"]) + float(info["cw"]))
			else:
				virtual_w = maxf(virtual_w, float(info["cw"]))
		if not align_left:
			for info in infos:
				info["pad_x"] = (virtual_w - float(info["cw"])) / 2.0

		# ── Πέρασμα 3: κόψιμο κελιών σε AtlasTextures με margin ──────────────
		sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, bool(anim.get("loop", false)))
		sf.set_animation_speed(anim_name, float(anim.get("fps", 8.0)))
		for info in infos:
			var tex: Texture2D = info["tex"]
			var cols: int = info["cols"]
			var rows: int = info["rows"]
			var taken := 0
			for row in rows:
				for col in cols:
					if taken >= int(info["count"]):
						break
					taken += 1
					# round(i*W/n): ακέραια όρια χωρίς κενά ακόμη κι όταν το
					# μέγεθος δεν διαιρείται τέλεια (βλ. ίδιο μοτίβο στο παλιό
					# boss_fight.gd).
					var x0 := int(round(float(col) * tex.get_width() / cols))
					var x1 := int(round(float(col + 1) * tex.get_width() / cols))
					var y0 := int(round(float(row) * tex.get_height() / rows))
					var y1 := int(round(float(row + 1) * tex.get_height() / rows))
					var at := AtlasTexture.new()
					at.atlas = tex
					at.region = Rect2(x0, y0, x1 - x0, y1 - y0)
					# filter_clip: χωρίς αυτό το φιλτράρισμα «τραβάει» pixels
					# από το διπλανό frame στα κελιά που ακουμπάνε μεταξύ τους.
					at.filter_clip = true
					at.margin = Rect2(
						Vector2(float(info["pad_x"]), float(info["pad_y"])),
						Vector2(virtual_w - float(info["cw"]), virtual_h - float(info["ch"])))
					sf.add_frame(anim_name, at)

		# Μετρικές αγκύρωσης (σε συντεταγμένες εικονικού καμβά). Το σώμα
		# μετριέται από το 1ο κελί του ΠΡΩΤΟΥ αρχείου — αυτό ορίζει την
		# «κανονική» στάση του animation.
		var first: Dictionary = infos[0]
		meta[anim_name] = {
			"cell_w": virtual_w,
			"cell_h": virtual_h,
			"foot": virtual_foot,
			"body_top": float(first["pad_y"]) + float(first["top"]),
			"body_cx": float(first["pad_x"]) + (float(first["left"]) + float(first["right"])) / 2.0,
		}
	return {"frames": sf, "meta": meta}


## Όρια «στέρεου» περιεχομένου του 1ου κελιού (πάνω-αριστερά) ενός sheet:
## γραμμή/στήλη μετράει μόνο αν έχει ≥MIN_RUN έντονα αδιαφανή δείγματα, ώστε
## καπνιές/λάμψεις να μην μετράνε. Επιστρέφει Rect2 σε συντεταγμένες κελιού.
static func _solid_bounds(tex: Texture2D, cw: int, ch: int) -> Rect2:
	var img: Image = tex.get_image()
	if img == null:
		return Rect2(0, 0, cw, ch)
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var data: PackedByteArray = img.get_data()
	var img_w := img.get_width()
	var w := mini(cw, img_w)
	var h := mini(ch, img.get_height())

	var row_hits := PackedInt32Array()
	row_hits.resize(h)
	var col_hits := PackedInt32Array()
	col_hits.resize(w)
	for y in range(0, h, SCAN_STEP):
		var base := y * img_w
		for x in range(0, w, SCAN_STEP):
			if data[(base + x) * 4 + 3] >= SOLID_ALPHA:
				row_hits[y] += 1
				col_hits[x] += 1

	var top := -1
	var bot := -1
	for y in range(0, h, SCAN_STEP):
		if row_hits[y] >= MIN_RUN:
			if top < 0:
				top = y
			bot = y
	var left := -1
	var right := -1
	for x in range(0, w, SCAN_STEP):
		if col_hits[x] >= MIN_RUN:
			if left < 0:
				left = x
			right = x
	if top < 0 or left < 0:
		return Rect2(0, 0, cw, ch)
	return Rect2(left, top, right - left + 1, bot - top + 1)


# ═══════════════════════════════════════════════════════════════════════════
# Fighter — AnimatedSprite2D με αγκύρωση ποδιών/σώματος
# ═══════════════════════════════════════════════════════════════════════════
class Fighter extends AnimatedSprite2D:
	var _anim_meta: Dictionary = {}
	var anchor_x := 0.0        # πού «στέκεται» οριζόντια το κέντρο του σώματος
	var ground_y := 0.0        # πού πατάνε τα πόδια
	var target_h := 300.0      # εμφανιζόμενο ύψος ΣΩΜΑΤΟΣ (όχι καμβά)
	var face_left := false     # true = καθρέφτισμα (τα sheets κοιτάνε δεξιά)

	func _init(fighter_id: String) -> void:
		centered = true
		var bundle := BattleAnimations.get_bundle(fighter_id)
		sprite_frames = bundle["frames"]
		_anim_meta = bundle["meta"]

	func place(x: float, gy: float, h: float, left: bool) -> void:
		anchor_x = x
		ground_y = gy
		target_h = h
		face_left = left

	func has_anim(anim_name: String) -> bool:
		return sprite_frames != null and sprite_frames.has_animation(anim_name)

	## Παίζει το animation ΚΑΙ διορθώνει scale/flip/position ώστε το σώμα να
	## μένει καρφωμένο στο (anchor_x, ground_y) — βλ. σχόλιο κορυφής.
	func play_anim(anim_name: String) -> void:
		if not has_anim(anim_name) or not _anim_meta.has(anim_name):
			return
		var m: Dictionary = _anim_meta[anim_name]
		var body_h: float = maxf(float(m["foot"]) - float(m["body_top"]), 1.0)
		var s: float = target_h / body_h
		var cw: float = m["cell_w"]
		var ch: float = m["cell_h"]
		var cx_off: float = cw / 2.0 - float(m["body_cx"])   # κέντρο καμβά -> κέντρο σώματος
		flip_h = face_left
		scale = Vector2(s, s)
		position = Vector2(
			anchor_x + cx_off * s * (-1.0 if face_left else 1.0),
			ground_y + ch * s / 2.0 - float(m["foot"]) * s)
		frame = 0
		play(anim_name)
