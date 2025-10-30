## Camera2DMoveMap.gd
class_name Camera2DMoveMap
extends Camera2D

@export var world_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(700, 600))
@export var min_zoom: float = 1
@export var max_zoom: float = 3.0
@export var mouse_drag_button: MouseButton = MOUSE_BUTTON_LEFT
@export var drag_sensitivity: float = 1.0
@export var wheel_zoom_factor: float = 1.1
@export var touch_zoom_smooth: float = 1.0


var _dragging: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

# touch state
var _touches: Dictionary = {}             
var _last_pinch_dist: float = 0.0
var _one_finger_active: bool = false
var _one_finger_prev: Vector2 = Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT

func _unhandled_input(event: InputEvent) -> void:
	# --- Mouse drag ---
	if event is InputEventMouseButton and event.button_index == mouse_drag_button:
		if event.pressed:
			_dragging = true
			_last_mouse_pos = (event as InputEventMouseButton).position
		else:
			_dragging = false

	if event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		var delta: Vector2 = mm.position - _last_mouse_pos
		_last_mouse_pos = mm.position
		var factor: float = 1.0 / zoom.x
		global_position -= delta * factor * drag_sensitivity
		_clamp_to_bounds()

	# --- Mouse wheel zoom (focus at cursor) ---
	if event is InputEventMouseButton and ((event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_UP or (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var mb := event as InputEventMouseButton
		var focus_vp: Vector2 = get_viewport().get_mouse_position()
		var step: float = wheel_zoom_factor if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / wheel_zoom_factor
		_zoom_at(focus_vp, step)

	# --- Touch tracking ---
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
			_last_pinch_dist = 0.0
			if _one_finger_active and _touches.size() == 0:
				_one_finger_active = false

	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		_handle_touch_gestures(sd)

	# --- Optional desktop gestures (if OS provides) ---
	if event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		var focus: Vector2 = mg.position
		var factor: float = max(0.01, (1.0 + mg.factor))
		_zoom_at(focus, factor)
	if event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		global_position -= pg.delta / zoom.x
		_clamp_to_bounds()

func _handle_touch_gestures(_sd: InputEventScreenDrag) -> void:
	var keys: Array = _touches.keys()
	if keys.size() == 1:
		# one-finger pan
		var p: Vector2 = _touches[keys[0]]
		if not _one_finger_active:
			_one_finger_active = true
			_one_finger_prev = p
			return
		var delta: Vector2 = p - _one_finger_prev
		_one_finger_prev = p
		global_position -= (delta / zoom.x) * drag_sensitivity
		_clamp_to_bounds()
	elif keys.size() >= 2:
		_one_finger_active = false
		var p1: Vector2 = _touches[keys[0]]
		var p2: Vector2 = _touches[keys[1]]
		var mid: Vector2 = (p1 + p2) * 0.5
		var dist: float = p1.distance_to(p2)
		if _last_pinch_dist == 0.0:
			_last_pinch_dist = dist
			return
		var ratio_raw: float = dist / _last_pinch_dist
		_last_pinch_dist = lerpf(_last_pinch_dist, dist, touch_zoom_smooth)
		var ratio: float = clamp(ratio_raw, 0.01, 100.0)
		_zoom_at(mid, ratio)

# --- Utilities ---

# Конвертира viewport координата към world (без да ползваме screen_to_world()).
# Работи при стандартна Camera2D без ротация/скейл по осите различен от zoom.
func _vp_to_world(vp_pos: Vector2) -> Vector2:
	var vp_size: Vector2 = get_viewport_rect().size
	# отместване спрямо центъра и компенсация на zoom
	return global_position + (vp_pos - vp_size * 0.5) / zoom

func _zoom_at(focus_in_viewport: Vector2, factor: float) -> void:
	var before: Vector2 = _vp_to_world(focus_in_viewport)
	var new_zoom_val: float = clamp(zoom.x * factor, min_zoom, max_zoom)
	zoom = Vector2(new_zoom_val, new_zoom_val)
	var after: Vector2 = _vp_to_world(focus_in_viewport)
	global_position += (before - after)
	_clamp_to_bounds()

func _clamp_to_bounds() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var half: Vector2 = (vp_size * 0.5) / zoom

	var min_x: float = world_bounds.position.x + min(half.x, world_bounds.size.x * 0.5)
	var max_x: float = world_bounds.position.x + world_bounds.size.x - min(half.x, world_bounds.size.x * 0.5)
	var min_y: float = world_bounds.position.y + min(half.y, world_bounds.size.y * 0.5)
	var max_y: float = world_bounds.position.y + world_bounds.size.y - min(half.y, world_bounds.size.y * 0.5)

	global_position.x = clampf(global_position.x, min_x, max_x)
	global_position.y = clampf(global_position.y, min_y, max_y)
