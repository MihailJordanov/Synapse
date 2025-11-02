class_name Tutorial
extends Node2D

@export_file("*.tscn") var menu_scene_path: String = "res://Scenes/Scenes_In_Game/map.tscn"


@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var anim_parts := $AnimParts
@onready var infot_label: RichTextLabel = $InfotLabel

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

func _on_skip_button_button_down() -> void:
	_edge4_looping = false
	_edge4_timer = null

	if animation_player.current_animation == "final":
		await _play_close_and_go_menu()
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
	if not _edge4_looping or animation_player.current_animation != "edge_4":
		return

	for c in [card_2, card_3, card_4]:
		_play_card_anim_and_then_reset(c, _CARD_FIRE_ANIM, _CARD_RESET_ANIM)

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
	LevelManager.add_cleared("0")
	var close_anim: Animation = animation_player.get_animation("closeScene")
	if close_anim == null:
		push_warning("Missing animation: closeScene")
		if ResourceLoader.exists(menu_scene_path):
			LevelManager.add_cleared("0")
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
	animation_player.play("openScene")
	var finished_name: String = await animation_player.animation_finished
	if finished_name == "openScene":
		animation_player.play(animations[current_index])
		
		
# --- Tutorial Messages ---
var tutorial_texts := {
	"pl_play_first_card": """
[center][b][color=#00ffb7]Welcome to Synapse![/color][/b][/center]

This tutorial will show you the [b]core rules[/b] and [b]flow[/b] of the game.

In Synapse, two players take turns placing cards on the board.
Each card has its own [color=#7fe9ff]Self Types[/color] and [color=#ff7b7b]Attack On[/color] attributes.

Let's begin — it's your turn to place your first card!
""",

	"ai_play_first_card": """
[center][b][color=#ff6961]Enemy’s turn![/color][/b][/center]

Now the opponent places their first card.
Just like you, their card also has [color=#7fe9ff]Self Types[/color] and [color=#ff7b7b]Attack On[/color] —  
these define how connections are formed between cards.
""",

	"edge_1": """
[center][b][color=#00ffb7]Connections![/color][/b][/center]

Whenever a card’s [b]Attack On[/b] matches another card’s [b]Self Type[/b],  
a [color=#00ffb7]connection[/color] is formed between them.

These links are key to creating powerful [b]cycles[/b] on the board.
""",

	"pl_play_second_card": """
[center][b][color=#00ffb7]Your turn again![/color][/b][/center]

You’ve placed another card.  
Connections between cards are [i]invisible[/i] at first — they only become visible once a [b]cycle[/b] is formed.

Keep playing strategically to link multiple cards together!
""",

	"edge_2": """
[center][b][color=#FFD166]Forming a Cycle[/color][/b][/center]

New cards bring new connections!  
Your goal is to [b]form a closed cycle[/b].

When a cycle is created, all cards that are part of it are [b]destroyed[/b],  
and the player who placed the last card in that cycle earns [color=#00ffb7]+1 point[/color] for each card destroyed!
""",

	"ai_play_second_card": """
[center][b][color=#ff6961]Enemy plays again![/color][/b][/center]

The opponent also aims to form cycles —  
it doesn’t matter whose cards connect,  
[b]any[/b] matching elements can form a valid link!

Stay alert and plan your next move wisely.
""",

	"edge_3": """
[center][b][color=#7fe9ff]More Links![/color][/b][/center]

Connections can form between [b]your own cards[/b] or [b]enemy cards[/b].  
What matters is the [color=#FFD166]pattern[/color] they create on the board.

Build larger networks — the more complex they become,  
the higher your chances to form a rewarding cycle.
""",

	"pl_play_third_card": """
[center][b][color=#00ffb7]A Cycle Appears![/color][/b][/center]

You’ve placed a card that almost completes a full connection loop.  
Keep your eyes open — the next edge might close the cycle!
""",

	"edge_4": """
[center][b][color=#FF5555]Cycle Complete![/color][/b][/center]

A closed network has been formed!  
The connected cards are now [b]destroyed[/b] in a burst of energy.

You’ve earned [color=#00ffb7]points[/color] for each card that was part of the loop —  
well done, Synapse master!
""",

	"final": """
[center][b][color=#00ffb7]Tutorial Complete![/color][/b][/center]

You’ve learned the basics of Synapse:
• Place cards strategically  
• Match [color=#7fe9ff]Attack On[/color] with [color=#ff7b7b]Self Types[/color]  
• Form cycles to score points  

That’s all!  
[b]You’re ready to play the real game.[/b]  
Press [color=#FFD166]Skip[/color] to finish the tutorial.
"""
}
