class_name GameMaster
extends Node

@onready var level: Level = $".."
@onready var game_state_random: GameStateRandom = $"../GameStateRandom"
@onready var player_deck_count_label: RichTextLabel = $PlayerDeckCountLabel
@onready var ai_deck_count_label: RichTextLabel = $AIDeckCountLabel

# UI
@onready var ai_points_label: RichTextLabel = $"../CanvasLayer/PointsPanel/AI_points_label"
@onready var player_points_label: RichTextLabel = $"../CanvasLayer/PointsPanel/Player_points_label"
@onready var coefficient_rich_text_label: RichTextLabel = $"../CanvasLayer/LevelRulesPanel/CoefficientRichTextLabel"

@export var player_points_to_reach : int = 10
@export var enemy_points_to_reach : int = 10
@export var coefficient_when_destroy_your_card : float = 1.0
@export var coefficient_when_destroy_enemy_card : float = 1.0

var max_player_deck_count: int = 0
var max_AI_deck_count: int = 0

# Точки (float, защото коефициентите може да са дробни)
var player_points: float = 0.0
var ai_points: float = 0.0

# По желание: сигнал за край на играта
signal game_over(winner: String)

func _ready() -> void:
	# позволи BBCode в RichTextLabel
	player_deck_count_label.bbcode_enabled = true
	ai_deck_count_label.bbcode_enabled = true
	player_points_label.bbcode_enabled = true
	ai_points_label.bbcode_enabled = true

	# on draw
	level.card_is_drawed.connect(_on_level_card_is_drawed)
	game_state_random.card_AI_is_drawed.connect(_on_ai_card_is_drawed)
	
	# on destroyed (затворен цикъл)
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
	_update_points_labels() 
	_update_coefficient_label()


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

# ====== ЛОГИКА ЗА ТОЧКИ ======

# Когато ИГРАЧЪТ затвори цикъл:
# points += унищожени МOИ карти * coeff_your + унищожени ВРАЖЕСКИ карти * coeff_enemy
func _on_human_closed_cycle(player_lost: int, ai_lost: int) -> void:
	# Осигури, че не минават отрицателни стойности
	player_lost = max(player_lost, 0)
	ai_lost = max(ai_lost, 0)

	print("Cycle closed by PLAYER. Player lost: %d, AI lost: %d" % [player_lost, ai_lost])

	var delta := float(player_lost) * coefficient_when_destroy_your_card \
		+ float(ai_lost) * coefficient_when_destroy_enemy_card
	player_points += delta

	_update_points_labels()
	if delta > 0.0:
		_animate_points_gain(player_points_label, Color("C7FFF0")) # ← анимирай играчa

	_check_win()

# Когато AI затвори цикъл — гледната точка е на AI:
# ai_points += унищожени НЕГОВИ карти (ai_lost) * coeff_your + унищожени КАРТИ НА ПРОТИВНИКА (player_lost) * coeff_enemy
func _on_ai_closed_cycle(player_lost: int, ai_lost: int) -> void:
	player_lost = max(player_lost, 0)
	ai_lost = max(ai_lost, 0)

	print("Cycle closed by AI. Player lost: %d, AI lost: %d" % [player_lost, ai_lost])

	var delta := float(ai_lost) * coefficient_when_destroy_your_card \
		+ float(player_lost) * coefficient_when_destroy_enemy_card
	ai_points += delta
	
	_update_points_labels()
	if delta > 0.0:
		_animate_points_gain(ai_points_label, Color("FFC4C4"))      # ← анимирай AI

	_check_win()

func _update_points_labels() -> void:
	# Enable BBCode for color formatting
	player_points_label.bbcode_enabled = true
	ai_points_label.bbcode_enabled = true

	# Format numbers with two decimal places
	var player_points_str := String.num(player_points, 2)
	var ai_points_str := String.num(ai_points, 2)

	# Choose colors (neon green for player, red for enemy)
	var player_color := "#00ffb7"  # bright teal-green
	var ai_color := "#ff5555"      # vivid red

	# Build rich text with color and alignment
	var player_text := "[center][b][color=%s]%s / %d[/color][/b][/center]" % [
		player_color, player_points_str, player_points_to_reach
	]

	var ai_text := "[center][b][color=%s]%s / %d[/color][/b][/center]" % [
		ai_color, ai_points_str, enemy_points_to_reach
	]

	player_points_label.text = player_text
	ai_points_label.text = ai_text


func _check_win() -> void:
	if player_points >= float(player_points_to_reach):
		print("[GameMaster] Player reached the goal: %.2f / %d" % [player_points, player_points_to_reach])
		emit_signal("game_over", "player")
	elif ai_points >= float(enemy_points_to_reach):
		print("[GameMaster] AI reached the goal: %.2f / %d" % [ai_points, enemy_points_to_reach])
		emit_signal("game_over", "ai")

# ====== ДЕЦК ЕТИКЕТИ ======

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

func _update_coefficient_label() -> void:
	coefficient_rich_text_label.bbcode_enabled = true
	coefficient_rich_text_label.text = (
		"[center][b]Coefficient:[/b]\n"
		+ "[color=#00ff7f]Your:[/color] x%.1f | [color=#ff5555]Enemy:[/color] x%.1f[/center]"
	) % [coefficient_when_destroy_your_card, coefficient_when_destroy_enemy_card]
	

func _animate_points_gain(label: Control, flash: Color) -> void:
	var orig_scale := label.scale
	var orig_mod := label.modulate
	var tw := create_tween()

	tw.parallel().tween_property(label, "scale", orig_scale * 1.13, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "modulate", flash, 0.10)

	tw.tween_property(label, "scale", orig_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "modulate", orig_mod, 0.18)
