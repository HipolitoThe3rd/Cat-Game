## Global variables
extends Node

@onready var web_version = false # whether or not this is the web version

var cursor_default = load("res://sprites/cursors/cursor_default.png")
var cursor_pet = load("res://sprites/cursors/cursor_pet.png")
var cursor_shower = load("res://sprites/cursors/cursor_shower-head.png")
var cursor_shower_pour = load("res://sprites/cursors/cursor_shower-head_pressed.png")
var cursor_scooper = load("res://sprites/cursors/cursor_scooper.png")
var cursor_scooper_pressed = load("res://sprites/cursors/cursor_scooper_pressed.png")
var cursor_laser = load("res://sprites/cursors/cursor_laser.png")
var cursor_laser_pressed = load("res://sprites/cursors/cursor_laser_pressed.png")
var cursor_secret = load("res://sprites/cursors/cursor_secret.png")

# small cursors for web version
var smcursor_default = load("res://sprites/cursors/smcursor_default.png")
var smcursor_pet = load("res://sprites/cursors/smcursor_pet.png")
var smcursor_shower = load("res://sprites/cursors/smcursor_shower-head.png")
var smcursor_shower_pour = load("res://sprites/cursors/smcursor_shower-head_pressed.png")
var smcursor_scooper = load("res://sprites/cursors/smcursor_scooper.png")
var smcursor_scooper_pressed = load("res://sprites/cursors/smcursor_scooper_pressed.png")
var smcursor_laser = load("res://sprites/cursors/smcursor_laser.png")
var smcursor_laser_pressed = load("res://sprites/cursors/smcursor_laser_pressed.png")
var smcursor_secret = load("res://sprites/cursors/smcursor_secret.png")


# Tracks the cursor path
var cursor_path: Resource = null

# Cat mood system globals
var mood = 50 # how happy the cat is; 0 is minimum and 100 is maximum, default 50

# Cat mood contributors
var hunger = 30 # 0 to 100, affects mood and behavior, default 30
var energy = 80 # 0 to 100, decreases with activity, default 80
var cleanliness = 95 # 0 to 100, decreases over time, affects mood, default 95
var entertainment = 50 # 0 to 100, boredom level; too low means bored, default 50
var affection = 40 # 0 to 100, needs player interaction to increase, default 40
var bladder = 100 # 0 to 100, decreases over time/activity; at 0 cat soils itself and resets to 100, default 100

# Misc variables
var poop_in_litterbox = 0 # how much poop is in the litterbox; default 0

# Playroom laser maze; dynamic difficulty adjustment nudges this up on every
# win and back down every time the player has to hit Reset. 0 is gentlest.
var playroom_difficulty: float = 0.15


# Save system ---------------------------------------------------------------
const SAVE_PATH := "user://catgame_save.cfg"
const SAVE_VERSION := 1

# How often the game quietly writes to disk, in seconds.
const AUTOSAVE_INTERVAL := 10.0

# Absences shorter than this are ignored, so refreshing the page is free.
const MIN_OFFLINE_SECONDS := 60.0

# Offline decay is far gentler than the in-game tick in cat_hub.gd, which drains
# hunger at 0.3/second. At that rate one night away would zero out every stat.
# These are per REAL hour, starting from the cat's stats when you left.
const OFFLINE_HUNGER_PER_HOUR := 8.0         # starving after ~12h away
const OFFLINE_CLEANLINESS_PER_HOUR := 4.0    # grubby after about a day
const OFFLINE_ENTERTAINMENT_PER_HOUR := 5.0  # bored after ~20h
const OFFLINE_AFFECTION_PER_HOUR := 3.0      # misses you
const OFFLINE_BLADDER_PER_HOUR := 6.0
const OFFLINE_ENERGY_PER_HOUR := 10.0        # goes UP: the cat naps while away

const OFFLINE_ACCIDENT_CLEANLINESS_COST := 30.0
const OFFLINE_MAX_ACCIDENTS := 2

const OFFLINE_MOOD_DRIFT_PER_HOUR := 2.0
const NEUTRAL_MOOD := 50.0

# Every absence longer than this is treated identically. Two days away should
# not be meaningfully worse than two weeks away.
const MAX_OFFLINE_HOURS := 48.0

# False when the browser denies us persistent storage. The game still plays, it
# just will not remember anything between sessions.
var save_available := true

# Filled in by load_game(); read it to show a "while you were away" popup.
# Empty for a new save or a short absence.
var offline_summary := {}

var _autosave_countdown := AUTOSAVE_INTERVAL


func _ready() -> void:
	# Private browsing, or a browser with IndexedDB blocked, means user:// writes
	# silently evaporate. Detect it once so we can warn instead of pretending.
	save_available = OS.is_userfs_persistent()
	if not save_available:
		push_warning("Cat Game: persistent storage unavailable; progress will not be saved.")
	load_game()


func _process(delta: float) -> void:
	# Autosave on a timer rather than only on quit. A browser tab can be closed
	# without ever delivering a close notification, so the timer is the real
	# safety net and the _notification() handler below is a bonus.
	_autosave_countdown -= delta
	if _autosave_countdown <= 0.0:
		_autosave_countdown = AUTOSAVE_INTERVAL
		save_game()


func _notification(what: int) -> void:
	# Desktop window close, plus Android back/home. Best effort only.
	if what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_WM_GO_BACK_REQUEST \
			or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


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


## ---------------------------------------------------------------------------
## Save / load
## ---------------------------------------------------------------------------

## Writes every stat above to disk, stamped with the current time so the next
## load knows how long the cat was left alone.
func save_game() -> void:
	if not save_available:
		return

	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SAVE_VERSION)
	cfg.set_value("meta", "last_played_unix", Time.get_unix_time_from_system())

	cfg.set_value("cat", "mood", mood)
	cfg.set_value("cat", "hunger", hunger)
	cfg.set_value("cat", "energy", energy)
	cfg.set_value("cat", "cleanliness", cleanliness)
	cfg.set_value("cat", "entertainment", entertainment)
	cfg.set_value("cat", "affection", affection)
	cfg.set_value("cat", "bladder", bladder)

	cfg.set_value("world", "poop_in_litterbox", poop_in_litterbox)
	cfg.set_value("world", "playroom_difficulty", playroom_difficulty)

	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Cat Game: could not write save (error %d)." % err)
		save_available = false


## Restores the last session and then ages the cat by however long it was left
## alone. Safe to call when no save exists; the defaults declared above stand.
func load_game() -> void:
	offline_summary = {}

	if not FileAccess.file_exists(SAVE_PATH):
		return # brand new player

	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		push_warning("Cat Game: save unreadable (error %d). Starting fresh." % err)
		return

	if int(cfg.get_value("meta", "version", 0)) != SAVE_VERSION:
		# Ignore rather than half-apply an unknown layout. Migrations go here
		# if the stat list ever changes.
		push_warning("Cat Game: save is from another version. Starting fresh.")
		return

	# Clamped on the way in: cat_hub.gd drains hunger with min(100, ...) instead
	# of max(0, ...), so a stored value can legitimately be negative.
	mood = clamp(float(cfg.get_value("cat", "mood", mood)), 0.0, 100.0)
	hunger = clamp(float(cfg.get_value("cat", "hunger", hunger)), 0.0, 100.0)
	energy = clamp(float(cfg.get_value("cat", "energy", energy)), 0.0, 100.0)
	cleanliness = clamp(float(cfg.get_value("cat", "cleanliness", cleanliness)), 0.0, 100.0)
	entertainment = clamp(float(cfg.get_value("cat", "entertainment", entertainment)), 0.0, 100.0)
	affection = clamp(float(cfg.get_value("cat", "affection", affection)), 0.0, 100.0)
	bladder = clamp(float(cfg.get_value("cat", "bladder", bladder)), 0.0, 100.0)

	poop_in_litterbox = int(cfg.get_value("world", "poop_in_litterbox", poop_in_litterbox))
	playroom_difficulty = float(cfg.get_value("world", "playroom_difficulty", playroom_difficulty))

	var last_played := float(cfg.get_value("meta", "last_played_unix", 0.0))
	if last_played > 0.0:
		_apply_offline_decay(Time.get_unix_time_from_system() - last_played)


## Ages the cat by `seconds` of real time spent with the game closed.
func _apply_offline_decay(seconds: float) -> void:
	if seconds <= MIN_OFFLINE_SECONDS:
		return # a quick restart or a page refresh should not cost anything

	var hours := minf(seconds / 3600.0, MAX_OFFLINE_HOURS)

	var old_hunger: float = hunger
	var old_cleanliness: float = cleanliness
	var old_entertainment: float = entertainment
	var old_affection: float = affection
	var old_energy: float = energy
	var old_mood: float = mood

	hunger = clamp(hunger - OFFLINE_HUNGER_PER_HOUR * hours, 0.0, 100.0)
	cleanliness = clamp(cleanliness - OFFLINE_CLEANLINESS_PER_HOUR * hours, 0.0, 100.0)
	entertainment = clamp(entertainment - OFFLINE_ENTERTAINMENT_PER_HOUR * hours, 0.0, 100.0)
	affection = clamp(affection - OFFLINE_AFFECTION_PER_HOUR * hours, 0.0, 100.0)
	# The one stat that improves while you are gone: the cat is asleep.
	energy = clamp(energy + OFFLINE_ENERGY_PER_HOUR * hours, 0.0, 100.0)

	# Bladder wraps the same way it does in cat_hub.gd: each time it empties the
	# cat has an accident and cleanliness takes the hit. Capped so that coming
	# back after a long trip is a mess to clean up, not an unwinnable state.
	var drained := OFFLINE_BLADDER_PER_HOUR * hours
	var accidents := 0
	while drained > 0.0 and drained >= bladder and accidents < OFFLINE_MAX_ACCIDENTS:
		drained -= bladder
		bladder = 100.0
		cleanliness = maxf(0.0, cleanliness - OFFLINE_ACCIDENT_CLEANLINESS_COST)
		accidents += 1
	bladder = clamp(bladder - drained, 0.0, 100.0)

	# Mood eases toward neutral instead of free-falling, so an abandoned cat is
	# not miserable forever but also does not keep the 95-mood secret scene
	# unlocked for free.
	var drift := OFFLINE_MOOD_DRIFT_PER_HOUR * hours
	if mood > NEUTRAL_MOOD:
		mood = maxf(NEUTRAL_MOOD, mood - drift)
	else:
		mood = minf(NEUTRAL_MOOD, mood + drift)

	offline_summary = {
		"hours_away": hours,
		"was_capped": (seconds / 3600.0) > MAX_OFFLINE_HOURS,
		"accidents": accidents,
		"hunger_lost": old_hunger - hunger,
		"cleanliness_lost": old_cleanliness - cleanliness,
		"entertainment_lost": old_entertainment - entertainment,
		"affection_lost": old_affection - affection,
		"energy_gained": energy - old_energy,
		"mood_change": mood - old_mood,
	}


## Wipes the save and restores the starting stats. Wire this to a "new game"
## button if you ever add one.
func reset_save() -> void:
	mood = 50
	hunger = 30
	energy = 80
	cleanliness = 95
	entertainment = 50
	affection = 40
	bladder = 100
	poop_in_litterbox = 0
	playroom_difficulty = 0.15
	offline_summary = {}

	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove(SAVE_PATH)
