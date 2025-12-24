# health_bar.gd
# A health bar that follows a SpaceRock and displays its health
extends Node2D

@onready var background: ColorRect = $Background
@onready var fill: ColorRect = $Fill
@onready var label: Label = $Label

var rock: SpaceRock = null
var bar_width: float = 80.0


func _ready() -> void:
	# Get the SpaceRock parent
	rock = get_parent() as SpaceRock
	if rock:
		rock.damage_changed.connect(_on_damage_changed)
		_update_bar()


func _process(_delta: float) -> void:
	# Counter-rotate to stay upright (don't rotate with parent)
	# Use global_rotation to handle all parent rotations
	global_rotation = 0


func _on_damage_changed(_current: float, _maximum: float) -> void:
	_update_bar()


func _update_bar() -> void:
	if not rock:
		return
	
	var health_percent = 1.0 - rock.get_damage_percent()
	
	# Update fill width
	if fill:
		fill.size.x = bar_width * health_percent
	
	# Update color based on health
	if fill:
		if health_percent > 0.6:
			fill.color = Color(0.2, 0.9, 0.2)  # Green
		elif health_percent > 0.3:
			fill.color = Color(0.9, 0.7, 0.1)  # Yellow
		else:
			fill.color = Color(0.9, 0.2, 0.2)  # Red
	
	# Update label
	if label:
		var current_health = rock.max_health - rock.current_damage
		label.text = str(int(max(0, current_health)))

