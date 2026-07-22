extends Node2D

@onready var litter_box = $LitterBox
@onready var lb_clean_button = $LitterBoxClean
@onready var lb_dirty_button = $LitterBoxDirty
@onready var scat = $Scat
@onready var cat = $Cat
@onready var bl_bar = $BladderBar

func _ready() -> void:
	#set cursor
	if Global.web_version:
		Input.set_custom_mouse_cursor(Global.smcursor_default)
	else:
		Input.set_custom_mouse_cursor(Global.cursor_default)
	
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
	lb_clean_button.disabled = true
	lb_clean_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb_dirty_button.disabled = false
	scat.visible = true
	cat.animate("stinky")

func _on_back_button_button_down() -> void:
	get_tree().change_scene_to_file("res://scenes/hub.tscn")


func _on_litter_box_dirty_button_up() -> void:
	pass


func _on_litter_box_clean_button_up() -> void:
	pass


func _on_litter_box_dirty_button_down() -> void:
	pass # Replace with function body.


func _on_litter_box_clean_button_down() -> void:
	if Global.bladder > 25 and Global.bladder < 75:
		relieve_cat()
