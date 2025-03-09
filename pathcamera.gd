extends Camera3D

@export var target: Node3D
@export var carrier: PathFollow3D

func _process(delta: float) -> void:
  # Look at the target
  look_at(target.global_transform.origin, Vector3.UP)

  # Move the camera along the path
  carrier.progress += delta * 10.0
