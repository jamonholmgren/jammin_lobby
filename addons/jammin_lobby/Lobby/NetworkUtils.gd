class_name NetworkUtils extends Node

@onready var http = HTTPRequest.new()

# Some network utilities
#
# get_local_ipv4_addresses()
#   Returns an array of local IPv4 addresses
#
# get_external_ip()
#   Returns a Result object with the external IP address
#
# get_router_ip()
#   Returns a Result object with the router IP address
#
# is_valid_ipv4(address: String) -> bool
#   Returns true if the address is a good address

func _ready():
	add_child(http)

# Network utilities
func get_local_ipv4_addresses() -> Array[String]:
	var ipv4_addresses: Array[String] = []
	for address in IP.get_local_addresses():
		if not is_valid_ipv4(address): continue
		ipv4_addresses.append(address)
	return ipv4_addresses

# Returns a Result object with the external IP address if successful
func get_external_ip() -> Result:
	http.request("https://api.ipify.org")
	
	var result = await http.request_completed
	
	var wan_ip = result[3].get_string_from_utf8()

	if not is_valid_ipv4(wan_ip): return Result.err(ERR_CANT_RESOLVE)
	
	return Result.ok(wan_ip)

# Tries to get the router IP address (kinda slow)
# Tested on:
#   - ✅ macOS 15.1.1
#   - ❓ Windows 10
#   - ❓ Windows 11
#   - ❓ Linux
func get_router_ip() -> Result:
	var output := []
	
	var router_ip: String = ""

	match OS.get_name():
		"Windows":
			OS.execute("ipconfig", [], output)
			for line in output[0].split("\n"): if "Default Gateway" in line: router_ip = line.split(":")[-1].strip_edges()
		"macOS":
			OS.execute("netstat", ["-nr"], output)
			for line in output[0].split("\n"): if "default" in line: router_ip = line.split()[1]
		"Linux":
			OS.execute("ip", ["route", "show", "default"], output)
			if output[0]: router_ip = output[0].split()[2]

	if is_valid_ipv4(router_ip) and not router_ip.begins_with("127."): return Result.ok(router_ip)
	return Result.err(ERR_CANT_RESOLVE)

func is_valid_ipv4(address: String) -> bool:
	if not address.is_valid_ip_address(): return false
	if address.split(".").size() != 4: return false
	return true

# Result class for handling success/failure responses
class Result:
	var success: bool
	var value: Variant
	var error_code: int = OK

	func _init(p_success: bool, p_value = null, p_error_code: int = OK):
		success = p_success
		value = p_value
		error_code = p_error_code

	static func ok(value) -> Result:
		return Result.new(true, value)
		
	static func err(error_code: int = ERR_CANT_RESOLVE) -> Result:
		return Result.new(false, null, error_code)
