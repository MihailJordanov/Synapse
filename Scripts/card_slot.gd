class_name CardSlot
extends Node2D

var card_in_slot = false

@export var is_card_in_test :  bool = false
@onready var panel: Panel = $Panel

func _ready() -> void:
	card_in_slot = is_card_in_test
	if is_card_in_test:
		panel.visible = true
	pass
