class_name Bullet
extends RigidBody3D

# collisions
var explode_timer: Timer

func _ready() -> void:
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
		other_body.apply_central_impulse(global_transform.basis.z * linear_velocity.length() * 1000.0)

	# play audio
	Game.play_audio_3d(load("res://assets/impact.mp3"), location)
	queue_free()

	# draw a scorch mark on the floor if we hit the floor
	if other_body.name == "Floor":
		var fs: float = Tracks.instance.floor_size
		var sf: float = Tracks.instance.scale_factor
		var tex_x: int = int((fs/2 - global_transform.origin.z) * sf)
		var tex_y: int = int((fs/2 - global_transform.origin.x) * sf)
		
		# randomly add 20 scorch marks around the impact point
		var locations: Array[Vector2i] = []
		for i in range(30):
			locations.append(Vector2i(tex_x + randi_range(-10, 10), tex_y + randi_range(-10, 10)))
		
		Game.draw_on_texture(Tracks.instance.floor_texture, locations, Color(0.1, 0.1, 0.1, 1.0), 2, randi_range(1, 3), randf_range(0.0, TAU), randf_range(0.0, 0.1))
	