# customization_manager.gd
# Manages player customization preferences
extends Node

var player_customization: Dictionary = {
	"particle_effect": 0,
	"death_effect": 0,
	"body_shape": 0,
	"color": Color.WHITE
}


func set_customization(customization: Dictionary) -> void:
	"""Set the player's customization preferences."""
	player_customization = customization


func get_customization() -> Dictionary:
	"""Get the player's current customization preferences."""
	return player_customization.duplicate()

