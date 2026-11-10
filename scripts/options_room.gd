## Options: sound, window and update settings. The controls are built in code;
## the values live in the Settings autoload (settings.gd).
class_name OptionsRoom
extends Node2D

const BACKGROUND := Color(0.16, 0.2, 0.26)

var _volume_slider: HSlider
var _volume_value: Label
var _mute: CheckButton
var _fullscreen: CheckButton
var _vsync: CheckButton
var _updates: CheckButton


# DEFAULT FUNCTIONS
func _ready() -> void:
	if Global.web_version:
		Input.set_custom_mouse_cursor(Global.smcursor_default)
	else:
		Input.set_custom_mouse_cursor(Global.cursor_default)

	# Behind everything in the scene, including the Back button.
	var ui := CanvasLayer.new()
	ui.layer = -1
	add_child(ui)
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# On its own layer so it can fill (and center on) the screen; a Control
	# under a Node2D has nothing to stretch to.
	var front := CanvasLayer.new()
	front.add_child(center)
	add_child(front)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.2, 0.25)
	style.border_color = Color(0.35, 0.5, 0.58)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Options"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(HSeparator.new())

	# Sound
	var volume_row := _row(box, "Volume")
	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0
	_volume_slider.max_value = 100
	_volume_slider.step = 1
	_volume_slider.custom_minimum_size = Vector2(260, 0)
	_volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_volume_slider.value_changed.connect(func(value):
		Settings.change("master_volume", value / 100.0)
		_volume_value.text = "%d%%" % value)
	volume_row.add_child(_volume_slider)
	_volume_value = Label.new()
	_volume_value.custom_minimum_size = Vector2(60, 0)
	_volume_value.add_theme_font_size_override("font_size", 20)
	_volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	volume_row.add_child(_volume_value)

	_mute = _toggle(box, "Mute all sound", "muted")

	# Window (desktop downloads only)
	if Settings.is_desktop():
		_fullscreen = _toggle(box, "Fullscreen", "fullscreen")
		_vsync = _toggle(box, "V-Sync", "vsync")
	# Updates (downloaded builds only; the web version is always the latest)
	if not OS.has_feature("web"):
		_updates = _toggle(box, "Check for updates at startup", "check_updates")

	box.add_child(HSeparator.new())
	var reset := Button.new()
	reset.text = "Reset to defaults"
	reset.add_theme_font_size_override("font_size", 20)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(func():
		Settings.reset_to_defaults()
		_refresh())
	box.add_child(reset)

	var version := Label.new()
	var game_version := str(ProjectSettings.get_setting("application/config/version", ""))
	version.text = "Version %s" % game_version if not game_version.is_empty() else ""
	version.add_theme_font_size_override("font_size", 14)
	version.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(version)

	_refresh()


# CUSTOM FUNCTIONS
func _row(box: VBoxContainer, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 20)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


func _toggle(box: VBoxContainer, label_text: String, key: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(func(on): Settings.change(key, on))
	_row(box, label_text).add_child(toggle)
	return toggle


## Shows the current settings without triggering the change handlers.
func _refresh() -> void:
	_volume_slider.set_value_no_signal(roundf(Settings.master_volume * 100.0))
	_volume_value.text = "%d%%" % roundi(Settings.master_volume * 100.0)
	_mute.set_pressed_no_signal(Settings.muted)
	if _fullscreen != null:
		_fullscreen.set_pressed_no_signal(Settings.fullscreen)
		_vsync.set_pressed_no_signal(Settings.vsync)
	if _updates != null:
		_updates.set_pressed_no_signal(Settings.check_updates)


# SIGNALS
func _on_back_button_button_down() -> void:
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
