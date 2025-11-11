extends Node2D
class_name BetterCollection


@export var collection_manager_path: NodePath
@export var button_card_scene: PackedScene
@export var filler_min_size: Vector2 = Vector2(180, 240)
@export_file("*.tscn") var menu_scene_path: String = "res://Scenes/Scenes_In_Game/map.tscn"


@onready var grid: GridContainer = $Control/ScrollContainer/GridContainer
@onready var card_count_rich_text_label: RichTextLabel = $CanvasLayer/BorderPanel/CardCountRichTextLabel
@onready var info_rich_text_label: RichTextLabel = $CanvasLayer/BorderPanel/InfoRichTextLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer


var deck_limit : int = 15
var _cm: Node = null

func _ready() -> void:
	animation_player.play("openScene")
	
	deck_limit = UpgradesData.get_deck_size()
	
	_resolve_collection_manager()
	if _cm:
		if not _cm.is_connected("deck_changed", Callable(self, "_update_deck_labels")):
			_cm.deck_changed.connect(_update_deck_labels)
	refresh()
	_update_deck_labels()  



# -----------------------
# Публично API
# -----------------------
# добави/замени в BetterCollection.gd

func refresh() -> void:
	if _cm == null or not _cm.has_method("get_all_cards"):
		push_warning("BetterCollection: CollectionManager not found or missing get_all_cards().")
		return

	_clear_grid()

	# 1) измерваме размера на клетката (от сцената на бутона)
	var cell_size := _preview_cell_size()

	# 2) водещи (малки по височина) пълнители
	_add_leading_fillers(4, cell_size)

	# 3) реалните бутони
	var cards: Array = _cm.get_all_cards()
	for cdict in cards:
		if typeof(cdict) != TYPE_DICTIONARY:
			continue
		var btn := _make_button_for_card(cdict)
		if btn:
			grid.add_child(btn)

	# 4) завършващи пълнители (нормална височина)
	_add_trailing_fillers(4, cell_size)


# -----------------------
# Вътрешно
# -----------------------
func _resolve_collection_manager() -> void:
	if collection_manager_path != NodePath():
		_cm = get_node_or_null(collection_manager_path)
	if _cm == null:
		_cm = get_node_or_null("/root/CollectionManager")

func _clear_grid() -> void:
	for ch in grid.get_children():
		ch.queue_free()


func _make_button_for_card(card: Dictionary) -> Button:
	if button_card_scene == null:
		push_error("BetterCollection: button_card_scene is not assigned.")
		return null

	var btn: ButtonCardForCollection = button_card_scene.instantiate()
	var cid = card.get("id", null)
	btn.name = "Card_%s" % [str(cid)]
	btn.card_id = int(cid) if typeof(cid) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING] else -1

	# Текстура
	var tex_path: String = str(card.get("card_texture", ""))
	if tex_path != "":
		var tex := load(tex_path)
		if tex:
			btn.set_card_texture(tex)

	# ---- Self ----
	var self_el = card.get("self_element", null)
	btn.set_use_self_element(self_el != null)
	if self_el != null:
		btn.set_element(_parse_enum(self_el, btn.Element))

	var self_kind = card.get("self_kind", null)
	btn.set_use_self_kind(self_kind != null)
	if self_kind != null:
		btn.set_kind(_parse_enum(self_kind, btn.CardKind))

	var self_style = card.get("self_attack_style", null)
	btn.set_use_self_attack_style(self_style != null)
	if self_style != null:
		btn.set_attack_style(_parse_enum(self_style, btn.AttackStyle))

	# ---- Targets ----
	var t_el = card.get("connect_element", null)
	btn.set_use_element_target(t_el != null)
	if t_el != null:
		btn.set_target_element(_parse_enum(t_el, btn.Element))

	var t_kind = card.get("connect_kind", null)
	btn.set_use_kind_target(t_kind != null)
	if t_kind != null:
		btn.set_target_kind(_parse_enum(t_kind, btn.CardKind))

	var t_style = card.get("connect_attack_style", null)
	btn.set_use_attack_style_target(t_style != null)
	if t_style != null:
		btn.set_target_attack_style(_parse_enum(t_style, btn.AttackStyle))

	# ---- Deck / Unlock ----
	if _cm and _cm.has_method("is_unlocked"):
		btn.is_unlcok = _cm.is_unlocked(cid)
	if _cm and _cm.has_method("in_deck"):
		btn.is_in_deck = _cm.in_deck(cid)

	# подай мениджъра на бутона, за да може сам да добавя/махa от deck
	btn.set_collection_manager(_cm)

	btn.text = str(cid)
	btn.tooltip_text = "Card ID: %s" % [str(cid)]
	btn.deck_limit = deck_limit          
	btn.set_collection_manager(_cm)
	# ВАЖНО: не свързваме pressed/pressed_down тук – бутонът се грижи сам.
	return btn


func _parse_enum(value, enum_map: Dictionary) -> int:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	if typeof(value) == TYPE_STRING:
		for key in enum_map.keys():
			if str(key).to_upper() == value.to_upper():
				return enum_map[key]
	return 0


# -----------------------
# Fillers (пълнители)
# -----------------------
# Взима размера на клетката от сцената на бутона; ако няма – fallback
func _preview_cell_size() -> Vector2:
	if button_card_scene:
		var tmp := button_card_scene.instantiate()
		if tmp is Control:
			var ms := (tmp as Control).get_combined_minimum_size()
			if ms.x <= 0.0 or ms.y <= 0.0:
				ms = (tmp as Control).custom_minimum_size
			tmp.queue_free()
			if ms.x > 0.0 and ms.y > 0.0:
				return ms
		else:
			tmp.queue_free()
	return filler_min_size


# Пълнители в края (нормален размер)
func _add_trailing_fillers(count: int, cell_size: Vector2) -> void:
	for i in count:
		var filler := Control.new()
		filler.name = "FillerTail_%d" % i
		filler.focus_mode = Control.FOCUS_NONE
		filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
		filler.custom_minimum_size = cell_size
		grid.add_child(filler)


# Пълнители отпред (същата ширина, 10x по-малка височина)
func _add_leading_fillers(count: int, cell_size: Vector2) -> void:
	var small := Vector2(cell_size.x, max(1.0, cell_size.y * 0.1))
	for i in count:
		var filler := Control.new()
		filler.name = "FillerHead_%d" % i
		filler.focus_mode = Control.FOCUS_NONE
		filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
		filler.custom_minimum_size = small
		grid.add_child(filler)  # добавяме преди бутоните (в refresh())


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

func _deck_size() -> int:
	return CollectionManager.deck.size()


func _on_go_menu_button_button_down() -> void:
	animation_player.play("closeScene")
	await animation_player.animation_finished
	get_tree().change_scene_to_file(menu_scene_path)
