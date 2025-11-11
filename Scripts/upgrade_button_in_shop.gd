class_name UpgradeButtonInShop
extends Button

@onready var panel: UpgradesLevels = $".."
@onready var animation_player: AnimationPlayer = $"../../AnimationPlayer"

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	if panel == null or panel.upgrade_panel == null:
		push_warning("Upgrade button: missing panel or upgrade_panel")
		return
	
	if panel.cur_level >= panel.upgrade_panel.max_level - 1:
		_play_anim_if_exists("max_level")
		return

	var price: int = _get_current_price()
	if price < 0:
		push_warning("Upgrade button: price not found for current level")
		return

	var coins: int = ItemManager.get_money()
	if coins < price:
		_play_anim_if_exists("no_money")
		return

	ItemManager.remove_money(price)

	var upgraded: bool = bool(panel.upgrade())
	if not upgraded:
		ItemManager.add_money(price) 
		_play_anim_if_exists("no_money")
		return

	_apply_itemmanager_level_inc()

	_play_anim_if_exists("upgrade")


# ---------- Helpers ----------

func _get_current_price() -> int:
	var type: int = panel.upgrade_panel.upgrade_type
	var level: int = clampi(panel.cur_level, 0, panel.upgrade_panel.max_level - 1)

	if not panel.upgrade_data.has(type):
		return -1

	var data: Array = panel.upgrade_data[type]
	if level < 0 or level >= data.size():
		return -1

	return int(data[level].get("price", -1))



func _apply_itemmanager_level_inc() -> void:
	var type: int = panel.upgrade_panel.upgrade_type
	match type:
		UpgradePanel.UpgradeType.DECK_LEVEL:
			ItemManager.add_deck_level(1)
		UpgradePanel.UpgradeType.PLAY_POINTS_TO_REACH:
			ItemManager.add_player_points_level(1)
		UpgradePanel.UpgradeType.ENEMY_POINTS_TO_REACH:
			ItemManager.add_enemy_points_level(1)
		_:
			pass

func _play_anim_if_exists(_name: String) -> void:
	if is_instance_valid(animation_player) and animation_player.has_animation(_name):
		animation_player.play(_name)
