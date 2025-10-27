extends Resource
class_name LevelConfig

@export_category("Enemy / AI")
@export var enemy_texture : Texture
@export var max_hand : int = 5
@export var think_time_ms : int = 500
@export var deck : AIDeck

@export_category("Game points")
@export var player_points_to_reach : int = 10
@export var enemy_points_to_reach  : int = 10

@export_category("Coefficient")
@export var coefficient_when_destroy_your_card  : float = 1.0
@export var coefficient_when_destroy_enemy_card : float = 1.0
@export var points_ai_get_when_slots_full       : float = 0.0
@export var points_player_get_when_slots_full   : float = 0.0

@export_category("On Win")
@export var cur_level : String
@export var levels_to_unlock_on_win : Array[String] = []
@export var cards_to_unlock_on_win  : Array[int] = []
