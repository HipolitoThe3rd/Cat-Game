class_name KitchenCat
extends CharacterBody2D

@onready var sfx_happy = $AudioCat/MeowHappy
@onready var sfx_angry = $AudioCat/MeowAngry
@onready var sfx_eat = $AudioCat/EatFish

func play_sound(audio_name:String):
	match audio_name:
		"happy", "sfx_happy":
			sfx_happy.play()
		"angry", "sfx_angry":
			sfx_angry.play()
		"eat", "sfx_eat":
			sfx_eat.play()
