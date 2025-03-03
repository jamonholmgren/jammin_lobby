# JamminLobby -- Multiplayer Lobby System for Godot 4.x

Have you ever been confused by multiplayer in Godot?

Do you want a drop-dead simple lobby and multiplayer system for your game?

This is the plugin for you!

> [!CAUTION]
> This is a work in progress! I hope to have it stable by mid-2025.

## Features

- Very simple to set up
- Automatically handles client/server connections
- Easy lobby setup
- Optional built-in basic Lobby UI
- or build your own custom UI and connect easily to this
- Built-in chat system
- We went through the pain so you don't have to

What's not to love?

## Setup

1. Download this repo as a zip and unzip it
2. Place the `addons/jammin_lobby` folder in your own `addons` folder
3. Open your project in Godot 4.x and go to `Project -> Project Settings -> addons` to enable it
4. Restart the project

## Using the built-in Lobby UI

Just add the `JamminLobbyUI` scene to your main scene. It'll handle everything for you.

To access the current players in the lobby, use `Lobby.get_players()`. It'll return a dictionary that looks like this:

```gdscript
{
  1: {
    "id": 1,
    "username": "Your Playername",
    "is_host": true,
  },
  2948524: {
    "id": 2948524,
    "username": "Player 2",
    "is_host": false,
  },
}
```

To access your own player object, use `Lobby.me`:

```gdscript
Lobby.me.username
Lobby.me.is_host

print(Lobby.me)

# {
#   "id": 1,
#   "username": "Your Playername",
#   "is_host": true,
# }
```

To update your username, use `Lobby.me.update_me({ "ready": true })`. This will update on all other players as well.

## Custom Usage

To build your own custom UI, you can use the `Lobby` singleton to connect to the lobby and send/receive messages.

```gdscript
Lobby.setup({
  "lobby_name": "My Game",
  "game_port": 1234,
  "broadcast_port": 1235,
  "response_port": 1236,
  "autosave": true,
  "save_slot": 1,
  "options_save_file": "user://options.json"
})
```

To start hosting, use `Lobby.start_hosting()`.

To join a game, use `Lobby.join({ "ip": "192.168.1.100", "port": 1234 })`.

To send a message to all players, use `Lobby.send_message("Hello, world!")`.

To get the current players in the lobby, use `Lobby.get_players()`.

To get your own player object, use `Lobby.me`.

To update your username, use `Lobby.me.update_me({ "ready": true })`. This will update on all other players as well.

You can find other lobbies on the current network by calling `Lobby.find_lobbies()`, and connect to a specific lobby by calling `Lobby.join(lobby)`.

There are a variety of signals and other features included. Read the [plugin docs](addons/jammin_lobby/README.md) for more information!

## Running the Demo Project

Download or clone this repo to your local machine and open the `project.godot` file in Godot 4.x.

Run the project as you normally would, and play a multiplayer tank game with your friends!
