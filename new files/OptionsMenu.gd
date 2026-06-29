extends Panel

const SAVE_PATH := "user://audio_settings.cfg"

@onready var master_slider: HSlider = $Margin/VBox/MasterSlider
@onready var music_slider: HSlider = $Margin/VBox/MusicSlider
@onready var sfx_slider: HSlider = $Margin/VBox/SFXSlider

func _ready() -> void:
	_load_settings()

func _on_options_pressed() -> void:
	visible = true

func _on_master_slider_value_changed(value: float) -> void:
	_apply_bus_volume("Master", value)

func _on_music_slider_value_changed(value: float) -> void:
	_apply_bus_volume("Music", value)

func _on_sfx_slider_value_changed(value: float) -> void:
	_apply_bus_volume("SFX", value)

func _on_reset_pressed() -> void:
	master_slider.value = 1.0
	music_slider.value = 1.0
	sfx_slider.value = 1.0

func _on_back_pressed() -> void:
	_save_settings()
	visible = false

func _apply_bus_volume(bus_name: String, linear_val: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear_val))

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		master_slider.value = config.get_value("audio", "master", 1.0)
		music_slider.value = config.get_value("audio", "music", 1.0)
		sfx_slider.value = config.get_value("audio", "sfx", 1.0)
	_apply_bus_volume("Master", master_slider.value)
	_apply_bus_volume("Music", music_slider.value)
	_apply_bus_volume("SFX", sfx_slider.value)

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", master_slider.value)
	config.set_value("audio", "music", music_slider.value)
	config.set_value("audio", "sfx", sfx_slider.value)
	config.save(SAVE_PATH)
