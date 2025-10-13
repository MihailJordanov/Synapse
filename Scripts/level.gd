class_name Level
extends Node2D

const MAX_HAND := 4
const MIN_CYCLE_LEN := 3  # игнорирай 2-цикъл (1 ↔ 2)
const CARD_SCENE := preload("res://Scenes/card.tscn")
const EDGE_SCENE := preload("res://Scenes/edge.tscn")

@export var is_edge_visible : bool = false

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
var card_to_slot: Dictionary = {}         # Card -> CardSlot
var all_slots: Array[CardSlot] = []

# --- граф / поставени карти ---
var placed_cards: Array[Card] = []        # реалните нодове на дъската
var graph: Dictionary = {}                # instance_id(int) -> Array[int]
var uid_to_card: Dictionary = {}          # uid(int) -> Card
var edges: Dictionary = {}                # речник: "a_uid->b_uid" -> инстанция на ръб


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
	
	if hand_cards.has(card):
		hand_cards.erase(card)
		home_of_card.erase(card)

	var c := card as Card
	if c:
		_add_to_board(c)
		_bind_card_to_slot(c, slot as CardSlot)
		_check_new_edges(c)
	_draw_to_full_hand()

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
	var a_uid := a.get_instance_id()
	var b_uid := b.get_instance_id()

	if not graph.has(a_uid):
		graph[a_uid] = []
	var neigh: Array = graph[a_uid]
	if not neigh.has(b_uid):
		neigh.append(b_uid)
		graph[a_uid] = neigh

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
	
# Level.gd (_spawn_edge)
func _spawn_edge(a: Card, b: Card, labels: Array[String]) -> Edge:
	var key := _edge_key(a, b)
	if edges.has(key):
		return edges[key] as Edge
	var edge: Edge = EDGE_SCENE.instantiate() as Edge
	add_child(edge)
	# ако е скрит режим – 0.0 (моментално); иначе кратка анимация
	var dur := 0.15 if is_edge_visible else 0.0
	edge.call_deferred("set_endpoints", a, b, labels, dur)
	edges[key] = edge
	if not is_edge_visible:
		edge.visible = false
	return edge


	# ако не искаме да се виждат по време на играта – скрий ги
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
			# само при скрити ръбове: покажи цикъла за момент (за да се види трасето)
			if not is_edge_visible:
				await _show_cycle_edges_once(cycle_path, a_uid, b_uid, 1.2)
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
	# махни дубликати, създай подреден списък
	var seen := {}
	var ordered: Array[int] = []
	for uid in cycle_uids:
		if not seen.has(uid):
			seen[uid] = true
			ordered.append(uid)

	# 1) ВАНИШ на всички ръбове, които докосват някой UID от цикъла
	await _vanish_edges_touching(ordered)

	# 2) Сега унищожи картите (ще пуснат своите анимации)
	for uid in ordered:
		var card: Card = uid_to_card.get(uid, null) as Card
		if card and card.has_method("on_destroy"):
			card.on_destroy()

	# 3) Почисти графа/буферите
	for uid in ordered:
		graph.erase(uid)
	for key in graph.keys():
		var arr: Array = graph[key]
		for uid in ordered:
			if arr.has(uid):
				arr.erase(uid)
		graph[key] = arr

	for uid in ordered:
		var c: Card = uid_to_card.get(uid, null) as Card
		if c and placed_cards.has(c):
			placed_cards.erase(c)
		uid_to_card.erase(uid)


	# По желание: махни и визуалните ръбове, ако държиш да изчезнат веднага
	# (обикновено ще се разкарат сами, когато картите се изтрият)
	# for key in edges.keys():
	#     var parts = key.split("->")
	#     if int(parts[0]) in seen or int(parts[1]) in seen:
	#         var e = edges[key]
	#         if is_instance_valid(e): e.queue_free()
	#         edges.erase(key)
	
	
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
	# 1) опитай директно през мапинга
	var slot: CardSlot = card_to_slot.get(card, null) as CardSlot
	if slot != null:
		_mark_slot_free(slot)
		card_to_slot.erase(card)
	else:
		# 2) fallback: намери слота, който още реферира тази карта
		_force_free_slot_for_card(card)

	# почистване на структури (ако още не са почистени другаде)
	uid_to_card.erase(card.get_instance_id())
	placed_cards.erase(card)  # ако присъства

	# остави 1 кадър за стабилизиране на drag/drop
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
			for k in card_to_slot.keys():
				if card_to_slot[k] == s:
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

		if uid_set.has(a_uid) or uid_set.has(b_uid):
			var edge_obj = edges[key]
			if not is_instance_valid(edge_obj):
				to_erase.append(key)
				continue

			var e := edge_obj as Edge
			if e:
				if e.has_method("vanish"):
					e.vanish(max_vanish)
					did_vanish = true
				else:
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
