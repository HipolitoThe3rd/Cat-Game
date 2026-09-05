class_name Playroom
extends Node2D

## Laser maze minigame.
##
## Every round the room is rebuilt out of Block/PlayroomDoor prefabs into a
## descending maze: the cat starts on the top floor and has to reach the yarn
## on the ground floor. He cannot climb, so the only way down is to find a hole
## and drop through it -- walls split each floor into segments, so picking the
## wrong hole strands him in a dead end and the player hits Reset.
##
## Difficulty is adjusted dynamically: each win nudges Global.playroom_difficulty
## up, each Reset nudges it back down.

const BLOCK_SCENE = preload("res://scenes/prefabs/playroom/block_line.tscn")
const SQUARE_SCENE = preload("res://scenes/prefabs/playroom/block_square.tscn")
const DOOR_SCENE = preload("res://scenes/prefabs/playroom/playroom_door.tscn")
const YARN_SCENE = preload("res://scenes/prefabs/yarn.tscn")

# --- Grid -----------------------------------------------------------------
# The room sits on a 128px grid, which is exactly the length of a block_line:
# one floor tile is one cell wide and one wall is one storey tall.
const CELL = 128.0
const COLS = 9                  # 9 * 128 == 1152, the width of the room
const ROWS = 5                  # floor levels, top to bottom
const TOP_ROW = 1               # row 0 is a solid ceiling: the UI buttons
								# sit over it, so nothing playable goes there
const ROW_TOP = 130.0           # y of the highest floor
const BLOCK_SPAN = 123.75       # collision length of block_line (1.65 * 75)
const BLOCK_HALF = 10.0         # half its thickness
const BLOCK_FIT = CELL / BLOCK_SPAN  # stretch tiles so neighbours butt together

# --- Entertainment --------------------------------------------------------
const FUN_IDLE = 0.2            # per second, just being in the playroom
const FUN_ACTIVE = 0.5          # per second, while actually chasing the laser
const FUN_YARN = 5.0           # payoff for catching the yarn

# --- Speed readout --------------------------------------------------------
const SPEED_FAST = Color(0.25, 1.0, 0.35)  # quick enough to clear a one-tile gap
const SPEED_SLOW = Color(1.0, 0.5, 0.15)   # he will step off the ledge instead

# --- Dynamic difficulty ---------------------------------------------------
const WIN_STEP = 0.12
const RESET_STEP = 0.10

@onready var fn_bar = $UI/FunBar
@onready var speed_bar: ProgressBar = $UI/SpeedBar
@onready var cat: PlayroomCat = $Cat
@onready var sp_bar = $UI/SpeedBar # indicates how fast the cat is moving to the left or to the right
@onready var level: Node2D = $LevelDesign
@onready var replay_button: TextureButton = $UI/ReplayButton
@onready var back_button: TextureButton = $UI/BackButton

var pointing_at_door = false

# Maze layout. floor_solid[row][col] is a tile; wall_at[row][boundary] is a
# vertical block standing on that floor, boundary b sitting between col b-1
# and col b (0 and COLS are the outer walls of the room).
var floor_solid := []
var wall_at := []
var protected := []             # cells the guaranteed route walks over
var start_col := 0
var yarn: Yarn = null

var _mouse_was_down := false
var _laser_engaged := false     # press began on the play field, not on the UI


## Default functions
func _ready() -> void:
	randomize()
	add_to_group("playroom")
	set_cursor(Global.smcursor_laser if Global.web_version else Global.cursor_laser)
	generate_maze()


func _process(delta: float) -> void:
	update_fun_bar()
	update_speed_bar()
	update_laser(delta)
	update_cursor()

	# Safety net in case he ever squeezes out of the room.
	if cat.global_position.y > 900.0 or cat.global_position.x < -80.0 or cat.global_position.x > 1232.0:
		cat.place_at(cat.start_pos)


## Custom functions
func update_fun_bar() -> void:
	fn_bar.value = Global.entertainment
	if fn_bar.value < 25:
		fn_bar.modulate = Color(1, 0, 0) # red for low values
	elif fn_bar.value > 75:
		fn_bar.modulate = Color(0, 1, 0) # green for high values
	else:
		fn_bar.modulate = Color(0.333, 0.333, 0.333) # gray for neutral range


# Signed readout of how hard he is running and which way: the bar sits at the
# centre when he is still, and colours green once he is quick enough to hop.
func update_speed_bar() -> void:
	var frac := clampf(cat.velocity.x / cat.RUN_SPEED, -1.0, 1.0)
	var mid: float = (speed_bar.min_value + speed_bar.max_value) * 0.5
	speed_bar.value = mid + frac * (speed_bar.max_value - mid)
	speed_bar.modulate = SPEED_FAST if cat.at_jump_speed() else SPEED_SLOW


func update_laser(delta: float) -> void:
	var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if down and not _mouse_was_down:
		if not pointer_over_ui():
			_laser_engaged = true
			$Audio/LaserOn.play()
	elif not down and _mouse_was_down:
		if _laser_engaged:
			_laser_engaged = false
			$Audio/LaserOff.play()
	_mouse_was_down = down

	cat.laser_pos = get_global_mouse_position()
	cat.laser_held = down and _laser_engaged

	# Playing is entertaining whether or not he ever reaches the yarn.
	var gain: float = FUN_ACTIVE if cat.following else FUN_IDLE
	Global.entertainment = min(100, Global.entertainment + gain * delta)


func update_cursor() -> void:
	var pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if Global.web_version:
		if pointing_at_door:
			set_cursor(Global.smcursor_pet if pressed else Global.smcursor_default)
		else:
			set_cursor(Global.smcursor_laser_pressed if pressed else Global.smcursor_laser)
	else:
		if pointing_at_door:
			set_cursor(Global.cursor_pet if pressed else Global.cursor_default)
		else:
			set_cursor(Global.cursor_laser_pressed if pressed else Global.cursor_laser)


func set_cursor(res: Resource) -> void:
	Global.set_cursor(res)


func pointer_over_ui() -> bool:
	var m := get_viewport().get_mouse_position()
	for b: Control in [replay_button, back_button]:
		if (b.get_global_transform() * Rect2(Vector2.ZERO, b.size)).has_point(m):
			return true
	return false


# --- Grid helpers ---------------------------------------------------------
func col_x(c: int) -> float:
	return CELL * c + CELL * 0.5


func row_y(r: int) -> float:
	return ROW_TOP + CELL * r


# Top surface of a floor row, i.e. what the cat stands on.
func surface_y(r: int) -> float:
	return row_y(r) - BLOCK_HALF


# The stretch of floor r the cat can reach from column c without a wall in the
# way, returned as [first_col, last_col].
func segment_of(r: int, c: int) -> Array:
	var lo := c
	while lo > 0 and not wall_at[r][lo]:
		lo -= 1
	var hi := c
	while hi < COLS - 1 and not wall_at[r][hi + 1]:
		hi += 1
	return [lo, hi]


# --- Maze generation ------------------------------------------------------
func generate_maze() -> void:
	pointing_at_door = false
	clear_level()

	var d: float = Global.playroom_difficulty
	var wall_chance := lerpf(0.22, 0.62, d)
	var decoys := int(round(lerpf(1.0, 5.0, d)))
	var jump_gaps := int(round(lerpf(0.0, 3.0, d)))
	var doors := int(floor(lerpf(0.0, 2.49, d)))
	cat.follow_radius = lerpf(430.0, 210.0, d)

	var door_cells := []
	seed_grid(wall_chance)
	var landing := carve_route(door_cells, doors, jump_gaps)
	carve_decoys(decoys)
	tidy_walls()

	# Send him home BEFORE the new yarn is spawned. Otherwise a yarn that lands
	# near where he just celebrated can catch him on the very next physics step
	# and win the round for him instantly.
	cat.place_at(cat.stand_position(col_x(start_col), surface_y(TOP_ROW)))
	build_level(door_cells, landing)


func seed_grid(wall_chance: float) -> void:
	floor_solid = []
	wall_at = []
	protected = []
	for r in ROWS:
		var tiles := []
		for c in COLS:
			tiles.append(true)
		floor_solid.append(tiles)

		var walls := []
		for b in COLS + 1:
			walls.append(b == 0 or b == COLS)
		if r > 0:
			for b in range(1, COLS):
				walls[b] = randf() < wall_chance
		wall_at.append(walls)

		protected.append({})


# Walks a guaranteed route from the top floor to the ground floor, carving the
# hole it drops through on each level. Returns the column it lands on the
# ground floor, which is where the yarn has to be reachable from.
func carve_route(door_cells: Array, doors: int, jump_gaps: int) -> int:
	var door_rows := pick_rows(doors)
	var jump_rows := pick_rows(jump_gaps)

	start_col = randi() % COLS
	var e := start_col

	for r in range(TOP_ROW, ROWS - 1):
		# Give him room to build up speed and somewhere to put a hole he is not
		# already standing on.
		var seg := widen_segment(r, e, 4)
		var use_door: bool = door_rows.has(r)
		var hole := pick_hole(seg, e, 1 if use_door else 2)
		var hole_end: int = hole if use_door else hole + 1

		# The stretch he walks over has to stay put.
		for c in range(mini(e, hole), maxi(e, hole_end) + 1):
			protected[r][c] = true
		for c in range(hole, hole_end + 1):
			floor_solid[r][c] = false
		if use_door:
			door_cells.append(Vector2i(r, hole))

		# Optionally drop a single-tile gap in his path: narrow enough to hop,
		# but only if the player keeps the laser far enough ahead to make him run.
		if jump_rows.has(r):
			var lo := e + 1 if e < hole else hole_end + 2
			var hi := hole - 2 if e < hole else e - 1
			if hi >= lo:
				floor_solid[r][lo + randi() % (hi - lo + 1)] = false

		e = hole if e < hole else hole_end

	return e


# Knocks out walls until the segment holding column c is at least min_width wide.
func widen_segment(r: int, c: int, min_width: int) -> Array:
	for _i in 12:
		var seg := segment_of(r, c)
		if seg[1] - seg[0] + 1 >= min_width:
			return seg
		if seg[0] > 0:
			wall_at[r][seg[0]] = false
		elif seg[1] < COLS - 1:
			wall_at[r][seg[1] + 1] = false
		else:
			break
	return segment_of(r, c)


# Picks the left column of a `width` wide hole inside seg that does not sit
# under the cat.
func pick_hole(seg: Array, c: int, width: int) -> int:
	var opts := []
	for h in range(seg[0], seg[1] - width + 2):
		if c < h or c > h + width - 1:
			opts.append(h)
	if opts.is_empty():
		return seg[0] if c != seg[0] else seg[1]
	return opts[randi() % opts.size()]


func pick_rows(n: int) -> Dictionary:
	var pool := range(TOP_ROW, ROWS - 1)
	pool.shuffle()
	var out := {}
	for i in mini(n, pool.size()):
		out[pool[i]] = true
	return out


# Extra holes away from the guaranteed route. These are the wrong turns: drop
# through one and the cat lands in a segment the yarn is walled off from.
func carve_decoys(count: int) -> void:
	var made := 0
	var tries := 0
	while made < count and tries < 80:
		tries += 1
		var r := TOP_ROW + randi() % (ROWS - 1 - TOP_ROW)
		var c := randi() % (COLS - 1)
		if protected[r].has(c) or protected[r].has(c + 1):
			continue
		if not floor_solid[r][c] or not floor_solid[r][c + 1]:
			continue
		floor_solid[r][c] = false
		floor_solid[r][c + 1] = false
		made += 1


# A wall standing on the lip of a hole would hang in mid-air and snag the cat
# on his way down, so drop those. Removing walls only ever merges segments, so
# the guaranteed route survives.
func tidy_walls() -> void:
	for r in ROWS:
		for b in range(1, COLS):
			if not floor_solid[r][b - 1] or not floor_solid[r][b]:
				wall_at[r][b] = false


# --- Building -------------------------------------------------------------
func clear_level() -> void:
	yarn = null
	for child in level.get_children():
		level.remove_child(child)
		child.queue_free()


func build_level(door_cells: Array, landing: int) -> void:
	var doors := {}
	for cell: Vector2i in door_cells:
		doors[cell] = true

	for r in ROWS:
		for c in COLS:
			if floor_solid[r][c]:
				spawn_floor(r, c)
			elif doors.has(Vector2i(r, c)):
				spawn_door(r, c)
		for b in range(COLS + 1):
			if wall_at[r][b]:
				spawn_wall(r, b)

	spawn_decor()
	spawn_yarn(landing)


func spawn_floor(r: int, c: int) -> void:
	var block := BLOCK_SCENE.instantiate()
	block.position = Vector2(col_x(c), row_y(r))
	block.scale = Vector2(BLOCK_FIT, 1.0)
	level.add_child(block)


func spawn_wall(r: int, b: int) -> void:
	var block := BLOCK_SCENE.instantiate()
	block.rotation = PI * 0.5
	block.scale = Vector2(BLOCK_FIT, 1.0)
	# The two outer walls get nudged inwards so they sit fully on screen.
	var x := CELL * b
	if b == 0:
		x += BLOCK_HALF
	elif b == COLS:
		x -= BLOCK_HALF
	# Fills the storey between this floor and the one above it.
	block.position = Vector2(x, surface_y(r) - CELL * 0.5)
	level.add_child(block)


func spawn_door(r: int, c: int) -> void:
	var door := DOOR_SCENE.instantiate()
	# Squashed to one cell wide; the offsets line the closed gate's collider up
	# with the surrounding floor tiles.
	door.scale = Vector2(2.0, 1.0)
	door.position = Vector2(col_x(c) - 5.13, row_y(r) + 14.67)
	door.get_node("ClickArea").scale = Vector2(1.0, 2.0)  # roomier click target
	level.add_child(door)


# Loose toy blocks lying about. Purely decorative, so their collision is off.
func spawn_decor() -> void:
	for _i in 5:
		var r := TOP_ROW + randi() % (ROWS - TOP_ROW)
		var c := randi() % COLS
		if not floor_solid[r][c]:
			continue
		var square := SQUARE_SCENE.instantiate()
		square.position = Vector2(col_x(c) + randf_range(-40.0, 40.0), surface_y(r) - 19.0)
		square.z_index = -1
		square.get_node("StaticBody2D/CollisionShape2D").disabled = true
		level.add_child(square)


func spawn_yarn(landing: int) -> void:
	var seg := segment_of(ROWS - 1, landing)
	# Put it at the far end of the segment he lands in so there is a walk left.
	var c: int = seg[0] if landing - seg[0] > seg[1] - landing else seg[1]
	yarn = YARN_SCENE.instantiate()
	yarn.scale = Vector2(0.08, 0.08)
	yarn.position = Vector2(col_x(c), row_y(ROWS - 1) - 55.0)
	level.add_child(yarn)
	yarn.collected.connect(_on_yarn_collected)


## Signals
func _on_yarn_collected(_yarn: Yarn) -> void:
	Global.entertainment = min(100, Global.entertainment + FUN_YARN)
	Global.playroom_difficulty = clampf(Global.playroom_difficulty + WIN_STEP, 0.0, 1.0)


func _on_replay_button_button_down() -> void:
	# Getting stuck is the game working as intended, but it should not keep
	# happening, so back the mazes off a notch.
	Global.playroom_difficulty = clampf(Global.playroom_difficulty - RESET_STEP, 0.0, 1.0)
	generate_maze()


func _on_back_button_button_down() -> void:
	get_tree().change_scene_to_file("res://scenes/hub.tscn")


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "yarn":
		# reset room and rearrange blocks
		generate_maze()
