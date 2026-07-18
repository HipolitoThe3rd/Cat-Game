class_name LitterRoomCat
extends Node2D

@onready var anim_play = $AnimationPlayer

func animate(anim := "idle") -> void:
	anim_play.play(anim)
	
func happy_meow():
	$AudioCat/MeowHappy.play()
