class_name JamminUIScale extends Node


var _last_size: Vector2i = Vector2i(0, 0)
var _base_resolution: Vector2 = Vector2(1920, 1080)
var _enabled: bool = false
var _update_rate: float = 0.1
var _min_ui_scale: float = 0.5
var _max_ui_scale: float = 2.0

enum Config { UPDATE_RATE, MIN_UI_SCALE, MAX_UI_SCALE }

func enable(base_resolution: Vector2 = Vector2(1920, 1080), config: Dictionary[Config, float] = {}) -> void:
	_base_resolution = base_resolution
	_enabled = true
	_update_rate = config.get(Config.UPDATE_RATE, 0.0001)
	_min_ui_scale = config.get(Config.MIN_UI_SCALE, 0.5)
	_max_ui_scale = config.get(Config.MAX_UI_SCALE, 2.0)

	get_viewport().size_changed.connect(_on_viewport_resize)
	scale_ui_to_size()

func disable() -> void:
	_enabled = false
	get_viewport().size_changed.disconnect(_on_viewport_resize)

# Handle viewport resize events
func _on_viewport_resize() -> void:
	if not _enabled: return

	var new_viewport_size = get_viewport().size
	if _last_size == new_viewport_size: return
	
	# Wait a moment for any other resize events to settle
	await get_tree().create_timer(_update_rate).timeout
	
	# If the size has changed, ignore since we have another event coming
	if new_viewport_size != get_viewport().size: return
	
	_last_size = new_viewport_size
	scale_ui_to_size()

# Calculate and apply the UI scale
func scale_ui_to_size() -> void:
	var viewport = get_viewport()
	var width = viewport.size.x
	var height = viewport.size.y
	
	# Calculate scale based on both dimensions relative to the base resolution
	var scale_x = width / _base_resolution.x
	var scale_y = height / _base_resolution.y
	
	# Use the smaller scale to ensure everything fits
	var scale = min(scale_x, scale_y)
	
	# Clamp to ensure we stay within reasonable bounds
	scale = clampf(scale, _min_ui_scale, _max_ui_scale)
	
	# Apply the calculated scale
	viewport.content_scale_factor = scale
