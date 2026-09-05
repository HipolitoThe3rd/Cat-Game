class_name PlayroomCat
extends CharacterBody2D

## The cat in the laser maze.
##
## He only moves while the player holds the laser near him. How fast he moves
## depends on how far away the dot is: park it next to him and he creeps, throw
## it across the room and he sprints. That one rule drives the whole ledge feel
## from the brief -- a sprinting cat hops a one-tile gap, an ambling cat walks
## straight off the edge and drops to the floor below.

# --- Movement -------------------------------------------------------------
const RUN_SPEED = 280.0         # top speed, reached when the dot is far away
const RUN_DISTANCE = 190.0      # dot distance that counts as "far away"
const MIN_SPEED_FACTOR = 0.18   # dot right under his nose -> slow creep
const STOP_DEADZONE = 6.0       # dot this close horizontally: stand still
const ACCEL = 1100.0
const DECEL = 1300.0
const AIR_ACCEL = 380.0

const GRAVITY = 980.0
const MAX_FALL = 900.0
const JUMP_VELOCITY = -280.0    # ~40px hop, clears a gap without a head bonk
const JUMP_LOCK = 0.22          # keep the arc honest right after take-off

# --- Ledges ---------------------------------------------------------------
const JUMP_MIN_SPEED = 0.75     # fraction of RUN_SPEED needed to commit
const MAX_JUMP_GAP = 170.0      # one grid cell (128) is hoppable, two are not
const EDGE_TRIGGER = 10.0       # how close to the lip before he pushes off
const SCAN_START = 3.0
const SCAN_STEP = 4.0
const SCAN_MAX = 340.0
const PROBE_UP = 6.0
const PROBE_DOWN = 34.0
const TIP_PUSH = 70.0           # nudge that tips a teetering cat off the lip

# --- Feedback -------------------------------------------------------------
const JUMP_TINT = Color(0.62, 1.0, 0.7)  # wash over him while he could clear a gap
const ANIM_SLOWEST = 0.4        # "move" playback at a creep
const ANIM_FASTEST = 1.6        # ... and at a full sprint

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_play: AnimationPlayer = $AnimationPlayer
@onready var collider: CollisionShape2D = $CollisionShape2D
@onready var sfx_meow1 = $SFX/Meow1
@onready var sfx_meow2 = $SFX/Meow2
@onready var sfx_meow3 = $SFX/Meow3
@onready var sfx_meow_happy = $SFX/MeowHappy
@onready var sfx_purr = $SFX/Purr

# Driven by the playroom every frame
var laser_pos := Vector2.ZERO
var laser_held := false
var follow_radius := 320.0

var following := false          # read by the playroom to score "actively playing"
var celebrating := false
var hovered := false
var facing := 1

var start_pos := Vector2.ZERO
var radius := 30.8              # collider size in world units, filled in _ready
var foot_offset := 35.28        # origin -> soles, in world units

var jump_lock := 0.0
var meow_timer := 6.0
var stat_decay_timer := 0.0


## Default functions
func _ready() -> void:
	randomize()
	meow_timer = randf_range(4.0, 9.0)
	start_pos = global_position
	var shape: CircleShape2D = collider.shape
	radius = shape.radius * absf(scale.x)
	foot_offset = collider.position.y * scale.y + radius


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	jump_lock = maxf(jump_lock - delta, 0.0)

	if celebrating:
		velocity.x = move_toward(velocity.x, 0.0, DECEL * delta)
		move_and_slide()
		return

	following = laser_held and global_position.distance_to(laser_pos) <= follow_radius

	var dx := laser_pos.x - global_position.x
	var dir := 0
	if following and absf(dx) > STOP_DEADZONE:
		dir = 1 if dx > 0.0 else -1

	# Speed is a function of how far the dot is: this is what lets the player
	# choose between hopping a gap and stepping off the ledge into it.
	var target := 0.0
	if dir != 0:
		target = dir * RUN_SPEED * clampf(absf(dx) / RUN_DISTANCE, MIN_SPEED_FACTOR, 1.0)

	if is_on_floor():
		if dir != 0:
			facing = dir
			velocity.x = move_toward(velocity.x, target, ACCEL * delta)
			try_hop(dir)
		else:
			velocity.x = move_toward(velocity.x, 0.0, DECEL * delta)
			tip_off_ledge()
	elif dir != 0 and jump_lock <= 0.0:
		velocity.x = move_toward(velocity.x, target, AIR_ACCEL * delta)

	move_and_slide()
	update_anim()
	update_timers(delta)
	update_mood_stats(delta)


## Custom functions
# Only hops when he is genuinely running at a gap he can clear. Anything wider
# than a single tile, or any slower approach, and he just walks off the edge.
func try_hop(dir: int) -> void:
	# He pushes off the floor under his feet, so a tile that just disappeared
	# from under him -- a hatch the player opened -- is not a launch pad.
	if not ground_at(global_position.x):
		return
	var scan := scan_ahead(dir)
	var edge: float = scan["edge"]
	if edge < 0.0 or edge > EDGE_TRIGGER:
		return
	if scan["gap"] > MAX_JUMP_GAP:
		return
	if absf(velocity.x) < RUN_SPEED * JUMP_MIN_SPEED:
		return
	velocity.y = JUMP_VELOCITY
	velocity.x = dir * RUN_SPEED
	jump_lock = JUMP_LOCK


# Standing still with nothing under his middle means he is balanced on the lip,
# so he slips off instead of hovering there.
func tip_off_ledge() -> void:
	if ground_at(global_position.x):
		return
	velocity.x = facing * TIP_PUSH


# Walks probes forward along the floor line looking for where the floor stops
# and, if it does, where it starts again.
func scan_ahead(dir: int) -> Dictionary:
	var edge := -1.0
	var landing := -1.0
	var d := SCAN_START
	while d <= SCAN_MAX:
		var solid := ground_at(global_position.x + dir * d)
		if edge < 0.0:
			if not solid:
				edge = d
		elif solid:
			landing = d
			break
		d += SCAN_STEP
	var gap := INF
	if edge >= 0.0 and landing >= 0.0:
		gap = landing - edge
	return {"edge": edge, "gap": gap}


func ground_at(x: float) -> bool:
	var feet := global_position.y + foot_offset
	var query := PhysicsRayQueryParameters2D.create(
		Vector2(x, feet - PROBE_UP), Vector2(x, feet + PROBE_DOWN))
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


# True while he is running hard enough to clear a one-tile gap instead of
# stepping off into it. Drives the speed bar and his own tint.
func at_jump_speed() -> bool:
	return absf(velocity.x) >= RUN_SPEED * JUMP_MIN_SPEED


func update_anim() -> void:
	if at_jump_speed():
		if sprite.modulate != JUMP_TINT:
			$SFX/Woosh.play()
		sprite.modulate = JUMP_TINT
	else:
		sprite.modulate = Color.WHITE
	if anim_play.current_animation == "yarn":
		return
	if velocity.x > 1.0:
		sprite.flip_h = true
	elif velocity.x < -1.0:
		sprite.flip_h = false

	if is_on_floor() and absf(velocity.x) > 15.0:
		# His legs keep up with him: a creep shuffles, a sprint blurs.
		anim_play.speed_scale = lerpf(ANIM_SLOWEST, ANIM_FASTEST,
			clampf(absf(velocity.x) / RUN_SPEED, 0.0, 1.0))
		if anim_play.current_animation != "move":
			anim_play.play("move")
	else:
		anim_play.speed_scale = 1.0
		if anim_play.current_animation == "move":
			anim_play.play("pet" if hovered else "RESET")


func update_timers(delta: float) -> void:
	meow_timer -= delta
	if meow_timer <= 0.0:
		play_meow()
		meow_timer = randf_range(6.0, 14.0)

	stat_decay_timer -= delta
	if stat_decay_timer <= 0:
		# Stats decay gradually
		Global.hunger = min(100, Global.hunger - 0.3)  # Cat gets hungrier
		Global.cleanliness = max(0, Global.cleanliness - 0.2)  # Cat gets dirtier
		Global.energy = max(0, Global.energy - 0.1)  # Slow energy loss
		Global.bladder = max(0, Global.bladder - 0.2)  # Bladder slowly drains over time

		if Global.bladder <= 0:
			Global.cleanliness = max(0, Global.cleanliness - 30)
			Global.bladder = 100

		stat_decay_timer = 1.0


func update_mood_stats(delta: float) -> void:
	# Calculate mood based on all factors
	var mood_modifiers = 0

	# Hunger strongly affects mood
	if Global.hunger < 70:
		mood_modifiers -= 0.20
	elif Global.hunger < 50:
		mood_modifiers -= 0.10

	# Cleanliness affects mood
	if Global.cleanliness < 30:
		mood_modifiers -= 0.15
	elif Global.cleanliness < 50:
		mood_modifiers -= 0.8

	# Entertainment/boredom affects mood
	if Global.entertainment < 20:
		mood_modifiers -= 0.15
	elif Global.entertainment < 40:
		mood_modifiers -= 0.8

	# Energy affects mood
	if Global.energy < 20:
		mood_modifiers -= 0.12

	# Affection affects mood
	if Global.affection < 30:
		mood_modifiers -= 0.10
	elif Global.affection > 70:
		mood_modifiers += 0.15

	# Contentment bonus (all stats in good range)
	if Global.hunger > 50 and Global.cleanliness > 50 and Global.entertainment > 50 and Global.energy > 50 and Global.affection > 50:
		mood_modifiers += 5

	# 0.6/s matches the old per-frame 0.01 drift, minus the frame-rate dependency
	Global.mood = clamp(Global.mood + mood_modifiers * delta * 0.6, 0, 100)


func play_meow() -> void:
	var meow_sounds = [sfx_meow1, sfx_meow2, sfx_meow3]
	var random_meow = meow_sounds[randi() % meow_sounds.size()]
	random_meow.play()


# Called by the yarn when he reaches it.
func celebrate() -> void:
	celebrating = true
	following = false
	# Lock in whichever way he was headed so he cheers facing that way; the
	# yarn animation only swaps textures, so flip_h carries through it.
	sprite.flip_h = facing < 0
	sprite.modulate = Color.WHITE
	anim_play.speed_scale = 1.0
	anim_play.play("yarn")
	Global.energy = max(0, Global.energy - 8)
	Global.affection = min(100, Global.affection + 3)


# Called by the playroom whenever a fresh maze is built.
func place_at(pos: Vector2) -> void:
	celebrating = false
	following = false
	velocity = Vector2.ZERO
	jump_lock = 0.0
	global_position = pos
	start_pos = pos
	sprite.modulate = Color.WHITE
	anim_play.speed_scale = 1.0
	anim_play.play("RESET")


# Where his origin has to sit for his soles to rest on a surface at surface_y.
func stand_position(x: float, surface_y: float) -> Vector2:
	return Vector2(x, surface_y - foot_offset)


## Signals
func _on_mouse_entered() -> void:
	hovered = true


func _on_mouse_exited() -> void:
	hovered = false
	sfx_purr.stop()
	if anim_play.current_animation == "pet":
		anim_play.play("RESET")
