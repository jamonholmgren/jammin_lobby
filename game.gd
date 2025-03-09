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

func world_to_texture_coords(texture: ImageTexture, world_coords: Vector3) -> Vector2i:
	var floor_size: float = 200.0
	var tex_x: int = int((floor_size/2 - wheel_pos.z) * scale_factor)
	var tex_y: int = int((floor_size/2 - wheel_pos.x) * scale_factor)

# Draws points on a texture with optional rotation and size
func draw_on_texture(texture: ImageTexture, locations: Array[Vector2i], color: Color, size_x: int = 1, size_y: int = 1, rotation: float = 0.0, color_variance: float = 0.0) -> void:
	var image: Image = texture.get_image()
	
	for location in locations:
		var x: int = location.x
		var y: int = location.y
		# Make sure we're within bounds
		if x < 0 or x >= image.get_width() or y < 0 or y >= image.get_height(): continue
		
		# Calculate rotated rectangle bounds
		for dy in range(-size_y, size_y + 1):
			for dx in range(-size_x, size_x + 1):
				# Rotate the point around the center
				var rotated_x = dx * cos(rotation + PI/2) - dy * sin(rotation + PI/2)
				var rotated_y = dx * sin(rotation + PI/2) + dy * cos(rotation + PI/2)
				
				# Round to nearest pixel
				var pixel_x = x + round(rotated_x)
				var pixel_y = y + round(rotated_y)
				
				# Check bounds
				if pixel_x < 0 or pixel_x >= image.get_width() or pixel_y < 0 or pixel_y >= image.get_height(): continue
					
				var c: Color = color
				if color_variance > 0.0:
					c = Color(
						color.r + randf_range(-color_variance, color_variance),
						color.g + randf_range(-color_variance, color_variance),
						color.b + randf_range(-color_variance, color_variance),
						color.a)
				image.set_pixel(pixel_x, pixel_y, c)
	
	# Update the ImageTexture with the modified image
	texture.update(image)
