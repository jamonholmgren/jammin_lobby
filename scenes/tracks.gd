class_name Tracks extends Node

var floor_image_setup: bool = false
var original_texture: Texture2D = null
var floor_image: Image = null
var floor_texture: ImageTexture = null  # This should be the ImageTexture, not the NoiseTexture2D
@export var track_spacing: float = 0.5 # Minimum distance between track marks

# Singleton pattern
static var instance: Tracks

func _ready() -> void:
	instance = self
	setup_floor()

func setup_floor() -> void:
	# Set up the floor for tracks
	if floor_image_setup: return
	# Wait for level to be fully initialized
	await get_tree().process_frame
	
	# Get the floor material and texture
	var floor_node = Main.level.get_node("%Floor")
	if floor_node == null:
		print("Could not find floor node!")
		return
		
	original_texture = floor_node.material.albedo_texture
	if original_texture == null:
		print("Could not find floor texture!")
		return
		
	# Create a working copy of the image data that we can modify
	floor_image = original_texture.get_image()
	# Create a new ImageTexture from this image
	floor_texture = ImageTexture.create_from_image(floor_image)
	# Apply the new texture to the floor
	floor_node.material.albedo_texture = floor_texture
	
	floor_image_setup = true
	# print("Track system initialized!")

# Call this from each tank when it moves
func add_track_marks(tank: Tank) -> void:
	var tank_position: Vector3 = tank.position
	var wheel_positions: Array[Vector3] = []
	for wheel in tank.wheels: wheel_positions.append(wheel.global_position)
	var last_track_pos: Vector3 = tank.last_track_pos

	# Check if tracks are enabled
	if not floor_image_setup or floor_image == null: return 
		
	# Skip if tank hasn't moved enough since last tracks
	if last_track_pos.distance_to(tank_position) < track_spacing: return
		
	# Convert world position to texture coordinates
	# Assuming the floor is centered at origin and has size from level.tscn
	var floor_size: float = 200.0
	var tex_size: int = floor_image.get_width()
	var scale_factor: float = tex_size / floor_size
	
	# Draw tracks at each wheel position
	var track_locations: Array[Vector2i] = []
	for wheel_pos in wheel_positions:
		var tex_x: int = int((floor_size/2 - wheel_pos.z) * scale_factor)
		var tex_y: int = int((floor_size/2 - wheel_pos.x) * scale_factor)
		track_locations.append(Vector2i(tex_x, tex_y))
	
	# Calculate the rotation of the tank
	var tank_rotation: float = atan2(tank.global_transform.basis.z.x, tank.global_transform.basis.z.z)
	
	Game.draw_on_texture(floor_texture, track_locations, Color(0.05, 0.05, 0.05, 1.0), 4, 1, tank_rotation, 0.1)
	
	tank.last_track_pos = tank_position
