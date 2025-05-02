extends Node2D

signal card_mouse_entered(card)
signal card_mouse_exited(card)

# Track the original collision shape size
var original_collision_size: Vector2

func _ready():
	# Store the original collision shape size
	if has_node("Area2D/CollisionShape2D"):
		original_collision_size = $Area2D/CollisionShape2D.shape.size
	
	# Connect to parent card manager if it has the required method
	var parent = get_parent()
	if parent and parent.has_method("connect_card_signals"):
		parent.connect_card_signals(self)
	
	# Connect Area2D signals
	$Area2D.mouse_entered.connect(_on_mouse_entered)
	$Area2D.mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	# Just emit the signal - let the manager handle the visual effects
	card_mouse_entered.emit(self)

func _on_mouse_exited():
	# Just emit the signal - let the manager handle the visual effects
	card_mouse_exited.emit(self)
