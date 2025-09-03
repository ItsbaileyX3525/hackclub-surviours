extends Control

@onready var options: Control = $Options


func _on_start_pressed() -> void:
	pass#get_tree().change_scene_to_file()

func _on_options_pressed() -> void:
	options.visible = true
	pass # Replace with function body.

func _on_exit_pressed() -> void:
	get_tree().quit()
