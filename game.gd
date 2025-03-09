extends Node

var status: StringName = &"Lobby" # or &"Game"

# Autoloaded as "Game"
# Mostly helper functions

# Play audio_3d with speed of sound delay and obstacle muffling
func play_audio_3d(stream: AudioStream, location: Vector3) -> void:
	var distance_to_sound = Tank.me.global_transform.origin.distance_to(location)
	var speed_of_sound = 343.0
	var time_to_sound = distance_to_sound / speed_of_sound
	await get_tree().create_timer(time_to_sound).timeout

	var audio_player = AudioStreamPlayer3D.new()
	
	# Check if there's an obstacle between the tank and the sound,
	# and apply a low-pass filter to the sound if so (makes it sound more realistic)
	if not sees(Tank.me.global_transform.origin, location): audio_player.bus = "Muffled"

	audio_player.stream = stream
	audio_player.unit_size = 100.0
	get_tree().current_scene.add_child(audio_player)
	audio_player.global_transform.origin = location
	audio_player.finished.connect(audio_player.queue_free)
	audio_player.play()

# Spawn a scene at a location (usually best for bullets and effects)
func spawn_at(scene: PackedScene, location: Vector3) -> Node3D:
	var instance = scene.instantiate()
	get_tree().current_scene.add_child(instance)
	instance.global_transform.origin = location
	return instance

# Raycast to see if there's an obstacle between two points
func sees(from: Vector3, to: Vector3) -> bool:
	var space_state: PhysicsDirectSpaceState3D = get_tree().current_scene.get_world_3d().direct_space_state
	var ray_params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	ray_params.from = from
	ray_params.to = to
	ray_params.hit_from_inside = false
	ray_params.hit_back_faces = false
	ray_params.collision_mask = 1 # obstacles only
	var result: Dictionary = space_state.intersect_ray(ray_params)
	return result.is_empty()
