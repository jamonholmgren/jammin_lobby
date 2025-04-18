# JamminLobby -- Multiplayer Lobby System for Godot 4.x

Have you ever been confused by multiplayer in Godot?

Do you want a drop-dead simple lobby and multiplayer system for your game?

This is the plugin for you!

> [!CAUTION]
> This is a work in progress! I hope to have it stable by mid-2025.

## Demo

This repo has a demo game called "Attack 3D" that you can play with your friends!

There's a web version here that doesn't actually allow you to make lobbies, but you can still see the UI: [https://attack3d.jammin.games/](https://attack3d.jammin.games/)

_(Eventually, I'd like to make JamminLobby work with web browsers, but that's a ways off.)_

And if you clone down this repo and run it in Godot 4.4+, you can play with others in the same LAN (or forward a port).

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
    "username": "Host Player",
    "host": true,
  },
  2948524: {
    "id": 2948524,
    "username": "Client Player",
    "host": false,
  },
}
```

To access your own player object, use `Lobby.me`:

```gdscript
Lobby.me.username
Lobby.me.host

print(Lobby.me)

# {
#   "id": 1,
#   "username": "Your Playername",
#   "host": true,
# }
```

To update your player data, use `Lobby.update_me({ "username": "New Name" })`. This will update your local player data and synchronize it with all other players in the lobby.

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

To send a chat message to all players, use `Lobby.send_chat("Hello, world!")`.

To display system messages locally (not sent to other players), use `Lobby.send_system_chat("Game starting...")`.

To get the current players in the lobby, access `Lobby.get_players()`.

To get your own player object, use `Lobby.me`.

To update your username, use `Lobby.me.update_me({ "ready": true })`. This will update on all other players as well.

You can find other lobbies on the current network by calling `Lobby.find_lobbies()`, and connect to a specific lobby by calling `Lobby.join(lobby)`.

There are a variety of signals and other features included. Read the [plugin docs](addons/jammin_lobby/README.md) for more information!

## Running the Demo Project

Download or clone this repo to your local machine and open the `project.godot` file in Godot 4.x.

Run the project as you normally would, and play a multiplayer tank game with your friends!

## Credits

- [Jamon Holmgren - Jammin Games](https://github.com/jamonholmgren)
- [Denton Holmgren - Deadslap](https://github.com/dentonholmgren)

## License

The JamminLobby plugin (in `addons/jammin_lobby`) is licensed under the MIT license.

The Attack 3D tank demo code (such as GDScript and GDShader code, scene and material files) are also licensed under the MIT license.

The Attack 3D tank demo assets (such as models, textures, audio, icons, and anything else in the `assets` folder) are copyright 2025 Jamon Holmgren and Denton Holmgren. They may be freely used for personal enjoyment, but may not be used for commercial purposes without permission.
