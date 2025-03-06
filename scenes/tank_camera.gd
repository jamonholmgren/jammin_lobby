extends Camera3D

var ray_range = 20
var max_zoom = 40.0 # FOV
var min_zoom = 75.0 # FOV
var target_fov = min_zoom

func _input(event: InputEvent) -> void:
	# If it's the left shift button, smoothly zoom to max zoom
	if event.is_action_pressed("zoom_in"):
		target_fov = max_zoom
	# If it's the right shift button, smoothly zoom to min zoom
	elif event.is_action_released("zoom_in"):
		target_fov = min_zoom

func _process(delta: float) -> void:
	fov = lerp(fov, target_fov, delta * 10.0)

func get_camera_collision() -> Vector3:
	var center = get_viewport().get_size() / 2 / UIScale.scale()
	return project_position(center, ray_range)

func raycast_collision() -> Vector3:
	return Vector3.ZERO
	# var ray_origin = global_position + global_transform.basis.z * -1.0
	# var ray_end = ray_origin + global_transform.basis.z * -ray_range

	# # Set the raycast position to the ray origin
	# get_node("RayCast3D").global_position = ray_origin
	# # Set the target position as a relative vector from the raycast origin
	# get_node("RayCast3D").target_position = Vector3(0, 0, -ray_range)

	# var new_intersection = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)

	# #new_intersection.collision_mask = 128
	
	# return get_world_3d().direct_space_state.intersect_ray(new_intersection)

