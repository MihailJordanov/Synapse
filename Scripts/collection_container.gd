# CollectionFlowContainer.gd
class_name CollectionContainer
extends GridContainer

const CARD_SCENE := preload("res://Scenes/card.tscn")
const DECK_LIMIT := 20

@onready var template: Control = $"../Card_Visualisation"
@onready var locked_panel: Panel = $"../Card_Visualisation/LockedPanel"
@onready var picked_card_show: PickedCardShow = $"../CanvasLayer/PickedCardShow"
@onready var card_count_rich_text_label: RichTextLabel = $"../CanvasLayer/BorderPanel/CardCountRichTextLabel"
@onready var info_rich_text_label: RichTextLabel = $"../CanvasLayer/BorderPanel/InfoRichTextLabel"



signal deck_changed(card_id, in_deck: bool) 

var _scratch_card: Card
var _id_to_ui: Dictionary = {}

const KIND_DISPLAY := {
	"HERO":   {"icon": "res://Images/Type_Icons/Kind/knight_icon.png", "color": Color("#9c7e00")},
	"ORG":    {"icon": "res://Images/Type_Icons/Kind/orc_icon.png",    "color": Color("#84994F")},
	"WIZARD": {"icon": "res://Images/Type_Icons/Kind/wizard_icon.png", "color": Color("#640D5F")},
}
const STYLE_DISPLAY := {
	"MELEE":    {"icon": "res://Images/Type_Icons/Attack_Type/mele_icon.png",     "color": Color("#483900")},
	"RANGE":    {"icon": "res://Images/Type_Icons/Attack_Type/range_icon.png",    "color": Color("#77BEF0")},
	"TELEPATH": {"icon": "res://Images/Type_Icons/Attack_Type/telepathy_icon.png","color": Color("#FF00FF")},
}
const ELEMENT_DISPLAY := {
	"WATER":     {"icon": "res://Images/Type_Icons/Element/water_icon.png",     "color": Color("#3A86FF")},
	"FIRE":      {"icon": "res://Images/Type_Icons/Element/fire_icon.png",      "color": Color("#E63946")},
	"AIR":       {"icon": "res://Images/Type_Icons/Element/air_icon.png",       "color": Color("#8ECae6")},
	"LIGHTNING": {"icon": "res://Images/Type_Icons/Element/lightning_icon.png", "color": Color("#FFD166")},
}

func _ready() -> void:
	_scratch_card = CARD_SCENE.instantiate() as Card
	_build_collection()
	_update_deck_labels()

# Повикай това след промяна в дека (add/remove) ако не искаш да ребилдваш.
func refresh_in_deck_icons() -> void:
	for id_str in _id_to_ui.keys():
		var ui := _id_to_ui[id_str] as Control
		if ui == null: continue
		var in_deck_panel: Panel = ui.get_node_or_null("InDeckPanel")
		if in_deck_panel:
			in_deck_panel.visible = CollectionManager.in_deck(id_str)
	_update_deck_labels() 

func _build_collection() -> void:
	if template:
		template.visible = false

	for child in get_children():
		remove_child(child)
		child.queue_free()
	_id_to_ui.clear()

	var cards: Array = CollectionManager.get_all_cards()
	for card_dict in cards:
		var ui: Control = _make_card_visual(card_dict)
		if ui:
			add_child(ui)
			_id_to_ui[str(card_dict.get("id",""))] = ui


func _make_card_visual(data: Dictionary) -> Control:
	if template == null:
		push_error("CollectionContainer: missing Card_Visualisation template.")
		return null

	var inst: Control = template.duplicate() as Control
	inst.visible = true
	inst.mouse_filter = Control.MOUSE_FILTER_STOP
	inst.name = "Card_%s" % str(data.get("id", "X"))

	_set_children_mouse_pass(inst)
	var locked := inst.get_node_or_null("LockedPanel") as Control
	if locked:
		locked.mouse_filter = Control.MOUSE_FILTER_STOP
	# 🔒 LOCKED / UNLOCKED
	var cid = data.get("id", null)
	var is_unlocked: bool = cid != null and CollectionManager.is_unlocked(cid)

	var locked_panel_inst: Panel = inst.get_node_or_null("LockedPanel")
	if locked_panel_inst:
		locked_panel_inst.visible = not is_unlocked

	# ✅ InDeck значка/панел – включваме ако картата е в дека
	_update_in_deck_badge(inst, cid)

	_wire_preview_and_toggle(inst, data, is_unlocked)  # ← Актуализирано: toggle + preview
	if not is_unlocked:
		return inst

	# --- попълване за unlocked карти ---
	var tex_path: String = str(data.get("card_texture", ""))
	var tex_rect: TextureRect = inst.get_node("MainPanel/ImagePanel/TextureRect") as TextureRect
	tex_rect.texture = _load_texture(tex_path)

	_set_type_block_optional(
		inst.get_node("MainPanel/CardTypesPanel/HBoxContainer/ElementControl") as Control,
		inst.get_node("MainPanel/CardTypesPanel/HBoxContainer/ElementControl/Panel/ColorRect") as ColorRect,
		inst.get_node("MainPanel/CardTypesPanel/HBoxContainer/ElementControl/Panel/TextureRect") as TextureRect,
		_display_for_element(_norm_key(data.get("self_element", null)))
	)
	_set_type_block_optional(
		inst.get_node("MainPanel/CardTypesPanel/HBoxContainer/KindControl") as Control,
		inst.get_node("MainPanel/CardTypesPanel/HBoxContainer/KindControl/Panel/ColorRect") as ColorRect,
		inst.get_node("MainPanel/CardTypesPanel/HBoxContainer/KindControl/Panel/TextureRect") as TextureRect,
		_display_for_kind(_norm_key(data.get("self_kind", null)))
	)
	_set_type_block_optional(
		inst.get_node("MainPanel/CardTypesPanel/HBoxContainer/AttackStyleControl") as Control,
		inst.get_node("MainPanel/CardTypesPanel/HBoxContainer/AttackStyleControl/Panel/ColorRect") as ColorRect,
		inst.get_node("MainPanel/CardTypesPanel/HBoxContainer/AttackStyleControl/Panel/TextureRect") as TextureRect,
		_display_for_style(_norm_key(data.get("self_attack_style", null)))
	)
	_set_type_block_optional(
		inst.get_node("MainPanel/ConnectingPanel/HBoxContainer/ElementControl") as Control,
		inst.get_node("MainPanel/ConnectingPanel/HBoxContainer/ElementControl/Panel/ColorRect") as ColorRect,
		inst.get_node("MainPanel/ConnectingPanel/HBoxContainer/ElementControl/Panel/TextureRect") as TextureRect,
		_display_for_element(_norm_key(data.get("connect_element", null)))
	)
	_set_type_block_optional(
		inst.get_node("MainPanel/ConnectingPanel/HBoxContainer/KindControl") as Control,
		inst.get_node("MainPanel/ConnectingPanel/HBoxContainer/KindControl/Panel/ColorRect") as ColorRect,
		inst.get_node("MainPanel/ConnectingPanel/HBoxContainer/KindControl/Panel/TextureRect") as TextureRect,
		_display_for_kind(_norm_key(data.get("connect_kind", null)))
	)
	_set_type_block_optional(
		inst.get_node("MainPanel/ConnectingPanel/HBoxContainer/AttackStyleControl") as Control,
		inst.get_node("MainPanel/ConnectingPanel/HBoxContainer/AttackStyleControl/Panel/ColorRect") as ColorRect,
		inst.get_node("MainPanel/ConnectingPanel/HBoxContainer/AttackStyleControl/Panel/TextureRect") as TextureRect,
		_display_for_style(_norm_key(data.get("connect_attack_style", null)))
	)

	return inst
	

# --- помощни (същите като при теб) ---
func _set_type_block(ctrl: Control, color_rect: ColorRect, icon_rect: TextureRect, disp: Dictionary) -> void:
	if ctrl: ctrl.visible = true
	if color_rect and disp.has("color"): color_rect.color = disp["color"]
	if icon_rect and disp.has("icon"): icon_rect.texture = _load_texture(str(disp["icon"]))

func _set_type_block_optional(ctrl: Control, color_rect: ColorRect, icon_rect: TextureRect, disp: Dictionary) -> void:
	if disp.is_empty():
		if ctrl: ctrl.visible = false
		return
	_set_type_block(ctrl, color_rect, icon_rect, disp)

func _norm_key(v) -> String:
	if v == null: return ""
	var s: String = str(v).strip_edges()
	return s.to_upper()

func _display_for_element(k: String) -> Dictionary: return ELEMENT_DISPLAY.get(k, {}) as Dictionary
func _display_for_kind(k: String) -> Dictionary:    return KIND_DISPLAY.get(k, {}) as Dictionary
func _display_for_style(k: String) -> Dictionary:   return STYLE_DISPLAY.get(k, {}) as Dictionary

func _load_texture(path: String) -> Texture2D:
	if path.is_empty(): return null
	return load(path)

# превюто остава непроменено...



func _wire_preview_signals(ui: Control, data: Dictionary, is_unlocked: bool) -> void:
	# ако е заключена – не показваме нищо при hover/click
	if not is_unlocked:
		ui.mouse_entered.connect(func():
			if is_instance_valid(picked_card_show):
				picked_card_show.clear())
		ui.mouse_exited.connect(func():
			if is_instance_valid(picked_card_show):
				picked_card_show.clear())
		return

	# показвай при hover
	ui.mouse_entered.connect(func():
		_fill_scratch_card_from_data(data)
		if is_instance_valid(picked_card_show):
			picked_card_show.show_card(_scratch_card))

	# скрий при излизане с мишката
	ui.mouse_exited.connect(func():
		if is_instance_valid(picked_card_show):
			picked_card_show.clear())

	# показвай и при клик (ако искаш да „закотвяш“, можеш да пропуснеш clear на mouse_exited)
	ui.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_fill_scratch_card_from_data(data)
			if is_instance_valid(picked_card_show):
				picked_card_show.show_card(_scratch_card))
				
				
func _fill_scratch_card_from_data(d: Dictionary) -> void:
	if _scratch_card == null:
		return

	# ID + текстура
	_scratch_card.id = int(_safe_id(d.get("id", 0)))
	var tex_path := str(d.get("card_texture",""))
	if not tex_path.is_empty() and _scratch_card.has_method("set_card_texture"):
		_scratch_card.set_card_texture(load(tex_path))

	# SELF флагове (true ако има стойност, иначе false)
	var se = d.get("self_element", null)
	var sk = d.get("self_kind", null)
	var ss = d.get("self_attack_style", null)

	_scratch_card.set_use_self_element(se != null)
	_scratch_card.set_use_self_kind(sk != null)
	_scratch_card.set_use_self_attack_style(ss != null)

	# Стойности (ако има)
	if se != null and _scratch_card.has_method("set_element"):
		_scratch_card.set_element(_to_element(se))
	if sk != null and _scratch_card.has_method("set_kind"):
		_scratch_card.set_kind(_to_kind(sk))
	if ss != null and _scratch_card.has_method("set_attack_style"):
		_scratch_card.set_attack_style(_to_style(ss))

	# CONNECT флагове
	var ce = d.get("connect_element", null)
	var ck = d.get("connect_kind", null)
	var cs = d.get("connect_attack_style", null)

	_scratch_card.set_use_element_target(ce != null)
	_scratch_card.set_use_kind_target(ck != null)
	_scratch_card.set_use_attack_style_target(cs != null)

	# CONNECT стойности (ако има)
	if ce != null and _scratch_card.has_method("set_target_element"):
		_scratch_card.set_target_element(_to_element(ce))
	if ck != null and _scratch_card.has_method("set_target_kind"):
		_scratch_card.set_target_kind(_to_kind(ck))
	if cs != null and _scratch_card.has_method("set_target_attack_style"):
		_scratch_card.set_target_attack_style(_to_style(cs))



func _safe_id(v) -> int:
	if v == null: return 0
	if typeof(v) == TYPE_INT: return v
	if typeof(v) == TYPE_FLOAT: return int(v)
	if typeof(v) == TYPE_STRING and v.is_valid_int(): return int(v)
	if typeof(v) == TYPE_STRING and v.is_valid_float(): return int(float(v))
	return 0

func _to_element(v) -> int:
	var s := str(v).to_upper()
	if Card.Element.has(s): return Card.Element[s]
	if v is int: return v
	return Card.Element.AIR

func _to_kind(v) -> int:
	var s := str(v).to_upper()
	if s == "ORC": s = "ORG"
	if Card.CardKind.has(s): return Card.CardKind[s]
	if v is int: return v
	return Card.CardKind.HERO

func _to_style(v) -> int:
	var s := str(v).to_upper()
	if Card.AttackStyle.has(s): return Card.AttackStyle[s]
	if v is int: return v
	return Card.AttackStyle.MELEE
	
func _update_in_deck_badge(ui: Control, cid) -> void:
	var in_deck_panel: Panel = ui.get_node_or_null("InDeckPanel")
	if in_deck_panel:
		in_deck_panel.visible = CollectionManager.in_deck(cid)

# превю + toggle в deck при клик (само за unlocked)
func _wire_preview_and_toggle(ui: Control, data: Dictionary, is_unlocked: bool) -> void:
	if not is_unlocked:
		ui.mouse_entered.connect(func():
			if is_instance_valid(picked_card_show): picked_card_show.clear())
		ui.mouse_exited.connect(func():
			if is_instance_valid(picked_card_show): picked_card_show.clear())
		return

	ui.mouse_entered.connect(func():
		_fill_scratch_card_from_data(data)
		if is_instance_valid(picked_card_show):
			picked_card_show.show_card(_scratch_card))

	ui.mouse_exited.connect(func():
		if is_instance_valid(picked_card_show):
			picked_card_show.clear())

	ui.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_click_animation(ui)

			# превю (по избор)
			_fill_scratch_card_from_data(data)
			if is_instance_valid(picked_card_show):
				picked_card_show.show_card(_scratch_card)

			var cid = data.get("id", null)
			if cid == null:
				return

			# TOGGLE с лимит
			if CollectionManager.in_deck(cid):
				if CollectionManager.remove_from_deck(cid):
					_update_in_deck_badge(ui, cid)
					_update_deck_labels()
					emit_signal("deck_changed", cid, false)
			else:
				# ЛИМИТ преди добавяне
				if _deck_size() >= DECK_LIMIT:
					_flash_limit_warning()
					return
				if CollectionManager.add_to_deck(cid):
					_update_in_deck_badge(ui, cid)
					_update_deck_labels()
					emit_signal("deck_changed", cid, true)
)



func _click_animation(node: Control) -> void:
	if node == null: return
	# центриран pivot (за да не „мести“ hit-зоната)
	node.pivot_offset = node.size * 0.5
	var t := create_tween()
	t.tween_property(node, "scale", Vector2(0.9, 0.9), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2(1, 1), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)



func _set_children_mouse_pass(n: Node) -> void:
	for ch in n.get_children():
		if ch is Control:
			# по подразбиране: пропуска към родителя
			(ch as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		_set_children_mouse_pass(ch)
		
		
# помощни за брояча/предупреждението
func _deck_size() -> int:
	return CollectionManager.deck.size()

func _update_deck_labels() -> void:
	if is_instance_valid(card_count_rich_text_label):
		card_count_rich_text_label.bbcode_enabled = true
		card_count_rich_text_label.text = "[center][b]Deck:[/b]\n%d / %d[/center]" % [_deck_size(), DECK_LIMIT]

	if is_instance_valid(info_rich_text_label):
		info_rich_text_label.bbcode_enabled = true
		if _deck_size() > DECK_LIMIT:
			var over := _deck_size() - DECK_LIMIT
			info_rich_text_label.text = "[color=red][b]Limit exceeded! Remove %d cards.[/b][/color]" % over
		elif _deck_size() == DECK_LIMIT:
			info_rich_text_label.text = "[color=yellow][b]The limit has been reached.[/b][/color]"
		else:
			info_rich_text_label.text = ""

func _flash_limit_warning() -> void:
	if not is_instance_valid(info_rich_text_label):
		return
	_update_deck_labels()
	var t := create_tween()
	t.tween_property(info_rich_text_label, "modulate", Color(1, 0.4, 0.4), 0.08)
	t.tween_property(info_rich_text_label, "modulate", Color(1, 1, 1), 0.18)
