class_name ElisabethPlayer
extends CharacterBody2D

const WALK_SHEET: Texture2D = preload("res://assets/sprites/elisabeth_sheet.png")
const RUN_SHEET: Texture2D = preload("res://assets/sprites/elisabeth_run_sheet.png")

@export var walk_speed: float = 155.0
@export var run_speed: float = 225.0
@export var dash_speed: float = 440.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var flashlight: PointLight2D = $Flashlight
@onready var camera: Camera2D = $Camera2D

# Row order in sheets: 0 = D, 1 = U, 2 = L, 3 = R
var facing_dir: Vector2 = Vector2.DOWN
var dir_row: int = 0
var anim_timer: float = 0.0
var anim_frame: int = 0
var idle_timer: float = 0.0
var active_sheet_mode: String = "walk" # "walk", "run"

var dash_timer: float = 0.0
var dash_dir: Vector2 = Vector2.DOWN
var dash_cooldown: float = 0.0

var shake_intensity: float = 0.0
var shake_timer: float = 0.0
var sphere_pulse: float = 0.0


func _ready() -> void:
	add_to_group("player")
	EventBus.screen_shake_requested.connect(_on_screen_shake)
	EventBus.tactical_mode_changed.connect(_on_tactical_changed)
	EventBus.player_stats_changed.connect(queue_redraw)


func is_invulnerable() -> bool:
	return dash_timer > 0.0


func trigger_dash() -> void:
	if GameState.is_world_paused() or dash_cooldown > 0.0 or dash_timer > 0.0:
		return
	var input_vec: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vec.length() < 0.05 and GameState.virtual_move_vector.length() > 0.05:
		input_vec = GameState.virtual_move_vector
	dash_dir = input_vec.normalized() if input_vec.length() > 0.1 else facing_dir
	if absf(dash_dir.x) > absf(dash_dir.y):
		dir_row = 3 if dash_dir.x > 0.0 else 2
	else:
		dir_row = 0 if dash_dir.y > 0.0 else 1
	dash_timer = 0.24
	dash_cooldown = 2.0
	AudioManager.play_sfx("dash", -4.0, 0.06)


func _on_screen_shake(intensity: float, duration: float) -> void:
	shake_intensity = maxf(shake_intensity, intensity)
	shake_timer = maxf(shake_timer, duration)


func _on_tactical_changed(_active: bool, _mode_type: String) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dash"):
		trigger_dash()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if dash_cooldown > 0.0 and not GameState.is_world_paused():
		dash_cooldown = maxf(0.0, dash_cooldown - delta)

	if shake_timer > 0.0:
		shake_timer = maxf(0.0, shake_timer - delta)
		camera.offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
	else:
		camera.offset = Vector2.ZERO

	if GameState.is_tactical_paused:
		sphere_pulse += delta * 3.0
		queue_redraw()


func _set_sheet_mode(mode: String) -> void:
	if active_sheet_mode == mode:
		return
	active_sheet_mode = mode
	if mode == "run":
		sprite.texture = RUN_SHEET
		sprite.hframes = 8
		sprite.vframes = 4
	else:
		sprite.texture = WALK_SHEET
		sprite.hframes = 8
		sprite.vframes = 4


func _physics_process(delta: float) -> void:
	if GameState.is_world_paused():
		velocity = Vector2.ZERO
		return

	# Subtle tint only for negative status ailments
	if GameState.poison_timer > 0.0:
		sprite.modulate = Color(0.75, 1.15, 0.72, 1.0)
	elif GameState.stiff_timer > 0.0:
		sprite.modulate = Color(0.7, 0.8, 1.2, 1.0)
	else:
		sprite.modulate = Color.WHITE

	# Realistic evade/sprint burst: faster run animation frames, no supernatural VFX
	if dash_timer > 0.0:
		dash_timer -= delta
		velocity = dash_dir * dash_speed
		move_and_slide()
		_set_sheet_mode("run")
		sprite.scale = Vector2(0.76, 0.76)
		sprite.position = Vector2(0, -34)
		anim_timer += delta * 24.0
		if anim_timer >= 1.0:
			anim_timer -= 1.0
			anim_frame = (anim_frame + 1) % 8
		sprite.frame = dir_row * 8 + anim_frame
		flashlight.position = Vector2(0, -18) + dash_dir * 34.0
		return

	var input_vec: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var using_joy: bool = false
	if input_vec.length() < 0.05 and GameState.virtual_move_vector.length() > 0.05:
		input_vec = GameState.virtual_move_vector
		using_joy = true

	var raw_len: float = input_vec.length()
	if raw_len > 1.0:
		input_vec = input_vec.normalized()

	# Hold Shift on PC (or push virtual joystick > 75% on mobile) to run; otherwise walk
	var is_running: bool = (raw_len > 0.75) if using_joy else Input.is_action_pressed("run")

	var speed_mult: float = 1.35 if GameState.haste_timer > 0.0 else 1.0
	if GameState.stiff_timer > 0.0:
		speed_mult *= 0.55

	var base_spd: float = run_speed if is_running else walk_speed
	velocity = input_vec * base_spd * speed_mult
	move_and_slide()

	if raw_len > 0.1:
		_set_sheet_mode("run" if is_running else "walk")
		sprite.scale = Vector2(0.76, 0.76)
		sprite.position = Vector2(0, -34)

		facing_dir = input_vec.normalized()
		if absf(facing_dir.x) > absf(facing_dir.y):
			dir_row = 3 if facing_dir.x > 0.0 else 2
		else:
			dir_row = 0 if facing_dir.y > 0.0 else 1

		var fps: float = (13.0 if is_running else 9.0) * (1.25 if GameState.haste_timer > 0.0 else 1.0)
		anim_timer += delta * fps
		if anim_timer >= 1.0:
			anim_timer -= 1.0
			anim_frame = (anim_frame + 1) % 8
			if anim_frame == 2 or anim_frame == 6:
				AudioManager.play_sfx("step", -11.0, 0.14)
		sprite.frame = dir_row * 8 + anim_frame
	else:
		idle_timer += delta * 3.2
		_set_sheet_mode("walk")
		sprite.frame = dir_row * 8
		var wave: float = sin(idle_timer)
		var breath_y: float = 1.0 + 0.018 * wave
		var breath_x: float = 1.0 - 0.008 * wave
		sprite.scale = Vector2(0.76 * breath_x, 0.76 * breath_y)
		sprite.position = Vector2(0, -34.0 - 0.6 * wave)

	flashlight.position = Vector2(0, -18) + facing_dir * 34.0


func _draw() -> void:
	# Subtle ground shadow
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 16.0, Color(0.0, 0.0, 0.0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Tactical targeting range dome when paused
	if GameState.is_tactical_paused:
		var r: float = GameState.get_current_range_px()
		var is_energy: bool = GameState.tactical_action_mode == "energy_shot"
		var base_col: Color = Color(0.85, 0.3, 1.0, 1.0) if is_energy else Color(0.15, 0.92, 0.96, 1.0)
		var pulse_alpha: float = 0.10 + 0.04 * sin(sphere_pulse)

		draw_circle(Vector2.ZERO, r, Color(base_col.r, base_col.g, base_col.b, pulse_alpha))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 72, Color(base_col.r, base_col.g, base_col.b, 0.85), 2.5, true)
		draw_arc(Vector2.ZERO, r * 0.65, 0.0, TAU, 48, Color(base_col.r, base_col.g, base_col.b, 0.28), 1.2, true)
		draw_arc(Vector2.ZERO, r * 0.33, 0.0, TAU, 36, Color(base_col.r, base_col.g, base_col.b, 0.22), 1.0, true)

		draw_line(Vector2(-r, 0), Vector2(r, 0), Color(base_col.r, base_col.g, base_col.b, 0.20), 1.0)
		draw_line(Vector2(0, -r), Vector2(0, r), Color(base_col.r, base_col.g, base_col.b, 0.20), 1.0)
