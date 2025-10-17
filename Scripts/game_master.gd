class_name GameMaster
extends Node

@onready var level: Level = $".."
@onready var game_state_random: GameStateRandom = $"../GameStateRandom"
@onready var player_deck_count_label: RichTextLabel = $PlayerDeckCountLabel
@onready var ai_deck_count_label: RichTextLabel = $AIDeckCountLabel

@export var player_hp : int = 10
@export var enemy_hp : int = 10

var max_player_deck_count: int = 0
var max_AI_deck_count: int = 0

func _ready() -> void:
	# позволи BBCode в RichTextLabel
	player_deck_count_label.bbcode_enabled = true
	ai_deck_count_label.bbcode_enabled = true

	# on draw
	level.card_is_drawed.connect(_on_level_card_is_drawed)
	game_state_random.card_AI_is_drawed.connect(_on_ai_card_is_drawed)
	
	# on destroyed
	level.human_closed_cycle.connect(_on_human_closed_cycle)
	level.ai_closed_cycle.connect(_on_ai_closed_cycle)

	max_player_deck_count = CollectionManager.deck.size()
	max_AI_deck_count = game_state_random.deck.ids.size()
	
	# slots-full notifications
	if not level.player_slots_full.is_connected(_on_player_slots_full):
		level.player_slots_full.connect(_on_player_slots_full)

	if not game_state_random.ai_slots_full.is_connected(_on_ai_slots_full):
		game_state_random.ai_slots_full.connect(_on_ai_slots_full)
		
	if not level.board_cleared_due_to_full_slots.is_connected(_on_board_cleared_due_to_full_slots):
		level.board_cleared_due_to_full_slots.connect(_on_board_cleared_due_to_full_slots)


	_update_deck_labels()
	
func _on_board_cleared_due_to_full_slots() -> void:
	print("[GameMaster] All slots are full")
	
func _on_player_slots_full() -> void:
	print("[GameMaster] Player slots are FULL — player cannot place a card this turn.")

func _on_ai_slots_full() -> void:
	print("[GameMaster] AI slots are FULL — AI cannot place a card this turn.")

	

func _on_level_card_is_drawed() -> void:
	_update_deck_labels()

func _on_ai_card_is_drawed() -> void:
	_update_deck_labels()
	
func _on_human_closed_cycle(player_lost: int, ai_lost: int) -> void:
	print("Cycle closed by PLAYER. Player lost: %d, AI lost: %d" % [player_lost, ai_lost])
	# по желание: UI апдейт, точки, ефекти и т.н.

func _on_ai_closed_cycle(player_lost: int, ai_lost: int) -> void:
	print("Cycle closed by AI. Player lost: %d, AI lost: %d" % [player_lost, ai_lost])
	# по желание: UI апдейт, точки, ефекти и т.н.


func _update_deck_labels() -> void:
	# За играча
	var remaining_player_cards := max_player_deck_count - level.deck_index
	if remaining_player_cards < 0:
		remaining_player_cards = 0

	# За AI
	var remaining_ai_cards := game_state_random._ai_deck.size()
	if remaining_ai_cards < 0:
		remaining_ai_cards = 0

	# Цветове според оставащите карти (червен при <= 0, иначе бял)
	var player_color := "red" if remaining_player_cards <= 0 else "white"
	var ai_color := "red" if remaining_ai_cards <= 0 else "white"

	player_deck_count_label.text = "[center][color=%s]%d / %d[/color][/center]" % [player_color, remaining_player_cards, max_player_deck_count]
	ai_deck_count_label.text = "[center][color=%s]%d / %d[/color][/center]" % [ai_color, remaining_ai_cards, max_AI_deck_count]
