extends Node2D

@onready var sh_hitbox = $ShowerheadHitbox
@onready var pb_hungerbar = $HungerBar
@onready var fish_bucket = $FishBucket
@onready var fish_prefab = preload("res://scenes/prefabs/fish.tscn")

var fish

func _ready() -> void:
	Input.set_custom_mouse_cursor(Global.cursor_default)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Global.hunger >= 100:
		pass
	else:
		pass
	pb_hungerbar.value = Global.cleanliness
	if pb_hungerbar.value < 25:
		pb_hungerbar.modulate = Color(1, 0, 0) # red for low values
	elif pb_hungerbar.value > 75:
		pb_hungerbar.modulate = Color(0, 1, 0) # green for high values
	else:
		pb_hungerbar.modulate = Color(0.333, 0.333, 0.333) # gray for neutral range

func _on_fish_bucket_button_down() -> void:
	Input.set_custom_mouse_cursor(Global.cursor_pet)
	if is_instance_valid(fish):
		return
	fish = fish_prefab.instantiate()
	add_child(fish)
	fish.start_drag(get_global_mouse_position())

func _on_fish_bucket_button_up() -> void:
	Input.set_custom_mouse_cursor(Global.cursor_default)

func _on_back_button_button_down() -> void:
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
