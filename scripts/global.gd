## Global variables
extends Node

var cursor_default = load("res://sprites/cursors/cursor_default.png")
var cursor_pet = load("res://sprites/cursors/cursor_pet.png")
var cursor_shower = load("res://sprites/cursors/cursor_shower-head.png")
var cursor_shower_pour = load("res://sprites/cursors/cursor_shower-head_pressedd.png")

# Cat mood system globals
var mood = 90 # how happy the cat is; 0 is minimum and 100 is maximum, default 50

# Cat mood contributors
var hunger = 25 # 0 to 100, affects mood and behavior, default 30
var energy = 80 # 0 to 100, decreases with activity, default 80
var cleanliness = 95 # 0 to 100, decreases over time, affects mood, default 95
var entertainment = 75 # 0 to 100, boredom level; too low means bored, default 50
var affection = 15 # 0 to 100, needs player interaction to increase, default 40
var bladder = 100 # 0 to 100, decreases over time/activity; at 0 cat soils itself and resets to 100, default 100

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
