class_name LitterBoxCat
extends TextureButton

@onready var anim_play = $AnimationPlayer

func animate(anim := "idle") -> void:
	anim_play.play(anim)
	
func happy_meow():
	$AudioCat/MeowHappy.play()
