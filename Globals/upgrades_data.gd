extends Node

func get_deck_size() -> int:
	var deck_level := ItemManager.get_deck_level()
	match deck_level:
		0: return 15
		1: return 20
		2: return 25
		3: return 30
		4: return 35
		5: return 40
		6: return 45
		7: return 50
		8: return 55
		_: return 20

func get_player_points_to_victory_bonus() -> int:
	var player_points_level := ItemManager.get_player_points_level()
	match player_points_level:
		0: return 0
		1: return 1
		2: return 2
		3: return 3
		4: return 4
		5: return 5
		_: return 0
		
func get_enemy_points_to_victory_bonus() -> int:
	var enemy_points_level := ItemManager.get_enemy_points_level()
	match enemy_points_level:
		0: return 0
		1: return 1
		2: return 2
		3: return 3
		4: return 4
		5: return 5
		_: return 0
