class_name Bedroom
extends Node2D

const ENERGY_PER_SECOND = 1.0 # how fast the cat recovers energy while it is asleep, default 2.5
const SPAWN_INTERVAL = 3.0 # seconds between bedbugs

@onready var cat = $Cat
@onready var en_bar = $UI/EnergyBar
@onready var hitbox = $Hitbox
@onready var hitbox_area = $Hitbox/Area2D
@onready var spawn_timer = $SpawnTimer
@onready var walk_areas = $BedbugWalkAreas
@onready var bedbug_prefab = preload("res://scenes/prefabs/bedbug.tscn")
@onready var enemy_list = $EnemyList

var rested = false # true once energy reached 100 and the cat woke up happy

#default functions
func _ready() -> void:
	#set cursor
	if Global.web_version:
		Input.set_custom_mouse_cursor(Global.smcursor_default)
	else:
		Input.set_custom_mouse_cursor(Global.cursor_default)
	if Global.energy >= 88:
		rested = true
		set_awake()
	else:
		set_asleep()
		spawn_timer.start(SPAWN_INTERVAL)

func _process(delta: float) -> void:
	# cat's energy goes up until it reaches 100, after which it wakes up
	gain_energy(delta)
	update_energy_bar()
	hitbox.global_position = get_viewport().get_mouse_position()
	if Input.is_action_just_pressed("left_click"):
		#kill bedbug if it was just clicked on
		squish_bedbug()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		#print("Left mouse button is being held down!")
		if Global.web_version:
			Global.set_cursor(Global.smcursor_pet)
		else:
			Input.set_custom_mouse_cursor(Global.cursor_pet)
	else:
		if Global.web_version:
			Global.set_cursor(Global.smcursor_default)
		else:
			Input.set_custom_mouse_cursor(Global.cursor_default)

# custom functions
func gain_energy(delta: float) -> void:
	# only a sleeping cat rests: an upset cat gains nothing until it settles down again
	if rested or cat.upset:
		return
	Global.energy = min(100.0, Global.energy + ENERGY_PER_SECOND * delta)
	if Global.energy >= 100:
		rested = true
		spawn_timer.stop()
		set_awake()

func update_energy_bar() -> void:
	en_bar.value = Global.energy
	if en_bar.value < 25:
		en_bar.modulate = Color(1, 0, 0) # red for low values
	elif en_bar.value > 75:
		en_bar.modulate = Color(0, 1, 0) # green for high values
	else:
		en_bar.modulate = Color(0.333, 0.333, 0.333) # gray for neutral range

func squish_bedbug() -> void:
	# kill whichever bedbug under the click hitbox is nearest to the cursor
	var closest = null
	var closest_distance = INF
	for area in hitbox_area.get_overlapping_areas():
		var bug = area.get_parent() as BedBug
		if bug == null or bug.is_dead():
			continue
		var distance = hitbox.global_position.distance_to(bug.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = bug
	if closest != null:
		closest.squish()

func disturb_cat() -> void:
	# cat wakes up when bedbug touches collider
	# after this, all bedbugs, regardless of where they are, must be killed before cat can sleep again
	if cat.upset:
		return
	cat.upset = true
	cat.animate("upset")

func set_asleep() -> void:
	# cat continues to sleep
	cat.upset = false
	cat.animate()

func set_awake() -> void:
	# wakes up the cat
	cat.upset = false
	cat.happy_meow()
	cat.animate("rested")

# signals
func _on_spawn_timer_timeout() -> void:
	# spawn a bedbug somewhere in $BedbugWalkAreas/SpawnArea if the cat is not sleeping
	# the bedbug will become a child node of enemy_list
	if Global.energy < 100:
		# spawn bed bug, with a 50/50 chance of it taking the left or the right path
		var bug = bedbug_prefab.instantiate()
		enemy_list.add_child(bug)
		bug.start_walk(walk_areas, cat, "L" if randf() < 0.5 else "R")

func _on_enemy_list_child_exiting_tree(node: Node) -> void:
	if is_queued_for_deletion():
		# the whole room is being freed, e.g. on the way back to the hub
		return
	if not cat.upset or rested:
		return
	# the bedbug that is leaving is still in the list, so skip past it while counting
	for child in enemy_list.get_children():
		var bug = child as BedBug
		if child != node and bug != null and not bug.is_dead():
			return
	set_asleep()

func _on_area_2d_area_entered(area: Area2D) -> void:
	# a bedbug made it onto the cat
	var bug = area.get_parent() as BedBug
	if bug == null or bug.is_dead() or rested:
		return
	bug.reach_cat()
	disturb_cat()

func _on_back_button_button_down() -> void:
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
