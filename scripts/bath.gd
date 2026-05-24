extends Node2D

@onready var sh_hitbox = $ShowerheadHitbox

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.set_custom_mouse_cursor(Global.cursor_shower)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		#print("Left mouse button is being held down!")
		Input.set_custom_mouse_cursor(Global.cursor_shower_pour)
		sh_hitbox.global_position = get_viewport().get_mouse_position()
	else:
		Input.set_custom_mouse_cursor(Global.cursor_shower)
