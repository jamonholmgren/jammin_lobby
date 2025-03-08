extends Node

# Autoloaded as "Game"
# Mostly helper functions

# Game.play_audio_3d(preload("res://assets/impact.mp3"), some_origin)
func play_audio_3d(stream: AudioStream, location: Vector3) -> void:
	var distance_to_sound = Tank.me.global_transform.origin.distance_to(location)
	var speed_of_sound = 343.0
	var time_to_sound = distance_to_sound / speed_of_sound
	await get_tree().create_timer(time_to_sound).timeout

	var audio_player = AudioStreamPlayer3D.new()
	audio_player.stream = stream
	audio_player.unit_size = 100.0
	get_tree().current_scene.add_child(audio_player)
	audio_player.global_transform.origin = location
	audio_player.finished.connect(audio_player.queue_free)
	audio_player.play()

# Game.spawn_at(preload("res://scenes/bullet.tscn"), some_origin)
func spawn_at(scene: PackedScene, location: Vector3) -> Node3D:
	var instance = scene.instantiate()
	get_tree().current_scene.add_child(instance)
	instance.global_transform.origin = location
	return instance
