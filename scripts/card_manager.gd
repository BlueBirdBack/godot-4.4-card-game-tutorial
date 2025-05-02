extends Node2D

# This mask is used for detecting card collisions
const CARD_COLLISION_MASK = 1

# --- VARIABLES ---
# Card currently being dragged by the player
var active_card: Node2D = null
# Where the card was before we started dragging it
var card_start_position: Vector2 = Vector2.ZERO
# How far the mouse is from the card's center (keeps card from jumping to cursor)
var mouse_to_card_offset: Vector2 = Vector2.ZERO
# Size of the game window
var viewport_dimensions: Vector2 = Vector2.ZERO
# Used to track which card should appear on top of others
var highest_z_index: int = 0

# Called when the scene starts
func _ready() -> void:
	# Get the current window size
	viewport_dimensions = get_viewport_rect().size
	# Listen for window resize events
	get_tree().root.size_changed.connect(_on_viewport_resized)
	# Make sure all cards have proper layering
	initialize_card_z_indices()

# Called when the window is resized
func _on_viewport_resized() -> void:
	# Update our stored window size
	viewport_dimensions = get_viewport_rect().size

# Called every frame
func _process(_delta: float) -> void:
	# Only do something if we're dragging a card
	if active_card:
		# Calculate where the card should be based on mouse position
		var target_position = get_global_mouse_position() + mouse_to_card_offset
		
		# Figure out the card's size
		var card_dimensions = calculate_card_dimensions(active_card)
		var half_width = card_dimensions.x / 2
		var half_height = card_dimensions.y / 2
		
		# Keep the card inside the screen boundaries
		target_position.x = clamp(target_position.x, half_width, viewport_dimensions.x - half_width)
		target_position.y = clamp(target_position.y, half_height, viewport_dimensions.y - half_height)
		
		# Move the card to its new position
		active_card.position = target_position

# Handle player input
func _input(event: InputEvent) -> void:
	# We only care about left mouse button clicks
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Mouse button pressed down - try to pick up a card
			begin_card_drag()
		else:
			# Mouse button released - drop the card
			end_card_drag()

# Start dragging a card
func begin_card_drag() -> void:
	# Check if there's a card under the mouse cursor
	var card = find_card_under_cursor()
	if card:
		# Remember which card we're dragging
		active_card = card
		# Remember where the card started (not used currently)
		card_start_position = card.position
		# Calculate offset so card doesn't jump to cursor
		mouse_to_card_offset = card.position - get_global_mouse_position()
		
		# Make this card appear on top of other cards
		highest_z_index += 1
		card.z_index = highest_z_index

# Stop dragging the current card
func end_card_drag() -> void:
	# Clear the active card reference
	active_card = null

# Find which card (if any) is under the mouse cursor
func find_card_under_cursor() -> Node2D:
	# Use Godot's physics system to detect cards
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = CARD_COLLISION_MASK
	
	# Check if we hit anything
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		# Return the card (parent of the Area2D we hit)
		return result[0].collider.get_parent()
	return null

# Get the width and height of a card
func calculate_card_dimensions(card: Node2D) -> Vector2:
	# Try to get the size from the card's collision shape
	if card.has_node("Area2D/CollisionShape2D"):
		var shape = card.get_node("Area2D/CollisionShape2D").shape
		if shape is RectangleShape2D:
			return shape.size
	# If we can't find the shape, use default values
	return Vector2(164.5, 257)

# Set up the initial layering of cards
func initialize_card_z_indices() -> void:
	# Loop through all child nodes
	for i in range(get_child_count()):
		var child = get_child(i)
		# Check if this child is a card
		if child is Node2D and child.has_node("Area2D"):
			# Set its layer based on its position in the list
			child.z_index = i
			# Keep track of the highest z-index
			highest_z_index = max(highest_z_index, i)


