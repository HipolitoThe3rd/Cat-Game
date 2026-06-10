extends CharacterBody2D


const SPEED = 30.0
const JUMP_VELOCITY = -400.0

@onready var sprite = $Sprite2D
@onready var anim_play = $AnimationPlayer
@onready var sfx_meow1 = $SFX/Meow1
@onready var sfx_meow2 = $SFX/Meow2
@onready var sfx_meow3 = $SFX/Meow3
@onready var sfx_meow_happy = $SFX/MeowHappy

# Autonomous behavior timers
var meow_timer = 0.0
var meow_interval = randf_range(3.0, 8.0)
var movement_timer = 0.0
var movement_interval = randf_range(2.0, 5.0)
var hop_timer = 0.0
var hop_interval = randf_range(8.0, 15.0)
var stat_decay_timer = 0.0

# Movement state
var current_direction = 0 # -1, 0, or 1
var is_autonomous = true


func _ready() -> void:
	Input.set_custom_mouse_cursor(null)
	randomize()


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle player input
	var player_direction := Input.get_axis("ui_left", "ui_right")
	
	# Handle jump (player input takes priority).
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		Global.energy = max(0, Global.energy - 5)
		Global.bladder = max(0, Global.bladder - 2)

	# Update autonomous behavior
	if is_autonomous and is_on_floor():
		update_autonomous_behavior(delta)
		update_timers(delta)
		update_mood_stats(delta)
	
	# Determine direction: player input overrides autonomous behavior
	var direction = player_direction if player_direction else current_direction
	
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()


func update_autonomous_behavior(delta: float) -> void:
	# Decide to change direction
	movement_timer -= delta
	if movement_timer <= 0:
		current_direction = randi() % 3 - 1  # -1, 0, or 1
		print("cat's current direction: ", current_direction)
		if current_direction == 0:
			anim_play.play("RESET")
		else:
			#print("cat started walking")
			if anim_play.current_animation != "walk":
				anim_play.play("walk")
			if current_direction == 1: # if moving right
				sprite.flip_h = current_direction # flip sprite
			elif current_direction == -1: # if moving left
				sprite.flip_h = 0 # don't flip sprite
			
			
		movement_interval = randf_range(1.5, 4.0) if current_direction != 0 else randf_range(2.0, 5.0)
		movement_timer = movement_interval
		
		# Cats with low bladder move more urgently
		if Global.bladder < 30:
			movement_timer *= 0.5
	
	# Occasionally hop
	hop_timer -= delta
	if hop_timer <= 0:
		# Higher energy and lower bladder = more fidgety hops
		var hop_chance = 0.3 if Global.energy > 60 and Global.bladder < 60 else 0.1
		if randf() < hop_chance and is_on_floor():
			velocity.y = JUMP_VELOCITY * 0.7  # Smaller hop than player jump
			Global.energy = max(0, Global.energy - 3)
			Global.bladder = max(0, Global.bladder - 1)
		
		hop_interval = randf_range(6.0, 12.0)
		hop_timer = hop_interval
	
	# Play meow sounds
	meow_timer -= delta
	if meow_timer <= 0:
		play_meow()
		meow_interval = randf_range(2.5, 7.0)
		meow_timer = meow_interval


func update_timers(delta: float) -> void:
	stat_decay_timer -= delta
	if stat_decay_timer <= 0:
		# Stats decay gradually
		Global.hunger = min(100, Global.hunger + 0.3)  # Cat gets hungrier
		Global.cleanliness = max(0, Global.cleanliness - 0.2)  # Cat gets dirtier
		Global.energy = max(0, Global.energy - 0.1)  # Slow energy loss
		Global.entertainment = max(0, Global.entertainment - 0.15)  # Boredom increases
		Global.bladder = max(0, Global.bladder - 0.2)  # Bladder slowly drains over time

		if Global.bladder <= 0:
			Global.cleanliness = max(0, Global.cleanliness - 30)
			Global.bladder = 100
		
		stat_decay_timer = 1.0


func update_mood_stats(delta: float) -> void:
	# Calculate mood based on all factors
	var mood_modifiers = 0
	
	# Hunger strongly affects mood
	if Global.hunger > 70:
		mood_modifiers -= 20
	elif Global.hunger > 50:
		mood_modifiers -= 10
	
	# Cleanliness affects mood
	if Global.cleanliness < 30:
		mood_modifiers -= 15
	elif Global.cleanliness < 50:
		mood_modifiers -= 8
	
	# Entertainment/boredom affects mood
	if Global.entertainment < 20:
		mood_modifiers -= 15
	elif Global.entertainment < 40:
		mood_modifiers -= 8
	
	# Energy affects mood
	if Global.energy < 20:
		mood_modifiers -= 12
	
	# Affection affects mood
	if Global.affection < 30:
		mood_modifiers -= 10
	elif Global.affection > 70:
		mood_modifiers += 15
	
	# Contentment bonus (all stats in good range)
	if Global.hunger < 50 and Global.cleanliness > 50 and Global.entertainment > 50 and Global.energy > 50 and Global.affection > 50:
		mood_modifiers += 5
	
	Global.mood = clamp(Global.mood + mood_modifiers * 0.01, 0, 100)


func play_meow() -> void:
	if Global.mood >= 80:
		sfx_meow_happy.play()
	else:
		var meow_sounds = [sfx_meow1, sfx_meow2, sfx_meow3]
		var random_meow = meow_sounds[randi() % meow_sounds.size()]
		random_meow.play()


# Helper functions for external interactions
func feed_cat() -> void:
	Global.hunger = max(0, Global.hunger - 30)
	Global.mood = min(100, Global.mood + 5)
	Global.affection = min(100, Global.affection + 2)


func pet_cat() -> void:
	Global.affection = min(100, Global.affection + 15)
	Global.entertainment = min(100, Global.entertainment + 10)
	Global.mood = min(100, Global.mood + 10)


func play_with_cat() -> void:
	Global.entertainment = 100
	Global.energy = max(0, Global.energy - 20)
	Global.affection = min(100, Global.affection + 5)


func bathe_cat() -> void:
	Global.cleanliness = 100
	Global.mood = min(100, Global.mood + 8)
	Global.affection = max(0, Global.affection - 10)  # Cats don't like baths!
	Global.energy = max(0, Global.energy - 15)
