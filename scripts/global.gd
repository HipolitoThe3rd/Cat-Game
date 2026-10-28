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

# Touchscreens never draw a mouse cursor, so while a finger is down these are
# drawn as a sprite under it instead. Points are fractions of the image size:
#   grip - the spot on the handle the finger "holds", so the business end of
#          the tool pokes out above the fingertip rather than hiding under it
#   tip  - where the tool actually acts (the spray, the scoop, the laser dot);
#          rooms aim their hitboxes here on touchscreens via pointer_position()
const TOUCH_TOOLS := {
	"shower": {"grip": Vector2(0.78, 0.80), "tip": Vector2(0.20, 0.34)},
	"scooper": {"grip": Vector2(0.74, 0.80), "tip": Vector2(0.28, 0.22)},
	"laser": {"grip": Vector2(0.74, 0.80), "tip": Vector2(0.06, 0.05)},
}
@onready var touch_cursors := {
	cursor_shower_pour: "shower", smcursor_shower_pour: "shower",
	cursor_scooper_pressed: "scooper", smcursor_scooper_pressed: "scooper",
	cursor_laser_pressed: "laser", smcursor_laser_pressed: "laser",
}
# Used for sizing, since the hit point has to be known even on the frame a
# finger lands, before the room has swapped to the pressed cursor.
@onready var _touch_tool_textures := {
	"shower": smcursor_shower_pour,
	"scooper": smcursor_scooper_pressed,
	"laser": smcursor_laser_pressed,
}
# The full-size cursors range up to 1280px, so every touch cursor is drawn at
# this size (in game pixels, longest side) regardless of which one is active.
const TOUCH_CURSOR_SIZE := 128.0
var _touch_cursor: Sprite2D
var _touches := {} # finger index -> screen position

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

# game's currency. can be used to buy clothes, skins, furniture, toys, etc.
# a paycheck with Kitcoins is earned every week.
var kitcoins: int = 0

# Mail / paycheck system ------------------------------------------------------
# Crispy's anonymous owner pays out once per real-world Friday (local time):
# base pay plus a bonus scaled by the cat's average mood since the last payday.
const PAYDAY_WEEKDAY := 5 # Time.WEEKDAY_FRIDAY
const PAYCHECK_BASE_PAY := 50
const PAYCHECK_MAX_BONUS := 50 # paid in full at an average mood of 100
const PAYCHECK_SENDER := "Anonymous"
const MAIL_RECIPIENT := "Crispy's Caretaker"

# Oldest letters are dropped past this so the save file stays small.
const MAX_MAIL := 50

enum mail_kinds { LETTER, PAYCHECK, PLAYER }

# Each letter is a Dictionary built by receive_mail(); oldest first.
var mail: Array = []
var _next_mail_id := 1

# Start (unix, UTC) of the last payday that has been paid out. 0 means the
# mail system has not been set up yet for this save.
var last_payday_unix := 0.0

# Time-weighted running average of mood since the last payday. Covers both
# time spent playing and (via _apply_offline_decay) time spent away.
var mood_seconds := 0.0
var mood_weighted_sum := 0.0

# Rooms (a hub badge, say) can listen for this to react to new mail.
signal mail_received(letter: Dictionary)

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
	_start_mail_if_new()
	check_payday()

	# Reskin every cat sprite as it is spawned, in whatever room it lives in.
	get_tree().node_added.connect(_apply_skin_to_node)
	# Console is autoloaded after us, so wait for it before registering.
	_register_skin_commands.call_deferred()

	# Top-most layer so the cursor is never hidden behind a room's UI.
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_touch_cursor = Sprite2D.new()
	_touch_cursor.centered = false # offset is set per cursor from its grip point
	_touch_cursor.visible = false
	layer.add_child(_touch_cursor)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position


func _process(delta: float) -> void:
	_update_touch_cursor()
	_track_mood(mood, delta)

	# Autosave on a timer rather than only on quit. A browser tab can be closed
	# without ever delivering a close notification, so the timer is the real
	# safety net and the _notification() handler below is a bonus.
	_autosave_countdown -= delta
	if _autosave_countdown <= 0.0:
		_autosave_countdown = AUTOSAVE_INTERVAL
		# Piggybacks on the autosave timer so a paycheck still arrives if the
		# game is left open past midnight into Friday.
		check_payday()
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


func _update_touch_cursor() -> void:
	if _touches.is_empty() or not cursor_path in touch_cursors:
		_touch_cursor.visible = false
		return
	_touch_cursor.texture = cursor_path
	var size: Vector2 = cursor_path.get_size()
	_touch_cursor.offset = -size * TOUCH_TOOLS[touch_cursors[cursor_path]].grip
	_touch_cursor.scale = Vector2.ONE * (TOUCH_CURSOR_SIZE / maxf(size.x, size.y))
	_touch_cursor.position = _touch_position()
	_touch_cursor.visible = true


# Follows the first finger that went down.
func _touch_position() -> Vector2:
	return _touches[_touches.keys()[0]]


## Where a room should aim the tool's hitbox. With a mouse that is the mouse
## position, as before. On a touchscreen it is the tool's tip as drawn above the
## finger, minus hitbox_offset (the hitbox Area2D's offset from the node being
## positioned) so the Area2D itself lands on the tip.
func pointer_position(tool: String, hitbox_offset := Vector2.ZERO) -> Vector2:
	var viewport := get_viewport()
	if _touches.is_empty():
		return viewport.get_mouse_position()
	var size: Vector2 = _touch_tool_textures[tool].get_size()
	size *= TOUCH_CURSOR_SIZE / maxf(size.x, size.y)
	var t: Dictionary = TOUCH_TOOLS[tool]
	return _touch_position() + (t.tip - t.grip) * size - hitbox_offset


func feed_cat(hunger_amount:int = 30) -> void:
	Global.hunger = min(100, Global.hunger + hunger_amount)


## ---------------------------------------------------------------------------
## Skins
## ---------------------------------------------------------------------------

func _register_skin_commands() -> void:
	Console.add_command("charles", set_skin.bind(skins.CRISPY))
	Console.add_command("051426", set_skin.bind(skins.COLTRANE))
	# Debug helpers until the hub has a way into the inbox.
	Console.add_command("inbox", func(): get_tree().change_scene_to_file("res://scenes/inbox.tscn"))
	Console.add_command("payday", func():
		last_payday_unix = 0.0
		check_payday())


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

	cfg.set_value("wallet", "kitcoins", kitcoins)

	cfg.set_value("mail", "letters", mail)
	cfg.set_value("mail", "next_id", _next_mail_id)
	cfg.set_value("mail", "last_payday_unix", last_payday_unix)
	cfg.set_value("mail", "mood_seconds", mood_seconds)
	cfg.set_value("mail", "mood_weighted_sum", mood_weighted_sum)

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

	kitcoins = maxi(0, int(cfg.get_value("wallet", "kitcoins", kitcoins)))

	var saved_mail = cfg.get_value("mail", "letters", [])
	mail = saved_mail if saved_mail is Array else []
	_next_mail_id = int(cfg.get_value("mail", "next_id", _next_mail_id))
	last_payday_unix = float(cfg.get_value("mail", "last_payday_unix", last_payday_unix))
	mood_seconds = float(cfg.get_value("mail", "mood_seconds", mood_seconds))
	mood_weighted_sum = float(cfg.get_value("mail", "mood_weighted_sum", mood_weighted_sum))

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

	# Time away still counts toward the paycheck's average mood. Uses the real
	# absence rather than the capped one, at roughly the mood the cat drifted
	# through, so a neglected week pulls the bonus toward neutral.
	_track_mood((old_mood + mood) / 2.0, seconds)

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
	kitcoins = 0
	mail = []
	_next_mail_id = 1
	last_payday_unix = 0.0
	mood_seconds = 0.0
	mood_weighted_sum = 0.0

	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove(SAVE_PATH)

	_start_mail_if_new()


## ---------------------------------------------------------------------------
## Mail / paychecks
## ---------------------------------------------------------------------------

## Adds a letter to the inbox and returns it. Anything that delivers mail
## (paychecks now, other players later) should come through here.
func receive_mail(kind: mail_kinds, from: String, subject: String, body: String,
		kitcoins_attached: int = 0) -> Dictionary:
	var letter := {
		"id": _next_mail_id,
		"kind": kind,
		"from": from,
		"to": MAIL_RECIPIENT,
		"subject": subject,
		"body": body,
		"kitcoins": maxi(0, kitcoins_attached),
		"sent_unix": Time.get_unix_time_from_system(),
		"read": false,
		"delivered": false, # set once the inbox has been visited after it arrived
	}
	_next_mail_id += 1
	mail.append(letter)

	while mail.size() > MAX_MAIL:
		# Never let money vanish just because the inbox overflowed.
		open_mail(mail.pop_front())

	mail_received.emit(letter)
	return letter


## Marks a letter read and deposits any Kitcoins attached to it the first time
## it is opened. Returns how many Kitcoins were deposited just now.
func open_mail(letter: Dictionary) -> int:
	if letter.get("read", false):
		return 0
	letter["read"] = true
	var amount := int(letter.get("kitcoins", 0))
	kitcoins += amount
	return amount


func unread_mail_count() -> int:
	return mail.filter(func(l): return not l.get("read", false)).size()


## Mail that arrived since the inbox was last visited. The hub sends the player
## to the inbox while this is non-zero. Letters from saves made before the flag
## existed count as delivered once read.
func undelivered_mail_count() -> int:
	return mail.filter(func(l): return not l.get("delivered", l.get("read", false))).size()


## Called on entering the inbox, so backing out with letters still unread does
## not bounce the player straight back in.
func mark_mail_delivered() -> void:
	for letter in mail:
		letter["delivered"] = true


## The inbox's reading order: unread paychecks first, then other unread mail,
## then everything already read. Newest first within each group.
func sorted_mail() -> Array:
	var sorted := mail.duplicate()
	sorted.sort_custom(func(a, b):
		var ra := _mail_rank(a)
		var rb := _mail_rank(b)
		if ra != rb:
			return ra < rb
		return float(a.get("sent_unix", 0.0)) > float(b.get("sent_unix", 0.0)))
	return sorted


func _mail_rank(letter: Dictionary) -> int:
	if letter.get("read", false):
		return 2
	return 0 if int(letter.get("kind", mail_kinds.LETTER)) == mail_kinds.PAYCHECK else 1


## Sends this week's paycheck if a Friday has started since the last one.
## Missing several Fridays still pays out once, so time away is not farmed.
func check_payday() -> void:
	var payday := _current_payday_start()
	if last_payday_unix >= payday:
		return

	var average_mood := clampf(
		mood_weighted_sum / mood_seconds if mood_seconds > 0.0 else float(mood),
		0.0, 100.0)
	var bonus := roundi(PAYCHECK_MAX_BONUS * average_mood / 100.0)
	var total := PAYCHECK_BASE_PAY + bonus

	receive_mail(mail_kinds.PAYCHECK, PAYCHECK_SENDER, "Your weekly pay",
		("Thank you for taking care of Crispy this week.\n\n"
		+ "Base pay: %d Kitcoins\n" % PAYCHECK_BASE_PAY
		+ "Mood bonus: %d Kitcoins (Crispy's average mood: %d)\n\n" % [bonus, roundi(average_mood)]
		+ "Total: %d Kitcoins\n\n" % total
		+ "Please keep taking care of Crispy."),
		total)

	last_payday_unix = payday
	mood_seconds = 0.0
	mood_weighted_sum = 0.0
	save_game()


## First run of the mail system for this save: start the pay period now, so the
## first paycheck arrives on the coming Friday, and leave a note explaining it.
func _start_mail_if_new() -> void:
	if last_payday_unix > 0.0:
		return
	last_payday_unix = _current_payday_start()
	receive_mail(mail_kinds.LETTER, "???", "Crispy",
		("You came. Thank you.\n\n"
		+ "Please take care of Crispy. Keep him fed, clean and happy.\n\n"
		+ "I will send your pay here every Friday. The happier he is, "
		+ "the more you will get."))


## Unix time (UTC) of the most recent local midnight that started a payday,
## today included if today is payday.
func _current_payday_start() -> float:
	var bias := float(Time.get_time_zone_from_system().get("bias", 0)) * 60.0
	var local_now := Time.get_unix_time_from_system() + bias
	var local_midnight := floorf(local_now / 86400.0) * 86400.0
	var weekday: int = Time.get_datetime_dict_from_unix_time(int(local_now)).weekday
	var days_since := posmod(weekday - PAYDAY_WEEKDAY, 7)
	return local_midnight - days_since * 86400.0 - bias


func _track_mood(value: float, seconds: float) -> void:
	mood_weighted_sum += value * seconds
	mood_seconds += seconds
