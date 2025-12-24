# space_rock.gd
# The main player-controlled physics actor
# Players apply forces with WASD, collisions deal damage based on momentum differential
extends RigidBody2D
class_name SpaceRock

# Movement configuration
@export var force_multiplier: float = 50000.0  # Very strong acceleration
@export var max_velocity: float = 2000.0  # High max speed

# Sonic Boom configuration
@export var sonic_boom_multiplier: float = 5.0  # 5x boost per charge tick
@export var sonic_boom_interval: float = 0.05  # Charge builds every 0.05 seconds
@export var sonic_boom_max_velocity: float = 4000.0  # Higher cap after blast
@export var sonic_boom_max_charge_time: float = 2.5  # Max charge duration in seconds

# Damage configuration  
@export var max_health: float = 1000.0
@export var damage_scale: float = 0.01  # Scales physics force to damage

# Synced across network
var current_damage: float = 0.0:
	set(value):
		current_damage = value
		damage_changed.emit(current_damage, max_health)

var rock_color: Color = Color.WHITE

# Sonic boom state
var sonic_boom_charge: float = 0.0  # How many 10x boosts we've accumulated
var is_charging_boom: bool = false  # Currently holding space
var charge_direction: Vector2 = Vector2.ZERO  # Direction player wants to blast
var velocity_before_charge: Vector2 = Vector2.ZERO  # Store velocity when charge started
var just_blasted: bool = false  # Flag to allow higher velocity after blast

# AI control flag - set to true if this rock is AI controlled
var is_ai_controlled: bool = false

# Signals
signal damage_changed(current: float, maximum: float)
signal rock_destroyed

# Node references
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var camera: Camera2D = $Camera2D
@onready var trail: CPUParticles2D = $Trail


func _ready() -> void:
	# Check if this rock has an AI controller
	for child in get_children():
		if child.name == "AIController":
			is_ai_controlled = true
			break
	
	# Only enable camera for local player (not AI)
	if camera:
		camera.enabled = is_multiplayer_authority() and not is_ai_controlled
	
	# Randomize color for this rock
	_setup_visuals()
	
	# Connect to body_entered for collision detection
	body_entered.connect(_on_body_entered)
	
	# Configure physics
	gravity_scale = 0.0  # No gravity in space
	
	print("[SpaceRock] Ready - AI: ", is_ai_controlled, ", Authority: ", get_multiplayer_authority())


func _setup_visuals() -> void:
	"""Set up the rock's visual appearance."""
	# Generate a random bright color (skip for AI - they have preset colors)
	if not is_ai_controlled:
		rock_color = Color.from_hsv(randf(), 0.7, 1.0)
		if sprite:
			sprite.modulate = rock_color
	
	# Set trail color to match rock
	if trail:
		var trail_color = rock_color if not is_ai_controlled else Color(1, 0.3, 0.3, 1)
		trail_color.a = 0.7  # Semi-transparent trail
		trail.color = trail_color


func _physics_process(delta: float) -> void:
	# Skip input processing for AI-controlled rocks
	if is_ai_controlled:
		return
	
	# Only process input for the local player
	if not is_multiplayer_authority():
		return
	
	# Get input direction
	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Handle Sonic Boom charging
	_handle_sonic_boom(delta, input_direction)
	
	# If charging, freeze movement but track desired direction
	if is_charging_boom:
		# Freeze the rock in place
		linear_velocity = Vector2.ZERO
		
		# Track the direction player wants to blast
		if input_direction != Vector2.ZERO:
			charge_direction = input_direction.normalized()
		return  # Skip normal movement while charging
	
	# Normal movement when not charging
	if input_direction != Vector2.ZERO:
		var force = input_direction.normalized() * force_multiplier
		apply_central_force(force)
	
	# Clamp velocity - allow higher max right after a blast
	var current_max = sonic_boom_max_velocity if just_blasted else max_velocity
	if linear_velocity.length() > current_max:
		linear_velocity = linear_velocity.normalized() * current_max
	
	# Decay the blast state when velocity drops below normal max
	if just_blasted and linear_velocity.length() <= max_velocity:
		just_blasted = false


func _handle_sonic_boom(delta: float, input_direction: Vector2) -> void:
	"""Handle the sonic boom charge-and-release ability."""
	
	# Start charging when space is pressed
	if Input.is_action_just_pressed("sonic_boom"):
		is_charging_boom = true
		sonic_boom_charge = 0.0
		velocity_before_charge = linear_velocity
		# Initialize charge direction from current movement or input
		if input_direction != Vector2.ZERO:
			charge_direction = input_direction.normalized()
		elif linear_velocity.length() > 10.0:
			charge_direction = linear_velocity.normalized()
		else:
			charge_direction = Vector2.RIGHT  # Default direction
		print("[SpaceRock] Charging sonic boom...")
	
	# Build charge while holding (capped at max charge time)
	if is_charging_boom and Input.is_action_pressed("sonic_boom"):
		var max_charge_ticks = sonic_boom_max_charge_time / sonic_boom_interval
		sonic_boom_charge += delta / sonic_boom_interval  # +1 charge per interval
		sonic_boom_charge = min(sonic_boom_charge, max_charge_ticks)  # Cap at max
		# Update direction if player changes input
		if input_direction != Vector2.ZERO:
			charge_direction = input_direction.normalized()
	
	# RELEASE - Blast off!
	if Input.is_action_just_released("sonic_boom") and is_charging_boom:
		_release_sonic_boom()


func _release_sonic_boom() -> void:
	"""Release the charged sonic boom and blast off!"""
	is_charging_boom = false
	
	# Check if player is holding a direction - only blast if they are!
	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_direction == Vector2.ZERO:
		# No direction held - cancel the blast, just resume normal movement
		print("[SpaceRock] Sonic boom cancelled - no direction held")
		sonic_boom_charge = 0.0
		return
	
	# Player is holding a direction - BLAST OFF!
	just_blasted = true
	charge_direction = input_direction.normalized()
	
	# Calculate total boost: base force × 10x × number of charge ticks
	var charge_ticks = floor(sonic_boom_charge)
	if charge_ticks < 1:
		charge_ticks = 1  # Minimum 1 tick even for quick tap
	
	var boom_force = charge_direction * force_multiplier * sonic_boom_multiplier * charge_ticks
	
	# Apply as impulse for instant velocity
	apply_central_impulse(boom_force * 0.01)
	
	print("[SpaceRock] SONIC BOOM! Ticks: ", charge_ticks, " | Multiplier: ", sonic_boom_multiplier, "x | Total Boost: ", charge_ticks * sonic_boom_multiplier, "x | Velocity: ", snapped(linear_velocity.length(), 1))
	
	# Reset charge
	sonic_boom_charge = 0.0


func _on_body_entered(body: Node2D) -> void:
	"""Handle collision with another body."""
	# In multiplayer, only the server calculates damage
	# In single-player (no peer), process locally
	var is_singleplayer = multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	if not is_singleplayer and not multiplayer.is_server():
		return
	
	# Only care about collisions with other SpaceRocks
	if not body is SpaceRock:
		return
	
	var other_rock: SpaceRock = body as SpaceRock
	
	# Only the rock with the lower instance ID processes the collision
	# This prevents double-processing
	if get_instance_id() > other_rock.get_instance_id():
		return
	
	# Calculate collision damage for both rocks
	_calculate_collision_damage(other_rock)


func _calculate_collision_damage(other: SpaceRock) -> void:
	"""
	Calculate damage from collision based on momentum.
	The rock with LESS momentum takes damage equal to the difference.
	This function handles damage for BOTH rocks involved.
	"""
	# Impact force = mass × velocity magnitude
	var my_force: float = mass * linear_velocity.length()
	var their_force: float = other.mass * other.linear_velocity.length()
	
	# Calculate damage as the force differential
	var damage_force: float = abs(my_force - their_force)
	var damage_amount: float = damage_force * damage_scale
	
	# Minimum damage threshold to prevent tiny bumps causing damage
	if damage_amount < 1.0:
		print("[SpaceRock] Collision too weak - no damage. My force=", int(my_force), " Their force=", int(their_force))
		return
	
	var is_singleplayer = multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	
	print("[SpaceRock] COLLISION: ", name, " (force=", int(my_force), ") vs ", other.name, " (force=", int(their_force), ") | Damage=", int(damage_amount))
	
	# The rock with LESS force takes the damage
	if my_force < their_force:
		# I lose this collision
		if is_singleplayer:
			_apply_damage(damage_amount)
		else:
			_apply_damage.rpc(damage_amount)
		print("[SpaceRock] >>> ", name, " TAKES ", int(damage_amount), " DAMAGE")
	elif their_force < my_force:
		# They lose this collision
		if is_singleplayer:
			other._apply_damage(damage_amount)
		else:
			other._apply_damage.rpc(damage_amount)
		print("[SpaceRock] >>> ", other.name, " TAKES ", int(damage_amount), " DAMAGE")
	else:
		# Equal force - both take half damage
		var half_damage = damage_amount / 2.0
		if is_singleplayer:
			_apply_damage(half_damage)
			other._apply_damage(half_damage)
		else:
			_apply_damage.rpc(half_damage)
			other._apply_damage.rpc(half_damage)
		print("[SpaceRock] >>> BOTH take ", int(half_damage), " DAMAGE (tied)")


@rpc("authority", "call_local", "reliable")
func _apply_damage(amount: float) -> void:
	"""Apply damage to this rock. Called via RPC from server."""
	current_damage += amount
	
	print("[SpaceRock] ", name, " took ", amount, " damage (Total: ", current_damage, "/", max_health, ")")
	
	# Check for destruction
	if current_damage >= max_health:
		_die()


func _die() -> void:
	"""Handle rock destruction."""
	print("[SpaceRock] ", name, " destroyed!")
	
	rock_destroyed.emit()
	
	# Notify game manager (server-side or single-player)
	var is_singleplayer = multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	if is_singleplayer or multiplayer.is_server():
		GameManager.player_died.emit(get_multiplayer_authority())
	
	# Remove from scene
	queue_free()


func get_damage_percent() -> float:
	"""Get current damage as a percentage (0.0 - 1.0)."""
	if max_health <= 0:
		return 0.0
	return clamp(current_damage / max_health, 0.0, 1.0)


func heal(amount: float) -> void:
	"""Heal the rock by reducing damage."""
	current_damage = max(0.0, current_damage - amount)

