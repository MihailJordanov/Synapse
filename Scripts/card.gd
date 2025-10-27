class_name Card
extends Node2D


const destroy_fire_anim : String = "destroyed_fire"
const destroy_water_anim : String = "destroyed_water"
const destroy_air_anim : String = "destroyed_air"
const destroy_lightning_anim : String = "destroyed_lightning"

var _is_destroying: bool = false
var is_locked: bool = false
signal destroyed(card: Card)

# --- Enums ---
enum Element     { AIR, WATER, FIRE, LIGHTNING }
enum CardKind    { HERO, ORC, WIZARD, SKELETON }
enum AttackStyle { MELEE, RANGE, TELEPATH }
enum OwnerType   { PLAYER, AI }

# --- Exports ---
@export var id : int = 0

@export_category("Ownership")
@export var card_owner: OwnerType = OwnerType.PLAYER : set = set_card_owner

@export_category("Self")
@export var use_self_element: bool = true : set = set_use_self_element
@export var element: Element = Element.AIR : set = set_element

@export var use_self_kind: bool = true : set = set_use_self_kind
@export var kind: CardKind = CardKind.HERO : set = set_kind

@export var use_self_attack_style: bool = true : set = set_use_self_attack_style
@export var attack_style: AttackStyle = AttackStyle.MELEE : set = set_attack_style

@export_category("Attacking On")
@export var use_element_target := false : set = set_use_element_target
@export var target_element: Element = Element.WATER : set = set_target_element

@export var use_kind_target := false : set = set_use_kind_target
@export var target_kind: CardKind = CardKind.ORC : set = set_target_kind

@export var use_attack_style_target := false : set = set_use_attack_style_target
@export var target_attack_style: AttackStyle = AttackStyle.RANGE : set = set_target_attack_style

@export_category("Card Image")
@export var card_texture: Texture2D : set = set_card_texture


# --- UI refs ---
@onready var card_texture_rect: TextureRect = $MainPanel/ImagePanel/TextureRect
@onready var back_card: Panel = $BackCard

# Self Card Type (добавяме и Control контейнерите)
@onready var self_element_control: Control = $MainPanel/CardTypesPanel/HBoxContainer/ElementControl
@onready var seld_card_type_element_color_rect: ColorRect   = $MainPanel/CardTypesPanel/HBoxContainer/ElementControl/Panel/ColorRect
@onready var seld_card_type_element_texture_rect: TextureRect = $MainPanel/CardTypesPanel/HBoxContainer/ElementControl/Panel/TextureRect

@onready var self_kind_control: Control = $MainPanel/CardTypesPanel/HBoxContainer/KindControl
@onready var seld_card_type_kind_color_rect: ColorRect      = $MainPanel/CardTypesPanel/HBoxContainer/KindControl/Panel/ColorRect
@onready var seld_card_type_kind_texture_rect: TextureRect  = $MainPanel/CardTypesPanel/HBoxContainer/KindControl/Panel/TextureRect

@onready var self_attack_style_control: Control = $MainPanel/CardTypesPanel/HBoxContainer/AttackStyleControl
@onready var seld_card_type_attack_style_color_rect: ColorRect  = $MainPanel/CardTypesPanel/HBoxContainer/AttackStyleControl/Panel/ColorRect
@onready var seld_card_type_attack_style_texture_rect: TextureRect = $MainPanel/CardTypesPanel/HBoxContainer/AttackStyleControl/Panel/TextureRect


# Targets / Connecting
@onready var connect_wth_element_color_rect: ColorRect      = $MainPanel/ConnectingPanel/HBoxContainer/ElementControl/Panel/ColorRect
@onready var connect_wth_element_texture_rect: TextureRect  = $MainPanel/ConnectingPanel/HBoxContainer/ElementControl/Panel/TextureRect
@onready var connect_wth_kind_color_rect: ColorRect         = $MainPanel/ConnectingPanel/HBoxContainer/KindControl/Panel/ColorRect
@onready var connect_wth_kind_texture_rect: TextureRect     = $MainPanel/ConnectingPanel/HBoxContainer/KindControl/Panel/TextureRect
@onready var connect_wth_attackStyle_color_rect: ColorRect  = $MainPanel/ConnectingPanel/HBoxContainer/AttackStyleControl/Panel/ColorRect
@onready var connect_wth_attack_style_texture_rect: TextureRect = $MainPanel/ConnectingPanel/HBoxContainer/AttackStyleControl/Panel/TextureRect

@onready var connect_wth_element_control: Control = $MainPanel/ConnectingPanel/HBoxContainer/ElementControl
@onready var connect_wth_kind_control: Control    = $MainPanel/ConnectingPanel/HBoxContainer/KindControl
@onready var connect_wth_attack_style_control: Control = $MainPanel/ConnectingPanel/HBoxContainer/AttackStyleControl
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# --- Display dictionaries ---
const KIND_DISPLAY := {
	CardKind.HERO:     {"icon": "res://Images/Type_Icons/Kind/knight_icon.png",   "color": Color("#9c7e00")},
	CardKind.ORC:      {"icon": "res://Images/Type_Icons/Kind/orc_icon.png",      "color": Color("#84994F")},
	CardKind.WIZARD:   {"icon": "res://Images/Type_Icons/Kind/wizard_icon.png",   "color": Color("#640D5F")},
	CardKind.SKELETON: {"icon": "res://Images/Type_Icons/Kind/skeleton_icon.png", "color": Color("#f6f6f6")},
}

const STYLE_DISPLAY := {
	AttackStyle.MELEE:    {"icon": "res://Images/Type_Icons/Attack_Type/mele_icon.png",     "color": Color("#483900")},
	AttackStyle.RANGE:    {"icon": "res://Images/Type_Icons/Attack_Type/range_icon.png",    "color": Color("#77BEF0")},
	AttackStyle.TELEPATH: {"icon": "res://Images/Type_Icons/Attack_Type/telepathy_icon.png","color": Color("#FF00FF")},
}

const ELEMENT_DISPLAY := {
	Element.WATER:     {"icon": "res://Images/Type_Icons/Element/water_icon.png",     "color": Color("#3A86FF")},
	Element.FIRE:      {"icon": "res://Images/Type_Icons/Element/fire_icon.png",      "color": Color("#E63946")},
	Element.AIR:       {"icon": "res://Images/Type_Icons/Element/air_icon.png",       "color": Color("#8ECae6")},
	Element.LIGHTNING: {"icon": "res://Images/Type_Icons/Element/lightning_icon.png", "color": Color("#FFD166")},
}

# --- Signals ---
signal hovered
signal hovered_off

func _ready() -> void:
	if get_parent() and get_parent().has_method("connect_card_signals"):
		get_parent().connect_card_signals(self)

	if is_instance_valid(card_texture_rect) and card_texture:
		card_texture_rect.texture = card_texture

	# уважи флаговете за видимост преди да попълниш
	set_use_self_element(use_self_element)
	set_use_self_kind(use_self_kind)
	set_use_self_attack_style(use_self_attack_style)

	_update_element_ui()
	_update_kind_ui()
	_update_style_ui()
	_update_targets_ui()


# --- setters ---
func set_card_owner(v: OwnerType) -> void:
	card_owner = v

func is_owned_by_player() -> bool:
	return card_owner == OwnerType.PLAYER

func is_owned_by_ai() -> bool:
	return card_owner == OwnerType.AI


func set_card_texture(value: Texture2D) -> void:
	card_texture = value
	if is_instance_valid(card_texture_rect):
		card_texture_rect.texture = card_texture

func set_element(v: Element) -> void:
	element = v
	_update_element_ui()

func set_kind(v: CardKind) -> void:
	kind = v
	_update_kind_ui()

func set_attack_style(v: AttackStyle) -> void:
	attack_style = v
	_update_style_ui()

func set_use_element_target(v: bool) -> void:
	use_element_target = v
	_update_targets_ui()

func set_target_element(v: Element) -> void:
	target_element = v
	_update_targets_ui()

func set_use_kind_target(v: bool) -> void:
	use_kind_target = v
	_update_targets_ui()

func set_target_kind(v: CardKind) -> void:
	target_kind = v
	_update_targets_ui()

func set_use_attack_style_target(v: bool) -> void:
	use_attack_style_target = v
	_update_targets_ui()

func set_target_attack_style(v: AttackStyle) -> void:
	target_attack_style = v
	_update_targets_ui()
	
	
func set_use_self_element(v: bool) -> void:
	use_self_element = v
	_update_element_ui()

func set_use_self_kind(v: bool) -> void:
	use_self_kind = v
	_update_kind_ui()

func set_use_self_attack_style(v: bool) -> void:
	use_self_attack_style = v
	_update_style_ui()


# --- UI updates ---
func _update_element_ui() -> void:
	# контролирай видимостта на целия self-element блок
	if is_instance_valid(self_element_control):
		self_element_control.visible = use_self_element
	# ако е скрит – не попълваме нищо (оставяме темплейта по default)
	if not use_self_element:
		return

	if not (is_instance_valid(seld_card_type_element_color_rect) and is_instance_valid(seld_card_type_element_texture_rect)):
		return
	if ELEMENT_DISPLAY.has(element):
		var data = ELEMENT_DISPLAY[element]
		seld_card_type_element_color_rect.color = data["color"]
		_set_texture(seld_card_type_element_texture_rect, data["icon"])


func _update_kind_ui() -> void:
	if is_instance_valid(self_kind_control):
		self_kind_control.visible = use_self_kind
	if not use_self_kind:
		return

	if not (is_instance_valid(seld_card_type_kind_color_rect) and is_instance_valid(seld_card_type_kind_texture_rect)):
		return
	if KIND_DISPLAY.has(kind):
		var data = KIND_DISPLAY[kind]
		seld_card_type_kind_color_rect.color = data["color"]
		_set_texture(seld_card_type_kind_texture_rect, data["icon"])


func _update_style_ui() -> void:
	if is_instance_valid(self_attack_style_control):
		self_attack_style_control.visible = use_self_attack_style
	if not use_self_attack_style:
		return

	if not (is_instance_valid(seld_card_type_attack_style_color_rect) and is_instance_valid(seld_card_type_attack_style_texture_rect)):
		return
	if STYLE_DISPLAY.has(attack_style):
		var data = STYLE_DISPLAY[attack_style]
		seld_card_type_attack_style_color_rect.color = data["color"]
		_set_texture(seld_card_type_attack_style_texture_rect, data["icon"])


func _update_targets_ui() -> void:
	# visibility
	if is_instance_valid(connect_wth_element_control):
		connect_wth_element_control.visible = use_element_target
	if is_instance_valid(connect_wth_kind_control):
		connect_wth_kind_control.visible = use_kind_target
	if is_instance_valid(connect_wth_attack_style_control):
		connect_wth_attack_style_control.visible = use_attack_style_target

	# element target
	if use_element_target and ELEMENT_DISPLAY.has(target_element):
		var ed = ELEMENT_DISPLAY[target_element]
		if is_instance_valid(connect_wth_element_color_rect):
			connect_wth_element_color_rect.color = ed["color"]
		_set_texture(connect_wth_element_texture_rect, ed["icon"])

	# kind target
	if use_kind_target and KIND_DISPLAY.has(target_kind):
		var kd = KIND_DISPLAY[target_kind]
		if is_instance_valid(connect_wth_kind_color_rect):
			connect_wth_kind_color_rect.color = kd["color"]
		_set_texture(connect_wth_kind_texture_rect, kd["icon"])

	# attack style target
	if use_attack_style_target and STYLE_DISPLAY.has(target_attack_style):
		var sd = STYLE_DISPLAY[target_attack_style]
		if is_instance_valid(connect_wth_attackStyle_color_rect):
			connect_wth_attackStyle_color_rect.color = sd["color"]
		_set_texture(connect_wth_attack_style_texture_rect, sd["icon"])

# --- helper ---
func _set_texture(tex_rect: TextureRect, path: String) -> void:
	if not is_instance_valid(tex_rect):
		return
	if path.is_empty():
		tex_rect.texture = null
		return
	# Можеш да замениш load() с preload() ако иконите са фиксирани.
	var tex: Texture2D = load(path)
	tex_rect.texture = tex

# --- hover signals (ако ползваш Area2D в сцената) ---
func _on_area_2d_mouse_exited() -> void:
	emit_signal("hovered_off", self)

func _on_area_2d_mouse_entered() -> void:
	emit_signal("hovered", self)
	
func on_destroy() -> void:
	if _is_destroying:
		return
	_is_destroying = true
	set_process(false)
	set_physics_process(false)

	var anim := _get_destroy_anim_for_element(element)
	if animation_player and animation_player.has_animation(anim):
		animation_player.play(anim)
		animation_player.animation_finished.connect(
			func(_name):
				if _name == anim:
					emit_signal("destroyed", self) 
					queue_free(),
			CONNECT_ONE_SHOT
		)
	else:
		emit_signal("destroyed", self)     
		queue_free()


func _get_destroy_anim_for_element(el: int) -> String:
	match el:
		Card.Element.WATER:
			return destroy_water_anim
		Card.Element.FIRE:
			return destroy_fire_anim
		Card.Element.AIR:
			return destroy_air_anim
		Card.Element.LIGHTNING:
			return destroy_lightning_anim
		_:
			# дефолтна/резервна
			return destroy_air_anim
			
func _input_event(_viewport, event, _shape_idx):
	if event is InputEventScreenTouch:
		if event.pressed:
			emit_signal("hovered", self)
		else:
			emit_signal("hovered_off", self)
	elif event is InputEventScreenDrag:
		# Ако искаш да позволиш плъзгане (drag)
		emit_signal("hovered", self)
		
func show_back(state: bool) -> void:
	if is_instance_valid(back_card):
		back_card.visible = state
