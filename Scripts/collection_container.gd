class_name CollectionContainer
extends GridContainer

@export_category("Deack and Path")
@export var deck_limit : int = 20
@export_file("*.tscn") var menu_scene_path: String = "res://Scenes/Scenes_In_Game/map.tscn"

@onready var template: Control = $"../Card_Visualisation"
@onready var card_count_rich_text_label: RichTextLabel = $"../CanvasLayer/BorderPanel/CardCountRichTextLabel"
@onready var info_rich_text_label: RichTextLabel = $"../CanvasLayer/BorderPanel/InfoRichTextLabel"
@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"

signal deck_changed(card_id, in_deck: bool)

var _id_to_ui: Dictionary[String, Control] = {}  # <- типизиран речник

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
	animation_player.play("openScene")
	_build_collection()
	_update_deck_labels()


func refresh_in_deck_icons() -> void:
	for id_str in _id_to_ui.keys():
		var ui: Control = _id_to_ui[id_str]
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

	# LOCKED / UNLOCKED
	var cid = data.get("id", null)
	var is_unlocked: bool = cid != null and CollectionManager.is_unlocked(cid)

	var locked_panel_inst: Panel = inst.get_node_or_null("LockedPanel")
	if locked_panel_inst:
		locked_panel_inst.visible = not is_unlocked
		locked_panel_inst.mouse_filter = Control.MOUSE_FILTER_STOP

	_update_in_deck_badge(inst, cid)
	_wire_toggle_only(inst, data, is_unlocked)

	if not is_unlocked:
		return inst

	# Попълване за unlocked карти
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

# --- помощни за попълване ---
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

# --- Toggle only (mouse + touch) ---
func _wire_toggle_only(ui: Control, data: Dictionary, is_unlocked: bool) -> void:
	if not is_unlocked:
		ui.gui_input.connect(func(_ev): pass)
		return

	ui.gui_input.connect(func(ev):
		# Mouse
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_click_animation(ui)
			_toggle_for_card_id(data)
			return
		# Touch
		if ev is InputEventScreenTouch and ev.pressed:
			_click_animation(ui)
			_toggle_for_card_id(data)
			return
	)

func _toggle_for_card_id(data: Dictionary) -> void:
	var cid = data.get("id", null)
	if cid == null:
		return

	# махане
	if CollectionManager.in_deck(cid):
		if CollectionManager.remove_from_deck(cid):
			var ui: Control = _id_to_ui.get(str(cid), null)
			if ui:
				_update_in_deck_badge(ui, cid)
			_update_deck_labels()
			emit_signal("deck_changed", cid, false)
		return

	# добавяне с лимит
	if _deck_size() >= deck_limit:
		_flash_limit_warning()
		return

	if CollectionManager.add_to_deck(cid):
		var ui2: Control = _id_to_ui.get(str(cid), null)
		if ui2:
			_update_in_deck_badge(ui2, cid)
		_update_deck_labels()
		emit_signal("deck_changed", cid, true)

func _update_in_deck_badge(ui: Control, cid) -> void:
	var in_deck_panel: Panel = ui.get_node_or_null("InDeckPanel")
	if in_deck_panel:
		in_deck_panel.visible = CollectionManager.in_deck(cid)

func _set_children_mouse_pass(n: Node) -> void:
	for ch in n.get_children():
		if ch is Control:
			(ch as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		_set_children_mouse_pass(ch)

# --- брояч/лимит ---
func _deck_size() -> int:
	return CollectionManager.deck.size()

func _update_deck_labels() -> void:
	if is_instance_valid(card_count_rich_text_label):
		card_count_rich_text_label.bbcode_enabled = true
		card_count_rich_text_label.text = "[center][b]Deck:[/b]\n%d / %d[/center]" % [_deck_size(), deck_limit]

	if is_instance_valid(info_rich_text_label):
		info_rich_text_label.bbcode_enabled = true
		if _deck_size() > deck_limit:
			var over := _deck_size() - deck_limit
			info_rich_text_label.text = "[color=red][b]Limit exceeded! Remove %d cards.[/b][/color]" % over
		elif _deck_size() == deck_limit:
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

func _click_animation(node: Control) -> void:
	if node == null: return
	node.pivot_offset = node.size * 0.5
	var t := create_tween()
	t.tween_property(node, "scale", Vector2(0.9, 0.9), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2(1, 1), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _on_go_menu_button_button_down() -> void:
	animation_player.play("closeScene")
	await animation_player.animation_finished
	get_tree().change_scene_to_file(menu_scene_path)


func _on_sort_button_button_down() -> void:
	_sort_cards()


func _sort_cards() -> void:
	# 1) Вземаме текущия ред (линейно) от имената "Card_<id>"
	var current_ids := _collect_current_ids()
	# 2) Ако вече е сортирано според правилата – излизаме (O(n) проверка)
	if _is_already_sorted(current_ids):
		return

	# 3) Иначе сортираме и пренареждаме децата
	var ids: Array[String] = _id_to_ui.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return _id_a_precedes_b(a, b)
	)

	for i in ids.size():
		var ui: Control = _id_to_ui.get(ids[i], null)
		if ui:
			move_child(ui, i)

	refresh_in_deck_icons()


# Взима текущия ред на картите от имената на нодовете "Card_<id>"
func _collect_current_ids() -> Array[String]:
	var out: Array[String] = []
	for ch in get_children():
		if ch is Control:
			var n := (ch as Control).name
			if n.begins_with("Card_"):
				out.append(n.substr(5)) # след "Card_"
	return out

# Линейна проверка дали редът вече е сортиран според нашите правила
func _is_already_sorted(ids: Array[String]) -> bool:
	if ids.size() <= 1:
		return true
	var prev := ids[0]
	for i in range(1, ids.size()):
		var cur := ids[i]
		# ако cur трябва да е преди prev -> не е сортирано
		if _id_a_precedes_b(cur, prev):
			return false
		prev = cur
	return true

# Главното правило за реда:
# 1) картите в дека (CollectionManager.deck) първи, по реда им в дека
# 2) след това unlocked (не-в-дека), по id
# 3) накрая locked, по id
func _id_a_precedes_b(a: String, b: String) -> bool:
	var a_in := CollectionManager.in_deck(a)
	var b_in := CollectionManager.in_deck(b)
	if a_in != b_in:
		return a_in and not b_in

	if a_in and b_in:
		return _deck_index(a) < _deck_index(b)

	var a_un := CollectionManager.is_unlocked(a)
	var b_un := CollectionManager.is_unlocked(b)
	if a_un != b_un:
		return a_un and not b_un

	# и двете са unlocked (или locked) -> сравняваме по id (числово, ако и двете са числа)
	var a_num := a.is_valid_int()
	var b_num := b.is_valid_int()
	if a_num and b_num:
		return int(a) < int(b)
	return a < b

func _deck_index(id_str: String) -> int:
	var idx := CollectionManager.deck.find(id_str)
	return idx if idx != -1 else 999999
