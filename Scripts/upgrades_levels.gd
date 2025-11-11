class_name UpgradesLevels
extends Panel

@onready var upgrade_panel: UpgradePanel = $".." # само за типа и max_level (не ползваме cur_level от него)

@onready var name_rich_text_label: RichTextLabel = $NameRichTextLabel
@onready var info_rich_text_label: RichTextLabel = $InfoRichTextLabel
@onready var curlevel_rich_text_label: RichTextLabel = $CurlevelRichTextLabel
@onready var price_text_label: RichTextLabel = $UpgradeButton/PriceTextLabel
@onready var texture_panel: Panel = $TexturePanel

var cur_level: int = 0  

var upgrade_data: Dictionary =  {
	UpgradePanel.UpgradeType.DECK_LEVEL: [
		{"name": "Deck Size", "info": "Raises your deck size limit.", "price": 5,   "icon": "res://Images/Shop/Upgrades/deck_upgrade_icon_1.png"},
		{"name": "Deck Size", "info": "Raises your deck size limit.", "price": 10,  "icon": "res://Images/Shop/Upgrades/deck_upgrade_icon_1.png"},
		{"name": "Deck Size", "info": "Raises your deck size limit.", "price": 25,  "icon": "res://Images/Shop/Upgrades/deck_upgrade_icon_1.png"},
		{"name": "Deck Size", "info": "Raises your deck size limit.", "price": 50,  "icon": "res://Images/Shop/Upgrades/deck_upgrade_icon_1.png"},
		{"name": "Deck Size", "info": "Raises your deck size limit.", "price": 100, "icon": "res://Images/Shop/Upgrades/deck_upgrade_icon_1.png"},
		{"name": "Deck Size", "info": "Raises your deck size limit.", "price": 300, "icon": "res://Images/Shop/Upgrades/deck_upgrade_icon_1.png"},
		{"name": "Deck Size", "info": "Raises your deck size limit.", "price": 500, "icon": "res://Images/Shop/Upgrades/deck_upgrade_icon_1.png"},
		{"name": "Deck Size", "info": "Raises your deck size limit.", "price": 1000, "icon": "res://Images/Shop/Upgrades/deck_upgrade_icon_1.png"}
	],
	UpgradePanel.UpgradeType.PLAY_POINTS_TO_REACH: [
		{"name": "Victory Ease", "info": "Lowers the victory point requirement (min 3)", "price": 25,  "icon": "res://Images/Shop/Upgrades/player_points_to_reach_upgrade_icon_2.png"},
		{"name": "Victory Ease", "info": "Lowers the victory point requirement (min 3)", "price": 50,  "icon": "res://Images/Shop/Upgrades/player_points_to_reach_upgrade_icon_2.png"},
		{"name": "Victory Ease", "info": "Lowers the victory point requirement (min 3)", "price": 100, "icon": "res://Images/Shop/Upgrades/player_points_to_reach_upgrade_icon_2.png"},
		{"name": "Victory Ease", "info": "Lowers the victory point requirement (min 3)", "price": 200, "icon": "res://Images/Shop/Upgrades/player_points_to_reach_upgrade_icon_2.png"},
		{"name": "Victory Ease", "info": "Lowers the victory point requirement (min 3)", "price": 300, "icon": "res://Images/Shop/Upgrades/player_points_to_reach_upgrade_icon_2.png"}
	],
	UpgradePanel.UpgradeType.ENEMY_POINTS_TO_REACH: [
		{"name": "Enemy Challenge", "info": "Raises enemy victory point requirement.", "price": 30,  "icon": "res://Images/Shop/Upgrades/enemy_points_to_reach_upgrade_icon_2.png"},
		{"name": "Enemy Challenge", "info": "Raises enemy victory point requirement.", "price": 60,  "icon": "res://Images/Shop/Upgrades/enemy_points_to_reach_upgrade_icon_2.png"},
		{"name": "Enemy Challenge", "info": "Raises enemy victory point requirement.", "price": 120, "icon": "res://Images/Shop/Upgrades/enemy_points_to_reach_upgrade_icon_2.png"},
		{"name": "Enemy Challenge", "info": "Raises enemy victory point requirement.", "price": 240, "icon": "res://Images/Shop/Upgrades/enemy_points_to_reach_upgrade_icon_2.png"},
		{"name": "Enemy Challenge", "info": "Raises enemy victory point requirement.", "price": 360, "icon": "res://Images/Shop/Upgrades/enemy_points_to_reach_upgrade_icon_2.png"}
	]
}

func _ready():
	cur_level = _get_level_for_type()
	update_upgrade_display()

	if not ItemManager.value_changed.is_connected(_on_item_value_changed):
		ItemManager.value_changed.connect(_on_item_value_changed)

func _on_item_value_changed(key: String, value: int) -> void:
	match upgrade_panel.upgrade_type:
		UpgradePanel.UpgradeType.DECK_LEVEL:
			if key == ItemManager.KEY_DECK_LEVEL:
				cur_level = value
				update_upgrade_display()
		UpgradePanel.UpgradeType.PLAY_POINTS_TO_REACH:
			if key == ItemManager.KEY_PLAYER_POINTS_LEVEL:
				cur_level = value
				update_upgrade_display()
		UpgradePanel.UpgradeType.ENEMY_POINTS_TO_REACH:
			if key == ItemManager.KEY_ENEMY_POINTS_LEVEL:
				cur_level = value
				update_upgrade_display()

func _get_level_for_type() -> int:
	match upgrade_panel.upgrade_type:
		UpgradePanel.UpgradeType.DECK_LEVEL:
			return ItemManager.get_deck_level()
		UpgradePanel.UpgradeType.PLAY_POINTS_TO_REACH:
			return ItemManager.get_player_points_level()
		UpgradePanel.UpgradeType.ENEMY_POINTS_TO_REACH:
			return ItemManager.get_enemy_points_level()
	return 0

func update_upgrade_display():
	var type: int = upgrade_panel.upgrade_type
	var data = upgrade_data.get(type, []) 

	if data.is_empty():
		return

	var clamped_level: int = clampi(cur_level, 0, upgrade_panel.max_level - 1)
	var info: Dictionary = data[clamped_level] as Dictionary

	name_rich_text_label.text = "[center][b][color=#FFD700]%s[/color][/b][/center]" % info["name"] 
	info_rich_text_label.text = info["info"] 
	curlevel_rich_text_label.text = "[font_size=5][color=#FFD700]Lv: [font_size=9][b]%d" % [cur_level] 
	price_text_label.text = str(info["price"]) + " coins"

	if cur_level >= upgrade_panel.max_level - 1:
		price_text_label.text = "[b][color=#00FF00]Max. Level[/color][/b]"
	else:
		price_text_label.text = "[b]%d[/b] coins" % int(info.get("price", 0))

	var icon_path: String = info.get("icon", "")
	var tex_rect := _ensure_texture_rect()
	if icon_path != "":
		var tex: Texture2D = load(icon_path)
		if tex:
			tex_rect.texture = tex
			tex_rect.visible = true
		else:
			push_warning("Icon not found: %s" % icon_path)
			tex_rect.visible = false
	else:
		tex_rect.visible = false


func _ensure_texture_rect() -> TextureRect:
	var node := texture_panel.get_node_or_null("TextureRect")
	if node and node is TextureRect:
		return node
	var trr := TextureRect.new()
	trr.name = "TextureRect"
	trr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	trr.anchor_left = 0.0
	trr.anchor_top = 0.0
	trr.anchor_right = 1.0
	trr.anchor_bottom = 1.0
	trr.offset_left = 0
	trr.offset_top = 0
	trr.offset_right = 0
	trr.offset_bottom = 0
	texture_panel.add_child(trr)
	return trr

func upgrade() -> bool:
	cur_level = _get_level_for_type()
	update_upgrade_display()
	return true

func set_level(level: int):
	cur_level = clampi(level, 0, upgrade_panel.max_level - 1)
	update_upgrade_display()
