extends Node

var data_loaded: bool = false

func save_data(content: Dictionary) -> void:
	var file = FileAccess.open("user://SettingsManager.sav", FileAccess.WRITE)
	#### store_8 (8bit int aka bool)
	file.store_var(content["volume"])
	file.store_var(content["voice_volume"])

func load_from_file():
	if FileAccess.file_exists("user://SettingsManager.sav"):
		var file = FileAccess.open("user://SettingsManager.sav", FileAccess.READ)
		var content = [
			file.get_var(),
			file.get_var(),
		]
		return content
	else:
		return false

func save_game() -> void:
	var content = {
		"volume": volume,
		"voice_volume": voice_volume,
	}
	
	save_data(content)

func _ready() -> void:
	var content = load_from_file()
	
	if content:
		volume = content[0]
		voice_volume = content[1]
		
	data_loaded = true

var first_load: bool = true

var _resolution_selected: int = 1
var _volume: int = 100
var _fullscreen: bool = false
var _borderless: bool = false
var _voice_volume: int = 100

var resolution_selected: int = 1:
	set(value):
		_resolution_selected = value
		if data_loaded:
			save_game()
	get:
		return _resolution_selected

var volume: int = 100:
	set(value):
		_volume = value
		if data_loaded:
			save_game()
	get:
		return _volume

var fullscreen: bool = false:
	set(value):
		_fullscreen = value
		if data_loaded:
			save_game()
	get:
		return _fullscreen

var borderless: bool = false:
	set(value):
		_borderless = value
		if data_loaded:
			save_game()
	get:
		return _borderless

var voice_volume: int = 100:
	set(value):
		_voice_volume = value
		if data_loaded:
			save_game()
	get:
		return _voice_volume
