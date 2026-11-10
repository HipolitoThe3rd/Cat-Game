## Asks steelfishstudios.com whether a newer build is out and, if so, offers to
## open the itch.io page. The version file is written by the release workflow
## (.github/workflows/release.yml) after each build reaches itch.
##
## Skipped on the web build (it is always the latest) and in the editor (there
## is nothing to download). Being offline just means no popup.
extends Node

signal update_available(latest: String, url: String)

const VERSION_URL := "https://steelfishstudios.com/games/crispy-the-cat/version.json"
const UpdateNoticeScript := preload("res://scripts/update_notice.gd")
const DEFAULT_URL := "https://steelfishstudios.itch.io/crispy-the-cat"
# version.json can only send players to our own pages.
const ALLOWED_URL_PREFIXES := [
	"https://steelfishstudios.itch.io/",
	"https://steelfishstudios.com/",
]

var current_version: String = str(ProjectSettings.get_setting("application/config/version", ""))
var latest_version := ""
var download_url := DEFAULT_URL


func _ready() -> void:
	if OS.has_feature("web") or OS.has_feature("editor") or current_version.is_empty():
		return
	check()


func check() -> void:
	var http := HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	if http.request(VERSION_URL) != OK:
		http.queue_free()
		return
	var result: Array = await http.request_completed
	http.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS or result[1] != 200:
		return

	var data = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	if not data is Dictionary:
		return
	var latest := str(data.get("version", ""))
	if not is_newer(latest, current_version):
		return

	latest_version = latest
	var url := str(data.get("url", ""))
	for prefix in ALLOWED_URL_PREFIXES:
		if url.begins_with(prefix):
			download_url = url
	update_available.emit(latest_version, download_url)
	get_tree().root.add_child(UpdateNoticeScript.new(current_version, latest_version, download_url))


## Compares dotted versions numerically, so 1.0.10 is newer than 1.0.9.
static func is_newer(candidate: String, current: String) -> bool:
	var a := candidate.split(".")
	var b := current.split(".")
	for i in maxi(a.size(), b.size()):
		var x := a[i].to_int() if i < a.size() else 0
		var y := b[i].to_int() if i < b.size() else 0
		if x != y:
			return x > y
	return false
