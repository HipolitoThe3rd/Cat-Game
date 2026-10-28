### Login panel: "Log in with Discord", the code to check, and who is logged in.
### Built entirely in code so it needs no scene file; the office adds one, and
### any other room can too with add_child(AccountPanel.new()).
class_name AccountPanel
extends CanvasLayer

const COLOR_ERROR := Color(0.95, 0.5, 0.45)
const COLOR_OK := Color(0.4, 0.85, 0.4)
const COLOR_HINT := Color(0.7, 0.7, 0.7)
const DISCORD_BLURPLE := Color(0.345, 0.396, 0.949)

var _avatar: TextureRect
var _title: Label
var _info: Label
var _code: Label
var _status: Label
var _main_button: Button
var _second_button: Button
var _avatar_url_shown := ""


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.2, 0.25)
	style.border_color = Color(0.35, 0.5, 0.58)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	_avatar = TextureRect.new()
	_avatar.custom_minimum_size = Vector2(96, 96)
	_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_avatar)

	_title = _label(box, 28)
	_info = _label(box, 18)
	_code = _label(box, 44)
	_status = _label(box, 16)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	box.add_child(buttons)
	_main_button = Button.new()
	_main_button.add_theme_font_size_override("font_size", 22)
	_main_button.pressed.connect(_on_main_pressed)
	buttons.add_child(_main_button)
	_second_button = Button.new()
	_second_button.add_theme_font_size_override("font_size", 22)
	_second_button.pressed.connect(_on_second_pressed)
	buttons.add_child(_second_button)

	Account.changed.connect(_refresh)
	MailClient.registered.connect(_refresh)
	_refresh()
	# Opening the panel is when a new backer would look for their perks.
	Account.refresh_supporter(true)


func _label(box: VBoxContainer, font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	box.add_child(label)
	return label


func _refresh() -> void:
	_status.remove_theme_color_override("font_color")
	_code.visible = false
	_avatar.visible = false
	_second_button.visible = false
	_main_button.disabled = false
	_main_button.remove_theme_color_override("font_color")
	_main_button.remove_theme_stylebox_override("normal")

	if Account.is_logged_in():
		_title.text = "Logged in as %s" % Account.display_name
		_info.text = ("@%s\n\nYour progress, letters and friend code are saved to your account, "
			% Account.username + "so you can pick them up on any device.")
		_code.text = _supporter_text()
		_code.add_theme_font_size_override("font_size", 22)
		_code.add_theme_color_override("font_color",
			Account.tier_color() if Account.is_supporter() else COLOR_HINT)
		_code.visible = true
		_status.text = ("Friend code: %s" % MailClient.friend_code) if MailClient.is_registered() else ""
		_status.add_theme_color_override("font_color", COLOR_HINT)
		_main_button.text = "Save now"
		_second_button.text = "Log out"
		_second_button.visible = true
		_show_avatar(Account.avatar_url)
	elif Account.is_logging_in():
		_title.text = "Log in with Discord"
		_info.text = "Your login page will show this code. Only continue if it matches:"
		_code.text = Account.login_code
		_code.add_theme_font_size_override("font_size", 44)
		_code.remove_theme_color_override("font_color")
		_code.visible = true
		_status.text = "Waiting for you to log in..."
		_status.add_theme_color_override("font_color", COLOR_HINT)
		_main_button.text = "Open login page"
		_second_button.text = "Cancel"
		_second_button.visible = true
	else:
		_title.text = "Your account"
		_info.text = ("Log in with Discord to keep your progress, letters and friend code "
			+ "on every device you play on.\n\nWithout logging in, this device keeps its own save.")
		_status.text = Account.login_error
		_status.add_theme_color_override("font_color", COLOR_ERROR)
		_main_button.text = "Log in with Discord"
		var blurple := StyleBoxFlat.new()
		blurple.bg_color = DISCORD_BLURPLE
		blurple.set_corner_radius_all(8)
		blurple.set_content_margin_all(10)
		_main_button.add_theme_stylebox_override("normal", blurple)
		_main_button.add_theme_color_override("font_color", Color.WHITE)


func _supporter_text() -> String:
	if Account.is_supporter():
		return "%s supporter - thank you!" % Account.tier_name()
	if not Account.in_discord_server:
		return "Join our Discord server to get supporter perks when you back us."
	return "Back us on Ko-fi, Patreon or SubscribeStar for supporter perks!"


func _show_avatar(url: String) -> void:
	_avatar.visible = _avatar.texture != null
	if url.is_empty() or url == _avatar_url_shown:
		return
	_avatar_url_shown = url
	var http := HTTPRequest.new()
	add_child(http)
	if http.request(url) != OK:
		http.queue_free()
		return
	var result: Array = await http.request_completed
	http.queue_free()
	var image := Image.new()
	if result[1] == 200 and image.load_png_from_buffer(result[3]) == OK:
		_avatar.texture = ImageTexture.create_from_image(image)
		_avatar.visible = Account.is_logged_in()


func _on_main_pressed() -> void:
	if Account.is_logged_in():
		_main_button.disabled = true
		_status.text = "Saving..."
		await Account.sync_now()
		if is_inside_tree():
			_main_button.disabled = false
			_status.text = "Saved!"
			_status.add_theme_color_override("font_color", COLOR_OK)
	elif Account.is_logging_in():
		Account.open_login_page()
	else:
		_main_button.disabled = true
		_status.text = "Connecting..."
		_status.remove_theme_color_override("font_color")
		await Account.start_login()
		if is_inside_tree():
			_refresh()


func _on_second_pressed() -> void:
	if Account.is_logging_in():
		Account.cancel_login()
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Log out?"
	dialog.dialog_text = ("Your progress stays saved to your account. "
		+ "This device goes back to its own save.")
	dialog.dialog_autowrap = true
	dialog.ok_button_text = "Log out"
	dialog.confirmed.connect(Account.logout)
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			dialog.queue_free.call_deferred())
	add_child(dialog)
	dialog.popup_centered(Vector2i(460, 0))
