class_name Inbox
extends Node2D

@onready var back_button = $UI/BackButton
@onready var mail_panel = $UI/MailPanel
@onready var prev_button = $UI/MailPanel/HBoxContainer/ButtonPrev
@onready var next_button = $UI/MailPanel/HBoxContainer/ButtonNext

## DEFAULT FUNCTIONS
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

## CUSTOM FUNCTIONS

## SIGNALS
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"mail":
			# enable back button after cat's mail animation plays
			back_button.disabled = false
			back_button.visible = true
			
			
		_:
			pass


func _on_back_button_pressed() -> void:
	pass # Replace with function body.
	



func _on_button_prev_pressed() -> void:
	pass # Replace with function body.


func _on_button_next_pressed() -> void:
	pass # Replace with function body.
