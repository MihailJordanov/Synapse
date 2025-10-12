# PickedCardShow.gd
class_name PickedCardShow
extends Node2D

@onready var main_panel: Panel = $MainPanel
@onready var texture_rect: TextureRect = $MainPanel/ImagePanel/TextureRect

# connected (targets)
@onready var connected_element_control: Control = $MainPanel/ConnectingPanel/HBoxContainer/ElementControl
@onready var connected_element_color_rect: ColorRect = connected_element_control.get_node("Panel/ColorRect")
@onready var connected_element_texture_rect: TextureRect = connected_element_control.get_node("Panel/TextureRect")

@onready var connected_kind_control: Control = $MainPanel/ConnectingPanel/HBoxContainer/KindControl
@onready var connected_kind_color_rect: ColorRect = connected_kind_control.get_node("Panel/ColorRect")
@onready var connected_kind_texture_rect: TextureRect = connected_kind_control.get_node("Panel/TextureRect")

@onready var connected_attack_style_control: Control = $MainPanel/ConnectingPanel/HBoxContainer/AttackStyleControl
@onready var connected_attack_style_color_rect: ColorRect = connected_attack_style_control.get_node("Panel/ColorRect")
@onready var connected_attack_style_texture_rect: TextureRect = connected_attack_style_control.get_node("Panel/TextureRect")

# self (card types)
@onready var self_element_color_rect: ColorRect = $MainPanel/CardTypesPanel/HBoxContainer/ElementControl/Panel/ColorRect
@onready var self_element_texture_rect: TextureRect = $MainPanel/CardTypesPanel/HBoxContainer/ElementControl/Panel/TextureRect
@onready var self_kind_color_rect: ColorRect = $MainPanel/CardTypesPanel/HBoxContainer/KindControl/Panel/ColorRect
@onready var self_kind_texture_rect: TextureRect = $MainPanel/CardTypesPanel/HBoxContainer/KindControl/Panel/TextureRect
@onready var self_attack_style_color_rect: ColorRect = $MainPanel/CardTypesPanel/HBoxContainer/AttackStyleControl/Panel/ColorRect
@onready var self_attack_style_texture_rect: TextureRect = $MainPanel/CardTypesPanel/HBoxContainer/AttackStyleControl/Panel/TextureRect

func _ready() -> void:
	main_panel.visible = false
	_configure_texture_rect()

func show_card(card: Card) -> void:
	if not is_instance_valid(card):
		clear()
		return

	main_panel.visible = true

	# image
	if is_instance_valid(texture_rect):
		texture_rect.texture = card.card_texture
		await get_tree().process_frame  # позволява на контейнерите да преизчислят размера


	# self (types)
	_apply_element(card.element, self_element_color_rect, self_element_texture_rect)
	_apply_kind(card.kind, self_kind_color_rect, self_kind_texture_rect)
	_apply_style(card.attack_style, self_attack_style_color_rect, self_attack_style_texture_rect)

	# connected (targets) + visibility
	connected_element_control.visible = card.use_element_target
	connected_kind_control.visible = card.use_kind_target
	connected_attack_style_control.visible = card.use_attack_style_target

	if card.use_element_target:
		_apply_element(card.target_element, connected_element_color_rect, connected_element_texture_rect)
	if card.use_kind_target:
		_apply_kind(card.target_kind, connected_kind_color_rect, connected_kind_texture_rect)
	if card.use_attack_style_target:
		_apply_style(card.target_attack_style, connected_attack_style_color_rect, connected_attack_style_texture_rect)

func clear() -> void:
	if is_instance_valid(texture_rect):
		texture_rect.texture = null
	# по желание: изчисти и иконите
	_set_texture(self_element_texture_rect, "")
	_set_texture(self_kind_texture_rect, "")
	_set_texture(self_attack_style_texture_rect, "")
	_set_texture(connected_element_texture_rect, "")
	_set_texture(connected_kind_texture_rect, "")
	_set_texture(connected_attack_style_texture_rect, "")

	connected_element_control.visible = false
	connected_kind_control.visible = false
	connected_attack_style_control.visible = false
	main_panel.visible = false

# --- helpers ---
func _apply_element(el: int, color_rect: ColorRect, tex_rect: TextureRect) -> void:
	if Card.ELEMENT_DISPLAY.has(el):
		var d = Card.ELEMENT_DISPLAY[el]
		if is_instance_valid(color_rect): color_rect.color = d["color"]
		_set_texture(tex_rect, d["icon"])

func _apply_kind(k: int, color_rect: ColorRect, tex_rect: TextureRect) -> void:
	if Card.KIND_DISPLAY.has(k):
		var d = Card.KIND_DISPLAY[k]
		if is_instance_valid(color_rect): color_rect.color = d["color"]
		_set_texture(tex_rect, d["icon"])

func _apply_style(s: int, color_rect: ColorRect, tex_rect: TextureRect) -> void:
	if Card.STYLE_DISPLAY.has(s):
		var d = Card.STYLE_DISPLAY[s]
		if is_instance_valid(color_rect): color_rect.color = d["color"]
		_set_texture(tex_rect, d["icon"])

func _set_texture(tex_rect: TextureRect, path: String) -> void:
	if not is_instance_valid(tex_rect):
		return
	if path.is_empty():
		tex_rect.texture = null
		return
	var tex: Texture2D = load(path)
	tex_rect.texture = tex
	
	
func _configure_texture_rect() -> void:
	if not is_instance_valid(texture_rect):
		return

	# 1) Нека TextureRect запълва родителя си
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# 2) Да пази пропорциите и да показва цялата текстура (letterbox, без кроп)
	#    Godot 4:
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# (в Godot 3 е същото enum име)

	# 3) По желание – по-качествен филтър при скалиране
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
