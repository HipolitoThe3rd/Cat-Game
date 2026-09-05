class_name Yarn
extends Node2D

signal collected(yarn: Yarn)

const REACH_SLACK = 8.0   # forgives the cat's collider sitting a little low

var taken := false
var pickup_radius := 40.0


func _ready() -> void:
	# Connected here rather than in the scene so the yarn keeps working when a
	# maze spawns it at runtime.
	var area: Area2D = $Area2D
	var shape: CircleShape2D = area.get_node("CollisionShape2D").shape
	pickup_radius = shape.radius * absf(global_scale.x)
	if not area.body_entered.is_connected(_on_area_2d_body_entered):
		area.body_entered.connect(_on_area_2d_body_entered)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if taken:
		return
	if body is PlayroomCat:
		# A yarn spawned into a fresh maze gets told about overlaps the physics
		# server saw at spawn time, even against a cat who has since been moved
		# to the other end of the room. That is what used to hand the player the
		# next round for free, so confirm he is really here before believing it.
		if global_position.distance_to(body.global_position) \
				> pickup_radius + body.radius + REACH_SLACK:
			return
		# A cat already mid-celebration is being carried over from the last
		# round, so he must not trip this one on his way out of the old room.
		if body.celebrating:
			return
		taken = true
		$AnimatedSprite2D.visible = false
		# Cat will play yarn animation, after which the room will reset
		# and rearrange the blocks. He keeps whichever way he was facing when
		# he got here -- celebrate() locks that in.
		body.celebrate()
		collected.emit(self)
