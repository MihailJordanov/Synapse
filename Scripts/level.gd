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


# game manager
enum PlayerID { HUMAN = 0, AI = 1 }
var current_player: int = PlayerID.HUMAN
var player_played_this_turn: bool = false

@onready var end_turn_btn: Button = $EndTurnButton       # посочи бутона
@onready var ai: GameStateRandom = $GameStateRandom     # посочи нода с AI
@onready var info_rich_text_label: RichTextLabel = $InfoPanel/InfoRichTextLabel
@onready var panel: Panel = $PlayerHand/Deck/Panel
@onready var card_manager: CardManager = $CardManager


@export var is_edge_visible : bool = false
@export var draw_anim_s: float = 1.# продължителност на анимацията при теглене от дека
@export var draw_delay_s: float = 0.08  
@export var starting_hand_size: int = 5


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
var home_of_card: Dictionary[Node2D, Node2D] = {}   # card(Node2D) -> point(Node2D)
var deck_index := 0                       # позиция в CollectionManager.deck
var card_to_slot: Dictionary = {}         # Card -> CardSlot
var all_slots: Array[CardSlot] = []

# --- граф / поставени карти ---
var placed_cards: Array[Card] = []        # реалните нодове на дъската
var graph: Dictionary = {}                # instance_id(int) -> Array[int]
var uid_to_card: Dictionary = {}          # uid(int) -> Card
var edges: Dictionary = {}                # речник: "a_uid->b_uid" -> инстанция на ръб
var waiting_cycle_ack: bool = false
var resolving_links: bool = false 

func _ready() -> void:
	points = [point_1, point_2, point_3, point_4, point_5, point_6, point_7]

	# събери всички слотове на едно място
	all_slots = [
		player_card_slot_1, player_card_slot_2, player_card_slot_3, player_card_slot_4, player_card_slot_5,
		enemy_card_slot_6, enemy_card_slot_7, enemy_card_slot_8, enemy_card_slot_9, enemy_card_slot_10
	]

	card_manager.card_dropped_on_slot.connect(_on_card_dropped_on_slot)
	card_manager.card_dropped_back.connect(_on_card_dropped_back)

	_draw_to_full_hand()
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	_update_turn_ui()
	_info("[b]Your turn[/b] — play [b]one[/b] card.", false, INFO_COLOR_NORMAL)


# ---------------------- РЪКА / ТЕГЛЕНЕ ----------------------

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

	# присвои id към Card (ако има поле id)
	emit_signal("card_is_drawed")
	var as_card := card as Card
	if as_card:
		as_card.id = int(id)

	# --- SELF секции: уважи null -> скрий; иначе попълни ---
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
	# стартова позиция = панела на дека (ако има), иначе директно до целта
	var start_pos: Vector2 = point.global_position
	if is_instance_valid(panel):
		# Panel е Control, но си има global_position; fallback при нужда:
		# start_pos = panel.get_global_transform().origin
		start_pos = panel.global_position

	# позиционирай картата при дека
	card.global_position = start_pos

	# бекър за ръката (за да може CardManager да я върне при “drop back”)
	home_of_card[card] = point
	hand_cards.append(card)
	card.set_meta("home_pos", point.global_position)

	# покажи гърба по време на “изтеглянето”
	if card.has_method("show_back"):
		card.show_back(true)


	card.z_index = 3

	# анимирано прехвърляне към точката в ръката
	await _tween_to(card as Node2D, point.global_position, draw_anim_s)

	# след като „дойде в ръката“ – покажи лицето (ако искаш да остане с гръб, просто махни следващия блок)
	if card.has_method("show_back"):
		card.show_back(false)


	card.z_index = 1


# ---------------------- DRAG/DROP CALLBACKS ----------------------

func _on_card_dropped_back(card: Node2D) -> void:
	var home: Vector2 = card.get_meta("home_pos")
	if typeof(home) == TYPE_VECTOR2:
		var tw := create_tween()
		tw.tween_property(card, "global_position", home, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if current_player == PlayerID.HUMAN and not player_played_this_turn and not waiting_cycle_ack:
		_info("Drop the card on your slots.")


func _on_card_dropped_on_slot(card: Node2D, slot: Node2D) -> void:
	_lock_during_resolve()          # 🔒 моментално заключване

	home_of_card.erase(card)
	if hand_cards.has(card):
		hand_cards.erase(card)


	var c := card as Card
	if c:
		_add_to_board(c)
		_bind_card_to_slot(c, slot as CardSlot)

		await _check_new_edges(c)   # чака и ръб-растежa, и cycle flow-а

	_draw_to_full_hand()

	# Ако НЯМА цикъл (=> не сме в waiting_cycle_ack), дай малък „буфер“
	if current_player == PlayerID.HUMAN and not waiting_cycle_ack:
		player_played_this_turn = true

		# 🔔 минимален визуален буфер (1.0s) преди да стане достъпен
		await get_tree().create_timer(1.0).timeout

		_unlock_after_resolve()     # 🔓 централизирано пускане
		_info("You must end your turn\n(press the [b]'End Turn'[/b] button).")
	else:
		# При цикъл _await_cycle_ack() ще се погрижи да отвори "Go next"
		# и да върне управлението след натискане.
		pass

# ---------------------- ГРАФ / ВРЪЗКИ ----------------------

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
	# защити: ако някоя карта вече напуска сцената/унищожава се
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


		var a_tpl := "?" if not ("id" in a) else str(a.id)
		var b_tpl := "?" if not ("id" in b) else str(b.id)
		print("LINK: %s(#%d) -> %s(#%d) via %s" % [a_tpl, a_uid, b_tpl, b_uid, ", ".join(labels)])

		var edge: Edge = _spawn_edge(a, b, labels)

		# 🔸 Изчакай визуалното израстване на ръба
		if edge and edge.has_method("wait_for_growth"):
			await edge.wait_for_growth()
		else:
			# защитен fallback, ако сцената още не е готова
			await get_tree().process_frame

		# Едва СЕГА проверяваме за цикъл и разрушаваме
		_check_cycle_and_destroy(a_uid, b_uid)

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



	
# ---------------------- ЦИКЛИ ----------------------

# Проверява дали добавянето на a->b затваря цикъл.
# Ако да, унищожава всички карти в цикъла (пътят b..a).
func _check_cycle_and_destroy(a_uid: int, b_uid: int) -> void:
	var parent := {}
	if _dfs_find_path(b_uid, a_uid, parent):
		var cycle_path := _reconstruct_path(parent, b_uid, a_uid)  # [b, ..., a]
		if cycle_path.size() >= MIN_CYCLE_LEN:
			# 1) визуализация (ако ръбовете иначе са скрити, ги „реплейваме“ за да се видят)
			if not is_edge_visible:
				await _show_cycle_edges_once(cycle_path, a_uid, b_uid, 1.2)
			else:
				# дори при видими ръбове – кратко „наблягане“
				await _show_cycle_edges_once(cycle_path, a_uid, b_uid, 0.8)

			# 2) пауза: изчакай играчът да натисне "Go next"
			await _await_cycle_ack()

			# 3) чак сега унищожи картите от цикъла
			_destroy_cards_in_cycle(cycle_path)


# Намира път (ако съществува) от start до target в насочения граф.
func _dfs_find_path(start: int, target: int, parent: Dictionary) -> bool:
	parent.clear()
	var visited := {}
	var stack: Array[int] = [start]
	visited[start] = true

	while stack.size() > 0:
		var u: int = stack.pop_back()
		for v in graph.get(u, []):
			if not visited.has(v):
				parent[v] = u
				if v == target:
					return true
				visited[v] = true
				stack.append(v)
	return false

# Възстановява път от start до end (ползвайки parent),
# където parent[x] е предшественик по намерения път.
func _reconstruct_path(parent: Dictionary, start: int, end: int) -> Array[int]:
	var path: Array[int] = [end]
	var cur := end
	while cur != start and parent.has(cur):
		cur = parent[cur]
		path.append(cur)
	path.reverse()  # [start .. end]
	return path

func _destroy_cards_in_cycle(cycle_uids: Array[int]) -> void:
	# уникални + подредени
	var seen := {}
	var ordered: Array[int] = []
	for uid in cycle_uids:
		if not seen.has(uid):
			seen[uid] = true
			ordered.append(uid)

	# 1) махни визуалните ръбове, които докосват цикъла
	await _vanish_edges_touching(ordered)

	# 2) стартирай анимациите за унищожение (emit "destroyed" вътре)
	for uid in ordered:
		var card: Card = uid_to_card.get(uid, null) as Card
		if card and card.has_method("on_destroy"):
			card.on_destroy()

	# 3) допълнително за здравина: махни от графа (ако още не са изчистени)
	for uid in ordered:
		await _remove_uid_from_graph(uid)

	
	
func _bind_card_to_slot(card: Card, slot: CardSlot) -> void:
	if card == null or slot == null:
		return

	card_to_slot[card] = slot
	_mark_slot_occupied(slot, card)

	# При унищожаване на картата -> освободи слота
	if not card.is_connected("destroyed", Callable(self, "_on_card_destroyed")):
		card.destroyed.connect(_on_card_destroyed)

	# Допълнителен safeguard: ако картата излезе от дървото по друг път
	card.tree_exited.connect(func():
		if card_to_slot.has(card):
			_on_card_destroyed(card),
		CONNECT_ONE_SHOT)

		
func _on_card_destroyed(card: Card) -> void:
	# 0) освободи слота
	var slot: CardSlot = card_to_slot.get(card, null) as CardSlot
	if slot != null:
		_mark_slot_free(slot)
		card_to_slot.erase(card)
	else:
		_force_free_slot_for_card(card)

	# 1) почисти графа (идемпотентно е; няма да счупи ако вече е чистено)
	var uid := card.get_instance_id()
	await _remove_uid_from_graph(uid)

	# 2) синхронизирай локалните структури (също идемпотентно)
	placed_cards.erase(card)
	uid_to_card.erase(uid)

	# 3) остави 1 кадър за стабилизиране
	if is_inside_tree():
		await get_tree().process_frame


	
	
func _mark_slot_occupied(slot: CardSlot, card: Card) -> void:
	if slot == null: return
	# occupant / API:
	if "occupant" in slot: slot.occupant = card
	elif slot.has_method("set_occupant"): slot.set_occupant(card)

	# стандартен флаг
	if "is_occupied" in slot: slot.is_occupied = true
	elif slot.has_method("mark_occupied"): slot.mark_occupied(card)

	# 🔸 ВАЖНО за CardManager:
	if "card_in_slot" in slot:
		slot.card_in_slot = true

	# (по избор) синк към CardManager, ако имаш такива методи
	if card_manager and card_manager.has_method("on_slot_occupied"):
		card_manager.on_slot_occupied(slot, card)

func _mark_slot_free(slot: CardSlot) -> void:
	if slot == null: return
	# occupant / API:
	if "occupant" in slot: slot.occupant = null
	elif slot.has_method("set_occupant"): slot.set_occupant(null)

	# стандартен флаг
	if "is_occupied" in slot: slot.is_occupied = false
	elif slot.has_method("mark_free"): slot.mark_free()

	# 🔸 ВАЖНО за CardManager:
	if "card_in_slot" in slot:
		slot.card_in_slot = false

	# (по избор) синк към CardManager
	if card_manager and card_manager.has_method("on_slot_freed"):
		card_manager.on_slot_freed(slot)
		
		
func _force_free_slot_for_card(card: Card) -> void:
	for s in all_slots:
		if s == null:
			continue
		var matched := false

		# огледай най-чести схеми
		if "occupant" in s and s.occupant == card:
			matched = true
		elif s.has_method("get_occupant") and s.get_occupant() == card:
			matched = true

		# ако няма пряка референция — може да има флагов механизъм
		# тогава прецени по близост (ако слотовете са позиционни)
		if not matched:
			# ако имаш Area2D/Rect проверка, можеш да я ползваш тук
			# примерна евристика по дистанция:
			if s is Node2D and card is Node2D:
				if s.global_position.distance_to(card.global_position) < 8.0: # прага го нагласи
					matched = true

		if matched:
			_mark_slot_free(s)
			# премахни и обратно евентуални мапинги
			var to_remove: Array = []
			for k in card_to_slot.keys():
				if card_to_slot[k] == s:
					to_remove.append(k)
			for k in to_remove:
				card_to_slot.erase(k)

			break


func _vanish_edges_touching(target_uids: Array[int]) -> void:
	var uid_set := {}
	for u in target_uids: uid_set[u] = true

	var to_erase: Array[String] = []
	var did_vanish := false
	var max_vanish := 0.18  # синхронизирай с Edge.vanish()

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
	# събери ключовете "u_i->u_{i+1}" от пътя + затварящия "a->b"
	var keys: Array[String] = []
	for i in range(path_uids.size() - 1):
		keys.append("%d->%d" % [path_uids[i], path_uids[i + 1]])
	keys.append("%d->%d" % [a_uid, b_uid])

	# покажи само тези ръбове
	for key in keys:
		var edge_obj: Node = edges.get(key, null)
		if edge_obj == null: 
			continue
		if not is_instance_valid(edge_obj):
			continue
		var e: Edge = edge_obj as Edge
		if e == null:
			continue

		e.visible = true
		if e.line:
			e.line.modulate.a = 1.0
		if e.has_method("replay_growth"):
			e.replay_growth(1.0)  

	# единствено, кратко изчакване за визуализацията
	if is_inside_tree():
		await get_tree().create_timer(max(0.0, show_time)).timeout
		
func can_player_drop_on_slot(card: Node2D, slot: Node2D) -> bool:
	# стоп по време на паузата за цикъл
	if waiting_cycle_ack:
		_info("A cycle is being resolved. Press [b]Go next[/b].", false, INFO_COLOR_WARNING)
		return false
	
	# 1) човешки ход ли е?
	if current_player != PlayerID.HUMAN:
		_info("It's AI's turn… please wait.", false, INFO_COLOR_AI)
		return false

	# 2) точно една карта на ход
	if player_played_this_turn:
		_info("You can't place more than one card per turn.", false, INFO_COLOR_ERROR)
		return false  # ← важно: вътре в if-а!

	# 3) реален слот ли е?
	if slot == null:
		_info("Drop the card on your slots.", false, INFO_COLOR_WARNING)
		return false

	# 4) само в PlayerSlots
	if slot.get_parent() != $Slots/PlayerSlots:
		_info("You can place cards only on [b]your[/b] side.", false, INFO_COLOR_WARNING)
		return false

	return true



func _on_end_turn_pressed() -> void:
	if resolving_links:
		return
	if waiting_cycle_ack:
		emit_signal("cycle_continue_requested")
		return

	if current_player != PlayerID.HUMAN:
		return
	if not player_played_this_turn:
		_info("You have to play one card.", false, INFO_COLOR_WARNING)
		return

	# към AI
	current_player = PlayerID.AI
	player_played_this_turn = false
	_update_turn_ui()
	_info("AI is playing…", false, INFO_COLOR_AI)

	await get_tree().process_frame
	ai.take_turn()
	await ai.turn_finished

	# обратно към човека
	current_player = PlayerID.HUMAN
	_update_turn_ui()
	_info("[b]Your turn[/b] — play [b]one[/b] card.", false, INFO_COLOR_NORMAL)


func _set_player_input_enabled(enabled: bool) -> void:
	if card_manager:
		card_manager.set_process(enabled)
		card_manager.set_process_input(enabled)
		card_manager.set_physics_process(enabled)
		
		
# докато тече проверка/визуализация, UI не трябва да го включва
func _update_turn_ui() -> void:
	if waiting_cycle_ack:
		return  # "Go next" режим управлява UI-то сам
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

	# поставяме текста (с цвят)
	var colored_text := "[color=#%s]%s[/color]" % [color.to_html(false), text]
	if append and not info_rich_text_label.text.is_empty():
		info_rich_text_label.append_text("\n" + colored_text)
	else:
		info_rich_text_label.text = colored_text

	# леко „премигване“ / подсилване на вниманието
	info_rich_text_label.modulate = Color(1, 1, 1, 0)  # започва прозрачен
	var tw := create_tween()
	tw.tween_property(info_rich_text_label, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished

	# кратко задържане, после леко избледняване (по избор)
	var tw2 := create_tween()
	tw2.tween_property(info_rich_text_label, "modulate:a", 0.8, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _tween_to(node: Node2D, to_pos: Vector2, dur: float) -> void:
	var tw := node.create_tween()
	tw.tween_property(node, "global_position", to_pos, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	
func _set_go_next_ui(show: bool) -> void:
	waiting_cycle_ack = show
	if show:
		_set_end_turn_enabled(true, "Go next")
		_set_player_input_enabled(false)
	else:
		_update_turn_ui()



# когато стигнем до паузата за цикъл – едва СЛЕД визуализацията включваме бутона за "Go next"
func _await_cycle_ack() -> void:
	# до тук сме в resolving_links == true
	_set_go_next_ui(true)    # прави бутона активен + текст "Go next"
	resolving_links = false  # вече само чакаме потвърждение
	_info("A cycle was detected. Press [b]Go next[/b] to continue.", false, INFO_COLOR_WARNING)

	await cycle_continue_requested
	_set_go_next_ui(false)   # връща към нормалния режим (ще мине през _update_turn_ui)


	
	
func _remove_uid_from_graph(uid: int) -> void:
	# 1) махни визуалните ръбове, които го докосват
	await _vanish_edges_touching([uid])

	# 2) махни върха
	graph.erase(uid)

	# 3) махни всички препратки към него в съседните списъци
	for key in graph.keys():
		var arr: Array = graph[key]
		if arr.has(uid):
			arr.erase(uid)
		graph[key] = arr

	# 4) изчисти uid->card мапинга
	uid_to_card.erase(uid)

	# 5) допълнително: ако е останал визуален ръб в `edges`, го махни
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
		
func _set_end_turn_enabled(enabled: bool, label: String = "") -> void:
	if label != "":
		end_turn_btn.text = label
	end_turn_btn.disabled = not enabled

func _lock_during_resolve() -> void:
	resolving_links = true
	_set_end_turn_enabled(false)  # заключи бутона
	_set_player_input_enabled(false)

func _unlock_after_resolve() -> void:
	resolving_links = false
	_update_turn_ui()  # централизирано пуска каквото трябва
