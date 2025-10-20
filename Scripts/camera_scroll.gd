extends Camera2D

@export var scroll_speed := 100.0     # сила на скрол с колелцето / gesture
@export var drag_speed := 1.0         # чувствителност при влачене
@export var min_y := 180.0            # горна граница
@export var max_y := 2500.0           # долна граница
@export var smooth := true            # плавно движение САМО когато не влачим
@export var smooth_factor := 0.1

var target_y: float

# mouse drag (по избор; ако не искаш мишка-валидиране, можеш да махнеш този блок)
@export var mouse_drag_button: MouseButton = MOUSE_BUTTON_LEFT
var _mouse_dragging := false
var _last_mouse_pos := Vector2.ZERO

# touch state (старата логика: 1 пръст = пан; 2+ пръста се игнорират тук)
var _touches: Dictionary = {}              # index -> pos
var _one_finger_active := false
var _one_finger_prev := Vector2.ZERO

func _ready():
	target_y = position.y
	set_process_input(true)

func _unhandled_input(event):
	# --- МИШКА: скрол само по Y ---
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_y -= scroll_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_y += scroll_speed

	# --- МИШКА: вертикално влачене (по избор) ---
	if event is InputEventMouseButton and event.button_index == mouse_drag_button:
		_mouse_dragging = event.pressed
		if _mouse_dragging:
			_last_mouse_pos = event.position

	if event is InputEventMouseMotion and _mouse_dragging:
		var dy :float = event.position.y - _last_mouse_pos.y
		_last_mouse_pos = event.position
		# по време на влачене: директно местим (без smooth), само по Y
		position.y = clamp(position.y + (-dy * drag_speed), min_y, max_y)
		target_y = position.y  # синхронизираме целта

	# --- TOUCH: старата логика с 1 пръст (пан по Y) ---
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
			if _one_finger_active and _touches.size() == 0:
				_one_finger_active = false

	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		_handle_touch_drag_y_only()

	# --- Desktop Pan Gesture (trackpad): само вертикалния компонент ---
	if event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		target_y += pg.delta.y    # delta.y > 0 => надолу, < 0 => нагоре

	# --- Граници за target (ако не сме в директно влачене) ---
	target_y = clamp(target_y, min_y, max_y)

func _process(delta):
	# По време на активно влачене с мишка/пръст НЕ изглаждаме.
	if smooth and not _mouse_dragging and not _one_finger_active:
		position.y = lerp(position.y, target_y, delta / smooth_factor)
	else:
		# при директни стъпки (скрол, gesture pan) може да скачаме към target или да сме вече задали position
		position.y = clamp(position.y if (_mouse_dragging or _one_finger_active) else target_y, min_y, max_y)

func _handle_touch_drag_y_only() -> void:
	var keys := _touches.keys()
	if keys.size() == 1:
		var p: Vector2 = _touches[keys[0]]
		if not _one_finger_active:
			_one_finger_active = true
			_one_finger_prev = p
			return
		var delta := p - _one_finger_prev
		_one_finger_prev = p
		# директно местим по Y (без smooth), инвертираме за „дърпане“ на сцената
		position.y = clamp(position.y + (-delta.y * drag_speed), min_y, max_y)
		target_y = position.y   # синхронизираме целта
	else:
		# 0 или 2+ пръста – не местим (тук няма zoom/rotate)
		_one_finger_active = false
