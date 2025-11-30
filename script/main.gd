extends Control

const DEF_PORT = 7357
const SEND_PORT = 63575
const LISTEN_PORT = 63574
const PROTO_NAME = "ludus"

@onready var _host_btn = $Panel/VBoxContainer/HBoxContainer2/HBoxContainer/Host
@onready var _connect_btn = $Panel/VBoxContainer/HBoxContainer2/HBoxContainer/Connect
@onready var _disconnect_btn = $Panel/VBoxContainer/HBoxContainer2/HBoxContainer/Disconnect
@onready var _name_edit = $Panel/VBoxContainer/HBoxContainer/NameEdit
@onready var _host_edit = $Panel/VBoxContainer/HBoxContainer2/Hostname
@onready var _game = $Panel/VBoxContainer/Game

var peer = WebSocketMultiplayerPeer.new()
var udp_sender = PacketPeerUDP.new()
var udp_listener = PacketPeerUDP.new()
var is_host = false
var num_players = 0

func _init():
	peer.supported_protocols = ["ludus"]

func _ready():
	udp_sender.bind(LISTEN_PORT)
	udp_listener.bind(SEND_PORT)
	
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.server_disconnected.connect(_close_network)
	multiplayer.connection_failed.connect(_close_network)
	multiplayer.connected_to_server.connect(_connected)

	$AcceptDialog.get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$AcceptDialog.get_label().vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Set the player name according to the system username. Fallback to the path.
	if OS.has_environment("USERNAME"):
		_name_edit.text = OS.get_environment("USERNAME")
	else:
		var desktop_path = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP).replace("\\", "/").split("/")
		_name_edit.text = desktop_path[desktop_path.size() - 2]


func  _process(_delta: float) -> void:
	if udp_listener.get_available_packet_count() > 0:
		var msg = udp_listener.get_var()
		var ip = udp_listener.get_packet_ip()
		if msg is String and msg == "DISCOVER_SERVER" and is_host:
			# responde dizendo "eu sou um servidor" + porta
			udp_sender.set_dest_address(ip, LISTEN_PORT)
			udp_sender.put_var({
			"players": "server",
			"server_name":_name_edit.text + " server" ,
			})
			print("Respondido discovery para ", ip)
		else:
			print(msg)

#utils
func get_lan_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
	return "0.0.0.0"  # fallback

func scan_servers():
	udp_sender.set_broadcast_enabled(true)
	print("Procurando servidores na LAN...")
	udp_sender.connect_to_host("255.255.255.255", LISTEN_PORT)
	udp_sender.put_var("DISCOVER_SERVER")
	

#game
func start_game():
	_host_btn.disabled = true
	_name_edit.editable = false
	_host_edit.editable = false
	_connect_btn.hide()
	_disconnect_btn.show()
	_game.start()


func stop_game():
	_host_btn.disabled = false
	_name_edit.editable = true
	_host_edit.editable = true
	_disconnect_btn.hide()
	_connect_btn.show()
	_game.stop()


func _close_network():
	stop_game()
	$AcceptDialog.popup_centered()
	$AcceptDialog.get_ok_button().grab_focus()
	multiplayer.multiplayer_peer = null
	peer.close()


func _connected():
	_game.set_player_name.rpc(_name_edit.text)


func _peer_connected(id):
	num_players += 1
	_game.on_peer_add(id)

func _peer_disconnected(id):
	num_players -= 1
	print("Disconnected %d" % id)
	_game.on_peer_del(id)


func _on_Host_pressed():
	is_host = true
	udp_sender.set_broadcast_enabled(false)

	multiplayer.multiplayer_peer = null
	peer.create_server(DEF_PORT)
	multiplayer.multiplayer_peer = peer
	_game.add_player(1, _name_edit.text)
	start_game()


func _on_Disconnect_pressed():
	_close_network()


func _on_Connect_pressed():
	multiplayer.multiplayer_peer = null
	peer.create_client("ws://" + _host_edit.text + ":" + str(DEF_PORT))
	multiplayer.multiplayer_peer = peer
	start_game()


func _on_button_pressed() -> void:
	scan_servers()
