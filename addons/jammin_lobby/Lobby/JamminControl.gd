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
	# Connect to our own value_changed signal to save changes
	value_changed.connect(_save_value)
	
	# Connect to the control's signal for changes
	print("control_signal: ", control_signal)
	if control_signal and control.has_signal(control_signal):
		control.connect(control_signal, _on_control_changed)
	
	# Connect to Options.updated for external changes
	if not is_player_specific:
		print("connecting to options changes")
		Options.updated.connect(_on_option_changed)
	else:
		# Connect to player data changes
		print("connecting to player data changes")
		Lobby.me_updated.connect(_on_player_changed)

func _load_saved_value():
	var saved_value = default_value
	
	var options = Options.data
	if is_player_specific: options = Lobby.me
	if options.has(option_name): saved_value = options[option_name]

	set_value(saved_value)

func _save_value(key: String, value: Variant):
	if is_player_specific:
		# Create a dictionary with just this option and update the player
		Lobby.update_me({ option_name: value })
	else:
		# Save to main Options
		Options.set(option_name, value)

func _on_control_changed(arg1 = null, arg2 = null, arg3 = null):
	# Handle different signal patterns
	var value = get_value()
	value_changed.emit(option_name, value)

func _on_option_changed(key: String, value: Variant):
	print("option changed: ", key, " = ", value)
	if key == option_name:
		set_value(value)

func _on_player_changed(player: Dictionary):
	print("player changed: ", player)
	if option_name in player: set_value(player[option_name])

func set_value(value: Variant):
	# Skip if the control already has this value
	if get_value() == value: return

	# Convert value to correct type
	value = _convert_value_type(value)
	
	# Set the control's value
	set_control_value(value)

func get_value() -> Variant:
	if not control_value_property: return null
	return control.get(control_value_property)

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

func set_control_value(value: Variant):
	if control_value_property != "": control.set(control_value_property, value); return

	# Handle specific control types
	if control is LineEdit: control.text = str(value); return
	if control is TextEdit: control.text = str(value); return
	if control is SpinBox: control.value = float(value); return
	if control is Slider: control.value = float(value); return
	if control is OptionButton: control.selected = int(value); return
	if control is ColorPicker: control.color = value; return
	if control is ColorPickerButton: control.color = value; return

	push_error("Unsupported control type: ", control.get_class())
