extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const DIRTY_COLOR = Color(0.45, 0.40, 0.34, 1.0)
const CLEAN_COLOR = Color(1.0, 1.0, 1.0, 1.0)
const WASH_TICK_SECONDS = 1.0
const WASH_AMOUNT_PER_TICK = 1.0
const WALL_LOOKAHEAD = 16.0

@onready var sprite = $Sprite2D
@onready var anim_play = $AnimationPlayer
@onready var shower_area: Area2D = get_node_or_null("../ShowerheadHitbox/Area2D")

signal squeaky_clean()

var has_reached_squeaky_clean = false
var wash_tick_timer = 0.0

func _process(_delta: float) -> void:
	var cleanliness_ratio := clamp(Global.cleanliness / 100.0, 0.0, 1.0)
	sprite.modulate = DIRTY_COLOR.lerp(CLEAN_COLOR, cleanliness_ratio)

	if cleanliness_ratio >= 1.0 and not has_reached_squeaky_clean:
		has_reached_squeaky_clean = true
		emit_signal("squeaky_clean")

func _physics_process(delta: float) -> void:
	var cleanliness_ratio := clamp(Global.cleanliness / 100.0, 0.0, 1.0)
	var is_pressing_shower := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var is_intersecting_shower := shower_area != null and shower_area.overlaps_body(self)

	if cleanliness_ratio >= 1.0:
		velocity.x = 0.0
		if anim_play.current_animation != "sigh":
			anim_play.play("sigh")
	else:
		if is_pressing_shower and is_intersecting_shower:
			wash_tick_timer += delta
			while wash_tick_timer >= WASH_TICK_SECONDS:
				Global.cleanliness = min(100.0, Global.cleanliness + WASH_AMOUNT_PER_TICK)
				wash_tick_timer -= WASH_TICK_SECONDS

			# Move away from showerhead unless blocked by a nearby wall.
			var desired_direction := sign(global_position.x - shower_area.global_position.x)
			if desired_direction == 0:
				desired_direction = -1.0 if sprite.flip_h else 1.0

			var desired_motion := Vector2(desired_direction * WALL_LOOKAHEAD, 0.0)
			if test_move(global_transform, desired_motion):
				desired_direction *= -1.0

			velocity.x = desired_direction * SPEED * cleanliness_ratio
			sprite.flip_h = velocity.x < 0

			if anim_play.current_animation != "move":
				anim_play.play("move")
		else:
			wash_tick_timer = 0.0
			velocity.x = 0.0
			if anim_play.current_animation != "idle":
				anim_play.play("idle")

	move_and_slide()
