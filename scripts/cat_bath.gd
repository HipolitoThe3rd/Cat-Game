class_name BathCat
extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const DIRTY_COLOR = Color(0.45, 0.40, 0.34, 1.0)
const CLEAN_COLOR = Color(1.0, 1.0, 1.0, 1.0)
const WASH_TICK_SECONDS = 1.0
const WASH_AMOUNT_PER_TICK = 1.0
const CAT_CRY_INTERVAL_SECONDS = 2.0
const WALL_LOOKAHEAD = 16.0
const WALL_BOUNCE_DURATION = 2.0
const CAT_CRY_STREAMS = [
	preload("res://sfx/cat_cry/cat_cry_1.wav"),
	preload("res://sfx/cat_cry/cat_cry_2.wav"),
	preload("res://sfx/cat_cry/cat_cry_3.wav"),
	preload("res://sfx/cat_cry/cat_cry_4.wav"),
	preload("res://sfx/cat_cry/cat_cry_5.wav"),
	preload("res://sfx/cat_cry/cat_cry_6.wav"),
	preload("res://sfx/cat_cry/cat_cry_7.wav")
]

@onready var sprite = $Sprite2D
@onready var anim_play = $AnimationPlayer
@onready var audio_cat = $AudioCat
@onready var shower_area: Area2D = get_node_or_null("../ShowerheadHitbox/Area2D")

var cooldown = 0.0
var bounce_direction = 0.0
var cry_timer = 0.0
var cry_player: AudioStreamPlayer
var was_being_sprayed = false

signal squeaky_clean()

var has_reached_squeaky_clean = false
var is_squeaky_clean_state = false
var wash_tick_timer = 0.0


func _ready() -> void:
	randomize()
	cry_player = AudioStreamPlayer.new()
	audio_cat.add_child(cry_player)
	$AudioCat/MeowAngry.play()
	if not squeaky_clean.is_connected(_on_squeaky_clean):
		squeaky_clean.connect(_on_squeaky_clean)

func _process(_delta: float) -> void:
	var cleanliness_ratio := clamp(Global.cleanliness / 100.0, 0.0, 1.0)
	sprite.modulate = DIRTY_COLOR.lerp(CLEAN_COLOR, cleanliness_ratio)

	if cleanliness_ratio >= 1.0 and not has_reached_squeaky_clean:
		has_reached_squeaky_clean = true
		is_squeaky_clean_state = true
		emit_signal("squeaky_clean")

func _physics_process(delta: float) -> void:
	var cleanliness_ratio := clamp(Global.cleanliness / 100.0, 0.0, 1.0)
	var is_pressing_shower := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var is_intersecting_shower := shower_area != null and shower_area.overlaps_body(self)
	var is_being_sprayed := is_pressing_shower and is_intersecting_shower
	_update_cry_audio(delta, is_being_sprayed)

	if is_squeaky_clean_state:
		velocity.x = 0.0
		move_and_slide()
		return

	if cleanliness_ratio >= 1.0:
		velocity.x = 0.0
	else:
		if is_pressing_shower and is_intersecting_shower:
			wash_tick_timer += delta
			while wash_tick_timer >= WASH_TICK_SECONDS:
				Global.cleanliness = min(100.0, Global.cleanliness + WASH_AMOUNT_PER_TICK)
				wash_tick_timer -= WASH_TICK_SECONDS

			var move_direction: float
			if cooldown > 0.0:
				cooldown -= delta
				move_direction = bounce_direction
				# If we also hit a wall in the bounce direction, just stop early.
				if test_move(global_transform, Vector2(move_direction * WALL_LOOKAHEAD, 0.0)):
					cooldown = 0.0
					move_direction = 0.0
			else:
				# Normal: move away from showerhead.
				var desired_direction := sign(global_position.x - shower_area.global_position.x)
				if desired_direction == 0:
					desired_direction = -1.0 if sprite.flip_h else 1.0

				if test_move(global_transform, Vector2(desired_direction * WALL_LOOKAHEAD, 0.0)):
					# Wall ahead — bounce the other way for a few seconds.
					bounce_direction = -desired_direction
					cooldown = WALL_BOUNCE_DURATION
					move_direction = bounce_direction
				else:
					move_direction = desired_direction

			velocity.x = move_direction * SPEED * cleanliness_ratio
			if velocity.x != 0.0:
				sprite.flip_h = velocity.x < 0

			if anim_play.current_animation != "move":
				anim_play.play("move")
		else:
			wash_tick_timer = 0.0
			cooldown = 0.0
			velocity.x = 0.0
			if anim_play.current_animation != "idle":
				anim_play.play("idle")

	move_and_slide()


func _update_cry_audio(delta: float, is_being_sprayed: bool) -> void:
	if not is_being_sprayed:
		cry_timer = 0.0
		was_being_sprayed = false
		return

	if not was_being_sprayed:
		_play_random_cat_cry()
		cry_timer = 0.0
		was_being_sprayed = true
		return

	cry_timer += delta
	while cry_timer >= CAT_CRY_INTERVAL_SECONDS:
		_play_random_cat_cry()
		cry_timer -= CAT_CRY_INTERVAL_SECONDS


func _play_random_cat_cry() -> void:
	if CAT_CRY_STREAMS.is_empty() or cry_player == null:
		return

	cry_player.stream = CAT_CRY_STREAMS[randi_range(0, CAT_CRY_STREAMS.size() - 1)]
	if Global.cleanliness < 100:
		cry_player.play()


func _on_squeaky_clean() -> void:
	if anim_play.current_animation != "sigh" or not anim_play.is_playing():
		anim_play.play("sigh")
		if $AudioCat/MeowAngry.playing == true:
			$AudioCat/MeowAngry.stop()
