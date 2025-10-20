extends VScrollBar

@onready var camera: Camera2D = $"../../Camera2D"
@onready var scrollbar: VScrollBar = $"."

# тези стойности трябва да отговарят на min_y и max_y от камерата
@export var min_y := 180.0
@export var max_y := 2500.0

func _ready():
	# Настройваме диапазона на скролбара
	scrollbar.min_value = min_y
	scrollbar.max_value = max_y
	scrollbar.page = 200.0  # колко „вижда“ камерата наведнъж (опционално)

	# Свързваме сигналите
	scrollbar.value_changed.connect(_on_scrollbar_value_changed)

func _on_scrollbar_value_changed(value: float) -> void:
	# когато местиш скролбара — мести камерата
	camera.position.y = value
	if "target_y" in camera:
		camera.target_y = value  # ако ползваш твоя smooth логика

func _process(delta):
	# когато камерата се движи с пръсти или мишка — актуализирай скролбара
	scrollbar.value = clamp(camera.position.y, min_y, max_y)
