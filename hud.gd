extends Control

@onready var fps: Label = %FPS

func _process(_delta: float) -> void:
  fps.text = "FPS: %d" % Engine.get_frames_per_second()
