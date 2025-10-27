class_name Level
extends Node2D

const MIN_CYCLE_LEN := 3  # игнорирай 2-цикъл (1 ↔ 2)
const CARD_SCENE := preload("res://Scenes/card.tscn")
const EDGE_SCENE := preload("res://Scenes/edge.tscn")

const INFO_COLOR_NORMAL := Color(0.7, 1.0, 0.7)      # зеленикав — стандартни инструкции
const INFO_COLOR_WARNING := Color(1.0, 0.8, 0.3)     # жълтеникав — предупреждение
const INFO_COLOR_ERROR := Color(1.0, 0.4, 0.4)       # червен — грешка
const INFO_COLOR_AI := Color(0.5, 0.8, 1.0)          # синкав — AI съобщения

signal cycle_continue_requested
signal card_is_drawed

signal human_closed_cycle(player_lost: int, ai_lost: int)
signal ai_closed_cycle(player_lost: int, ai_lost: int)

signal player_slots_full
signal board_cleared_due_to_full_slots

signal human_out_of_cards
signal ai_out_of_cards


# --- STATE MACHINE ---
enum PlayerID { HUMAN = 0, AI = 1 }
enum TurnState { INIT, TURN_START, PLACE_OR_SKIP, RESOLVE_CYCLE, WAIT_GO_NEXT, WAIT_END_TURN, AI_PLAYING, GAME_OVER }

@export var player_starts_first: bool = true

var current_player: int = PlayerID.HUMAN
var last_card_owner: int = PlayerID.HUMAN
var state: int = TurnState.INIT

var player_played_this_turn: bool = false
var waiting_cycle_ack: bool = false
var resolving_links: bool = false

# --- НОДОВЕ / СЦЕНА ---
@onready var end_turn_btn: Button = $EndTurnButton
@onready var ai: GameStateRandom = $GameStateRandom
@onready var info_rich_text_label: RichTextLabel = $InfoPanel/InfoRichTextLabel
@onready var panel: Panel = $PlayerHand/Deck/Panel
@onready var card_manager: CardManager = $CardManager

@export var is_edge_visible : bool = false
@export var draw_anim_s: float = 0.7
@export var draw_delay_s: float = 0.2
@export var starting_hand_size: int = 5

# Points
@onready var point_1: Node2D = $PlayerHand/Points/Point1
@onready var point_2: Node2D = $PlayerHand/Points/Point2
@onready var point_3: Node2D = $PlayerHand/Points/Point3
@onready var point_4: Node2D = $PlayerHand/Points/Point4
@onready var point_5: Node2D = $PlayerHand/Points/Point5
@onready var point_6: Node2D = $PlayerHand/Points/Point6
@onready var point_7: Node2D = $PlayerHand/Points/Point7

# Slots
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
var hand_cards: Array[Node2D] = []              # текущи карти в ръката
var home_of_card: Dictionary[Node2D, Node2D] = {}   # card(Node2D) -> point(Node2D)
var deck_index := 0                             # позиция в CollectionManager.deck
var card_to_slot: Dictionary = {}               # Card -> CardSlot
var all_slots: Array[CardSlot] = []

# --- граф / поставени карти ---
var placed_cards: Array[Card] = []        # реалните нодове на дъската
var graph: Dictionary = {}                # instance_id(int) -> Array[int]
var uid_to_card: Dictionary = {}          # uid(int) -> Card
var edges: Dictionary = {}                # "a_uid->b_uid" -> Edge

func _ready() -> void:
	CollectionManager.deck.shuffle()
	
	points = [point_1, point_2, point_3, point_4, point_5, point_6, point_7]

	all_slots = [
		player_card_slot_1, player_card_slot_2, player_card_slot_3, player_card_slot_4, player_card_slot_5,
		enemy_card_slot_6, enemy_card_slot_7, enemy_card_slot_8, enemy_card_slot_9, enemy_card_slot_10
	]

	card_manager.card_dropped_on_slot.connect(_on_card_dropped_on_slot)
	card_manager.card_dropped_back.connect(_on_card_dropped_back)

	end_turn_btn.pressed.connect(_on_end_turn_pressed)

	await _deal_initial_hand_slow()

	current_player = PlayerID.HUMAN if player_starts_first else PlayerID.AI
	last_card_owner = current_player
	player_played_this_turn = false

	_enter_state(TurnState.TURN_START)

# =========================
#   STATE MACHINE CORE
# =========================

func _enter_state(new_state: int) -> void:
	state = new_state
	match state:
		TurnState.TURN_START:
			_on_turn_start()
		TurnState.PLACE_OR_SKIP:
			_on_place_or_skip()
		TurnState.RESOLVE_CYCLE:
			_on_resolve_cycle()
		TurnState.WAIT_GO_NEXT:
			_on_wait_go_next()
		TurnState.WAIT_END_TURN:
			_on_wait_end_turn()
		TurnState.AI_PLAYING:
			_on_ai_playing()
		TurnState.GAME_OVER:
			_on_game_over()

func _on_turn_start() -> void:
	player_played_this_turn = false
	# НЕ нулираме waiting_cycle_ack тук – той се управлява от UI helper-ите
	resolving_links = false

	# ⬇️ Първо: ако всичко е пълно → опитай цикъл, иначе чисти
	if _are_all_slots_full():
		var cycle_handled := await _try_resolve_any_cycle_before_stalemate()
		if not cycle_handled:
			await _reset_board_due_to_stalemate()
		_update_turn_ui()
		# след като сме освободили, продължаваме нормално

	_update_turn_ui()

	if current_player == PlayerID.HUMAN:
		if _are_player_slots_full():
			emit_signal("player_slots_full")
			_info("You have no free slots. Press [b]End Turn[/b].", false, INFO_COLOR_WARNING)
			_enter_state(TurnState.WAIT_END_TURN)
		else:
			# ➜ НОВО: ако ръката е празна и няма дек, вдигни сигнал и не позволявай поставяне
			if _is_human_out_of_cards():
				emit_signal("human_out_of_cards")
				_info("You have no cards left. Press [b]End Turn[/b].", false, INFO_COLOR_WARNING)
				_enter_state(TurnState.WAIT_END_TURN)
			else:
				_info("[b]Your turn[/b] — place [b]one[/b] card.", false, INFO_COLOR_NORMAL)
				_enter_state(TurnState.PLACE_OR_SKIP)
	else:
		if _are_ai_slots_full():
			_info("AI slots are full — AI can’t place a card this turn. Your turn again.", false, INFO_COLOR_AI)
			current_player = PlayerID.HUMAN
			_enter_state(TurnState.TURN_START)
			return
		_enter_state(TurnState.AI_PLAYING)



func _on_place_or_skip() -> void:
	_set_player_input_enabled(true)
	# ако има свободен слот → не може End Turn
	_set_end_turn_enabled(_are_player_slots_full(), "End Turn")


func _on_resolve_cycle() -> void:
	# Влиза се тук чрез логиката за цикъл; UI ще показва „Go next“.
	_set_go_next_ui(true)
	_info("A cycle was detected. Press [b]Go next[/b] to continue.", false, INFO_COLOR_WARNING)

func _on_wait_go_next() -> void:
	# Чакаме сигнал cycle_continue_requested (от бутона)
	pass

func _on_wait_end_turn() -> void:
	if current_player == PlayerID.HUMAN:
		_set_player_input_enabled(false)
		_set_end_turn_enabled(true, "End Turn")
	else:
		_set_player_input_enabled(false)
		_set_end_turn_enabled(false, "AI turn…")

func _on_ai_playing() -> void:
	_set_player_input_enabled(false)
	_set_end_turn_enabled(false, "AI turn…")

	if _is_ai_out_of_cards():
		emit_signal("ai_out_of_cards")
		_info("AI has no cards left. Your turn.", false, INFO_COLOR_AI)
		_switch_turn()
		return

	if _are_ai_slots_full():
		_info("AI slots are full — AI can’t place a card this turn. Your turn again.", false, INFO_COLOR_AI)
		_switch_turn()
		return

	_info("AI is on turn...", false, INFO_COLOR_AI)
	await get_tree().process_frame
	ai.take_turn()
	await ai.turn_finished

	if current_player == PlayerID.HUMAN:
		return
	_switch_turn()



func _switch_turn() -> void:
	current_player = PlayerID.AI if current_player == PlayerID.HUMAN else PlayerID.HUMAN
	_enter_state(TurnState.TURN_START)



# =========================
#     РЪКА / ТЕГЛЕНЕ
# =========================

func _deal_initial_hand_slow() -> void:
	while hand_cards.size() < starting_hand_size:
		var target_point := _first_free_point()
		if target_point == null:
			break
		var card := _draw_next_card_instance()
		if card == null:
			break

		# Регистрирай картата като „в ръката“ преди анимацията
		home_of_card[card] = target_point
		hand_cards.append(card)
		card.set_meta("home_pos", target_point.global_position)

		# Постави „от дека“ и анимирай със същата продължителност като AI
		await _place_player_card_in_hand(card, target_point, true)

		# Същият стегър като при AI
		await get_tree().create_timer(0.05).timeout


# Аналог на _place_ai_card_in_hand, но за играча (разкрива картата след пристигане)
func _place_player_card_in_hand(card: Node2D, target_point: Node2D, animate_from_deck: bool = false) -> void:
	if card == null or target_point == null:
		return

	# Стартова позиция: от player „дек“ панела или директно на целта
	if animate_from_deck and is_instance_valid(panel):
		card.global_position = panel.global_position
	else:
		card.global_position = target_point.global_position

	# В ръката на играча картата се разкрива (за разлика от AI)
	if card.has_method("show_back"):
		card.show_back(true)

	card.z_index = 3

	# Използвай абсолютно същата продължителност като AI: ai.hand_anim_s (fallback към draw_anim_s)
	var dur := (ai.hand_anim_s if is_instance_valid(ai) else draw_anim_s)
	await _tween_to(card as Node2D, target_point.global_position, dur)

	if card.has_method("show_back"):
		card.show_back(false)
	card.z_index = 1





func _draw_to_full_hand() -> void:
	while hand_cards.size() < starting_hand_size:
		var p := _first_free_point()
		if p == null:
			break
		var card := _draw_next_card_instance()
		if card == null:
			break
		_place_card_at_point(card, p)

func _first_free_point() -> Node2D:
	var used := {}
	for c in hand_cards:
		var hp: Node2D = home_of_card.get(c, null)
		if hp != null:
			used[hp] = true
	for p in points:
		if not used.has(p):
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

	emit_signal("card_is_drawed")
	var as_card := card as Card
	if as_card:
		as_card.id = int(id)

	var se = data.get("self_element")
	if card.has_method("set_use_self_element"):
		card.set_use_self_element(se != null)
	if se != null and card.has_method("set_element"):
		card.set_element(_to_element(se))

	var sk = data.get("self_kind")
	if card.has_method("set_use_self_kind"):
		card.set_use_self_kind(sk != null)
	if sk != null and card.has_method("set_kind"):
		card.set_kind(_to_kind(sk))

	var ss = data.get("self_attack_style")
	if card.has_method("set_use_self_attack_style"):
		card.set_use_self_attack_style(ss != null)
	if ss != null and card.has_method("set_attack_style"):
		card.set_attack_style(_to_style(ss))

	if card.has_method("set_card_texture"):
		var path := str(data.get("card_texture", ""))
		if path != "":
			card.set_card_texture(load(path))

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

	if card_manager and card_manager.has_method("connect_card_signals"):
		card_manager.connect_card_signals(card)

	return card

func _place_card_at_point(card: Node2D, point: Node2D) -> void:
	var start_pos: Vector2 = point.global_position
	if is_instance_valid(panel):
		start_pos = panel.global_position
	card.global_position = start_pos

	home_of_card[card] = point
	hand_cards.append(card)
	card.set_meta("home_pos", point.global_position)

	if card.has_method("show_back"):
		card.show_back(true)

	card.z_index = 3
	await _tween_to(card as Node2D, point.global_position, draw_anim_s)
	if card.has_method("show_back"):
		card.show_back(false)
	card.z_index = 1

# =========================
#     DRAG / DROP
# =========================

func _on_card_dropped_back(card: Node2D) -> void:
	var home: Vector2 = card.get_meta("home_pos")
	if typeof(home) == TYPE_VECTOR2:
		var tw := create_tween()
		tw.tween_property(card, "global_position", home, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if current_player == PlayerID.HUMAN and not player_played_this_turn and not waiting_cycle_ack:
		_info("Place the card on your half.")

# STATE MACHINE: приемаме drop само в PLACE_OR_SKIP и само за човека
func _on_card_dropped_on_slot(card: Node2D, slot: Node2D) -> void:
	if state != TurnState.PLACE_OR_SKIP or current_player != PlayerID.HUMAN:
		_on_card_dropped_back(card)
		return

	_lock_during_resolve()

	home_of_card.erase(card)
	if hand_cards.has(card):
		hand_cards.erase(card)

	var c := card as Card
	if c:
		if c.has_method("set_card_owner"):
			c.set_card_owner(Card.OwnerType.PLAYER)
		last_card_owner = PlayerID.HUMAN
		_add_to_board(c)
		_bind_card_to_slot(c, slot as CardSlot)

		await _check_new_edges(c) 

	_draw_to_full_hand()
	player_played_this_turn = true

	if waiting_cycle_ack:
		_unlock_after_resolve()
		_enter_state(TurnState.WAIT_GO_NEXT)
	else:
		_unlock_after_resolve()
		_enter_state(TurnState.WAIT_END_TURN)

# =========================
#     ГРАФ / ВРЪЗКИ
# =========================

func _add_to_board(c: Card) -> void:
	if not placed_cards.has(c):
		placed_cards.append(c)
	var uid := c.get_instance_id()
	if not graph.has(uid):
		graph[uid] = []
	uid_to_card[uid] = c

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
	if not is_instance_valid(a) or not is_instance_valid(b):
		return
	if ("_is_destroying" in a and a._is_destroying) or ("_is_destroying" in b and b._is_destroying):
		return

	var a_uid := a.get_instance_id()
	var b_uid := b.get_instance_id()

	if not graph.has(a_uid):
		graph[a_uid] = []
	var neigh: Array = graph[a_uid]
	if not neigh.has(b_uid):
		neigh.append(b_uid)

		print("%d %d" % [a_uid, b_uid])

		var edge: Edge = _spawn_edge(a, b, labels)

		if edge and edge.has_method("wait_for_growth"):
			await edge.wait_for_growth()
		else:
			await get_tree().process_frame

		_check_cycle_and_destroy(a_uid, b_uid)

# =========================
#   КОНВЕРТОРИ / EDGE
# =========================

func _to_element(v) -> int:
	if v is int: return v
	if v is float: return int(v)
	if v is String and Card.Element.has(v): return Card.Element[v]
	return Card.Element.AIR

func _to_kind(v) -> int:
	if v is int: return v
	if v is float: return int(v)
	if v is String:
		if v == "ORC": v = "ORG"
		if Card.CardKind.has(v): return Card.CardKind[v]
	return Card.CardKind.HERO

func _to_style(v) -> int:
	if v is int: return v
	if v is float: return int(v)
	if v is String and Card.AttackStyle.has(v): return Card.AttackStyle[v]
	return Card.AttackStyle.MELEE

func _edge_key(a: Node, b: Node) -> String:
	return "%d->%d" % [a.get_instance_id(), b.get_instance_id()]

func _spawn_edge(a: Card, b: Card, labels: Array[String]) -> Edge:
	var key := _edge_key(a, b)
	if edges.has(key):
		return edges[key] as Edge

	var edge: Edge = EDGE_SCENE.instantiate() as Edge
	add_child(edge)
	var dur := 0.15 if is_edge_visible else 0.0
	edge.call_deferred("set_endpoints", a, b, labels, dur)
	edges[key] = edge
	if not is_edge_visible:
		edge.visible = false
	return edge

# =========================
#          ЦИКЛИ
# =========================

func _check_cycle_and_destroy(a_uid: int, b_uid: int) -> void:
	var parent := {}
	if _dfs_find_path(b_uid, a_uid, parent, MIN_CYCLE_LEN, b_uid, a_uid):
		var cycle_path := _reconstruct_path(parent, b_uid, a_uid)  # [b, ..., a]
		if cycle_path.size() >= MIN_CYCLE_LEN:
			resolving_links = true
			_set_end_turn_enabled(false, "Resolving..")
			_set_player_input_enabled(false)
			
			if not is_edge_visible:
				await _show_cycle_edges_once(cycle_path, a_uid, b_uid, 1.2)
			else:
				await _show_cycle_edges_once(cycle_path, a_uid, b_uid, 0.8)

			# STATE MACHINE: влиза в режим „Go next“
			_set_go_next_ui(true)
			resolving_links = false
			waiting_cycle_ack = true
			_info("A cycle was detected. Press [b]Go next[/b] to continue.", false, INFO_COLOR_WARNING)
			_enter_state(TurnState.WAIT_GO_NEXT)

			await cycle_continue_requested
			_set_go_next_ui(false)
			waiting_cycle_ack = false

			_destroy_cards_in_cycle(cycle_path)
			# Ако човекът е поставил последната карта → чакаме неговия End Turn.
			# Ако ИИ е поставил последната карта → веднага даваме ход на човека.
			if last_card_owner == PlayerID.HUMAN:
				_enter_state(TurnState.WAIT_END_TURN)
			else:
				# Ако още "официално" е ИИ на ход, прехвърли го към човека.
				if current_player == PlayerID.AI:
					_switch_turn()
				else:
					_enter_state(TurnState.TURN_START)


# Търси път от start до target с поне min_nodes възли (мин. цикъл = min_nodes).
# По избор игнорира ребро skip_from -> skip_to (за да избегнем 2-цикъла).
func _dfs_find_path(start: int, target: int, parent: Dictionary, min_nodes: int = 2, skip_from: int = -1, skip_to: int = -1) -> bool:
	parent.clear()
	var visited := {}
	# стек от кортежи: (node, depth)
	var stack: Array = []
	stack.append([start, 1]) # depth в брой ВЪЗЛИ по пътя; start броим като 1
	visited[start] = true

	while stack.size() > 0:
		var top = stack.pop_back()
		var u: int = top[0]
		var depth: int = top[1]

		for v in graph.get(u, []):
			# игнорирай конкретен ръб (примерно b -> a)
			if u == skip_from and v == skip_to:
				continue

			# не маркираме target като visited, ако е твърде къс път — за да позволим по-дълъг по-късно
			var is_target : bool = (v == target)
			var next_depth := depth + 1

			if is_target:
				if next_depth >= min_nodes:
					parent[v] = u
					return true
				# иначе НЕ връщаме; продължаваме да търсим други маршрути
				continue

			if not visited.has(v):
				visited[v] = true
				parent[v] = u
				stack.append([v, next_depth])

	return false



func _reconstruct_path(parent: Dictionary, start: int, end: int) -> Array[int]:
	var path: Array[int] = [end]
	var cur := end
	while cur != start and parent.has(cur):
		cur = parent[cur]
		path.append(cur)
	path.reverse()
	return path

func _destroy_cards_in_cycle(cycle_uids: Array[int]) -> void:
	var ordered: Array[int] = []
	var seen := {}
	for uid in cycle_uids:
		if not seen.has(uid):
			seen[uid] = true
			ordered.append(uid)

	await _vanish_edges_touching(ordered)

	var player_lost := 0
	var ai_lost := 0

	for uid in ordered:
		var card: Card = uid_to_card.get(uid, null) as Card
		if card and card.has_method("on_destroy"):
			card.on_destroy()
			if card.is_owned_by_ai():
				ai_lost += 1
			elif card.is_owned_by_player():
				player_lost += 1

	for uid in ordered:
		await _remove_uid_from_graph(uid)

	if last_card_owner == PlayerID.HUMAN:
		emit_signal("human_closed_cycle", player_lost, ai_lost)
	elif last_card_owner == PlayerID.AI:
		emit_signal("ai_closed_cycle", player_lost, ai_lost)

func _vanish_edges_touching(target_uids: Array[int]) -> void:
	var uid_set := {}
	for u in target_uids: uid_set[u] = true

	var to_erase: Array[String] = []
	var did_vanish := false
	var max_vanish := 0.18

	for key in edges.keys():
		var parts: PackedStringArray = key.split("->")
		if parts.size() != 2: continue
		var a_uid := int(parts[0])
		var b_uid := int(parts[1])

		if not (uid_set.has(a_uid) or uid_set.has(b_uid)):
			continue

		var edge_obj = edges[key]
		if not is_instance_valid(edge_obj):
			to_erase.append(key)
			continue

		var e := edge_obj as Edge
		if e and e.has_method("vanish"):
			e.vanish(max_vanish)
			did_vanish = true
		elif e:
			e.queue_free()
		to_erase.append(key)

	if did_vanish and is_inside_tree():
		await get_tree().create_timer(max_vanish).timeout

	for k in to_erase:
		edges.erase(k)

func _show_cycle_edges_once(path_uids: Array[int], a_uid: int, b_uid: int, show_time: float = 0.35) -> void:
	var keys: Array[String] = []
	for i in range(path_uids.size() - 1):
		keys.append("%d->%d" % [path_uids[i], path_uids[i + 1]])
	keys.append("%d->%d" % [a_uid, b_uid])

	for key in keys:
		var edge_obj: Node = edges.get(key, null)
		if edge_obj == null: continue
		if not is_instance_valid(edge_obj): continue
		var e: Edge = edge_obj as Edge
		if e == null: continue

		e.visible = true
		if e.line:
			e.line.modulate.a = 1.0
		if e.has_method("replay_growth"):
			e.replay_growth(1.0)

	if is_inside_tree():
		await get_tree().create_timer(max(0.0, show_time)).timeout

# =========================
#      СЛОТОВЕ / БИНД
# =========================

func _bind_card_to_slot(card: Card, slot: CardSlot) -> void:
	if card == null or slot == null:
		return

	card_to_slot[card] = slot
	_mark_slot_occupied(slot, card)

	if not card.is_connected("destroyed", Callable(self, "_on_card_destroyed")):
		card.destroyed.connect(_on_card_destroyed)

	card.tree_exited.connect(func():
		if card_to_slot.has(card):
			_on_card_destroyed(card),
		CONNECT_ONE_SHOT)

func _on_card_destroyed(card: Card) -> void:
	var slot: CardSlot = card_to_slot.get(card, null) as CardSlot
	if slot != null:
		_mark_slot_free(slot)
		card_to_slot.erase(card)
	else:
		_force_free_slot_for_card(card)

	var uid := card.get_instance_id()
	await _remove_uid_from_graph(uid)

	placed_cards.erase(card)
	uid_to_card.erase(uid)

	if is_inside_tree():
		await get_tree().process_frame

func _mark_slot_occupied(slot: CardSlot, card: Card) -> void:
	if slot == null: return
	if "occupant" in slot: slot.occupant = card
	elif slot.has_method("set_occupant"): slot.set_occupant(card)

	if "is_occupied" in slot: slot.is_occupied = true
	elif slot.has_method("mark_occupied"): slot.mark_occupied(card)

	if "card_in_slot" in slot:
		slot.card_in_slot = true

	if card_manager and card_manager.has_method("on_slot_occupied"):
		card_manager.on_slot_occupied(slot, card)

func _mark_slot_free(slot: CardSlot) -> void:
	if slot == null: return
	if "occupant" in slot: slot.occupant = null
	elif slot.has_method("set_occupant"): slot.set_occupant(null)

	if "is_occupied" in slot: slot.is_occupied = false
	elif slot.has_method("mark_free"): slot.mark_free()

	if "card_in_slot" in slot:
		slot.card_in_slot = false

	if card_manager and card_manager.has_method("on_slot_freed"):
		card_manager.on_slot_freed(slot)

func _force_free_slot_for_card(card: Card) -> void:
	for s in all_slots:
		if s == null:
			continue
		var matched := false
		if "occupant" in s and s.occupant == card:
			matched = true
		elif s.has_method("get_occupant") and s.get_occupant() == card:
			matched = true
		if not matched:
			if s is Node2D and card is Node2D:
				if s.global_position.distance_to(card.global_position) < 8.0:
					matched = true
		if matched:
			_mark_slot_free(s)
			var to_remove: Array = []
			for k in card_to_slot.keys():
				if card_to_slot[k] == s:
					to_remove.append(k)
			for k in to_remove:
				card_to_slot.erase(k)
			break

func _remove_uid_from_graph(uid: int) -> void:
	await _vanish_edges_touching([uid])

	graph.erase(uid)

	for key in graph.keys():
		var arr: Array = graph[key]
		if arr.has(uid):
			arr.erase(uid)
		graph[key] = arr

	uid_to_card.erase(uid)

	var to_erase: Array[String] = []
	for k in edges.keys():
		var parts : PackedStringArray = k.split("->")
		if parts.size() == 2 and (int(parts[0]) == uid or int(parts[1]) == uid):
			var e = edges[k]
			if is_instance_valid(e):
				e.queue_free()
			to_erase.append(k)
	for k in to_erase:
		edges.erase(k)

# =========================
#        ПРАВИЛА / UI
# =========================
func _are_all_slots_full() -> bool:
	return _are_player_slots_full() and _are_ai_slots_full()

# Нулира дъската: премахва всички карти (и от слотове), ръбове и граф
func _clear_board_all() -> void:
	# 1) изчезване на всички ръбове
	var all_uids: Array[int] = []
	for uid in uid_to_card.keys():
		all_uids.append(uid)
	await _vanish_edges_touching(all_uids)

	# 2) освободете всички слотове
	for s in all_slots:
		if s is CardSlot:
			_mark_slot_free(s)

	# 3) унищожете картите (ако имат on_destroy, извикай го)
	#    и изчисти локалните структури
	var to_destroy: Array[Card] = []
	for c in placed_cards:
		to_destroy.append(c)
	for c in to_destroy:
		if is_instance_valid(c):
			if c.has_method("on_destroy"):
				c.on_destroy()
			else:
				c.queue_free()

	# 4) изчисти граф/ръбове/мапинги
	graph.clear()
	uid_to_card.clear()

	for k in edges.keys():
		var e = edges[k]
		if is_instance_valid(e):
			e.queue_free()
	edges.clear()

	card_to_slot.clear()
	placed_cards.clear()

	# 5) малък кадър за стабилизиране
	if is_inside_tree():
		await get_tree().process_frame

func _reset_board_due_to_stalemate() -> void:
	emit_signal("board_cleared_due_to_full_slots")
	await _clear_board_all()
	_info("All slots were full. The board has been cleared.", false, INFO_COLOR_WARNING)




func can_player_drop_on_slot(_card: Node2D, slot: Node2D) -> bool:
	if waiting_cycle_ack:
		_info("A cycle is being resolved. Press [b]Go next[/b].", false, INFO_COLOR_WARNING)
		return false
	if current_player != PlayerID.HUMAN:
		_info("It’s AI’s turn… please wait.", false, INFO_COLOR_AI)
		return false
	if state != TurnState.PLACE_OR_SKIP:
		_info("You can’t place a card right now.", false, INFO_COLOR_WARNING)
		return false
	if player_played_this_turn:
		_info("You can’t place more than one card per turn.", false, INFO_COLOR_ERROR)
		return false
	if slot == null:
		_info("Drop the card on your side.", false, INFO_COLOR_WARNING)
		return false
	if slot.get_parent() != $Slots/PlayerSlots:
		_info("You can place cards only on [b]your[/b] side.", false, INFO_COLOR_WARNING)
		return false
	return true

func _on_end_turn_pressed() -> void:
	match state:
		TurnState.WAIT_GO_NEXT:
			emit_signal("cycle_continue_requested")

		TurnState.PLACE_OR_SKIP, TurnState.WAIT_END_TURN:
			if current_player != PlayerID.HUMAN:
				return

			# ❗ задължително поставяне: ако има място и не е сложена карта, не позволяваме End Turn
			if state == TurnState.PLACE_OR_SKIP and not _are_player_slots_full() and not player_played_this_turn:
				_info("You must place one card before ending your turn.", false, INFO_COLOR_WARNING)
				return

			_switch_turn()
		_:
			return


func _are_player_slots_full() -> bool:
	var player_slots_node := $Slots/PlayerSlots
	if not is_instance_valid(player_slots_node):
		return false
	for c in player_slots_node.get_children():
		if c is CardSlot and (not ("card_in_slot" in c and c.card_in_slot)):
			return false
	return true

func _are_ai_slots_full() -> bool:
	var parent := $Slots/EnemySlots
	if not is_instance_valid(parent):
		return false
	for c in parent.get_children():
		if c is CardSlot and not ("card_in_slot" in c and c.card_in_slot):
			return false
	return true

func _notify_if_player_slots_full_on_turn_start() -> void:
	if _are_player_slots_full():
		emit_signal("player_slots_full")
		_info("All your slots are full — you can’t place a card this turn.", false, INFO_COLOR_WARNING)

func _set_player_input_enabled(enabled: bool) -> void:
	if card_manager:
		card_manager.set_process(enabled)
		card_manager.set_process_input(enabled)
		card_manager.set_physics_process(enabled)

func _update_turn_ui() -> void:
	if waiting_cycle_ack:
		return
	if resolving_links:
		_set_end_turn_enabled(false, "Resolving…")
		return

	var human_turn := (current_player == PlayerID.HUMAN)
	_set_end_turn_enabled(human_turn, "End Turn" if human_turn else "AI turn…")
	_set_player_input_enabled(human_turn)

func _on_game_over() -> void:
	_set_end_turn_enabled(false, "Game Over")
	_set_player_input_enabled(false)
	_info("[b]Game Over[/b]", false, INFO_COLOR_NORMAL)

func _info(text: String, append: bool = false, color: Color = INFO_COLOR_NORMAL) -> void:
	if not is_instance_valid(info_rich_text_label):
		return
	var colored_text := "[color=#%s]%s[/color]" % [color.to_html(false), text]
	if append and not info_rich_text_label.text.is_empty():
		info_rich_text_label.append_text("\n" + colored_text)
	else:
		info_rich_text_label.text = colored_text

	info_rich_text_label.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(info_rich_text_label, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished

	var tw2 := create_tween()
	tw2.tween_property(info_rich_text_label, "modulate:a", 0.8, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _tween_to(node: Node2D, to_pos: Vector2, dur: float) -> void:
	var tw := node.create_tween()
	tw.tween_property(node, "global_position", to_pos, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

# --- UI helpers ---
func _set_go_next_ui(_show: bool) -> void:
	waiting_cycle_ack = _show
	if _show:
		_set_end_turn_enabled(true, "Go next")
		_set_player_input_enabled(false)
	else:
		_update_turn_ui()

func _set_end_turn_enabled(enabled: bool, label: String = "") -> void:
	if label != "":
		end_turn_btn.text = label
	end_turn_btn.disabled = not enabled

func _lock_during_resolve() -> void:
	resolving_links = true
	_set_end_turn_enabled(false, "Resolving..")
	_set_player_input_enabled(false)


func _unlock_after_resolve() -> void:
	resolving_links = false
	_update_turn_ui()
	
	
func _try_resolve_any_cycle_before_stalemate() -> bool:
	for a_uid in graph.keys():
		for b_uid in graph.get(a_uid, []):
			var parent := {}
			if _dfs_find_path(b_uid, a_uid, parent):
				var cycle_path := _reconstruct_path(parent, b_uid, a_uid)
				if cycle_path.size() >= MIN_CYCLE_LEN:
					await _run_cycle_flow(cycle_path, a_uid, b_uid)
					return true
	return false

func _run_cycle_flow(cycle_path: Array[int], a_uid: int, b_uid: int) -> void:
	resolving_links = true
	_set_end_turn_enabled(false, "Resolving..")
	_set_player_input_enabled(false)

	if not is_edge_visible:
		await _show_cycle_edges_once(cycle_path, a_uid, b_uid, 1.2)
	else:
		await _show_cycle_edges_once(cycle_path, a_uid, b_uid, 0.8)

	_set_go_next_ui(true)
	resolving_links = false
	waiting_cycle_ack = true
	_info("A cycle was detected. Press [b]Go next[/b] to continue.", false, INFO_COLOR_WARNING)
	_enter_state(TurnState.WAIT_GO_NEXT)

	await cycle_continue_requested
	_set_go_next_ui(false)
	waiting_cycle_ack = false

	_destroy_cards_in_cycle(cycle_path)

	if last_card_owner == PlayerID.HUMAN:
		_enter_state(TurnState.WAIT_END_TURN)
	else:
		if current_player == PlayerID.AI:
			_switch_turn()
		else:
			_enter_state(TurnState.TURN_START)
			
func _is_human_out_of_cards() -> bool:
	var deck := CollectionManager.deck
	return hand_cards.size() == 0 and deck_index >= deck.size()

func _is_ai_out_of_cards() -> bool:
	return is_instance_valid(ai) and ai.has_method("is_out_of_cards") and ai.is_out_of_cards()
