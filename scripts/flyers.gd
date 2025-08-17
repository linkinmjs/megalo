extends Node2D

@export var speed := 180.0
@export var bob_amp := 8.0
@export var bob_freq := 1.2
var dir := 1.0
var t := 0.0

func _process(delta: float) -> void:
	t += delta
	position.x += speed * dir * delta
	position.y += sin(t * TAU * bob_freq) * bob_amp * delta

	# Autodestruir si sale de pantalla (con margen)
	var rect := get_viewport().get_visible_rect().grow(64)
	if not rect.has_point(global_position):
		queue_free()
