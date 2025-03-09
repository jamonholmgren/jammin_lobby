class_name JamminBase extends Node

static var debug := OS.is_debug_build()

# Timing utilities
func wait(time: float):
	return Lobby.get_tree().create_timer(time).timeout

func debounce_single_timer(c: Callable):
	for t in get_children(): if t is Timer and t.is_connected("timeout", c): t.stop(); t.start(); return t
	return null

func debounce(ms: float, c: Callable) -> Signal:
	# find the timer for this callback, if it exists already, and reset it
	var t = debounce_single_timer(c)
	if t: return t.timeout

	# create a new timer for this callback
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = ms / 1000.0 # Convert to seconds
	timer.one_shot = true
	timer.timeout.connect(c)
	# Kill the timer after it fires
	timer.timeout.connect(func(): timer.queue_free())
	timer.start()
	return timer.timeout

# Connects a callback to a signal if it's not already connected
func cs(o: Object, s: String, c: Callable) -> void:
	if not o[s].is_connected(c): o[s].connect(c)

var _options: JamminOptions = null
func options_get(settings: Dictionary) -> JamminOptions:
	if _options: return _options
	_options = JamminOptions.new(settings)
	add_child(_options)
	if settings.get("restore", true): _options.restore()
	return _options

func is_property_exported(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if property["name"] == property_name:
			# Check if PROPERTY_USAGE_EDITOR flag is set
			return bool(property["usage"] & PROPERTY_USAGE_EDITOR)
	return false

# Pushes an error with a prefix
func pe(m1: String, m2: Variant = "", m3: Variant = "", m4: Variant = "", m5: Variant = "", m6: Variant = "", m7: Variant = "", m8: Variant = "", m9: Variant = ""):
	push_error("Lobby: ", m1, m2, m3, m4, m5, m6, m7, m8, m9)
	return self

func timestamp() -> float:
	return Time.get_unix_time_from_system()

func time_str(ts: float) -> String:
	var t = Time.get_time_dict_from_unix_time(ts)
	return "%02d:%02d:%02d" % [t.hour, t.minute, t.second]

func time_ago(ts: float) -> String:
	var seconds_ago = floor(timestamp() - ts)
	if seconds_ago < 60.0: return "just now"
	if seconds_ago < 3600.0: return "%dm ago" % [seconds_ago / 60]
	if seconds_ago < 86400.0: return "%dh ago" % [seconds_ago / 60 / 60]
	if seconds_ago < 172800.0: return "1d ago"
	return "%dd ago" % [seconds_ago / 60 / 60 / 24]

func find(array: Array[Variant], callback: Callable) -> Variant:
	for k in array: if callback.call(k): return k
	return null

func find_index(array: Array[Variant], callback: Callable) -> int:
	for k in array: if callback.call(k): return array.find(k)
	return -1

func find_by_key(array: Array[Variant], key: String, value: Variant) -> Variant:
	for v in array: if v[key] == value: return v
	return null

func find_index_by_key(array: Array[Variant], key: String, value: Variant) -> int:
	for v in array: if v[key] == value: return array.find(v)
	return -1

# Logs a message with a prefix
func lm(m1: Variant, m2: Variant = "", m3: Variant = "", m4: Variant = "", m5: Variant = "", m6: Variant = "", m7: Variant = "", m8: Variant = "", m9: Variant = ""):
	# if multiplayer and multiplayer.multiplayer_peer and multiplayer.get_unique_id() != Lobby.host_id(): return null
	if not debug: return null
	var prelim = "H →" if Lobby.i_am_host() else "  →"
	print(prelim, (Lobby.me.username if Lobby.me else "Unknown") + ": ", m1, m2, m3, m4, m5, m6, m7, m8, m9)
	return null

# Runs a function every N frames
# Should be called from _physics_process
# Game.every(20, fn) # will every the function every 20 frames
func every(frames: int, fn: Callable, offset: int = 0, debug_label: StringName = &""):
	if frames == 0: return # never

	if (Engine.get_physics_frames() + offset) % frames == 0:
		if debug_label != &"":
			call_deferred("exec_every", fn, debug_label)
		else:
			# Don't use exec_every if no debug label, for performance reasons
			fn.call_deferred()

func exec_every(fn: Callable, debug_label: StringName = &""):
	fn.call()
