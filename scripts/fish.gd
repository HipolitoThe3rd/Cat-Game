class_name Fish
extends Node2D

@onready var drag_sprite = $SpriteDrag
@onready var fall_sprite = $SpriteFall

const GRAVITY := 1600.0
const OFFSCREEN_BUFFER := 200.0
const MIN_FALL_MULT := 1.0
const MAX_FALL_MULT := 2.5
const FULL_BONUS_FALL_DISTANCE := 450.0

var is_dragging := false
var velocity := Vector2.ZERO
var fall_mult := 1.0 # increases depending on how far it has fallen
var drop_start_y := 0.0

func _ready() -> void:
	set_process(false)

func start_drag(spawn_position: Vector2) -> void:
	$Audio/FishGrab.play()
	global_position = spawn_position
	is_dragging = true
	velocity = Vector2.ZERO
	fall_mult = MIN_FALL_MULT
	drop_start_y = global_position.y
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

	# Scale reward by how far the fish has fallen after release.
	var distance_fallen := maxf(0.0, global_position.y - drop_start_y)
	var t := clampf(distance_fallen / FULL_BONUS_FALL_DISTANCE, 0.0, 1.0)
	fall_mult = lerpf(MIN_FALL_MULT, MAX_FALL_MULT, t)

	var viewport_height := get_viewport_rect().size.y
	if global_position.y > viewport_height + OFFSCREEN_BUFFER:
		queue_free()

func _begin_fall() -> void:
	$Audio/FishFall.play()
	is_dragging = false
	drop_start_y = global_position.y
	drag_sprite.visible = false
	fall_sprite.visible = true

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is KitchenCat and is_dragging == false:
		#print("fish collided with Cat")
		var hunger_gain := max(1, roundi(5.0 * fall_mult))
		Global.feed_cat(hunger_gain)
		if Global.hunger >= 100:
			#print("Cat is full!")
			body.play_sound("happy")
			body.get_node("AnimationPlayer").play("full")
		else:
			body.play_sound("eat")
		queue_free()
	pass
