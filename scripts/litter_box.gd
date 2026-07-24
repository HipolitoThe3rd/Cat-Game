extends Node2D

@onready var sc_hitbox = $ScooperHitbox
@onready var spawn_area = $SpawnArea # a Poop prefab will randomly spawn somewhere in this area
@onready var poop_prefab = load("res://scenes/prefabs/poop.tscn")

func _ready() -> void:
	#set cursor
	if Global.web_version:
		Input.set_custom_mouse_cursor(Global.smcursor_scooper)
	else:
		Input.set_custom_mouse_cursor(Global.cursor_scooper)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Global.cleanliness >= 100:
		# set cursor to default as showerhead is no longer needed
		if Global.web_version:
			Global.set_cursor(Global.smcursor_default)
		else:
			Input.set_custom_mouse_cursor(Global.cursor_default)
		if $Audio/ShowerRun.playing == true:
			$Audio/ShowerRun.stop()
	else:
		sc_hitbox.global_position = get_viewport().get_mouse_position()
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			#print("Left mouse button is being held down!")
			if Global.web_version:
				Global.set_cursor(Global.smcursor_scooper_pressed)
			else:
				Input.set_custom_mouse_cursor(Global.cursor_scooper_pressed)
			#if $Audio/ShowerToggle.playing == false and $Audio/ShowerRun.playing == false:
				#$Audio/ShowerRun.play()
				#pass
		else:
			if Global.web_version:
				Global.set_cursor(Global.smcursor_scooper)
			else:
				Input.set_custom_mouse_cursor(Global.cursor_scooper)
			#if $Audio/ShowerRun.playing == true:
			#	$Audio/ShowerRun.stop()

func _on_back_button_button_down() -> void:
	get_tree().change_scene_to_file("res://scenes/litter_room.tscn")
