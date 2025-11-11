# Shop.gd
class_name Shop
extends Node2D

@export_file("*.tscn") var map: String = "res://Scenes/Scenes_In_Game/map.tscn"



@onready var coin_info_text_label: RichTextLabel = $CanvasLayer/UpPanel/CoinsInfo/CoinInfoTextLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	animation_player.play("openScene")
	coin_info_text_label.bbcode_enabled = true
	_update_coins_label(ItemManager.get_money())
	if not ItemManager.value_changed.is_connected(_on_item_value_changed):
		ItemManager.value_changed.connect(_on_item_value_changed)

func _on_item_value_changed(key: String, value: int) -> void:
	if key == ItemManager.KEY_COINS:
		_update_coins_label(value)

func _update_coins_label(coins: int) -> void:
	coin_info_text_label.text = "[outline_size=3][outline_color=#1a0e00][b][color=#d4af37]$%d[/color][/b]" % [coins]


func _on_go_to_shop_button_down() -> void:
	animation_player.play("closeScene")
	await animation_player.animation_finished
	get_tree().change_scene_to_file(map)
