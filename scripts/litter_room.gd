extends Node2D

@onready var litter_box = $LitterBox
@onready var lb_clean_sprite = $LitterBox/LitterboxClean
@onready var lb_dirty_sprite = $LitterBox/LitterboxDirty
@onready var cat = $Cat
@onready var bl_bar = $BladderBar

func _ready() -> void:
	# if bladder is below 25, use the litterbox automatically
	if Global.bladder < 25:
		relieve_cat()
	elif Global.bladder > 75:
		cat.happy_meow()
		cat.animate()
	else:
		cat.animate("idle_half-speed")
	
func _process(_delta: float) -> void:
	bl_bar.value = Global.bladder

func relieve_cat() -> void:
	Global.bladder = 100
	lb_clean_sprite.visible = false
	lb_dirty_sprite.visible = true
	cat.animate("stinky")

func _on_back_button_button_down() -> void:
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
