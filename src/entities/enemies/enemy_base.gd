class_name EnemyBase
extends CharacterBody2D

enum AIState { IDLE, CHASE, WINDUP, SHOCKWAVE_WINDUP, COOLDOWN }

@export var enemy_key: String = ""
@export var bestiary_id: String = "deformed_common"
@export var enemy_name: String = "Deformed Attendee"
@export var is_boss: bool = false
@export var max_hp: int = 95
@export var move_speed: float = 76.0
@export var attack_damage: int = 38
@export var attack_range: float = 52.0
@export var detection_range: float = 360.0
@export var exp_reward: int = 4
@export var bp_reward: int = 18

@onready var sprite: Sprite2D = $Sprite2D
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var hp: int = 95
var boss_phase: int = 1
var state: AIState = AIState.IDLE
var state_timer: float = 0.0
var shockwave_cooldown: float = 4.5
var nav_repath_timer: float = 0.0
var anim_timer: float = 0.0
var anim_frame: int = 0
var dir_row: int = 0 # 0 = D, 1 = U
var hit_flash_timer: float = 0.0
var is_in_tactical_range: bool = false
var is_targeted_hover: bool = false


func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")
	EventBus.tactical_mode_changed.connect(_on_tactical_changed)
	if is_boss:
		EventBus.boss_status_changed.emit(true, enemy_name, hp, max_hp, boss_phase)


func _on_tactical_changed(_active: bool, _mode_type: String) -> void:
	queue_redraw()


func _process(delta: float) -> void:
	if hit_flash_timer > 0.0:
		hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
		sprite.modulate = Color(2.4, 1.4, 1.4, 1.0)
	elif state == AIState.WINDUP or state == AIState.SHOCKWAVE_WINDUP:
		sprite.modulate = Color(1.65, 0.45, 0.45, 1.0)
	elif is_boss and boss_phase == 2:
		sprite.modulate = Color(1.25, 0.8, 0.95, 1.0)
	else:
		sprite.modulate = Color.WHITE

	if GameState.is_tactical_paused:
		var player: Node2D = _get_player()
		if player != null:
			var dist: float = global_position.distance_to(player.global_position)
			is_in_tactical_range = dist <= GameState.get_current_range_px()
		queue_redraw()
	else:
		is_in_tactical_range = false
		is_targeted_hover = false
		if hp < max_hp or state == AIState.WINDUP or state == AIState.SHOCKWAVE_WINDUP:
			queue_redraw()


func _physics_process(delta: float) -> void:
	if GameState.is_world_paused():
		velocity = Vector2.ZERO
		return

	var player: Node2D = _get_player()
	if player == null:
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()

	if is_boss and boss_phase == 2 and shockwave_cooldown > 0.0:
		shockwave_cooldown -= delta

	match state:
		AIState.IDLE:
			velocity = Vector2.ZERO
			if dist <= detection_range:
				state = AIState.CHASE

		AIState.CHASE:
			if is_boss and boss_phase == 2 and shockwave_cooldown <= 0.0 and dist <= 135.0:
				state = AIState.SHOCKWAVE_WINDUP
				state_timer = 0.85
				velocity = Vector2.ZERO
				AudioManager.play_sfx("tactical_open", -3.0, 0.15)
				queue_redraw()
			elif dist <= attack_range:
				state = AIState.WINDUP
				state_timer = 0.50 if (is_boss and boss_phase == 2) else 0.58
				velocity = Vector2.ZERO
				queue_redraw()
			elif dist > detection_range * 1.45 and not is_boss:
				state = AIState.IDLE
				velocity = Vector2.ZERO
			else:
				nav_repath_timer -= delta
				if nav_repath_timer <= 0.0:
					nav_repath_timer = 0.16
					nav_agent.target_position = player.global_position

				var next_pos: Vector2 = nav_agent.get_next_path_position()
				var dir: Vector2 = (next_pos - global_position)
				if dir.length_squared() < 4.0:
					dir = to_player
				dir = dir.normalized()

				var spd: float = move_speed * (1.28 if (is_boss and boss_phase == 2) else 1.0)
				velocity = dir * spd
				move_and_slide()
				dir_row = 1 if dir.y < -0.2 else 0
				sprite.flip_h = dir.x < -0.15
				anim_timer += delta * 7.5
				if anim_timer >= 1.0:
					anim_timer -= 1.0
					anim_frame = (anim_frame + 1) % 6
				sprite.frame = dir_row * 6 + anim_frame

		AIState.WINDUP:
			velocity = Vector2.ZERO
			state_timer -= delta
			if state_timer <= 0.0:
				if dist <= attack_range + 24.0:
					GameState.apply_damage(attack_damage, player.global_position)
				state = AIState.COOLDOWN
				state_timer = 0.95 if (is_boss and boss_phase == 2) else 1.15
				queue_redraw()

		AIState.SHOCKWAVE_WINDUP:
			velocity = Vector2.ZERO
			state_timer -= delta
			queue_redraw()
			if state_timer <= 0.0:
				AudioManager.play_sfx("energy_shot", -2.0, 0.15)
				EventBus.screen_shake_requested.emit(9.0, 0.3)
				if dist <= 122.0:
					GameState.apply_damage(int(round(float(attack_damage) * 1.35)), player.global_position)
				shockwave_cooldown = 5.0
				state = AIState.COOLDOWN
				state_timer = 1.0
				queue_redraw()

		AIState.COOLDOWN:
			velocity = Vector2.ZERO
			state_timer -= delta
			if state_timer <= 0.0:
				state = AIState.CHASE


func take_damage(amount: int, is_crit: bool = false) -> void:
	hp = maxi(0, hp - amount)
	hit_flash_timer = 0.16
	AudioManager.play_sfx("hit_enemy", -3.0, 0.09)
	var col: Color = Color(1.0, 0.9, 0.25) if is_crit else Color(1.0, 0.95, 0.95)
	var label: String = "%d CRIT!" % amount if is_crit else "%d" % amount
	EventBus.floating_text_requested.emit(label, global_position + Vector2(0, -52), col)

	if is_boss and boss_phase == 1 and hp > 0 and hp <= int(max_hp * 0.5):
		boss_phase = 2
		AudioManager.play_sfx("energy_shot", -1.5, 0.12)
		EventBus.screen_shake_requested.emit(8.0, 0.35)
		EventBus.toast_message.emit("FASE 2: MUTANTE ALFA EM SOBRECARGA MITOCONDRIAL!", Color(1.0, 0.32, 0.38))

	if is_boss:
		EventBus.boss_status_changed.emit(hp > 0, enemy_name, hp, max_hp, boss_phase)

	queue_redraw()

	if hp <= 0:
		if enemy_key != "":
			GameState.defeated_enemy_keys[enemy_key] = true
		GameState.register_bestiary_kill(bestiary_id)
		EventBus.enemy_defeated.emit(enemy_name, exp_reward, bp_reward, global_position)
		GameState.award_exp_and_bp(exp_reward, bp_reward, global_position)
		queue_free()


func _get_player() -> Node2D:
	var nodes: Array[Node] = get_tree().get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	return nodes[0] as Node2D


func _draw() -> void:
	# Ground shadow
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 17.0, Color(0.0, 0.0, 0.0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Melee telegraph ring
	if state == AIState.WINDUP:
		draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 32, Color(1.0, 0.2, 0.2, 0.88), 2.5, true)

	# Boss Phase 2 expanding shockwave telegraph
	if state == AIState.SHOCKWAVE_WINDUP:
		var prog: float = clampf(1.0 - (state_timer / 0.85), 0.0, 1.0)
		var rad: float = lerpf(32.0, 120.0, prog)
		draw_circle(Vector2.ZERO, rad, Color(1.0, 0.15, 0.35, 0.16))
		draw_arc(Vector2.ZERO, 120.0, 0.0, TAU, 48, Color(1.0, 0.2, 0.3, 0.85), 2.5, true)
		draw_arc(Vector2.ZERO, rad, 0.0, TAU, 48, Color(1.0, 0.8, 0.3, 0.9), 2.0, true)

	# Tactical reticle when in range during pause
	if GameState.is_tactical_paused and is_in_tactical_range:
		var reticle_col: Color = Color(1.0, 0.85, 0.2, 0.95) if is_targeted_hover else Color(0.2, 1.0, 0.9, 0.85)
		draw_arc(Vector2(0, -24), 26.0, 0.0, TAU, 32, reticle_col, 2.5, true)
		draw_line(Vector2(-32, -24), Vector2(-18, -24), reticle_col, 2.0)
		draw_line(Vector2(18, -24), Vector2(32, -24), reticle_col, 2.0)
		draw_line(Vector2(0, -56), Vector2(0, -42), reticle_col, 2.0)
		draw_line(Vector2(0, -6), Vector2(0, 8), reticle_col, 2.0)

	# Compact HP bar (hidden for boss because boss has dedicated HUD Boss Health Bar)
	if not is_boss and (hp < max_hp or GameState.is_tactical_paused):
		var bar_w: float = 44.0
		var bar_h: float = 5.0
		var top_left: Vector2 = Vector2(-bar_w * 0.5, -68.0)
		draw_rect(Rect2(top_left, Vector2(bar_w, bar_h)), Color(0.08, 0.08, 0.12, 0.85))
		var ratio: float = clampf(float(hp) / float(max_hp), 0.0, 1.0)
		draw_rect(Rect2(top_left, Vector2(bar_w * ratio, bar_h)), Color(0.92, 0.22, 0.28, 0.95))
