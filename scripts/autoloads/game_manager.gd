# game_manager.gd
# Manages game state, player spawning, and respawning
extends Node

signal player_spawned(peer_id: int, rock: Node2D)
signal player_died(peer_id: int)
signal player_respawning(peer_id: int, time_left: float)

const SPACE_ROCK_SCENE: PackedScene = preload("res://scenes/space_rock/space_rock.tscn")
const RESPAWN_DELAY: float = 3.0

# Track all players
var players: Dictionary = {}  # peer_id -> SpaceRock node
var spawn_points: Array[Vector2] = []
var player_spawn_container: Node = null


func _ready() -> void:
	player_died.connect(_on_player_died)
	_generate_spawn_points()


func _generate_spawn_points() -> void:
	"""Generate spawn points in a circle around the center."""
	spawn_points.clear()
	var spawn_radius: float = 400.0
	
	for i in range(MAX_SPAWN_POINTS):
		var angle = (float(i) / MAX_SPAWN_POINTS) * TAU
		var point = Vector2(cos(angle), sin(angle)) * spawn_radius
		spawn_points.append(point)


const MAX_SPAWN_POINTS: int = 10


func set_spawn_container(container: Node) -> void:
	"""Set the node that will contain spawned players."""
	player_spawn_container = container


func spawn_player(peer_id: int) -> void:
	"""Spawn a SpaceRock for the given peer. Server only."""
	if not multiplayer.is_server():
		return
	
	if players.has(peer_id):
		push_warning("[GameManager] Player ", peer_id, " already spawned")
		return
	
	if not player_spawn_container:
		push_error("[GameManager] No spawn container set!")
		return
	
	# Instantiate the rock
	var rock = SPACE_ROCK_SCENE.instantiate()
	rock.name = "SpaceRock_" + str(peer_id)
	
	# Set multiplayer authority to the owning peer
	rock.set_multiplayer_authority(peer_id)
	
	# Pick a spawn position
	var spawn_index = randi() % spawn_points.size()
	rock.position = spawn_points[spawn_index]
	
	# Add to scene tree
	player_spawn_container.add_child(rock, true)
	players[peer_id] = rock
	
	print("[GameManager] Spawned player ", peer_id, " at ", rock.position)
	player_spawned.emit(peer_id, rock)


func remove_player(peer_id: int) -> void:
	"""Remove a player's SpaceRock from the game."""
	if players.has(peer_id):
		var rock = players[peer_id]
		if is_instance_valid(rock):
			rock.queue_free()
		players.erase(peer_id)
		print("[GameManager] Removed player ", peer_id)


func get_player(peer_id: int) -> Node2D:
	"""Get a player's SpaceRock node."""
	if players.has(peer_id):
		return players[peer_id]
	return null


func get_all_players() -> Array:
	"""Get all active SpaceRock nodes."""
	return players.values()


func get_player_count() -> int:
	"""Get the number of active players."""
	return players.size()


func _on_player_died(peer_id: int) -> void:
	"""Handle player death - schedule respawn."""
	if not multiplayer.is_server():
		return
	
	# Remove from active players
	players.erase(peer_id)
	
	print("[GameManager] Player ", peer_id, " died, respawning in ", RESPAWN_DELAY, "s")
	
	# Schedule respawn
	var timer = get_tree().create_timer(RESPAWN_DELAY)
	
	# Emit respawning signal for UI updates
	player_respawning.emit(peer_id, RESPAWN_DELAY)
	
	await timer.timeout
	
	# Check if still connected before respawning
	if multiplayer.multiplayer_peer and multiplayer.get_peers().has(peer_id) or peer_id == 1:
		spawn_player(peer_id)

