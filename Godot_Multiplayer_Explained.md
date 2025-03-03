# Multiplayer in Godot 4.x -- the Best Guide on the Internet

by [Jamon Holmgren](https://jamon.dev) -- [@jamonholmgren](https://x.com/jamonholmgren)

_last updated: 2025-03-03_

The docs for Godot's multiplayer system are lacking, so this is a collection of notes I've been taking as I've been learning and building [JamminLobby](https://github.com/jamonholmgren/jammin_lobby).

This is focused on normal level multiplayer -- above basic, but not super advanced either. Good enough for most indie games.

## `multiplayer` and `multiplayer_peer`

In every node, you have `multiplayer`. This is technically a [SceneMultiplayer](https://docs.godotengine.org/en/stable/classes/class_scenemultiplayer.html)
object.

There's also a `multiplayer.multiplayer_peer` property. This is by default an [OfflineMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_offlinemultiplayerpeer.html) object.

## OfflineMultiplayerPeer

The OfflineMultiplayerPeer object has no `start_server` method, but always reports that it's
a server if you run `multiplayer.is_server()`. It also says it's connected if you check
`multiplayer.multiplayer_peer.get_connection_status()`.

## Stopping the server / leaving the server

I highly recommend NOT setting `multiplayer.multiplayer_peer` to `null`, as many other
guides on the internet will tell you to do. It makes everything more complicated, because
you then have to check if it's null every time you do anything.

For example, if you have code that calls `get_multiplayer_authority()`, it will produce an error if the peer is null:

`No multiplayer peer is assigned. Unable to get unique ID.`

Instead, if you want to disconnect from the server, use this:

```gdscript
multiplayer.multiplayer_peer.close()
multiplayer.multiplayer_peer = new OfflineMultiplayerPeer() # Do not set to null!
```

> [!NOTE]
> JamminLobby handles this for you. When you call `Lobby.stop_hosting()` or `Lobby.leave()`,
> it will disconnect from the server and set `multiplayer.multiplayer_peer` to
> a new OfflineMultiplayerPeer.

## Connection status

## Lifecycle Events

- multiplayer.peer_connected
- multiplayer.peer_disconnected
- multiplayer.server_disconnected
- multiplayer.connected_to_server
- multiplayer.connection_failed
- multiplayer.peer_packet
- multiplayer.peer_authenticating
- multiplayer.peer_authentication_failed

- multiplayer.multiplayer_peer.peer_connected
- multiplayer.multiplayer_peer.peer_disconnected

### Starting a server

There are _no signals_ when you start a server successfully. Instead, you have to use `your_peer.create_server(port, max_players)` and then check if it succeeded.

```gdscript
var peer = ENetMultiplayer.new()
var error = peer.create_server(1234, 8) # port 1234, max 8 players
if error != OK:
  print("Failed to create server")
else:
  print("Server created successfully")
```

> [!NOTE]
> JamminLobby handles this for you and provides signals:
>
> ```gdscript
> Lobby.hosting_started.connect(func(): print("Hosting started"))
> Lobby.hosting_failed.connect(func(message: String): print("Hosting failed: ", message))
> Lobby.start_hosting()
> ```

### Getting your peer ID

You can get your peer ID by using `multiplayer.get_unique_id()`.

```gdscript
var peer_id = multiplayer.get_unique_id()
print("Peer ID: ", peer_id)
```

However, with the OfflineMultiplayerPeer, this will always return 1.

### `multiplayer.peer_connected`

```gdscript
multiplayer.peer_connected.connect(func(peer_id: int):
  print("Peer connected: ", peer_id)
)
```

### `multiplayer.peer_disconnected`

```gdscript
multiplayer.peer_disconnected.connect(func(peer_id: int):
  print("Peer disconnected: ", peer_id)
)
```

### `multiplayer.server_disconnected`

```gdscript
multiplayer.server_disconnected.connect(func(peer_id: int):
  print("Server disconnected: ", peer_id)
)
```

### `multiplayer.connected_to_server`

```gdscript
multiplayer.connected_to_server.connect(func():
  print("Connected to server")
)
```

### `multiplayer.connection_failed` (Server)

```gdscript
multiplayer.connection_failed.connect(func(message: String):
  print("Connection failed: ", message)
)
```

### `multiplayer.peer_packet`

```gdscript
multiplayer.peer_packet.connect(func(peer_id: int, packet: Packet): # Packet is a Dictionary
  print("Peer packet: ", peer_id, packet)
)
```

### `multiplayer.peer_authenticating`

```gdscript
  multiplayer.peer_authenticating.connect(func(peer_id: int): # This is called when a peer is authenticating
  print("Peer authenticating: ", peer_id)
)
```

### `multiplayer.peer_authentication_failed`

```gdscript
multiplayer.peer_authentication_failed.connect(func(peer_id: int, message: String): # This is called when a peer authentication fails
  print("Peer authentication failed: ", peer_id, message)
)
```

## `multiplayer.multiplayer_peer`

The `multiplayer.multiplayer_peer` property is by default an [OfflineMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_offlinemultiplayerpeer.html) object.

### `multiplayer.multiplayer_peer.create_server`

```gdscript
multiplayer.multiplayer_peer.create_server(port: int, max_players: int = 4)
```

### `multiplayer.multiplayer_peer.create_client`

```gdscript
multiplayer.multiplayer_peer.create_client(ip: String, port: int)
```
