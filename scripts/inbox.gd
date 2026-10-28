class_name Inbox
extends Node2D

@onready var back_button = $UI/BackButton
@onready var mail_panel = $UI/MailPanel
@onready var mail_body = $"UI/MailPanel/Mail Body"
@onready var counter_label = $UI/MailPanel/HBoxContainer/Counter
@onready var prev_button = $UI/MailPanel/HBoxContainer/ButtonPrev
@onready var next_button = $UI/MailPanel/HBoxContainer/ButtonNext

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
		return

	current = clampi(index, 0, letters.size() - 1)
	var letter: Dictionary = letters[current]
	var was_unread: bool = not letter.get("read", false)
	var deposited := Global.open_mail(letter)
	if deposited > 0:
		Global.save_game() # don't risk losing a paycheck to a closed tab

	var text := "[b]From:[/b] %s\n\n[b]To:[/b] %s\n\n[b]Subject:[/b] %s%s\n\n%s" % [
		_escape(letter.get("from", "")),
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
