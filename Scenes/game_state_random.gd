# GameStateRandom.gd — Random AI за твоята текуща архитектура
class_name GameStateRandom
extends Node

# === КОНФИГ ===
@export var level_path: NodePath             # посочи Level нода
@export var enemy_slots_root_path: NodePath           # посочи .../Slots/EnemySlots
@export var max_hand: int = 4                         # можеш да го сетнеш на 5 от инспектора
@export var think_time_ms: int = 300                  # "мислене" за по-естествено
@export var ai_points_root_path: NodePath  
@export var place_anim_s: float = 1.0   # време на анимацията при поставяне
@export var hand_anim_s: float = 0.2

# AI дек (id-та от CollectionManager)
@export var ai_deck_ids: PackedInt32Array = []

# === ВЪТРЕШНО СЪСТОЯНИЕ ===
const CARD_SCENE := preload("res://Scenes/card.tscn")

var _ai_points: Array[Node2D] = []
var _ai_card_home := {}   # Card -> Node2D (point)

var _level: Node = null
var _enemy_slots: Array[CardSlot] = []

var _ai_deck: Array[int] = []        # копие + shuffle на ai_deck_ids
var _ai_hand: Array[Card] = []       # Card нодове (НЕ човешката ръка)
var _rng := RandomNumberGenerator.new()

signal turn_finished

func _ready() -> void:
	_rng.randomize()
	_level = get_node(level_path)

	var enemy_root := get_node(enemy_slots_root_path)
	_enemy_slots = []
	if enemy_root:
		for c in enemy_root.get_children():
			if c is CardSlot:
				_enemy_slots.append(c)

	# събери AI Points
	var points_root := get_node(ai_points_root_path)
	if points_root:
		for p in points_root.get_children():
			if p is Node2D:
				_ai_points.append(p)

	if ai_deck_ids.size() > 0:
		init_with_ids(ai_deck_ids)

# Инициализация/смяна на тестето на AI
func init_with_ids(ids: PackedInt32Array) -> void:
	_ai_deck = []
	for i in ids:
		_ai_deck.append(int(i))
	_ai_deck.shuffle()
	_fill_hand_to_max()

# Публичен метод: извикай го при "End Turn" на играча
func take_turn() -> void:
	_fill_hand_to_max()

	var free_slots: Array[CardSlot] = _get_free_enemy_slots()
	if free_slots.is_empty() or _ai_hand.is_empty():
		emit_signal("turn_finished")
		return

	await get_tree().create_timer(think_time_ms / 1000.0).timeout

	var card_idx: int = _rng.randi_range(0, _ai_hand.size() - 1)
	var slot_idx: int = _rng.randi_range(0, free_slots.size() - 1)
	var card: Card = _ai_hand[card_idx]
	var slot: CardSlot = free_slots[slot_idx]

	if card and slot:
		# премахни занимането на точката в ръката
		_ai_card_home.erase(card)

		# анимирано „издърпване“ към слота
		await _tween_to(card, slot.global_position, place_anim_s)

		# скрий гърба – картата вече е разкрита на дъската
		if card.has_method("show_back"):
			card.show_back(false)

		# заключи и маркирай слота
		card.is_locked = true
		if "card_in_slot" in slot:
			slot.card_in_slot = true

		if _level:
			if _level.has_method("_add_to_board"):      _level._add_to_board(card)
			if _level.has_method("_bind_card_to_slot"): _level._bind_card_to_slot(card, slot)
			if _level.has_method("_check_new_edges"):   _level._check_new_edges(card)

		_ai_hand.remove_at(card_idx)

		# пренареди останалите карти в ръката (с леки tweens)
		await _relayout_ai_hand()
		# пренареди останалите карти по точките (по ред)


		_fill_hand_to_max()  # допълни до max_hand (новата карта ще си заеме свободната точка)
	emit_signal("turn_finished")


# ------------------------- ВЪТРЕШНИ ПОМОЩНИ -------------------------

func _get_free_enemy_slots() -> Array[CardSlot]:
	var res: Array[CardSlot] = []
	for s in _enemy_slots:
		if s and not s.card_in_slot:
			res.append(s)
	return res

func _fill_hand_to_max() -> void:
	while _ai_hand.size() < max_hand and _ai_deck.size() > 0:
		var id: int = _ai_deck.pop_back()
		var c := _instantiate_card_from_id(id)
		if c:
			_ai_hand.append(c)

# Създава Card по id, използвайки CollectionManager (копие на логиката ти за човешката ръка)
func _instantiate_card_from_id(id: int) -> Card:
	var data := CollectionManager.get_card(id)
	if data.is_empty():
		return null

	var card: Node2D = CARD_SCENE.instantiate()
	# логично е картите да се държат при CardManager, както правиш за човека
	if is_instance_valid(_level) and "card_manager" in _level and is_instance_valid(_level.card_manager):
		_level.card_manager.add_child(card)
	else:
		add_child(card) # fallback

	var as_card := card as Card
	if as_card:
		as_card.id = int(id)

		# --- SELF секции ---
		var se = data.get("self_element")
		as_card.set_use_self_element(se != null)
		if se != null: as_card.set_element(_to_element(se))

		var sk = data.get("self_kind")
		as_card.set_use_self_kind(sk != null)
		if sk != null: as_card.set_kind(_to_kind(sk))

		var ss = data.get("self_attack_style")
		as_card.set_use_self_attack_style(ss != null)
		if ss != null: as_card.set_attack_style(_to_style(ss))

		# текстура
		var path := str(data.get("card_texture", ""))
		if path != "": as_card.set_card_texture(load(path))

		# --- TARGET секции ---
		var ce = data.get("connect_element")
		as_card.set_use_element_target(ce != null)
		if ce != null: as_card.set_target_element(_to_element(ce))

		var ck = data.get("connect_kind")
		as_card.set_use_kind_target(ck != null)
		if ck != null: as_card.set_target_kind(_to_kind(ck))

		var cs = data.get("connect_attack_style")
		as_card.set_use_attack_style_target(cs != null)
		if cs != null: as_card.set_target_attack_style(_to_style(cs))

		_place_ai_card_in_hand(as_card)

	return as_card

# --- конвертори (копие на твоите помощни, за да не зависим от Level.*) ---
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


func _place_ai_card_in_hand(card: Card) -> void:
	# първа свободна точка
	var target: Node2D = null
	for p in _ai_points:
		var taken := false
		for c in _ai_hand:
			if _ai_card_home.get(c) == p:
				taken = true
				break
		if not taken:
			target = p
			break
	# ако няма точки, просто не местим (оставяме off-screen/0,0) или измисли си fallback
	if target:
		card.global_position = target.global_position
		card.show_back(true)   # покаже гърба, докато е в ръката
		_ai_card_home[card] = target
	# заключи картата в ръката
	card.is_locked = true
	
func _relayout_ai_hand() -> void:
	var n : int = min(_ai_hand.size(), _ai_points.size())
	for i in n:
		var card: Card = _ai_hand[i]
		var p: Node2D = _ai_points[i]
		_ai_card_home[card] = p
		await _tween_relayout(card, p)

	# ако има повече карти от точки — остави ги където са (или направи допълнителни точки)


func _tween_to(node: Node2D, to_pos: Vector2, dur: float) -> void:
	var tw := node.create_tween()
	tw.tween_property(node, "global_position", to_pos, dur) \
	  .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

func _tween_relayout(card: Card, point: Node2D) -> void:
	var tw := card.create_tween()
	tw.tween_property(card, "global_position", point.global_position, hand_anim_s) \
	  .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
