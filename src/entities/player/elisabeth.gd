class_name ElisabethPlayer
extends CharacterBody2D

@export var walk_speed: float = 155.0
@export var run_speed: float = 225.0
@export var dash_speed: float = 440.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var flashlight: PointLight2D = $Flashlight
@onready var camera: Camera2D = $Camera2D

var atlas: CharacterAtlas = null
var fallback_walk_tex: Texture2D = null
var char_scale: float = 0.48
var fallback_scale: float = 0.76

# 8-direction rows: 0=D, 1=U, 2=L, 3=R, 4=DL, 5=DR, 6=UL, 7=UR
var facing_dir: Vector2 = Vector2.DOWN
var dir8: int = 0
var anim_elapsed: float = 0.0
var last_step_half: int = -1
var idle_timer: float = 0.0

var dash_timer: float = 0.0
var dash_dir: Vector2 = Vector2.DOWN
var dash_cooldown: float = 0.0

var recoil_velocity: Vector2 = Vector2.ZERO
var recoil_lock_timer: float = 0.0

var shake_intensity: float = 0.0
var shake_timer: float = 0.0
var sphere_pulse: float = 0.0


func _ready() -> void:
	add_to_group("player")
	apply_active_character()
	EventBus.screen_shake_requested.connect(_on_screen_shake)
	EventBus.tactical_mode_changed.connect(_on_tactical_changed)
	EventBus.player_stats_changed.connect(queue_redraw)


func apply_active_character() -> void:
	var ch: Dictionary = GameState.get_active_character()
	var atlas_id: String = str(ch.get("atlas_id", "elisabeth"))
	atlas = CharacterAtlas.get_atlas(atlas_id)
	char_scale = float(ch.get("scale", 0.48))
	fallback_scale = float(ch.get("fallback_scale", 0.76))
	var fb_path: String = str(ch.get("fallback_walk", ""))
	fallback_walk_tex = (load(fb_path) as Texture2D) if fb_path != "" else null
	anim_elapsed = 0.0
	_render_pose("walk", dir8, 0.0, false)


func is_invulnerable() -> bool:
	return dash_timer > 0.0


func apply_recoil(shot_dir: Vector2, push_speed: float, recovery_time: float) -> void:
	if shot_dir.length_squared() < 0.001:
		return
	var back_dir: Vector2 = -shot_dir.normalized()
	recoil_velocity = back_dir * push_speed
	recoil_lock_timer = maxf(recoil_lock_timer, recovery_time)
	facing_dir = shot_dir.normalized()
	dir8 = _vec_to_dir8(facing_dir)


func _vec_to_dir8(v: Vector2) -> int:
	var deg: float = rad_to_deg(v.angle())
	if deg >= -22.5 and deg < 22.5:
		return 3 # R
	elif deg >= 22.5 and deg < 67.5:
		return 5 # DR
	elif deg >= 67.5 and deg < 112.5:
		return 0 # D
	elif deg >= 112.5 and deg < 157.5:
		return 4 # DL
	elif deg >= 157.5 or deg < -157.5:
		return 2 # L
	elif deg >= -157.5 and deg < -112.5:
		return 6 # UL
	elif deg >= -112.5 and deg < -67.5:
		return 1 # U
	else:
		return 7 # UR


func trigger_dash() -> void:
	if GameState.is_world_paused() or dash_cooldown > 0.0 or dash_timer > 0.0:
		return
	var input_vec: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vec.length() < 0.05 and GameState.virtual_move_vector.length() > 0.05:
		input_vec = GameState.virtual_move_vector
	dash_dir = input_vec.normalized() if input_vec.length() > 0.1 else facing_dir
	dir8 = _vec_to_dir8(dash_dir)
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


func _render_pose(action: String, d8: int, elapsed: float, is_idle: bool, speed_mult: float = 1.0) -> void:
	var resolved: Dictionary = atlas.resolve_8dir(action, d8) if atlas != null else {"anim": "", "flip_h": false}
	var anim_name: String = str(resolved.get("anim", ""))
	if atlas != null and anim_name != "":
		var fidx: int = 0 if is_idle else atlas.get_frame_index(anim_name, elapsed, speed_mult)
		atlas.apply_to_sprite(sprite, anim_name, fidx, bool(resolved.get("flip_h", false)))
		if is_idle:
			var wave: float = sin(idle_timer)
			sprite.scale = Vector2(char_scale * (1.0 - 0.008 * wave), char_scale * (1.0 + 0.018 * wave))
			sprite.position = Vector2(0.0, 4.0 - 0.6 * wave)
		else:
			sprite.scale = Vector2(char_scale, char_scale)
			sprite.position = Vector2(0.0, 4.0)
	elif fallback_walk_tex != null:
		# Seamless fallback for Elisabeth's 3 cardinal walk directions (D/U/L/R)
		sprite.texture = fallback_walk_tex
		sprite.hframes = 8
		sprite.vframes = 8
		sprite.centered = true
		sprite.offset = Vector2.ZERO
		sprite.flip_h = false
		var fidx_fb: int = 0 if is_idle else (int(elapsed * 9.5 * speed_mult) % 8)
		sprite.frame = d8 * 8 + fidx_fb
		if is_idle:
			var wave2: float = sin(idle_timer)
			sprite.scale = Vector2(fallback_scale * (1.0 - 0.008 * wave2), fallback_scale * (1.0 + 0.018 * wave2))
			sprite.position = Vector2(0.0, -34.0 - 0.6 * wave2)
		else:
			sprite.scale = Vector2(fallback_scale, fallback_scale)
			sprite.position = Vector2(0.0, -34.0)


func _physics_process(delta: float) -> void:
	if GameState.is_world_paused():
		velocity = Vector2.ZERO
		return

	if GameState.poison_timer > 0.0:
		sprite.modulate = Color(0.75, 1.15, 0.72, 1.0)
	elif GameState.stiff_timer > 0.0:
		sprite.modulate = Color(0.7, 0.8, 1.2, 1.0)
	else:
		sprite.modulate = Color.WHITE

	# Physical weapon recoil knockback & posture recovery
	if recoil_lock_timer > 0.0 or recoil_velocity.length() > 8.0:
		recoil_lock_timer = maxf(0.0, recoil_lock_timer - delta)
		velocity = recoil_velocity
		move_and_slide()
		recoil_velocity = recoil_velocity.move_toward(Vector2.ZERO, 920.0 * delta)
		_render_pose("walk", dir8, 0.0, true)
		if recoil_lock_timer > 0.0:
			return

	# Realistic evade/sprint burst: accelerated 8-dir run frames, no supernatural VFX
	if dash_timer > 0.0:
		dash_timer -= delta
		velocity = dash_dir * dash_speed
		move_and_slide()
		anim_elapsed += delta
		_render_pose("run", dir8, anim_elapsed, false, 1.75)
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

	var is_running: bool = (raw_len > 0.75) if using_joy else Input.is_action_pressed("run")

	var speed_mult: float = 1.35 if GameState.haste_timer > 0.0 else 1.0
	if GameState.stiff_timer > 0.0:
		speed_mult *= 0.55

	var base_spd: float = run_speed if is_running else walk_speed
	velocity = input_vec * base_spd * speed_mult
	move_and_slide()

	if raw_len > 0.1:
		facing_dir = input_vec.normalized()
		dir8 = _vec_to_dir8(facing_dir)
		var anim_speed: float = (1.25 if GameState.haste_timer > 0.0 else 1.0)
		anim_elapsed += delta
		_render_pose("run" if is_running else "walk", dir8, anim_elapsed, false, anim_speed)

		# Subtle synced footstep cadence (~2.6 steps/sec walk, ~3.8 steps/sec run)
		var step_rate: float = (3.8 if is_running else 2.6) * anim_speed
		var step_tick: int = int(anim_elapsed * step_rate)
		if step_tick != last_step_half:
			last_step_half = step_tick
			AudioManager.play_sfx("step", -11.0, 0.14)
	else:
		idle_timer += delta * 3.2
		last_step_half = -1
		_render_pose("walk", dir8, 0.0, true)

	flashlight.position = Vector2(0, -18) + facing_dir * 34.0


func _draw() -> void:
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 16.0, Color(0.0, 0.0, 0.0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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
