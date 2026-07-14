extends Control

# ═══════════════════════════════════════════════════════════════════════════
# Daily Streak — Εικονίδιο HUD
# ═══════════════════════════════════════════════════════════════════════════
# Καθαρά οπτικό στοιχείο δίπλα στο Side Quest (βλ. Scenes/Area1.tscn,
# HUD/DailyStreak) — δείχνει τον αριθμό streak πάνω στη βάση της φλόγας.
# Καμία δική του λογική streak εδώ· διαβάζει/ακούει το Autoload "GameData"
# (Scripts/GameData.gd), ίδιο μοτίβο με το daily_quest_popup.gd — αυτό το
# script απλά εμφανίζει την τιμή, δεν την υπολογίζει.

@onready var _count_label: Label = %CountLabel


func _ready() -> void:
	GameData.streak_changed.connect(_on_streak_changed)
	_refresh()


func _refresh() -> void:
	_count_label.text = str(GameData.get_streak())


func _on_streak_changed(new_streak: int) -> void:
	_count_label.text = str(new_streak)
