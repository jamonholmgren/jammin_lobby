# The configuration for the lobby lives here
# You add this node to your main scene to configure the lobby system
# Even if the scene gets unloaded, this config will persist in .instance
# (until the next time the scene is loaded -- but even then, we'll copy
# the current config to the new instance)
class_name JamminLobby extends JamminBase

static var instance: JamminLobby = null

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

# Game name
@export var game_name: String = ProjectSettings.get_setting("application/config/name")

# Game version
@export var game_version: String = ProjectSettings.get_setting("application/config/version")

