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
	print("Track system initialized!")

# Call this from each tank when it moves
func add_track_marks(tank_position: Vector3, wheel_positions: Array, last_track_pos: Vector3) -> Vector3:
	# Check if tracks are enabled
	if not floor_image_setup or floor_image == null: return tank_position
		
	# Skip if tank hasn't moved enough since last tracks
	if last_track_pos.distance_to(tank_position) < track_spacing: return last_track_pos
		
	# Convert world position to texture coordinates
	# Assuming the floor is centered at origin and has size from level.tscn
	var floor_size: float = 350.0
	var tex_size: int = floor_image.get_width()
	var scale_factor: float = tex_size / floor_size
	
	# Draw tracks at each wheel position
	for wheel_pos in wheel_positions:
		var tex_x: int = int((wheel_pos.z - floor_size/2) * scale_factor)
		var tex_z: int = int((wheel_pos.x + floor_size/2) * scale_factor)
		
		# Make sure we're within bounds
		if tex_x < 0 or tex_x >= tex_size or tex_z < 0 or tex_z >= tex_size: continue
			
		# Draw a small dark track at this position
		var track_color: Color = Color(0.05, 0.05, 0.05, 1.0)
		var track_size: int = 3
		for x in range(-track_size, track_size + 1):
			for z in range(-track_size, track_size + 1):
				var px = tex_x + x
				var pz = tex_z + z
				if px >= 0 and px < tex_size and pz >= 0 and pz < tex_size:
					floor_image.set_pixel(px, pz, track_color)
	
	# Update the ImageTexture with the modified image
	floor_texture.update(floor_image)
	
	return tank_position # Return updated last position 
