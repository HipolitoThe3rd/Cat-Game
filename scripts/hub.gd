extends Node2D

@onready var pb_moodbar = $Control/MoodBar
@onready var pb_hungerbar = $Control/HungerBar
@onready var pb_energybar = $Control/EnergyBar
@onready var pb_cleanbar = $Control/CleanlinessBar
@onready var pb_funbar = $Control/EntertainmentBar
@onready var pb_lovebar = $Control/AffectionBar
@onready var pb_bladderbar = $Control/BladderBar

var room_kitchen = "res://scenes/kitchen.tscn"
var room_bath = "res://scenes/bath.tscn"
var room_litter = "res://scenes/litter_room.tscn"
var room_bed = "res://scenes/bedroom.tscn"
var room_play = "res://scenes/playroom.tscn"
var room_secret = "res://scenes/secret_scene.tscn"
var room_inbox = "res://scenes/inbox.tscn"
var room_office = "res://scenes/office.tscn"
var room_options = "res://scenes/options_room.tscn"

# Hallway sections, left to right. Each is a full screen wide and laid out side
# by side in hub.tscn; moving between them slides the whole row.
const SECTIONS := ["HallwayLeft2", "HallwayLeft1", "HallwayStart", "HallwayRight1", "HallwayRight2"]
# The only sections the player can reach for now.
const OPEN_SECTIONS := ["HallwayLeft1", "HallwayStart"]

const EDGE_WIDTH := 40.0 # px at each side of the screen that switch sections
const SLIDE_TIME := 0.35
const SWIPE_COMMIT := 0.25 # fraction of the screen a swipe must cover to switch
const SWIPE_FLICK_SPEED := 900.0 # px/s; a quick flick switches even if short
const EDGE_TINT := Color(0.55, 0.85, 1.0, 0.75) # edge cursor: tinted and see-through

var _home_x := {} # section name -> its x while HallwayStart is on screen
var _section_width := 1152.0
var _current := "HallwayStart"
var _scroll := 0.0 # how far the row is slid; 0 shows HallwayStart
var _slide: Tween
var _hover_side := 0 # -1/1 while the mouse is over a usable edge, else 0
var _swipe_index := -1 # finger currently swiping, or -1
var _swipe_side := 0
var _swipe_start := Vector2.ZERO
var _swipe_velocity := 0.0
var _edge_glow := {} # side -> Control shown while that edge is hovered/swiped
var _edge_cursors := {} # default cursor texture -> its tinted edge version
var _delivery_check := 0.0
@onready var _cat: CharacterBody2D = $Cat
var _cat_section := "HallwayStart" # the section Crispy is in
var _cat_follows := true # decided when a move starts, from his mood then
var _cat_parked := false # true while he is off in another section
var _cat_parked_x := 0.0 # his x within his section while parked

## DEFAULT FUNCTIONS
func _ready() -> void:
	Global.inbox_via_mailbox = false
	if Global.web_version:
		Input.set_custom_mouse_cursor(Global.smcursor_default)
	else:
		Input.set_custom_mouse_cursor(Global.cursor_default)

	_setup_hallway()

	# When Crispy is in a good mood he brings new mail (a paycheck, say) to you
	# himself. Otherwise it waits in the office mailbox. Checked before the
	# welcome-back popup so that summary is kept for when we return here.
	if Global.crispy_has_mail_to_deliver():
		_go_to_inbox.call_deferred()
		return
	Global.mail_received.connect(_on_mail_received)

	# Only populated when load_game() measured real time away, so returning
	# from a minigame room will not re-trigger it. Cleared once shown.
	if not Global.offline_summary.is_empty():
		add_child(WelcomeBack.new(Global.offline_summary))
		Global.offline_summary = {}

func  _process(delta: float) -> void:
	#print("Cat's mood: ", Global.mood)
	_update_edge_hover()
	# Mail that arrived while Crispy was grumpy: he fetches it once he cheers up.
	_delivery_check -= delta
	if _delivery_check <= 0.0:
		_delivery_check = 1.0
		if Global.crispy_has_mail_to_deliver() and not _popup_open():
			_go_to_inbox()
	pb_moodbar.value = Global.mood
	if pb_moodbar.value < 25:
		pb_moodbar.modulate = Color(0, 0, 1) # blue for low values
	elif pb_moodbar.value > 75:
		pb_moodbar.modulate = Color(1, 1, 0) # yellow for high values
	else:
		pb_moodbar.modulate = Color(0.333, 0.333, 0.333) # gray for neutral range
	pb_hungerbar.value = Global.hunger
	if pb_hungerbar.value < 25:
		pb_hungerbar.modulate = Color(1, 0, 0) # red for low values
	elif pb_hungerbar.value > 75:
		pb_hungerbar.modulate = Color(0, 1, 0) # green for high values
	else:
		pb_hungerbar.modulate = Color(0.333, 0.333, 0.333) # gray for neutral range
	pb_energybar.value = Global.energy
	if pb_energybar.value < 25:
		pb_energybar.modulate = Color(1, 0, 0) # red for low values
	elif pb_energybar.value > 75:
		pb_energybar.modulate = Color(0, 1, 0) # green for high values
	else:
		pb_energybar.modulate = Color(0.333, 0.333, 0.333) # gray for neutral range
	pb_cleanbar.value = Global.cleanliness
	if pb_cleanbar.value < 25:
		pb_cleanbar.modulate = Color(1, 0, 0) # red for low values
	elif pb_cleanbar.value > 75:
		pb_cleanbar.modulate = Color(0, 1, 0) # green for high values
	else:
		pb_cleanbar.modulate = Color(0.333, 0.333, 0.333) # gray for neutral range
	pb_funbar.value = Global.entertainment
	if pb_funbar.value < 25:
		pb_funbar.modulate = Color(1, 0, 0) # red for low values
	elif pb_funbar.value > 75:
		pb_funbar.modulate = Color(0, 1, 0) # green for high values
	else:
		pb_funbar.modulate = Color(0.333, 0.333, 0.333) # gray for neutral range
	pb_lovebar.value = Global.affection
	if pb_lovebar.value < 25:
		pb_lovebar.modulate = Color(1, 0, 0) # red for low values
	elif pb_lovebar.value > 75:
		pb_lovebar.modulate = Color(0, 1, 0) # green for high values
	else:
		pb_lovebar.modulate = Color(0.333, 0.333, 0.333) # gray for neutral range
	pb_bladderbar.value = Global.bladder
	if pb_bladderbar.value < 25:
		pb_bladderbar.modulate = Color(1, 0, 0) # red for low values
	elif pb_bladderbar.value > 75:
		pb_bladderbar.modulate = Color(0, 1, 0) # green for high values
	else:
		pb_bladderbar.modulate = Color(0.333, 0.333, 0.333) # gray for neutral range
	pass

## SIGNALS
func _on_cat_mouse_entered() -> void:
	#print("cursor entered cat")
	if Global.web_version:
		if Global.mood >= 95:
			Input.set_custom_mouse_cursor(Global.smcursor_secret)
		else:
			Input.set_custom_mouse_cursor(Global.smcursor_pet)
	else:
		if Global.mood >= 95:
			Input.set_custom_mouse_cursor(Global.cursor_secret)
		else:
			Input.set_custom_mouse_cursor(Global.cursor_pet)

func _on_cat_mouse_exited() -> void:
	#print("cursor exited cat")
	if Global.web_version:
		Input.set_custom_mouse_cursor(Global.smcursor_default)
	else:
		Input.set_custom_mouse_cursor(Global.cursor_default)

func _on_cat_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Global.mood >= 95:
			get_tree().change_scene_to_file(room_secret)

func _on_mail_received(_letter: Dictionary) -> void:
	if Global.crispy_has_mail_to_deliver():
		_go_to_inbox.call_deferred()

func _go_to_inbox() -> void:
	get_tree().change_scene_to_file(room_inbox)

func _on_door_1_pressed() -> void:
	get_tree().change_scene_to_file(room_kitchen)

func _on_door_2_pressed() -> void:
	get_tree().change_scene_to_file(room_bath)

func _on_door_3_pressed() -> void:
	get_tree().change_scene_to_file(room_litter)

func _on_door_4_pressed() -> void:
	get_tree().change_scene_to_file(room_bed)

func _on_door_5_pressed() -> void:
	get_tree().change_scene_to_file(room_play)

func _on_door_office_pressed() -> void:
	get_tree().change_scene_to_file(room_office)

func _on_door_options_pressed() -> void:
	get_tree().change_scene_to_file(room_options)


## ---------------------------------------------------------------------------
## Hallway sections
## ---------------------------------------------------------------------------

func _setup_hallway() -> void:
	for section in SECTIONS:
		_home_x[section] = get_node(section).position.x
	_section_width = _home_x["HallwayStart"] - _home_x["HallwayLeft1"]
	_build_edge_glow()
	# Come back out of a room in front of the same doors.
	_current = Global.hub_section if Global.hub_section in OPEN_SECTIONS else "HallwayStart"
	_cat_section = Global.hub_cat_section if Global.hub_cat_section in OPEN_SECTIONS else _current
	_cat_follows = _cat_section == _current
	_set_scroll(_scroll_for(_current))


func _scroll_for(section: String) -> float:
	return _home_x[section] - _home_x["HallwayStart"]


func _set_scroll(value: float) -> void:
	_scroll = value
	for section in SECTIONS:
		get_node(section).position.x = _home_x[section] - _scroll
	_place_cat()


## Crispy walks around (with physics) only while his section is on screen. When
## he stays behind he is frozen and slides away with his section, and comes back
## with it.
func _place_cat() -> void:
	var offset: float = 0.0 if _cat_follows else float(_home_x[_cat_section]) - _scroll
	if is_zero_approx(offset) or absf(offset) < 0.5:
		if _cat_parked:
			_cat_parked = false
			_cat.position.x = _cat_parked_x
			_cat.process_mode = Node.PROCESS_MODE_INHERIT
			_cat.visible = true
		return
	if not _cat_parked:
		_cat_parked = true
		_cat_parked_x = _cat.position.x
		_cat.process_mode = Node.PROCESS_MODE_DISABLED
	_cat.position.x = _cat_parked_x + offset
	_cat.visible = absf(offset) < _section_width


## Called as a move between sections starts: a grumpy Crispy stays put.
func _decide_cat_follows() -> void:
	_cat_follows = Global.mood > Global.CAT_FOLLOW_MAX_GRUMPY_MOOD
	if _cat_follows:
		# Catches up if he was left behind earlier.
		_cat_section = _current


## The open section next to the current one on that side (-1 left, 1 right),
## or "" if there is none.
func _neighbor(side: int) -> String:
	var i := SECTIONS.find(_current) + side
	if i < 0 or i >= SECTIONS.size() or not SECTIONS[i] in OPEN_SECTIONS:
		return ""
	return SECTIONS[i]


func _go_side(side: int) -> void:
	var target := _neighbor(side)
	if target.is_empty() or _sliding():
		return
	_slide_to(target)


func _slide_to(section: String) -> void:
	if _swipe_index < 0 and section != _current:
		_decide_cat_follows()
	_current = section
	Global.hub_section = section
	if _cat_follows:
		_cat_section = section
	Global.hub_cat_section = _cat_section
	if _slide != null:
		_slide.kill()
	_slide = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide.tween_method(_set_scroll, _scroll, _scroll_for(section), SLIDE_TIME)


func _sliding() -> bool:
	return _slide != null and _slide.is_running()


func _screen_width() -> float:
	return get_viewport().get_visible_rect().size.x


## Which edge (-1 left, 1 right) a point is over, if that edge leads somewhere.
func _edge_at(pos: Vector2) -> int:
	if pos.x < EDGE_WIDTH and not _neighbor(-1).is_empty():
		return -1
	if pos.x > _screen_width() - EDGE_WIDTH and not _neighbor(1).is_empty():
		return 1
	return 0


func _input(event: InputEvent) -> void:
	# Taps also arrive as emulated mouse clicks; swipes handle those instead.
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _popup_open():
			var side := _edge_at(event.position)
			if side != 0:
				_go_side(side)
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag and event.index == _swipe_index:
		_on_swipe_drag(event)
	elif event is InputEventKey and event.pressed and not event.echo and _keys_free():
		if event.keycode == KEY_LEFT:
			_go_side(-1)
		elif event.keycode == KEY_RIGHT:
			_go_side(1)


## Arrow keys belong to text boxes and the console while those are in use.
func _keys_free() -> bool:
	if Console.is_visible() or _popup_open():
		return false
	var focus := get_viewport().gui_get_focus_owner()
	return not (focus is LineEdit or focus is TextEdit)


func _popup_open() -> bool:
	for child in get_children():
		if child is WelcomeBack:
			return true
	for child in get_tree().root.get_children():
		if child is UpdateNotice:
			return true
	return false


# Swiping in from an edge drags the neighboring section onto the screen; let go
# far (or fast) enough and it takes over, otherwise it slides back.
func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed and _swipe_index < 0 and not _sliding() and not _popup_open():
		var side := _edge_at(event.position)
		if side != 0:
			_decide_cat_follows()
			_swipe_index = event.index
			_swipe_side = side
			_swipe_start = event.position
			_swipe_velocity = 0.0
			_show_edge_glow(side)
			get_viewport().set_input_as_handled()
	elif not event.pressed and event.index == _swipe_index:
		_swipe_index = -1
		_show_edge_glow(0)
		var pulled := (event.position.x - _swipe_start.x) * -_swipe_side
		var flicked := _swipe_velocity * -_swipe_side > SWIPE_FLICK_SPEED
		if pulled > _section_width * SWIPE_COMMIT or (flicked and pulled > 0.0):
			_slide_to(_neighbor(_swipe_side))
		else:
			_slide_to(_current)
		get_viewport().set_input_as_handled()


func _on_swipe_drag(event: InputEventScreenDrag) -> void:
	_swipe_velocity = event.velocity.x
	# Only toward the neighbor, and never past it.
	var pulled := clampf((event.position.x - _swipe_start.x) * -_swipe_side, 0.0, _section_width)
	_set_scroll(_scroll_for(_current) + _swipe_side * pulled)
	get_viewport().set_input_as_handled()


func _update_edge_hover() -> void:
	if _swipe_index >= 0:
		return
	var side := 0
	if not _sliding() and not _popup_open():
		var mouse := get_viewport().get_mouse_position()
		if get_viewport().get_visible_rect().has_point(mouse):
			side = _edge_at(mouse)
	if side == _hover_side:
		return
	_hover_side = side
	_show_edge_glow(side)
	var normal: Texture2D = Global.smcursor_default if Global.web_version else Global.cursor_default
	Input.set_custom_mouse_cursor(_edge_cursor(normal) if side != 0 else normal)


func _show_edge_glow(side: int) -> void:
	for s in _edge_glow:
		_edge_glow[s].visible = s == side


## The normal cursor, tinted and partly see-through, so it is obvious a click
## here changes the view rather than pressing whatever is underneath.
func _edge_cursor(normal: Texture2D) -> Texture2D:
	if not _edge_cursors.has(normal):
		var image := normal.get_image()
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		for y in image.get_height():
			for x in image.get_width():
				image.set_pixel(x, y, image.get_pixel(x, y) * EDGE_TINT)
		_edge_cursors[normal] = ImageTexture.create_from_image(image)
	return _edge_cursors[normal]


## A soft glow with an arrow on each edge, shown while it is hovered or swiped.
func _build_edge_glow() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	for side in [-1, 1]:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0.1, 0.15, 0.25, 0.45))
		gradient.set_color(1, Color(0.1, 0.15, 0.25, 0.0))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 64
		texture.height = 4
		if side == 1:
			texture.fill_from = Vector2(1, 0)
			texture.fill_to = Vector2(0, 0)

		var glow := TextureRect.new()
		glow.texture = texture
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.stretch_mode = TextureRect.STRETCH_SCALE
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.anchor_top = 0.0
		glow.anchor_bottom = 1.0
		glow.anchor_left = 0.0 if side == -1 else 1.0
		glow.anchor_right = glow.anchor_left
		glow.offset_left = 0.0 if side == -1 else -EDGE_WIDTH * 2.5
		glow.offset_right = EDGE_WIDTH * 2.5 if side == -1 else 0.0
		glow.visible = false
		layer.add_child(glow)

		var arrow := Label.new()
		arrow.text = "<" if side == -1 else ">"
		arrow.add_theme_font_size_override("font_size", 56)
		arrow.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		arrow.add_theme_color_override("font_outline_color", Color(0.1, 0.15, 0.25, 0.8))
		arrow.add_theme_constant_override("outline_size", 8)
		arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.add_child(arrow)
		_edge_glow[side] = glow
