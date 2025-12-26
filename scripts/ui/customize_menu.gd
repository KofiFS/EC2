# customize_menu.gd
# Customization menu for player appearance
extends Control

signal customization_changed

# Customization options
var selected_particle_effect: int = 0
var selected_death_effect: int = 0
var selected_body_shape: int = 0
var selected_color: Color = Color.WHITE

# Available options
const PARTICLE_EFFECTS = ["Default", "Sparkle", "Flame", "Electric", "Smoke"]
const DEATH_EFFECTS = ["Explosion", "Fade", "Shrink", "Spin Out", "Flash"]
const BODY_SHAPES = ["Circle", "Square", "Triangle", "Hexagon", "Star"]

@onready var particle_option: OptionButton = $Panel/VBoxContainer/ParticleContainer/ParticleOption
@onready var death_option: OptionButton = $Panel/VBoxContainer/DeathContainer/DeathOption
@onready var shape_option: OptionButton = $Panel/VBoxContainer/ShapeContainer/ShapeOption
@onready var color_picker: ColorPickerButton = $Panel/VBoxContainer/ColorContainer/ColorPicker
@onready var preview_panel: Panel = $Panel/VBoxContainer/PreviewContainer/PreviewPanel
@onready var preview_visual: Polygon2D = $Panel/VBoxContainer/PreviewContainer/PreviewPanel/PreviewSprite/PreviewVisual
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton


func _ready() -> void:
	# Populate option buttons
	for effect in PARTICLE_EFFECTS:
		particle_option.add_item(effect)
	
	for effect in DEATH_EFFECTS:
		death_option.add_item(effect)
	
	for shape in BODY_SHAPES:
		shape_option.add_item(shape)
	
	# Set default color
	selected_color = Color.from_hsv(randf(), 0.7, 1.0)
	color_picker.color = selected_color
	
	# Connect signals
	particle_option.item_selected.connect(_on_particle_selected)
	death_option.item_selected.connect(_on_death_selected)
	shape_option.item_selected.connect(_on_shape_selected)
	color_picker.color_changed.connect(_on_color_changed)
	close_button.pressed.connect(_on_close_pressed)
	
	# Load saved preferences
	_load_preferences()
	
	# Update preview
	_update_preview()


func _on_particle_selected(index: int) -> void:
	selected_particle_effect = index
	_save_preferences()
	_update_customization_manager()
	customization_changed.emit()


func _on_death_selected(index: int) -> void:
	selected_death_effect = index
	_save_preferences()
	_update_customization_manager()
	customization_changed.emit()


func _on_shape_selected(index: int) -> void:
	selected_body_shape = index
	_save_preferences()
	_update_preview()
	_update_customization_manager()
	customization_changed.emit()


func _on_color_changed(color: Color) -> void:
	selected_color = color
	_save_preferences()
	_update_preview()
	_update_customization_manager()
	customization_changed.emit()


func _on_close_pressed() -> void:
	visible = false


func _update_preview() -> void:
	# Update preview visual with selected shape and color
	if preview_visual:
		preview_visual.color = selected_color
		# Update shape based on selection
		match selected_body_shape:
			0:  # Circle
				preview_visual.polygon = _create_circle_polygon(30, 20)
			1:  # Square
				preview_visual.polygon = _create_square_polygon(30)
			2:  # Triangle
				preview_visual.polygon = _create_triangle_polygon(30)
			3:  # Hexagon
				preview_visual.polygon = _create_hexagon_polygon(30, 6)
			4:  # Star
				preview_visual.polygon = _create_star_polygon(30, 5)


func _create_circle_polygon(radius: float, points: int) -> PackedVector2Array:
	"""Create a circle polygon."""
	var polygon = PackedVector2Array()
	for i in range(points):
		var angle = (float(i) / points) * TAU
		polygon.append(Vector2(cos(angle), sin(angle)) * radius)
	return polygon


func _create_square_polygon(size: float) -> PackedVector2Array:
	"""Create a square polygon."""
	return PackedVector2Array([
		Vector2(size, size),
		Vector2(-size, size),
		Vector2(-size, -size),
		Vector2(size, -size)
	])


func _create_triangle_polygon(size: float) -> PackedVector2Array:
	"""Create a triangle polygon."""
	return PackedVector2Array([
		Vector2(0, -size),
		Vector2(size * 0.866, size * 0.5),
		Vector2(-size * 0.866, size * 0.5)
	])


func _create_hexagon_polygon(radius: float, sides: int) -> PackedVector2Array:
	"""Create a hexagon polygon."""
	var polygon = PackedVector2Array()
	for i in range(sides):
		var angle = (float(i) / sides) * TAU
		polygon.append(Vector2(cos(angle), sin(angle)) * radius)
	return polygon


func _create_star_polygon(outer_radius: float, points: int) -> PackedVector2Array:
	"""Create a star polygon."""
	var polygon = PackedVector2Array()
	var inner_radius = outer_radius * 0.5
	for i in range(points * 2):
		var angle = (float(i) / (points * 2)) * TAU - PI / 2.0
		var radius = outer_radius if i % 2 == 0 else inner_radius
		polygon.append(Vector2(cos(angle), sin(angle)) * radius)
	return polygon


func _save_preferences() -> void:
	# Save customization preferences to a config file
	var config = ConfigFile.new()
	config.set_value("customization", "particle_effect", selected_particle_effect)
	config.set_value("customization", "death_effect", selected_death_effect)
	config.set_value("customization", "body_shape", selected_body_shape)
	config.set_value("customization", "color_r", selected_color.r)
	config.set_value("customization", "color_g", selected_color.g)
	config.set_value("customization", "color_b", selected_color.b)
	config.set_value("customization", "color_a", selected_color.a)
	config.save("user://customization.cfg")


func _load_preferences() -> void:
	# Load customization preferences from config file
	var config = ConfigFile.new()
	var err = config.load("user://customization.cfg")
	
	if err == OK:
		selected_particle_effect = config.get_value("customization", "particle_effect", 0)
		selected_death_effect = config.get_value("customization", "death_effect", 0)
		selected_body_shape = config.get_value("customization", "body_shape", 0)
		
		var r = config.get_value("customization", "color_r", 1.0)
		var g = config.get_value("customization", "color_g", 1.0)
		var b = config.get_value("customization", "color_b", 1.0)
		var a = config.get_value("customization", "color_a", 1.0)
		selected_color = Color(r, g, b, a)
		
		# Update UI
		particle_option.selected = selected_particle_effect
		death_option.selected = selected_death_effect
		shape_option.selected = selected_body_shape
		color_picker.color = selected_color
	
	_update_customization_manager()


func _update_customization_manager() -> void:
	"""Update the global customization manager with current settings."""
	if has_node("/root/CustomizationManager"):
		var customization_data = get_customization_data()
		get_node("/root/CustomizationManager").set_customization(customization_data)


func get_customization_data() -> Dictionary:
	"""Get current customization settings as a dictionary."""
	return {
		"particle_effect": selected_particle_effect,
		"death_effect": selected_death_effect,
		"body_shape": selected_body_shape,
		"color": selected_color
	}


func show_menu() -> void:
	"""Show the customization menu."""
	visible = true
	_update_preview()  # Refresh preview when menu is shown


