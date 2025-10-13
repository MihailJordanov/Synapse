class_name CardManager
extends Node2D

const COLLISION_MASK_CARD = 1
const COLLISION_MASK_CARD_SLOT = 2

signal card_dropped_on_slot(card: Node2D, slot: Node2D)
signal card_dropped_back(card: Node2D)

@export var picked_card_show_path: NodePath
var picked_card_show: PickedCardShow


var screen_size: Vector2
var card_being_dragged: Node2D
var is_hovering_on_card := false
var pointer_pos: Vector2
var active_touch_id: int = -1



func _ready() -> void:
	screen_size = get_viewport_rect().size
	pointer_pos = get_global_mouse_position()
	if picked_card_show_path != NodePath():
		picked_card_show = get_node(picked_card_show_path)

func _process(_delta: float) -> void:
	if card_being_dragged:
		card_being_dragged.global_position = Vector2(
			clamp(pointer_pos.x, 0, screen_size.x),
			clamp(pointer_pos.y, 0, screen_size.y)
		)

func _input(event) -> void:
	# --- обновяване на универсалната позиция ---
	if event is InputEventMouseMotion:
		pointer_pos = event.position
	elif event is InputEventScreenDrag:
		pointer_pos = event.position

	# --- старт на drag (мишка) ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer_pos = event.position
		if event.pressed:
			var card: Node2D = raycast_check_for_card(pointer_pos)
			if card:
				if card is Card and card.is_locked:
					return
				start_drag(card)
		else:
			if card_being_dragged:
				finish_drag()
		return

	# --- старт/край на drag (touch) ---
	if event is InputEventScreenTouch:
		# ако вече влачим с друг пръст, игнорирай останалите
		if active_touch_id != -1 and event.index != active_touch_id:
			return

		pointer_pos = event.position
		if event.pressed:
			# маркирай кой пръст влачи
			active_touch_id = event.index
			var card_t: Node2D = raycast_check_for_card(pointer_pos)
			if card_t:
				if card_t is Card and card_t.is_locked:
					return
				start_drag(card_t)
		else:
			# отлепяне на същия пръст -> край
			if card_being_dragged:
				finish_drag()
			if event.index == active_touch_id:
				active_touch_id = -1
		return

	elif event is InputEventScreenDrag:
		# ъпдейтвай само от активния пръст
		if active_touch_id == -1 or event.index != active_touch_id:
			return
		pointer_pos = event.position
		return



func start_drag(card: Node2D) -> void:
	card_being_dragged = card
	is_hovering_on_card = true
	hightlight_card(card, true)
	card.scale = Vector2(1, 1)
	if picked_card_show:
		picked_card_show.show_card(card)

func finish_drag() -> void:
	card_being_dragged.scale = Vector2(1.05, 1.05)

	var card_slot_found: Node2D = raycast_check_for_card_slot(pointer_pos)


	var level := $".."  # качваме се към родителя (Level)
	if level and level.has_method("can_player_drop_on_slot"):
		if not level.can_player_drop_on_slot(card_being_dragged, card_slot_found):
			emit_signal("card_dropped_back", card_being_dragged)
			card_being_dragged = null
			return


	if card_slot_found and not card_slot_found.card_in_slot:
		card_being_dragged.global_position = card_slot_found.global_position
		card_being_dragged.is_locked = true
		card_slot_found.card_in_slot = true
		emit_signal("card_dropped_on_slot", card_being_dragged, card_slot_found)
	else:
		emit_signal("card_dropped_back", card_being_dragged)


	# след пускане – ако не сме върху друга карта, скрий
	var still_hovered: Node2D = raycast_check_for_card(pointer_pos)
	if picked_card_show:
		if still_hovered:
			picked_card_show.show_card(still_hovered)
		else:
			picked_card_show.clear()

	card_being_dragged = null


func raycast_check_for_card(pos: Vector2 = pointer_pos):
	var space_state = get_world_2d().direct_space_state
	var p := PhysicsPointQueryParameters2D.new()
	p.position = pos
	p.collide_with_areas = true
	p.collision_mask = COLLISION_MASK_CARD
	var result = space_state.intersect_point(p)
	if result.size() > 0:
		return get_card_with_highest_z_index(result)
	return null

func raycast_check_for_card_slot(pos: Vector2 = pointer_pos):
	var space_state = get_world_2d().direct_space_state
	var p := PhysicsPointQueryParameters2D.new()
	p.position = pos
	p.collide_with_areas = true
	p.collision_mask = COLLISION_MASK_CARD_SLOT
	var result = space_state.intersect_point(p)
	if result.size() > 0:
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
	card.connect("hovered", Callable(self, "on_hovered_over_card"))
	card.connect("hovered_off", Callable(self, "on_hovered_off_card"))

func on_hovered_over_card(card) -> void:
	if !is_hovering_on_card:
		is_hovering_on_card = true
		hightlight_card(card, true)
	if picked_card_show:
		picked_card_show.show_card(card)

func on_hovered_off_card(card) -> void:
	if !card_being_dragged:
		hightlight_card(card, false)
		var new_card_hover = raycast_check_for_card(pointer_pos)
		if new_card_hover:
			hightlight_card(new_card_hover, true)
			if picked_card_show:
				picked_card_show.show_card(new_card_hover)
		else:
			is_hovering_on_card = false
			if picked_card_show:
				picked_card_show.clear()

func hightlight_card(card, hovered) -> void:
	if hovered:
		card.scale = Vector2(1.05, 1.05)
		card.z_index = 2
	else:
		card.scale = Vector2(1, 1)
		card.z_index = 1
