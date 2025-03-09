extends Node

# Game state and some helper functions

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

# Draws points on a texture
func draw_on_texture(texture: ImageTexture, locations: Array[Vector2i], size: int, color: Color, color_variance: float = 0.0) -> void:
	var image: Image = texture.get_image()
	
	for location in locations:
		var x: int = location.x
		var y: int = location.y
		# Make sure we're within bounds
		if x < 0 or x >= image.get_width() or y < 0 or y >= image.get_height(): continue
			
		for dx in range(-size, size + 1):
			for dy in range(-size, size + 1):
				var c: Color = color
				if color_variance > 0.0:
					c = Color(
						color.r + randf_range(-color_variance, color_variance),
						color.g + randf_range(-color_variance, color_variance),
						color.b + randf_range(-color_variance, color_variance),
						color.a)
				image.set_pixel(x + dx, y + dy, c)
	
	# Update the ImageTexture with the modified image
	texture.update(image)
