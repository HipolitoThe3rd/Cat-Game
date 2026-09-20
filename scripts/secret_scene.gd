### Scene that is only accessible when
### Cat is at 95 mood or higher.
class_name SecretScene
extends Node2D

@onready var back_button = $UI/BackButton

## PREMADE FUNCTIONS
func _ready() -> void:
	back_button.visible = false
	back_button.disabled = true

## SIGNALS
func _on_sfx_secret_finished() -> void:
	back_button.visible = true
	back_button.disabled = false

func _on_back_button_button_down() -> void:
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
