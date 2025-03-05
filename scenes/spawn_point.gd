extends Area3D

var occupants: Array[Node3D] = []

# Tracks what tanks are near this spawn point
func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("tanks"): occupants.append(body)

func _on_body_exited(body: Node3D) -> void:
	if occupants.has(body): occupants.erase(body)

func is_free() -> bool:
	return occupants.size() == 0
