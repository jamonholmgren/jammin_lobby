class_name JamminOptionControl extends Control

# Attach this script to a control in your menu UI to automatically save its value to the Lobby options

signal value_changed(key: String, value: Variant)

# What object handles the option
var option_emitter: Node

# What option this control should be bound to
@export var option_name: String

# What child control to bind to
@onready var control = get_node("Contents/Value")

# What property to update on the control
@export var control_value_property: String = "value"

# What callback to call when the value changes
var callback: Callable

func bind_option(emitter: Node, option_name: String, cb: Callable = func(_k, _v, _c): pass):
	option_emitter = emitter
	
	# ⬅️ Connect the control's value_changed signal to update the option emitter's option
	value_changed.connect(option_emitter.set_option)
	
	# ➡️ Connect the option emitter's options_updated signal to update the control's value
	option_emitter.options_updated.connect(update_control_value)

	# Save the callback
	callback = cb

	# Set the control's value to the option's value
	update_control_value(option_name, option_emitter.get_option(option_name))

	# Run the callback immediately with the current value
	if callback: callback.call(option_name, option_emitter.get_option(option_name), self)

func update_control_value(key: String, value: Variant) -> void:
	if key != option_name: return
	if control.get(control_value_property) != value: control.set(control_value_property, value)

func _on_value_changed(value: Variant) -> void:
	if callback: callback.call(option_name, value, self)
	value_changed.emit(option_name, value)
