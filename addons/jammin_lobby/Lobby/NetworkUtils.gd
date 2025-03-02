class_name NetworkUtils

# Some network utilities
#
# NetworkUtils.get_local_ipv4_addresses()
#   Returns an array of local IPv4 addresses
#
# NetworkUtils.get_external_ip()
#   Returns the external IP address by pinging api.ipify.org
#
# NetworkUtils.is_good_address(address: String) -> bool
#   Returns true if the address is a good address

# Network utilities
static func get_local_ipv4_addresses() -> Array[String]:
	var ipv4_addresses: Array[String] = []
	for address in IP.get_local_addresses():
		if not is_good_address(address): continue
		ipv4_addresses.append(address)
	return ipv4_addresses

static func get_external_ip() -> Array:
	var http = HTTPRequest.new()
	Engine.get_main_loop().root.add_child(http)
	http.request("https://api.ipify.org")
	var result = await http.request_completed
	Engine.get_main_loop().root.remove_child(http)
	http.queue_free()
	var wan_ip = result[3].get_string_from_utf8()
	if not is_good_address(wan_ip): return [ERR_CANT_RESOLVE, ""]
	return [OK, wan_ip]

# Tries to get the router IP address (kinda slow)
# Tested on:
#   - ✅ macOS 15.1.1
#   - ❓ Windows 10
#   - ❓ Windows 11
#   - ❓ Linux
static func get_router_ip():
	var output := []
	var exit_code: int
	
	var router_ip: String = ""

	match OS.get_name():
		"Windows":
			exit_code = OS.execute("ipconfig", [], output)
			for line in output[0].split("\n"): if "Default Gateway" in line: router_ip = line.split(":")[-1].strip_edges()
		"macOS":
			exit_code = OS.execute("netstat", ["-nr"], output)
			for line in output[0].split("\n"): if "default" in line: router_ip = line.split()[1]
		"Linux":
			exit_code = OS.execute("ip", ["route", "show", "default"], output)
			if output[0]: router_ip = output[0].split()[2]

	if is_good_address(router_ip): return router_ip
	return null

static func is_good_address(address: String) -> bool:
	if not address.is_valid_ip_address(): return false
	if address.begins_with("127."): return false
	if address.split(".").size() != 4: return false
	return true
