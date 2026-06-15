extends Node2D

@onready var sh_hitbox = $ShowerheadHitbox
@onready var pb_cleanbar = $CleanlinessBar
#@onready var sfx_water = $SFX/WaterSound

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.set_custom_mouse_cursor(Global.cursor_shower)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Global.cleanliness >= 100:
		# set cursor to default as showerhead is no longer needed
		Input.set_custom_mouse_cursor(null)
		if $Audio/ShowerRun.playing == true:
			$Audio/ShowerRun.stop()
	else:
		sh_hitbox.global_position = get_viewport().get_mouse_position()
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			#print("Left mouse button is being held down!")
			Input.set_custom_mouse_cursor(Global.cursor_shower_pour)
			if $Audio/ShowerToggle.playing == false and $Audio/ShowerRun.playing == false:
				$Audio/ShowerRun.play()
		else:
			Input.set_custom_mouse_cursor(Global.cursor_shower)
			if $Audio/ShowerRun.playing == true:
				$Audio/ShowerRun.stop()
	pb_cleanbar.value = Global.cleanliness
	if pb_cleanbar.value < 25:
		pb_cleanbar.modulate = Color(1, 0, 0) # red for low values
	elif pb_cleanbar.value > 75:
		pb_cleanbar.modulate = Color(0, 1, 0) # green for high values
	else:
		pb_cleanbar.modulate = Color(0.333, 0.333, 0.333) # gray for neutral range

func _input(event):
	# Check if the event is a mouse button click
	if event is InputEventMouseButton and (event.pressed or event.is_released()):
		if event.button_index == MOUSE_BUTTON_LEFT and Global.cleanliness < 100:
			#print("Left mouse button just pressed/released!")
			$Audio/ShowerToggle.play()

func _on_back_button_button_down() -> void:
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
