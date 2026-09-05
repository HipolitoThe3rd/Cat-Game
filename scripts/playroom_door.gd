class_name PlayroomDoor
extends Node2D

## A hatch in the maze floor. Closed it is a tile the cat walks over, open it
## is a hole he drops through, and the player toggles it by clicking on it.

@onready var anim_play = $AnimationPlayer
@onready var body_shape: CollisionShape2D = $StaticBody2D/CollisionShape2D

var is_open := false

var _room: Node = null


func _ready() -> void:
	# Sub-resources are shared between instances of a packed scene, so give this
	# door a shape of its own before the AnimationPlayer starts writing to it --
	# otherwise opening one door resizes every other door's collider too.
	body_shape.shape = body_shape.shape.duplicate()
	_room = get_tree().get_first_node_in_group("playroom")
	set_open(false)


## Custom functions
func set_open(open: bool) -> void:
	is_open = open
	anim_play.play("open" if open else "closed")
	# The swung-open gate parks a stray post right in the hole, which the cat
	# would land on; drop the collider entirely so an open hatch is a clean drop.
	body_shape.set_deferred("disabled", open)


func toggle() -> void:
	if is_open:
		$SFX/SFXDoorClose.play()
	else:
		$SFX/SFXDoorOpen.play()
	set_open(not is_open)


## Signals
func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Check if the event is a mouse button click
	if event is InputEventMouseButton:
		# Check if it was a Left Click and if it was just pressed (not released)
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			toggle()


func _on_click_area_mouse_entered() -> void:
	if _room:
		_room.pointing_at_door = true


func _on_click_area_mouse_exited() -> void:
	if _room:
		_room.pointing_at_door = false
