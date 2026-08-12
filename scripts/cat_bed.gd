class_name BedCat
extends Node2D

@onready var anim_play = $AnimationPlayer
@onready var upset = false

func animate(anim := "sleep") -> void:
	anim_play.play(anim)
	
func happy_meow():
	$AudioCat/MeowHappy.play()
	
func upset_meow():
	$AudioCat/MeowUpset.play()
