## Talks to the player mail API on the Steel Fish Studios website
## (netlify/functions/mail-api.mjs there). Registers this install once, then
## polls for letters from other players and drops them into Global's inbox.
extends Node

var api_url := "https://steelfishstudios.com/api/mail/" # tests point this at a local server
const ACCOUNT_PATH := "user://mail_account.cfg" # without a login; see use_account_file()
const POLL_INTERVAL := 120.0 # seconds between inbox checks while playing
const RETRY_INTERVAL := 30.0 # after a failed request, e.g. while offline

# Kept apart from the main save, so a save reset or a SAVE_VERSION bump never
# loses the player's mailbox or friend code.
var player_id := ""
var secret := ""
var friend_code := ""
var display_name := ""
# Friend codes this player blocked. The server is what actually stops their
# letters; this copy is just so the inbox knows to offer "Unblock".
var blocked_codes: Array = []

# Fires once this install has a friend code, e.g. for a compose screen that was
# opened while offline.
signal registered

var _busy := false
var _poll_countdown := 0.0 # check right away on launch
# A logged-in player's mail account is kept in its own file (Account picks it),
# so the device's own friend code comes back on logging out.
var account_path := ACCOUNT_PATH


## DEFAULT FUNCTIONS
func _ready() -> void:
	_load_account()
	# Console is autoloaded after us, so wait for it before registering.
	_register_commands.call_deferred()


func _process(delta: float) -> void:
	_poll_countdown -= delta
	if _poll_countdown <= 0.0 and not _busy:
		_poll_countdown = POLL_INTERVAL
		_sync()


## CUSTOM FUNCTIONS
func is_registered() -> bool:
	return not player_id.is_empty()


## Switches to the mail account stored at path, registering a new one on the
## next check if there is none there yet.
func use_account_file(path: String) -> void:
	_forget_account()
	account_path = path
	_load_account()
	_poll_countdown = 0.0
	if is_registered():
		registered.emit()


## Adopts a mail account handed over by the account server.
func use_credentials(path: String, data: Dictionary) -> void:
	_forget_account()
	account_path = path
	player_id = str(data.get("player_id", ""))
	secret = str(data.get("secret", ""))
	friend_code = str(data.get("friend_code", ""))
	display_name = str(data.get("display_name", ""))
	_save_account()
	_poll_countdown = 0.0
	registered.emit()


func credentials() -> Dictionary:
	return {"player_id": player_id, "secret": secret} if is_registered() else {}


## Sends a letter to another player's friend code. Returns "" on success, or an
## error message fit to show the player.
func send(to_code: String, subject: String, body: String) -> String:
	if not is_registered():
		return "Mail isn't set up yet. Check your internet connection."
	var res := await _request(HTTPClient.METHOD_POST, "send",
		{"to": to_code, "subject": subject, "body": body})
	return "" if res.ok else res.error


func is_blocked(code: String) -> bool:
	return blocked_codes.has(code)


## Stops letters from a friend code. Returns "" on success or an error message.
func block(code: String) -> String:
	var res := await _request(HTTPClient.METHOD_POST, "block", {"code": code})
	if not res.ok:
		return res.error
	if not blocked_codes.has(code):
		blocked_codes.append(code)
		_save_account()
	return ""


func unblock(code: String) -> String:
	var res := await _request(HTTPClient.METHOD_POST, "unblock", {"code": code})
	if not res.ok:
		return res.error
	blocked_codes.erase(code)
	_save_account()
	return ""


## Sends a letter to Steel Fish Studios for review; the server also blocks its
## sender. Only letters fetched from the server (which carry a "sig") can be
## reported. Returns "" on success or an error message.
func report(letter: Dictionary) -> String:
	if not can_report(letter):
		return "This letter can't be reported."
	var res := await _request(HTTPClient.METHOD_POST, "report", {"letter": {
		"id": letter["server_id"],
		"from_code": letter.get("from_code", ""),
		"from_name": letter.get("from", ""),
		"subject": letter.get("subject", ""),
		"body": letter.get("body", ""),
		"sig": letter["sig"],
	}})
	if not res.ok:
		return res.error
	var code := str(letter.get("from_code", ""))
	if not blocked_codes.has(code):
		blocked_codes.append(code)
		_save_account()
	return ""


func can_report(letter: Dictionary) -> bool:
	return letter.has("server_id") and not str(letter.get("sig", "")).is_empty()


## Registers if needed, then pulls new letters into the inbox.
func _sync() -> void:
	# On storage that is wiped when the tab closes (private browsing), a new
	# account would be made every session, so mail is left off there.
	if not Global.save_available:
		return
	_busy = true
	if not is_registered():
		await _register()
	if is_registered():
		await _fetch_inbox()
	_busy = false


func _register() -> void:
	var res := await _request(HTTPClient.METHOD_POST, "register", {})
	if not res.ok:
		_poll_countdown = RETRY_INTERVAL
		return
	player_id = str(res.data.get("player_id", ""))
	secret = str(res.data.get("secret", ""))
	friend_code = str(res.data.get("friend_code", ""))
	display_name = str(res.data.get("display_name", ""))
	_save_account()
	registered.emit()


func _fetch_inbox() -> void:
	var res := await _request(HTTPClient.METHOD_GET, "inbox")
	if not res.ok:
		_poll_countdown = RETRY_INTERVAL
		return

	var letters = res.data.get("letters", [])
	if not letters is Array or letters.is_empty():
		return

	var ids: Array = []
	for item in letters:
		if not item is Dictionary or not item.has("id"):
			continue
		var server_id := str(item["id"])
		ids.append(server_id)
		# Already saved on a previous fetch whose ack never reached the server.
		if _has_letter(server_id):
			continue
		var letter := Global.receive_mail(Global.mail_kinds.PLAYER,
			str(item.get("from_name", "")), str(item.get("subject", "")),
			str(item.get("body", "")))
		letter["server_id"] = server_id
		letter["from_code"] = str(item.get("from_code", ""))
		letter["sent_unix"] = float(item.get("sent_unix", letter["sent_unix"]))
		letter["sig"] = str(item.get("sig", "")) # proves the letter's text if it is reported
		letter["from_tier"] = int(item.get("from_tier", 0)) # sender's supporter tier, for a badge

	# Save before acking: the ack deletes the letters from the server, so they
	# have to be on disk first or a closed tab would lose them.
	Global.save_game()
	if Global.save_available and not ids.is_empty():
		await _request(HTTPClient.METHOD_POST, "ack", {"ids": ids})


func _has_letter(server_id: String) -> bool:
	for letter in Global.mail:
		if letter.get("server_id", "") == server_id:
			return true
	return false


## Makes one API call and returns {ok, data, error}. Never fails loudly: mail is
## a bonus, so being offline just means trying again later.
func _request(method: HTTPClient.Method, action: String, body = null) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)

	var headers := PackedStringArray(["Content-Type: application/json"])
	if is_registered():
		headers.append("X-Player-Id: " + player_id)
		headers.append("X-Player-Secret: " + secret)

	var err := http.request(api_url + action, headers, method,
		JSON.stringify(body) if body != null else "")
	if err != OK:
		http.queue_free()
		return {"ok": false, "data": {}, "error": "Couldn't reach the mail server."}

	var result: Array = await http.request_completed
	http.queue_free()
	var code: int = result[1]
	var parsed = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	var data: Dictionary = parsed if parsed is Dictionary else {}

	if result[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "data": data, "error": "Couldn't reach the mail server."}
	if code == 401 and action != "register":
		# The server no longer knows this account, so start over with a new one.
		push_warning("Cat Game: mail account rejected; registering again.")
		_forget_account()
	if code < 200 or code >= 300:
		return {"ok": false, "data": data,
			"error": str(data.get("error", "Something went wrong (%d)." % code))}
	return {"ok": true, "data": data, "error": ""}


func _load_account() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(account_path) != OK:
		return
	player_id = str(cfg.get_value("account", "player_id", ""))
	secret = str(cfg.get_value("account", "secret", ""))
	friend_code = str(cfg.get_value("account", "friend_code", ""))
	display_name = str(cfg.get_value("account", "display_name", ""))
	var saved_blocked = cfg.get_value("account", "blocked_codes", [])
	blocked_codes = saved_blocked if saved_blocked is Array else []
	if player_id.is_empty() or secret.is_empty():
		_forget_account()


func _save_account() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("account", "player_id", player_id)
	cfg.set_value("account", "secret", secret)
	cfg.set_value("account", "friend_code", friend_code)
	cfg.set_value("account", "display_name", display_name)
	cfg.set_value("account", "blocked_codes", blocked_codes)
	if cfg.save(account_path) != OK:
		push_warning("Cat Game: could not save mail account.")


func _forget_account() -> void:
	player_id = ""
	secret = ""
	friend_code = ""
	display_name = ""
	blocked_codes = [] # blocks belonged to the old account


# Debug helpers for testing mail without going through the inbox.
func _register_commands() -> void:
	Console.add_command("mail_code", _cmd_mail_code)
	Console.add_command("mail_check", func(): _poll_countdown = 0.0)
	Console.add_command("mail_send", _cmd_mail_send, ["friend_code", "\"body\""], 2)


func _cmd_mail_code() -> void:
	Console.print_line(friend_code if is_registered() else "Not registered yet.")


func _cmd_mail_send(to_code: String, body: String) -> void:
	var error := await send(to_code, "Hello", body)
	Console.print_line("Sent!" if error.is_empty() else error)
