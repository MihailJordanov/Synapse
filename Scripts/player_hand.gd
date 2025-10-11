class_name PlayerHand 
extends Node2D

const HAND_COUNT = 2
const CARD_SCENE_PATH = "res://Scenes/card.tscn"
const CARD_WIDTH = 200
const HAND_Y_POSITION = 890

var player_hand : Array = []
var center_screen_x

func _ready() -> void:
	center_screen_x = get_viewport_rect().size.x / 2
	
	var card_scene = preload(CARD_SCENE_PATH)
	for i in range(HAND_COUNT):
		var new_card = card_scene.instantiate()
		$"../CardManager".add_child(new_card)
		new_card.name = "Card"
		add_card_to_hand(new_card)
		
func add_card_to_hand(card) -> void:
	player_hand.insert(0, card)
	update_hand_position()
	
	
func update_hand_position() -> void:
	for i in range(player_hand.size()):
		var new_position = Vector2(calculate_card_position(i), HAND_Y_POSITION)
		var card = player_hand[i]
		anime_card_to_position(card, new_position)
 
func calculate_card_position(index):
	var total_widht = (player_hand.size() - 1) * CARD_WIDTH
	var x_offset = center_screen_x + index * CARD_WIDTH - total_widht / 2
	return x_offset
	
	
func anime_card_to_position(card, new_position):
	var tween = get_tree().create_tween()
	tween.tween_property(card, "position", new_position, 0.1)
	
	
	
	
	
	
	
	
	
	
	
