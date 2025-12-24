# network_manager.gd
# Handles multiplayer networking - hosting and joining games
extends Node

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal server_started
signal connection_failed
signal connected_to_server

const PORT: int = 7777
const MAX_PLAYERS: int = 10

var peer: ENetMultiplayerPeer


func _ready() -> void:
	# Connect multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game() -> Error:
	"""Start hosting a game server."""
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_PLAYERS)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		server_started.emit()
		print("[NetworkManager] Server started on port ", PORT)
		
		# Host is also a player, spawn them
		GameManager.spawn_player(1)  # Server is always peer_id 1
	else:
		push_error("[NetworkManager] Failed to create server: ", error)
	
	return error


func join_game(address: String) -> Error:
	"""Join an existing game server."""
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("[NetworkManager] Connecting to ", address, ":", PORT)
	else:
		push_error("[NetworkManager] Failed to connect: ", error)
	
	return error


func disconnect_from_game() -> void:
	"""Disconnect from the current game."""
	if peer:
		peer.close()
		multiplayer.multiplayer_peer = null
		peer = null
		print("[NetworkManager] Disconnected from game")


func is_server() -> bool:
	"""Check if this instance is the server."""
	return multiplayer.is_server()


func get_my_id() -> int:
	"""Get this peer's unique ID."""
	return multiplayer.get_unique_id()


# Signal handlers
func _on_peer_connected(id: int) -> void:
	print("[NetworkManager] Peer connected: ", id)
	player_connected.emit(id)
	
	# Server spawns players when they connect
	if multiplayer.is_server():
		GameManager.spawn_player(id)


func _on_peer_disconnected(id: int) -> void:
	print("[NetworkManager] Peer disconnected: ", id)
	player_disconnected.emit(id)
	GameManager.remove_player(id)


func _on_connected_to_server() -> void:
	print("[NetworkManager] Connected to server!")
	connected_to_server.emit()


func _on_connection_failed() -> void:
	push_error("[NetworkManager] Connection failed!")
	connection_failed.emit()
	peer = null


func _on_server_disconnected() -> void:
	print("[NetworkManager] Server disconnected")
	peer = null

