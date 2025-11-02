class_name Tutorial
extends Node2D

@export_file("*.tscn") var menu_scene_path: String = "res://Scenes/Scenes_In_Game/map.tscn"


@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var anim_parts := $AnimParts
@onready var infot_label: RichTextLabel = $InfoPanel/InfotLabel
@onready var skip_button: Button = $SkipButton

var _skip_locked: bool = false

var EdgeScene := preload("res://Scenes/edge.tscn")

var animations := [
	"pl_play_first_card",
	"ai_play_first_card",
	"edge_1",
	"pl_play_second_card",
	"edge_2",
	"ai_play_second_card",
	"edge_3",
	"pl_play_third_card",
	"edge_4",
	"final"
]

var current_index := 0
var edges_current: Array[Edge] = []
var edge_pairs: Dictionary


@onready var card_1: Card = $Cards/Card
@onready var card_2: Card = $Cards/Card2
@onready var card_3: Card = $Cards/Card3
@onready var card_4: Card = $Cards/Card4
@onready var card_5: Card = $Cards/Card5
@onready var card_6: Card = $Cards/Card6


var _edge4_looping: bool = false
var _edge4_timer: SceneTreeTimer = null
const _CARD_FIRE_ANIM := "destroyed_fire"
const _CARD_RESET_ANIM := "RESET"


func _ready() -> void:
	_lock_skip()
	animation_player.play("openScene")
	
	edge_pairs = {
		"edge_1": [ { "from": card_2, "to": card_4, "duration": 0.6 } ],
		"edge_2": [ { "from": card_1, "to": card_4, "duration": 0.6 } ],
		"edge_3": [
			{ "from": card_2, "to": card_5, "duration": 0.6 },
			{ "from": card_4, "to": card_5, "duration": 0.6 },
		],
		"edge_4": [
			{ "from": card_2, "to": card_4, "duration": 0.6 },
			{ "from": card_4, "to": card_3, "duration": 0.6 },
			{ "from": card_3, "to": card_2, "duration": 0.6 },
		],
	}

	animation_player.animation_started.connect(_on_animation_started)
	animation_player.animation_finished.connect(_on_animation_finished)
	_play_open_then_start()

func _lock_skip() -> void:
	_skip_locked = true
	if is_instance_valid(skip_button):
		skip_button.disabled = true

func _unlock_skip() -> void:
	_skip_locked = false
	if is_instance_valid(skip_button):
		skip_button.disabled = false


func _on_skip_button_button_down() -> void:
	if _skip_locked:
		return

	_edge4_looping = false
	_edge4_timer = null

	if animation_player.current_animation == "final":
		_lock_skip()
		await _play_close_and_go_menu()
		return

	if animation_player.current_animation == "edge_4":
		_lock_skip()

		for c in [card_2, card_3, card_4]:
			_play_card_anim_and_then_reset(c, _CARD_FIRE_ANIM, _CARD_RESET_ANIM)

		_clear_edges(0.2)

		var wait_time := _calc_fire_reset_total_wait([card_2, card_3, card_4])
		await get_tree().create_timer(wait_time).timeout

		var final_index := animations.find("final")
		if final_index == -1:
			final_index = animations.size() - 1
		current_index = final_index
		animation_player.play(animations[current_index])

		_unlock_skip()
		return

	current_index += 1
	if current_index < animations.size():
		animation_player.play(animations[current_index])



func _on_animation_started(anim_name: StringName) -> void:
	_clear_edges(0.0)

	if anim_name != "edge_4":
		_edge4_looping = false
		_edge4_timer = null

	if edge_pairs.has(anim_name):
		var list: Array = edge_pairs[anim_name]
		for cfg in list:
			_spawn_edge(cfg)

	if anim_name == "edge_4":
		_start_edge4_loop()
	
	if tutorial_texts.has(anim_name):
		infot_label.bbcode_text = tutorial_texts[anim_name]



func _on_animation_finished(anim_name: StringName) -> void:
	if edge_pairs.has(anim_name):
		_clear_edges(0.2)



func _on_edge4_done() -> void:
	if animation_player.current_animation != "edge_4":
		return
	for c in [card_2, card_3, card_4]:
		var ap: AnimationPlayer = c.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if ap and ap.has_animation("destroyed_fire"):
			ap.stop(true)
			ap.play("destroyed_fire")
			ap.seek(0.0, true)

func _spawn_edge(cfg: Dictionary) -> void:
	if EdgeScene == null:
		return
	var a: Node = cfg["from"]
	var b: Node = cfg["to"]
	if not (is_instance_valid(a) and is_instance_valid(b)):
		return

	var e: Edge = EdgeScene.instantiate()
	anim_parts.add_child(e)
	var dur: float = float(cfg.get("duration", 0.6))
	e.set_endpoints(a, b, [], dur)
	edges_current.append(e)

func _clear_edges(fade: float) -> void:
	for e in edges_current:
		if is_instance_valid(e):
			if fade > 0.0:
				e.vanish(fade)
			else:
				e.queue_free()
	edges_current.clear()
	
	
# --- ЦИКЪЛ ЗА edge_4 ---

func _start_edge4_loop() -> void:
	_edge4_looping = true
	_schedule_edge4_tick()

func _schedule_edge4_tick() -> void:
	if not _edge4_looping:
		return
	var anim: Animation = animation_player.get_animation("edge_4")
	if anim == null:
		return
	var dur: float = anim.length / max(animation_player.speed_scale, 0.0001)
	_edge4_timer = get_tree().create_timer(dur)
	_edge4_timer.timeout.connect(_edge4_tick, CONNECT_ONE_SHOT)

func _edge4_tick() -> void:
	if not _edge4_looping:
		return
	if animation_player.current_animation != "edge_4":
		return

	await _play_fire_reset_all_and_wait([card_2, card_3, card_4])

	if not _edge4_looping:
		return

	animation_player.stop(true)
	animation_player.play("edge_4")
	_schedule_edge4_tick()




# --- помощници само в Tutorial ---

func _play_card_anim_and_then_reset(card: Node, fire_anim: String, reset_anim: String) -> void:
	if not is_instance_valid(card):
		return
	var ap: AnimationPlayer = card.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap == null:
		return
	if ap.has_animation(fire_anim):
		ap.stop(true)
		ap.play(fire_anim)
		ap.seek(0.0, true)
		ap.animation_finished.connect(
			func(name):
				if name == fire_anim and ap and ap.has_animation(reset_anim):
					ap.stop(true)
					ap.play(reset_anim)
					ap.seek(0.0, true),
			CONNECT_ONE_SHOT
		)
		
func _play_close_and_go_menu() -> void:
	_lock_skip()
	LevelManager.add_cleared("0")
	var close_anim: Animation = animation_player.get_animation("closeScene")
	if close_anim == null:
		push_warning("Missing animation: closeScene")
		if ResourceLoader.exists(menu_scene_path):
			get_tree().change_scene_to_file(menu_scene_path)
		else:
			push_error("Menu scene not found: %s" % menu_scene_path)
		return

	animation_player.play("closeScene")
	while true:
		var finished_name: String = await animation_player.animation_finished
		if finished_name == "closeScene":
			break

	if ResourceLoader.exists(menu_scene_path):
		get_tree().change_scene_to_file(menu_scene_path)
	else:
		push_error("Menu scene not found: %s" % menu_scene_path)


func _play_open_then_start() -> void:
	_lock_skip()
	animation_player.play("openScene")
	var finished_name: String = await animation_player.animation_finished
	if finished_name == "openScene":
		_unlock_skip()
		animation_player.play(animations[current_index])

		

func _get_anim_length(card: Node, anim_name: String) -> float:
	if not is_instance_valid(card):
		return 0.0
	var ap: AnimationPlayer = card.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap and ap.has_animation(anim_name):
		var a: Animation = ap.get_animation(anim_name)
		if a:
			return a.length / max(ap.speed_scale, 0.0001)
	return 0.0

func _calc_fire_reset_total_wait(cards: Array) -> float:
	var max_wait := 0.0
	for c in cards:
		var fire_len := _get_anim_length(c, _CARD_FIRE_ANIM)
		var reset_len := _get_anim_length(c, _CARD_RESET_ANIM)
		var total := fire_len + reset_len
		if total > max_wait:
			max_wait = total
	if max_wait <= 0.0:
		max_wait = 0.8  
	return max_wait


func _play_fire_reset_all_and_wait(cards: Array) -> void:
	# 🔒 Заключваме Skip бутона
	_lock_skip()

	# Пускаме FIRE → RESET за всички карти
	for c in cards:
		_play_card_anim_and_then_reset(c, _CARD_FIRE_ANIM, _CARD_RESET_ANIM)

	# Изчисляваме колко време общо траят (максимум от всички)
	var wait_time := _calc_fire_reset_total_wait(cards)
	if wait_time <= 0.0:
		wait_time = 0.8

	# Изчакваме
	await get_tree().create_timer(wait_time).timeout

	# 🔓 Отключваме след края
	_unlock_skip()


		
# --- Tutorial Messages ---
var tutorial_texts := {
	"pl_play_first_card": """
[center][b][color=#00ffb7]Welcome to Synapse! ⚡️[/color][/b][/center]

This quick guide shows the [b]core flow[/b] of the game.  
Players take turns placing cards. 🕹️

Each card has [color=#7fe9ff]Self Types[/color] and [color=#ff7b7b]Attack On[/color] —  
their interaction creates [b]edges[/b]. 🧠

Your move — place your first card! 🎯
""",

	"ai_play_first_card": """
[center][b][color=#ff6961]Enemy’s turn! 🤖[/color][/b][/center]

The opponent places a card.  
It also has [color=#7fe9ff]Self Types[/color] and [color=#ff7b7b]Attack On[/color].

When they align, an [color=#00ffb7]edge[/color] sparks! ✨
""",

	"edge_1": """
[center][b][color=#00ffb7]Edges! 🧩[/color][/b][/center]

If [b]Attack On[/b] matches a card’s [b]Self Type[/b],  
an [color=#00ffb7]edge[/color] forms between them. ⚡️

Edges weave the game’s [i]neural web[/i] —  
your path to powerful [b]cycles[/b]. 🔄
""",

	"pl_play_second_card": """
[center][b][color=#00ffb7]Your move again! 🔁[/color][/b][/center]

You placed another card.  
Edges stay [i]hidden[/i] until a [b]cycle[/b] forms — then they ignite! ✨

Keep building smart patterns. 🧠
""",

	"edge_2": """
[center][b][color=#FFD166]Cycle Formation 🌀[/color][/b][/center]

Every new card adds potential edges.  
Goal: [b]close a full cycle[/b]. 🎯

When it closes, all cards in the loop are [b]destroyed[/b], 💥  
and you gain [color=#00ffb7]+1 point[/color] per card!
""",

	"ai_play_second_card": """
[center][b][color=#ff6961]Enemy plays again! ♟️[/color][/b][/center]

They want cycles too.  
It doesn’t matter whose cards connect —  
[b]any matching pair[/b] can make an edge. ⚡️

Think ahead and outplay them. 🧭
""",

	"edge_3": """
[center][b][color=#7fe9ff]Expanding the Web 🌐[/color][/b][/center]

Edges can link [b]your cards[/b], [b]enemy cards[/b], or both.  
Focus on the [color=#FFD166]pattern[/color] they create. 🧵

Bigger networks = more chances for a cycle! 📈
""",

	"pl_play_third_card": """
[center][b][color=#00ffb7]Cycle Incoming! ⚠️[/color][/b][/center]

Your card almost completes the loop…  
One more edge and the chain reaction begins! 🔓
""",

	"edge_4": """
[center][b][color=#FF5555]Cycle Complete! ✅[/color][/b][/center]

The network closes and ignites! ✨  
Cards in the loop are [b]obliterated[/b]. 💥

You score [color=#00ffb7]points[/color] for each —  
well played, Synapse master! 👑
""",

	"final": """
[center][b][color=#00ffb7]Tutorial Complete! 🏁[/color][/b][/center]

You’re ready to play Synapse:  
• Place cards with intent 🧭  
• Match [color=#ff7b7b]Attack On[/color] ↔ [color=#7fe9ff]Self Types[/color] 🔗  
• Form [b]cycles[/b] to score points 🌀

That’s it — simple, elegant, powerful.  
[b]Enter the real battle![/b] 🚀  
Press [color=#FFD166]Skip[/color] to begin.
"""
}
