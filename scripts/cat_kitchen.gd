class_name KitchenCat
extends CharacterBody2D

const SPEED = 30.0
const JUMP_VELOCITY = -600.0

@onready var sprite = $Sprite2D
@onready var anim = $AnimationPlayer
@onready var sfx_happy = $AudioCat/MeowHappy
@onready var sfx_angry = $AudioCat/MeowAngry
@onready var sfx_eat = $AudioCat/EatFish

var direction = 1
var target: Fish # the fish that the Cat is targeting, if any

func _physics_process(delta: float) -> void:	
	
	# handle full Cat 
	if Global.hunger >= 100:
		velocity.x = 0
	else:
		# handle walking
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	
		# jump when fish is dropped
		if target == null:
			pass
		else:
			if target.is_dragging == false && velocity.y == 0:
				velocity.y = JUMP_VELOCITY
				if anim.current_animation != "jump":
					anim.play("jump")
	
	# handle sprite direction
		if direction == 1: # if moving right
			sprite.flip_h = direction # flip sprite
		elif direction == -1: # if moving left
			sprite.flip_h = 0 # don't flip sprite
		
	velocity.y += get_gravity().y * delta
	
	#print("velocity.y: ", velocity.y)
	#print("velocity.x: ", velocity.x)
	#print("anim.current_animation: ", anim.current_animation)
	#print("hunger: ", Global.hunger)
	if velocity.y > 16.5 and velocity.y < 300 and velocity.x != 0 and anim.current_animation != "walk" and Global.hunger < 100:
		anim.play("walk")
	

	
	move_and_slide()

func play_sound(audio_name:String):
	match audio_name:
		"happy", "sfx_happy":
			sfx_happy.play()
		"angry", "sfx_angry":
			sfx_angry.play()
		"eat", "sfx_eat":
			sfx_eat.play()
