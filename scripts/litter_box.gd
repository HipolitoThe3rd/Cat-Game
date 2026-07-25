extends Node2D

@onready var sc_hitbox = $ScooperHitbox
@onready var spawn_area = $SpawnArea # a Poop prefab will randomly spawn somewhere in this area
@onready var spawn_area_poly = $SpawnArea/CollisionPolygon2D
@onready var poop_prefab = load("res://scenes/prefabs/poop.tscn")
@onready var scooped = false # whether the scooper is holding poop
@onready var cat = $Cat

func _ready() -> void:
	#set cursor
	if Global.web_version:
		Input.set_custom_mouse_cursor(Global.smcursor_scooper)
	else:
		Input.set_custom_mouse_cursor(Global.cursor_scooper)
	spawn_poop(Global.poop_in_litterbox)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Global.cleanliness >= 100:
		# set cursor to default as showerhead is no longer needed
		if Global.web_version:
			Global.set_cursor(Global.smcursor_default)
		else:
			Input.set_custom_mouse_cursor(Global.cursor_default)
		if $Audio/ShowerRun.playing == true:
			$Audio/ShowerRun.stop()
	else:
		sc_hitbox.global_position = get_viewport().get_mouse_position()
		if Input.is_action_just_pressed("left_click"):
			#print("scoop!")
			if scooped == false:
				$Audio/Scoop.play()
			var overlapping_targets = sc_hitbox.get_node("Area2D").get_overlapping_areas()
			for target in overlapping_targets:
				#print("Touching: ", target.name)
				if target.get_parent() is Poop:
					#print("found poop!")
					print('Scooped? ', scooped)
					if scooped == false and cat.position.y > 86.0:
						target.get_parent().queue_free()
						scooped = true
						cat.animate("move_up")
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or scooped == true:
			#print("Left mouse button is being held down!")
			if Global.web_version:
				Global.set_cursor(Global.smcursor_scooper_pressed)
			else:
				Input.set_custom_mouse_cursor(Global.cursor_scooper_pressed)
			#if $Audio/ShowerToggle.playing == false and $Audio/ShowerRun.playing == false:
				#$Audio/ShowerRun.play()
				#pass
		else:
			if Global.web_version:
				Global.set_cursor(Global.smcursor_scooper)
			else:
				Input.set_custom_mouse_cursor(Global.cursor_scooper)
			#if $Audio/ShowerRun.playing == true:
			#	$Audio/ShowerRun.stop()

func spawn_poop(num_to_spawn: int) -> void:
	# spawn [num_to_spawn] instances of poop prefab in a random area within spawn_area
	var polygon = spawn_area_poly.polygon
	
	# Calculate bounding rect from polygon points
	var min_x = polygon[0].x
	var max_x = polygon[0].x
	var min_y = polygon[0].y
	var max_y = polygon[0].y
	
	for point in polygon:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)
	
	var spawn_area_pos = spawn_area.global_position
	
	for i in range(num_to_spawn):
		var spawn_point = Vector2.ZERO
		var point_valid = false
		
		# Keep trying until we find a valid point inside the polygon
		while not point_valid:
			spawn_point = Vector2(
				randf_range(min_x, max_x),
				randf_range(min_y, max_y)
			)
			point_valid = Geometry2D.is_point_in_polygon(spawn_point, polygon)
		
		var poop_instance = poop_prefab.instantiate()
		poop_instance.global_position = spawn_area_pos + spawn_point
		add_child(poop_instance)

func _on_cat_button_down() -> void:
	if scooped == true:
		scooped = false
		Global.poop_in_litterbox -= 1
		cat.animate("move_down")


func _on_cat_button_up() -> void:
	pass # Replace with function body.


func _on_cat_pressed() -> void:
	pass # Replace with function body.


func _on_cat_toggled(_toggled_on: bool) -> void:
	pass # Replace with function body.

func _on_back_button_button_down() -> void:
	get_tree().change_scene_to_file("res://scenes/litter_room.tscn")

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "move_down":
		print("Poop left: ", Global.poop_in_litterbox		)
		if Global.poop_in_litterbox == 0:
			get_tree().change_scene_to_file("res://scenes/litter_room.tscn")
