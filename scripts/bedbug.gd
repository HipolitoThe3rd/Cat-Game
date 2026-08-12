class_name BedBug
extends Node2D

const WALK_SPEED = 100.0        # crawl speed on the way down to the cat
const ON_CAT_SPEED = 70.0       # slower shuffle once it is walking on the cat
const FLEE_SPEED = 320.0        # much faster retreat once the cat is fully rested
const TURN_SPEED = 10.0         # how quickly it swings around to face where it is going
const OFFSCREEN_BUFFER = 150.0  # how far past the viewport edge counts as "out of the room"
const EXIT_Y = -400.0           # height it retreats to when leaving the room

var walk_areas: Node2D            # holds the SpawnArea and the WalkArea* polygons
var cat: Node2D
var target = Vector2.ZERO         # the point it is currently walking toward
var side = "L"                    # which of the two paths this bug takes: "L" or "R"
var route = PackedVector2Array()  # spawn point, one point per walk area, then the cat
var route_index = 0
var on_cat = false                # reached the cat and is now milling around on it
var fleeing = false
var dying = false

# default functions
func _ready() -> void:
	# nothing to do until the room hands over the areas to walk through
	set_process(false)

func _process(delta: float) -> void:
	if dying:
		# do not move if dying
		return

	if Global.energy >= 100 and not fleeing:
		# cat is fully rested, so turn around and head back out of the room
		start_fleeing()

	if fleeing:
		# going up toward WalkArea?3 -> WalkArea?2 -> WalkArea? -> SpawnArea -> outside scene
		if step_toward(target, FLEE_SPEED, delta) and route_index < route.size() - 1:
			route_index += 1
			target = route[route_index]
		if is_out_of_room():
			queue_free()
		return

	if on_cat:
		# the cat is already awake, so the bug just wanders around inside its Area2D
		if step_toward(target, ON_CAT_SPEED, delta):
			target = cat_point()
		return

	# move toward the cat, starting from SpawnArea
	# going down toward WalkArea? -> WalkArea?2 -> WalkArea?3 -> Cat
	if step_toward(target, WALK_SPEED, delta):
		if route_index < route.size() - 1:
			route_index += 1
			target = route[route_index]
		else:
			reach_cat()

# custom functions
# drops the bug in the spawn area and builds the path it walks down to the cat
func start_walk(areas: Node2D, bed_cat: Node2D, walk_side: String) -> void:
	walk_areas = areas
	cat = bed_cat
	side = walk_side
	global_position = random_point_in_area("SpawnArea", side)
	route = PackedVector2Array([global_position])
	for area_name in ["WalkArea" + side, "WalkArea" + side + "2", "WalkArea" + side + "3"]:
		route.append(random_point_in_area(area_name))
	route.append(cat_point())
	route_index = 1
	target = route[route_index]
	rotation = (target - global_position).angle()
	set_process(true)

# the bug has touched the cat, so from here it only walks around inside the cat's Area2D
func reach_cat() -> void:
	if on_cat or fleeing or dying:
		return
	on_cat = true
	route_index = route.size() - 1
	target = cat_point()

# clicked on: play the death animation, which frees the bug when it finishes
func squish() -> void:
	if dying:
		return
	dying = true
	$AnimationPlayer.play("die")

func is_dead() -> bool:
	return dying

# retraces the waypoints it has already passed, then keeps going up and out of the room
func start_fleeing() -> void:
	fleeing = true
	on_cat = false
	var escape = PackedVector2Array()
	for i in range(min(route_index - 1, route.size() - 1), -1, -1):
		escape.append(route[i])
	if escape.is_empty():
		escape.append(global_position)
	escape.append(Vector2(escape[escape.size() - 1].x, EXIT_Y))
	route = escape
	route_index = 0
	target = route[route_index]

# moves toward point and reports whether it arrived this frame
func step_toward(point: Vector2, speed: float, delta: float) -> bool:
	var to_point = point - global_position
	var distance = to_point.length()
	face(to_point, delta)
	var step = speed * delta
	if distance <= step:
		global_position = point
		return true
	global_position += to_point / distance * step
	return false

# turns the bug so it crawls head first toward where it is going
func face(direction: Vector2, delta: float) -> void:
	if direction.length_squared() < 0.01:
		return
	rotation = lerp_angle(rotation, direction.angle(), min(1.0, TURN_SPEED * delta))

func is_out_of_room() -> bool:
	return not get_viewport_rect().grow(OFFSCREEN_BUFFER).has_point(global_position)

# a random spot inside one of the walk areas; x_side ("L"/"R") keeps the point on one
# side of the room, which matters for the spawn area as it spans the whole width
func random_point_in_area(area_name: String, x_side := "") -> Vector2:
	var poly_node: CollisionPolygon2D = walk_areas.get_node(area_name + "/CollisionPolygon2D")
	var poly = poly_node.polygon
	var bounds = polygon_bounds(poly)
	if x_side == "L":
		bounds.end = Vector2(min(bounds.end.x, 0.0), bounds.end.y)
	elif x_side == "R":
		bounds.position = Vector2(max(bounds.position.x, 0.0), bounds.position.y)
	# the areas are not rectangles, so keep sampling the bounding box until a point lands inside
	for i in 64:
		var point = Vector2(
			randf_range(bounds.position.x, bounds.end.x),
			randf_range(bounds.position.y, bounds.end.y)
		)
		if Geometry2D.is_point_in_polygon(point, poly):
			return poly_node.to_global(point)
	return poly_node.to_global(bounds.get_center())

func polygon_bounds(poly: PackedVector2Array) -> Rect2:
	var bounds = Rect2(poly[0], Vector2.ZERO)
	for point in poly:
		bounds = bounds.expand(point)
	return bounds

# a random spot inside the cat's Area2D
func cat_point() -> Vector2:
	var shape_node: CollisionShape2D = cat.get_node("Area2D/CollisionShape2D")
	var capsule = shape_node.shape as CapsuleShape2D
	var point = Vector2.ZERO
	if capsule != null:
		# a capsule's long axis is its local y; stay within the straight part of it
		point = Vector2(
			randf_range(-0.6, 0.6) * capsule.radius,
			randf_range(-1.0, 1.0) * max(0.0, capsule.height * 0.5 - capsule.radius)
		)
	return shape_node.to_global(point)

# signals
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "die":
		queue_free()
