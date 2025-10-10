class_name CardManager
extends Node2D

const COLLISION_MASK_CARD = 1
const COLLISION_MASK_CARD_SLOT = 2

var screen_size
var card_being_dragged
var is_hovering_on_card

func _ready() -> void:
	screen_size = get_viewport_rect().size


func _process(delta : float) -> void:
	if card_being_dragged:
		var mouse_pos = get_global_mouse_position()
		card_being_dragged.position = Vector2(clamp(mouse_pos.x, 0, screen_size.x),
			clamp(mouse_pos.y, 0, screen_size.y))

func _input(event) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var card = raycast_check_for_card()
			if card:
				start_drag(card)
		else:
			if card_being_dragged:
				finish_drag()


func start_drag(card):
	card_being_dragged = card
	card.scale = Vector2(0.1, 0.1)
	
func finish_drag():
	card_being_dragged.scale = Vector2(0.105, 0.105)
	var card_slot_found = raycast_check_for_card_slot()
	if card_slot_found and not card_slot_found.card_in_slot:
		card_being_dragged.global_position = card_slot_found.global_position
		card_being_dragged.get_node("Area2D/CollisionShape2D").disabled = true
		card_slot_found.card_in_slot = true
	card_being_dragged = null



func raycast_check_for_card():
	var space_state = get_world_2d().direct_space_state
	var parametars = PhysicsPointQueryParameters2D.new()
	parametars.position = get_global_mouse_position()
	parametars.collide_with_areas = true
	parametars.collision_mask = COLLISION_MASK_CARD
	var result = space_state.intersect_point(parametars)
	if result.size() > 0:
		#return result[0].collider.get_parent()
		return get_card_with_highest_z_index(result)
	return null
	
func raycast_check_for_card_slot():
	var space_state = get_world_2d().direct_space_state
	var parametars = PhysicsPointQueryParameters2D.new()
	parametars.position = get_global_mouse_position()
	parametars.collide_with_areas = true
	parametars.collision_mask = COLLISION_MASK_CARD_SLOT
	var result = space_state.intersect_point(parametars)
	if result.size() > 0:
		#return result[0].collider.get_parent()
		return result[0].collider.get_parent()
	return null
	
	
func get_card_with_highest_z_index(cards):
	var highest_z_card = cards[0].collider.get_parent()
	var highest_z_index = highest_z_card.z_index
	
	for i in range(1, cards.size()):
		var current_card = cards[i].collider.get_parent()
		if current_card.z_index > highest_z_index:
			highest_z_card = current_card
			highest_z_index = current_card.z_index
	return highest_z_card
	
	
func connect_card_signals(card) -> void:
	card.connect("hovered", on_hovered_over_card)
	card.connect("hovered_off", on_hovered_off_card)


func on_hovered_over_card(card) -> void:
	if !is_hovering_on_card:
		is_hovering_on_card = true
		hightlight_card(card, true)

func on_hovered_off_card(card) -> void:
	if !card_being_dragged:
		hightlight_card(card, false)
		
		var new_card_hover = raycast_check_for_card()
		if new_card_hover:
			hightlight_card(new_card_hover, true)
		else:
			is_hovering_on_card = false
	
	
func hightlight_card(card, hovered) -> void:
	if hovered:
		card.scale = Vector2(0.105, 0.105)
		card.z_index = 2
	else:
		card.scale = Vector2(0.1, 0.1)
		card.z_index = 1
