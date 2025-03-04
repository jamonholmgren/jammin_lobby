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
a server if you run `multiplayer.is_server()`.

It also says it's connected if you check
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

Want to know if you're the server, or if you're connected to a server, or if you're offline?

Here's the best way to do that (outside of using JamminLobby):

```gdscript
func online() -> bool:
  if not multiplayer: return false
  if multiplayer.multiplayer_peer is not ENetMultiplayerPeer: return false
  return multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
```

> [!NOTE]
> JamminLobby not only does this, but also provides signals for each of the
> connection statuses. It also has status strings for each connection type:
> `Lobby.status() # "Offline", "Connecting", "Connected", "Server"`

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

### Starting a server as the host

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
> JamminLobby handles this for you and provides signals. We call it "hosting" rather than
> "starting a server".
>
> ```gdscript
> Lobby.hosting_started.connect(func(): print("Hosting started"))
> Lobby.hosting_failed.connect(func(message: String): print("Hosting failed: ", message))
> Lobby.start_hosting()
> ```

#### Authenticating

If you want an authentication callback, you can set it like this:

```gdscript
multiplayer.set_auth_callback(func(_peer_id: int, _secret: String) -> bool:
  # do something to authenticate the peer
  return true
)
```

The client would need to send the secret to the server as soon as it connects:

```gdscript
multiplayer.
multiplayer.multiplayer_peer.put_packet(secret.to_utf8_buffer())
```

#### When a client connects

When a client connects, you'll get signals from two places -- the main multiplayer object and your multiplayer peer object:

`multiplayer.peer_connected(peer_id)`

This will fire with the new peer's id.

`multiplayer.multiplayer_peer.peer_connected(peer_id)`

This will fire with the new peer's id.

#### When a client disconnects

`multiplayer.peer_disconnected(peer_id)`

This will fire with the peer's id.

`multiplayer.multiplayer_peer.peer_disconnected(peer_id)`

This will fire with the peer's id.

---

### Connecting to a server as a client

Like starting a server, there are no signals when you try to connect to a server. Instead, there are two things to do:

1. Check the return value of `your_peer.create_client(ip, port)`
2. Watch for the other signals that fire when you connect to a server, such as:
   - `multiplayer.connected_to_server`
   - `multiplayer.connection_failed`

```gdscript
# Set up the signals on the main multiplayer object
multiplayer.connected_to_server.connect(func(): print("Connected to server"))
multiplayer.connection_failed.connect(func(message: String): print("Connection failed: ", message))

# Now connect to the server
var peer = ENetMultiplayer.new()
var error = peer.create_client("127.0.0.1", 1234)
if error != OK: print("Failed to create connection")
else: print("Connecting to server...")

# Set the multiplayer peer to the new peer
multiplayer.multiplayer_peer = peer
```

> [!NOTE]
> JamminLobby handles this for you and provides signals.
>
> ```gdscript
> Lobby.i_joined_lobby.connect(func(): print("Joined lobby"))
> Lobby.i_failed_to_join_lobby.connect(func(message: String): print("Failed to join lobby: ", message))
> Lobby.join({ "ip": "127.0.0.1", "port": 1234 })
> ```

#### When the connection fails

(after about 30 seconds)

- `multiplayer.connection_failed()` - this will fire with no arguments

(As far as I can tell, there's no `peer` signal on failure, just the main multiplayer object.)

#### When the connection succeeds

`multiplayer.connected_to_server()` - this will fire when you successfully connect to the server -- no arguments provided

`multiplayer.multiplayer_peer.peer_connected(peer_id)` - this will fire _once_ with the server ID, which is 1

`multiplayer.peer_connected(peer_id)` - this will fire _for every single peer_ that is connected to the server, including the server itself (but not you):

```gdscript
multiplayer.peer_connected.connect(func(pid: int): print(pid))
1
1533334359
1364819277
```

#### When a different peer disconnects

`multiplayer.peer_disconnected(peer_id)`

This will fire with the other peer's id on your client.

#### When the server disconnects

`multiplayer.server_disconnected()`

This will fire with no arguments.

`multiplayer.multiplayer_peer.peer_disconnected()`

This will fire with the server's id.

---

---

---

### `multiplayer.peer_connected`

**From the server's perspective:**

This signal fires once when a new peer connects to the server. It provides the new peer_id. `get_remote_sender_id()` during this event returns 0.

```gdscript
multiplayer.peer_connected.connect(func(peer_id: int):
  print("Peer connected: ", peer_id)
)
```

**From the client's perspective:**

This signal fires multiple times during a connection.

### `multiplayer.multiplayer_peer.peer_connected`

On the server, this seems to fire the same time as `multiplayer.peer_connected`. It provides the new peer_id. `get_remote_sender_id()` returns 0.

```gdscript
multiplayer.multiplayer_peer.peer_connected.connect(func(peer_id: int):
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

### Getting your peer ID

When connected, you can get your peer ID by using `multiplayer.get_unique_id()`. This will change when you reconnect, so don't rely on it as a persistent identifier; however, it works fine as an identifier during a single connection. Basically, it's a session ID.

```gdscript
var peer_id = multiplayer.get_unique_id()
print("Peer ID: ", peer_id)
```

- With the OfflineMultiplayerPeer active, this will always return 1, which means "i'm the server".
- With multiplayer.multiplayer_peer set to `null`, this will return 0 and push an error.
- For JamminLobby, `Lobby.id()` will return `0` if you're offline (even if you have an OfflineMultiplayerPeer), and your true peer ID if you're connected.

# Misc Notes

These are hard-won lessons I've learned. Not very necessary for you -- just use JamminLobby.

- Don't ask for `peer.host` prior to `create_server` or `create_client`. It will be null and it'll generate an error.
-
