class_name UpgradesLevels
extends Panel

@onready var upgrade_panel: UpgradePanel = $".."

@onready var name_rich_text_label: RichTextLabel = $NameRichTextLabel
@onready var info_rich_text_label: RichTextLabel = $InfoRichTextLabel
@onready var curlevel_rich_text_label: RichTextLabel = $CurlevelRichTextLabel
@onready var price_text_label: RichTextLabel = $UpgradeButton/PriceTextLabel
@onready var texture_panel: Panel = $TexturePanel

var cur_level: int = 0

var upgrade_data := {
	UpgradePanel.UpgradeType.DECK_LEVEL: [
		{"name": "Deck Lv.1", "info": "Allows you to have 20 cards in your deck.", "price": 5,   "icon": "res://UI/upgrades/deck_1.png"},
		{"name": "Deck Lv.2", "info": "Allows you to have 25 cards in your deck.", "price": 10,  "icon": "res://UI/upgrades/deck_2.png"},
		{"name": "Deck Lv.3", "info": "Allows you to have 30 cards in your deck.", "price": 25,  "icon": "res://UI/upgrades/deck_3.png"},
		{"name": "Deck Lv.4", "info": "Allows you to have 35 cards in your deck.", "price": 50,  "icon": "res://UI/upgrades/deck_4.png"},
		{"name": "Deck Lv.5", "info": "Allows you to have 40 cards in your deck.", "price": 100, "icon": "res://UI/upgrades/deck_5.png"}
	],
	UpgradePanel.UpgradeType.PLAY_POINTS_TO_REACH: [
		{"name": "Victory Ease Lv.1", "info": "One less point required to reach the player's minimum victory points.", "price": 25,  "icon": "res://UI/upgrades/victory_ease_1.png"},
		{"name": "Victory Ease Lv.2", "info": "Two less points required to reach the player's minimum victory points.", "price": 50,  "icon": "res://UI/upgrades/victory_ease_2.png"},
		{"name": "Victory Ease Lv.3", "info": "Three less points required to reach the player's minimum victory points.", "price": 100, "icon": "res://UI/upgrades/victory_ease_3.png"},
		{"name": "Victory Ease Lv.4", "info": "Four less points required to reach the player's minimum victory points.", "price": 200, "icon": "res://UI/upgrades/victory_ease_4.png"},
		{"name": "Victory Ease Lv.5", "info": "Five less points required to reach the player's minimum victory points.", "price": 300, "icon": "res://UI/upgrades/victory_ease_5.png"}
	],
	UpgradePanel.UpgradeType.ENEMY_POINTS_TO_REACH: [
		{"name": "Enemy Challenge Lv.1", "info": "Enemy needs one more point to reach their victory points goal.", "price": 30,  "icon": "res://UI/upgrades/enemy_challenge_1.png"},
		{"name": "Enemy Challenge Lv.2", "info": "Enemy needs two more points to reach their victory points goal.", "price": 60,  "icon": "res://UI/upgrades/enemy_challenge_2.png"},
		{"name": "Enemy Challenge Lv.3", "info": "Enemy needs three more points to reach their victory points goal.", "price": 120, "icon": "res://UI/upgrades/enemy_challenge_3.png"},
		{"name": "Enemy Challenge Lv.4", "info": "Enemy needs four more points to reach their victory points goal.", "price": 240, "icon": "res://UI/upgrades/enemy_challenge_4.png"},
		{"name": "Enemy Challenge Lv.5", "info": "Enemy needs five more points to reach their victory points goal.", "price": 360, "icon": "res://UI/upgrades/enemy_challenge_5.png"}
	]
}

func _ready():
	update_upgrade_display()

func update_upgrade_display():
	var type = upgrade_panel.upgrade_type
	var data = upgrade_data[type]

	var clamped_level = clamp(cur_level, 0, upgrade_panel.max_level - 1)
	var info = data[clamped_level]

	name_rich_text_label.text = "[center]" + info["name"] + "[/center]"
	info_rich_text_label.text = info["info"]
	curlevel_rich_text_label.text = "Lv: %d" % [cur_level + 1]
	price_text_label.text = str(info["price"]) + " coins"

	# --- Set icon on TextureRect ---
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
	# Взима или създава TextureRect вътре в texture_panel, с anchors = full rect.
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

func upgrade():
	if cur_level >= upgrade_panel.max_level - 1:
		print("Already at max level!")
		return false
	cur_level += 1
	update_upgrade_display()
	return true

func set_level(level: int):
	cur_level = clamp(level, 0, upgrade_panel.max_level - 1)
	update_upgrade_display()
