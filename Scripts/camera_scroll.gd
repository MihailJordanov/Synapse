extends Camera2D

@export var scroll_speed := 100.0     # колелце/gesture сила
@export var drag_speed := 1.0         # колко чувствително е влаченето
@export var min_y := 180.0            # горна граница
@export var max_y := 1500.0           # долна граница
@export var smooth := true
@export var smooth_factor := 0.2

var target_y: float
var is_dragging := false

func _ready():
	target_y = position.y
	set_process_input(true)

func _unhandled_input(event):
	# 🖱️ Скрол с колелцето
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_y -= scroll_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_y += scroll_speed

	# 📱 Плъзгане с пръст
	elif event is InputEventScreenDrag:
		# event.relative.y е колко е мръднал пръста от последния кадър
		target_y -= event.relative.y * drag_speed

	# 🧭 Граници
	target_y = clamp(target_y, min_y, max_y)

func _process(delta):
	if smooth:
		position.y = lerp(position.y, target_y, delta / smooth_factor)
	else:
		position.y = target_y
