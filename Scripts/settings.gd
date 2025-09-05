extends Control
@onready var volume_display: Label = $MarginContainer/CenterContainer/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/Display #Holy moly
@onready var resolution_options: OptionButton = $MarginContainer/CenterContainer/VBoxContainer/HBoxContainer3/MarginContainer/ResolutionOptions
@onready var fullscreen_chkbox: CheckBox = $MarginContainer/CenterContainer/VBoxContainer/HBoxContainer2/MarginContainer/VBoxContainer/MarginContainer/Fullscreen
@onready var borderless_chkbox: CheckBox = $MarginContainer/CenterContainer/VBoxContainer/HBoxContainer2/MarginContainer3/CheckBox
@onready var volume_slider: HSlider = $MarginContainer/CenterContainer/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/VolumeSlider
@onready var voice_display: Label = $MarginContainer/CenterContainer/VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/Display
@onready var voiceline_slider: HSlider = $MarginContainer/CenterContainer/VBoxContainer/HBoxContainer/MarginContainer2/VBoxContainer/VoiceLineSlider

func _ready() -> void:
	#voiceline_slider.value = SettingsManager.voice_volume
	volume_slider.value = SettingsManager.volume
	volume_display.text = str(SettingsManager.volume)
	#voice_display.text = str(SettingsManager.voice_volume)
	var sfx_index = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(sfx_index, volume_remap(int(volume_display.text)))
	#sfx_index = AudioServer.get_bus_index("VoiceLines")
	#AudioServer.set_bus_volume_db(sfx_index, volume_remap(int(voice_display.text)))
	resolution_options.selected = SettingsManager.resolution_selected
	fullscreen_chkbox.button_pressed = SettingsManager.fullscreen
	borderless_chkbox.button_pressed = SettingsManager.borderless

var stored_border_switch: Array[bool] = [false, false]
var index_to_resolution = {
	0: Vector2(1920, 1080),
	1: Vector2(1280, 720),
	2: Vector2(854, 480),
	3: Vector2(640, 360)
}

func volume_remap(volume: float) -> float:
	var in_min = 0.0
	var in_max = 100.0
	var out_min = -80.0
	var out_max = 0.0
	return (volume - in_min) / (in_max - in_min) * (out_max - out_min) + out_min

func _on_volume_slider_value_changed(value: float) -> void:
	volume_display.text = str(int(value))

func _on_volume_slider_drag_ended(_value_changed: bool) -> void:
	var sfx_index = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(sfx_index, volume_remap(int(volume_display.text)))
	SettingsManager.volume = int(volume_display.text)

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		SettingsManager.fullscreen = true
		resolution_options.disabled = true
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		resolution_options.disabled = false
		SettingsManager.fullscreen = false
		#Windows bugs the fuck out otherwise
		get_window().set_size(index_to_resolution[resolution_options.selected]) #NOTE: Causes the window to move down slightly... Annoying
		get_window().position = Vector2(0, 0) #Should account for the note above (looks ugly at runtime tho)
		if stored_border_switch[0]:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, stored_border_switch[1])
			stored_border_switch = [false, false]

func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_check_box_toggled(toggled_on: bool) -> void:
	#Have to check if its in fullscreen to avoid the smaller window bug from occuring
	SettingsManager.borderless = toggled_on
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, toggled_on)
	else:
		stored_border_switch = [true, toggled_on]
		

func _on_option_button_item_selected(index: int) -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		get_window().set_size(index_to_resolution[index])
		SettingsManager.resolution_selected = index
		get_window().position = Vector2(0, 0) #Stop window from going off screen

func _on_voice_line_slider_value_changed(value: float) -> void:
	pass#voice_display.text = str(int(value))

func _on_voice_line_slider_drag_ended(_value_changed: bool) -> void:
	pass#var sfx_index = AudioServer.get_bus_index("VoiceLines")
	#AudioServer.set_bus_volume_db(sfx_index, volume_remap(int(voice_display.text)))
	#SettingsManager.voice_volume = int(voice_display.text)
