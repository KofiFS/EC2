# breakable_block.gd
# A block that breaks when hit with enough force
extends StaticBody2D
class_name BreakableBlock

# How much total damage needed to break this block
@export var break_threshold: float = 60.0
# Whether to show damage numbers
@export var show_damage: bool = true

# Damage popup scene
const DamagePopupScene = preload("res://scenes/damage_popup.tscn")

# Node references
@onready var collision_area: Area2D = $HitArea
@onready var visual: Polygon2D = $Visual
@onready var cracks: Polygon2D = $Cracks

# Accumulated damage
var total_damage: float = 0.0
var is_broken: bool = false
var original_color: Color


func _ready() -> void:
	if collision_area:
		collision_area.body_entered.connect(_on_body_entered)
	
	if visual:
		original_color = visual.color
	
	print("[BreakableBlock] Ready - Break threshold: ", break_threshold)


func _on_body_entered(body: Node2D) -> void:
	"""Handle collision with a SpaceRock."""
	if is_broken:
		return
		
	if not body is SpaceRock:
		return
	
	var rock: SpaceRock = body as SpaceRock
	
	# Calculate impact force (mass × velocity)
	var impact_force: float = rock.mass * rock.linear_velocity.length()
	var damage: float = impact_force * rock.damage_scale
	
	# Only register meaningful hits
	if damage < 1.0:
		return
	
	# Accumulate damage
	total_damage += damage
	
	print("[BreakableBlock] HIT! Damage: ", snapped(damage, 1), " | Total: ", snapped(total_damage, 1), "/", break_threshold)
	
	# Show damage popup
	if show_damage:
		_spawn_damage_popup(damage)
	
	# Update visual to show damage
	_update_damage_visual()
	
	# Check if total damage exceeds break threshold
	if total_damage >= break_threshold:
		_break()


func _update_damage_visual() -> void:
	"""Update the block's appearance based on damage taken."""
	var damage_percent = clamp(total_damage / break_threshold, 0.0, 1.0)
	
	# Darken the block as it takes damage
	if visual:
		visual.color = original_color.darkened(damage_percent * 0.4)
	
	# Make cracks more visible
	if cracks:
		cracks.modulate.a = 0.5 + (damage_percent * 0.5)


func _spawn_damage_popup(damage: float) -> void:
	"""Spawn a floating damage number."""
	var popup = DamagePopupScene.instantiate()
	popup.position = Vector2(randf_range(-20, 20), -50)
	add_child(popup)
	popup.setup(damage)


func _break() -> void:
	"""Break the block!"""
	is_broken = true
	
	print("[BreakableBlock] DESTROYED!")
	
	# Spawn break particles/fragments
	_spawn_fragments()
	
	# Remove the block
	queue_free()


func _spawn_fragments() -> void:
	"""Spawn visual fragments when breaking."""
	# Get our global position before we're freed
	var spawn_pos = global_position
	var parent = get_parent()
	
	# Create several small fragment pieces
	for i in range(6):
		var fragment = Polygon2D.new()
		fragment.polygon = PackedVector2Array([
			Vector2(-15, -15),
			Vector2(15, -10),
			Vector2(10, 15),
			Vector2(-10, 12)
		])
		fragment.color = visual.color if visual else Color(0.5, 0.5, 0.6)
		fragment.position = spawn_pos
		fragment.rotation = randf() * TAU
		
		# Add to parent so it persists after we're freed
		parent.add_child(fragment)
		
		# Animate the fragment flying outward and fading
		var tween = fragment.create_tween()
		var direction = Vector2.from_angle(randf() * TAU)
		var end_pos = spawn_pos + direction * randf_range(80, 150)
		
		tween.set_parallel(true)
		tween.tween_property(fragment, "position", end_pos, 0.5).set_ease(Tween.EASE_OUT)
		tween.tween_property(fragment, "rotation", fragment.rotation + randf_range(-3, 3), 0.5)
		tween.tween_property(fragment, "modulate:a", 0.0, 0.5).set_delay(0.2)
		tween.set_parallel(false)
		tween.tween_callback(fragment.queue_free)

