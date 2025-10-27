class_name GameMaster
extends Node

# === CONFIG ===
@export_category("Game points")
@export var player_points_to_reach : int = 10
@export var enemy_points_to_reach : int = 10

@export_category("Coefficient")
@export var coefficient_when_destroy_your_card : float = 1.0
@export var coefficient_when_destroy_enemy_card : float = 1.0
@export var points_ai_get_when_slots_full : float = 0.0
@export var points_player_get_when_slots_full : float = 0.0

@export_category("On Win")
@export var cur_level : String
@export var levels_to_unlock_on_win : Array[String]
@export var cards_to_unlock_on_win : Array[int]
# === NODES ===
@onready var level: Level = $".."
@onready var game_state_random: GameStateRandom = $"../GameStateRandom"
@onready var player_deck_count_label: RichTextLabel = $PlayerDeckCountLabel
@onready var ai_deck_count_label: RichTextLabel = $AIDeckCountLabel
@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"
# UI
@onready var ai_points_label: RichTextLabel = $"../CanvasLayer/PointsPanel/AI_points_label"
@onready var player_points_label: RichTextLabel = $"../CanvasLayer/PointsPanel/Player_points_label"
@onready var coefficient_rich_text_label: RichTextLabel = $"../CanvasLayer/LevelRulesPanel/CoefficientRichTextLabel"
@onready var reward_info_text_label: RichTextLabel = $"../CanvasLayer/WinPanel/RewardInfoTextLabel"
@onready var lose_info_rich_text_label: RichTextLabel = $"../CanvasLayer/LosePanel/LoseInfoRichTextLabel"

# === STATE ===
var max_player_deck_count: int = 0
var max_AI_deck_count: int = 0

var player_points: float = 0.0
var ai_points: float = 0.0

enum GamePhase { PLAYING, WON, LOST }
var _phase: GamePhase = GamePhase.PLAYING

signal game_over(winner: String) # "player" или "ai"

# === COLORS ===
const PLAYER_FLASH := Color("C7FFF0") # нежно неон зеленикаво
const AI_FLASH := Color("FFC4C4")     # леко червеникаво
const PLAYER_TEXT := "#00ffb7"
const AI_TEXT := "#ff5555"

func _ready() -> void:
	print("3")
	animation_player.play("open_scene")
	# allow BBCode
	player_deck_count_label.bbcode_enabled = true
	ai_deck_count_label.bbcode_enabled = true
	player_points_label.bbcode_enabled = true
	ai_points_label.bbcode_enabled = true
	coefficient_rich_text_label.bbcode_enabled = true
	

	# signals
	level.card_is_drawed.connect(_on_level_card_is_drawed)
	game_state_random.card_AI_is_drawed.connect(_on_ai_card_is_drawed)
	level.human_closed_cycle.connect(_on_human_closed_cycle)
	level.ai_closed_cycle.connect(_on_ai_closed_cycle)

	if not level.player_slots_full.is_connected(_on_player_slots_full):
		level.player_slots_full.connect(_on_player_slots_full)
	if not game_state_random.ai_slots_full.is_connected(_on_ai_slots_full):
		game_state_random.ai_slots_full.connect(_on_ai_slots_full)
	if not level.board_cleared_due_to_full_slots.is_connected(_on_board_cleared_due_to_full_slots):
		level.board_cleared_due_to_full_slots.connect(_on_board_cleared_due_to_full_slots)

	# директни сигнали за край на играта при свършване на карти
	if not level.human_out_of_cards.is_connected(_on_human_out_of_cards):
		level.human_out_of_cards.connect(_on_human_out_of_cards)
	if not level.ai_out_of_cards.is_connected(_on_ai_out_of_cards):
		level.ai_out_of_cards.connect(_on_ai_out_of_cards)

	# deck sizes
	max_player_deck_count = CollectionManager.deck.size()
	max_AI_deck_count = game_state_random.deck.ids.size()

	_update_deck_labels()
	_update_points_labels()
	_update_coefficient_label()

# === DIRECT GAME-END EVENTS (no point checking here) ===
func _on_human_out_of_cards() -> void:
	if _phase != GamePhase.PLAYING: return
	on_lose("You're out of cards!")

func _on_ai_out_of_cards() -> void:
	if _phase != GamePhase.PLAYING: return
	on_win("enemy_no_cards")

# === BOARD FULL BONUS/PENALTY ===
func _on_board_cleared_due_to_full_slots() -> void:
	if _phase != GamePhase.PLAYING: return
	if points_player_get_when_slots_full != 0.0:
		_add_points(true, points_player_get_when_slots_full, PLAYER_FLASH, "slots_full_bonus_player")
	if points_ai_get_when_slots_full != 0.0:
		_add_points(false, points_ai_get_when_slots_full, AI_FLASH, "slots_full_bonus_ai")

# === SLOTS INFO ===
func _on_player_slots_full() -> void:
	print("[GameMaster] Player slots are FULL — player cannot place a card this turn.")

func _on_ai_slots_full() -> void:
	print("[GameMaster] AI slots are FULL — AI cannot place a card this turn.")

# === DRAW EVENTS (only visuals here) ===
func _on_level_card_is_drawed() -> void:
	_update_deck_labels()

func _on_ai_card_is_drawed() -> void:
	_update_deck_labels()

# === SCORING ===
func _on_human_closed_cycle(player_lost: int, ai_lost: int) -> void:
	if _phase != GamePhase.PLAYING: return

	player_lost = max(player_lost, 0)
	ai_lost = max(ai_lost, 0)

	if animation_player: animation_player.play("on_player_get_points")

	var delta := float(player_lost) * coefficient_when_destroy_your_card \
			   + float(ai_lost) * coefficient_when_destroy_enemy_card

	_add_points(true, delta, PLAYER_FLASH, "human_closed_cycle")

func _on_ai_closed_cycle(player_lost: int, ai_lost: int) -> void:
	if _phase != GamePhase.PLAYING: return

	player_lost = max(player_lost, 0)
	ai_lost = max(ai_lost, 0)

	if animation_player: animation_player.play("on_enemy_get_points")

	var delta := float(ai_lost) * coefficient_when_destroy_your_card \
			   + float(player_lost) * coefficient_when_destroy_enemy_card

	_add_points(false, delta, AI_FLASH, "ai_closed_cycle")

# Centralized add-points + UI + win-check
func _add_points(is_player: bool, delta: float, flash: Color, _reason: String) -> void:
	if _phase != GamePhase.PLAYING:
		return
	if delta == 0.0:
		# дори и при нула – ъпдейтни етикетите, но не анимирай
		_update_points_labels()
		return

	if is_player:
		player_points += delta
	else:
		ai_points += delta

	_update_points_labels()

	# лека анимация за обратна връзка
	if delta > 0.0:
		_animate_points_gain((player_points_label if is_player else ai_points_label), flash)


	# проверка за край СЛЕД реално добавени точки
	_check_points_and_end_if_needed()

# === UI HELPERS ===
func _update_points_labels() -> void:
	player_points_label.bbcode_enabled = true
	ai_points_label.bbcode_enabled = true

	# Ограничаваме показваните точки до максимума
	var display_player_points : int = min(player_points, player_points_to_reach)
	var display_ai_points : int = min(ai_points, enemy_points_to_reach)

	var player_points_str := String.num(display_player_points, 2)
	var ai_points_str := String.num(display_ai_points, 2)

	player_points_label.text = "[center][b][color=%s]%s / %d[/color][/b][/center]" % [
		PLAYER_TEXT, player_points_str, player_points_to_reach
	]
	ai_points_label.text = "[center][b][color=%s]%s / %d[/color][/b][/center]" % [
		AI_TEXT, ai_points_str, enemy_points_to_reach
	]


func _update_deck_labels() -> void:
	var remaining_player_cards := max_player_deck_count - level.deck_index
	if remaining_player_cards < 0: remaining_player_cards = 0

	var remaining_ai_cards := game_state_random._ai_deck.size()
	if remaining_ai_cards < 0: remaining_ai_cards = 0

	var player_color := "red" if remaining_player_cards <= 0 else "white"
	var ai_color := "red" if remaining_ai_cards <= 0 else "white"

	player_deck_count_label.text = "[center][color=%s]%d / %d[/color][/center]" % [
		player_color, remaining_player_cards, max_player_deck_count
	]
	ai_deck_count_label.text = "[center][color=%s]%d / %d[/color][/center]" % [
		ai_color, remaining_ai_cards, max_AI_deck_count
	]

func _update_coefficient_label() -> void:
	var player_points_info := ""
	var ai_points_info := ""

	if points_player_get_when_slots_full > 0:
		player_points_info = "[color=#00ff7f]You: +%d pts[/color]" % points_player_get_when_slots_full
	elif points_player_get_when_slots_full < 0:
		player_points_info = "[color=#ff5555]You: %d pts[/color]" % points_player_get_when_slots_full
	else:
		player_points_info = "[color=gray]You: no points[/color]"

	if points_ai_get_when_slots_full > 0:
		ai_points_info = "[color=#ff5555]Enemy: +%d pts[/color]" % points_ai_get_when_slots_full
	elif points_ai_get_when_slots_full < 0:
		ai_points_info = "[color=#00ff7f]Enemy: %d pts[/color]" % points_ai_get_when_slots_full
	else:
		ai_points_info = "[color=gray]Enemy: no points[/color]"

	coefficient_rich_text_label.text = (
		"[center][b]Coefficient:[/b]\n"
		+ "[color=#00ff7f]Your:[/color] x%.1f | [color=#ff5555]Enemy:[/color] x%.1f\n\n"
		+ "[font_size=6][b]Board Full Bonus:[/b]\n"
		+ "%s\n%s[/font_size][/center]"
	) % [
		coefficient_when_destroy_your_card,
		coefficient_when_destroy_enemy_card,
		player_points_info,
		ai_points_info
	]




# === ENDING LOGIC ===
func _check_points_and_end_if_needed() -> void:
	if _phase != GamePhase.PLAYING: return

	if player_points >= float(player_points_to_reach):
		on_win("points_reached (player: %.2f / %d)" % [player_points, player_points_to_reach])
		return

	if ai_points >= float(enemy_points_to_reach):
		on_lose("Your opponent reached the goal score! (ai: [color=red][b]%d / %d[/b][/color])" % [enemy_points_to_reach, enemy_points_to_reach])
		return

func on_win(reason: String = "") -> void:
	if _phase != GamePhase.PLAYING: return
	_phase = GamePhase.WON
	print("[GameMaster] WIN! Reason: %s" % reason)
	emit_signal("game_over", "player")
	if animation_player: animation_player.play("on_win")
	
	_rewards_gain()


func on_lose(reason: String = "") -> void:
	if _phase != GamePhase.PLAYING: return
	_phase = GamePhase.LOST
	print("[GameMaster] LOSE! Reason: %s" % reason)
	emit_signal("game_over", "ai")
	if animation_player: animation_player.play("on_lose")
	lose_info_rich_text_label.text = "[wave]"+reason

# === MICRO FX ===
func _animate_points_gain(label: Control, flash: Color) -> void:
	var orig_scale := label.scale
	var orig_mod := label.modulate
	var tw := create_tween()
	tw.parallel().tween_property(label, "scale", orig_scale * 1.13, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "modulate", flash, 0.10)
	tw.tween_property(label, "scale", orig_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "modulate", orig_mod, 0.18)

func _rewards_gain() -> void:
	LevelManager.add_cleared(cur_level)
	var new_level_count : int = 0
	var new_cards_count : int = 0

	for i in levels_to_unlock_on_win:
		if not LevelManager.is_unlocked(i):
			new_level_count += 1
			LevelManager.add_unlocked(i)
		
	for i in cards_to_unlock_on_win:
		if not CollectionManager.is_unlocked(i):
			new_cards_count += 1
			CollectionManager.unlock(i)
	
	var level_text := ""
	if new_level_count > 0:
		level_text = "+[b]%d[/b] new level%s unlocked" % [new_level_count, "" if new_level_count == 1 else "s"]
	else:
		level_text = "No new levels"

	var card_text := ""
	if new_cards_count > 0:
		card_text = "+[b]%d[/b] new card%s added" % [new_cards_count, "" if new_cards_count == 1 else "s"]
	else:
		card_text = "No new cards"

	reward_info_text_label.text = (
		level_text + "\n" +
		card_text
	)
