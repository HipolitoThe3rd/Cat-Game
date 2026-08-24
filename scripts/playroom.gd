class_name Playroom
extends Node2D

@onready var fn_bar = $UI/FunBar
@onready var cat = $Cat

## Default functions
func _ready() -> void:
	#set cursor
	if Global.web_version:
		Input.set_custom_mouse_cursor(Global.smcursor_laser)
	else:
		Input.set_custom_mouse_cursor(Global.cursor_laser)

func _process(_delta: float) -> void:
	update_fun_bar()
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			#print("Left mouse button is being held down!")
		if Global.web_version:
			Global.set_cursor(Global.smcursor_laser_pressed)
		else:
			Input.set_custom_mouse_cursor(Global.cursor_laser_pressed)
			#if $Audio/ShowerToggle.playing == false and $Audio/ShowerRun.playing == false:
				#$Audio/ShowerRun.play()
				#pass
	else:
		if Global.web_version:
			Global.set_cursor(Global.smcursor_laser)
		else:
			Input.set_custom_mouse_cursor(Global.cursor_laser)

## Custom functions
func update_fun_bar() -> void:
	fn_bar.value = Global.entertainment
	if fn_bar.value < 25:
		fn_bar.modulate = Color(1, 0, 0) # red for low values
	elif fn_bar.value > 75:
		fn_bar.modulate = Color(0, 1, 0) # green for high values
	else:
		fn_bar.modulate = Color(0.333, 0.333, 0.333) # gray for neutral range
		
		
## Signals
func _on_back_button_button_down() -> void:
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
