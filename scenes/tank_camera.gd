extends Camera3D

var ray_range = 2000

func get_camera_collision():
	var center = get_viewport().get_size() / 2
	
	var ray_origin = project_ray_origin(center)
	var ray_end = ray_origin + project_ray_normal(center) * ray_range

	var new_intersection = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)

	#new_intersection.collision_mask = 128
	
	var intersection = get_world_3d().direct_space_state.intersect_ray(new_intersection)
	
	if not intersection.is_empty():
		print(intersection.collider.name)
		return intersection.position
	else:
		return null
