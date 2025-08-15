extends Control

@export var slide_time := 0.6
@export var fade_time := 0.4
@export var extra_left := 80.0  # píxeles extra para salir holgado

@onready var barrel: Node2D = %BarrelHero
@onready var menu_card: Control = %MenuCard
@onready var play_btn: Button = $HBoxContainer/MenuSlot/MenuCard/MarginContainer/VBoxContainer/PlayButton
@onready var options_btn: Button = $HBoxContainer/MenuSlot/MenuCard/MarginContainer/VBoxContainer/OptionsButton
@onready var exit_btn: Button = $HBoxContainer/MenuSlot/MenuCard/MarginContainer/VBoxContainer/ExitButton

func _on_play_button_pressed() -> void:
	# evitar doble click
	play_btn.disabled = true
	options_btn.disabled = true
	exit_btn.disabled = true

	# destino: bien a la izquierda de la pantalla
	var view_w := get_viewport_rect().size.x
	var target_x := barrel.position.x - (view_w + extra_left)

	var t := create_tween()

	# deslizamiento del barril
	t.tween_property(barrel, "position:x", target_x, slide_time)\
	 .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(barrel, "scale", barrel.scale * 0.4, slide_time)

	# en paralelo, desvanecemos la tarjeta del menú
	t.parallel().tween_property(menu_card, "modulate:a", 0.0, fade_time)\
	 .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# cuando termina, arrancamos el juego y cerramos el menú
	t.finished.connect(func ():
		GameManager.start_game()
		GameManager.change_level(0)
		queue_free()
	)

func _on_exit_button_pressed() -> void:
	get_tree().quit()
