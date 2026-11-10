### The office PC: a home screen with the account login and the online store.
### Built in code like WelcomeBack; office.gd adds one when the PC is clicked.
class_name OfficeComputer
extends CanvasLayer

const COLOR_SCREEN := Color(0.13, 0.2, 0.25)
const COLOR_BORDER := Color(0.35, 0.5, 0.58)
const COLOR_GOLD := Color(1.0, 0.84, 0.3)
const COLOR_ERROR := Color(0.95, 0.5, 0.45)
const COLOR_OK := Color(0.4, 0.85, 0.4)
const COLOR_HINT := Color(0.7, 0.7, 0.7)
const FOOD_BAG_ICON := "res://sprites/mood_icons/hunger.png"

var _panel: PanelContainer
var _title: Label
var _wallet: Label
var _home_button: Button
var _content: MarginContainer # holds whichever screen is showing
var _status: Label
var _patterns_grid: GridContainer
var _food_status: Label
var _food_button: Button


func _init() -> void:
	layer = 10


func _ready() -> void:
	# Swallows clicks so the office behind the screen cannot be pressed through it.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SCREEN
	style.border_color = COLOR_BORDER
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(960, 560)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	# Title bar: [< Home]  Title  ...  Kitcoins  [Close]
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	box.add_child(bar)
	_home_button = _button("< Home", 18, _show_home)
	bar.add_child(_home_button)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 28)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_title)
	_wallet = Label.new()
	_wallet.add_theme_font_size_override("font_size", 22)
	_wallet.add_theme_color_override("font_color", COLOR_GOLD)
	bar.add_child(_wallet)
	bar.add_child(_button("Close", 18, queue_free))

	box.add_child(HSeparator.new())

	_content = MarginContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_content)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 18)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)

	_show_home()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _panel.visible:
		queue_free()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_wallet.text = "%d Kitcoins" % Global.kitcoins
	_refresh_food_bag()


## ---------------------------------------------------------------------------
## Screens
## ---------------------------------------------------------------------------

func _show_screen(title: String, screen: Control, show_home_button: bool) -> void:
	for child in _content.get_children():
		child.queue_free()
	_title.text = title
	_home_button.visible = show_home_button
	_status.text = ""
	_content.add_child(screen)


func _show_home() -> void:
	var apps := HBoxContainer.new()
	apps.alignment = BoxContainer.ALIGNMENT_CENTER
	apps.add_theme_constant_override("separation", 48)
	apps.add_child(_app_button("Account", "Log in to save your progress\nand get your friend code", _show_account))
	apps.add_child(_app_button("Online Store", "Letter designs and\nsupplies for Crispy", _show_store))
	_show_screen("Desktop", apps, false)


func _app_button(label: String, blurb: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = "%s\n\n%s" % [label, blurb]
	button.custom_minimum_size = Vector2(320, 220)
	button.add_theme_font_size_override("font_size", 22)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	return button


## The login panel is its own overlay; the PC hides while it is up.
func _show_account() -> void:
	var account := AccountPanel.new()
	account.layer = layer + 1
	account.on_close = func():
		account.queue_free()
		_panel.visible = true
	_panel.visible = false
	add_child(account)


func _show_store() -> void:
	var tabs := TabContainer.new()
	tabs.add_theme_font_size_override("font_size", 20)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var patterns := ScrollContainer.new()
	patterns.name = "Mail Patterns"
	patterns.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_patterns_grid = GridContainer.new()
	_patterns_grid.columns = 3
	_patterns_grid.add_theme_constant_override("h_separation", 20)
	_patterns_grid.add_theme_constant_override("v_separation", 20)
	_patterns_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	patterns.add_child(_patterns_grid)
	tabs.add_child(patterns)

	var supplies := ScrollContainer.new()
	supplies.name = "Supplies"
	supplies.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	list.add_child(_food_bag_card())
	supplies.add_child(list)
	tabs.add_child(supplies)

	_show_screen("Online Store", tabs, true)
	_fill_patterns()
	_refresh_food_bag()


## ---------------------------------------------------------------------------
## Store: mail patterns
## ---------------------------------------------------------------------------

func _fill_patterns() -> void:
	for child in _patterns_grid.get_children():
		child.queue_free()
	for id in Global.MAIL_PATTERNS:
		_patterns_grid.add_child(_pattern_card(id))


func _pattern_card(id: String) -> Control:
	var info: Dictionary = Global.MAIL_PATTERNS[id]
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 6)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var preview := TextureRect.new()
	preview.texture = Global.mail_pattern_texture(id)
	preview.custom_minimum_size = Vector2(272, 153)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.add_child(preview)

	var name_label := Label.new()
	name_label.text = str(info.name)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_label)

	var price := int(info.price)
	var button: Button
	if Global.mail_pattern == id:
		button = _button("In use", 16, Callable())
		button.disabled = true
	elif Global.owns_mail_pattern(id):
		button = _button("Use", 16, _use_pattern.bind(id))
	else:
		button = _button("Buy - %d Kitcoins" % price, 16, _buy_pattern.bind(id))
	card.add_child(button)
	return card


func _buy_pattern(id: String) -> void:
	var info: Dictionary = Global.MAIL_PATTERNS[id]
	if Global.kitcoins < int(info.price):
		_say("You need %d more Kitcoins for %s." % [int(info.price) - Global.kitcoins, info.name], COLOR_ERROR)
		return
	if Global.buy_mail_pattern(id):
		Global.set_mail_pattern(id)
		_say("Bought %s! Your letters will use it." % info.name, COLOR_OK)
	_fill_patterns()


func _use_pattern(id: String) -> void:
	Global.set_mail_pattern(id)
	_say("Your letters will use %s." % Global.MAIL_PATTERNS[id].name, COLOR_OK)
	_fill_patterns()


## ---------------------------------------------------------------------------
## Store: supplies
## ---------------------------------------------------------------------------

func _food_bag_card() -> Control:
	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 20)

	var icon := TextureRect.new()
	if ResourceLoader.exists(FOOD_BAG_ICON):
		icon.texture = load(FOOD_BAG_ICON)
	icon.custom_minimum_size = Vector2(96, 96)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.add_child(icon)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(text)
	var title := Label.new()
	title.text = "Food Bag"
	title.add_theme_font_size_override("font_size", 24)
	text.add_child(title)
	var blurb := Label.new()
	blurb.text = ("Crispy feeds himself for a week: his Hunger won't drop below %d. "
		+ "Buying another while one is open adds another week.") % int(Global.FOOD_BAG_MIN_HUNGER)
	blurb.add_theme_font_size_override("font_size", 16)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(blurb)
	_food_status = Label.new()
	_food_status.add_theme_font_size_override("font_size", 16)
	text.add_child(_food_status)

	_food_button = _button("Buy - %d Kitcoins" % Global.FOOD_BAG_PRICE, 18, _buy_food_bag)
	_food_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.add_child(_food_button)
	return card


func _refresh_food_bag() -> void:
	# Freed along with the store screen when another screen is shown.
	if _food_status == null or not is_instance_valid(_food_status) or _food_status.is_queued_for_deletion():
		return
	if Global.food_bag_active():
		_food_status.text = "Open: %s left." % _format_time_left(Global.food_bag_seconds_left())
		_food_status.add_theme_color_override("font_color", COLOR_OK)
	else:
		_food_status.text = "Not in use."
		_food_status.add_theme_color_override("font_color", COLOR_HINT)


func _buy_food_bag() -> void:
	if Global.kitcoins < Global.FOOD_BAG_PRICE:
		_say("You need %d more Kitcoins for a Food Bag." % (Global.FOOD_BAG_PRICE - Global.kitcoins), COLOR_ERROR)
		return
	if Global.buy_food_bag():
		_say("Food Bag opened! Crispy won't go hungry this week.", COLOR_OK)
	_refresh_food_bag()


static func _format_time_left(seconds: float) -> String:
	var hours := int(ceil(seconds / 3600.0))
	if hours >= 24:
		var days := hours / 24
		var rest := hours % 24
		return "%d day%s%s" % [days, "" if days == 1 else "s",
			"" if rest == 0 else ", %d hour%s" % [rest, "" if rest == 1 else "s"]]
	return "%d hour%s" % [hours, "" if hours == 1 else "s"]


## ---------------------------------------------------------------------------
## Helpers
## ---------------------------------------------------------------------------

func _button(text: String, font_size: int, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	if action.is_valid():
		button.pressed.connect(action)
	return button


func _say(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)
