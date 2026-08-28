class_name PlayroomDoor
extends Node2D

@onready var anim_play = $AnimationPlayer



## Signals
func _on_click_area_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	# Check if the event is a mouse button click
	if event is InputEventMouseButton:
		# Check if it was a Left Click and if it was just pressed (not released)
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("Playroom Door animation on click: ", anim_play.current_animation)
			if anim_play.current_animation == "closed":
				$SFX/SFXDoorOpen.play()
				anim_play.play("open")
			elif anim_play.current_animation == "open":
				$SFX/SFXDoorClose.play()
				anim_play.play("closed")
			
			# Mark the input as handled so it doesn't pass to objects behind it
			get_viewport().set_input_as_handled()

func _on_click_area_mouse_entered() -> void:
	#print("mouse entered Playroom Door")
	owner.pointing_at_door = true


func _on_click_area_mouse_exited() -> void:
	#print("mouse exited Playroom Door")
	owner.pointing_at_door = false
