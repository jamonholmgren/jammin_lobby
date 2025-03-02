class_name FileUtils

# Serialization utilities
func to_dict(obj: Object, props: Array[String]) -> Dictionary:
	var dict = {}
	for p in props: dict[p] = obj[p]
	return dict

# File utilities
func save_json(path: String, data: Dictionary) -> Error:
	var serialized = JSON.stringify(data)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file: return FileAccess.get_open_error()
	file.store_string(serialized)
	file.close()
	return OK

func load_json(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return {}
	var serialized = file.get_as_text()
	file.close()
	var json := JSON.new()
	var error = json.parse(serialized)
	if error != OK:
		push_error("JamminBase: failed to parse JSON: ", error)
		return {}
	return json.data

func file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)

func copy_file(src: String, dst: String) -> Error:
	var file_exists = FileAccess.file_exists(src)
	if not file_exists: return FileAccess.get_open_error()
	var dir = DirAccess.open(src.get_base_dir())
	dir.copy(src, dst)
	return OK
