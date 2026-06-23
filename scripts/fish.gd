class_name Fish
extends Node2D

@onready var drag_sprite = $SpriteDrag
@onready var fall_sprite = $SpriteFall

const GRAVITY := 1600.0
const OFFSCREEN_BUFFER := 200.0

var is_dragging := false
var velocity := Vector2.ZERO

func _ready() -> void:
	set_process(false)

func start_drag(spawn_position: Vector2) -> void:
	$Audio/FishGrab.play()
	global_position = spawn_position
	is_dragging = true
	velocity = Vector2.ZERO
	drag_sprite.visible = true
	fall_sprite.visible = false
	set_process(true)

func _process(delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position()
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_begin_fall()
		return

	velocity.y += GRAVITY * delta
	global_position += velocity * delta

	var viewport_height := get_viewport_rect().size.y
	if global_position.y > viewport_height + OFFSCREEN_BUFFER:
		queue_free()

func _begin_fall() -> void:
	$Audio/FishFall.play()
	is_dragging = false
	drag_sprite.visible = false
	fall_sprite.visible = true

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is KitchenCat:
		print("fish collided with Cat")
		body.play_sound("happy")
		Global.feed_cat(10)
		queue_free()
	pass
