class_name ItemShowSystem
extends Node

@onready var levels_info_text_label: RichTextLabel = $"../CanvasLayer/UpPanel/LevelsInfo/LevelsInfoTextLabel"
@onready var unlock_info_text_label: RichTextLabel = $"../CanvasLayer/UpPanel/LevelsUnlockInfo/UnlockInfoTextLabel"
@onready var coin_info_text_label: RichTextLabel = $"../CanvasLayer/UpPanel/CoinsInfo/CoinInfoTextLabel"
@onready var map: MapLevelController = $".."


func _ready() -> void:
	_update_UI()
	
func _update_UI() -> void:
	var max_level: int = map.buttons.size()
	var cleared_levels: int = LevelManager.get_cleared().size() - 1 # Махаме туториала
	var unlocked_levels: int = LevelManager.get_unlocked().size()
	var coins: int = ItemManager.get_money()

	levels_info_text_label.text = "[outline_size=3][outline_color=#1a0e00][b][color=#3fa34d]%d / %d[/color][/b]" % [cleared_levels, max_level]
	unlock_info_text_label.text = "[outline_size=3][outline_color=#1a0e00][b][color=#FEF2F2]x%d[/color][/b]" % [unlocked_levels - cleared_levels]
	coin_info_text_label.text = "[outline_size=3][outline_color=#1a0e00][b][color=#d4af37]$%d[/color][/b]" % [coins]
