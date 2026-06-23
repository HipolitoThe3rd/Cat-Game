class_name Wall
extends Area2D

@export var new_direction := 1 # what direction a colliding object will change to when it touches this wall


func _on_body_entered(body: Node) -> void:
	#print(body, " has collided with the wall")
	if body is KitchenCat:
		body.direction = new_direction

func _on_area_entered(area: Area2D) -> void:
	print(area, " has collided with the wall")
