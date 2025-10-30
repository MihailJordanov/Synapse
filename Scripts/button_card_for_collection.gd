extends Button
class_name ButtonCardForCollection

signal long_pressed()
signal short_tapped()

# Настрой — „по-меко“ усещане:
const TAP_MAX_TIME     := 0.20  # сек — ако отпуснем до толкова бързо, броим за клик
const TAP_MAX_MOVE     := 18.0  # px — позволено леко движение за клик
const LONG_PRESS_TIME  := 0.32  # сек — дълъг тап (по-късно = по-малко фалшиви long)
const DRAG_START_MOVE  := 22.0  # px — колко да се „отлепи“, за да стартираме drag при long

# --- Enums ---
enum Element     { AIR, WATER, FIRE, LIGHTNING }
enum CardKind    { HERO, ORC, WIZARD, SKELETON }
enum AttackStyle { MELEE, RANGE, TELEPATH }

# --- Display maps ---
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

@export var card_id: int = -1

# --- UI refs ---
@onready var card_texture_rect: TextureRect = $MainPanel/ImagePanel/TextureRect

# Self
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

# Helpers
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var locked_panel: Panel = $AnimationgPanels/LockedPanel
@onready var in_deck_panel: Panel = $AnimationgPanels/InDeckPanel


var is_in_deck : bool = false
var is_unlcok : bool = false
var _cm: Node = null

var _pressing := false
var _press_pos := Vector2.ZERO
var _press_time := 0.0
var _long_fired := false
var _timer: SceneTreeTimer


# --- Data (UI-only) ---
@export var card_texture: Texture2D : set = set_card_texture, get = get_card_texture

# Self (what this button visually "is")
@export var use_self_element := true  : set = set_use_self_element, get = is_self_element_enabled
@export var element: Element = Element.AIR : set = set_element, get = get_self_element

@export var use_self_kind := true     : set = set_use_self_kind,    get = is_self_kind_enabled
@export var kind: CardKind = CardKind.HERO : set = set_kind, get = get_self_kind

@export var use_self_attack_style := true : set = set_use_self_attack_style, get = is_self_attack_style_enabled
@export var attack_style: AttackStyle = AttackStyle.MELEE : set = set_attack_style, get = get_self_attack_style

# Targets / Connecting (what this button visually "connects to")
@export var use_element_target := false : set = set_use_element_target, get = is_connect_element_enabled
@export var target_element: Element = Element.WATER : set = set_target_element, get = get_connect_element

@export var use_kind_target := false : set = set_use_kind_target, get = is_connect_kind_enabled
@export var target_kind: CardKind = CardKind.ORC : set = set_target_kind, get = get_connect_kind

@export var use_attack_style_target := false : set = set_use_attack_style_target, get = is_connect_attack_style_enabled
@export var target_attack_style: AttackStyle = AttackStyle.RANGE : set = set_target_attack_style, get = get_connect_attack_style


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	gui_input.connect(_on_gui_input)
	_update_all_ui()
	

# ----------------------------
# Getters (explicit & удобни)
# ----------------------------
func get_card_texture() -> Texture2D: return card_texture

# Self getters
func get_self_element() -> Element: return element
func get_self_kind() -> CardKind: return kind
func get_self_attack_style() -> AttackStyle: return attack_style

# Self enabled-state
func is_self_element_enabled() -> bool: return use_self_element
func is_self_kind_enabled() -> bool: return use_self_kind
func is_self_attack_style_enabled() -> bool: return use_self_attack_style

# Connect getters
func get_connect_element() -> Element: return target_element
func get_connect_kind() -> CardKind: return target_kind
func get_connect_attack_style() -> AttackStyle: return target_attack_style

# Connect enabled-state
func is_connect_element_enabled() -> bool: return use_element_target
func is_connect_kind_enabled() -> bool: return use_kind_target
func is_connect_attack_style_enabled() -> bool: return use_attack_style_target


# ----------------------------
# Setters (обновяват UI)
# ----------------------------
func set_collection_manager(cm: Node) -> void:
	_cm = cm

func set_card_texture(v: Texture2D) -> void:
	card_texture = v
	if is_instance_valid(card_texture_rect):
		card_texture_rect.texture = v

# Self
func set_use_self_element(v: bool) -> void:
	use_self_element = v
	_update_self_element_ui()

func set_element(v: Element) -> void:
	element = v
	_update_self_element_ui()

func set_use_self_kind(v: bool) -> void:
	use_self_kind = v
	_update_self_kind_ui()

func set_kind(v: CardKind) -> void:
	kind = v
	_update_self_kind_ui()

func set_use_self_attack_style(v: bool) -> void:
	use_self_attack_style = v
	_update_self_style_ui()

func set_attack_style(v: AttackStyle) -> void:
	attack_style = v
	_update_self_style_ui()

# Connecting
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


# ----------------------------
# UI updates
# ----------------------------
func _update_all_ui() -> void:
	# картинка
	if is_instance_valid(card_texture_rect):
		card_texture_rect.texture = card_texture
	# self блокове
	_update_self_element_ui()
	_update_self_kind_ui()
	_update_self_style_ui()
	# таргети
	_update_targets_ui()
	_update_anim_panels()
		

func _update_self_element_ui() -> void:
	if is_instance_valid(self_element_control):
		self_element_control.visible = use_self_element
	if not use_self_element:
		return
	if not (is_instance_valid(seld_card_type_element_color_rect) and is_instance_valid(seld_card_type_element_texture_rect)):
		return
	if ELEMENT_DISPLAY.has(element):
		var data = ELEMENT_DISPLAY[element]
		seld_card_type_element_color_rect.color = data["color"]
		_set_texture(seld_card_type_element_texture_rect, data["icon"])

func _update_self_kind_ui() -> void:
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

func _update_self_style_ui() -> void:
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
	# visibility на трите контролa
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


# ----------------------------
# Helpers
# ----------------------------
func _set_texture(tex_rect: TextureRect, path: String) -> void:
	if not is_instance_valid(tex_rect):
		return
	if path.is_empty():
		tex_rect.texture = null
		return
	var tex: Texture2D = load(path)
	tex_rect.texture = tex


func _update_anim_panels() -> void:
	if not is_unlcok:
		locked_panel.visible = true
	else:
		locked_panel.visible = false
		if is_in_deck:
			in_deck_panel.visible = true
		else:
			in_deck_panel.visible = false
			
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_down(event.position)
		else:
			_on_up(event.position)
	elif event is InputEventScreenDrag:
		_on_drag(event.position)

func _on_down(pos: Vector2) -> void:
	_pressing = true
	_press_pos = pos
	_press_time = Time.get_ticks_msec() / 1000.0
	_long_fired = false

	if is_instance_valid(_timer):
		_timer = null
	_timer = get_tree().create_timer(LONG_PRESS_TIME)
	_timer.timeout.connect(_maybe_long_press, CONNECT_ONE_SHOT)

func _on_drag(pos: Vector2) -> void:
	if not _pressing:
		return
	# не правим нищо тук – оставяме ScrollContainer да си скролва (mouse_filter = PASS)
	# long-press ще се потвърди в _maybe_long_press, само ако има и време, и достатъчно движение

func _on_up(pos: Vector2) -> void:
	if not _pressing:
		return
	_pressing = false

	var elapsed := (Time.get_ticks_msec() / 1000.0) - _press_time
	var moved := pos.distance_to(_press_pos)

	# Ако long не е „гръмнал“ и се побира в прозореца → броим за клик,
	# дори да има леко плъзване.
	if not _long_fired and (elapsed <= TAP_MAX_TIME or moved <= TAP_MAX_MOVE):
		emit_signal("short_tapped")
		# по избор: call_deferred("emit_signal", "pressed")
		return
	# иначе — нищо (или е бил long, или е скрол/голямо движение)

func _maybe_long_press() -> void:
	if not _pressing or _long_fired:
		return
	# Приемаме long само ако има и достатъчно време, и малко „отлепване“
	# (така избягваме фалшив long при просто задържане за четене).
	var moved := (get_local_mouse_position() - _press_pos).length()
	if moved >= DRAG_START_MOVE:
		_long_fired = true
		emit_signal("long_pressed")


func _on_button_down() -> void:
	# заключена карта → само анимация за lock
	if not is_unlcok:
		if is_instance_valid(animation_player):
			animation_player.play("click_on_lock")
		return

	# добавяне/махане от deck + анимация
	if is_in_deck:
		if _cm and _cm.has_method("remove_from_deck"):
			_cm.remove_from_deck(card_id)
		is_in_deck = false
		if is_instance_valid(animation_player):
			animation_player.play("on_remove")
	else:
		if _cm and _cm.has_method("add_to_deck"):
			_cm.add_to_deck(card_id)
		is_in_deck = true
		if is_instance_valid(animation_player):
			animation_player.play("on_add")
