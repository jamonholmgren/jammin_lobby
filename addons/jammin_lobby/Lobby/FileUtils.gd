class_name FileUtils

# Serialization utilities
static func to_dict(obj: Object, props: Array[String]) -> Dictionary:
	var dict = {}
	for p in props: dict[p] = obj[p]
	return dict

static func is_eq(a: Dictionary, b: Dictionary) -> bool:
	var a_keys = a.keys()
	var b_keys = b.keys()
	a_keys.sort()
	b_keys.sort()
	if a_keys.size() != b_keys.size(): return false
	for k in a_keys: if a[k] != b[k]: return false
	return true

# Check if a is a subset of b
static func is_subset(a: Dictionary, b: Dictionary) -> bool:
	for k in b.keys():
		if not a.has(k): return false
		if a[k] != b[k]: return false
	return true

# File utilities
static func save_json(path: String, data: Dictionary) -> Error:
	var serialized = JSON.stringify(data)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file: return FileAccess.get_open_error()
	file.store_string(serialized)
	file.close()
	return OK

static func load_json(path: String) -> Dictionary:
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

static func file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)

static func copy_file(src: String, dst: String) -> Error:
	var file_exists = FileAccess.file_exists(src)
	if not file_exists: return FileAccess.get_open_error()
	var dir = DirAccess.open(src.get_base_dir())
	dir.copy(src, dst)
	return OK
