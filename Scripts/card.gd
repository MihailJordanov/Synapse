class_name Card
extends Node2D

enum CardColor { BLUE, RED, GREEN, YELLOW }
enum CardKind  { HERO, ORG, ARCHER }
enum AttackStyle { MELEE, RANGE, TELEPATH }

@export var color: CardColor = CardColor.BLUE : set = set_color
@export var kind: CardKind = CardKind.HERO : set = set_kind
@export var attack_style: AttackStyle = AttackStyle.MELEE : set = set_attack_style

@export_category("Attacking On")
@export var use_color_target := false : set = set_use_color_target
@export var target_color: CardColor = CardColor.RED : set = set_target_color

@export var use_kind_target := false : set = set_use_kind_target
@export var target_kind: CardKind = CardKind.ORG : set = set_target_kind

@export var use_attack_style_target := false : set = set_use_attack_style_target
@export var target_attack_style: AttackStyle = AttackStyle.RANGE : set = set_target_attack_style

@export_category("Card Image")
@export var card_texture: Texture2D : set = set_card_texture

# --- UI refs ---
@onready var texture_rect: TextureRect = $MainPanel/ImagePanel/TextureRect
@onready var self_kind_panel: Panel = $MainPanel/KindPanel
@onready var self_kind_text_label: RichTextLabel = $MainPanel/KindPanel/RichTextLabel
@onready var self_attack_style_panel: Panel = $MainPanel/AttackStylePanel
@onready var self_attack_style_text_label: RichTextLabel = $MainPanel/AttackStylePanel/RichTextLabel
@onready var self_color_panel: Panel = $MainPanel/ColorPanel

@onready var attack_color_rect: ColorRect = $MainPanel/AttackingPanel/HBoxContainer/ColorControl/Panel/ColorRect
@onready var attack_kind_color_rect: ColorRect = $MainPanel/AttackingPanel/HBoxContainer/KindControl/Panel/ColorRect
@onready var attack_kind_text_label: RichTextLabel = $MainPanel/AttackingPanel/HBoxContainer/KindControl/Panel/RichTextLabel
@onready var attack_style_color_rect: ColorRect = $MainPanel/AttackingPanel/HBoxContainer/AttackStyleControl/Panel/ColorRect
@onready var attack_style_text_label: RichTextLabel = $MainPanel/AttackingPanel/HBoxContainer/AttackStyleControl/Panel/RichTextLabel
@onready var color_control: Control = $MainPanel/AttackingPanel/HBoxContainer/ColorControl
@onready var kind_control: Control  = $MainPanel/AttackingPanel/HBoxContainer/KindControl
@onready var style_control: Control = $MainPanel/AttackingPanel/HBoxContainer/AttackStyleControl

const KIND_DISPLAY := {
	CardKind.HERO:   {"name":"HERO",   "color": Color("#9c7e00")},
	CardKind.ORG:    {"name":"ORG",    "color": Color("#84994F")},
	CardKind.ARCHER: {"name":"ARCHER", "color": Color("#640D5F")},
}
const STYLE_DISPLAY := {
	AttackStyle.MELEE:    {"name":"MELEE",    "color": Color("#483900")},
	AttackStyle.RANGE:    {"name":"RANGE",    "color": Color("#77BEF0")},
	AttackStyle.TELEPATH: {"name":"TELEPATH", "color": Color("#3D74B6")},
}
const CARD_COLORS := {
	CardColor.BLUE:   Color("#89CFF0"),
	CardColor.RED:    Color("#F54927"),
	CardColor.GREEN:  Color("#84994F"),
	CardColor.YELLOW: Color("#F8FAB4"),
}

# --- Константа за целеви размер на картинката ---
const SPRITE_SIZE := Vector2(88, 88)

# --- Сигнали ---
signal hovered
signal hovered_off

func _ready() -> void:
	#All cards must be a child of CardManager or this will error
	get_parent().connect_card_signals(self)
	
	# В този момент @onready нодовете са валидни → приложи текущите стойности
	if is_instance_valid(texture_rect) and card_texture:
		texture_rect.texture = card_texture
	_update_kind_ui()
	_update_style_ui()
	_update_color_ui()
	_update_attack_targets_ui()

# --- setters ---
func set_card_texture(value: Texture2D) -> void:
	card_texture = value
	if is_instance_valid(texture_rect):
		texture_rect.texture = card_texture


func set_kind(v: CardKind) -> void:
	kind = v
	_update_kind_ui()

func set_attack_style(v: AttackStyle) -> void:
	attack_style = v
	_update_style_ui()

func set_color(v: CardColor) -> void:
	color = v
	_update_color_ui()

func set_use_color_target(v: bool) -> void:
	use_color_target = v
	_update_attack_targets_ui()

func set_target_color(v: CardColor) -> void:
	target_color = v
	_update_attack_targets_ui()

func set_use_kind_target(v: bool) -> void:
	use_kind_target = v
	_update_attack_targets_ui()

func set_target_kind(v: CardKind) -> void:
	target_kind = v
	_update_attack_targets_ui()

func set_use_attack_style_target(v: bool) -> void:
	use_attack_style_target = v
	_update_attack_targets_ui()

func set_target_attack_style(v: AttackStyle) -> void:
	target_attack_style = v
	_update_attack_targets_ui()

# --- UI updates ---
func _update_kind_ui() -> void:
	if not is_instance_valid(self_kind_text_label) or not is_instance_valid(self_kind_panel):
		return
	if KIND_DISPLAY.has(kind):
		self_kind_text_label.text = KIND_DISPLAY[kind]["name"]
		_set_panel_bg(self_kind_panel, KIND_DISPLAY[kind]["color"])

func _update_style_ui() -> void:
	if not is_instance_valid(self_attack_style_text_label) or not is_instance_valid(self_attack_style_panel):
		return
	if STYLE_DISPLAY.has(attack_style):
		self_attack_style_text_label.text = STYLE_DISPLAY[attack_style]["name"]
		_set_panel_bg(self_attack_style_panel, STYLE_DISPLAY[attack_style]["color"])

func _update_color_ui() -> void:
	if not is_instance_valid(self_color_panel):
		return
	if CARD_COLORS.has(color):
		_set_panel_bg(self_color_panel, CARD_COLORS[color])

func _update_attack_targets_ui() -> void:
	if not (is_instance_valid(color_control) and is_instance_valid(kind_control) and is_instance_valid(style_control)):
		return

	color_control.visible = use_color_target
	kind_control.visible  = use_kind_target
	style_control.visible = use_attack_style_target

	if use_color_target and CARD_COLORS.has(target_color):
		attack_color_rect.color = CARD_COLORS[target_color]

	if use_kind_target and KIND_DISPLAY.has(target_kind):
		attack_kind_text_label.text = str(KIND_DISPLAY[target_kind]["name"]).substr(0,1).to_upper()
		attack_kind_color_rect.color = KIND_DISPLAY[target_kind]["color"]

	if use_attack_style_target and STYLE_DISPLAY.has(target_attack_style):
		attack_style_text_label.text = str(STYLE_DISPLAY[target_attack_style]["name"]).substr(0,1).to_upper()
		attack_style_color_rect.color = STYLE_DISPLAY[target_attack_style]["color"]

# --- helper ---
func _set_panel_bg(panel: Panel, color: Color) -> void:
	if not is_instance_valid(panel):
		return
	var sb := panel.get_theme_stylebox("panel")
	if sb and sb is StyleBoxFlat:
		var copy := (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
		copy.bg_color = color
		panel.add_theme_stylebox_override("panel", copy)
	else:
		var new_sb := StyleBoxFlat.new()
		new_sb.bg_color = color
		new_sb.corner_radius_top_left = 8
		new_sb.corner_radius_top_right = 8
		new_sb.corner_radius_bottom_left = 8
		new_sb.corner_radius_bottom_right = 8
		panel.add_theme_stylebox_override("panel", new_sb)
		





func _on_area_2d_mouse_exited() -> void:
	emit_signal("hovered_off", self)


func _on_area_2d_mouse_entered() -> void:
	emit_signal("hovered", self)
