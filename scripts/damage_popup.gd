# damage_popup.gd
# Floating damage number that fades in, floats up, fades out, then deletes itself
extends Node2D
class_name DamagePopup

@export var float_speed: float = 50.0  # How fast it floats upward
@export var fade_in_time: float = 0.15  # Time to fade in
@export var display_time: float = 0.8  # Time to stay visible
@export var fade_out_time: float = 0.5  # Time to fade out

@onready var label: Label = $Label

var elapsed_time: float = 0.0
var total_duration: float


func _ready() -> void:
	total_duration = fade_in_time + display_time + fade_out_time
	# Start invisible
	modulate.a = 0.0


func setup(damage_amount: float) -> void:
	"""Set the damage number to display."""
	if label:
		label.text = str(int(damage_amount))
		
		# Color based on damage amount
		if damage_amount >= 500:
			label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))  # Red for big hits
		elif damage_amount >= 100:
			label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))  # Orange for medium
		else:
			label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))  # Yellow for small


func _process(delta: float) -> void:
	elapsed_time += delta
	
	# Float upward
	position.y -= float_speed * delta
	
	# Handle fade phases
	if elapsed_time < fade_in_time:
		# Fade in
		modulate.a = elapsed_time / fade_in_time
	elif elapsed_time < fade_in_time + display_time:
		# Fully visible
		modulate.a = 1.0
	elif elapsed_time < total_duration:
		# Fade out
		var fade_progress = (elapsed_time - fade_in_time - display_time) / fade_out_time
		modulate.a = 1.0 - fade_progress
	else:
		# Done - delete self
		queue_free()

