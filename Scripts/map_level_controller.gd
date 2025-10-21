class_name MapLevelController
extends Node2D

@export_category("Go to scenes")
@export_file("*.tscn") var collection_scene_path: String = "res://Scenes/Scenes_In_Game/collection.tscn"

@export_category("Button -> level")
@export var buttons: Array[NodePath] = []          
@export var level_ids: Array[String] = []       

@onready var panel: Control = $CanvasLayer/SelectLevelPanel2
@onready var cooler_texture_rect: TextureRect = $CanvasLayer/SelectLevelPanel2/RichTextLabel2/CoolerTextureRect
@onready var enemy_name_label: RichTextLabel = $CanvasLayer/SelectLevelPanel2/NameLabel
@onready var enemy_texture_rect: TextureRect = $CanvasLayer/SelectLevelPanel2/EnemyTextureRect
@onready var play_button: Button = $CanvasLayer/SelectLevelPanel2/Button
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var info_rich_text_label: RichTextLabel = $CanvasLayer/SelectLevelPanel2/InfoRichTextLabel
@onready var go_to_collection: Button = $CanvasLayer/DownPanel/GoToCollection

var _selected_button: LevelButton = null
var _pending_show := false
var _next_button: LevelButton = null
var _panel_visible := false

func _ready() -> void:
	animation_player.play("openScene")
	# 1) Синхронизиране на бутони с LevelManager
	if buttons.size() != level_ids.size():
		push_warning("buttons и level_ids трябва да са с еднаква дължина! Използвам минималната.")

	var count := mini(buttons.size(), level_ids.size())
	for i in count:
		var btn := get_node_or_null(buttons[i]) as LevelButton
		if btn == null:
			push_warning("Елемент %d в 'buttons' не е валиден LevelButton." % i)
			continue

		var level_id := level_ids[i]
		btn.is_unlock = LevelManager.is_unlocked(level_id)
		btn.is_clear  = LevelManager.is_cleared(level_id)
		if btn.has_method("_update_textures"):
			btn._update_textures()

		# 2) Връзка: натискане на бутон -> селекция/панел
		btn.pressed.connect(func(): _on_level_button_pressed(btn))

	# 3) Анимации и Play
	animation_player.animation_finished.connect(_on_anim_finished)
	play_button.pressed.connect(_on_play_pressed)

	# 4) Първоначално панелът да е скрит (ако анимацията очаква)
	panel.visible = false
	_panel_visible = false


func _on_level_button_pressed(btn: LevelButton) -> void:
	
	if not btn.is_unlock:
		btn.modulate = Color(1, 0.3, 0.3) 
		var tween := create_tween()
		tween.tween_property(btn, "modulate", Color(1, 1, 1), 0.5)
		return
	
	if _panel_visible and _selected_button == btn:
		_apply_button_info(btn)
		return


	if _panel_visible and _selected_button != btn:
		_next_button = btn
		_pending_show = true
		animation_player.play("hide_select_level_menu")
		return


	_apply_button_info(btn)
	_selected_button = btn
	_show_panel()


func _apply_button_info(btn: LevelButton) -> void:
	# enemy_name_label = LevelButton.level_name
	enemy_name_label.bbcode_enabled = true
	enemy_name_label.clear()
	enemy_name_label.append_text(btn.level_name)  


	cooler_texture_rect.visible = btn.make_cooler


	enemy_texture_rect.texture = btn.enemy_texture


func _show_panel() -> void:
	panel.visible = true
	animation_player.play("show_select_level_menu")
	_panel_visible = true


func _hide_panel() -> void:
	if _panel_visible:
		animation_player.play("hide_select_level_menu")


func _on_anim_finished(_name: StringName) -> void:
	if _name == "hide_select_level_menu":
		panel.visible = false
		_panel_visible = false
		# Ако чакаме да покажем нов избор – сега го правим
		if _pending_show and _next_button:
			_apply_button_info(_next_button)
			_selected_button = _next_button
			_next_button = null
			_pending_show = false
			_show_panel()
	elif _name == "show_select_level_menu":
		panel.visible = true
		_panel_visible = true


func _on_play_pressed() -> void:
	if _selected_button == null:
		return
	
	if CollectionManager.deck.size() < 5:
		info_rich_text_label.text = "Your deck must contain at least 5 cards."
		_pulse_button(go_to_collection)
		return
	else:
		info_rich_text_label.text = ""
	# Зареждаме сцената, ако е зададена (PackedScene)
	if _selected_button.scene_name != null:
		animation_player.play("closeScene")
		get_tree().change_scene_to_packed(_selected_button.scene_name)
	else:
		push_warning("There is no scene for selected LevelButton.")



func _unhandled_input(event: InputEvent) -> void:
	# Клик извън панела и извън бутоните -> hide
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _panel_visible:
			return
		var hovered := get_viewport().gui_get_hovered_control()

		# Ако няма hovered control -> скриваме
		if hovered == null:
			_hide_panel()
			return

		# Ако е в панела -> не правим нищо
		if _is_descendant_of(hovered, panel):
			return

		# Ако е върху някой от бутоните -> не крий (онзи handler ще се погрижи)
		for p in buttons:
			var b := get_node_or_null(p) as Control
			if b and _is_descendant_of(hovered, b):
				return

		# Иначе – клик встрани
		_hide_panel()


func _is_descendant_of(node: Control, ancestor: Node) -> bool:
	var n: Node = node
	while n:
		if n == ancestor:
			return true
		n = n.get_parent()
	return false


func _on_go_to_collection_button_down() -> void:
	animation_player.play("closeScene")
	await animation_player.animation_finished
	get_tree().change_scene_to_file(collection_scene_path)
	
func _pulse_button(button: Button) -> void:
	if not is_instance_valid(button):
		return

	button.pivot_offset = button.size * 0.5 

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(button, "scale", Vector2(1.2, 1.2), 0.05)
	tween.parallel().tween_property(button, "modulate", Color(1.3, 1.3, 1.3), 0.05)
	tween.tween_property(button, "scale", Vector2(1, 1), 0.05)
	tween.parallel().tween_property(button, "modulate", Color(1, 1, 1), 0.05)
