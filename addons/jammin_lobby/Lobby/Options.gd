# Class for saving and restoring options
class_name JamminOptions extends JamminBase

signal updated(key: String, value: Variant)
signal problem_detected(message: String)

var save_file = "user://options.json"
var backup_file = "user://options-backup.json"

# Where we store the actual options
var data: Dictionary

func _init(config: Dictionary = {}):
	save_file = config.get("save_file", save_file)
	backup_file = config.get("backup_file", backup_file)
	data = config.get("defaults", {})

# You can get options with Options.get_option(k, default_value)
func _get(k: StringName) -> Variant:
	return data.get(k, null)

func _set(k: StringName, v: Variant):
	var old_v = data.get(k, null)
	if v is Dictionary and old_v is Dictionary and FileUtils.is_eq(old_v, v): return true
	elif str(old_v) == str(v): return true
	data[k] = v
	autosave()
	updated.emit.call_deferred(k, v)
	return true

# Convenience method for getting options with a default value
func get_option(key: String, default_value = null) -> Variant:
	return data.get(key, default_value)

# Convenience method for setting options
func set_option(key: String, value: Variant) -> void:
	set(key, value)

func autosave() -> void:
	debounce(500, save)

func save() -> JamminOptions:
	# If there's already a saved file, see if anything has changed
	var saved_data: Dictionary = FileUtils.load_json(save_file)
	if FileUtils.is_eq(data, saved_data): return self

	# Make a backup
	backup()

	# Save the new data
	FileUtils.save_json(save_file, data)

	# Test if the newly saved file is valid
	var error = test_restore_options(save_file)
	if error != OK: return pe("options mismatch! ", error)

	print("saved: ", data)
	return self

func restore() -> JamminOptions:
	if not FileUtils.file_exists(save_file): return self

	var restored = FileUtils.load_json(save_file)
	for k in restored: set(k, restored[k])
	return self

func clear_all():
	data = {}
	save()
	restore()

func backup():
	FileUtils.copy_file(save_file, backup_file)

func test_restore_options(loc: String):
	# Test restoring the options, make sure it ends up being the same as current
	var restored = FileUtils.load_json(loc)
	if not FileUtils.is_eq(data, restored):
		# Something went wrong; restore from a backup if it exists
		pe("options mismatch! ", loc, data, restored)
		var bkp = loc + ".backup.json"
		FileUtils.copy_file(bkp, loc)
		return ERR_INVALID_DATA
	return OK

func problem(message: String) -> JamminOptions:
	push_error(message)
	problem_detected.emit.call_deferred(message)
	return self

func noop_callback(_n: String, _v: Variant): pass
