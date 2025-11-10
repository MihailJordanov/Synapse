class_name UpgradePanel
extends Control

enum UpgradeType {
	DECK_LEVEL,
	PLAY_POINTS_TO_REACH,
	ENEMY_POINTS_TO_REACH
}

@export var upgrade_type: UpgradeType
@export var max_level: int = 5
