class_name JamminPlayer extends JamminBase

signal updated(player: JamminPlayer)

# Core properties that every lobby player needs, aside from `name` which is built-in

# # For local changes (CURRENTLY DOESNT WORK EXCEPT FOR NAME)
# func _set(property, value):
# 	if get(property) == value: return false
# 	self[property] = value
# 	updated.emit()
# 	on_updated()

# NOTE: https://github.com/godotengine/godot/issues/99828
# Because _set() and _get() are not called properly (until the above issue is fixed),
# we need to use a custom setter/getter for the properties that we want to call
# `updated` on change.

# This is this player instance's multiplayer ID. Normally it's the same as
# multiplayer_authority, but if we're not connected, it's 0
@export var id: int = 0

@export var is_ready: bool = false:
	set(v):
		is_ready = v
		updated.emit()

const DEFAULT_USERNAMES: Array[String] = [
	"Ghost",
	"Gorilla",
	"Hawk",
	"Hunter",
	"Jaguar",
	"Maverick",
	"Phoenix",
	"Raven",
	"Raptor",
	"Rogue",
	"Scorpion",
	"Viper",
	"Wolf",
	"Wraith",
	"Wolverine",
	"X-Ray",
	"Skyhawk",
	"Bladerunner",
	"Firebird",
	"Tornado"
]
@export var username: String = DEFAULT_USERNAMES[randi() % DEFAULT_USERNAMES.size()]:
	set(v):
		username = v
		updated.emit()

var options: JamminOptions = null:
	get: return options_get({
		"save_file": Lobby.player_save_file.format(["options_" + str(Lobby.save_slot)]),
		"backup_file": Lobby.player_save_file.format(["options_" + str(Lobby.save_slot)]) + ".backup.json",
		"restore": true
	})

var _synced_props: Dictionary = {}
var _saved_props: Array[String] = ["username"]

# Public API **********************************************************************

func set_id(v: int) -> void:
	var is_me_here = Lobby.is_me(self)
	lm("set_id: ", v, " is_me: ", is_me_here)
	id = v
	if Lobby.has_multiplayer_connection() and id != 0:
		set_multiplayer_authority(id)
		name = "Player" + str(id)
		lm("set_id, set_multiplayer_authority: ", id, " and name: ", name)
		updated.emit()

func save_prop(prop: String) -> JamminPlayer:
	_saved_props.append(prop)
	return self

func save_props(props: Array[String]) -> JamminPlayer:
	_saved_props.append_array(props)
	return self

func is_me() -> bool: return id == Lobby.me.id
func is_host() -> bool: return id == Lobby.SERVER_ID
func joined() -> bool: return id != 0

# Save local player data to disk
func save() -> JamminPlayer:
	lm("save")
	self.options.save()
	save_json(Lobby.player_save_file.format([Lobby.save_slot]), to_dict(self, _saved_props))
	return self

# Loads player data from disk
func restore() -> JamminPlayer:
	lm("restore")
	self.options.restore()
	var data = load_json(Lobby.player_save_file.format([Lobby.save_slot]))
	for key in _saved_props: if data.has(key): set(key, data[key])
	return self

func clear():
	options.clear_all()

# Sync
func synchronizer() -> MultiplayerSynchronizer: return $PlayerSync
func sync_prop(prop: String, mode := SceneReplicationConfig.ReplicationMode.REPLICATION_MODE_ON_CHANGE) -> void: _synced_props[prop] = { "mode": mode, "spawn": true }
func is_syncing() -> bool: return Lobby.has_multiplayer_connection() and synchronizer().public_visibility	
func start_sync() -> void: apply_replication_config(); synchronizer().public_visibility = true
func stop_sync() -> void: if is_syncing(): synchronizer().public_visibility = false

func apply_replication_config() -> void:
	var config = synchronizer().get_replication_config()
	for prop in _synced_props:
		assert(is_property_exported(self, prop), "Property not exported: " + prop)
		var prop_name = ".:" + prop
		if not config.has_property(prop_name): config.add_property(prop_name)
		config.property_set_spawn(prop_name, _synced_props[prop]["spawn"])
		config.property_set_replication_mode(prop_name, _synced_props[prop]["mode"])
	synchronizer().set_replication_config(config)

# For delta sync server changes (we don't do this for continuous sync)
func _on_delta_synchronized() -> void:
	updated.emit()
	on_updated()

func _on_player_sync_visibility_changed(for_peer:int) -> void:
	updated.emit()
	on_updated()

# Communication

func ask(req_name: String, data: Dictionary) -> Variant: return await Lobby.ask(id, req_name, data)

# Hooks **********************************************************************

# Override these hooks in subclass
func on_me_created() -> void: pass
func on_joined_lobby() -> void: pass
func on_left_lobby() -> void: pass
func on_updated() -> void: pass
