class_name LevelButton
extends Button

@export_category("About Level")
@export var level_name : String  = ""
@export var make_cooler : bool = false
@export var config : LevelConfig

@export_category("About Button")
@export var is_unlock : bool = false
@export var is_clear : bool = false

@export_category("Camera zoom")
@onready var cam: Camera2D = get_viewport().get_camera_2d()
@export var base_scale: float = 1.0         
@export var mode_constant_screen_size := false 
@export var offset_strength: float = 0.9
@export var max_up_offset: float = -300
@export var max_down_offset: float = -100


@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var enemy_texture_rect: TextureRect = $EnemyTextureRect
@onready var mystery_texture_rect: TextureRect = $MysteryTextureRect
@onready var finished_texture_rect: TextureRect = $FinishedTextureRect
@onready var waiting_for_beating_texture_rect: TextureRect = $WaitingForBeatingTextureRect



func _ready() -> void:
	waiting_for_beating_texture_rect.set_anchors_preset(Control.PRESET_CENTER)
	waiting_for_beating_texture_rect.pivot_offset = waiting_for_beating_texture_rect.size * 0.5

	_update_textures()
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("mouse_exited", Callable(self, "_on_mouse_exited"))
	


func _process(_dt: float) -> void:
	if cam and is_unlock and not is_clear:
		var z := cam.zoom.x
		var factor := z if mode_constant_screen_size else (1.0 / z)
		waiting_for_beating_texture_rect.scale = Vector2.ONE * (base_scale * factor)

		var h := waiting_for_beating_texture_rect.size.y * (base_scale * factor)
		var new_y := -h * offset_strength

		var down_offset := max_down_offset
		if z > 2 and z <= 3:
			max_down_offset = -80
			max_up_offset = -300
		elif z > 1.1 and z < 0.7:
			max_down_offset = -100
			max_up_offset = -300
		elif z > 0.7 and z < 1.1:
			max_down_offset = -130
			max_up_offset = -300
		elif z >= 0.3 and z < 0.5:
			max_down_offset = -100
			max_up_offset = -240
		else:
			max_down_offset = -100
			max_up_offset = -300
			
		new_y = clamp(new_y, max_up_offset, down_offset)
		waiting_for_beating_texture_rect.position.y = lerp(waiting_for_beating_texture_rect.position.y, new_y, 0.15)



		
		  


func _on_mouse_entered() -> void:
	animation_player.stop()


func _on_mouse_exited() -> void:
	if not is_clear and is_unlock:
		animation_player.play("default")

func _update_textures() -> void:
	if is_unlock:
		enemy_texture_rect.visible = true
		mystery_texture_rect.visible = false
		waiting_for_beating_texture_rect.visible = true
	else:
		enemy_texture_rect.visible = false
		mystery_texture_rect.visible = true
		finished_texture_rect.visible = false
		
	if is_clear and is_unlock:
		enemy_texture_rect.visible = true
		finished_texture_rect.visible = true
		waiting_for_beating_texture_rect.visible = false
	else:
		finished_texture_rect.visible = false
		
	if config:
		enemy_texture_rect.texture = config.enemy_texture
	
	if not is_clear and is_unlock:
		animation_player.play("default")
