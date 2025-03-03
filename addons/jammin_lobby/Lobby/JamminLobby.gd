# The configuration for the lobby lives here
# You add this node to your main scene to configure the lobby system
# Even if the scene gets unloaded, this config will persist in .instance
# (until the next time the scene is loaded -- but even then, we'll copy
# the current config to the new instance)
class_name JamminLobby extends Control

# Signals ***********************************************************************

# Signals for the local player
signal me_joining_lobby()
signal me_joined_lobby(player: Dictionary)
signal me_left_lobby(reason: String)
signal me_updated(player: Dictionary)

# Signals for other players
signal player_joining_lobby(pid: int) # all we have is a pid, no player yet
signal player_joined_lobby(player: Dictionary)
signal player_left_lobby(player: Dictionary)
signal player_updated(player: Dictionary)

# Signals for the host
signal host_joining_lobby()
signal host_joined_lobby()
signal host_left_lobby(reason: String)
signal host_player_joining_lobby(pid: int) # all we have is a pid, no player yet
signal host_player_joined_lobby(player: Dictionary)
signal host_player_left_lobby(player: Dictionary)
signal host_player_updated(player: Dictionary)

# Signals for the lobby
signal hosting_started()
signal hosting_failed(message: String)
signal hosting_stopped(message: String)

# Signals for the discovery server
signal discovery_server_started()
signal discovery_server_failed(error: int)
signal discovery_server_stopped()

# Signals for the chat messages
signal chat_messages_updated()

# Default name for the player's lobby
@export var lobby_name: String = "Game Lobby"

# Game server port: connect to lobbies & players
@export var game_port: int = 9500

# Discovery server port: broadcast presence
@export var broadcast_port: int = 9501

# Discovery client port: receive responses from discovery servers
@export var response_port: int = 9502

# Max number of players allowed on the server
@export var max_players: int = 8

# Connection timeout in seconds
@export var connection_timeout: float = 3.0

# Whether to save & restore the local player automatically
@export var autosave: bool = true

# The save location for player-specific options
@export var player_save_file: String = "user://jammin_player_save_{0}.json"

# The save location for lobby-wide options
@export var options_save_file: String = "user://jammin_options.json"

func _ready() -> void:
  setup_config()
  setup_signals()

func setup_config() -> void:
  if Lobby.config and Lobby.config != self:
    merge_config(Lobby.config)
    Lobby.config.queue_free()
  Lobby.config = self

func setup_signals() -> void:
  # Pass through signals from the Lobby singleton

  # Make sure we're not connecting signals twice
  if Lobby.me_joining_lobby.is_connected(_me_joining_lobby): return

  # Signals for the local player
  Lobby.me_joining_lobby.connect(_me_joining_lobby)
  Lobby.me_joined_lobby.connect(_me_joined_lobby)
  Lobby.me_left_lobby.connect(_me_left_lobby)
  Lobby.me_updated.connect(_me_updated)

  # Signals for other players
  Lobby.player_joining_lobby.connect(_player_joining_lobby)
  Lobby.player_joined_lobby.connect(_player_joined_lobby)
  Lobby.player_left_lobby.connect(_player_left_lobby)
  Lobby.player_updated.connect(_player_updated)

  # Signals for the host
  Lobby.host_joining_lobby.connect(_host_joining_lobby)
  Lobby.host_joined_lobby.connect(_host_joined_lobby)
  Lobby.host_left_lobby.connect(_host_left_lobby)

  # Signals for the lobby
  Lobby.hosting_started.connect(_hosting_started)
  Lobby.hosting_failed.connect(_hosting_failed)
  Lobby.hosting_stopped.connect(_hosting_stopped)

  # Signals for the discovery server
  Lobby.discovery_server_started.connect(_discovery_server_started)
  Lobby.discovery_server_failed.connect(_discovery_server_failed)
  Lobby.discovery_server_stopped.connect(_discovery_server_stopped)

  # Signals for the chat messages
  Lobby.chat_messages_updated.connect(_chat_messages_updated)


func merge_config(config: JamminLobby) -> void:
  lobby_name = config.lobby_name
  game_port = config.game_port
  broadcast_port = config.broadcast_port
  response_port = config.response_port
  max_players = config.max_players
  connection_timeout = config.connection_timeout
  autosave = config.autosave
  player_save_file = config.player_save_file
  options_save_file = config.options_save_file

# Signal handlers **************************************************************

func _me_joining_lobby() -> void:
  me_joining_lobby.emit()
  if visible: pass # TODO: update UI

func _me_joined_lobby(player: Dictionary) -> void:
  me_joined_lobby.emit(player)
  if visible: pass # TODO: update UI

func _me_left_lobby(reason: String) -> void:
  me_left_lobby.emit(reason)
  if visible: pass # TODO: update UI

func _me_updated(player: Dictionary) -> void:
  me_updated.emit(player)
  if visible: pass # TODO: update UI

func _player_joining_lobby(pid: int) -> void:
  player_joining_lobby.emit(pid)
  if visible: pass # TODO: update UI

func _player_joined_lobby(player: Dictionary) -> void:
  player_joined_lobby.emit(player)
  if visible: pass # TODO: update UI

func _player_left_lobby(player: Dictionary) -> void:
  player_left_lobby.emit(player)
  if visible: pass # TODO: update UI

func _player_updated(player: Dictionary) -> void:
  player_updated.emit(player)
  if visible: pass # TODO: update UI

func _host_joining_lobby() -> void:
  host_joining_lobby.emit()
  if visible: pass # TODO: update UI

func _host_joined_lobby() -> void:
  host_joined_lobby.emit()
  if visible: pass # TODO: update UI

func _host_left_lobby(reason: String) -> void:
  host_left_lobby.emit(reason)
  if visible: pass # TODO: update UI

func _host_player_joining_lobby(pid: int) -> void:
  host_player_joining_lobby.emit(pid)
  if visible: pass # TODO: update UI

func _host_player_joined_lobby(player: Dictionary) -> void:
  host_player_joined_lobby.emit(player)
  if visible: pass # TODO: update UI

func _hosting_started() -> void:
  hosting_started.emit()
  if visible: pass # TODO: update UI

func _hosting_failed(message: String) -> void:
  hosting_failed.emit(message)
  if visible: pass # TODO: update UI

func _hosting_stopped(message: String) -> void:
  hosting_stopped.emit(message)
  if visible: pass # TODO: update UI

func _discovery_server_started() -> void:
  discovery_server_started.emit()
  if visible: pass # TODO: update UI

func _discovery_server_failed(error: int) -> void:
  discovery_server_failed.emit(error)
  if visible: pass # TODO: update UI

func _discovery_server_stopped() -> void:
  discovery_server_stopped.emit()
  if visible: pass # TODO: update UI

func _chat_messages_updated() -> void:
  chat_messages_updated.emit()
  if visible: pass # TODO: update UI

