@tool
extends Node2D

@export var world_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(700, 600)) : set = set_world_bounds
@export var color: Color = Color(0, 1, 0, 0.8) : set = set_color
@export var line_width: float = 2.0 : set = set_line_width
@export var draw_in_game: bool = true

func _ready():
	# Прерисува в редактора
	if Engine.is_editor_hint():
		queue_redraw()

func _process(_delta):
	# В редактора прерисува постоянно, в играта - ако draw_in_game е true
	if Engine.is_editor_hint() or draw_in_game:
		queue_redraw()

func _draw():
	draw_rect(world_bounds, color, false, line_width)

func set_world_bounds(v: Rect2):
	world_bounds = v
	queue_redraw()

func set_color(v: Color):
	color = v
	queue_redraw()

func set_line_width(v: float):
	line_width = v
	queue_redraw()
