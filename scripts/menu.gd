extends Control

func _on_play_button_pressed() -> void:
	GameManager.start_game()
	GameManager.change_level(0)
	queue_free()

func _on_quit_button_pressed() -> void:
	get_tree().quit()
