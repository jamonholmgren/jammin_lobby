extends RigidBody3D

# collisions
var explode_timer: Timer

func _ready() -> void:
	max_contacts_reported = 1
	explode_timer = Timer.new()
	explode_timer.wait_time = 10.0
	explode_timer.one_shot = true
	explode_timer.timeout.connect(explode_timer.queue_free)
	add_child(explode_timer)
	explode_timer.start()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if state.get_contact_count() == 0: return

	# only the multiplayer authority can explode
	if not is_multiplayer_authority(): return
	
	# Get the other body in the collision
	var other_body: Node3D = state.get_contact_collider_object(0)
	
	spawn_explosion.rpc(global_transform.origin, other_body.get_path())

func cancel_timer() -> void:
	if not explode_timer: return
	explode_timer.stop()
	explode_timer.queue_free()
	explode_timer = null

@rpc("reliable", "any_peer", "call_local")
func spawn_explosion(location: Vector3, other_body_path: NodePath) -> void:
	var other_body: Node3D = get_node(other_body_path)
	visible = false
	set_physics_process(false)
	cancel_timer()

	Game.spawn_at(preload("res://scenes/explosion.tscn"), location)

	# Apply knockback to the other body if it's a RigidBody3D and we are the authority
	if other_body is RigidBody3D and other_body.is_multiplayer_authority():
		other_body.apply_central_impulse(global_transform.basis.z * linear_velocity.length() * 10000.0)

	# play audio
	Game.play_audio_3d(load("res://assets/impact.mp3"), location)
	queue_free()
