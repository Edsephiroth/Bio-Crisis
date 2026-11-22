class_name ElisabethPlayer
extends CharacterBody2D

const WALK_SHEET: Texture2D = preload("res://assets/sprites/elisabeth_sheet.png")
const IDLE_SHEET: Texture2D = preload("res://assets/sprites/elisabeth_idle_sheet.png")

@export var base_speed: float = 175.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var flashlight: PointLight2D = $Flashlight
@onready var camera: Camera2D = $Camera2D

# Row order in elisabeth_sheet.png: 0 = D, 1 = U, 2 = L, 3 = R
var facing_dir: Vector2 = Vector2.DOWN
var dir_row: int = 0
var anim_timer: float = 0.0
var anim_frame: int = 0
var idle_timer: float = 0.0
var is_using_idle_sheet: bool = false

var shake_intensity: float = 0.0
var shake_timer: float = 0.0
var sphere_pulse: float = 0.0


func _ready() -> void:
	add_to_group("player")
	EventBus.screen_shake_requested.connect(_on_screen_shake)
	EventBus.tactical_mode_changed.connect(_on_tactical_changed)
	EventBus.player_stats_changed.connect(queue_redraw)


func _on_screen_shake(intensity: float, duration: float) -> void:
	shake_intensity = maxf(shake_intensity, intensity)
	shake_timer = maxf(shake_timer, duration)


func _on_tactical_changed(_active: bool, _mode_type: String) -> void:
	queue_redraw()


func _process(delta: float) -> void:
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


func _physics_process(delta: float) -> void:
	if GameState.is_world_paused():
		velocity = Vector2.ZERO
		return

	var input_vec: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vec.length() < 0.05 and GameState.virtual_move_vector.length() > 0.05:
		input_vec = GameState.virtual_move_vector

	if input_vec.length() > 1.0:
		input_vec = input_vec.normalized()

	var speed_mult: float = 1.45 if GameState.haste_timer > 0.0 else 1.0
	velocity = input_vec * base_speed * speed_mult
	move_and_slide()

	if input_vec.length() > 0.1:
		if is_using_idle_sheet:
			is_using_idle_sheet = false
			sprite.texture = WALK_SHEET
			sprite.hframes = 8
			sprite.vframes = 4
		sprite.scale = Vector2(0.76, 0.76)

		facing_dir = input_vec.normalized()
		if absf(facing_dir.x) > absf(facing_dir.y):
			dir_row = 3 if facing_dir.x > 0.0 else 2
		else:
			dir_row = 0 if facing_dir.y > 0.0 else 1

		anim_timer += delta * (12.0 if GameState.haste_timer > 0.0 else 9.0)
		if anim_timer >= 1.0:
			anim_timer -= 1.0
			anim_frame = (anim_frame + 1) % 8
			if anim_frame == 2 or anim_frame == 6:
				AudioManager.play_sfx("step", -11.0, 0.14)
		sprite.frame = dir_row * 8 + anim_frame
	else:
		idle_timer += delta * 4.5
		if dir_row == 0:
			if not is_using_idle_sheet:
				is_using_idle_sheet = true
				sprite.texture = IDLE_SHEET
				sprite.hframes = 8
				sprite.vframes = 1
			sprite.frame = int(idle_timer) % 8
			sprite.scale = Vector2(0.76, 0.76)
		else:
			if is_using_idle_sheet:
				is_using_idle_sheet = false
				sprite.texture = WALK_SHEET
				sprite.hframes = 8
				sprite.vframes = 4
			sprite.frame = dir_row * 8
			var breath: float = 1.0 + 0.015 * sin(idle_timer * 1.4)
			sprite.scale = Vector2(0.76, 0.76 * breath)

	# Shift flashlight slightly ahead of Elisabeth
	flashlight.position = Vector2(0, -18) + facing_dir * 34.0


func _draw() -> void:
	# Subtle ground shadow
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 16.0, Color(0.0, 0.0, 0.0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Parasite Eve style tactical targeting dome when paused
	if GameState.is_tactical_paused:
		var r: float = GameState.get_current_range_px()
		var is_energy: bool = GameState.tactical_action_mode == "energy_shot"
		var base_col: Color = Color(0.85, 0.3, 1.0, 1.0) if is_energy else Color(0.15, 0.92, 0.96, 1.0)
		var pulse_alpha: float = 0.10 + 0.04 * sin(sphere_pulse)

		draw_circle(Vector2.ZERO, r, Color(base_col.r, base_col.g, base_col.b, pulse_alpha))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 72, Color(base_col.r, base_col.g, base_col.b, 0.85), 2.5, true)
		draw_arc(Vector2.ZERO, r * 0.65, 0.0, TAU, 48, Color(base_col.r, base_col.g, base_col.b, 0.28), 1.2, true)
		draw_arc(Vector2.ZERO, r * 0.33, 0.0, TAU, 36, Color(base_col.r, base_col.g, base_col.b, 0.22), 1.0, true)

		# Crosshair axis lines
		draw_line(Vector2(-r, 0), Vector2(r, 0), Color(base_col.r, base_col.g, base_col.b, 0.20), 1.0)
		draw_line(Vector2(0, -r), Vector2(0, r), Color(base_col.r, base_col.g, base_col.b, 0.20), 1.0)
