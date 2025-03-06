extends RigidBody3D

# collisions
var explode_timer: Timer

func _ready() -> void:
  max_contacts_reported = 1
  explode_timer = Timer.new()
  explode_timer.wait_time = 10.0
  explode_timer.one_shot = true
  explode_timer.timeout.connect(explode_timer.queue_free)
  add_child(explode_timer)
  explode_timer.start()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
  if state.get_contact_count() == 0: return

  # only the multiplayer authority can explode
  if not is_multiplayer_authority(): return
  
  # Get the other body in the collision
  var other_body: Node3D = state.get_contact_collider_object(0)

  # Knock back the other body if it's a CollisionObject3D
  if other_body is CollisionObject3D:
    other_body.apply_central_impulse(global_transform.basis.z * linear_velocity.length() * 100.0)
  
  spawn_explosion.rpc(global_transform.origin)

func cancel_timer() -> void:
  explode_timer.stop()
  explode_timer.queue_free()
  explode_timer = null

@rpc("reliable", "any_peer", "call_local")
func spawn_explosion(location: Vector3) -> void:
  visible = false
  set_physics_process(false)
  cancel_timer()

  Game.spawn_at(preload("res://scenes/explosion.tscn"), location)

  var distance := global_transform.origin.distance_to(location)
  var speed_of_sound := 343.0
  var time_to_impact := distance / speed_of_sound

  await get_tree().create_timer(time_to_impact).timeout

  # play audio
  Game.play_audio_3d(load("res://assets/impact.mp3"), location)
  queue_free()

