### "While you were away..." popup.
### Built entirely in code so it needs no scene file; hub.gd adds one of these
### when Global.offline_summary says real time passed since the last session.
class_name WelcomeBack
extends CanvasLayer

# Rows are only listed if the stat actually moved, so a short absence shows a
# short popup. Each entry is [icon name, label, summary key, is_a_gain].
const ROWS := [
	["hunger", "Hungrier", "hunger_lost", false],
	["hygiene", "Grubbier", "cleanliness_lost", false],
	["fun", "Bored", "entertainment_lost", false],
	["love", "Missed you", "affection_lost", false],
	["energy", "Well rested", "energy_gained", true],
]

# Changes smaller than this are not worth a line of their own.
const MIN_INTERESTING_CHANGE := 0.5

const ICON_DIR := "res://sprites/mood_icons/%s.png"
const ICON_SIZE := Vector2(30, 30)

var _summary: Dictionary


func _init(summary: Dictionary = {}) -> void:
	_summary = summary
	layer = 10


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

	_build_contents(box)


func _build_contents(box: VBoxContainer) -> void:
	var title := Label.new()
	title.text = "Welcome back!"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "You were gone for %s." % _format_duration(
		float(_summary.get("hours_away", 0.0)),
		bool(_summary.get("was_capped", false)))
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	box.add_child(HSeparator.new())

	var listed := 0
	for row in ROWS:
		var amount := absf(float(_summary.get(row[2], 0.0)))
		if amount < MIN_INTERESTING_CHANGE:
			continue
		box.add_child(_build_row(row[0], row[1], amount, row[3]))
		listed += 1

	if listed == 0:
		var nothing := Label.new()
		nothing.text = "Your cat barely noticed."
		nothing.add_theme_font_size_override("font_size", 20)
		nothing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(nothing)

	var accidents := int(_summary.get("accidents", 0))
	if accidents > 0:
		var oops := Label.new()
		oops.text = ("Uh oh - there was an accident while you were out."
			if accidents == 1
			else "Uh oh - there were %d accidents while you were out." % accidents)
		oops.add_theme_font_size_override("font_size", 18)
		oops.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		oops.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(oops)

	box.add_child(HSeparator.new())

	var button := Button.new()
	button.text = "I'm back!"
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(_on_dismiss)
	box.add_child(button)
	button.grab_focus()


func _build_row(icon_name: String, label_text: String, amount: float, is_gain: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var icon_path := ICON_DIR % icon_name
	if ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.custom_minimum_size = ICON_SIZE
		# The source art is a few hundred pixels wide, so ignore its size and
		# letterbox it into the small square above.
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var value := Label.new()
	value.text = ("+%d" % roundi(amount)) if is_gain else ("-%d" % roundi(amount))
	value.add_theme_font_size_override("font_size", 20)
	value.add_theme_color_override("font_color",
		Color(0.4, 0.85, 0.4) if is_gain else Color(0.95, 0.5, 0.45))
	row.add_child(value)

	return row


## Turns hours into something a child reads rather than "10.4h".
func _format_duration(hours: float, capped: bool) -> String:
	if capped:
		return "a long time"
	if hours < 1.0:
		return "%d minutes" % maxi(roundi(hours * 60.0), 1)
	if hours < 2.0:
		return "about an hour"
	if hours < 24.0:
		return "%d hours" % roundi(hours)
	if hours < 48.0:
		return "about a day"
	return "%d days" % roundi(hours / 24.0)


func _on_dismiss() -> void:
	queue_free()
