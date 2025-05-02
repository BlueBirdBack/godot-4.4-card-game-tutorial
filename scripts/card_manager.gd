extends Node2D

# This mask is used for detecting card collisions
const CARD_COLLISION_MASK = 1

const CARD_SLOT_COLLISION_MASK = 2

# --- PERFORMANCE NOTES ---
# For better performance with many cards, consider adjusting these project settings:
# - Project > Project Settings > Physics > Common > Physics Ticks per Second: Lower to 30-45 for card games
# - Project > Project Settings > Physics > Common > Max Physics Steps per Frame: Increase to 8-10
# This will help prevent the "physics spiral of death" mentioned in Godot documentation

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
# Whether the mouse is currently hovering on a card
var is_hovering_on_card: bool = false
# Base z-index for cards
var base_z_index: int = 0
# Z-index for hovered cards
var hover_z_index: int = 100
# Z-index for dragged cards
var drag_z_index: int = 200
var default_card_dimensions: Vector2

# Called when the scene starts
func _ready() -> void:
	# Get the current window size
	viewport_dimensions = get_viewport_rect().size
	# Listen for window resize events
	get_tree().root.size_changed.connect(_on_viewport_resized)
	# Load default card dimensions from the card scene
	load_default_card_dimensions()
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
		# Remember where the card started
		card_start_position = card.position
		# Calculate offset so card doesn't jump to cursor
		mouse_to_card_offset = card.position - get_global_mouse_position()
		
		# Make this card appear on top of other cards using the drag z-index
		card.z_index = drag_z_index

# Stop dragging the current card
func end_card_drag() -> void:
	if active_card == null:
		return
		
	var card_slot = find_card_slot_under_cursor()
	if card_slot and card_slot.card_in_slot == false:
		print("Placing card in slot")
		
		# Instead of just changing position, use the new place_card function
		# This will reparent the card to the slot
		card_slot.place_card(active_card)
		active_card.get_node("Area2D/CollisionShape2D").disabled = true
		
		print("Card placed in slot, new parent: ", active_card.get_parent().name)
	else:
		active_card.position = card_start_position
		active_card.z_index = base_z_index + active_card.get_index()

	active_card = null

# Find which card (if any) is under the mouse cursor
func find_card_under_cursor() -> Node2D:
	# Use Godot's physics system to detect cards, but with optimizations
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = CARD_COLLISION_MASK
	# Note: max_results is not available in PhysicsPointQueryParameters2D
	
	# Check if we hit anything
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		# Find the card with the highest z_index among all cards under cursor
		var highest_card = result[0].collider.get_parent()
		var highest_z = highest_card.z_index
		
		for i in range(1, result.size()):
			var card = result[i].collider.get_parent()
			if card.z_index > highest_z:
				highest_card = card
				highest_z = card.z_index
				
		return highest_card
	return null

# Find which card slot (if any) is under the mouse cursor
func find_card_slot_under_cursor() -> Node2D:
	# Use Godot's physics system to detect cards, but with optimizations
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = CARD_SLOT_COLLISION_MASK
	# Note: max_results is not available in PhysicsPointQueryParameters2D
	
	# Check if we hit anything
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		return result[0].collider.get_parent()
		# # Find the card with the highest z_index among all cards under cursor
		# var highest_card = result[0].collider.get_parent()
		# var highest_z = highest_card.z_index
		
		# for i in range(1, result.size()):
		# 	var card = result[i].collider.get_parent()
		# 	if card.z_index > highest_z:
		# 		highest_card = card
		# 		highest_z = card.z_index
				
		# return highest_card
	return null

# Get the width and height of a card
func calculate_card_dimensions(card: Node2D) -> Vector2:
	# First try to get the size from the card's collision shape
	if card.has_node("Area2D/CollisionShape2D"):
		var collision_shape = card.get_node("Area2D/CollisionShape2D")
		var shape = collision_shape.shape
		if shape is RectangleShape2D:
			return shape.size
	
	# If we can't find the shape, use the dimensions loaded from the scene
	return default_card_dimensions

# Set up the initial layering of cards
func initialize_card_z_indices() -> void:
	# Reset the highest z-index tracker
	highest_z_index = base_z_index
	
	# Loop through all child nodes
	for i in range(get_child_count()):
		var child = get_child(i)
		# Check if this child is a card
		if child is Node2D and child.has_node("Area2D"):
			# Set its layer based on its position in the list
			child.z_index = base_z_index + i
			# Keep track of the highest z-index
			highest_z_index = max(highest_z_index, base_z_index + i)

# Connect to all card signals
func connect_card_signals(card: Node2D) -> void:
	if !is_instance_valid(card):
		push_warning("Attempted to connect signals to invalid card instance")
		return
		
	if card.has_signal("card_mouse_entered"):
		if !card.card_mouse_entered.is_connected(_on_card_mouse_entered):
			card.card_mouse_entered.connect(_on_card_mouse_entered)
	else:
		push_warning("Card missing card_mouse_entered signal")
		
	if card.has_signal("card_mouse_exited"):
		if !card.card_mouse_exited.is_connected(_on_card_mouse_exited):
			card.card_mouse_exited.connect(_on_card_mouse_exited)
	else:
		push_warning("Card missing card_mouse_exited signal")

# Handle mouse entering card
func _on_card_mouse_entered(card: Node2D) -> void:
	# Apply hover effects using the highlight function
	if !is_hovering_on_card:
		is_hovering_on_card = true
		highlight_card(card, true)

# Handle mouse exiting card
func _on_card_mouse_exited(card: Node2D) -> void:
	# Reset hover effects using the highlight function
	highlight_card(card, false)

	var new_card_under_cursor = find_card_under_cursor()
	if new_card_under_cursor:
		highlight_card(new_card_under_cursor, true)
	else:
		is_hovering_on_card = false

# Highlight or unhighlight a card
func highlight_card(card: Node2D, hovered: bool) -> void:
	if !is_instance_valid(card):
		push_warning("Attempted to highlight invalid card instance")
		return
		
	# Set scale based on hover state
	card.scale = Vector2(1.05, 1.05) if hovered else Vector2(1.0, 1.0)
	
	# Manage z-index with defined ranges
	if hovered:
		card.z_index = hover_z_index
	else:
		# When no longer hovering, restore to base z-index range
		# Find the card's position among siblings to maintain relative ordering
		var card_index = card.get_index()
		card.z_index = base_z_index + card_index
	
	# Instead of modifying collision shape size directly, adjust the Area2D's scale
	if card.has_node("Area2D"):
		var area = card.get_node("Area2D")
		# Keep the collision shape's scale at 1.0 regardless of parent scale
		area.scale = Vector2(1.0, 1.0) / card.scale
	else:
		push_warning("Card missing Area2D node, cannot adjust collision scale")

# Add this function to reorganize z-indices when cards are added or removed
func reorganize_z_indices() -> void:
	initialize_card_z_indices()

# Add this new function to load dimensions from the card scene
func load_default_card_dimensions() -> void:
	var card_scene_path = "res://scenes/card.tscn"
	if ResourceLoader.exists(card_scene_path):
		var card_scene = load(card_scene_path)
		if card_scene:
			# Create a temporary instance to read its properties
			var temp_card = card_scene.instantiate()
			if temp_card.has_node("Area2D/CollisionShape2D"):
				var collision = temp_card.get_node("Area2D/CollisionShape2D")
				if collision.shape is RectangleShape2D:
					default_card_dimensions = collision.shape.size
				else:
					push_warning("Card collision shape is not a RectangleShape2D. Using default dimensions.")
			else:
				push_warning("Card scene missing Area2D/CollisionShape2D. Using default dimensions.")
			# Clean up the temporary instance
			temp_card.queue_free()
		else:
			push_error("Failed to load card scene from path: " + card_scene_path)
	else:
		push_error("Card scene not found at path: " + card_scene_path)
