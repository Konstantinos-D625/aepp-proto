extends Control

# ═══════════════════════════════════════════════════════════════════════════
# BossFight — η ΠΡΑΓΜΑΤΙΚΗ (animated) μάχη με τη Μόργκανα τη Μάγισσα.
# ═══════════════════════════════════════════════════════════════════════════
# Το ΠΑΛΙΟ boss_popup.gd είναι μια στατική οθόνη «ζαριάς» (odds + roll). Αυτό
# εδώ είναι το ΝΕΟ, ζωντανό encounter: η μάγισσα (αριστερά, στραμμένη δεξιά προς
# τον παίκτη) επιτίθεται με μωβ πύρινες μπάλες, κατάρες και μαγική ασπίδα.
#
# ── ΠΟΤΕ ΑΝΟΙΓΕΙ ─────────────────────────────────────────────────────────────
# Είναι το ΤΕΛΕΥΤΑΙΟ βήμα της ακολουθίας: σπίτι μάγισσας -> BossPopup (εισαγωγικός
# διάλογος -> κλικ -> πιθανότητα νίκης + κουμπί «Επίθεση») -> ΕΔΩ. Το BossPopup
# καλεί show_popup(probability, stats) περνώντας την πιθανότητα νίκης.
#
# ── ΤΙ ΚΑΝΕΙ ΤΩΡΑ (πρώτη φάση) ───────────────────────────────────────────────
#   1. IDLE    : ΣΤΑΤΙΚΗ εικόνα witch.png (ακίνητη, κοιτάει μπροστά· χωρίς
#      πόρτα/exit, χωρίς animated idle).
#   2. CASTING  : ΤΥΧΑΙΟΣ, αργός κύκλος επιθέσεων (fireball/curse/shield με
#      σταθμισμένη τυχαία επιλογή) και τυχαίες idle παύσεις ανάμεσά τους.
#      Σε κάθε επίθεση, στο «καίριο» frame, γεννιέται το εφέ (projectile/AoE)
#      που ταξιδεύει προς τον παίκτη. Ο ΠΑΙΚΤΗΣ ΜΕΝΕΙ IDLE (καμία αντίδραση/
#      επίθεση ακόμη) — αυτό είναι σκόπιμο για αυτή τη φάση.
#   3. FINISHED : μετά από FIGHT_DURATION δευτερόλεπτα (≈2-3 επιθέσεις) η μάχη
#      ΟΛΟΚΛΗΡΩΝΕΤΑΙ: γίνεται το roll νίκης/ήττας με βάση την πιθανότητα που
#      ήρθε από το BossPopup, καταγράφεται στο GameData (record_boss_win/loss —
#      το loss-gate) και εμφανίζεται overlay αποτελέσματος (ΝΙΚΗ/ΗΤΤΑ).
#
# ── ΤΙ ΘΑ ΕΡΘΕΙ (επόμενες φάσεις, ΟΧΙ εδώ) ────────────────────────────────────
#   - Επιθέσεις παίκτη (animation), HP/damage, ασπίδα που ενεργοποιείται ΟΤΑΝ ο
#     παίκτης χτυπάει (γι' αυτό το shield είναι ήδη στη rotation ως placeholder),
#     και το αποτέλεσμα να δένει με το HP αντί για σκέτο χρονόμετρο 5s. Προς το
#     παρόν ο παίκτης μένει IDLE μέχρι να φτιαχτεί το animation του.
#
# ── ΤΕΧΝΙΚΑ ─────────────────────────────────────────────────────────────────
# Τα spritesheets (Εικόνες/idle_stance|fireball|curse_spell|shield .png) είναι
# οριζόντιες λωρίδες με 1 σειρά. Το SpriteFrames χτίζεται
# ΣΕ ΚΩΔΙΚΑ με AtlasTexture ανά frame (ίδιο «όλα σε κώδικα» ύφος με τα
# υπόλοιπα scripts του project) — τα όρια των frames υπολογίζονται με
# round(i*W/n) ώστε να καλύπτουν ακέραια ακόμη κι όταν το πλάτος δεν διαιρείται
# τέλεια (π.χ. idle 1003/4). Κάθε animation έχει διαφορετικό ύψος κελιού· για
# να μη «χοροπηδάει» η μάγισσα στις μεταβάσεις, κάθε φορά που αλλάζει animation
# υπολογίζεται scale ώστε το κελί να εμφανίζεται πάντα TARGET_H ψηλό και
# αγκυρώνεται κάτω-κέντρο (τα πόδια «μένουν» στο GROUND_Y).

# ── Spritesheets (path, πλήθος frames, fps, loop) ───────────────────────────
# "idle" = ΣΤΑΤΙΚΗ εικόνα (witch.png, η μάγισσα ακίνητη) ως 1-frame animation —
# αντικατέστησε το παλιό animated idle_stance. Το exit_house (πόρτα) έχει επίσης
# αφαιρεθεί: μπαίνει κατευθείαν στο idle. Στο idle κοιτάει ΜΠΡΟΣΤΑ (unflipped)·
# μόνο στις επιθέσεις γίνεται flip ώστε να ΚΟΙΤΑΕΙ τον παίκτη (βλ. _play_anim).
const SHEETS := {
	"idle":        {"path": "res://Εικόνες/witch.png",      "frames": 1, "fps": 1.0, "loop": true},
	"fireball":    {"path": "res://Εικόνες/fireball.png",    "frames": 6, "fps": 8.0, "loop": false},
	"curse_spell": {"path": "res://Εικόνες/curse_spell.png", "frames": 6, "fps": 7.0, "loop": false},
	"shield":      {"path": "res://Εικόνες/shield.png",      "frames": 5, "fps": 6.0, "loop": false},
}
const PLAYER_PATH := "res://Εικόνες/avatar.png"
const BG_PATH     := "res://Εικόνες/boss_bg.png"

# «Καίρια» frames όπου φεύγει το εφέ προς τον παίκτη (0-indexed).
const FIREBALL_THROW_FRAME := 3
const CURSE_STRIKE_FRAME   := 3

# ── Ρυθμός επιθέσεων ─────────────────────────────────────────────────────────
# Αργός & ΤΥΧΑΙΟΣ: ανάμεσα στις επιθέσεις η μάγισσα μένει idle για τυχαίο
# διάστημα, με περιστασιακές μεγαλύτερες «ανάπαυλες». Η επόμενη επίθεση
# επιλέγεται τυχαία (σταθμισμένα), όχι με σταθερή σειρά.
const IDLE_GAP_MIN     := 0.7    # συνηθισμένη παύση (δευτ.) — γρήγορος ρυθμός επιθέσεων
const IDLE_GAP_MAX     := 1.8
const LONG_PAUSE_CHANCE := 0.15  # πιθανότητα για μεγαλύτερη ανάπαυλα
const LONG_PAUSE_MIN   := 2.5
const LONG_PAUSE_MAX   := 3.8

# ── Διάρκεια μάχης ───────────────────────────────────────────────────────────
# «Για αρχή»: η μάχη ολοκληρώνεται μετά από τόσα δευτερόλεπτα (≈2-3 επιθέσεις
# με τον παραπάνω ρυθμό), οπότε κρίνεται νίκη/ήττα. Αργότερα θα αντικατασταθεί
# από σύστημα HP/damage.
const FIGHT_DURATION := 5.0

# ── Layout (σχεδιασμός 1080×1920 portrait, ίδιο με project) ──────────────────
const W := 1080.0
const H := 1920.0
# Οι δύο στέκονται ΠΑΝΩ ΣΤΟΝ ΔΡΟΜΟ του boss_bg.png (768×1376, COVERED → ο
# δρόμος πέφτει ~ y=985 στην οθόνη). Η μάγισσα ΑΡΙΣΤΕΡΑ (flipped ώστε να
# κοιτάει/ρίχνει προς τα ΔΕΞΙΑ, στον παίκτη), ο παίκτης ΔΕΞΙΑ — μακριά ο ένας
# από τον άλλο.
const GROUND_Y     := 1010.0   # y όπου «πατάνε» τα πόδια — πάνω στον δρόμο
const WITCH_X      := 255.0    # οριζόντιο κέντρο μάγισσας (αριστερή μεριά δρόμου)
const WITCH_CELL_H := 470.0    # εμφανιζόμενο ύψος κελιού επιθέσεων (λίγο μικρότερη)
const WITCH_IDLE_H := 485.0    # ύψος στατικής idle (witch.png) — tuned ώστε το σώμα
                               # να ταιριάζει με τις επιθέσεις (witch.png έχει άλλο framing)
const WITCH_FLIP   := false    # τα attack sheets είναι ΗΔΗ στραμμένα δεξιά (staff στα
                               # δεξιά) → ΚΑΝΕΝΑ mirror· έτσι κοιτάει τον παίκτη (δεξιά)
                               # και ταιριάζει με το idle (witch.png, staff δεξιά)
const PLAYER_X     := 830.0    # παίκτης (δεξιά μεριά δρόμου) — μακριά από τη μάγισσα
const PLAYER_H     := 330.0    # εμφανιζόμενο ύψος παίκτη
# Πάνω άκρη του HUD (banner ονόματος + μπάρα HP). Χαμηλωμένο ώστε να ΜΗΝ
# καλύπτει το κάστρο που φαίνεται στο πάνω-κέντρο του boss_bg.png.
const HUD_TOP      := 178.0

# ── Παλέτα (ξύλο/χρυσό/μαγικό — ίδια γραμμή με boss_popup.gd) ────────────────
const C_WOOD    := Color(0.200, 0.120, 0.052)
const C_WOOD_D  := Color(0.130, 0.075, 0.028)
const C_GOLD    := Color(0.940, 0.760, 0.160)
const C_GOLD_S  := Color(1.000, 0.920, 0.560)
const C_MAGIC   := Color(0.520, 0.180, 0.880)
const C_PARCH_D := Color(0.720, 0.680, 0.760)

enum State { HIDDEN, ENTERING, IDLE, CASTING, FINISHED }

var _state: int = State.HIDDEN
var _last_attack := ""               # για αποφυγή διπλής ίδιας επίθεσης στη σειρά
var _fx_fired := false               # έχει ήδη «φύγει» το εφέ της τρέχουσας επίθεσης;

# ── Αποτέλεσμα μάχης (έρχονται από το BossPopup) ─────────────────────────────
var _win_prob: float = 1.0           # πιθανότητα νίκης (0-1) — για το roll στο τέλος
var _loss_stats: Dictionary = {}     # stats της στιγμής — για το GameData.record_boss_loss
var _fight_id := 0                   # «γενιά» μάχης: ακυρώνει stale timers σε reopen
var _result_overlay: Control         # overlay αποτελέσματος (καθαρίζεται σε reopen/close)

var _witch: AnimatedSprite2D
var _player: Sprite2D
var _cell_h := {}                    # anim_name -> ύψος κελιού (px στο sheet)
var _cell_w := {}                    # anim_name -> πλάτος κελιού (px στο sheet)
var _foot_y := {}                    # anim_name -> γραμμή ποδιών (px, cell space)

var _glow_tex: GradientTexture2D     # μαλακή μωβ λάμψη (orb / burst / trail)
var _ring_tex: GradientTexture2D     # μωβ δαχτυλίδι (μαγικός κύκλος AoE)

# ═══════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_glow_tex = _radial_glow()
	_ring_tex = _radial_ring()
	_build_background()
	_build_player()
	_build_witch()
	_build_hud()

## Καλείται από το boss_popup.gd (κουμπί «Επίθεση» της οθόνης πιθανότητας νίκης).
## Δέχεται την πιθανότητα νίκης + τα stats της στιγμής, μπαίνει ΚΑΤΕΥΘΕΙΑΝ με το
## idle, ξεκινάει τον κύκλο επιθέσεων ΚΑΙ το χρονόμετρο ολοκλήρωσης (FIGHT_DURATION).
func show_popup(probability: float = 1.0, loss_stats: Dictionary = {}) -> void:
	visible = true
	_win_prob   = clampf(probability, 0.0, 1.0)
	_loss_stats = loss_stats.duplicate()
	_last_attack = ""
	_fx_fired = false
	# Καθάρισε τυχόν overlay αποτελέσματος από προηγούμενη μάχη
	if is_instance_valid(_result_overlay):
		_result_overlay.queue_free()
		_result_overlay = null
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.45)
	_enter_idle()
	_start_fight_timer()

func close_popup() -> void:
	_state = State.HIDDEN   # ακυρώνει τυχόν προγραμματισμένη επόμενη επίθεση
	_fight_id += 1          # ακυρώνει τυχόν εκκρεμές χρονόμετρο ολοκλήρωσης
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.30)
	tw.tween_callback(func(): visible = false)

## Χρονόμετρο ολοκλήρωσης: μετά από FIGHT_DURATION κρίνεται το αποτέλεσμα. Το
## _fight_id εξασφαλίζει ότι ένα stale timer (π.χ. Πίσω + ξανά-άνοιγμα μέσα στα
## 5s) δεν θα ολοκληρώσει πρόωρα τη ΝΕΑ μάχη.
func _start_fight_timer() -> void:
	_fight_id += 1
	var id := _fight_id
	var t := get_tree().create_timer(FIGHT_DURATION)
	t.timeout.connect(func():
		if id == _fight_id and visible and _state != State.FINISHED:
			_conclude_fight())

## Τέλος μάχης: σταματά τον κύκλο επιθέσεων, κάνει το roll με βάση την πιθανότητα,
## καταγράφει στο GameData (win καθαρίζει το loss-gate, loss αποθηκεύει τα stats)
## και δείχνει το overlay αποτελέσματος.
func _conclude_fight() -> void:
	_state = State.FINISHED
	var won: bool = randf() < _win_prob
	if won:
		GameData.record_boss_win()
	else:
		GameData.record_boss_loss(_loss_stats)
	_show_result(won)

# ═══════════════════════════════════════════════════════════════════════════
# STATE MACHINE
# ═══════════════════════════════════════════════════════════════════════════
func _enter_idle() -> void:
	_state = State.IDLE
	_play_anim("idle")
	_schedule_next_attack()

## Τυχαία παύση (με περιστασιακή μεγαλύτερη ανάπαυλα) — η μάγισσα μένει idle
## όσο τρέχει ο χρόνος, μετά επιτίθεται.
func _schedule_next_attack() -> void:
	var gap: float
	if randf() < LONG_PAUSE_CHANCE:
		gap = randf_range(LONG_PAUSE_MIN, LONG_PAUSE_MAX)
	else:
		gap = randf_range(IDLE_GAP_MIN, IDLE_GAP_MAX)
	var t := get_tree().create_timer(gap)
	t.timeout.connect(func():
		if _state == State.IDLE and visible:
			_do_attack())

func _do_attack() -> void:
	_state = State.CASTING
	_fx_fired = false
	_play_anim(_pick_attack())

## Σταθμισμένη τυχαία επιλογή επόμενης επίθεσης — fireball συχνότερα, shield
## σπανιότερα (placeholder αμυντικής μέχρι να μπορεί ο παίκτης να επιτεθεί).
## Ένα reroll για να αποφεύγεται η ίδια επίθεση δύο φορές στη σειρά.
func _pick_attack() -> String:
	var atk := _weighted_attack()
	if atk == _last_attack:
		atk = _weighted_attack()
	_last_attack = atk
	return atk

func _weighted_attack() -> String:
	var r := randf()
	if r < 0.45:
		return "fireball"
	elif r < 0.80:
		return "curse_spell"
	return "shield"

func _on_witch_anim_finished() -> void:
	match _witch.animation:
		"fireball", "curse_spell", "shield":
			if _state == State.CASTING:
				_enter_idle()

## Γεννάει το εφέ ΑΚΡΙΒΩΣ στο καίριο frame της επίθεσης (μία φορά).
func _on_witch_frame_changed() -> void:
	if _fx_fired:
		return
	if _witch.animation == "fireball" and _witch.frame == FIREBALL_THROW_FRAME:
		_fx_fired = true
		_cast_fireball()
	elif _witch.animation == "curse_spell" and _witch.frame == CURSE_STRIKE_FRAME:
		_fx_fired = true
		_cast_curse()

# ═══════════════════════════════════════════════════════════════════════════
# ΕΦΕ ΕΠΙΘΕΣΕΩΝ (χτισμένα σε κώδικα — μωβ μαγεία, ίδιο ύφος με τα sparkles
# του boss_popup.gd· δεν υπάρχει ξεχωριστό projectile spritesheet ακόμη)
# ═══════════════════════════════════════════════════════════════════════════

## Μωβ πύρινη μπάλα: γεννιέται στο ελεύθερο χέρι της μάγισσας και ταξιδεύει
## προς τον παίκτη αφήνοντας ουρά από σωματίδια, με λάμψη πρόσκρουσης στο τέλος.
func _cast_fireball() -> void:
	# Unflipped: το ελεύθερο χέρι (orb) είναι στην ΑΡΙΣΤΕΡΗ της πλευρά· η μπάλα
	# ταξιδεύει προς τον παίκτη (δεξιά). Στόχος το στήθος του παίκτη.
	var origin := Vector2(WITCH_X - 85.0, GROUND_Y - 250.0)
	var target := Vector2(PLAYER_X - 8.0, GROUND_Y - 185.0)

	var orb := Sprite2D.new()
	orb.texture  = _glow_tex
	orb.position = origin
	orb.scale    = Vector2(0.5, 0.5)
	add_child(orb)

	# Ουρά σωματιδίων (local_coords=false ώστε να «μένουν» πίσω καθώς κινείται)
	var trail := CPUParticles2D.new()
	trail.texture   = _glow_tex
	trail.amount    = 22
	trail.lifetime  = 0.42
	trail.local_coords = false
	trail.spread    = 18.0
	trail.gravity   = Vector2.ZERO
	trail.initial_velocity_min = 8.0
	trail.initial_velocity_max = 26.0
	trail.scale_amount_min = 0.07
	trail.scale_amount_max = 0.14
	trail.color = Color(0.62, 0.24, 0.98, 0.85)
	orb.add_child(trail)

	var tw := create_tween()
	tw.tween_property(orb, "position", target, 0.5).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(orb, "scale", Vector2(0.82, 0.82), 0.5)
	tw.tween_callback(func():
		trail.emitting = false
		_impact_flash(target)
		# αφήνει την ουρά να σβήσει πριν ελευθερωθεί ο orb
		var t := get_tree().create_timer(0.45)
		t.timeout.connect(orb.queue_free))

## Κατάρα AoE: μωβ μαγικός κύκλος που «ανοίγει» στα πόδια του παίκτη + έκρηξη
## λάμψης προς τα πάνω + σύντομο flash οθόνης.
func _cast_curse() -> void:
	var feet := Vector2(PLAYER_X - 8.0, GROUND_Y - 8.0)

	# Διαστελλόμενος δαχτύλιος (squash σε y για προοπτική εδάφους)
	var ring := Sprite2D.new()
	ring.texture  = _ring_tex
	ring.position = feet
	ring.scale    = Vector2(0.15, 0.07)
	ring.modulate = Color(0.72, 0.34, 1.0, 0.95)
	add_child(ring)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector2(2.0, 0.9), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.55)
	tw.tween_callback(ring.queue_free)

	# Έκρηξη λάμψης που ανεβαίνει
	var burst := Sprite2D.new()
	burst.texture  = _glow_tex
	burst.position = feet - Vector2(0.0, 90.0)
	burst.scale    = Vector2(0.3, 0.55)
	burst.modulate = Color(0.85, 0.5, 1.0, 0.95)
	add_child(burst)
	var tw2 := create_tween()
	tw2.tween_property(burst, "scale", Vector2(1.4, 1.9), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.parallel().tween_property(burst, "modulate:a", 0.0, 0.5)
	tw2.tween_callback(burst.queue_free)

	_screen_flash(Color(0.45, 0.12, 0.75), 0.28, 0.45)

## Σύντομη λάμψη πρόσκρουσης της πύρινης μπάλας πάνω στον παίκτη.
func _impact_flash(pos: Vector2) -> void:
	var flash := Sprite2D.new()
	flash.texture  = _glow_tex
	flash.position = pos
	flash.scale    = Vector2(0.35, 0.35)
	flash.modulate = Color(1.0, 0.85, 1.0, 1.0)
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "scale", Vector2(1.15, 1.15), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(flash, "modulate:a", 0.0, 0.28)
	tw.tween_callback(flash.queue_free)

## Full-screen μωβ flash (κατάρα) — Control ColorRect, σβήνει μόνο του.
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
# ΚΑΤΑΣΚΕΥΗ ΜΑΓΙΣΣΑΣ (AnimatedSprite2D + SpriteFrames σε κώδικα)
# ═══════════════════════════════════════════════════════════════════════════
func _build_witch() -> void:
	_witch = AnimatedSprite2D.new()
	# centered=true → το position είναι το ΚΕΝΤΡΟ· έτσι το flip_h καθρεφτίζει
	# γύρω από το κέντρο χωρίς μετατόπιση. Το flip ορίζεται ΑΝΑ animation στο
	# _play_anim (idle: μπροστά· επιθέσεις: κοιτάει τον παίκτη).
	_witch.centered = true
	_witch.sprite_frames = _build_frames()
	add_child(_witch)
	_witch.animation_finished.connect(_on_witch_anim_finished)
	_witch.frame_changed.connect(_on_witch_frame_changed)

func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for anim_name in SHEETS:
		var info: Dictionary = SHEETS[anim_name]
		var tex: Texture2D = load(info["path"])
		if tex == null:
			# Χωρίς import (πρώτο άνοιγμα editor) το load αποτυγχάνει — προειδοποίηση
			# αντί για crash. Άνοιξε μία φορά τον Godot editor για να γίνει import.
			push_warning("BossFight: αδυναμία φόρτωσης %s — άνοιξε τον editor για import." % info["path"])
			continue
		var n: int = int(info["frames"])
		var full_w: int = tex.get_width()
		var h: int = tex.get_height()
		sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, bool(info["loop"]))
		sf.set_animation_speed(anim_name, float(info["fps"]))
		var cell0_x1: int = int(round(1.0 * full_w / n))
		for i in n:
			# round(i*W/n) → ακέραια, χωρίς κενά ακόμη κι όταν W δεν διαιρείται τέλεια
			var x0: int = int(round(float(i)     * full_w / n))
			var x1: int = int(round(float(i + 1) * full_w / n))
			var at := AtlasTexture.new()
			at.atlas  = tex
			at.region = Rect2(x0, 0, x1 - x0, h)
			sf.add_frame(anim_name, at)
		_cell_h[anim_name] = float(h)
		_cell_w[anim_name] = float(full_w) / float(n)
		# Γραμμή ποδιών από το 1ο κελί (alpha scan) → αγκύρωση στα πόδια, ώστε
		# idle (witch.png) και επιθέσεις να πατάνε ΑΚΡΙΒΩΣ στο ίδιο GROUND_Y.
		_foot_y[anim_name] = _detect_foot(tex, cell0_x1, h)
	return sf

## Βρίσκει τη χαμηλότερη «στέρεη» γραμμή (μπότες/σώμα) στο 1ο κελί, αγνοώντας
## τις αραιές μωβ καπνιές — ώστε να πατάει στα ΠΟΔΙΑ, όχι στην ουρά του καπνού.
func _detect_foot(tex: Texture2D, x1: int, h: int) -> float:
	var img: Image = tex.get_image()
	if img == null:
		return float(h)
	if img.is_compressed():
		img.decompress()
	for y in range(h - 1, -1, -1):
		var cnt := 0
		var x := 0
		while x < x1:
			if img.get_pixel(x, y).a > 0.7:
				cnt += 1
				if cnt >= 6:      # ≥6 έντονα αδιαφανή δείγματα = στέρεο σώμα, όχι καπνός
					return float(y + 1)
			x += 2
	return float(h)

## Αλλάζει animation ΚΑΙ διορθώνει scale/flip/position:
##   - μέγεθος: idle → WITCH_IDLE_H, επιθέσεις → WITCH_CELL_H (matched σώμα)
##   - flip: WITCH_FLIP (τώρα false — sheets ήδη δεξιά)· η μάγισσα κοιτάει τον
##     παίκτη (δεξιά) σε idle & επιθέσεις, staff πάντα δεξιά (χωρίς «πήδημα»)
##   - θέση: αγκύρωση στη ΓΡΑΜΜΗ ΠΟΔΙΩΝ (foot) στο (WITCH_X, GROUND_Y), ώστε να
##     μη «χοροπηδάει» ανάμεσα σε idle/επιθέσεις (centered=true → position=κέντρο).
func _play_anim(anim_name: String) -> void:
	if _witch.sprite_frames == null or not _witch.sprite_frames.has_animation(anim_name):
		return
	var ch: float = _cell_h.get(anim_name, 200.0)
	var target_h: float = WITCH_IDLE_H if anim_name == "idle" else WITCH_CELL_H
	var s: float = target_h / ch
	var foot: float = _foot_y.get(anim_name, ch)
	_witch.flip_h    = anim_name != "idle" and WITCH_FLIP
	_witch.scale     = Vector2(s, s)
	_witch.position  = Vector2(WITCH_X, GROUND_Y + ch * s / 2.0 - foot * s)
	_witch.animation = anim_name
	_witch.frame = 0
	_witch.play(anim_name)

# ═══════════════════════════════════════════════════════════════════════════
# ΠΑΙΚΤΗΣ (στατικός — idle με ελαφρύ «αναπνευστικό» bob)
# ═══════════════════════════════════════════════════════════════════════════
func _build_player() -> void:
	var tex: Texture2D = load(PLAYER_PATH)
	_player = Sprite2D.new()
	_player.centered = false
	if tex:
		_player.texture = tex
		var s: float = PLAYER_H / tex.get_height()
		_player.scale    = Vector2(s, s)
		_player.position = Vector2(PLAYER_X - tex.get_width() * s / 2.0, GROUND_Y - tex.get_height() * s)
	add_child(_player)
	# Ελαφρύ idle bob (μένει «idle» — απλώς όχι παγωμένος)
	var base_y := _player.position.y
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(_player, "position:y", base_y - 7.0, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_player, "position:y", base_y, 1.6).set_trans(Tween.TRANS_SINE)

# ═══════════════════════════════════════════════════════════════════════════
# ΦΟΝΤΟ — ζωγραφισμένος δρόμος στο δάσος με το κάστρο στο βάθος (boss_bg.png).
# COVERED + width-exact (768→1080), οπότε ο δρόμος κάθεται σταθερά ~ y=985 και
# οι φιγούρες πατάνε πάνω του (GROUND_Y).
# ═══════════════════════════════════════════════════════════════════════════
func _build_background() -> void:
	var tex: Texture2D = load(BG_PATH)
	var bg := TextureRect.new()
	if tex:
		bg.texture = tex
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Ελαφρύ σκοτείνιασμα ώστε να «κάθονται» καλύτερα οι φιγούρες πάνω στο φόντο
	_cr(Vector2(0, 0), Vector2(W, H), Color(0.03, 0.0, 0.06, 0.18))
	_sparkles()

func _sparkles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for _i in range(22):
		var sz := 3.0 + rng.randf() * 5.0
		var sp := ColorRect.new()
		sp.position = Vector2(rng.randf_range(0, W), rng.randf_range(200, GROUND_Y))
		sp.size     = Vector2(sz, sz)
		sp.color    = Color(C_MAGIC.r, C_MAGIC.g, C_MAGIC.b, 0.0)
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sp)
		var tw := create_tween()
		tw.set_loops()
		tw.tween_property(sp, "color:a", 0.0,  rng.randf_range(0.8, 2.2)).set_delay(rng.randf() * 3.0)
		tw.tween_property(sp, "color:a", 0.70, 0.2)
		tw.tween_property(sp, "color:a", 0.0,  0.5)

# ═══════════════════════════════════════════════════════════════════════════
# HUD (banner ονόματος + διακοσμητική μπάρα HP + κουμπί Πίσω)
# ═══════════════════════════════════════════════════════════════════════════
func _build_hud() -> void:
	# Banner ονόματος boss
	var panel := Panel.new()
	panel.position = Vector2(140, HUD_TOP)
	panel.size     = Vector2(800, 70)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.10, 0.06, 0.14, 0.85)
	ps.border_color = C_MAGIC
	ps.set_border_width_all(3)
	ps.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	var name_lbl := Label.new()
	name_lbl.text = "🔮  Μόργκανα η Μάγισσα"
	name_lbl.position = Vector2(140, HUD_TOP)
	name_lbl.size     = Vector2(800, 70)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 34)
	name_lbl.add_theme_color_override("font_color", C_GOLD)
	name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	name_lbl.add_theme_constant_override("shadow_offset_x", 1)
	name_lbl.add_theme_constant_override("shadow_offset_y", 2)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_lbl)

	# Διακοσμητική μπάρα HP (cosmetic προς το παρόν — γεμάτη)
	_cr(Vector2(140, HUD_TOP + 80), Vector2(800, 22), Color(0.05, 0.02, 0.06, 0.9))
	_cr(Vector2(143, HUD_TOP + 83), Vector2(794, 16), Color(C_MAGIC.r, C_MAGIC.g, C_MAGIC.b, 0.9))
	_cr(Vector2(143, HUD_TOP + 83), Vector2(794, 5),  Color(1, 1, 1, 0.18))

	# Κουμπί Πίσω (κεντραρισμένο) — η μάχη είναι πλέον το ΤΕΛΕΥΤΑΙΟ βήμα, οπότε
	# δεν υπάρχει κουμπί «Επίθεση» εδώ (η ζαριά/odds προηγήθηκε στο BossPopup).
	var back := Button.new()
	back.text     = "◄   Πίσω"
	back.position = Vector2(W / 2.0 - 180, H - 150)
	back.size     = Vector2(360, 84)
	back.add_theme_font_size_override("font_size", 30)
	_style_back_btn(back)
	add_child(back)
	back.pressed.connect(close_popup)

# ═══════════════════════════════════════════════════════════════════════════
# ΒΟΗΘΗΤΙΚΑ
# ═══════════════════════════════════════════════════════════════════════════

## Μαλακή ακτινική μωβ λάμψη (orb / burst / trail / impact).
func _radial_glow() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors  = PackedColorArray([
		Color(1.0, 0.90, 1.0, 1.0),
		Color(0.62, 0.24, 0.95, 0.85),
		Color(0.35, 0.08, 0.60, 0.0),
	])
	return _radial(96, g)

## Ακτινικό μωβ δαχτυλίδι (μαγικός κύκλος AoE).
func _radial_ring() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 0.72, 0.86, 1.0])
	g.colors  = PackedColorArray([
		Color(0.6, 0.2, 1.0, 0.0),
		Color(0.6, 0.2, 1.0, 0.0),
		Color(0.90, 0.55, 1.0, 0.95),
		Color(0.6, 0.2, 1.0, 0.5),
		Color(0.5, 0.1, 0.8, 0.0),
	])
	return _radial(160, g)

func _radial(px: int, grad: Gradient) -> GradientTexture2D:
	var gt := GradientTexture2D.new()
	gt.gradient  = grad
	gt.fill      = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to   = Vector2(1.0, 0.5)
	gt.width  = px
	gt.height = px
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
## MOUSE_FILTER_STOP ώστε να μπλοκάρει το από κάτω HUD (π.χ. το «Πίσω»). Το
## overlay φυλάσσεται στο _result_overlay για καθάρισμα σε reopen/close.
func _show_result(won: bool) -> void:
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
	const PH := 560.0
	var pxr: float = (W - PW) / 2.0
	var pyr: float = (H - PH) / 2.0 - 60.0

	var panel := Panel.new()
	panel.position = Vector2(pxr, pyr)
	panel.size     = Vector2(PW, PH)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := StyleBoxFlat.new()
	ps.bg_color     = Color(0.06, 0.18, 0.08, 0.92) if won else Color(0.18, 0.04, 0.04, 0.92)
	ps.border_color = C_GOLD if won else Color(0.580, 0.058, 0.058)
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
	sub.text = ("Νίκησες τη Μόργκανα!\nΞεκλειδώθηκε η επόμενη περιοχή." if won
		else "Η Μόργκανα ήταν πολύ δυνατή...\nΑνέβασε ΟΛΑ τα στατιστικά σου\n(τουλάχιστον +1 το καθένα) και ξαναδοκίμασε!")
	sub.position = Vector2(pxr + 40, pyr + 310)
	sub.size     = Vector2(PW - 80, 150)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", C_PARCH_D)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(sub)

	var btn := Button.new()
	btn.text     = "◄   Πίσω στο Χωριό"
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
