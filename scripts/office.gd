## The office: where the player logs in to their account, for now.
extends Node2D

const BACKGROUND := Color(0.22745098, 0.39215687, 0.4745098, 1)


func _ready() -> void:
	if Global.web_version:
		Input.set_custom_mouse_cursor(Global.smcursor_default)
	else:
		Input.set_custom_mouse_cursor(Global.cursor_default)

	# Placeholder until the office has art of its own.
	var ui := CanvasLayer.new()
	add_child(ui)
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(background)
	var back := Button.new()
	back.text = "Back"
	back.add_theme_font_size_override("font_size", 22)
	back.position = Vector2(20, 20)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub.tscn"))
	ui.add_child(back)

	add_child(AccountPanel.new())
