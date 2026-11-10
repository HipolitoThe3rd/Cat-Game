## Player options, kept apart from the save so they belong to the device rather
## than to the cat (logging in or out does not change them). Applied at startup
## and whenever the options room changes something.
extends Node

const PATH := "user://settings.cfg"

const DEFAULTS := {
	"master_volume": 1.0, # 0 to 1
	"muted": false,
	"fullscreen": false,
	"vsync": true,
	"check_updates": true,
}

var master_volume: float = DEFAULTS.master_volume
var muted: bool = DEFAULTS.muted
var fullscreen: bool = DEFAULTS.fullscreen
var vsync: bool = DEFAULTS.vsync
var check_updates: bool = DEFAULTS.check_updates


# Loaded as soon as the autoload is created rather than in _ready, so other
# autoloads (the update checker) see the saved values whatever order they load in.
func _init() -> void:
	load_settings()


func _ready() -> void:
	apply()


## Window options only mean something in a desktop window.
func is_desktop() -> bool:
	return not OS.has_feature("web") and not OS.has_feature("mobile") \
		and DisplayServer.get_name() != "headless"


func apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(bus, muted or master_volume <= 0.0)

	if is_desktop():
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in DEFAULTS:
		cfg.set_value("options", key, get(key))
	cfg.save(PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in DEFAULTS:
		var value = cfg.get_value("options", key, DEFAULTS[key])
		# Ignore anything of the wrong type rather than break on a bad file.
		if typeof(value) == typeof(DEFAULTS[key]) \
				or (DEFAULTS[key] is float and value is int):
			set(key, value)
	master_volume = clampf(master_volume, 0.0, 1.0)


## Changes one option, applies it and saves.
func change(key: String, value) -> void:
	set(key, value)
	apply()
	save_settings()


func reset_to_defaults() -> void:
	for key in DEFAULTS:
		set(key, DEFAULTS[key])
	apply()
	save_settings()
