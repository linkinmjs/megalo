extends Node

@export var level_paths: PackedStringArray = [
	"res://scenes/levels/level00.tscn",
	"res://scenes/levels/level01.tscn"
]
@export var player_scene: PackedScene = preload("res://scenes/player/player.tscn")
@export var song_stream: AudioStream = preload("res://assets/sounds/background/Megalo.mp3")

var music: AudioStreamPlayer
var levels: Array[PackedScene] = []
var current_level: CanvasLayer
var current_index: int = 0
var is_changing := false

var fade_rect: ColorRect
var actor_layer: CanvasLayer           # capa donde va el Player
var player: Node2D                     # referencia al Player

func _ready() -> void:
	# Cargar escenas
	for p in level_paths:
		var scn := load(p)
		if scn is PackedScene:
			levels.append(scn)
	if levels.is_empty():
		push_error("GameManager: no hay niveles en level_paths.")
		return

	# Capas auxiliares
	_ensure_fade()
	_ensure_actor_layer()

	# Instanciar primer nivel (solo background)
	_spawn_level(0)

# Llamado por el botón Play del menú
func start_game() -> void:
	if player: return
	_spawn_player_intro()
	_ensure_music()
	if not music.playing:
		music.play()

func _spawn_player_intro() -> void:
	if not player_scene:
		push_error("Asigná player_scene en GameManager.")
		return

	player = player_scene.instantiate() as Node2D
	if not player:
		push_error("Player.tscn no es Node2D.")
		return

	actor_layer.add_child(player)

	# Colocar fuera de pantalla a la izquierda
	var size := get_viewport().get_visible_rect().size
	var start_pos := Vector2(-0.25 * size.x, size.y * 0.5)  # 25% fuera de pantalla
	var end_pos := Vector2(size.x * 0.3, size.y * 0.5)      # centro

	player.position = start_pos

	# Animación de entrada
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(player, "position", end_pos, 0.9)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("action") and not is_changing:
		var next_index := (current_index + 1) % levels.size()
		change_level(next_index)

func change_level(next_index: int) -> void:
	if is_changing or next_index == current_index:
		return
	is_changing = true

	var old_level := current_level

	var t := create_tween()
	t.tween_property(fade_rect, "modulate:a", 1.0, 0.3).from(fade_rect.modulate.a)
	t.finished.connect(func ():
		if old_level:
			old_level.queue_free()

		var new_level := levels[next_index].instantiate() as CanvasLayer
		if new_level == null:
			push_error("El nivel no es CanvasLayer/ParallaxBackground.")
			is_changing = false
			return

		add_child(new_level)
		move_child(actor_layer, get_child_count()-1)  # asegurar Player por encima
		current_level = new_level
		current_index = next_index

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
	# Mantener actor_layer al tope
	move_child(actor_layer, get_child_count()-1)

func _ensure_fade() -> void:
	if has_node("FadeLayer/Fade"):
		fade_rect = get_node("FadeLayer/Fade") as ColorRect
		return

	var layer := CanvasLayer.new()
	layer.name = "FadeLayer"
	layer.layer = 100
	add_child(layer)

	var cr := ColorRect.new()
	cr.name = "Fade"
	cr.color = Color(0, 0, 0, 1)
	cr.modulate.a = 0.0
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE

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

func _ensure_actor_layer() -> void:
	if has_node("ActorLayer"):
		actor_layer = get_node("ActorLayer") as CanvasLayer
		return
	actor_layer = CanvasLayer.new()
	actor_layer.name = "ActorLayer"
	actor_layer.layer = 10  # por encima de backgrounds (que suelen estar en 0)
	add_child(actor_layer)

func _ensure_music() -> void:
	if music: return
	music = AudioStreamPlayer.new()
	music.name = "MusicPlayer"
	music.bus = "Music"  # o "Master" si no creaste el bus Music
	music.stream = song_stream
	music.volume_db = -6.0
	add_child(music)
