class_name UIController
extends CanvasLayer

@onready var paused_panel: Panel = $PausedPanel

func _on_pause_button_button_down() -> void:
	paused_panel.visible = true


func _on_play_button_button_down() -> void:
	paused_panel.visible = false


func _on_exit_button_button_down() -> void:
	pass # Replace with function body.
