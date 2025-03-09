class_name Hitbox
extends Area3D

@export var parent_tank : Tank
@export var parent_component: MeshInstance3D

func _init() -> void:
	body_entered.connect(on_body_entered)

func on_body_entered(body: RigidBody3D):
	if body is Bullet:
		parent_tank.take_damage(parent_component)
