## "Log in with Discord" and cloud saves, through the account API on the Steel
## Fish Studios website (netlify/functions/account-api.mjs there).
##
## Without a login the game saves to this device only, as it always has. Once
## logged in, the game switches to the account's own save, uploads it a minute
## or so after it changes, and downloads it on startup, so progress (letters
## included) follows the player to any device. The account's mail account
## (friend code and mailbox) follows too. Logging out brings the device's own
## save back.
extends Node

var api_url := "https://steelfishstudios.com/api/account/" # tests point this at a local server
const LOGIN_FILE := "user://account_login.cfg" # a login waiting on the browser
const UPLOAD_DELAY := 60.0 # seconds between uploads while the save keeps changing
const RETRY_DELAY := 30.0 # after a failed upload, e.g. while offline
const LOGIN_POLL_INTERVAL := 3.0

## Logged in or out, a login started, finished or failed, or the supporter
## tier changed. UI listens to this.
signal changed

# Backer tiers, from roles in the Steel Fish Studios Discord server that
# Ko-fi, Patreon and SubscribeStar hand out (netlify/lib/supporter.mjs on the
# website). Index = tier; 0 is not a supporter.
enum Tier { NONE, BRONZE_GUPPY, SILVER_BASS, GOLDEN_SHARK, PLATINUM_RAY }
const TIER_NAMES := ["", "Bronze Guppy", "Silver Bass", "Golden Shark", "Platinum Ray"]
const TIER_COLORS := [Color.WHITE, Color("cd7f32"), Color("c0c8d0"), Color("ffcc33"), Color("b8f0ff")]

var account_id := ""
var session := ""
var display_name := ""
var username := ""
var avatar_url := ""
# Decided by the website, never by the game, so it can't be edited into a
# save. Re-checked on launch and when the account panel opens.
var supporter_tier: int = Tier.NONE
var in_discord_server := false

# Login in progress: show login_code in the game, then send the player to
# login_url. login_error explains the last failed attempt.
var login_code := ""
var login_url := ""
var login_error := ""
var _login_id := ""
var _poll_secret := ""
var _login_expires_unix := 0.0
var _login_poll_countdown := 0.0

# The cloud save revision the local save is based on, and whether the local
# save has changed since it was last uploaded.
var _revision := 0
var _dirty := false
var _mail_linked := false
var _upload_countdown := -1.0 # < 0: nothing waiting to upload
var _uploading := false
var _busy_login := false


## DEFAULT FUNCTIONS
func _ready() -> void:
	_load()
	_load_pending_login()
	Global.game_saved.connect(_on_game_saved)
	MailClient.registered.connect(_on_mail_registered)
	if is_logged_in():
		MailClient.use_account_file(_mail_path())
		_startup_sync()


func _process(delta: float) -> void:
	if _upload_countdown >= 0.0:
		_upload_countdown -= delta
		if _upload_countdown < 0.0:
			_upload()

	if is_logging_in() and not _busy_login:
		_login_poll_countdown -= delta
		if _login_poll_countdown <= 0.0:
			_login_poll_countdown = LOGIN_POLL_INTERVAL
			_poll_login()


## CUSTOM FUNCTIONS
func is_logged_in() -> bool:
	return not session.is_empty()


func is_logging_in() -> bool:
	return not _login_id.is_empty()


## Whether the player backs us at min_tier or above. Use this to unlock
## supporter perks; items already earned should stay theirs even after it
## turns false.
func is_supporter(min_tier: int = Tier.BRONZE_GUPPY) -> bool:
	return is_logged_in() and supporter_tier >= min_tier


func tier_name(tier: int = supporter_tier) -> String:
	return TIER_NAMES[clampi(tier, 0, TIER_NAMES.size() - 1)]


func tier_color(tier: int = supporter_tier) -> Color:
	return TIER_COLORS[clampi(tier, 0, TIER_COLORS.size() - 1)]


## Asks the website for the current tier. With force, it checks with Discord
## even if it did so recently (the website allows that once a minute), e.g.
## for a player who has just started backing us.
func refresh_supporter(force := false) -> void:
	if not is_logged_in():
		return
	var res := await _request(HTTPClient.METHOD_GET, "supporter" + ("?refresh=1" if force else ""))
	if res.ok:
		_set_supporter(res.data)


## Asks the website for a login. On success login_code and login_url are set;
## show the code, then call open_login_page() from a button press.
func start_login() -> void:
	if is_logged_in() or is_logging_in() or _busy_login:
		return
	login_error = ""
	if not Global.save_available:
		_fail_login("Logging in needs the game to be able to save. Private browsing doesn't allow that.")
		return

	_busy_login = true
	var body := {}
	if OS.has_feature("web"):
		# Lets the login page bring the player back if it had to open in this tab.
		body["return_to"] = str(JavaScriptBridge.eval("window.location.href"))
	var res := await _request(HTTPClient.METHOD_POST, "login", body)
	_busy_login = false
	if not res.ok:
		_fail_login(res.error)
		return

	_login_id = str(res.data.get("login_id", ""))
	_poll_secret = str(res.data.get("poll_secret", ""))
	login_code = str(res.data.get("code", ""))
	login_url = str(res.data.get("url", ""))
	_login_expires_unix = Time.get_unix_time_from_system() + float(res.data.get("expires_in", 900))
	_login_poll_countdown = LOGIN_POLL_INTERVAL
	_save_pending_login()
	changed.emit()


## Opens the Discord login in the browser. Call it straight from a button press:
## browsers only allow new tabs right after a click.
func open_login_page() -> void:
	if login_url.is_empty():
		return
	if not OS.has_feature("web"):
		OS.shell_open(login_url)
		return
	var url_js := JSON.stringify(login_url)
	if not JavaScriptBridge.eval("!!window.open(%s, '_blank')" % url_js):
		# Pop-up blocked: go in this tab instead. The login is saved, so the game
		# picks it back up when the login page sends the player back.
		Global.save_game()
		JavaScriptBridge.eval("window.location.href = %s" % url_js)


func cancel_login() -> void:
	_clear_pending_login()
	changed.emit()


## Uploads anything unsaved, then goes back to this device's own save.
func logout() -> void:
	if not is_logged_in():
		return
	if _dirty:
		Global.save_game()
		await _upload()
	_request(HTTPClient.METHOD_POST, "logout") # best effort; the token is dropped either way
	_drop_account()


## Uploads right away instead of waiting for the timer.
func sync_now() -> void:
	if is_logged_in():
		Global.save_game()
		await _upload()


func _poll_login() -> void:
	if Time.get_unix_time_from_system() > _login_expires_unix:
		_fail_login("The login timed out. Please try again.")
		return
	_busy_login = true
	var res := await _request(HTTPClient.METHOD_GET, "login/poll?login=" + _login_id.uri_encode(),
		null, ["X-Login-Secret: " + _poll_secret])
	_busy_login = false
	if not is_logging_in():
		return # cancelled while waiting

	var status := str(res.data.get("status", ""))
	if res.code == 404 or status == "expired":
		_fail_login("The login timed out. Please try again.")
	elif status == "denied":
		_fail_login("The login was cancelled.")
	elif status == "done":
		_clear_pending_login()
		await _finish_login(res.data)
	# Anything else (pending, or offline for a moment): keep polling.


func _finish_login(data: Dictionary) -> void:
	_busy_login = true
	session = str(data.get("session", ""))
	_set_profile(data.get("account", {}))

	var cloud := await _request(HTTPClient.METHOD_GET, "save")
	if not cloud.ok:
		session = ""
		account_id = ""
		_busy_login = false
		_fail_login("Logged in, but couldn't load your save: %s" % cloud.error)
		return

	var save_text = cloud.data.get("save")
	if save_text is String and not save_text.is_empty():
		# The account already has progress: use it. This device's own save stays
		# as it is, for when the player logs out.
		var cfg := ConfigFile.new()
		if cfg.parse(save_text) == OK:
			Global.switch_save(Global.account_save_path(account_id), cfg)
		else:
			Global.switch_save(Global.account_save_path(account_id))
		_revision = int(cloud.data.get("revision", 0))
		_dirty = false
		_upload_countdown = -1.0 # switch_save() saved, but nothing changed yet
		_save()
		await _link_mail({})
	else:
		# A new account: offer to bring this device's progress (letters and
		# friend code included) along.
		var bring: bool = await _ask_bring_progress()
		var device_mail := MailClient.credentials() if bring else {}
		if bring:
			Global.switch_save(Global.account_save_path(account_id), Global.build_save())
		else:
			Global.switch_save(Global.account_save_path(account_id))
		_revision = 0
		_dirty = true
		_save()
		await _link_mail(device_mail)
		if bring and _mail_linked:
			# The friend code now belongs to the account, so the device gets a new
			# one of its own the next time someone plays here logged out.
			DirAccess.remove_absolute(MailClient.ACCOUNT_PATH)
		await _upload()

	_busy_login = false
	changed.emit()


## On launch while logged in: whichever of the local and cloud save is newer wins.
func _startup_sync() -> void:
	var cloud := await _request(HTTPClient.METHOD_GET, "save")
	if not cloud.ok:
		if _dirty:
			_upload_countdown = RETRY_DELAY # offline; try again later
		return

	var cloud_revision := int(cloud.data.get("revision", 0))
	if cloud_revision > _revision:
		var local_unix := FileAccess.get_modified_time(Global.save_path)
		var cloud_unix := float(cloud.data.get("updated_unix", 0.0))
		var cfg := ConfigFile.new()
		if not _dirty or cloud_unix > local_unix:
			if cfg.parse(str(cloud.data.get("save", ""))) == OK:
				Global.switch_save(Global.save_path, cfg)
				_revision = cloud_revision
				_dirty = false
				_upload_countdown = -1.0
				_save()
		else:
			# Played offline here after the other device last saved: keep this one.
			_revision = cloud_revision
			_upload()
	elif _dirty or cloud_revision == 0:
		_upload()

	if not _mail_linked:
		_link_mail(MailClient.credentials())
	refresh_supporter() # a lapsed or new backer is noticed on the next launch


func _upload() -> void:
	if not is_logged_in() or _uploading:
		return
	_uploading = true
	_upload_countdown = -1.0
	var res := {}
	for attempt in 2:
		var cfg := Global.build_save()
		res = await _request(HTTPClient.METHOD_POST, "save", {
			"save": cfg.encode_to_text(),
			"base_revision": _revision,
			"summary": Global.save_summary(),
		})
		if res.code == 409:
			# Another device saved since. This is the one being played right now,
			# so its progress wins.
			_revision = int(res.data.get("revision", _revision))
			continue
		break
	_uploading = false

	if res.ok:
		_revision = int(res.data.get("revision", _revision))
		_dirty = false
		_save()
	elif is_logged_in():
		_upload_countdown = RETRY_DELAY


## Ties a mail account to the login: the account's own if it has one,
## otherwise the one passed in. With none, MailClient registers a new one and
## _on_mail_registered() links it.
func _link_mail(device_mail: Dictionary) -> void:
	var res := await _request(HTTPClient.METHOD_POST, "mail", device_mail)
	if not res.ok:
		MailClient.use_account_file(_mail_path())
		return
	if res.data.has("player_id"):
		MailClient.use_credentials(_mail_path(), res.data)
		_mail_linked = true
		_save()
	else:
		MailClient.use_account_file(_mail_path())


func _on_mail_registered() -> void:
	if is_logged_in() and not _mail_linked and not _busy_login \
			and MailClient.account_path == _mail_path():
		_link_mail(MailClient.credentials())


func _on_game_saved(_cfg: ConfigFile) -> void:
	if not is_logged_in():
		return
	if not _dirty:
		_dirty = true
		_save()
	if _upload_countdown < 0.0 and not _uploading:
		_upload_countdown = UPLOAD_DELAY


func _ask_bring_progress() -> bool:
	var summary := Global.save_summary()
	var dialog := ConfirmationDialog.new()
	dialog.title = "Welcome, %s!" % display_name
	dialog.dialog_text = ("Bring this device's progress to your account?\n\n"
		+ "Kitcoins: %d    Letters: %d\n\n" % [summary.kitcoins, summary.letters]
		+ "Either way, this device keeps its own copy for when you're logged out.")
	dialog.dialog_autowrap = true
	dialog.ok_button_text = "Bring it"
	dialog.get_cancel_button().visible = false
	dialog.add_button("Start fresh", true, "fresh")
	dialog.add_user_signal("closed")
	dialog.custom_action.connect(func(_action): dialog.set_meta("fresh", true))
	dialog.custom_action.connect(func(_action): dialog.emit_signal("closed"))
	# Closing the window counts as "Bring it", the choice that loses nothing.
	dialog.confirmed.connect(dialog.emit_signal.bind("closed"))
	dialog.canceled.connect(dialog.emit_signal.bind("closed"))
	var layer := CanvasLayer.new()
	layer.layer = 20
	get_tree().root.add_child(layer)
	layer.add_child(dialog)
	dialog.popup_centered(Vector2i(520, 0))
	await Signal(dialog, "closed")
	var fresh: bool = dialog.get_meta("fresh", false)
	layer.queue_free()
	return not fresh


## Logged out, or the server no longer knows the session.
func _drop_account() -> void:
	var old_account := account_id
	session = ""
	account_id = ""
	display_name = ""
	username = ""
	avatar_url = ""
	supporter_tier = Tier.NONE
	in_discord_server = false
	_revision = 0
	_dirty = false
	_mail_linked = false
	_upload_countdown = -1.0
	DirAccess.remove_absolute(Global.ACCOUNT_FILE)
	# The account's copies on this device go too, so the next person to use it
	# doesn't see them. Everything is in the cloud.
	if not old_account.is_empty():
		DirAccess.remove_absolute(Global.account_save_path(old_account))
		DirAccess.remove_absolute(_mail_path(old_account))
	Global.switch_save(Global.SAVE_PATH)
	MailClient.use_account_file(MailClient.ACCOUNT_PATH)
	changed.emit()


func _fail_login(message: String) -> void:
	_clear_pending_login()
	login_error = message
	changed.emit()


func _set_profile(profile) -> void:
	if not profile is Dictionary:
		return
	account_id = str(profile.get("account_id", account_id))
	display_name = str(profile.get("display_name", display_name))
	username = str(profile.get("username", username))
	avatar_url = str(profile.get("avatar_url", avatar_url))
	_set_supporter(profile.get("supporter"))


func _set_supporter(status) -> void:
	if not status is Dictionary:
		return
	var tier := clampi(int(status.get("tier", 0)), 0, TIER_NAMES.size() - 1)
	var in_server := bool(status.get("in_server", false))
	if tier == supporter_tier and in_server == in_discord_server:
		return
	supporter_tier = tier
	in_discord_server = in_server
	_save()
	changed.emit()


func _mail_path(id := account_id) -> String:
	return "user://mail_%s.cfg" % id.validate_filename()


## Makes one API call and returns {ok, code, data, error}.
func _request(method: HTTPClient.Method, action: String, body = null,
		extra_headers: Array = []) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)

	var headers := PackedStringArray(["Content-Type: application/json"])
	if is_logged_in():
		headers.append("X-Session: " + session)
	headers.append_array(extra_headers)

	var err := http.request(api_url + action, headers, method,
		JSON.stringify(body) if body != null else "")
	if err != OK:
		http.queue_free()
		return {"ok": false, "code": 0, "data": {}, "error": "Couldn't reach the server."}

	var result: Array = await http.request_completed
	http.queue_free()
	var code: int = result[1]
	var parsed = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	var data: Dictionary = parsed if parsed is Dictionary else {}

	if result[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": 0, "data": data, "error": "Couldn't reach the server."}
	if code == 401 and is_logged_in():
		push_warning("Cat Game: session rejected; logging out.")
		_drop_account()
	if code < 200 or code >= 300:
		return {"ok": false, "code": code, "data": data,
			"error": str(data.get("error", "Something went wrong (%d)." % code))}
	return {"ok": true, "code": code, "data": data, "error": ""}


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(Global.ACCOUNT_FILE) != OK:
		return
	account_id = str(cfg.get_value("account", "account_id", ""))
	session = str(cfg.get_value("account", "session", ""))
	display_name = str(cfg.get_value("account", "display_name", ""))
	username = str(cfg.get_value("account", "username", ""))
	avatar_url = str(cfg.get_value("account", "avatar_url", ""))
	supporter_tier = int(cfg.get_value("account", "supporter_tier", Tier.NONE))
	in_discord_server = bool(cfg.get_value("account", "in_discord_server", false))
	_revision = int(cfg.get_value("sync", "revision", 0))
	_dirty = bool(cfg.get_value("sync", "dirty", false))
	_mail_linked = bool(cfg.get_value("sync", "mail_linked", false))
	if account_id.is_empty() or session.is_empty():
		session = ""
		account_id = ""


func _save() -> void:
	if not is_logged_in():
		return
	var cfg := ConfigFile.new()
	cfg.set_value("account", "account_id", account_id)
	cfg.set_value("account", "session", session)
	cfg.set_value("account", "display_name", display_name)
	cfg.set_value("account", "username", username)
	cfg.set_value("account", "avatar_url", avatar_url)
	cfg.set_value("account", "supporter_tier", supporter_tier)
	cfg.set_value("account", "in_discord_server", in_discord_server)
	cfg.set_value("sync", "revision", _revision)
	cfg.set_value("sync", "dirty", _dirty)
	cfg.set_value("sync", "mail_linked", _mail_linked)
	if cfg.save(Global.ACCOUNT_FILE) != OK:
		push_warning("Cat Game: could not save login.")


func _save_pending_login() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("login", "id", _login_id)
	cfg.set_value("login", "poll_secret", _poll_secret)
	cfg.set_value("login", "code", login_code)
	cfg.set_value("login", "url", login_url)
	cfg.set_value("login", "expires_unix", _login_expires_unix)
	cfg.save(LOGIN_FILE)


## A web login that had to leave the page comes back here after a reload.
func _load_pending_login() -> void:
	var cfg := ConfigFile.new()
	if is_logged_in() or cfg.load(LOGIN_FILE) != OK:
		return
	_login_expires_unix = float(cfg.get_value("login", "expires_unix", 0.0))
	if Time.get_unix_time_from_system() > _login_expires_unix:
		DirAccess.remove_absolute(LOGIN_FILE)
		return
	_login_id = str(cfg.get_value("login", "id", ""))
	_poll_secret = str(cfg.get_value("login", "poll_secret", ""))
	login_code = str(cfg.get_value("login", "code", ""))
	login_url = str(cfg.get_value("login", "url", ""))


func _clear_pending_login() -> void:
	_login_id = ""
	_poll_secret = ""
	login_code = ""
	login_url = ""
	_login_expires_unix = 0.0
	DirAccess.remove_absolute(LOGIN_FILE)
