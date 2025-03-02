# Based on the excellent rpc-await by @dominiks.
# https://github.com/dominiks/rpc-await

class_name JamminRequest extends JamminBase

var rc: int = 0 # request counter
var _requests: Dictionary = { }
var _responses := {}
var timeout := 10.0
var tick_rate := 0.1 # 10 ticks per second

func on_ask(req_name: String, player_fn: Callable = no_op): _requests[req_name] = player_fn
func remove_on_ask(req_name: String): _requests.erase(req_name)

# This is all handled by the caller -- we send off the request, then wait for them to call
# us and set a _response[req_id].
func ask(pid: int, req_name: String, data: Dictionary):
	if not Lobby.has_multiplayer_connection(): return null
	if not Lobby.pid_in_lobby(pid): push_error("Player not in lobby: " + str(pid)); return null

	var req_id = str(pid) + "_" + req_name + "_" + str(_next_rc())
	_responses[req_id] = null # this will be set by the response
	
	# Fire off the request
	_request.rpc_id(pid, req_id, req_name, data)
	
	# Wait for the response for up to timeout seconds
	var response = await _wait_for_response(req_id)
	
	# Now send the response back to the caller (which is actually ourselves)
	return response

# Broadcast does not wait for a response from anyone.
func broadcast(req_name: String, data: Dictionary): _request.rpc("broadcast", req_name, data)

func _wait_for_response(req_id: String):
	for i in range(timeout * (1.0 / tick_rate)):
		# Did we get a response?
		var response = _responses[req_id]
		if response != null: _responses.erase(req_id); return response
		
		# Otherwise, wait again for the next tick
		await wait(tick_rate)

	# Timeout
	_responses.erase(req_id)
	return null

@rpc("any_peer", "reliable", "call_local")
func _request(req_id: String, req_name: String, data: Dictionary):
	var sid = multiplayer.get_remote_sender_id()
	var _request_fn = _requests.get(req_name)
	if not _request_fn: lm(sid, req_id, { "error": "Request function not found for %s" % req_name }); return

	var requester = Lobby.find_by_pid(sid)
	var response = await _request_fn.call(data, requester)

	if req_id == "broadcast": return # broadcast does not need a response

	# Now send the response back to the caller so they can continue
	_response.rpc_id(sid, req_id, response)

@rpc("any_peer", "reliable", "call_local")
func _response(req_id: String, response: Dictionary): _responses[req_id] = response

func _next_rc(): rc += 1; return rc

func no_op(_a = null, _b = null, _c = null): pass
