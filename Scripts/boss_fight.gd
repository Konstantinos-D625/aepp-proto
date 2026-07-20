extends Control

# ═══════════════════════════════════════════════════════════════════════════
# BossFight — η animated μάχη ΟΛΩΝ των boss (Μόργκανα, καλικάντζαρος, δέντρο)
# ═══════════════════════════════════════════════════════════════════════════
# ΕΝΑ scene/script για κάθε animated encounter. Το boss στέκεται ΔΕΞΙΑ
# (καθρεφτισμένο — τα spritesheets κοιτάνε δεξιά) και επιτίθεται στους ήρωες
# της ΕΝΕΡΓΗΣ ΟΜΑΔΑΣ, που στέκονται ΑΡΙΣΤΕΡΑ και παίζουν τα δικά τους attack
# animations. Οι ήρωες είναι όσοι έχουν τοποθετηθεί σε party slots από το
# sidebar -> Χαρακτήρες (Heroes.get_active_party) — knight/frog/giant έχουν
# πλήρη animations (φάκελος res://Animations/, βλ. battle_animations.gd), ο
# starter (boy/girl) μένει στατικός με ελαφρύ «αναπνευστικό» bob.
#
# ── ΠΟΤΕ ΑΝΟΙΓΕΙ ─────────────────────────────────────────────────────────────
# Είναι το ΤΕΛΕΥΤΑΙΟ βήμα κάθε boss ακολουθίας:
#   - Μόργκανα: σπίτι μάγισσας -> BossPopup (διάλογος -> odds -> «Επίθεση») -> ΕΔΩ
#   - mini bosses: witch map -> MiniBossPopup (διάλογος -> odds -> «Επίθεση») -> ΕΔΩ
# Το popup καλεί show_popup(probability, boss_id) περνώντας την πιθανότητα
# νίκης (υπολογισμένη εκεί από τον μέσο όρο της ομάδας — βλ. Heroes.win_probability)
# και ΠΟΙΟ boss είναι ("witch"/"goblin"/"tree", βλ. BOSS_DEFS παρακάτω).
#
# ── ΡΟΗ ΜΑΧΗΣ ────────────────────────────────────────────────────────────────
#   1. IDLE    : το boss στην «κανονική» στάση του, οι ήρωες idle.
#   2. CASTING : τυχαίος κύκλος επιθέσεων boss (σταθμισμένη επιλογή animation +
#      τυχαίες παύσεις)· στο «καίριο» frame (IMPACT_FRAMES) το χτύπημα «φτάνει»
#      σε τυχαίο ήρωα (λάμψη + κόκκινο blink). Παράλληλα ΚΑΘΕ ήρωας παίζει το
#      δικό του attack animation σε δικό του τυχαίο ρυθμό (τόξο/σπαθιά/γροθιά
#      — τα εφέ είναι ψημένα στα sheets).
#   3. FINISHED: μετά από FIGHT_DURATION δευτερόλεπτα γίνεται το roll νίκης με
#      βάση την πιθανότητα του popup, καταγράφεται το αποτέλεσμα και βγαίνει
#      overlay ΝΙΚΗΣ/ΗΤΤΑΣ. Η καταγραφή διαφέρει ανά boss:
#        - Μόργκανα: GameData.record_boss_win/loss (η ήττα κάνει κάθε επόμενη
#          προσπάθεια να χρεώνεται — βλ. boss_popup.gd).
#        - mini: ανταμοιβή σε Χαλκό (+ το bootstrap κλειδί του καλικάντζαρου
#          στην πρώτη νίκη) + GameData.record_mini_boss_win/loss — ΙΔΙΑ λογική
#          που έκανε πριν το mini_boss_popup.gd με το στιγμιαίο roll· τώρα ζει
#          εδώ ώστε το roll να κρίνεται ΜΕΤΑ την animated μάχη.
#
# ── ΤΕΧΝΙΚΑ ─────────────────────────────────────────────────────────────────
# Όλα τα SpriteFrames χτίζονται σε κώδικα από τα sheets των συναδέλφων μέσω
# του BattleAnimations (κανονικοποίηση κελιών + αγκύρωση ποδιών/σώματος ώστε
# οι φιγούρες να μη «χοροπηδάνε» — βλ. σχόλια στο battle_animations.gd).

const BossPopupScript  = preload("res://Scripts/boss_popup.gd")
const MiniBossScript   = preload("res://Scripts/mini_boss_popup.gd")

# ── Ρυθμός επιθέσεων boss ────────────────────────────────────────────────────
# Οι νέες επιθέσεις είναι μεγάλες ακολουθίες (1.5-2.2s), οπότε οι παύσεις είναι
# μικρότερες από το παλιό witch-only encounter.
const IDLE_GAP_MIN      := 0.5
const IDLE_GAP_MAX      := 1.4
const LONG_PAUSE_CHANCE := 0.15
const LONG_PAUSE_MIN    := 2.0
const LONG_PAUSE_MAX    := 3.0

# ── Ρυθμός επιθέσεων ηρώων ──────────────────────────────────────────────────
const HERO_FIRST_MIN := 0.6
const HERO_FIRST_MAX := 2.0
const HERO_GAP_MIN   := 1.6
const HERO_GAP_MAX   := 3.6

# ── Διάρκεια μάχης ───────────────────────────────────────────────────────────
# Μετά από τόσα δευτερόλεπτα κρίνεται νίκη/ήττα (roll με την πιθανότητα του
# popup). 8s ώστε να προλάβουν και οι δύο πλευρές 2-3 πλήρεις επιθέσεις.
const FIGHT_DURATION := 8.0

# ── Layout (σχεδιασμός 1080×1920 portrait, ίδιο με project) ──────────────────
const W := 1080.0
const H := 1920.0
const HUD_TOP := 178.0

# Θέσεις ηρώων ΑΡΙΣΤΕΡΑ: (x, +y από το έδαφος) ανά σειρά ενεργού slot. Οι
# επόμενοι μπαίνουν πιο «μπροστά» (μεγαλύτερο y = πιο κοντά στην κάμερα) και
# προστίθενται αργότερα στο δέντρο, άρα ζωγραφίζονται από πάνω — σωστό βάθος.
const HERO_SPOTS: Array = [
	Vector2(350, 0), Vector2(150, 30), Vector2(255, 100),
	Vector2(110, 130), Vector2(330, 160), Vector2(190, 200),
]
# Εμφανιζόμενο ύψος σώματος ανά animated ήρωα (def_id) — ο γίγαντας ΕΙΝΑΙ
# μεγαλύτερος. Οι υπόλοιποι (starter boy/girl κ.λπ.) παίρνουν STATIC_HERO_H.
const HERO_HEIGHTS := {"knight": 300.0, "frog": 300.0, "giant": 400.0}
const STATIC_HERO_H := 300.0

# ── Παλέτα (ξύλο/χρυσό — ίδια γραμμή με boss_popup.gd/mini_boss_popup.gd) ────
const C_WOOD    := Color(0.200, 0.120, 0.052)
const C_WOOD_D  := Color(0.130, 0.075, 0.028)
const C_GOLD    := Color(0.940, 0.760, 0.160)
const C_GOLD_S  := Color(1.000, 0.920, 0.560)
const C_MAGIC   := Color(0.520, 0.180, 0.880)
const C_FOREST  := Color(0.180, 0.420, 0.160)
const C_PARCH_D := Color(0.720, 0.680, 0.760)
const C_CRIMSON := Color(0.580, 0.058, 0.058)
const C_OK      := Color(0.560, 0.900, 0.460)

# ── Ορισμοί boss ─────────────────────────────────────────────────────────────
# Ό,τι διαφέρει ανά boss: μαχητής (BattleAnimations), τίτλος, φόντο + γραμμή
# εδάφους του, θέση/ύψος, χρώματα HUD, σταθμισμένες επιθέσεις, «καίριο» frame
# κάθε επίθεσης (πότε φτάνει το χτύπημα στον ήρωα) και το είδος καταγραφής
# ("morgana" ή "mini"). Τα gameplay δεδομένα των mini (ανταμοιβές/ατάκες/κόστη)
# ΔΕΝ διπλογράφονται — διαβάζονται από το MiniBossScript.BOSS_DEFS.
const BOSS_DEFS := {
	"witch": {
		"fighter": "witch",
		"title": "🔮  Μόργκανα η Μάγισσα",
		"bg": "res://Εικόνες/boss_bg.png",
		"ground_y": 1010.0, "boss_x": 815.0, "boss_h": 470.0,
		"theme": C_MAGIC,
		"flash": Color(0.45, 0.12, 0.75),
		"attacks": {"attack": 0.72, "shield": 0.28},
		"impact_frames": {"attack": 11},   # τελευταίο frame του ψημένου κεραυνού
		"kind": "morgana",
	},
	"goblin": {
		"fighter": "goblin",
		"bg": "res://Εικόνες/bad_goblin_bg.png",
		"ground_y": 1330.0, "boss_x": 800.0, "boss_h": 400.0,
		"theme": C_FOREST,
		"flash": Color(0.45, 0.28, 0.06),
		"attacks": {"attack": 1.0},
		"impact_frames": {"attack": 15},   # το στιλέτο στη μέγιστη απόστασή του
		"kind": "mini",
	},
	"tree": {
		"fighter": "tree",
		"bg": "res://Εικόνες/bad_tree_bg.png",
		"ground_y": 1390.0, "boss_x": 800.0, "boss_h": 560.0,
		"theme": C_FOREST,
		"flash": Color(0.20, 0.40, 0.10),
		"attacks": {"attack": 1.0},
		"impact_frames": {"attack": 18},   # η εξαπόλυση των νυχιών (lunge)
		"kind": "mini",
	},
}

enum State { HIDDEN, IDLE, CASTING, FINISHED }

var _state: int = State.HIDDEN
var _boss_id := "witch"
var _last_attack := ""               # για αποφυγή διπλής ίδιας επίθεσης στη σειρά
var _fx_fired := false               # έχει ήδη «φτάσει» το χτύπημα της τρέχουσας επίθεσης;

# ── Αποτέλεσμα μάχης (έρχονται από το popup) ─────────────────────────────────
var _win_prob: float = 1.0           # πιθανότητα νίκης (0-1) — για το roll στο τέλος
var _fight_id := 0                   # «γενιά» μάχης: ακυρώνει stale timers σε reopen
var _result_overlay: Control         # overlay αποτελέσματος (καθαρίζεται σε reopen/close)

# ── Σκηνικά / actors ─────────────────────────────────────────────────────────
var _bg: TextureRect
var _spark_root: Control
var _actors: Node2D                  # ήρωες + boss (καθαρίζεται σε κάθε μάχη)
var _fx: Node2D                      # λάμψεις χτυπημάτων, πάνω από τους actors
var _boss: BattleAnimations.Fighter
var _heroes: Array = []              # [{node, chest: Vector2}] — στόχοι χτυπημάτων

# ── HUD (χτίζεται μία φορά, ξαναβάφεται ανά boss) ────────────────────────────
var _hud_panel: Panel
var _hud_name: Label
var _hud_hp: ColorRect
var _back_btn: Button

var _glow_tex: GradientTexture2D     # μαλακή λάμψη (impact flash)

# ═══════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_glow_tex = _radial_glow()
	_build_background()
	_spark_root = Control.new()
	_spark_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_spark_root)
	_actors = Node2D.new()
	add_child(_actors)
	_fx = Node2D.new()
	add_child(_fx)
	_build_hud()

func _def() -> Dictionary:
	return BOSS_DEFS.get(_boss_id, BOSS_DEFS["witch"])

## Τίτλος HUD: της Μόργκανας είναι δικός της· των mini έρχεται από το
## MiniBossScript.BOSS_DEFS (μία πηγή αλήθειας για όνομα/εικονίδιο).
func _title() -> String:
	var d := _def()
	if d.has("title"):
		return str(d["title"])
	var md: Dictionary = MiniBossScript.BOSS_DEFS.get(_boss_id, {})
	return "%s  %s" % [md.get("icon", ""), md.get("name", "")]

## Καλείται από τα popups (κουμπί «Επίθεση»). Δέχεται την πιθανότητα νίκης
## (υπολογισμένη εκεί) και το boss id, στήνει σκηνικό/boss/ήρωες και ξεκινάει
## τον κύκλο επιθέσεων ΚΑΙ το χρονόμετρο ολοκλήρωσης (FIGHT_DURATION).
func show_popup(probability: float = 1.0, boss_id: String = "witch") -> void:
	if not BOSS_DEFS.has(boss_id):
		boss_id = "witch"
	_boss_id  = boss_id
	visible   = true
	_win_prob = clampf(probability, 0.0, 1.0)
	_last_attack = ""
	_fx_fired = false
	# ΝΕΑ «γενιά» μάχης ΠΡΙΝ προγραμματιστεί οτιδήποτε — όλα τα timers που
	# ακολουθούν (επιθέσεις boss/ηρώων, ολοκλήρωση) κουβαλάνε αυτό το id και
	# αγνοούνται αν στο μεταξύ ξεκινήσει νέα μάχη ή κλείσει το popup.
	_fight_id += 1
	if is_instance_valid(_result_overlay):
		_result_overlay.queue_free()
		_result_overlay = null
	_apply_boss_visuals()
	_build_actors()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.45)
	_enter_idle()
	_start_hero_cycles()
	_start_fight_timer()

func close_popup() -> void:
	_state = State.HIDDEN   # ακυρώνει τυχόν προγραμματισμένη επόμενη επίθεση
	_fight_id += 1          # ακυρώνει εκκρεμή χρονόμετρα (ολοκλήρωσης/ηρώων)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.30)
	tw.tween_callback(func(): visible = false)

## Χρονόμετρο ολοκλήρωσης: μετά από FIGHT_DURATION κρίνεται το αποτέλεσμα. Το
## _fight_id εξασφαλίζει ότι ένα stale timer (π.χ. Πίσω + ξανά-άνοιγμα) δεν θα
## ολοκληρώσει πρόωρα τη ΝΕΑ μάχη.
func _start_fight_timer() -> void:
	var id := _fight_id
	var t := get_tree().create_timer(FIGHT_DURATION)
	t.timeout.connect(func():
		if id == _fight_id and visible and _state != State.FINISHED:
			_conclude_fight())

## Τέλος μάχης: roll με βάση την πιθανότητα του popup + καταγραφή ανά είδος
## boss (βλ. σχόλιο κορυφής) + overlay αποτελέσματος.
func _conclude_fight() -> void:
	_state = State.FINISHED
	var won: bool = randf() < _win_prob
	if str(_def()["kind"]) == "morgana":
		if won:
			GameData.record_boss_win()
		else:
			GameData.record_boss_loss()
	else:
		var md: Dictionary = MiniBossScript.BOSS_DEFS.get(_boss_id, {})
		if won:
			# ΙΔΙΑ ανταμοιβή/καταγραφή με το παλιό στιγμιαίο roll του
			# mini_boss_popup._do_fight: Χαλκός + (μόνο goblin) το bootstrap
			# κλειδί + η πανοπλία-τρόπαιο, ΜΙΑ φορά — το record_mini_boss_win
			# κλειδώνει το boss.
			Currency.add(MiniBossScript.REWARD_CURRENCY, int(md.get("reward", 0)))
			var key_reward: Dictionary = md.get("key_reward", {})
			if not key_reward.is_empty():
				KeyInventory.add_key(key_reward["value"], str(key_reward["category"]))
			var armor_reward := str(md.get("armor_reward", ""))
			if armor_reward != "":
				ArmorInventory.grant(armor_reward)
			GameData.record_mini_boss_win(_boss_id)
		else:
			GameData.record_mini_boss_loss(_boss_id)
	_show_result(won)

# ═══════════════════════════════════════════════════════════════════════════
# STATE MACHINE (boss)
# ═══════════════════════════════════════════════════════════════════════════
func _enter_idle() -> void:
	_state = State.IDLE
	if _boss:
		_boss.play_anim("idle")
	_schedule_next_attack()

## Τυχαία παύση (με περιστασιακή μεγαλύτερη ανάπαυλα) — το boss μένει idle
## όσο τρέχει ο χρόνος, μετά επιτίθεται.
func _schedule_next_attack() -> void:
	var gap: float
	if randf() < LONG_PAUSE_CHANCE:
		gap = randf_range(LONG_PAUSE_MIN, LONG_PAUSE_MAX)
	else:
		gap = randf_range(IDLE_GAP_MIN, IDLE_GAP_MAX)
	var id := _fight_id
	var t := get_tree().create_timer(gap)
	t.timeout.connect(func():
		if id == _fight_id and _state == State.IDLE and visible:
			_do_attack())

func _do_attack() -> void:
	_state = State.CASTING
	_fx_fired = false
	if _boss:
		_boss.play_anim(_pick_attack())

## Σταθμισμένη τυχαία επιλογή επίθεσης από το def του boss (η μάγισσα έχει
## attack/shield, τα mini μόνο attack). Ένα reroll για να αποφεύγεται η ίδια
## επίθεση δύο φορές στη σειρά.
func _pick_attack() -> String:
	var atk := _weighted_attack()
	if atk == _last_attack:
		atk = _weighted_attack()
	_last_attack = atk
	return atk

func _weighted_attack() -> String:
	var attacks: Dictionary = _def()["attacks"]
	var total := 0.0
	for k in attacks:
		total += float(attacks[k])
	var r := randf() * total
	for k in attacks:
		r -= float(attacks[k])
		if r <= 0.0:
			return str(k)
	return str(attacks.keys()[0])

func _on_boss_anim_finished() -> void:
	if _boss and _boss.animation != "idle" and _state == State.CASTING:
		_enter_idle()

## Το χτύπημα «φτάνει» ΑΚΡΙΒΩΣ στο καίριο frame της επίθεσης (μία φορά):
## λάμψη + κόκκινο blink σε τυχαίο ήρωα + σύντομο flash οθόνης.
func _on_boss_frame_changed() -> void:
	if _fx_fired or _boss == null or _state != State.CASTING:
		return
	var impacts: Dictionary = _def()["impact_frames"]
	if not impacts.has(_boss.animation):
		return
	if _boss.frame >= int(impacts[_boss.animation]):
		_fx_fired = true
		_strike_hero()

# ═══════════════════════════════════════════════════════════════════════════
# ΕΦΕ ΧΤΥΠΗΜΑΤΩΝ (τα projectiles — στιλέτο/κεραυνός/νύχια — είναι ψημένα στα
# spritesheets· εδώ μόνο η άφιξη του χτυπήματος πάνω στον ήρωα)
# ═══════════════════════════════════════════════════════════════════════════
func _strike_hero() -> void:
	if _heroes.is_empty():
		return
	var target: Dictionary = _heroes.pick_random()
	var node: Node2D = target["node"]
	if not is_instance_valid(node):
		return
	_impact_flash(target["chest"])
	# Κόκκινο blink «πόνου» στον ήρωα που δέχτηκε το χτύπημα
	var tw := create_tween()
	tw.tween_property(node, "modulate", Color(1.0, 0.35, 0.35), 0.10)
	tw.tween_property(node, "modulate", Color.WHITE, 0.30)
	var d := _def()
	_screen_flash(d["flash"], 0.22, 0.40)

## Σύντομη λάμψη πρόσκρουσης πάνω στον ήρωα.
func _impact_flash(pos: Vector2) -> void:
	var flash := Sprite2D.new()
	flash.texture  = _glow_tex
	flash.position = pos
	flash.scale    = Vector2(0.35, 0.35)
	flash.modulate = Color(1.0, 0.85, 1.0, 1.0)
	_fx.add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "scale", Vector2(1.15, 1.15), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(flash, "modulate:a", 0.0, 0.28)
	tw.tween_callback(flash.queue_free)

## Full-screen flash στο χρώμα του boss — Control ColorRect, σβήνει μόνο του.
func _screen_flash(col: Color, peak: float, dur: float) -> void:
	var f := ColorRect.new()
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f.color = Color(col.r, col.g, col.b, 0.0)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(f)
	var tw := create_tween()
	tw.tween_property(f, "color:a", peak, dur * 0.3)
	tw.tween_property(f, "color:a", 0.0, dur * 0.7)
	tw.tween_callback(f.queue_free)

# ═══════════════════════════════════════════════════════════════════════════
# ΚΑΤΑΣΚΕΥΗ ACTORS (boss δεξιά + ήρωες ενεργής ομάδας αριστερά)
# ═══════════════════════════════════════════════════════════════════════════
func _build_actors() -> void:
	for c in _actors.get_children():
		c.queue_free()
	_heroes.clear()
	_build_party()
	_build_boss()

func _build_boss() -> void:
	var d := _def()
	_boss = BattleAnimations.Fighter.new(str(d["fighter"]))
	# face_left=true: τα sheets κοιτάνε δεξιά, το boss στέκεται δεξιά και
	# κοιτάει/χτυπάει προς τους ήρωες (αριστερά).
	_boss.place(float(d["boss_x"]), float(d["ground_y"]), float(d["boss_h"]), true)
	_actors.add_child(_boss)
	_boss.animation_finished.connect(_on_boss_anim_finished)
	_boss.frame_changed.connect(_on_boss_frame_changed)

## Οι ήρωες της ενεργής ομάδας (sidebar -> Χαρακτήρες), στις θέσεις HERO_SPOTS.
## Όσοι έχουν animations (knight/frog/giant) γίνονται Fighter· οι υπόλοιποι
## (starter boy/girl) στατικό Sprite2D με «αναπνευστικό» bob.
func _build_party() -> void:
	var d := _def()
	var ground: float = float(d["ground_y"])
	var party := Heroes.get_active_party()
	for i in range(mini(party.size(), HERO_SPOTS.size())):
		var hero: Dictionary = party[i]
		var spot: Vector2 = HERO_SPOTS[i]
		var def_id := str(hero.get("def_id", ""))
		var gy := ground + spot.y
		var node: Node2D
		var h: float
		if BattleAnimations.DEFS.has(def_id):
			h = float(HERO_HEIGHTS.get(def_id, STATIC_HERO_H))
			var f := BattleAnimations.Fighter.new(def_id)
			f.place(spot.x, gy, h, false)   # κοιτάνε δεξιά, προς το boss
			f.play_anim("idle")
			node = f
		else:
			h = STATIC_HERO_H
			node = _build_static_hero(hero, spot.x, gy, h)
		_actors.add_child(node)
		_heroes.append({"node": node, "chest": Vector2(spot.x, gy - h * 0.55)})

## Στατικός ήρωας (χωρίς sheets): κομμένη εικόνα από το Heroes/GameData με τα
## πόδια στο έδαφος + ελαφρύ idle bob (ίδιο μοτίβο με τον παλιό «παίκτη»).
func _build_static_hero(hero: Dictionary, x: float, gy: float, h: float) -> Node2D:
	var root := Node2D.new()
	root.position = Vector2(x, gy)
	var tex: Texture2D = Heroes.hero_texture(hero)
	var spr := Sprite2D.new()
	if tex:
		spr.texture = tex
		var s: float = h / tex.get_height()
		spr.scale = Vector2(s, s)
		spr.centered = true
		spr.position = Vector2(0, -tex.get_height() * s / 2.0)
	root.add_child(spr)
	var tw := spr.create_tween()
	tw.set_loops()
	tw.tween_property(spr, "position:y", spr.position.y - 7.0, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(spr, "position:y", spr.position.y, 1.6).set_trans(Tween.TRANS_SINE)
	return root

# ── Κύκλος επιθέσεων ηρώων ──────────────────────────────────────────────────
# Κάθε animated ήρωας παίζει το attack του σε δικό του τυχαίο ρυθμό, ανεξάρτητα
# από το boss (καθαρά οπτικό — το αποτέλεσμα κρίνεται από την πιθανότητα).
func _start_hero_cycles() -> void:
	for entry in _heroes:
		var node: Node2D = entry["node"]
		if node is BattleAnimations.Fighter:
			_schedule_hero_attack(node, randf_range(HERO_FIRST_MIN, HERO_FIRST_MAX))

func _schedule_hero_attack(f: BattleAnimations.Fighter, delay: float) -> void:
	var id := _fight_id
	var t := get_tree().create_timer(delay)
	t.timeout.connect(func():
		if id != _fight_id or not visible or _state == State.FINISHED or _state == State.HIDDEN:
			return
		if not is_instance_valid(f) or not f.has_anim("attack"):
			return
		f.play_anim("attack")
		f.animation_finished.connect(func():
			if id == _fight_id and is_instance_valid(f):
				f.play_anim("idle")
				_schedule_hero_attack(f, randf_range(HERO_GAP_MIN, HERO_GAP_MAX))
		, CONNECT_ONE_SHOT))

# ═══════════════════════════════════════════════════════════════════════════
# ΣΚΗΝΙΚΟ (φόντο ανά boss + λαμπυρίσματα στο χρώμα του)
# ═══════════════════════════════════════════════════════════════════════════
func _build_background() -> void:
	_bg = TextureRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	# Ελαφρύ σκοτείνιασμα ώστε να «κάθονται» καλύτερα οι φιγούρες στο φόντο
	_cr(Vector2(0, 0), Vector2(W, H), Color(0.03, 0.0, 0.06, 0.18))

func _apply_boss_visuals() -> void:
	var d := _def()
	if ResourceLoader.exists(str(d["bg"])):
		_bg.texture = load(str(d["bg"]))
	var theme_col: Color = d["theme"]
	_hud_name.text = _title()
	(_hud_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color = theme_col
	_hud_hp.color = Color(theme_col.r, theme_col.g, theme_col.b, 0.9)
	_back_btn.text = "◄   Πίσω" if str(d["kind"]) == "morgana" else "◄   Πίσω στο Δάσος"
	_rebuild_sparkles(theme_col, float(d["ground_y"]))

func _rebuild_sparkles(col: Color, ground: float) -> void:
	for c in _spark_root.get_children():
		c.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for _i in range(22):
		var sz := 3.0 + rng.randf() * 5.0
		var sp := ColorRect.new()
		sp.position = Vector2(rng.randf_range(0, W), rng.randf_range(200, ground))
		sp.size     = Vector2(sz, sz)
		sp.color    = Color(col.r, col.g, col.b, 0.0)
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_spark_root.add_child(sp)
		var tw := sp.create_tween()
		tw.set_loops()
		tw.tween_property(sp, "color:a", 0.0,  rng.randf_range(0.8, 2.2)).set_delay(rng.randf() * 3.0)
		tw.tween_property(sp, "color:a", 0.70, 0.2)
		tw.tween_property(sp, "color:a", 0.0,  0.5)

# ═══════════════════════════════════════════════════════════════════════════
# HUD (banner ονόματος + διακοσμητική μπάρα HP + κουμπί Πίσω)
# ═══════════════════════════════════════════════════════════════════════════
func _build_hud() -> void:
	_hud_panel = Panel.new()
	_hud_panel.position = Vector2(140, HUD_TOP)
	_hud_panel.size     = Vector2(800, 70)
	_hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.10, 0.06, 0.14, 0.85)
	ps.border_color = C_MAGIC
	ps.set_border_width_all(3)
	ps.set_corner_radius_all(10)
	_hud_panel.add_theme_stylebox_override("panel", ps)
	add_child(_hud_panel)

	_hud_name = Label.new()
	_hud_name.position = Vector2(140, HUD_TOP)
	_hud_name.size     = Vector2(800, 70)
	_hud_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_name.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_hud_name.add_theme_font_size_override("font_size", 34)
	_hud_name.add_theme_color_override("font_color", C_GOLD)
	_hud_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_hud_name.add_theme_constant_override("shadow_offset_x", 1)
	_hud_name.add_theme_constant_override("shadow_offset_y", 2)
	_hud_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_name)

	# Διακοσμητική μπάρα HP (cosmetic προς το παρόν — γεμάτη)
	_cr(Vector2(140, HUD_TOP + 80), Vector2(800, 22), Color(0.05, 0.02, 0.06, 0.9))
	_hud_hp = ColorRect.new()
	_hud_hp.position = Vector2(143, HUD_TOP + 83)
	_hud_hp.size     = Vector2(794, 16)
	_hud_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_hp)
	_cr(Vector2(143, HUD_TOP + 83), Vector2(794, 5),  Color(1, 1, 1, 0.18))

	# Κουμπί Πίσω (κεντραρισμένο) — η μάχη είναι το ΤΕΛΕΥΤΑΙΟ βήμα, οπότε δεν
	# υπάρχει κουμπί «Επίθεση» εδώ (η ζαριά/odds προηγήθηκε στο popup).
	_back_btn = Button.new()
	_back_btn.text     = "◄   Πίσω"
	_back_btn.position = Vector2(W / 2.0 - 180, H - 150)
	_back_btn.size     = Vector2(360, 84)
	_back_btn.add_theme_font_size_override("font_size", 30)
	_style_back_btn(_back_btn)
	add_child(_back_btn)
	_back_btn.pressed.connect(close_popup)

# ═══════════════════════════════════════════════════════════════════════════
# ΒΟΗΘΗΤΙΚΑ
# ═══════════════════════════════════════════════════════════════════════════

## Μαλακή ακτινική λάμψη (impact flash).
func _radial_glow() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors  = PackedColorArray([
		Color(1.0, 0.90, 1.0, 1.0),
		Color(0.62, 0.24, 0.95, 0.85),
		Color(0.35, 0.08, 0.60, 0.0),
	])
	var gt := GradientTexture2D.new()
	gt.gradient  = g
	gt.fill      = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to   = Vector2(1.0, 0.5)
	gt.width  = 96
	gt.height = 96
	return gt

func _cr(pos: Vector2, sz: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.position = pos; r.size = sz; r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)

func _style_back_btn(btn: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = C_WOOD_D; n.border_color = C_GOLD.darkened(0.15)
	n.set_border_width_all(4); n.set_corner_radius_all(10)
	n.shadow_color = Color(0, 0, 0, 0.68); n.shadow_size = 7
	btn.add_theme_stylebox_override("normal", n)

	var h := StyleBoxFlat.new()
	h.bg_color = C_WOOD; h.border_color = C_GOLD
	h.set_border_width_all(5); h.set_corner_radius_all(10)
	h.shadow_color = C_GOLD.lightened(0.10); h.shadow_size = 16
	btn.add_theme_stylebox_override("hover", h)

	var pr := StyleBoxFlat.new()
	pr.bg_color = Color(0.055, 0.028, 0.008); pr.border_color = C_GOLD.darkened(0.25)
	pr.set_border_width_all(3); pr.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("pressed", pr)
	btn.add_theme_stylebox_override("focus", StyleBoxFlat.new())

	btn.add_theme_color_override("font_color",         C_GOLD)
	btn.add_theme_color_override("font_hover_color",   C_GOLD_S)
	btn.add_theme_color_override("font_pressed_color", C_GOLD.darkened(0.30))
	btn.add_theme_color_override("font_shadow_color",  Color(0, 0, 0, 0.92))
	btn.add_theme_constant_override("shadow_offset_x", 2)
	btn.add_theme_constant_override("shadow_offset_y", 3)

# ═══════════════════════════════════════════════════════════════════════════
# OVERLAY ΑΠΟΤΕΛΕΣΜΑΤΟΣ (ΝΙΚΗ/ΗΤΤΑ μετά το τέλος της μάχης)
# ═══════════════════════════════════════════════════════════════════════════
## Σκοτεινό full-screen overlay με πάνελ αποτελέσματος + κουμπί επιστροφής.
## MOUSE_FILTER_STOP ώστε να μπλοκάρει το από κάτω HUD. Το κείμενο διαφέρει
## ανά boss: Μόργκανα = ξεκλείδωμα περιοχής/κόστος επανάληψης 200· mini =
## ατάκα + ανταμοιβές (Χαλκός, κλειδί του goblin) / κόστος επανάληψης 100.
func _show_result(won: bool) -> void:
	var d := _def()
	var is_morgana := str(d["kind"]) == "morgana"
	var md: Dictionary = MiniBossScript.BOSS_DEFS.get(_boss_id, {})

	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_result_overlay = overlay

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.0, 0.05, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	const PW := 720.0
	const PH := 620.0
	var pxr: float = (W - PW) / 2.0
	var pyr: float = (H - PH) / 2.0 - 60.0

	var panel := Panel.new()
	panel.position = Vector2(pxr, pyr)
	panel.size     = Vector2(PW, PH)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := StyleBoxFlat.new()
	ps.bg_color     = Color(0.06, 0.18, 0.08, 0.92) if won else Color(0.18, 0.04, 0.04, 0.92)
	ps.border_color = C_GOLD if won else C_CRIMSON
	ps.set_border_width_all(4)
	ps.set_corner_radius_all(16)
	ps.shadow_color = Color(0, 0, 0, 0.60); ps.shadow_size = 18
	panel.add_theme_stylebox_override("panel", ps)
	overlay.add_child(panel)

	var icon := Label.new()
	icon.text = "🏆" if won else "💀"
	icon.position = Vector2(pxr, pyr + 50)
	icon.size     = Vector2(PW, 150)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 110)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(icon)

	var title := Label.new()
	title.text = "ΝΙΚΗ!" if won else "ΗΤΤΑ..."
	title.position = Vector2(pxr, pyr + 220)
	title.size     = Vector2(PW, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", C_GOLD if won else Color(0.85, 0.35, 0.35))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(title)

	var sub := Label.new()
	if is_morgana:
		sub.text = ("Νίκησες τη Μόργκανα!\nΞεκλειδώθηκε η επόμενη περιοχή." if won
			else "Η Μόργκανα ήταν πολύ δυνατή...\nΔυνάμωσε την ομάδα σου για μεγαλύτερο\nμέσο όρο και ξαναδοκίμασε!\n(η νέα προσπάθεια κοστίζει %d %s)" % [
				BossPopupScript.RETRY_COST, BossPopupScript.RETRY_CURRENCY])
	else:
		sub.text = str(md.get("taunt_win", "") if won else md.get("taunt_lose", ""))
		if not won:
			sub.text += "\n(η νέα προσπάθεια κοστίζει %d %s)" % [
				MiniBossScript.RETRY_COST, MiniBossScript.RETRY_CURRENCY]
	sub.position = Vector2(pxr + 40, pyr + 310)
	sub.size     = Vector2(PW - 80, 150)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", C_PARCH_D)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(sub)

	# Γραμμές ανταμοιβής (μόνο mini + νίκη): +Χαλκός και, αν υπάρχει (goblin),
	# +1 κλειδί + η πανοπλία-τρόπαιο — οι ποσότητες ήρθαν από το
	# MiniBossScript.BOSS_DEFS και έχουν ΗΔΗ πιστωθεί στο _conclude_fight.
	if not is_morgana and won:
		var reward_line := "+%d %s  %s" % [int(md.get("reward", 0)),
			MiniBossScript.REWARD_CURRENCY, Currency.ICONS.get(MiniBossScript.REWARD_CURRENCY, "")]
		var key_reward: Dictionary = md.get("key_reward", {})
		if not key_reward.is_empty():
			reward_line += "\n+1 %s  %s" % [str(key_reward["category"]),
				Currency.ICONS.get(str(key_reward["category"]), "🔑")]
		var armor_reward := str(md.get("armor_reward", ""))
		if armor_reward != "":
			reward_line += "\n+%s  🛡" % ArmorInventory.get_item_name(armor_reward)
		var rl := Label.new()
		rl.text = reward_line
		# Πάνω από το κουμπί (pyr+PH-110) — μέχρι 3 γραμμές πλέον (Χαλκός +
		# κλειδί + πανοπλία, βλ. goblin), οπότε μικρότερη γραμματοσειρά/πιο
		# ψηλά από πριν (2 γραμμές max) ώστε να μη μπλέκεται με το κουμπί.
		rl.position = Vector2(pxr, pyr + 385)
		rl.size     = Vector2(PW, 130)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.add_theme_font_size_override("font_size", 28)
		rl.add_theme_color_override("font_color", C_OK)
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(rl)

	var btn := Button.new()
	btn.text     = "◄   Πίσω στο Χωριό" if is_morgana else "◄   Πίσω στο Δάσος"
	btn.position = Vector2(pxr + PW / 2.0 - 180, pyr + PH - 110)
	btn.size     = Vector2(360, 84)
	btn.add_theme_font_size_override("font_size", 30)
	_style_back_btn(btn)
	overlay.add_child(btn)
	btn.pressed.connect(close_popup)

	overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(dim, "color:a", 0.72, 0.4)
