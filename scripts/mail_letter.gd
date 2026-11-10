### MailLetter will have one of the designs in "res://backgrounds/Mail/"
### The background in the prefab is the default design, this and the one with the color scheme of Crispy (and their inverses) will be the two defaults available, while you will be able to buy other designs with the money you earn through weekly paychecks 
class_name MailLetter
extends Control

@onready var body_panel = $PanelBody
@onready var body_scrollbar = $PanelBody/VSBBody # if the body of the mail is long enough, this scroll bar will go up down; the color of the circle-shaped handle should match the outer color of the mail desig, such as #f0f0f0 for the default design background; the color of the handle will not be blended, but replaced
@onready var sender_panel = $PanelSender # where the sender of the mail's name will be displayed, whether by Friend Code or Discord username

@export var path_to_mail_designs = "res://backgrounds/Mail/"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
