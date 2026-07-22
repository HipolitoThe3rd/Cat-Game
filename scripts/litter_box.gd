extends Node2D


func _on_back_button_button_down() -> void:
	get_tree().change_scene_to_file("res://scenes/litter_room.tscn")
