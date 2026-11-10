### "A new version is out" popup, shown by UpdateChecker.
### Built in code like WelcomeBack, and drawn above it if both appear at once.
class_name UpdateNotice
extends CanvasLayer

var _current: String
var _latest: String
var _url: String


func _init(current: String = "", latest: String = "", url: String = "") -> void:
	_current = current
	_latest = latest
	_url = url
	layer = 11


func _ready() -> void:
	# Swallows clicks so the doors behind the popup cannot be pressed through it.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Update available!"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var body := Label.new()
	body.text = "A new version of Crispy the Cat is out.\nYou have %s - the latest is %s." % [_current, _latest]
	body.add_theme_font_size_override("font_size", 20)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)

	box.add_child(HSeparator.new())

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)

	var later := Button.new()
	later.text = "Later"
	later.add_theme_font_size_override("font_size", 22)
	later.pressed.connect(queue_free)
	buttons.add_child(later)

	var get_it := Button.new()
	get_it.text = "Get the update"
	get_it.add_theme_font_size_override("font_size", 22)
	get_it.pressed.connect(_on_get_update)
	buttons.add_child(get_it)
	get_it.grab_focus()


func _on_get_update() -> void:
	OS.shell_open(_url)
	queue_free()
