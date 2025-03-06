extends MeshInstance3D

var growth_rate: float = 400.0

func _ready() -> void:
	# Make sure transparency is enabled on the material
	var material = mesh.material as StandardMaterial3D
	material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	# Set initial alpha to 0
	material.albedo_color.a = 0.0

func _physics_process(delta: float) -> void:
	# Rapid initial expansion that slows over time
	scale += (Vector3(growth_rate, growth_rate, growth_rate) * delta) * 0.1

	growth_rate -= 4.0

	# increase opacity
	var material = mesh.material as StandardMaterial3D
	material.albedo_color.a = min(material.albedo_color.a + delta, 1.0)
	# queue free when opacity is 1
	if material.albedo_color.a >= 0.25: queue_free()
