# main.gd
# Main game scene controller
extends Node2D

const AIRockScene = preload("res://scenes/ai_rock.tscn")

@onready var players_container: Node2D = $Players
@onready var lobby: Control = $UI/Lobby
@onready var hud: Control = $UI/HUD
@onready var damage_bar: ProgressBar = $UI/HUD/DamageBar
@onready var player_count_label: Label = $UI/HUD/PlayerCount
@onready var arena: Node2D = $Arena

var local_player: SpaceRock = null
var ai_opponent: SpaceRock = null
var ai_respawn_time: float = 3.0  # Seconds before AI respawns


func _ready() -> void:
	# Set up game manager with player container
	GameManager.set_spawn_container(players_container)
	
	# Connect signals
	GameManager.player_spawned.connect(_on_player_spawned)
	GameManager.player_died.connect(_on_player_died)
	NetworkManager.player_connected.connect(_on_network_player_connected)
	NetworkManager.player_disconnected.connect(_on_network_player_disconnected)
	
	# Initially hide HUD until game starts
	hud.visible = false
	
	# Find and track the initial AI opponent
	_setup_ai_tracking()
	
	print("[Main] Scene ready")


func _setup_ai_tracking() -> void:
	"""Find and connect to the AI opponent."""
	ai_opponent = arena.get_node_or_null("AIOpponent") as SpaceRock
	if ai_opponent:
		ai_opponent.rock_destroyed.connect(_on_ai_destroyed)
		print("[Main] AI opponent tracked")


func _on_ai_destroyed() -> void:
	"""Handle AI death - respawn after delay."""
	print("[Main] AI destroyed! Respawning in ", ai_respawn_time, " seconds...")
	ai_opponent = null
	
	# Create a timer for respawn
	var timer = get_tree().create_timer(ai_respawn_time)
	timer.timeout.connect(_respawn_ai)


func _respawn_ai() -> void:
	"""Spawn a new AI opponent."""
	# Random spawn position away from center
	var spawn_angle = randf() * TAU
	var spawn_distance = 400 + randf() * 300
	var spawn_pos = Vector2.from_angle(spawn_angle) * spawn_distance
	
	# Create new AI
	ai_opponent = AIRockScene.instantiate()
	ai_opponent.position = spawn_pos
	arena.add_child(ai_opponent)
	
	# Connect to its destruction signal
	ai_opponent.rock_destroyed.connect(_on_ai_destroyed)
	
	print("[Main] AI respawned at ", spawn_pos)


func _process(_delta: float) -> void:
	# Update HUD
	_update_hud()


func _update_hud() -> void:
	"""Update HUD elements."""
	# Update player count
	player_count_label.text = "Players: " + str(GameManager.get_player_count())
	
	# Update damage bar for local player
	if local_player and is_instance_valid(local_player):
		var health_percent = 1.0 - local_player.get_damage_percent()
		damage_bar.value = health_percent * 100.0
		
		# Color based on health
		if health_percent > 0.5:
			damage_bar.modulate = Color.GREEN
		elif health_percent > 0.25:
			damage_bar.modulate = Color.YELLOW
		else:
			damage_bar.modulate = Color.RED


func _on_player_spawned(peer_id: int, rock: Node2D) -> void:
	"""Handle player spawn."""
	print("[Main] Player spawned: ", peer_id)
	
	# Check if this is our local player
	if peer_id == multiplayer.get_unique_id():
		local_player = rock as SpaceRock
		hud.visible = true
		
		# Connect to damage signal
		if local_player:
			local_player.damage_changed.connect(_on_local_player_damage_changed)


func _on_player_died(peer_id: int) -> void:
	"""Handle player death."""
	print("[Main] Player died: ", peer_id)
	
	if peer_id == multiplayer.get_unique_id():
		local_player = null


func _on_local_player_damage_changed(_current: float, _maximum: float) -> void:
	"""Update UI when local player takes damage."""
	# Damage bar is updated in _process, but we could add effects here
	pass


func _on_network_player_connected(peer_id: int) -> void:
	"""Handle network player connect."""
	print("[Main] Network player connected: ", peer_id)


func _on_network_player_disconnected(peer_id: int) -> void:
	"""Handle network player disconnect."""
	print("[Main] Network player disconnected: ", peer_id)
