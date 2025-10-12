class_name Edge
extends Node2D

signal grown
signal vanished

@export var animate_duration: float = 1.0
@onready var line: Line2D = $Line2D


var _a_anchor: Node2D
var _b_anchor: Node2D
var _anim_tween: Tween
var _anim_t: float = 0.0  # 0..1
var _grown: bool = false

# Edge.gd
func set_endpoints(a_card: Node, b_card: Node, _labels := [], custom_duration: float = -1.0) -> void:
	if not is_node_ready():
		await ready

	if line == null:
		line = get_node_or_null("Line2D")
		if line == null:
			push_error("Edge: missing Line2D child")
			return

	_a_anchor = _resolve_anchor(a_card)
	_b_anchor = _resolve_anchor(b_card)
	if _a_anchor == null or _b_anchor == null:
		queue_free()
		return

	var pos_a: Vector2 = _a_anchor.global_position
	line.points = PackedVector2Array([pos_a, pos_a])

	_a_anchor.tree_exited.connect(_on_end_exited)
	_b_anchor.tree_exited.connect(_on_end_exited)

	# --- задаване на продължителност ---
	var dur := animate_duration
	if custom_duration >= 0.0:
		dur = custom_duration

	# убий стар tween, ако има
	if _anim_tween:
		_anim_tween.kill()
		_anim_tween = null

	if dur <= 0.0:
		# моментално „порастване“
		_anim_t = 1.0
		_on_grown()
		return

	_anim_t = 0.0
	_anim_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(self, "_anim_t", 1.0, dur)
	_anim_tween.finished.connect(_on_grown, CONNECT_ONE_SHOT)


func _process(_dt: float) -> void:
	if _a_anchor == null or _b_anchor == null or line == null:
		return

	var pos_a: Vector2 = _a_anchor.global_position
	var pos_b: Vector2 = _b_anchor.global_position

	line.set_point_position(0, pos_a)

	var current_b: Vector2 = pos_a.lerp(pos_b, _anim_t)
	if line.points.size() < 2:
		line.add_point(current_b)
	else:
		line.set_point_position(1, current_b)

	if _anim_t >= 1.0:
		line.set_point_position(1, pos_b)

func _resolve_anchor(card: Node) -> Node2D:
	if card and card.has_node("EdgeAnchor"):
		var n = card.get_node("EdgeAnchor")
		if n is Node2D:
			return n

	if card is Node2D:
		return card

	if card is Control:
		var top_left: Vector2 = card.global_position
		var center: Vector2 = top_left + card.size * 0.5
		var proxy := Node2D.new()
		add_child(proxy)
		proxy.global_position = center
		return proxy

	return null

func _on_end_exited() -> void:
	queue_free()
	
func _on_grown() -> void:
	_grown = true
	emit_signal("grown")

func wait_for_growth() -> void:
	if _grown:
		return
	await grown
	
func vanish(duration: float = 0.2) -> void:
	# спри да следваш картите, за да не подскача при queue_free на картите
	set_process(false)
	# спри текущи тийнове ако има
	if _anim_tween: _anim_tween.kill()

	# плавно скриване на линията
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(line, "modulate:a", 0.0, duration)
	tw.finished.connect(_on_vanished, CONNECT_ONE_SHOT)

func _on_vanished() -> void:
	emit_signal("vanished")
	queue_free()

func wait_for_vanish() -> void:
	await vanished
	
func replay_growth(duration: float = 0.5) -> void:
	if line == null or _a_anchor == null or _b_anchor == null:
		return
	# нулирай и пусни кратък растеж
	_anim_t = 0.0
	set_process(true)
	if _anim_tween: _anim_tween.kill()
	_anim_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(self, "_anim_t", 1.0, duration)
