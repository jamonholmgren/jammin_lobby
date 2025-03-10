# JamminLobby

JamminLobby is a powerful multiplayer lobby system for Godot 4.x that provides:

- Seamless multiplayer game hosting and joining
- Automatic LAN game discovery
- Player state synchronization and persistence
- Built-in chat system
- Options management and persistence
- Request/response system for client-server communication

You provide your own lobby UI, and the plugin will handle the hosting, joining, and more.

## Installation

1. Copy the `jammin_lobby` folder into your project's `addons/` directory
2. Enable the plugin in Project Settings -> Plugins

## Core Concepts

### The Lobby Singleton

The `Lobby` singleton (which is automatically added as an autoload) provides the main interface for multiplayer functionality:

```gdscript
# Configure the lobby
Lobby.setup({
    "lobby_name": "My Game",
    "game_port": 1234,
    "broadcast_port": 1235,
    "response_port": 1236,
    "autosave": true,
    "save_slot": 1,
    "options_save_file": "user://options.json"
})

# Host a game
Lobby.start_hosting()

# Join a game at a specific IP and port
Lobby.join({
    "ip": "192.168.1.100",
    "port": 1234
})

# Leave the current game
Lobby.leave("Player left the game")

# Send chat messages
Lobby.send_chat("Hello everyone!")
Lobby.send_system_chat("System message")
```

### Players

Players (also known as "peers") are managed through the `Lobby.players` Dictionary.

```gdscript
# Get the local player
Lobby.me

# Get all players
Lobby.players

# Get a player by ID
Lobby.players[pid]
```

Example Lobby.players data:

```gdscript
{
    # host is always pid 1
    1: {
        "pid": 1,
        "name": "Jammin",
        "color": Color.WHITE,
        "ready": false
    },
    # other players have random pids assigned by Godot's multiplayer system
    10482058: {
        "pid": 10482058,
        "name": "Deadslap",
        "color": Color.BLACK,
        "ready": true
    }
}
```

JamminLobby will automatically synchronize player data across the network.

To update the current player's data, use `Lobby.update_player(data)`. It will be merged with the existing player data and broadcast to all players.

```gdscript
# Update player data
Lobby.update_player({ "ready": false })
```

To update a different player's data, use `Lobby.update_player_id(pid, data)`.

```gdscript
# Update another player's data
Lobby.update_player_id(10482058, { "ready": false })
```

### Options Management

JamminLobby provides a robust options management system that is persisted to a file between game sessions:

```gdscript
# Global lobby options
Options.set("music_volume", 0.5)
Options.get("music_volume")

# Per-player options
Lobby.update_me({ "controls_inverted": true })
Lobby.me.get("controls_inverted", false)
```

### Request/Response System

The built-in request system allows for reliable client-server communication:

```gdscript
# On the host
Lobby.on_ask("start_game", func(data, requester):
    # Handle start game request
    return {"result": "ok"}
)

# On the client
var response = await Lobby.ask(Lobby.host_id(), "start_game", {})
if response.result == "ok":
    start_game()
```

### Chat System

The chat system supports both regular (from a player) and system messages to the local player:

```gdscript
# Send a regular chat message
Lobby.send_chat("Hello everyone!")

# Send a system message (local only)
Lobby.send_system_chat("Game starting in 3...")

# Listen for chat updates
Lobby.chat_messages_updated.connect(func():
    for message in Lobby.chat_messages:
        print(message.body)
)
```

### Discovery Server

The discovery server enables automatic LAN game discovery without needing to know IP addresses:

```gdscript
# Find local games
Lobby.find_lobbies(func(lobbies: Dictionary):
    for ip in lobbies:
        var server = lobbies[ip]
        print("Found server: ", {
            "name": server.server_name,
            "game": server.game_name,
            "version": server.game_version,
            "ip": server.ip,
            "port": server.port
        })
)

# When hosting, discovery is automatically started
Lobby.start_hosting()  # Starts both game server and discovery

# You can manually control discovery
Lobby.start_discovery()  # Start broadcasting presence
Lobby.stop_discovery()   # Stop broadcasting presence

# Get local network information
var local_ips = Lobby.get_local_ipv4_addresses()
var router_ip = Lobby.get_router_ip()
var wan_ip = await Lobby.get_external_ip()
```

The discovery server uses UDP broadcast to:

- Broadcast server presence on the LAN
- Respond to client discovery requests
- Share game name, version, and server name
- Provide connection details (IP/port)

This enables "LAN Party" style gameplay where players can see and join local games automatically.

## Signals

### Core Signals

```gdscript
# Lobby state
signal i_connecting_to_lobby()
signal i_joined_lobby(player: JamminPlayer)
signal i_left_lobby(reason: String)

# Player events
signal player_connecting_to_lobby(pid: int)
signal player_joined_lobby(player: JamminPlayer)
signal player_left_lobby(player: JamminPlayer)
signal player_updated(player: JamminPlayer)

# Host events
signal hosting_started()
signal hosting_failed(message: String)
signal hosting_stopped(message: String)

# Discovery
signal discovery_server_started()
signal discovery_server_failed(error: int)
signal discovery_server_stopped()

# Chat
signal chat_messages_updated()
```

## Advanced Features

### Save Slots

JamminLobby supports multiple save slots for player data:

```gdscript
Lobby.save_slot = 2  # Switch to save slot 2
Lobby.me.restore()   # Restore player data from slot 2
Lobby.me.save()      # Save player data to slot 2
```

### Proxy Support

> Note: Proxy support is currently in development and not yet functional. This will allow for relay servers and NAT traversal in future versions.

## License

MIT License - see LICENSE.md for details.

Created by Jamon Holmgren ([Jammin Games](https://jammin.games))
