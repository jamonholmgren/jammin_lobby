class_name JamminControl extends Control
# Attach this script to a control in your menu UI to
# automatically save its value to the Options object
# and retrieve with Options.get_option(key, default_value) or Lobby.me.get(key, default_value).

signal value_changed(value: Variant)

# What option name this control should be bound to
@export var option_name: String

# Default value to use if the option isn't set
@export var default_value: String = ""

# What type of data this is
enum DataTypes { STRING, INT, FLOAT, BOOL, COLOR }
@export var data_type: DataTypes = DataTypes.STRING

# Whether it's a player-specific option or computer-specific
# If true, the option will be saved to the local player's data
# otherwise it will be saved to the Options system
@export var is_player_specific: bool = false

# What child control to bind to (if null, will use self)
@export var control: Control

func _ready():
	# Use self as the control if none specified
	if control == null: control = self

	# Connect signals to handle updates in both directions
	_connect_signals()
	
	# Initialize control with saved value, but do it after a bit
	_load_saved_value.call_deferred()

func control_value_property() -> String:
	# Auto-detect property and signal
	if control is TextEdit: return "text"
	elif control is LineEdit: return "text"
	elif control is CheckBox: return "button_pressed"
	elif control is CheckButton: return "button_pressed"
	elif control is SpinBox: return "value"
	elif control is Slider: return "value"
	elif control is OptionButton: return "selected"
	elif control is ItemList: return "selected_items"
	elif control is ColorPicker: return "color"
	elif control is ColorPickerButton: return "color"
	else:
		push_error("Unsupported control type: ", control.get_class())
		return "value"

func control_signal() -> String:
	if control is TextEdit: return "text_changed"
	elif control is LineEdit: return "text_changed"
	elif control is CheckBox: return "toggled"
	elif control is CheckButton: return "toggled"
	elif control is Button: return "pressed"
	elif control is SpinBox: return "value_changed"
	elif control is Slider: return "value_changed"
	elif control is OptionButton: return "item_selected"
	elif control is ItemList: return "item_selected"
	elif control is ColorPicker: return "color_changed"
	elif control is ColorPickerButton: return "color_changed"
	else:
		push_error("Unsupported control type: ", control.get_class())
		return "value_changed"

func _connect_signals():
	var signal_name = control_signal()
	if signal_name and control.has_signal(signal_name):
		control.connect(signal_name, _on_control_changed)
	else:
		push_error("Control signal not found: ", signal_name)
	
	if not is_player_specific:
		Options.updated.connect(_on_option_changed)
	else:
		Lobby.i_updated.connect(_on_player_changed)

func _load_saved_value():
	var saved_value = default_value
	
	var options = Options.data
	if is_player_specific: options = Lobby.me
	if options.has(option_name): saved_value = options[option_name]

	set_control_value(saved_value)

func _save_value_to_storage(key: String, value: Variant):
	if is_player_specific:
		# Create a dictionary with just this option and update the player
		Lobby.update_me({ option_name: value })
	else:
		# Save to main Options
		Options.set(option_name, value)

func _on_control_changed(arg1 = null, arg2 = null, arg3 = null):
	# Handle different signal patterns
	var value = _get_control_value()
	value_changed.emit.call_deferred(value)
	_save_value_to_storage(option_name, value)

func _on_option_changed(key: String, value: Variant):
	if key == option_name: set_control_value(value)

func _on_player_changed(player: Dictionary):
	if option_name in player: set_control_value(player[option_name])

func set_control_value(value: Variant):
	assert(control != null, "Control is null")
	
	value = _convert_value_type(value)

	print(name + " set_control_value: ", value)
	
	if _get_control_value() == value: return
	
	_set_control_value(value)
	value_changed.emit.call_deferred(value)

func _get_control_value() -> Variant:
	assert(control != null, "Control is null")
	if control is ItemList: return _convert_value_type(_get_item_list_value())
	return _convert_value_type(control.get(control_value_property()))

func _get_item_list_value() -> String:
	var selected_items: PackedInt32Array = control.get_selected_items()
	if selected_items.size() == 0: return default_value
	var item_index = selected_items[0]
	var item_text = control.get_item_text(item_index)
	return clean_val(item_text)

func _set_item_list_value(value: String):
	value = clean_val(value)
	print(name + " set_item_list_value: ", value)
	var item_list_value = _get_item_list_value()
	if item_list_value == value: return
	for i in control.get_item_count():
		var item_text = clean_val(control.get_item_text(i))
		if item_text == value:
			control.select(i)
			break

func _convert_value_type(value: Variant) -> Variant:
	if value == null: value = default_value
	
	match data_type:
		DataTypes.INT: return int(value)
		DataTypes.FLOAT: return float(value)
		DataTypes.BOOL: return !!(value)
		DataTypes.STRING: return clean_val(str(value))
		DataTypes.COLOR:
			if value is String: return Color(value)
			return value
	return value

func _set_control_value(value: Variant):
	# Handle specific control types
	if control is ItemList: _set_item_list_value(value); return
	if control is CheckBox: control.button_pressed = bool(value); return
	if control is CheckButton: control.button_pressed = bool(value); return
	if control is LineEdit: control.text = str(value); return
	if control is TextEdit: control.text = str(value); return
	if control is SpinBox: control.value = float(value); return
	if control is Slider: control.value = float(value); return
	if control is OptionButton: control.selected = int(value); return
	if control is ColorPicker: control.color = value; return
	if control is ColorPickerButton: control.color = value; return

	push_error("Unsupported control type: ", control.get_class())

func clean_val(value: String) -> String:
	return value.split(" (")[0]

# This sets up a callback and then also calls it with the
# current value of the control, to do initial setup.
func on_change(callback: Callable):
	value_changed.connect(callback)
	callback.call_deferred(_get_control_value())
