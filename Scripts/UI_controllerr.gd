class_name UIController
extends CanvasLayer

@export_file("*.tscn") var menu_scene_path: String = "res://Scenes/Scenes_In_Game/map.tscn"


@onready var paused_panel: Panel = $PausedPanel
@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"

func _on_pause_button_button_down() -> void:
	paused_panel.visible = true


func _on_play_button_button_down() -> void:
	paused_panel.visible = false


func _on_exit_button_button_down() -> void:
	animation_player.play("closeScene")
	await animation_player.animation_finished
	get_tree().change_scene_to_file(menu_scene_path)
