extends Node

@export var level_paths: PackedStringArray = [
	"res://scenes/levels/level00.tscn",
	"res://scenes/levels/level01.tscn"
]

var levels: Array[PackedScene] = []
var current_level: CanvasLayer
var current_index: int = 0
var is_changing := false

var fade_rect: ColorRect    # se inicializa en _ensure_fade()

func _ready() -> void:
	# Cargar escenas
	for p in level_paths:
		var scn := load(p)
		if scn is PackedScene:
			levels.append(scn)
	if levels.is_empty():
		push_error("GameManager: no hay niveles en level_paths.")
		return

	# Asegurar overlay de fade (lo crea si no existe)
	_ensure_fade()

	# Instanciar primer nivel
	_spawn_level(0)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("action") and not is_changing:
		var next_index := (current_index + 1) % levels.size()
		change_level(next_index)

func change_level(next_index: int) -> void:
	if is_changing or next_index == current_index:
		return
	is_changing = true

	var old_level := current_level

	# Fade out a negro
	var t := create_tween()
	t.tween_property(fade_rect, "modulate:a", 1.0, 0.3).from(fade_rect.modulate.a)
	t.finished.connect(func ():
		# Swap durante negro
		if old_level:
			old_level.queue_free()

		var new_level := levels[next_index].instantiate() as CanvasLayer
		if new_level == null:
			push_error("El nivel no es CanvasLayer/ParallaxBackground.")
			is_changing = false
			return

		add_child(new_level)
		current_level = new_level
		current_index = next_index

		# Fade in
		var t2 := create_tween()
		t2.tween_property(fade_rect, "modulate:a", 0.0, 0.3)
		t2.finished.connect(func ():
			is_changing = false
		)
	)

func _spawn_level(index: int) -> void:
	var lvl := levels[index].instantiate() as CanvasLayer
	if lvl == null:
		push_error("El nivel no es CanvasLayer/ParallaxBackground.")
		return
	add_child(lvl)
	current_level = lvl
	current_index = index

func _ensure_fade() -> void:
	# Busca un overlay existente (opcional)
	if has_node("FadeLayer/Fade"):
		fade_rect = get_node("FadeLayer/Fade") as ColorRect
		return

	# Crea CanvasLayer + ColorRect pantalla completa
	var layer := CanvasLayer.new()
	layer.name = "FadeLayer"
	layer.layer = 100   # por encima de todo
	add_child(layer)

	var cr := ColorRect.new()
	cr.name = "Fade"
	cr.color = Color(0, 0, 0, 1)   # negro
	cr.modulate.a = 0.0            # transparente inicial
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Anclar a pantalla completa
	cr.anchor_left = 0.0
	cr.anchor_top = 0.0
	cr.anchor_right = 1.0
	cr.anchor_bottom = 1.0
	cr.offset_left = 0.0
	cr.offset_top = 0.0
	cr.offset_right = 0.0
	cr.offset_bottom = 0.0

	layer.add_child(cr)
	fade_rect = cr
