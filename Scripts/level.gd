class_name Level
extends Node2D

const MAX_HAND := 4
const CARD_SCENE := preload("res://Scenes/Card.tscn") # смени с твоя път

@onready var card_manager: CardManager = $CardManager

# Points (ползваме ти 7те, но ще пълним до MAX_HAND)
@onready var point_1: Node2D = $PlayerHand/Points/Point1
@onready var point_2: Node2D = $PlayerHand/Points/Point2
@onready var point_3: Node2D = $PlayerHand/Points/Point3
@onready var point_4: Node2D = $PlayerHand/Points/Point4
@onready var point_5: Node2D = $PlayerHand/Points/Point5
@onready var point_6: Node2D = $PlayerHand/Points/Point6
@onready var point_7: Node2D = $PlayerHand/Points/Point7

# Слотовете (не са нужни за логиката тук, но ги оставям за удобство)
@onready var player_card_slot_1: CardSlot = $Slots/PlayerSlots/CardSlot
@onready var player_card_slot_2: CardSlot = $Slots/PlayerSlots/CardSlot2
@onready var player_card_slot_3: CardSlot = $Slots/PlayerSlots/CardSlot3
@onready var player_card_slot_4: CardSlot = $Slots/PlayerSlots/CardSlot4
@onready var player_card_slot_5: CardSlot = $Slots/PlayerSlots/CardSlot5
@onready var enemy_card_slot_6: CardSlot  = $Slots/EnemySlots/CardSlot6
@onready var enemy_card_slot_7: CardSlot  = $Slots/EnemySlots/CardSlot7
@onready var enemy_card_slot_8: CardSlot  = $Slots/EnemySlots/CardSlot8
@onready var enemy_card_slot_9: CardSlot  = $Slots/EnemySlots/CardSlot9
@onready var enemy_card_slot_10: CardSlot = $Slots/EnemySlots/CardSlot10

var points: Array[Node2D]
var hand_cards: Array[Node2D] = []        # текущи карти в ръката
var home_of_card := {}                    # card(Node2D) -> point(Node2D)
var deck_index := 0                       # позиция в CollectionManager.deck

# --- граф / поставени карти ---
var placed_cards: Array[Card] = []        # реалните нодове на дъската
var graph: Dictionary = {}                # instance_id(int) -> Array[int]

func _ready() -> void:
	points = [point_1, point_2, point_3, point_4, point_5, point_6, point_7]

	# Слушаме резултат от drag/drop
	card_manager.card_dropped_on_slot.connect(_on_card_dropped_on_slot)
	card_manager.card_dropped_back.connect(_on_card_dropped_back)

	# Първоначално напълни ръката до MAX_HAND
	_draw_to_full_hand()

# ---------------------- РЪКА / ТЕГЛЕНЕ ----------------------

func _draw_to_full_hand() -> void:
	while hand_cards.size() < MAX_HAND:
		var p := _first_free_point()
		if p == null:
			break
		var card := _draw_next_card_instance()
		if card == null:
			break
		_place_card_at_point(card, p)

func _first_free_point() -> Node2D:
	for p in points:
		var taken := false
		for c in hand_cards:
			if home_of_card.get(c) == p:
				taken = true
				break
		if not taken:
			return p
	return null

func _draw_next_card_instance() -> Node2D:
	var deck := CollectionManager.deck
	if deck_index >= deck.size():
		return null
	var id = deck[deck_index]
	deck_index += 1

	var data := CollectionManager.get_card(id)
	if data.is_empty():
		return null

	var card: Node2D = CARD_SCENE.instantiate()
	add_child(card)

	# присвои id към Card (ако има поле id)
	var as_card := card as Card
	if as_card:
		as_card.id = int(id)

	# основни свойства (String -> enum int)
	if card.has_method("set_element"):
		card.set_element(_to_element(data.get("self_element")))
	if card.has_method("set_kind"):
		card.set_kind(_to_kind(data.get("self_kind")))
	if card.has_method("set_attack_style"):
		card.set_attack_style(_to_style(data.get("self_attack_style")))

	# текстура
	if card.has_method("set_card_texture"):
		var path := str(data.get("card_texture", ""))
		if path != "":
			card.set_card_texture(load(path))

	# targets
	var ce = data.get("connect_element")
	if card.has_method("set_use_element_target") and card.has_method("set_target_element"):
		card.set_use_element_target(ce != null)
		if ce != null:
			card.set_target_element(_to_element(ce))

	var ck = data.get("connect_kind")
	if card.has_method("set_use_kind_target") and card.has_method("set_target_kind"):
		card.set_use_kind_target(ck != null)
		if ck != null:
			card.set_target_kind(_to_kind(ck))

	var cs = data.get("connect_attack_style")
	if card.has_method("set_use_attack_style_target") and card.has_method("set_target_attack_style"):
		card.set_use_attack_style_target(cs != null)
		if cs != null:
			card.set_target_attack_style(_to_style(cs))

	# hover-ефекти през CardManager
	if card_manager and card_manager.has_method("connect_card_signals"):
		card_manager.connect_card_signals(card)

	return card

func _place_card_at_point(card: Node2D, point: Node2D) -> void:
	card.global_position = point.global_position
	home_of_card[card] = point
	hand_cards.append(card)
	card.set_meta("home_pos", point.global_position)

# ---------------------- DRAG/DROP CALLBACKS ----------------------

func _on_card_dropped_back(card: Node2D) -> void:
	var home: Vector2 = card.get_meta("home_pos")
	if typeof(home) == TYPE_VECTOR2:
		var tw := create_tween()
		tw.tween_property(card, "global_position", home, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_card_dropped_on_slot(card: Node2D, slot: Node2D) -> void:
	# махни от ръката
	if hand_cards.has(card):
		hand_cards.erase(card)
		home_of_card.erase(card)

	# регистрирай на дъската и провери за връзки
	var c := card as Card
	if c:
		_add_to_board(c)
		_check_new_edges(c)

	# попълни ръката отново
	_draw_to_full_hand()

# ---------------------- ГРАФ / ВРЪЗКИ ----------------------

func _add_to_board(c: Card) -> void:
	if not placed_cards.has(c):
		placed_cards.append(c)
	var uid := c.get_instance_id()
	if not graph.has(uid):
		graph[uid] = []

func _check_new_edges(c: Card) -> void:
	for other in placed_cards:
		if other == c:
			continue

		var m1 := _matches(c, other)
		if m1.size() > 0:
			_add_edge(c, other, m1)

		var m2 := _matches(other, c)
		if m2.size() > 0:
			_add_edge(other, c, m2)

func _matches(from: Card, to: Card) -> Array[String]:
	var res: Array[String] = []

	if from.use_element_target and from.target_element == to.element:
		res.append("Element")

	if from.use_kind_target and from.target_kind == to.kind:
		res.append("Kind")

	if from.use_attack_style_target and from.target_attack_style == to.attack_style:
		res.append("AttackStyle")

	return res

func _add_edge(a: Card, b: Card, labels: Array[String]) -> void:
	var a_uid := a.get_instance_id()
	var b_uid := b.get_instance_id()

	if not graph.has(a_uid):
		graph[a_uid] = []
	var neigh: Array = graph[a_uid]
	if not neigh.has(b_uid):
		neigh.append(b_uid)
		graph[a_uid] = neigh
		# Принтни и шаблонните ID-та за яснота
		var a_tpl := "?" if not ("id" in a) else str(a.id)
		var b_tpl := "?" if not ("id" in b) else str(b.id)
		print("LINK: %s(#%d) -> %s(#%d) via %s" % [a_tpl, a_uid, b_tpl, b_uid, ", ".join(labels)])

# ---------------------- Помощни конвертори ----------------------

func _to_element(v) -> int:
	if v is int: return v
	if v is float: return int(v)
	if v is String and Card.Element.has(v): return Card.Element[v]
	return Card.Element.AIR

func _to_kind(v) -> int:
	if v is int: return v
	if v is float: return int(v)
	if v is String:
		if v == "ORC": v = "ORG" # alias, ако в JSON има ORC
		if Card.CardKind.has(v): return Card.CardKind[v]
	return Card.CardKind.HERO

func _to_style(v) -> int:
	if v is int: return v
	if v is float: return int(v)
	if v is String and Card.AttackStyle.has(v): return Card.AttackStyle[v]
	return Card.AttackStyle.MELEE
