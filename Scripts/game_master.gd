class_name GameMaster
extends Node

@onready var level: Level = $".."
@onready var game_state_random: GameStateRandom = $"../GameStateRandom"
@onready var player_deck_count_label: RichTextLabel = $PlayerDeckCountLabel
@onready var ai_deck_count_label: RichTextLabel = $AIDeckCountLabel

var max_player_deck_count: int = 0
var max_AI_deck_count: int = 0


func _ready() -> void:
	# свържи сигналите за теглене на карта
	level.card_is_drawed.connect(_on_level_card_is_drawed)
	game_state_random.card_AI_is_drawed.connect(_on_ai_card_is_drawed)
	
	# вземи началните стойности
	max_player_deck_count = CollectionManager.deck.size()
	max_AI_deck_count = game_state_random.deck.ids.size()

	# покажи началните стойности
	_update_deck_labels()


func _on_level_card_is_drawed() -> void:
	_update_deck_labels()


func _on_ai_card_is_drawed() -> void:
	_update_deck_labels()


func _update_deck_labels() -> void:
	# За играча
	var remaining_player_cards := max_player_deck_count - level.deck_index
	if remaining_player_cards < 0:
		remaining_player_cards = 0

	# За AI
	var remaining_ai_cards := game_state_random._ai_deck.size()
	if remaining_ai_cards < 0:
		remaining_ai_cards = 0

	# Актуализирай етикетите
	player_deck_count_label.text = "[center]%d / %d[/center]" % [remaining_player_cards, max_player_deck_count]
	ai_deck_count_label.text = "[center]%d / %d[/center]" % [remaining_ai_cards, max_AI_deck_count]
