extends Node
class_name LevelRoot

@onready var gs: GameStateRandom = $"../GameStateRandom"
@onready var gm: GameMaster     = $"../GameMaster"

func _ready() -> void:
	var cfg := LevelRuntime.config
	if cfg:
		_apply_config(cfg)
	else:
		push_warning("LevelRuntime.config is null – стартирано ниво без конфигурация.")

func _apply_config(cfg: LevelConfig) -> void:
	# --- GameStateRandom ---
	gs.enemy_texture = cfg.enemy_texture
	gs.max_hand      = cfg.max_hand
	gs.think_time_ms = cfg.think_time_ms
	gs.deck          = cfg.deck
	gs._name         = cfg.name

	# --- GameMaster ---
	gm.player_points_to_reach = cfg.player_points_to_reach
	gm.enemy_points_to_reach  = cfg.enemy_points_to_reach

	gm.coefficient_when_destroy_your_card  = cfg.coefficient_when_destroy_your_card
	gm.coefficient_when_destroy_enemy_card = cfg.coefficient_when_destroy_enemy_card
	gm.points_ai_get_when_slots_full       = cfg.points_ai_get_when_slots_full
	gm.points_player_get_when_slots_full   = cfg.points_player_get_when_slots_full

	gm.cur_level                = cfg.cur_level
	gm.levels_to_unlock_on_win  = cfg.levels_to_unlock_on_win
	gm.levels_to_visible_on_win = cfg.levels_to_visible_on_win
	gm.cards_to_unlock_on_win   = cfg.cards_to_unlock_on_win
	gm.coins_min                = cfg.coins_min
	gm.coins_max                = cfg.coins_max
