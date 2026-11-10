## The office: the PC (account login and the online store) and the mailbox,
## where letters wait when Crispy is not in the mood to deliver them himself.
extends Node2D

const MAILBOX_READ := preload("res://sprites/mail/mailbox_read.png")
const MAILBOX_UNREAD := preload("res://sprites/mail/mailbox_unread.png")
const OfficeComputerScript := preload("res://scripts/office_computer.gd")

@onready var mailbox: TextureButton = $Mailbox
@onready var pc: TextureButton = $PC


func _ready() -> void:
	if Global.web_version:
		Input.set_custom_mouse_cursor(Global.smcursor_default)
	else:
		Input.set_custom_mouse_cursor(Global.cursor_default)
	Global.inbox_via_mailbox = false
	_refresh_mailbox()
	Global.mail_received.connect(func(_letter): _refresh_mailbox())


## The mailbox shows a letter in it while there is unread mail. Its sprite
## covers the whole screen, so only its visible pixels take clicks.
func _refresh_mailbox() -> void:
	var texture: Texture2D = MAILBOX_UNREAD if Global.unread_mail_count() > 0 else MAILBOX_READ
	mailbox.texture_normal = texture
	var mask := BitMap.new()
	mask.create_from_image_alpha(texture.get_image())
	mailbox.texture_click_mask = mask


func _open_computer() -> void:
	add_child(OfficeComputerScript.new())


## SIGNALS
# mailbox signals
func _on_mailbox_button_down() -> void:
	pass

func _on_mailbox_button_up() -> void:
	pass

func _on_mailbox_pressed() -> void:
	Global.inbox_via_mailbox = true
	get_tree().change_scene_to_file("res://scenes/inbox.tscn")

func _on_mailbox_toggled(_toggled_on: bool) -> void:
	pass

func _on_mailbox_mouse_entered() -> void:
	mailbox.modulate = Color(1.15, 1.15, 1.15)

func _on_mailbox_mouse_exited() -> void:
	mailbox.modulate = Color.WHITE

# office pc signals
func _on_pc_button_down() -> void:
	pass

func _on_pc_button_up() -> void:
	pass

func _on_pc_pressed() -> void:
	_open_computer()

func _on_pc_toggled(_toggled_on: bool) -> void:
	pass

func _on_pc_focus_entered() -> void:
	pass

func _on_pc_focus_exited() -> void:
	pass

func _on_pc_mouse_entered() -> void:
	pass

func _on_pc_mouse_exited() -> void:
	pass

# back button signals
func _on_back_button_button_down() -> void:
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
