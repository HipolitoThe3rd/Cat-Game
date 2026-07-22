## Global variables
extends Node

@onready var web_version = true # whether or not this is the web version

var cursor_default = load("res://sprites/cursors/cursor_default.png")
var cursor_pet = load("res://sprites/cursors/cursor_pet.png")
var cursor_shower = load("res://sprites/cursors/cursor_shower-head.png")
var cursor_shower_pour = load("res://sprites/cursors/cursor_shower-head_pressed.png")

# small cursors for web version
var smcursor_default = load("res://sprites/cursors/smcursor_default.png")
var smcursor_pet = load("res://sprites/cursors/smcursor_pet.png")
var smcursor_shower = load("res://sprites/cursors/smcursor_shower-head.png")
var smcursor_shower_pour = load("res://sprites/cursors/smcursor_shower-head_pressed.png")

# Tracks the cursor path
var cursor_path: Resource = null

# Cat mood system globals
var mood = 90 # how happy the cat is; 0 is minimum and 100 is maximum, default 50

# Cat mood contributors
var hunger = 5 # 0 to 100, affects mood and behavior, default 30
var energy = 80 # 0 to 100, decreases with activity, default 80
var cleanliness = 55 # 0 to 100, decreases over time, affects mood, default 95
var entertainment = 75 # 0 to 100, boredom level; too low means bored, default 50
var affection = 15 # 0 to 100, needs player interaction to increase, default 40
var bladder = 70 # 0 to 100, decreases over time/activity; at 0 cat soils itself and resets to 100, default 100

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

# only sets cursor to new_cursor if the current cursor does not already match it
# this is to prevent a glitch in the web version where the cursor rapidly switches
# back and forth between the OS default and the custom cursor when it processes
# every frame
func set_cursor(new_cursor:Resource) -> void:
	if cursor_path != new_cursor:
		Input.set_custom_mouse_cursor(new_cursor)
		cursor_path = new_cursor
	

func feed_cat(hunger_amount:int = 30) -> void:
	Global.hunger = min(100, Global.hunger + hunger_amount)
