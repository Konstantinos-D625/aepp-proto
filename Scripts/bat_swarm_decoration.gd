extends TextureRect

# Διακοσμητικό σμήνος νυχτερίδων πάνω από το σκοτεινό μονοπάτι του δάσους
# (bg1.png, κάτω-δεξιά γωνία, βλ. Area1.tscn "Houses/ForestPathButton" που
# κάθεται στο ίδιο σημείο) — καθαρά διακοσμητικό, καμία λειτουργία/κλικ.
#
# Το Godot δεν εισάγει κινούμενα GIF απευθείας (μόνο το πρώτο frame σαν
# στατική εικόνα) — τα 16 frames του πρωτότυπου Εικόνες/bats.gif έχουν ήδη
# εξαχθεί σε ξεχωριστά PNG (Εικόνες/bats_frames/bat_00..15.png) και
# συναρμολογούνται εδώ σε AnimatedTexture, με το ΙΔΙΟ timing (100ms/frame)
# με το πρωτότυπο GIF.
const FRAME_COUNT := 16
const FRAME_DURATION := 0.1
const FRAME_PATH := "res://Εικόνες/bats_frames/bat_%02d.png"

func _ready() -> void:
	var anim := AnimatedTexture.new()
	anim.frames = FRAME_COUNT
	for i in FRAME_COUNT:
		anim.set_frame_texture(i, load(FRAME_PATH % i))
		anim.set_frame_duration(i, FRAME_DURATION)
	texture = anim
