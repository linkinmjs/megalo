extends Node

var levels: Array[PackedScene]

func _ready() -> void:
	levels.append(preload("res://scenes/levels/level01.tscn"))
	levels.append(preload("res://scenes/levels/level02.tscn"))

func change_level(value: int):
	var level = levels[value].instantiate()
	add_child(level)

func remove_menu():
	var menu = get_tree().get_first_node_in_group("menu")
	menu.queue_free()
