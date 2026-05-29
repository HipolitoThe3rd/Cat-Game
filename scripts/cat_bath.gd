extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const DIRTY_COLOR = Color(0.45, 0.40, 0.34, 1.0)
const CLEAN_COLOR = Color(1.0, 1.0, 1.0, 1.0)

@onready var sprite = $Sprite2D
@onready var anim_play = $AnimationPlayer

signal squeaky_clean()

var has_reached_squeaky_clean = false

func _process(_delta: float) -> void:
	var cleanliness_ratio := clamp(Global.cleanliness / 100.0, 0.0, 1.0)
	sprite.modulate = DIRTY_COLOR.lerp(CLEAN_COLOR, cleanliness_ratio)

	if cleanliness_ratio >= 1.0 and not has_reached_squeaky_clean:
		has_reached_squeaky_clean = true
		emit_signal("squeaky_clean")

func _physics_process(_delta: float) -> void:
	var cleanliness_ratio := clamp(Global.cleanliness / 100.0, 0.0, 1.0)

	if cleanliness_ratio >= 1.0:
		velocity.x = 0.0
		if anim_play.current_animation != "sigh":
			anim_play.play("sigh")
	else:
		velocity.x = SPEED * cleanliness_ratio

	move_and_slide()

