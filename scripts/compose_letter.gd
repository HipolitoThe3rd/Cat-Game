### "Write a letter" popup for sending mail to another player.
### Built entirely in code so it needs no scene file; inbox.gd adds one of these
### from its Write and Reply buttons.
class_name ComposeLetter
extends CanvasLayer

# Same limits the mail server enforces (mail-api.mjs on the website), so the
# player finds out here rather than after pressing Send.
const MAX_SUBJECT := 80
const MAX_BODY := 1000
const CODE_LENGTH := 9 # "ABCD-EFGH"
const CLOSE_DELAY := 1.2 # seconds the "Sent!" message shows before closing

const COLOR_ERROR := Color(0.95, 0.5, 0.45)
const COLOR_OK := Color(0.4, 0.85, 0.4)
const COLOR_HINT := Color(0.7, 0.7, 0.7)

var _to_code: String
var _subject: String

var _code_label: Label
var _copy_button: Button
var _to_edit: LineEdit
var _subject_edit: LineEdit
var _body_edit: TextEdit
var _count_label: Label
var _status_label: Label
var _send_button: Button
var _cancel_button: Button


## Pass a friend code and subject to start a reply.
func _init(to_code: String = "", subject: String = "") -> void:
	_to_code = to_code
	_subject = subject
	layer = 10


func _ready() -> void:
	# Swallows clicks so the inbox behind the popup cannot be pressed through it.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# Solid, unlike the default theme's see-through panel, so the envelope art
	# behind it does not show through the letter.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.2, 0.25)
	style.border_color = Color(0.35, 0.5, 0.58)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	_build_contents(box)
	_update_friend_code()
	MailClient.registered.connect(_update_friend_code)

	if _to_code.is_empty():
		_to_edit.grab_focus()
	else:
		_body_edit.grab_focus()


func _build_contents(box: VBoxContainer) -> void:
	var title := Label.new()
	title.text = "Write a letter"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	# Your own code, so you can tell friends where to write back.
	var code_row := HBoxContainer.new()
	code_row.alignment = BoxContainer.ALIGNMENT_CENTER
	code_row.add_theme_constant_override("separation", 12)
	_code_label = Label.new()
	_code_label.add_theme_font_size_override("font_size", 18)
	code_row.add_child(_code_label)
	_copy_button = Button.new()
	_copy_button.text = "Copy"
	_copy_button.pressed.connect(_on_copy_pressed)
	code_row.add_child(_copy_button)
	box.add_child(code_row)

	box.add_child(HSeparator.new())

	_to_edit = LineEdit.new()
	_to_edit.placeholder_text = "Friend code, like ABCD-EFGH"
	_to_edit.max_length = CODE_LENGTH
	_to_edit.text = _to_code
	_to_edit.text_changed.connect(_on_text_changed)
	box.add_child(_labeled("To:", _to_edit))

	_subject_edit = LineEdit.new()
	_subject_edit.placeholder_text = "What's it about?"
	_subject_edit.max_length = MAX_SUBJECT
	_subject_edit.text = _subject
	box.add_child(_labeled("Subject:", _subject_edit))

	_body_edit = TextEdit.new()
	_body_edit.placeholder_text = "Write your letter here..."
	_body_edit.custom_minimum_size = Vector2(0, 220)
	_body_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_body_edit.text_changed.connect(_on_body_changed)
	box.add_child(_body_edit)

	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.add_theme_color_override("font_color", COLOR_HINT)
	box.add_child(_count_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.add_theme_font_size_override("font_size", 22)
	_cancel_button.pressed.connect(queue_free)
	buttons.add_child(_cancel_button)
	_send_button = Button.new()
	_send_button.text = "Send"
	_send_button.add_theme_font_size_override("font_size", 22)
	_send_button.pressed.connect(_on_send_pressed)
	buttons.add_child(_send_button)
	box.add_child(buttons)

	_on_body_changed()


func _labeled(text: String, field: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(90, 0)
	label.add_theme_font_size_override("font_size", 18)
	row.add_child(label)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	return row


func _update_friend_code() -> void:
	if MailClient.is_registered():
		_code_label.text = "Your friend code: %s" % MailClient.friend_code
		_copy_button.visible = true
	else:
		_code_label.text = "Getting your friend code... (needs internet)"
		_copy_button.visible = false
	_update_send_button()


func _update_send_button() -> void:
	_send_button.disabled = (not MailClient.is_registered()
		or _to_edit.text.strip_edges().is_empty()
		or _body_edit.text.strip_edges().is_empty())


func _set_status(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


## SIGNALS
func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(MailClient.friend_code)
	_set_status("Friend code copied!", COLOR_OK)


func _on_text_changed(_new_text: String) -> void:
	_update_send_button()


func _on_body_changed() -> void:
	# TextEdit has no max_length, so trim anything typed or pasted past it.
	if _body_edit.text.length() > MAX_BODY:
		var caret_line := _body_edit.get_caret_line()
		var caret_column := _body_edit.get_caret_column()
		_body_edit.text = _body_edit.text.left(MAX_BODY)
		_body_edit.set_caret_line(caret_line)
		_body_edit.set_caret_column(caret_column)
	var length := _body_edit.text.length()
	_count_label.text = "%d / %d" % [length, MAX_BODY]
	_count_label.add_theme_color_override("font_color",
		COLOR_ERROR if length >= MAX_BODY else COLOR_HINT)
	_update_send_button()


func _on_send_pressed() -> void:
	_send_button.disabled = true
	_cancel_button.disabled = true
	_set_status("Sending...", COLOR_HINT)

	var error: String = await MailClient.send(_to_edit.text.strip_edges(),
		_subject_edit.text.strip_edges(), _body_edit.text)
	if not is_inside_tree():
		return

	_cancel_button.disabled = false
	if not error.is_empty():
		_set_status(error, COLOR_ERROR)
		_update_send_button()
		return

	_set_status("Letter sent!", COLOR_OK)
	await get_tree().create_timer(CLOSE_DELAY).timeout
	if is_inside_tree():
		queue_free()
