class_name Edge
extends Node2D

signal grown
signal vanished

@export var animate_duration: float = 1.0
@export var card_half_size: Vector2 = Vector2(32, 48) # половин ширина/височина на карта
@export var trim_len: float = 0                    # скъсяване на краищата
@export var curve_segments: int = 50                # тесселация на кривата
@export var base_offset: float = 16.0      
@export var edge_inset: float = 15
@export var use_border_attachment: bool = true  # false => от център
@export var debug_vis: bool = false             # визуални маркери (A/B/ctrl)


var _dbg_A: Vector2 = Vector2.ZERO
var _dbg_B: Vector2 = Vector2.ZERO
var _dbg_C: Vector2 = Vector2.ZERO


@onready var line: Line2D = $Line2D

var _a_anchor: Node2D
var _b_anchor: Node2D
var _a_uid: int = 0
var _b_uid: int = 0

var _anim_tween: Tween
var _anim_t: float = 0.0  # 0..1
var _grown: bool = false

# ------------------------------------------------------------
# PUBLIC
# ------------------------------------------------------------

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

	_a_uid = a_card.get_instance_id()
	_b_uid = b_card.get_instance_id()

	# стартово начертаване (нулева дължина)
	var A: Vector2 = _attach_point_on_card(_a_anchor, _b_anchor.global_position)
	line.points = PackedVector2Array([A, A])

	_a_anchor.tree_exited.connect(_on_end_exited)
	_b_anchor.tree_exited.connect(_on_end_exited)

	# --- Продължителност ---
	var dur := animate_duration
	if custom_duration >= 0.0:
		dur = custom_duration

	# убий стар tween, ако има
	if _anim_tween:
		_anim_tween.kill()
		_anim_tween = null

	if dur <= 0.0:
		_anim_t = 1.0
		_grown = true
		emit_signal("grown")
		set_process(true) # да следва движението на картите
		return

	_anim_t = 0.0
	set_process(true) # анимираме по кривата
	_anim_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(self, "_anim_t", 1.0, dur)
	_anim_tween.finished.connect(_on_grown, CONNECT_ONE_SHOT)


func wait_for_growth() -> void:
	if _grown:
		return
	await grown


func vanish(duration: float = 0.2) -> void:
	# спираме да следваме картите (за да не подскача при queue_free)
	set_process(false)
	# спри текущи тийнове ако има
	if _anim_tween:
		_anim_tween.kill()

	# плавно скриване на линията
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(line, "modulate:a", 0.0, duration)
	tw.finished.connect(_on_vanished, CONNECT_ONE_SHOT)


func replay_growth(duration: float = 0.5) -> void:
	if line == null or _a_anchor == null or _b_anchor == null:
		return
	_anim_t = 0.0
	set_process(true)
	if _anim_tween:
		_anim_tween.kill()
	_anim_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(self, "_anim_t", 1.0, duration)

# ------------------------------------------------------------
# PROCESS & BUILD
# ------------------------------------------------------------

func _process(_dt: float) -> void:
	if _a_anchor == null or _b_anchor == null or line == null:
		return

	# 1) изчисли точки по квадратична Безие крива (A, Ctrl, B)
	var A: Vector2 = _attach_point_on_card(_a_anchor, _b_anchor.global_position)
	var B: Vector2 = _attach_point_on_card(_b_anchor, _a_anchor.global_position)

	var ab: Vector2 = (B - A)
	if ab == Vector2.ZERO:
		# обезопасителен fallback
		line.points = PackedVector2Array([A, B])
		return

	var mid :Vector2  = (A + B) * 0.5
	var n := Vector2(-ab.y, ab.x).normalized()
	var offset: float = _stable_offset_for_pair(_a_uid, _b_uid, base_offset, A, B)
	var ctrl :Vector2 = mid + n * offset

	var full_points :PackedVector2Array = _tessellate_quadratic(A, ctrl, B, curve_segments)

	# 2) скъси краищата към рамката
	if trim_len > 0.0 and full_points.size() >= 2:
		full_points = _trim_polyline_ends(full_points, trim_len)

	# 3) растеж по кривата (анимация от 0..1)
	var grown_points :PackedVector2Array = _polyline_prefix(full_points, _anim_t)
	line.points = grown_points

	# при приключила анимация — оставаме да следим позициите, но без отрязване
	if _anim_t >= 1.0:
		line.points = full_points
		
	if debug_vis:
		_dbg_A = A
		_dbg_B = B
		_dbg_C = ctrl
		queue_redraw() 


# ------------------------------------------------------------
# HELPERS
# ------------------------------------------------------------

func _resolve_anchor(card: Node) -> Node2D:
	# 1) Ако картата има EdgeAnchor дете → използвай него
	if card and card.has_node("EdgeAnchor"):
		var n = card.get_node("EdgeAnchor")
		if n is Node2D:
			return n

	# 2) Node2D → директно
	if card is Node2D:
		return card

	# 3) Control → създай временен Node2D в центъра
	if card is Control:
		var top_left: Vector2 = card.global_position
		var center: Vector2 = top_left + card.size * 0.5
		var proxy := Node2D.new()
		add_child(proxy)
		proxy.global_position = center
		return proxy

	return null

func _attach_point_on_card(anchor: Node2D, towards: Vector2) -> Vector2:
	var c: Vector2 = anchor.global_position

	# ако искаш от център (без рамка)
	if not use_border_attachment:
		return c

	var dir: Vector2 = towards - c
	if dir == Vector2.ZERO:
		return c
	var nx: Vector2 = dir.normalized()

	var half: Vector2 = _compute_card_half_size(anchor)
	var half_w: float = half.x
	var half_h: float = half.y
	var ax: float = abs(nx.x)
	var ay: float = abs(nx.y)

	var p: Vector2
	if ax > ay:
		var side: float = sign(nx.x) # -1 = left, +1 = right
		p = c + Vector2(side * half_w, clamp(nx.y * half_h / max(ax, 0.0001), -half_h, half_h))
	else:
		var side: float = sign(nx.y) # -1 = up, +1 = down
		p = c + Vector2(clamp(nx.x * half_w / max(ay, 0.0001), -half_w, half_w), side * half_h)

	# придърпай малко НАВЪТРЕ от рамката (противоположно на посоката към целта)
	var inset: float = max(0.0, edge_inset - trim_len * 0.5)  # компенсира част от trim-а
	return p - nx * inset




func _tessellate_quadratic(A: Vector2, C: Vector2, B: Vector2, segs: int) -> PackedVector2Array:
	segs = max(2, segs)
	var pts := PackedVector2Array()
	pts.resize(segs + 1)
	for i in range(segs + 1):
		var t := float(i) / float(segs)
		# квадратичен Безие: Lerp(Lerp(A,C,t), Lerp(C,B,t), t)
		var p1 := A.lerp(C, t)
		var p2 := C.lerp(B, t)
		pts[i] = p1.lerp(p2, t)
	return pts


func _polyline_length(pts: PackedVector2Array) -> float:
	var L := 0.0
	for i in range(1, pts.size()):
		L += pts[i - 1].distance_to(pts[i])
	return L


func _polyline_prefix(pts: PackedVector2Array, t: float) -> PackedVector2Array:
	t = clamp(t, 0.0, 1.0)
	if pts.size() <= 1:
		return pts
	if t <= 0.0:
		return PackedVector2Array([pts[0]])
	if t >= 1.0:
		return pts

	var total := _polyline_length(pts)
	var target := total * t

	var out := PackedVector2Array()
	out.append(pts[0])

	var acc := 0.0
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var seg := a.distance_to(b)
		if acc + seg < target:
			out.append(b)
			acc += seg
		else:
			var remain := target - acc
			var ratio := remain / seg
			out.append(a.lerp(b, ratio))
			break
	return out


func _trim_polyline_ends(pts: PackedVector2Array, trim: float) -> PackedVector2Array:
	if pts.size() < 2 or trim <= 0.0:
		return pts

	# Трим от началото
	var start_idx := 0
	var start_pos := pts[0]
	var remain := trim
	while start_idx < pts.size() - 1 and remain > 0.0:
		var seg := start_pos.distance_to(pts[start_idx + 1])
		if seg <= remain:
			remain -= seg
			start_idx += 1
			start_pos = pts[start_idx]
		else:
			start_pos = start_pos.lerp(pts[start_idx + 1], remain / seg)
			remain = 0.0

	# Трим от края
	var end_idx := pts.size() - 1
	var end_pos := pts[end_idx]
	remain = trim
	while end_idx > 0 and remain > 0.0:
		var seg2 := pts[end_idx - 1].distance_to(end_pos)
		if seg2 <= remain:
			remain -= seg2
			end_idx -= 1
			end_pos = pts[end_idx]
		else:
			end_pos = end_pos.lerp(pts[end_idx - 1], remain / seg2)
			remain = 0.0

	var out := PackedVector2Array()
	out.append(start_pos)
	for i in range(start_idx + 1, end_idx):
		out.append(pts[i])
	out.append(end_pos)
	return out


func _stable_offset_for_pair(a_uid: int, b_uid: int, base: float, A: Vector2, B: Vector2) -> float:
	var ab: Vector2 = (B - A).normalized()
	var ax: float = abs(ab.x)
	var ay: float = abs(ab.y)

	# криви само при почти колинеарни на осите (регулирай 0.92 по вкус)
	var need_curve: bool = (ax > 0.92 or ay > 0.92)
	if not need_curve:
		return 0.0

	var h: int = int(a_uid) * 73856093 ^ int(b_uid) * 19349663
	var seq: Array[int] = [0, 1, -1, 2, -2]
	var idx: int = abs(h) % seq.size()
	return float(seq[idx]) * base




# ------------------------------------------------------------
# CALLBACKS
# ------------------------------------------------------------

func _on_end_exited() -> void:
	queue_free()

func _on_grown() -> void:
	_grown = true
	emit_signal("grown")

func _on_vanished() -> void:
	emit_signal("vanished")
	queue_free()
	
func _compute_card_half_size(anchor: Node) -> Vector2:
	# 1) RectangleShape2D (ако има)
	if anchor is Node2D:
		var rect_shape: RectangleShape2D = _find_rect_shape(anchor as Node2D)
		if rect_shape != null:
			var ext: Vector2 = rect_shape.extents
			var gscale: Vector2 = (anchor as Node2D).get_global_transform().get_scale()
			return Vector2(abs(ext.x * gscale.x), abs(ext.y * gscale.y))

	# 2) Sprite2D като дете
	var sprite: Sprite2D = null
	if anchor is Node2D:
		sprite = ((anchor as Node2D).get_node_or_null("Sprite2D") as Sprite2D)
	if sprite != null and sprite.texture != null:
		var sz: Vector2 = sprite.texture.get_size() * sprite.scale
		return sz * 0.5

	# 3) Control (напр. TextureRect)
	if anchor is Control:
		return (anchor as Control).size * 0.5

	# 4) fallback
	return card_half_size



func _find_rect_shape(n: Node2D) -> RectangleShape2D:
	var cs: CollisionShape2D = n.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs != null and cs.shape is RectangleShape2D:
		return cs.shape as RectangleShape2D
	for child in n.get_children():
		var ccs := child as CollisionShape2D
		if ccs != null and ccs.shape is RectangleShape2D:
			return ccs.shape as RectangleShape2D
	return null



func _draw() -> void:
	if not debug_vis:
		return
	# A/B точки
	draw_circle(_dbg_A, 4.0, Color(0.2, 1.0, 0.2, 0.9))
	draw_circle(_dbg_B, 4.0, Color(1.0, 0.2, 0.2, 0.9))
	# Ctrl и нормала
	draw_circle(_dbg_C, 3.0, Color(0.2, 0.6, 1.0, 0.9))
	draw_line(_dbg_A, _dbg_B, Color(1,1,1,0.15), 1.0)   # ориентир AB
	draw_line((_dbg_A+_dbg_B)*0.5, _dbg_C, Color(0.2,0.6,1,0.5), 1.0)
