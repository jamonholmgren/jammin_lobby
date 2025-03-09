class_name JamminControl extends Control
# Attach this script to a control in your menu UI to
# automatically save its value to the Options object
# and retrieve with Options.get(key) or Lobby.me.get(key).

signal value_changed(key: String, value: Variant)

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

# Common control signals and properties
const AUTO_SIGNALS = {
	"TextEdit": "text_changed",
	"LineEdit": "text_changed",
	"CheckBox": "toggled",
	"CheckButton": "toggled",
	"Button": "pressed",
	"SpinBox": "value_changed",
	"Slider": "value_changed",
	"OptionButton": "item_selected",
	"ItemList": "item_selected",
	"ColorPicker": "color_changed",
	"ColorPickerButton": "color_changed"
}

const AUTO_PROPERTIES = {
	"TextEdit": "text",
	"LineEdit": "text",
	"CheckBox": "button_pressed",
	"CheckButton": "button_pressed",
	"SpinBox": "value",
	"Slider": "value",
	"OptionButton": "selected",
	"ItemList": "selected_items",
	"ColorPicker": "color",
	"ColorPickerButton": "color"
}

func _ready():
	# Use self as the control if none specified
	if control == null: control = self
		
	# Detect appropriate property/signal if not specified
	_setup_auto_property_and_signal()
	
	# Connect signals to handle updates in both directions
	_connect_signals()
	
	# Initialize control with saved value
	_load_saved_value()

func _setup_auto_property_and_signal():
	# Auto-detect property and signal if not specified
	var control_class = control.get_class()
	
	if control_value_property == "":
		control_value_property = AUTO_PROPERTIES.get(control_class, "")
		
	if control_signal == "":
		control_signal = AUTO_SIGNALS.get(control_class, "")

func _connect_signals():
	value_changed.connect(_save_value_to_storage)
	
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
	value_changed.emit(option_name, value)
	_save_value_to_storage(option_name, value)

func _on_option_changed(key: String, value: Variant):
	if key == option_name: set_control_value(value)

func _on_player_changed(player: Dictionary):
	if option_name in player: set_control_value(player[option_name])

func set_control_value(value: Variant):
	assert(control != null, "Control is null")
	assert(control_value_property != "", "Control value property is empty")
	if control is ItemList: return _set_item_list_value(value)
	if _get_control_value() == value: return
	value = _convert_value_type(value)
	_set_control_value(value)

func _get_control_value() -> Variant:
	assert(control != null, "Control is null")
	assert(control_value_property != "", "Control value property is empty")
	if control is ItemList: return _get_item_list_value()
	return _convert_value_type(control.get(control_value_property))

func _get_item_list_value() -> String:
	var selected_items: PackedInt32Array = control.get_selected_items()
	if selected_items.size() == 0: return default_value
	var item_index = selected_items[0]
	var item_text = control.get_item_text(item_index)
	return item_text

func _set_item_list_value(value: String):
	if _get_item_list_value() == value: return
	control.selected = control.get_item_index(value)

func _convert_value_type(value: Variant) -> Variant:
	if value == null: return default_value
		
	match data_type:
		DataTypes.INT: return int(value)
		DataTypes.FLOAT: return float(value)
		DataTypes.BOOL: return bool(value)
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
