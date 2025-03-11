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

# What property to update on the control
@export var control_value_property: String = ""

# What signal to connect to for control changes
@export var control_signal: String = ""

func _ready():
	# Use self as the control if none specified
	if control == null: control = self
		
	# Detect appropriate property/signal if not specified
	_setup_auto_property_and_signal()
	
	# Connect signals to handle updates in both directions
	_connect_signals()
	
	# Initialize control with saved value, but do it in the next frame
	_load_saved_value.call_deferred()

func _setup_auto_property_and_signal():
	# Auto-detect property and signal if not specified
	if control_value_property == "":
		if control is TextEdit: control_value_property = "text"
		elif control is LineEdit: control_value_property = "text"
		elif control is CheckBox: control_value_property = "button_pressed"
		elif control is CheckButton: control_value_property = "button_pressed"
		elif control is SpinBox: control_value_property = "value"
		elif control is Slider: control_value_property = "value"
		elif control is OptionButton: control_value_property = "selected"
		elif control is ItemList: control_value_property = "selected_items"
		elif control is ColorPicker: control_value_property = "color"
		elif control is ColorPickerButton: control_value_property = "color"
		else:
			push_error("Unsupported control type: ", control.get_class())

		
	if control_signal == "":
		if control is TextEdit: control_signal = "text_changed"
		elif control is LineEdit: control_signal = "text_changed"
		elif control is CheckBox: control_signal = "toggled"
		elif control is CheckButton: control_signal = "toggled"
		elif control is Button: control_signal = "pressed"
		elif control is SpinBox: control_signal = "value_changed"
		elif control is Slider: control_signal = "value_changed"
		elif control is OptionButton: control_signal = "item_selected"
		elif control is ItemList: control_signal = "item_selected"
		elif control is ColorPicker: control_signal = "color_changed"
		elif control is ColorPickerButton: control_signal = "color_changed"
		else:
			push_error("Unsupported control type: ", control.get_class())

func _connect_signals():
	if control_signal and control.has_signal(control_signal):
		control.connect(control_signal, _on_control_changed)
	
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
	value_changed.emit(value)
	_save_value_to_storage(option_name, value)

func _on_option_changed(key: String, value: Variant):
	if key == option_name: set_control_value(value)

func _on_player_changed(player: Dictionary):
	if option_name in player: set_control_value(player[option_name])

func set_control_value(value: Variant):
	assert(control != null, "Control is null")
	if control is ItemList: return _set_item_list_value(value)
	assert(control_value_property != "", "Control value property is empty")
	
	value = _convert_value_type(value)

	print(name + " set_control_value: ", value)
	
	if _get_control_value() == value: return
	
	_set_control_value(value)
	value_changed.emit(value)

func _get_control_value() -> Variant:
	assert(control != null, "Control is null")
	if control is ItemList: return _get_item_list_value()
	assert(control_value_property != "", "Control value property is empty")
	return _convert_value_type(control.get(control_value_property))

func _get_item_list_value() -> String:
	var selected_items: PackedInt32Array = control.get_selected_items()
	if selected_items.size() == 0: return default_value
	var item_index = selected_items[0]
	var item_text = control.get_item_text(item_index)
	return item_text.split(" (")[0]

func _set_item_list_value(value: String):
	if _get_item_list_value() == value: return
	for i in control.get_item_count():
		var item_text = control.get_item_text(i).split(" (")[0]
		if item_text == value:
			control.select(i)
			break

func _convert_value_type(value: Variant) -> Variant:
	if value == null: value = default_value
	
	match data_type:
		DataTypes.INT: return int(value)
		DataTypes.FLOAT: return float(value)
		DataTypes.BOOL: return !!(value)
		DataTypes.STRING: return str(value)
		DataTypes.COLOR:
			if value is String: return Color(value)
			return value
	return value

func _set_control_value(value: Variant):
	if control_value_property != "": control.set(control_value_property, value); return

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
