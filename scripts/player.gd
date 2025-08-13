extends CharacterBody2D

enum PlayerState { FLYING, DESCENDING }
var state: PlayerState = PlayerState.DESCENDING

@export var gravity: float = 900.0        # qué tan rápido cae
@export var thrust: float = 1400.0        # empuje hacia arriba al mantener fly
@export var max_up_speed: float = -520.0  # velocidad vertical máxima hacia arriba (negativa)
@export var max_down_speed: float = 650.0 # velocidad vertical máxima hacia abajo

@export var horizontal_speed: float = 120.0     # opcional: A/D o ←/→
@export var allow_horizontal: bool = true

# (Opcional) leve inclinación del sprite según la dirección vertical
@export var tilt_amount_deg: float = 10.0
@export var tilt_smooth: float = 8.0

func _physics_process(delta: float) -> void:
	# --- Input ---
	var fly := Input.is_action_pressed("fly")
	var dir_x := 0.0
	if allow_horizontal:
		dir_x = Input.get_axis("left", "right")

	# --- FSM súper simple ---
	if fly:
		state = PlayerState.FLYING
	else:
		state = PlayerState.DESCENDING

	# --- Vertical ---
	if state == PlayerState.FLYING:
		velocity.y -= thrust * delta
	else:
		velocity.y += gravity * delta

	velocity.y = clamp(velocity.y, max_up_speed, max_down_speed)

	# --- Horizontal (opcional) ---
	if allow_horizontal:
		velocity.x = dir_x * horizontal_speed
	else:
		velocity.x = 0.0

	move_and_slide()

	# --- Tilt visual (opcional) ---
	var target_tilt := lerpf(-tilt_amount_deg, tilt_amount_deg, inverse_lerp(max_up_speed, max_down_speed, velocity.y))
	rotation_degrees = lerp(rotation_degrees, target_tilt, 1.0 - exp(-tilt_smooth * delta))

	# --- Hooks para animaciones (si tenés AnimationPlayer/AnimatedSprite2D) ---
	# if $AnimationPlayer:
	#     $AnimationPlayer.play(state == PlayerState.FLYING ? "fly" : "descend")
