extends CharacterBody2D

enum PlayerState { FLYING, DESCENDING }
var state: PlayerState = PlayerState.DESCENDING

var debug_visible := false

# --- HORIZONTAL ---
@export var accel_x: float = 400.0       # aceleración lateral
@export var deaccel_x: float = 320.0     # desaceleración lateral
@export var max_speed_x: float = 220.0   # tope de velocidad lateral

# --- VERTICAL ---
@export var gravity: float = 520.0               # atracción hacia abajo
@export var thrust_accel: float = 720.0          # empuje hacia arriba al mantener fly
@export var max_up_speed: float = -420.0         # tope de subida (negativo)
@export var max_down_speed: float = 700.0        # tope de caída

# --- BOOST DIAGONAL (cuando se mantiene fly + izquierda/derecha) ---
@export var boost_max: float = 1.5               # hasta 1.5x aceleración
@export var boost_gain: float = 2.0              # qué tan rápido sube el boost
@export var boost_decay: float = 1.5             # qué tan rápido cae al soltar
var boost: float = 1.0

# --- LIMITE GLOBAL DE VELOCIDAD (opcional, para diagonales muy fuertes) ---
@export var limit_diagonal_speed: bool = true
@export var max_diag_speed: float = 760.0        # tope vectorial total

# --- CONTROLES ---
@export var allow_horizontal: bool = true        # desactiva para solo “flappy”
@export var input_fly: StringName = "fly"        # Space en el Input Map

# (Opcional) inclinación visual
@export var tilt_amount_deg: float = 12.0
@export var tilt_smooth: float = 8.0

func _ready() -> void:
	_ensure_debug_label()

func _physics_process(delta: float) -> void:
	# INPUT
	var fly := Input.is_action_pressed(input_fly)
	var dir_x := 0.0
	if allow_horizontal:
		dir_x = Input.get_axis("left", "right")
		
	# ESTADO
	state = PlayerState.FLYING if fly else PlayerState.DESCENDING

	# BOOST DIAGONAL (solo mientras hay fly + input lateral)
	var want_boost := fly and absf(dir_x) > 0.0
	if want_boost:
		boost = min(boost + boost_gain * delta, boost_max)
	else:
		boost = max(boost - boost_decay * delta, 1.0)

	# VERTICAL (con rampas suaves estilo up-escape)
	if state == PlayerState.FLYING:
		# Subir acercando velocity.y al tope de subida (negativo) usando aceleración con boost
		velocity.y = move_toward(velocity.y, max_up_speed, thrust_accel * boost * delta)
	else:
		# Caer acercando velocity.y al tope de caída usando gravedad
		velocity.y = move_toward(velocity.y, max_down_speed, gravity * delta)

	# HORIZONTAL (aceleración / desaceleración)
	if allow_horizontal:
		if dir_x != 0.0:
			var target := dir_x * max_speed_x
			velocity.x = move_toward(velocity.x, target, accel_x * boost * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, deaccel_x * delta)
	else:
		velocity.x = 0.0

	# LIMITE VECTORIAL (evita diagonales “cohete”)
	if limit_diagonal_speed and velocity.length() > max_diag_speed:
		velocity = velocity.normalized() * max_diag_speed

	move_and_slide()

	# Tilt visual (opcional)
	var target_tilt := lerpf(-tilt_amount_deg, tilt_amount_deg, inverse_lerp(max_up_speed, max_down_speed, velocity.y))
	rotation_degrees = lerp(rotation_degrees, target_tilt, 1.0 - exp(-tilt_smooth * delta))
	
	if Input.is_action_just_pressed("ui_toggle_debug"):
		debug_visible = not debug_visible
		$DebugLabel.visible = debug_visible

	update_debug_info()

func _ensure_debug_label() -> void:
	if has_node("DebugLabel"):
		return
	var lbl := Label.new()
	lbl.name = "DebugLabel"
	lbl.visible = debug_visible
	lbl.theme = null  # usa tema por defecto
	# Ubicación arriba-izquierda
	lbl.position = Vector2(8, 8)
	# Evitar que se escale con el zoom de cámara (si usás Camera2D con zoom)
	# Si preferís que siga el zoom, omití este CanvasItemMaterial.
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	lbl.material = mat
	add_child(lbl)

func update_debug_info() -> void:
	if not debug_visible or not has_node("DebugLabel"):
		return

	var lines := PackedStringArray()
	# Si tu enum se llama PlayerState:
	var state_name := "?"
	if typeof(state) == TYPE_INT:
		state_name = PlayerState.keys()[state]

	lines.append("STATE: %s" % state_name)
	lines.append("VEL: (%.1f, %.1f)" % [velocity.x, velocity.y])
	lines.append("POS: (%.0f, %.0f)" % [position.x, position.y])

	$DebugLabel.text = "\n".join(lines)
