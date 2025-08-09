extends Node

var levels: Array[PackedScene]
var actual_level_scene: ParallaxBackground
var actual_level = 0

func _ready() -> void:
	levels.append(preload("res://scenes/levels/level00.tscn"))
	levels.append(preload("res://scenes/levels/level01.tscn"))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		print(actual_level)
		actual_level += 1
		change_level(actual_level)

func change_level(value: int):
	if actual_level_scene:
		actual_level_scene.queue_free()
	var level = levels[value].instantiate()
	add_child(level)
	actual_level_scene = level
