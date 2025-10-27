class_name LevelButton
extends Button

@export_category("About Level")
@export var level_name : String  = ""
@export var make_cooler : bool = false
@export var config : LevelConfig

@export_category("About Button")
@export var is_unlock : bool = false
@export var is_clear : bool = false


@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var enemy_texture_rect: TextureRect = $EnemyTextureRect
@onready var mystery_texture_rect: TextureRect = $MysteryTextureRect
@onready var finished_texture_rect: TextureRect = $FinishedTextureRect



func _ready() -> void:

	_update_textures()
	# Свързваме сигналите за мишката
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("mouse_exited", Callable(self, "_on_mouse_exited"))
	

func _on_mouse_entered() -> void:
	animation_player.stop()


func _on_mouse_exited() -> void:
	if not is_clear and is_unlock:
		animation_player.play("default")

func _update_textures() -> void:
	if is_unlock:
		enemy_texture_rect.visible = true
		mystery_texture_rect.visible = false
	else:
		enemy_texture_rect.visible = false
		mystery_texture_rect.visible = true
		finished_texture_rect.visible = false
		
	if is_clear and is_unlock:
		enemy_texture_rect.visible = true
		finished_texture_rect.visible = true
	else:
		finished_texture_rect.visible = false
		
	if config:
		enemy_texture_rect.texture = config.enemy_texture
	
	if not is_clear and is_unlock:
		animation_player.play("default")
