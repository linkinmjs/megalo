extends Camera2D

func _physics_process(_delta: float) -> void:
	global_position += Vector2(5, 0)
