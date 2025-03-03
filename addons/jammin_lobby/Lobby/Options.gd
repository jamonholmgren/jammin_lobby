# Class for saving and restoring options
class_name JamminOptions extends JamminBase

signal options_updated(key: String, value: Variant)
signal problem_detected(message: String)

var save_file = "user://options.json"
var backup_file = "user://backup.json"

# Where we store the actual options
var local: Dictionary

# Tracking bound controls to various options
var control_bindings = {}
const CONTROL_UPDATE_SIGNALS = [ "value_changed", "toggled", "text_changed", "item_selected", "texture_changed" ]
const CONTROL_VALUE_PROPS = [ "button_pressed", "value", "texture", "text" ]

func _init(config: Dictionary = {}):
	save_file = config.get("save_file", save_file)
	backup_file = config.get("backup_file", backup_file)
	local = config.get("defaults", {})

# You can get either local or player options with Options.get(k)
func _get(k: StringName) -> Variant:
	var default_value = null
	if k in control_bindings: default_value = control_bindings[k].get("default")
	return local.get(k, default_value)

func _set(k: StringName, v: Variant):
	print("setting option: ", k, " to ", v)
	if str(local.get(k)) == str(v): return true # no need to change anything
	local[k] = v
	autosave()
	options_updated.emit(k, v)
	if k in control_bindings: _update_control_value(v, k)
	return true

func autosave() -> void:
	if Lobby.autosave: debounce(500, save)

func save() -> JamminOptions:
	backup()
	# save_json(save_file, local)

	# Test if the saved file is valid
	var error = test_restore_options(save_file)
	if error != OK: return pe("options mismatch! ", error)

	# Lobby.lm("Saved user options: ", local)
	print("saved: ", local)
	return self

func restore() -> JamminOptions:
	#if not file_exists(save_file): return self

	# var restored = load_json(save_file)
	# for k in restored: set(k, restored[k])
	# print("restored: ", local)
	return self

func clear_all():
	local = {}
	save()
	restore()

func reset_to_defaults():
	for k in control_bindings:
		if control_bindings[k].has("default"):
			local[k] = control_bindings[k].default
	save()
	restore()

func backup():
	pass
	#copy_file(save_file, backup_file)

func test_restore_options(loc: String):
	# Test restoring the options, make sure it ends up being the same as current
	# var restored = load_json(loc)
	# for key in local:
	# 	if not restored.has(key) or local[key] != restored[key]:
	# 		# Something went wrong; restore from a backup if it exists
	# 		var bkp = loc + ".backup.json"
	# 		copy_file(bkp, loc)
	# 		pe("Lobby: tested options restore, but they didn't match! ", key, ": ", local[key], " != ", restored[key])
	# 		return ERR_INVALID_DATA
	return OK

func problem(message: String) -> JamminOptions:
	push_error(message)
	problem_detected.emit(message)
	return self

func bind_control(option_name: String, control: Control, args: Variant = noop_callback, cb: Callable = noop_callback):
	# Third arg can either be the callback itself, or an extra arguments Dictionary
	assert(args is Dictionary or args is Callable, "bind_control: third argument must be a Callable or a Dictionary")
	if args is Callable: cb = args; args = {}

	# Just in case
	unbind_control(option_name) 

	# Convert items from a Dictionary to an Array of its keys, if necessary
	if args.has("items") and args.items is Dictionary: args.items = args.items.keys()

	# Save the binding, along with additional arguments
	control_bindings[option_name] = { "control": control, "callback": cb }
	control_bindings[option_name].merge(args)

	# If we have a default value and no existing value, set it
	if args.has("default"):
		if not option_name in local: set(option_name, args.default)

	# Automatically unbind from the control when it's removed from the scene tree
	control.tree_exiting.connect(unbind_control.bind(option_name))

	# For ItemList, you can provide an "items" property to set the items
	if control is ItemList and args.has("items"): _populate_itemlist(control, args.items)

	# Connect to the control's value changed signal
	_connect_control_value_changed(control, option_name)

	# Immediately set the control's value to the current option's value
	_update_control_value(get(option_name), option_name)

func unbind_control(option_name: String):
	if option_name in control_bindings: control_bindings.erase(option_name)

func _connect_control_value_changed(c: Control, option_name: String):
	var sig = null
	for s in CONTROL_UPDATE_SIGNALS: if c.has_signal(s): sig = s; break
	if sig: c.connect(sig, _update_option_value.bind(option_name))

func _update_option_value(raw_value: Variant, option_name: String):
	if raw_value == null: return
	if not option_name in control_bindings: return
	var binding: Dictionary = control_bindings[option_name]
	var cb: Callable = binding.callback
	var c: Control = binding.control
	var v: Variant = raw_value

	# Use the optional items map to convert the value to the actual item text
	if binding.has("items"): v = binding.items[v]
	set(option_name, v)

func _update_control_value(raw_value: Variant, option_name: String):
	print("updating control value: ", raw_value, " for ", option_name)
	if raw_value == null: return # can't set null values
	
	if not option_name in control_bindings: return
	var binding = control_bindings[option_name]
	var cb = binding.callback
	var c = binding.control
	var v = raw_value
	var t = binding.get("coerce", null)

	# This is for coercing the value to the correct type
	match t:
		"int": v = int(v)
		"float": v = float(v)
		"bool": v = bool(v)
		"string": v = str(v)

	# Special case for ItemList
	if c is ItemList:
		var current_value = _get_itemlist_value(c)
		if str(current_value) != str(v): _set_itemlist_value(c, str(v), binding.get("match", "exact"))
	else:
		# Is this value already set in the control? Don't need to update if so.
		var current_value = _get_control_value(option_name)
		if str(current_value) != str(v): _set_control_value(option_name, v)
	
	# Run the callback with the new value -- either name & value, or just the value
	if cb is Callable: trigger_callback(cb, option_name, v)

func trigger_callback(cb: Callable, option_name: String, value: Variant):
	if not cb is Callable: return
	var arity = cb.get_argument_count()
	if arity == 0: cb.call()
	elif arity == 1: cb.call(value)
	else: cb.call(option_name, value)

func _get_control_value(option_name: String) -> Variant:
	if not option_name in control_bindings: return null
	var binding = control_bindings[option_name]
	var c = binding.control
	
	# Custom getter
	if binding.get("control_getter"): return binding.control_getter.call(c)
	if binding.get("control_property"): return c.get(binding.control_property)

	# Special case for ItemList
	if c is ItemList: return _get_itemlist_value(c)

	# Guess various control properties
	for p in CONTROL_VALUE_PROPS: if p in c: return c.get(p)
	return null

func _set_control_value(option_name: String, value: Variant) -> void:
	if not option_name in control_bindings: return
	if value == null: return # can't set null values
	var binding = control_bindings[option_name]

	# Custom setter
	if binding.get("control_setter"): binding.control_setter.call(binding.control, value); return
	if binding.get("control_property"): binding.control.set(binding.control_property, value); return

	# Special case for ItemList
	if binding.control is ItemList: _set_itemlist_value(binding.control, value, binding.get("match", "exact")); return

	# Guess various control properties and methods
	for p in CONTROL_VALUE_PROPS:
		if p in binding.control: binding.control.set(p, value); return
		if "set_" + p in binding.control: binding.control["set_" + p].call(value); return

func _populate_itemlist(itemlist: ItemList, items: Array):
	itemlist.clear()
	for key in items: itemlist.add_item(key)

func _get_itemlist_value(itemlist: ItemList) -> String:
	var sel = itemlist.get_selected_items()
	if sel.size() == 0: return ""
	return itemlist.get_item_text(sel[0])

func _set_itemlist_value(itemlist: ItemList, value: Variant, match: String = "exact") -> void:
	var mi = null
	var v = str(value)
	for i in range(itemlist.item_count):
		var item_text = itemlist.get_item_text(i)
		if item_text == v: mi = i; break
		if match == "begins_with" and item_text.begins_with(v): mi = i; break
		if match == "ends_with" and item_text.ends_with(v): mi = i; break
		if match == "contains" and item_text.contains(v): mi = i; break
	if mi != null: itemlist.select(mi)

func noop_callback(_n: String, _v: Variant): pass
