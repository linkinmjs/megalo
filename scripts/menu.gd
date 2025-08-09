extends Control


func _on_play_button_pressed() -> void:
	queue_free()
	GameManager.change_level(0)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
