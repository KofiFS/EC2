# lobby.gd
# UI for hosting/joining multiplayer games
extends Control

@onready var address_input: LineEdit = $Panel/VBoxContainer/AddressInput
@onready var host_button: Button = $Panel/VBoxContainer/HostButton
@onready var join_button: Button = $Panel/VBoxContainer/JoinButton
@onready var customize_button: Button = $Panel/VBoxContainer/CustomizeButton
@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel
@onready var customize_menu: Control = $CustomizeMenu


func _ready() -> void:
	# Connect network signals
	NetworkManager.server_started.connect(_on_server_started)
	NetworkManager.connected_to_server.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	
	# Set default address
	address_input.text = "127.0.0.1"


func _on_host_pressed() -> void:
	"""Start hosting a game."""
	status_label.text = "Starting server..."
	host_button.disabled = true
	join_button.disabled = true
	
	var error = NetworkManager.host_game()
	if error != OK:
		status_label.text = "Failed to start server!"
		host_button.disabled = false
		join_button.disabled = false


func _on_join_pressed() -> void:
	"""Join an existing game."""
	var address = address_input.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	
	status_label.text = "Connecting to " + address + "..."
	host_button.disabled = true
	join_button.disabled = true
	
	var error = NetworkManager.join_game(address)
	if error != OK:
		status_label.text = "Failed to connect!"
		host_button.disabled = false
		join_button.disabled = false


func _on_server_started() -> void:
	"""Handle successful server start."""
	status_label.text = "Server started! Waiting for players..."
	_hide_lobby()


func _on_connected() -> void:
	"""Handle successful connection to server."""
	status_label.text = "Connected!"
	_hide_lobby()


func _on_connection_failed() -> void:
	"""Handle failed connection."""
	status_label.text = "Connection failed!"
	host_button.disabled = false
	join_button.disabled = false


func _hide_lobby() -> void:
	"""Hide the lobby UI after connecting."""
	# Fade out or just hide
	await get_tree().create_timer(0.5).timeout
	visible = false


func _on_customize_pressed() -> void:
	"""Open the customization menu."""
	if customize_menu:
		customize_menu.show_menu()


func show_lobby() -> void:
	"""Show the lobby UI."""
	visible = true
	host_button.disabled = false
	join_button.disabled = false
	status_label.text = ""

