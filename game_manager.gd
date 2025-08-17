extends Node

@export var level_paths: PackedStringArray = [
	"res://scenes/levels/level00.tscn",
	"res://scenes/levels/level01.tscn",
	"res://scenes/levels/level02.tscn",
	"res://scenes/levels/level03.tscn",
	"res://scenes/levels/level04.tscn",
	"res://scenes/levels/level05.tscn",
	"res://scenes/levels/level06.tscn",
	"res://scenes/levels/level07.tscn",
]

@export var player_scene: PackedScene = preload("res://scenes/player/player.tscn")
@export var song_stream: AudioStream = preload("res://assets/sounds/background/Megalo.mp3")
@export var wind_scene: PackedScene = preload("res://scenes/effects/wind_particles.tscn")

# Actores “del cielo”
@export var bird_scene: PackedScene = preload("res://scenes/actors/bird.tscn")
# @export var mini_barrel_scene: PackedScene = preload("res://scenes/actors/mini_barrel.tscn")
@export var midlayer_index: int = 3               # si querés insertarla en un índice concreto (no requerido)
@export var midlayer_motion := Vector2(0.6, 0.6)  # parallax “entre” fondo y primer plano

var music: AudioStreamPlayer
var levels: Array[PackedScene] = []
var current_level: CanvasLayer
var current_index: int = 0
var is_changing := false

var fade_rect: ColorRect
var actor_layer: CanvasLayer         # capa donde va el Player
var player: Node2D                   # referencia al Player

var effects_layer: CanvasLayer       # capa donde va el Viento (y otros fx si querés)
var wind: GPUParticles2D             # referencia al Viento

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

	# Cargar escenas de niveles
	for p in level_paths:
		var scn := load(p)
		if scn is PackedScene:
			levels.append(scn)
	if levels.is_empty():
		push_error("GameManager: no hay niveles en level_paths.")
		return

	# Capas auxiliares persistentes
	_ensure_fade()
	_ensure_actor_layer()
	_ensure_effects_layer()
	_spawn_wind_once()

	# Instanciar primer nivel (solo background)
	_spawn_level(0)


# -------------------------------------------------------------------
# UI / flujo de juego
# -------------------------------------------------------------------
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

	# Entrada desde la izquierda
	var size := get_viewport().get_visible_rect().size
	var start_pos := Vector2(-0.25 * size.x, size.y * 0.5)
	var end_pos := Vector2(size.x * 0.3,  size.y * 0.5)

	player.position = start_pos

	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(player, "position", end_pos, 0.9)

func _input(event: InputEvent) -> void:
	# Cambiar de nivel con E (acción "action")
	if event.is_action_pressed("action") and not is_changing:
		var next_index := (current_index + 1) % levels.size()
		change_level(next_index)

	# Spawnear actor intermedio con Q (acción "spawn_extra")
	if event.is_action_pressed("spawn_extra") and current_level:
		_spawn_mid_actor("bird")  # por ahora solo aves; cambiar a "barrel" si sumás la otra escena


func change_level(next_index: int) -> void:
	if is_changing or next_index == current_index:
		return
	is_changing = true

	var old_level := current_level

	# Fade out
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
		# asegurar Player por encima dentro del GameManager
		if actor_layer.get_parent() == self:
			move_child(actor_layer, get_child_count() - 1)

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

	# Solo actor_layer arriba dentro del GameManager (effects_layer cuelga de root)
	if actor_layer.get_parent() == self:
		move_child(actor_layer, get_child_count() - 1)


# -------------------------------------------------------------------
# Viento / FX persistentes
# -------------------------------------------------------------------
func _ensure_effects_layer() -> void:
	var root := get_tree().root
	var existing := root.find_child("EffectsLayer", true, false)
	if existing:
		effects_layer = existing as CanvasLayer
		if effects_layer.get_parent() != root:
			var old_parent := effects_layer.get_parent()
			old_parent.call_deferred("remove_child", effects_layer)
			root.call_deferred("add_child", effects_layer)
	else:
		effects_layer = CanvasLayer.new()
		effects_layer.name = "EffectsLayer"
		effects_layer.layer = 5
		root.call_deferred("add_child", effects_layer)

	# <<< NUEVO: deduplicar en el próximo frame >>>
	call_deferred("_dedupe_wind")


func _spawn_wind_once() -> void:
	# si effects_layer todavía no está en el árbol (por deferred), esperamos
	if effects_layer == null or effects_layer.get_parent() == null:
		await get_tree().process_frame

	if wind:
		return
	if not wind_scene:
		push_warning("No hay wind_scene asignada.")
		return

	var winds := get_tree().get_nodes_in_group("wind")
	if winds.size() > 0:
		# ya existe alguno: dejá que _dedupe_wind lo ordene
		call_deferred("_dedupe_wind")
		return

	# crear uno nuevo (único)
	var w := wind_scene.instantiate() as GPUParticles2D
	if w == null:
		push_warning("wind_scene no es GPUParticles2D.")
		return
	w.add_to_group("wind")
	# opcional visual:
	# w.local_coords = false
	# w.preprocess = 6.0
	effects_layer.add_child(w)
	w.emitting = true
	wind = w



# -------------------------------------------------------------------
# Fade / ActorLayer / Música
# -------------------------------------------------------------------
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
	actor_layer.layer = 10
	add_child(actor_layer)

func _ensure_music() -> void:
	if music: return
	music = AudioStreamPlayer.new()
	music.name = "MusicPlayer"
	music.bus = "Music"   # o "Master"
	music.stream = song_stream
	music.volume_db = -6.0
	add_child(music)


# -------------------------------------------------------------------
# Parallax helpers y spawner de actores intermedios (Q)
# -------------------------------------------------------------------
func _get_parallax() -> ParallaxBackground:
	if current_level == null:
		return null

	if current_level is ParallaxBackground:
		return current_level as ParallaxBackground

	var by_name := current_level.find_child("ParallaxBackground", true, false)
	if by_name is ParallaxBackground:
		return by_name as ParallaxBackground

	var stack: Array[Node] = [current_level]
	while not stack.is_empty():
		var n: Node = stack.pop_back() as Node
		if n is ParallaxBackground:
			return n as ParallaxBackground
		for c in n.get_children():
			stack.append(c as Node)
	return null

func _get_or_make_midlayer() -> ParallaxLayer:
	var par := _get_parallax()
	if par == null:
		push_warning("No hay ParallaxBackground en el nivel actual.")
		return null

	var mid := par.get_node_or_null("MidActors") as ParallaxLayer
	if mid:
		return mid

	mid = ParallaxLayer.new()
	mid.name = "MidActors"
	mid.motion_scale = midlayer_motion
	par.add_child(mid)
	# Si querés forzar posición entre layers:
	# par.move_child(mid, clampi(midlayer_index, 0, par.get_child_count()-1))
	return mid

func _spawn_mid_actor(kind: String) -> void:
	var mid := _get_or_make_midlayer()
	if not mid: return

	# Por ahora solo aves; si agregás mini_barrel, elegí según 'kind'
	var scene: PackedScene = bird_scene
	if not scene:
		push_warning("No hay escena para %s" % kind)
		return

	var actor := scene.instantiate() as Node2D
	mid.add_child(actor)  # cuelga del NIVEL → se destruye al cambiar con E

	var rect := get_viewport().get_visible_rect()
	var from_left := (rng.randi() & 1) == 0
	var y := rng.randf_range(rect.size.y * 0.25, rect.size.y * 0.8)
	var x := (-48.0 if from_left else rect.size.x + 48.0)
	actor.global_position = Vector2(x, y)

	var dir := (1.0 if from_left else -1.0)
	if actor.has_method("set"):
		actor.set("dir", dir)
		# opcional: si tu script acepta speed
		if actor.has_method("set"):
			actor.set("speed", rng.randf_range(120.0, 260.0))

	var spr := actor.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if spr:
		spr.flip_h = not from_left
		if spr.sprite_frames and spr.sprite_frames.has_animation("fly"):
			spr.play("fly")
		else:
			spr.play()

func _dedupe_wind() -> void:
	# Asegurarnos de tener EffectsLayer en el árbol
	if effects_layer == null or effects_layer.get_parent() == null:
		await get_tree().process_frame

	var winds := get_tree().get_nodes_in_group("wind")
	if winds.is_empty():
		# no hay ninguno, crear uno
		_spawn_wind_once()
		return

	# Elegimos el "sobreviviente":
	var survivor: GPUParticles2D = winds[0] as GPUParticles2D
	for w in winds:
		if w.get_parent() == effects_layer:
			survivor = w as GPUParticles2D
			break

	# Reparent del sobreviviente al EffectsLayer
	if survivor.get_parent() != effects_layer:
		var old_parent := survivor.get_parent()
		if old_parent:
			old_parent.call_deferred("remove_child", survivor)
		effects_layer.call_deferred("add_child", survivor)

	# Borrar duplicados
	for w in winds:
		if w != survivor and w is GPUParticles2D:
			(w as GPUParticles2D).queue_free()

	# Si quedó algún CanvasLayer vacío (como ese @CanvasLayer@2), limpiarlo
	var root := get_tree().root
	var stray_layers := []
	for n in root.get_children():
		if n is CanvasLayer and n != effects_layer:
			# ¿tiene algún hijo en grupo "wind"?
			var has_wind := false
			for c in n.get_children():
				if c.is_in_group("wind"):
					has_wind = true
					break
			# si no tiene viento y no tiene otros hijos, lo podemos retirar
			if not has_wind and n.get_child_count() == 0:
				stray_layers.append(n)
	for s in stray_layers:
		(root as Node).call_deferred("remove_child", s)

	# Set final
	wind = survivor
	wind.emitting = true
