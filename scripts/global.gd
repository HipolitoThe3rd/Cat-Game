## Global variables
extends Node

@onready var web_version = true # whether or not this is the web version

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

# Which skin the Cat has active, which affects his coloring
# CRISPY is the default skin
enum skins { CRISPY, COLTRANE }
var skin = skins.CRISPY

# Each skin is a folder of sprites sharing a filename prefix, e.g.
# crispy_walk_0.png <-> Coltrane_walk_0.png. Scenes are authored with Crispy's
# sprites and swapped to the active skin as their nodes enter the tree.
const SKIN_FOLDERS := {
	skins.CRISPY: "res://sprites/skins/Crispy/",
	skins.COLTRANE: "res://sprites/skins/Coltrane/",
}
const SKIN_PREFIXES := {
	skins.CRISPY: "crispy",
	skins.COLTRANE: "Coltrane",
}

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

	# Reskin every cat sprite as it is spawned, in whatever room it lives in.
	get_tree().node_added.connect(_apply_skin_to_node)
	# Console is autoloaded after us, so wait for it before registering.
	_register_skin_commands.call_deferred()


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
## Skins
## ---------------------------------------------------------------------------

func _register_skin_commands() -> void:
	Console.add_command("charles", set_skin.bind(skins.CRISPY))
	Console.add_command("051426", set_skin.bind(skins.COLTRANE))


## Switches the cat's skin, reskins the current room immediately, and saves so
## the choice survives restarts.
func set_skin(new_skin: skins) -> void:
	skin = new_skin
	print("Cat's skin changed to %s" % SKIN_PREFIXES[skin])
	_apply_skin_recursive(get_tree().root)
	save_game()


## Returns the active skin's version of a skinned texture. Textures that are not
## part of any skin (backgrounds, icons, etc.) are returned unchanged, as are
## sprites the active skin has no version of.
func skinned_texture(tex: Texture2D) -> Texture2D:
	if tex == null:
		return tex
	var path := tex.resource_path
	for s in SKIN_FOLDERS:
		var prefix: String = SKIN_FOLDERS[s] + SKIN_PREFIXES[s]
		if not path.begins_with(prefix):
			continue
		if s == skin:
			return tex
		var suffix := path.substr(prefix.length()) # e.g. "_walk_0.png"
		var target: String = SKIN_FOLDERS[skin] + SKIN_PREFIXES[skin] + suffix
		if ResourceLoader.exists(target):
			return load(target)
		# Fall back to the default skin rather than leave a stale one showing.
		var fallback: String = SKIN_FOLDERS[skins.CRISPY] + SKIN_PREFIXES[skins.CRISPY] + suffix
		return load(fallback) if ResourceLoader.exists(fallback) else tex
	return tex


func _apply_skin_recursive(node: Node) -> void:
	_apply_skin_to_node(node)
	for child in node.get_children():
		_apply_skin_recursive(child)


func _apply_skin_to_node(node: Node) -> void:
	if node is Sprite2D:
		node.texture = skinned_texture(node.texture)
	elif node is TextureButton:
		node.texture_normal = skinned_texture(node.texture_normal)
		node.texture_pressed = skinned_texture(node.texture_pressed)
		node.texture_hover = skinned_texture(node.texture_hover)
		node.texture_disabled = skinned_texture(node.texture_disabled)
		node.texture_focused = skinned_texture(node.texture_focused)
	elif node is AnimatedSprite2D:
		_apply_skin_to_frames(node.sprite_frames)
	elif node is AnimationPlayer:
		_apply_skin_to_animations(node)


func _apply_skin_to_frames(frames: SpriteFrames) -> void:
	if frames == null:
		return
	for anim in frames.get_animation_names():
		for i in frames.get_frame_count(anim):
			frames.set_frame(anim, i, skinned_texture(frames.get_frame_texture(anim, i)),
					frames.get_frame_duration(anim, i))


# Animation keys hold the textures directly, so they need swapping too or the
# first animation that plays would put the old skin straight back.
func _apply_skin_to_animations(player: AnimationPlayer) -> void:
	for anim_name in player.get_animation_list():
		var anim := player.get_animation(anim_name)
		for track in anim.get_track_count():
			if anim.track_get_type(track) != Animation.TYPE_VALUE:
				continue
			for key in anim.track_get_key_count(track):
				var value = anim.track_get_key_value(track, key)
				if value is Texture2D:
					anim.track_set_key_value(track, key, skinned_texture(value))


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

	cfg.set_value("cosmetic", "skin", skin)

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

	var saved_skin := int(cfg.get_value("cosmetic", "skin", skin))
	skin = saved_skin if saved_skin in skins.values() else skins.CRISPY

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
