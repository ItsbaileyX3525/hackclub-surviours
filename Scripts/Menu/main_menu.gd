extends Control

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Levels/Main.tscn")

func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Settings.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()
