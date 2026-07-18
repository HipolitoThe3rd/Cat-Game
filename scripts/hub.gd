extends Node2D

@onready var pb_moodbar = $Control/MoodBar
@onready var pb_hungerbar = $Control/HungerBar
@onready var pb_energybar = $Control/EnergyBar
@onready var pb_cleanbar = $Control/CleanlinessBar
@onready var pb_funbar = $Control/EntertainmentBar
@onready var pb_lovebar = $Control/AffectionBar
@onready var pb_bladderbar = $Control/BladderBar

var room_kitchen = "res://scenes/kitchen.tscn"
var room_bath = "res://scenes/bath.tscn"

func _ready() -> void:
	if Global.web_version:
		Input.set_custom_mouse_cursor(Global.smcursor_default)
	else:
		Input.set_custom_mouse_cursor(Global.cursor_default)

func  _process(_delta: float) -> void:
	#print("Cat's mood: ", Global.mood)
	pb_moodbar.value = Global.mood
	if pb_moodbar.value < 25:
		pb_moodbar.modulate = Color(0, 0, 1) # blue for low values
	elif pb_moodbar.value > 75:
		pb_moodbar.modulate = Color(1, 1, 0) # yellow for high values
	else:
		pb_moodbar.modulate = Color(0.333, 0.333, 0.333) # gray for neutral range
	pb_hungerbar.value = Global.hunger
	if pb_hungerbar.value < 25:
		pb_hungerbar.modulate = Color(1, 0, 0) # red for low values
	elif pb_hungerbar.value > 75:
		pb_hungerbar.modulate = Color(0, 1, 0) # green for high values
	else:
		pb_hungerbar.modulate = Color(0.333, 0.333, 0.333) # gray for neutral range
	pb_energybar.value = Global.energy
	if pb_energybar.value < 25:
		pb_energybar.modulate = Color(1, 0, 0) # red for low values
	elif pb_energybar.value > 75:
		pb_energybar.modulate = Color(0, 1, 0) # green for high values
	else:
		pb_energybar.modulate = Color(0.333, 0.333, 0.333) # gray for neutral range
	pb_cleanbar.value = Global.cleanliness
	if pb_cleanbar.value < 25:
		pb_cleanbar.modulate = Color(1, 0, 0) # red for low values
	elif pb_cleanbar.value > 75:
		pb_cleanbar.modulate = Color(0, 1, 0) # green for high values
	else:
		pb_cleanbar.modulate = Color(0.333, 0.333, 0.333) # gray for neutral range
	pb_funbar.value = Global.entertainment
	if pb_funbar.value < 25:
		pb_funbar.modulate = Color(1, 0, 0) # red for low values
	elif pb_funbar.value > 75:
		pb_funbar.modulate = Color(0, 1, 0) # green for high values
	else:
		pb_funbar.modulate = Color(0.333, 0.333, 0.333) # gray for neutral range
	pb_lovebar.value = Global.affection
	if pb_lovebar.value < 25:
		pb_lovebar.modulate = Color(1, 0, 0) # red for low values
	elif pb_lovebar.value > 75:
		pb_lovebar.modulate = Color(0, 1, 0) # green for high values
	else:
		pb_lovebar.modulate = Color(0.333, 0.333, 0.333) # gray for neutral range
	pb_bladderbar.value = Global.bladder
	if pb_bladderbar.value < 25:
		pb_bladderbar.modulate = Color(1, 0, 0) # red for low values
	elif pb_bladderbar.value > 75:
		pb_bladderbar.modulate = Color(0, 1, 0) # green for high values
	else:
		pb_bladderbar.modulate = Color(0.333, 0.333, 0.333) # gray for neutral range
	pass


func _on_cat_mouse_entered() -> void:
	#print("cursor entered cat")
	if Global.web_version:
		Input.set_custom_mouse_cursor(Global.smcursor_pet)
	else:
		Input.set_custom_mouse_cursor(Global.cursor_pet)

func _on_cat_mouse_exited() -> void:
	#print("cursor exited cat")
	if Global.web_version:
		Input.set_custom_mouse_cursor(Global.smcursor_default)
	else:
		Input.set_custom_mouse_cursor(Global.cursor_default)

func _on_door_1_pressed() -> void:
	get_tree().change_scene_to_file(room_kitchen)

func _on_door_2_pressed() -> void:
	get_tree().change_scene_to_file(room_bath)
