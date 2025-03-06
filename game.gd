extends Node

# Autoloaded as "Game"
# Mostly helper functions

# Game.play_audio_3d(preload("res://assets/impact.mp3"), some_origin)
func play_audio_3d(stream: AudioStream, location: Vector3) -> void:
  var audio_player = AudioStreamPlayer3D.new()
  audio_player.stream = stream
  audio_player.unit_size = 100.0
  get_tree().current_scene.add_child(audio_player)
  audio_player.global_transform.origin = location
  audio_player.finished.connect(audio_player.queue_free)
  audio_player.play()
