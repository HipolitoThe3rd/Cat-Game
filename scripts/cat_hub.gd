extends CharacterBody2D


const SPEED = 30.0
const JUMP_VELOCITY = -400.0

@onready var sprite = $Sprite2D
@onready var anim_play = $AnimationPlayer
@onready var sfx_meow1 = $SFX/Meow1
@onready var sfx_meow2 = $SFX/Meow2
@onready var sfx_meow3 = $SFX/Meow3
@onready var sfx_meow_happy = $SFX/MeowHappy

# Mood system
var mood = 50 # how happy the cat is; 0 is minimum and 100 is maximum

# Mood contributors
var hunger = 30 # 0 to 100, affects mood and behavior
var energy = 80 # 0 to 100, decreases with activity
var cleanliness = 60 # 0 to 100, decreases over time, affects mood
var entertainment = 50 # 0 to 100, boredom level; too low means bored
var affection = 40 # 0 to 100, needs player interaction to increase
var restlessness = 0 # 0 to 100, increases when stationary, affects movement

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
		energy = max(0, energy - 5)
		restlessness = 0

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
		
		# More restless cats move more often
		if restlessness > 70:
			movement_timer *= 0.5
	
	# Occasionally hop
	hop_timer -= delta
	if hop_timer <= 0:
		# Higher energy and restlessness = more hops
		var hop_chance = 0.3 if energy > 60 and restlessness > 40 else 0.1
		if randf() < hop_chance and is_on_floor():
			velocity.y = JUMP_VELOCITY * 0.7  # Smaller hop than player jump
			energy = max(0, energy - 3)
			restlessness = max(0, restlessness - 10)
		
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
		hunger = min(100, hunger + 0.3)  # Cat gets hungrier
		cleanliness = max(0, cleanliness - 0.2)  # Cat gets dirtier
		energy = max(0, energy - 0.1)  # Slow energy loss
		entertainment = max(0, entertainment - 0.15)  # Boredom increases
		restlessness = min(100, restlessness + 0.2)  # Restlessness increases when idle
		
		stat_decay_timer = 1.0


func update_mood_stats(delta: float) -> void:
	# Calculate mood based on all factors
	var mood_modifiers = 0
	
	# Hunger strongly affects mood
	if hunger > 70:
		mood_modifiers -= 20
	elif hunger > 50:
		mood_modifiers -= 10
	
	# Cleanliness affects mood
	if cleanliness < 30:
		mood_modifiers -= 15
	elif cleanliness < 50:
		mood_modifiers -= 8
	
	# Entertainment/boredom affects mood
	if entertainment < 20:
		mood_modifiers -= 15
	elif entertainment < 40:
		mood_modifiers -= 8
	
	# Energy affects mood
	if energy < 20:
		mood_modifiers -= 12
	
	# Affection affects mood
	if affection < 30:
		mood_modifiers -= 10
	elif affection > 70:
		mood_modifiers += 15
	
	# Contentment bonus (all stats in good range)
	if hunger < 50 and cleanliness > 50 and entertainment > 50 and energy > 50 and affection > 50:
		mood_modifiers += 5
	
	mood = clamp(mood + mood_modifiers * 0.01, 0, 100)


func play_meow() -> void:
	if mood >= 80:
		sfx_meow_happy.play()
	else:
		var meow_sounds = [sfx_meow1, sfx_meow2, sfx_meow3]
		var random_meow = meow_sounds[randi() % meow_sounds.size()]
		random_meow.play()


# Helper functions for external interactions
func feed_cat() -> void:
	hunger = max(0, hunger - 30)
	mood = min(100, mood + 5)
	affection = min(100, affection + 2)


func pet_cat() -> void:
	affection = min(100, affection + 15)
	entertainment = min(100, entertainment + 10)
	mood = min(100, mood + 10)
	restlessness = max(0, restlessness - 20)


func play_with_cat() -> void:
	entertainment = 100
	energy = max(0, energy - 20)
	affection = min(100, affection + 5)
	restlessness = max(0, restlessness - 30)


func bathe_cat() -> void:
	cleanliness = 100
	mood = min(100, mood + 8)
	affection = max(0, affection - 10)  # Cats don't like baths!
	energy = max(0, energy - 15)
