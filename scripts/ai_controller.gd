# ai_controller.gd
# AI controller for SpaceRock - aggressively chases and attacks players
extends Node

# AI Configuration
@export var attack_distance: float = 400.0  # Distance to start charging Sonic Boom
@export var sonic_boom_charge_time: float = 0.5  # How long to charge before blasting
@export var attack_cooldown: float = 0.8  # Time between attacks

# Reference to the SpaceRock this AI controls
var rock: SpaceRock
var target: Node2D = null

# AI State
enum State { CHASE, CHARGING, COOLDOWN }
var current_state: State = State.CHASE

# Timers
var charge_timer: float = 0.0
var cooldown_timer: float = 0.0
var search_timer: float = 0.0
var time_chasing: float = 0.0  # Track how long we've been chasing


func _ready() -> void:
	rock = get_parent() as SpaceRock
	if not rock:
		push_error("[AI] Must be child of SpaceRock!")
		return
	
	print("[AI] Controller ready - ATTACK MODE!")


func _physics_process(delta: float) -> void:
	if not rock:
		return
	
	# Search for targets
	search_timer += delta
	if search_timer >= 0.3:
		search_timer = 0.0
		var new_target = _find_nearest_player()
		if new_target:
			target = new_target
	
	# No target? Wander around center
	if not target or not is_instance_valid(target):
		_wander(delta)
		return
	
	# Execute current state
	match current_state:
		State.CHASE:
			_chase_player(delta)
		State.CHARGING:
			_charge_attack(delta)
		State.COOLDOWN:
			_cooldown(delta)


func _wander(_delta: float) -> void:
	"""Move around when no target found."""
	var to_center = -rock.global_position
	if to_center.length() > 100:
		rock.apply_central_force(to_center.normalized() * rock.force_multiplier * 0.3)


func _chase_player(delta: float) -> void:
	"""Aggressively chase the target player."""
	time_chasing += delta
	
	var to_target = target.global_position - rock.global_position
	var distance = to_target.length()
	var direction = to_target.normalized()
	
	# Predict where target is going
	if target is SpaceRock:
		var target_rock = target as SpaceRock
		var predicted_pos = target.global_position + target_rock.linear_velocity * 0.3
		direction = (predicted_pos - rock.global_position).normalized()
	
	# Full speed chase!
	rock.apply_central_force(direction * rock.force_multiplier)
	
	# Clamp velocity
	if rock.linear_velocity.length() > rock.max_velocity:
		rock.linear_velocity = rock.linear_velocity.normalized() * rock.max_velocity
	
	# Attack conditions - more aggressive!
	var should_attack = false
	
	# Attack if close enough
	if distance < attack_distance:
		should_attack = true
	
	# Attack if we've been chasing for a while (force attack)
	if time_chasing > 2.0 and distance < 600:
		should_attack = true
	
	if should_attack:
		_start_charge()


func _start_charge() -> void:
	"""Start charging Sonic Boom."""
	current_state = State.CHARGING
	charge_timer = 0.0
	print("[AI] CHARGING SONIC BOOM!")


func _charge_attack(delta: float) -> void:
	"""Charge up and then blast toward target."""
	if not target or not is_instance_valid(target):
		current_state = State.CHASE
		return
	
	charge_timer += delta
	
	# Freeze in place while charging
	rock.linear_velocity = Vector2.ZERO
	
	# Aim at target
	var direction = (target.global_position - rock.global_position).normalized()
	
	# Release after charge time
	if charge_timer >= sonic_boom_charge_time:
		_release_sonic_boom(direction)


func _release_sonic_boom(direction: Vector2) -> void:
	"""BLAST toward the target!"""
	# Calculate charge power
	var charge_ticks = charge_timer / rock.sonic_boom_interval
	charge_ticks = min(charge_ticks, rock.sonic_boom_max_charge_time / rock.sonic_boom_interval)
	charge_ticks = max(charge_ticks, 5.0)  # Minimum charge
	
	# Calculate and apply the impulse
	var boom_force = direction * rock.force_multiplier * rock.sonic_boom_multiplier * charge_ticks * 0.01
	rock.apply_central_impulse(boom_force)
	
	print("[AI] SONIC BOOM! Power: ", int(charge_ticks), " | Velocity: ", int(rock.linear_velocity.length()))
	
	# Enter cooldown
	current_state = State.COOLDOWN
	cooldown_timer = 0.0


func _cooldown(delta: float) -> void:
	"""Brief cooldown after attacking, then resume chase."""
	cooldown_timer += delta
	
	# Still apply some force toward target during cooldown
	if target and is_instance_valid(target):
		var direction = (target.global_position - rock.global_position).normalized()
		rock.apply_central_force(direction * rock.force_multiplier * 0.5)
	
	# Clamp velocity
	if rock.linear_velocity.length() > rock.max_velocity * 2:
		rock.linear_velocity = rock.linear_velocity.normalized() * rock.max_velocity * 2
	
	# Resume chasing after cooldown
	if cooldown_timer >= attack_cooldown:
		current_state = State.CHASE
		time_chasing = 0.0  # Reset chase timer
		print("[AI] Resuming chase!")


func _find_nearest_player() -> Node2D:
	"""Find the nearest player-controlled SpaceRock."""
	var nearest: Node2D = null
	var nearest_dist: float = INF
	
	var all_rocks = _get_all_space_rocks(get_tree().root)
	
	for candidate in all_rocks:
		if candidate == rock:
			continue
		
		# Skip other AI rocks
		var is_ai = false
		for child in candidate.get_children():
			if child.get_script() == get_script():
				is_ai = true
				break
		
		if is_ai:
			continue
		
		var dist = rock.global_position.distance_to(candidate.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = candidate
	
	return nearest


func _get_all_space_rocks(node: Node) -> Array:
	"""Recursively find all SpaceRock nodes."""
	var result = []
	
	for child in node.get_children():
		if child is SpaceRock:
			result.append(child)
		result.append_array(_get_all_space_rocks(child))
	
	return result
