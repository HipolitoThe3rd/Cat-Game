class_name Yarn
extends Node2D


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is PlayroomCat:
		# Cat will play yarn animation, after which the room will reset
		# and rearrange the blocks
		body.get_node("AnimationPlayer").play("yarn")
