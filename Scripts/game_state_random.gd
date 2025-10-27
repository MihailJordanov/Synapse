# GameStateRandom.gd — Random AI за твоята текуща архитектура
class_name GameStateRandom
extends Node


signal card_AI_is_drawed
signal ai_slots_full


# === КОНФИГ ===
@export_category("Enemy")
@export var enemy_texture : Texture
@export var level_path: NodePath             # посочи Level нода
@export var enemy_slots_root_path: NodePath           # посочи .../Slots/EnemySlots
@export var max_hand: int = 5                         # можеш да го сетнеш на 5 от инспектора
@export var think_time_ms: int = 500                 # "мислене" за по-естествено
@export var ai_points_root_path: NodePath  
@export var place_anim_s: float = 0.7  # време на анимацията при поставяне
@export var hand_anim_s: float = 0.2

# AI дек (id-та от CollectionManager)
@export var deck: AIDeck 


@onready var deckAI_pos: Node2D = $"../AIHand/Deck"
@onready var ai_texture: TextureRect = $"../CanvasLayer/PointsPanel/AI_texture"

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
	
	#UI
	ai_texture.texture = enemy_texture

	# Enemy slots
	_enemy_slots = []
	var enemy_root := get_node(enemy_slots_root_path)
	if enemy_root:
		for c in enemy_root.get_children():
			if c is CardSlot:
				_enemy_slots.append(c)

	# AI hand points
	_ai_points = []
	var points_root := get_node(ai_points_root_path)
	if points_root:
		for p in points_root.get_children():
			if p is Node2D:
				_ai_points.append(p)

	# Зареди тестето от Resource (AIDeck)
	if deck and deck.ids.size() > 0:
		var ids: PackedInt32Array = deck.ids
		var rng := RandomNumberGenerator.new()
		rng.randomize()

		for i in range(ids.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp := ids[i]
			ids[i] = ids[j]
			ids[j] = tmp

		deck.ids = ids
		init_with_ids(deck.ids)
		
	

# Инициализация/смяна на тестето на AI
func init_with_ids(ids: PackedInt32Array) -> void:
	_ai_deck = []
	for i in ids:
		_ai_deck.append(int(i))
	_ai_deck.shuffle()
	_fill_hand_to_max()

# Публичен метод: извикай го при "End Turn" на играча
func take_turn() -> void:
	_notify_if_ai_slots_full_on_turn_start()
	
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


		if _level:
			if "last_card_owner" in _level and "PlayerID" in _level:
				_level.last_card_owner = _level.PlayerID.AI

			
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
			# анимирай от AI дека към точката в ръката
			await _place_ai_card_in_hand(c, true)
			# по избор: малък стегър за по-приятно чувство
			await get_tree().create_timer(0.05).timeout


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

		if as_card.has_method("set_card_owner"):
			as_card.set_card_owner(Card.OwnerType.AI)

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



	return as_card

# --- конвертори (копие на твоите помощни, за да не зависим от Level.*) ---
func _to_element(v) -> int:
	if v is int: return v
	if v is float: return int(v)
	if v is String and Card.Element.has(v): return Card.Element[v]
	return Card.Element.AIR

func _to_kind(v) -> int:
	if v is int:
		return v
	if v is float:
		return int(v)
	if v is String:
		var key: String = (v as String).strip_edges().to_upper()
		if Card.CardKind.has(key):
			return Card.CardKind[key]
	push_warning("Unknown kind value: %s, defaulting to HERO" % str(v))
	return Card.CardKind.HERO



func _to_style(v) -> int:
	if v is int: return v
	if v is float: return int(v)
	if v is String and Card.AttackStyle.has(v): return Card.AttackStyle[v]
	return Card.AttackStyle.MELEE


# заменя твоята версия
func _place_ai_card_in_hand(card: Card, animate_from_deck: bool = false) -> void:
	# намери първа свободна точка
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

	if target == null:
		# няма къде да я сложим – оставяме я където е
		return

	_ai_card_home[card] = target
	card.is_locked = true
	if card.has_method("show_back"):
		card.show_back(true)

	# стартова позиция: или от AI дека, или директно на целта (без анимация)
	if animate_from_deck and is_instance_valid(deckAI_pos):
		card.global_position = deckAI_pos.global_position
	else:
		card.global_position = target.global_position

	# анимирай към целевата точка в ръката
	card.z_index = 3
	await _tween_to(card, target.global_position, hand_anim_s if animate_from_deck else 0.0)
	card.z_index = 1

	emit_signal("card_AI_is_drawed")



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
	
func _are_ai_slots_full() -> bool:
	for s in _enemy_slots:
		if s is CardSlot:
			if not ("card_in_slot" in s and s.card_in_slot):
				return false
	return true

func _notify_if_ai_slots_full_on_turn_start() -> void:
	if _are_ai_slots_full():
		emit_signal("ai_slots_full")
		# по желание: покажи съобщение и в Info панела на Level (ако имаш достъп)
		if is_instance_valid(_level) and _level.has_method("_info"):
			_level._info("AI slots are full — AI can’t place a card this turn.", false, Color(0.5, 0.8, 1.0))

func is_out_of_cards() -> bool:
	return _ai_hand.size() == 0 and _ai_deck.size() == 0
