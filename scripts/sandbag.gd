# sandbag.gd
# A target dummy that spawns floating damage numbers on hit
extends StaticBody2D
class_name Sandbag

# Damage popup scene
const DamagePopupScene = preload("res://scenes/damage_popup.tscn")

# Total damage accumulated
var total_damage: float = 0.0

# Node references
@onready var collision_area: Area2D = $HitArea
@onready var total_label: Label = $TotalLabel


func _ready() -> void:
	_update_total_display()
	
	# Connect to the hit detection area
	if collision_area:
		collision_area.body_entered.connect(_on_body_entered)
	
	print("[Sandbag] Ready - waiting for impacts!")


func _on_body_entered(body: Node2D) -> void:
	"""Handle collision with a SpaceRock."""
	if not body is SpaceRock:
		return
	
	var rock: SpaceRock = body as SpaceRock
	
	# Calculate damage based on rock's momentum (mass × velocity)
	var impact_force: float = rock.mass * rock.linear_velocity.length()
	var damage: float = impact_force * rock.damage_scale
	
	# Only register meaningful hits
	if damage < 1.0:
		return
	
	# Add to total damage
	total_damage += damage
	_update_total_display()
	
	# Spawn floating damage number
	_spawn_damage_popup(damage)
	
	print("[Sandbag] HIT! Damage: ", snapped(damage, 0.1), " | Total: ", snapped(total_damage, 0.1))


func _spawn_damage_popup(damage: float) -> void:
	"""Spawn a floating damage number that fades out."""
	var popup = DamagePopupScene.instantiate()
	
	# Position slightly above the sandbag with random horizontal offset
	popup.position = Vector2(randf_range(-30, 30), -70)
	
	# Add to sandbag so it follows if sandbag ever moves
	add_child(popup)
	
	# Set the damage value
	popup.setup(damage)


func _update_total_display() -> void:
	"""Update the total damage counter."""
	if total_label:
		total_label.text = "Total: " + str(int(total_damage))


func reset_damage() -> void:
	"""Reset the damage counter to zero."""
	total_damage = 0.0
	_update_total_display()

