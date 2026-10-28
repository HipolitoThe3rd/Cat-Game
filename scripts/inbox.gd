class_name Inbox
extends Node2D

@onready var back_button = $UI/BackButton
@onready var mail_panel = $UI/MailPanel
@onready var mail_body = $"UI/MailPanel/Mail Body"
@onready var counter_label = $UI/MailPanel/HBoxContainer/Counter
@onready var prev_button = $UI/MailPanel/HBoxContainer/ButtonPrev
@onready var next_button = $UI/MailPanel/HBoxContainer/ButtonNext
@onready var reply_button = $UI/MailPanel/HBoxContainer/ButtonReply
@onready var block_button = $UI/MailPanel/HBoxContainer/ButtonBlock
@onready var report_button = $UI/MailPanel/HBoxContainer/ButtonReport

# Snapshot of Global.sorted_mail() taken on entering, so opening a letter (which
# marks it read and would re-sort it) does not shuffle the pages mid-read.
var letters: Array = []
var current := 0

## DEFAULT FUNCTIONS
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Global.web_version:
		Input.set_custom_mouse_cursor(Global.smcursor_default)
	else:
		Input.set_custom_mouse_cursor(Global.cursor_default)

	# Hidden until Crispy finishes delivering the mail.
	mail_panel.visible = false
	mail_body.bbcode_enabled = true

	Global.check_payday()
	letters = Global.sorted_mail()
	Global.mark_mail_delivered()

## CUSTOM FUNCTIONS
func show_letter(index: int) -> void:
	if letters.is_empty():
		mail_body.text = "[center]No mail today.[/center]"
		counter_label.text = ""
		prev_button.disabled = true
		next_button.disabled = true
		reply_button.visible = false
		block_button.visible = false
		report_button.visible = false
		return

	current = clampi(index, 0, letters.size() - 1)
	var letter: Dictionary = letters[current]
	var was_unread: bool = not letter.get("read", false)
	var deposited := Global.open_mail(letter)
	if deposited > 0:
		Global.save_game() # don't risk losing a paycheck to a closed tab

	# Players are shown with their friend code, so it is clear who to write back to.
	var from := str(letter.get("from", ""))
	var from_code := str(letter.get("from_code", ""))
	if not from_code.is_empty() and from != from_code:
		from += " (%s)" % from_code

	var text := "[b]From:[/b] %s\n\n[b]To:[/b] %s\n\n[b]Subject:[/b] %s%s\n\n%s" % [
		_escape(from),
		_escape(letter.get("to", "")),
		_escape(letter.get("subject", "")),
		"  [color=gold](new)[/color]" if was_unread else "",
		_escape(letter.get("body", "")),
	]
	var attached := int(letter.get("kitcoins", 0))
	if deposited > 0:
		text += "\n\n[color=gold]+%d Kitcoins deposited! (Balance: %d)[/color]" % [deposited, Global.kitcoins]
	elif attached > 0:
		text += "\n\n[color=gray]%d Kitcoins (already deposited)[/color]" % attached
	mail_body.text = text

	counter_label.text = "%d / %d" % [current + 1, letters.size()]
	prev_button.disabled = current == 0
	next_button.disabled = current == letters.size() - 1
	reply_button.visible = not from_code.is_empty()
	block_button.visible = not from_code.is_empty()
	block_button.text = "Unblock" if MailClient.is_blocked(from_code) else "Block"
	report_button.visible = MailClient.can_report(letter)


## Asks a yes/no question and waits for the answer.
func _confirm(text: String, ok_text: String) -> bool:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Are you sure?"
	dialog.dialog_text = text
	dialog.dialog_autowrap = true
	dialog.ok_button_text = ok_text
	dialog.add_user_signal("closed")
	dialog.confirmed.connect(dialog.set_meta.bind("ok", true))
	dialog.confirmed.connect(dialog.emit_signal.bind("closed"))
	dialog.canceled.connect(dialog.emit_signal.bind("closed"))
	add_child(dialog)
	dialog.popup_centered(Vector2i(520, 0))
	await Signal(dialog, "closed")
	var ok: bool = dialog.get_meta("ok", false)
	dialog.queue_free()
	return ok


func _tell(text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Mail"
	dialog.dialog_text = text
	dialog.dialog_autowrap = true
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(520, 0))


# Letters from other players are untrusted text, so keep their BBCode from
# being rendered.
func _escape(value) -> String:
	return str(value).replace("[", "[lb]")

## SIGNALS
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"mail":
			# enable back button and show the mail after cat's mail animation plays
			back_button.disabled = false
			back_button.visible = true
			mail_panel.visible = true
			show_letter(0)
		_:
			pass


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/hub.tscn")

func _on_button_prev_pressed() -> void:
	show_letter(current - 1)


func _on_button_next_pressed() -> void:
	show_letter(current + 1)


func _on_button_reply_pressed() -> void:
	var letter: Dictionary = letters[current]
	var subject := str(letter.get("subject", ""))
	if not subject.to_lower().begins_with("re:"):
		subject = ("Re: " + subject).strip_edges()
	add_child(ComposeLetter.new(str(letter.get("from_code", "")),
		subject.left(ComposeLetter.MAX_SUBJECT)))


func _on_button_write_pressed() -> void:
	add_child(ComposeLetter.new())


func _on_button_block_pressed() -> void:
	var letter: Dictionary = letters[current]
	var code := str(letter.get("from_code", ""))
	var unblocking := MailClient.is_blocked(code)
	if not unblocking and not await _confirm(
			"Block %s? You won't get any more letters from them." % code, "Block"):
		return

	block_button.disabled = true
	var error: String
	if unblocking:
		error = await MailClient.unblock(code)
	else:
		error = await MailClient.block(code)
	if not is_inside_tree():
		return
	block_button.disabled = false
	if not error.is_empty():
		_tell(error)
	show_letter(current)


func _on_button_report_pressed() -> void:
	var letter: Dictionary = letters[current]
	if not await _confirm("Report this letter to Steel Fish Studios? It will be "
			+ "removed from your inbox, and you won't get any more letters from %s."
			% letter.get("from_code", ""), "Report"):
		return

	report_button.disabled = true
	var error: String = await MailClient.report(letter)
	if not is_inside_tree():
		return
	report_button.disabled = false
	if not error.is_empty():
		_tell(error)
		return

	Global.delete_mail(letter)
	Global.save_game()
	letters.erase(letter)
	show_letter(current)
	_tell("Thanks for letting us know. We'll take a look.")
