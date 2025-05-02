extends Node2D

var card_in_slot: bool = false
var placed_card: Node2D = null

func _ready() -> void:
	print($Area2D.collision_mask)

# Add this function to store a reference to the placed card
func place_card(card: Node2D) -> void:
	card_in_slot = true
	placed_card = card
	# Make sure we don't accidentally free the card
	if card.get_parent():
		card.get_parent().remove_child(card)
	add_child(card)
	card.position = Vector2.ZERO
	card.z_index = 10  # Ensure card is above the slot
