class_name EnemyBase
extends CharacterBody2D

enum AIState { IDLE, CHASE, WINDUP, SPIT_WINDUP, SHOCKWAVE_WINDUP, SHOCK, COOLDOWN, DYING }

@export var enemy_key: String = ""
@export var bestiary_id: String = "deformed_common"
@export var enemy_name: String = "Executiva Deformada"
@export var is_boss: bool = false
@export var max_hp: int = 95
@export var move_speed: float = 76.0
@export var attack_damage: int = 38
@export var attack_range: float = 54.0
@export var detection_range: float = 360.0
@export var exp_reward: int = 4
@export var bp_reward: int = 18

@onready var sprite: Sprite2D = $Sprite2D
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var hp: int = 95
var boss_phase: int = 1
var arms_hp: int = 160
var arms_broken: bool = false

var acid_dot_timer: float = 0.0
var _acid_accum: float = 0.0
var frost_timer: float = 0.0

var state: AIState = AIState.IDLE
var state_timer: float = 0.0
var spit_cooldown: float = 3.2
var shockwave_cooldown: float = 4.5
var nav_repath_timer: float = 0.0
var anim_timer: float = 0.0
var anim_frame: int = 0
var dir_row: int = 0
var dir8: int = 0
var hit_flash_timer: float = 0.0
var is_in_tactical_range: bool = false
var is_targeted_hover: bool = false

# CharacterAtlas support (Executiva Deformada 27-animation atlas for non-boss enemies)
var atlas: CharacterAtlas = null
var atlas_scale: float = 0.48
var anim_elapsed: float = 0.0
var active_anim_name: String = ""
var death_anim_name: String = "morte_death_baixo"
var death_fade_timer: float = 0.0


func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")
	EventBus.tactical_mode_changed.connect(_on_tactical_changed)
	if not is_boss:
		atlas = CharacterAtlas.get_atlas("executiva")
		if atlas != null:
			sprite.scale = Vector2(atlas_scale, atlas_scale)
			sprite.position = Vector2(0.0, 4.0)
			_play_atlas_action("idle", dir8, 0.0)
	if is_boss:
		EventBus.boss_status_changed.emit(true, enemy_name, hp, max_hp, boss_phase)


func _on_tactical_changed(_active: bool, _mode_type: String) -> void:
	queue_redraw()


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


func _play_atlas_action(action: String, d8: int, elapsed: float, speed_mult: float = 1.0) -> void:
	if atlas == null:
		return
	var res: Dictionary = atlas.resolve_8dir(action, d8)
	var aname: String = str(res.get("anim", ""))
	if aname == "":
		return
	var fidx: int = atlas.get_frame_index(aname, elapsed, speed_mult)
	atlas.apply_to_sprite(sprite, aname, fidx, bool(res.get("flip_h", false)))
	sprite.scale = Vector2(atlas_scale, atlas_scale)
	sprite.position = Vector2(0.0, 4.0)


func _play_atlas_exact(anim_name: String, elapsed: float, flip_h: bool = false, speed_mult: float = 1.0) -> void:
	if atlas == null or not atlas.has_anim(anim_name):
		return
	var fidx: int = atlas.get_frame_index(anim_name, elapsed, speed_mult)
	atlas.apply_to_sprite(sprite, anim_name, fidx, flip_h)
	sprite.scale = Vector2(atlas_scale, atlas_scale)
	sprite.position = Vector2(0.0, 4.0)


func _process(delta: float) -> void:
	if state == AIState.DYING:
		if not GameState.is_world_paused():
			anim_elapsed += delta
			if atlas != null and atlas.has_anim(death_anim_name):
				_play_atlas_exact(death_anim_name, anim_elapsed, false, 1.35)
				if atlas.is_one_shot_finished(death_anim_name, anim_elapsed, 1.35):
					death_fade_timer += delta
					sprite.modulate = Color(1.0, 1.0, 1.0, clampf(1.0 - death_fade_timer / 0.75, 0.0, 1.0))
					if death_fade_timer >= 0.75:
						queue_free()
			else:
				queue_free()
		return

	if not GameState.is_world_paused():
		if frost_timer > 0.0:
			frost_timer = maxf(0.0, frost_timer - delta)
		if acid_dot_timer > 0.0:
			acid_dot_timer = maxf(0.0, acid_dot_timer - delta)
			_acid_accum += delta
			if _acid_accum >= 1.0:
				_acid_accum -= 1.0
				take_damage(10, false, "body", true)

	if hit_flash_timer > 0.0:
		hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
		sprite.modulate = Color(2.4, 1.4, 1.4, 1.0)
	elif state == AIState.SHOCK:
		sprite.modulate = Color(0.7, 0.95, 1.6, 1.0)
	elif state == AIState.WINDUP or state == AIState.SHOCKWAVE_WINDUP:
		sprite.modulate = Color(1.5, 0.65, 0.65, 1.0)
	elif state == AIState.SPIT_WINDUP:
		sprite.modulate = Color(0.55, 1.55, 0.55, 1.0)
	elif frost_timer > 0.0 or GameState.slow_timer > 0.0:
		sprite.modulate = Color(0.55, 0.82, 1.4, 1.0)
	elif acid_dot_timer > 0.0:
		sprite.modulate = Color(0.7, 1.25, 0.55, 1.0)
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
		if hp < max_hp or state != AIState.IDLE:
			queue_redraw()


func _physics_process(delta: float) -> void:
	if state == AIState.DYING:
		velocity = Vector2.ZERO
		return
	if GameState.is_world_paused():
		velocity = Vector2.ZERO
		return

	var player: ElisabethPlayer = _get_player()
	if player == null:
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()

	if spit_cooldown > 0.0:
		spit_cooldown -= delta
	if is_boss and boss_phase == 2 and shockwave_cooldown > 0.0:
		shockwave_cooldown -= delta

	match state:
		AIState.IDLE:
			velocity = Vector2.ZERO
			if atlas != null:
				anim_elapsed += delta
				_play_atlas_action("idle", dir8, anim_elapsed, 1.0)
			if dist <= detection_range:
				state = AIState.CHASE
				anim_elapsed = 0.0

		AIState.CHASE:
			if is_boss and boss_phase == 2 and shockwave_cooldown <= 0.0 and dist <= 140.0:
				state = AIState.SHOCKWAVE_WINDUP
				state_timer = 0.85
				velocity = Vector2.ZERO
				AudioManager.play_sfx("tactical_open", -3.0, 0.15)
				queue_redraw()
			elif dist <= attack_range:
				state = AIState.WINDUP
				state_timer = 0.50 if (is_boss and boss_phase == 2) else 0.65
				anim_elapsed = 0.0
				dir8 = _vec_to_dir8(to_player.normalized())
				velocity = Vector2.ZERO
				queue_redraw()
			elif spit_cooldown <= 0.0 and dist > 105.0 and dist <= 290.0:
				state = AIState.SPIT_WINDUP
				state_timer = 0.55
				dir8 = _vec_to_dir8(to_player.normalized())
				velocity = Vector2.ZERO
				queue_redraw()
			elif dist > detection_range * 1.45 and not is_boss:
				state = AIState.IDLE
				anim_elapsed = 0.0
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
				var slow_mult: float = 0.52 if (GameState.slow_timer > 0.0 or frost_timer > 0.0) else 1.0
				velocity = dir * spd * slow_mult
				move_and_slide()

				if atlas != null:
					dir8 = _vec_to_dir8(dir)
					anim_elapsed += delta
					_play_atlas_action("walk", dir8, anim_elapsed, 1.35 * slow_mult)
				else:
					dir_row = 1 if dir.y < -0.2 else 0
					sprite.flip_h = dir.x < -0.15
					anim_timer += delta * 7.5 * slow_mult
					if anim_timer >= 1.0:
						anim_timer -= 1.0
						anim_frame = (anim_frame + 1) % 6
					sprite.frame = dir_row * 6 + anim_frame

		AIState.WINDUP:
			velocity = Vector2.ZERO
			state_timer -= delta
			if atlas != null:
				anim_elapsed += delta
				_play_atlas_action("attack", dir8, anim_elapsed, 2.8)
			if state_timer <= 0.0:
				if dist <= attack_range + 24.0 and not player.is_invulnerable():
					var dmg: int = int(round(float(attack_damage) * (0.65 if arms_broken else 1.0)))
					GameState.apply_damage(dmg, player.global_position)
					if is_boss and randf() < 0.35:
						GameState.apply_status("stiff", 5.0, player.global_position)
				state = AIState.COOLDOWN
				state_timer = 0.95 if (is_boss and boss_phase == 2) else 1.15
				anim_elapsed = 0.0
				queue_redraw()

		AIState.SPIT_WINDUP:
			velocity = Vector2.ZERO
			state_timer -= delta
			if atlas != null:
				anim_elapsed += delta
				_play_atlas_action("attack", dir8, anim_elapsed, 2.2)
			if state_timer <= 0.0:
				var dir: Vector2 = (player.global_position - global_position).normalized()
				var proj_dmg: int = int(round(float(attack_damage) * 0.65))
				var status_fx: String = "darkness" if is_boss else "poison"
				EventBus.enemy_projectile_spawned.emit(global_position + Vector2(0, -24), dir, proj_dmg, status_fx)
				spit_cooldown = 3.4 if is_boss else 4.8
				state = AIState.COOLDOWN
				state_timer = 0.65
				anim_elapsed = 0.0
				queue_redraw()

		AIState.SHOCKWAVE_WINDUP:
			velocity = Vector2.ZERO
			state_timer -= delta
			queue_redraw()
			if state_timer <= 0.0:
				AudioManager.play_sfx("energy_shot", -2.0, 0.15)
				EventBus.screen_shake_requested.emit(9.0, 0.3)
				if dist <= 122.0 and not player.is_invulnerable():
					var dmg: int = int(round(float(attack_damage) * (0.85 if arms_broken else 1.35)))
					GameState.apply_damage(dmg, player.global_position)
				shockwave_cooldown = 5.0
				state = AIState.COOLDOWN
				state_timer = 1.0
				queue_redraw()

		AIState.SHOCK:
			velocity = Vector2.ZERO
			state_timer -= delta
			if atlas != null:
				anim_elapsed += delta
				var shock_anim: String = "choque_shock_cima" if (dir8 == 1 or dir8 == 6 or dir8 == 7) else "choque_shock_baixo"
				_play_atlas_exact(shock_anim, anim_elapsed, false, 2.4)
			if state_timer <= 0.0:
				state = AIState.CHASE
				anim_elapsed = 0.0

		AIState.COOLDOWN:
			velocity = Vector2.ZERO
			state_timer -= delta
			if atlas != null:
				anim_elapsed += delta
				_play_atlas_action("idle", dir8, anim_elapsed, 1.0)
			if state_timer <= 0.0:
				state = AIState.CHASE
				anim_elapsed = 0.0


func is_chilled() -> bool:
	return frost_timer > 0.0 or GameState.slow_timer > 0.0


func apply_weapon_perks(perks: PackedStringArray) -> void:
	if state == AIState.DYING:
		return
	if perks.has("acid"):
		acid_dot_timer = 6.0
		EventBus.floating_text_requested.emit("ACID!", global_position + Vector2(0, -68), Color(0.55, 1.0, 0.35))
	if perks.has("frost"):
		frost_timer = 6.0
		EventBus.floating_text_requested.emit("FROST!", global_position + Vector2(0, -68), Color(0.45, 0.85, 1.0))


func take_damage(amount: int, is_crit: bool = false, hit_part: String = "body", is_dot: bool = false) -> void:
	if state == AIState.DYING:
		return
	var final_dmg: int = amount
	var extra_tag: String = ""

	if is_boss and not is_dot:
		if hit_part == "core":
			final_dmg = int(round(float(amount) * 1.45))
			is_crit = true
			extra_tag = " [NÚCLEO]"
		elif hit_part == "arms" and not arms_broken:
			arms_hp = maxi(0, arms_hp - final_dmg)
			extra_tag = " [BRAÇOS]"
			if arms_hp <= 0:
				arms_broken = true
				EventBus.toast_message.emit("BRAÇOS DO MUTANTE ALFA DESTRUÍDOS! Ataque reduzido em 35%!", Color(1.0, 0.82, 0.25))
				EventBus.floating_text_requested.emit("BRAÇOS QUEBRADOS!", global_position + Vector2(0, -78), Color(1.0, 0.82, 0.25))

	hp = maxi(0, hp - final_dmg)
	hit_flash_timer = 0.14 if is_dot else 0.16
	if not is_dot:
		AudioManager.play_sfx("hit_enemy", -3.0, 0.09)

	var col: Color = Color(0.55, 1.0, 0.4) if is_dot else (Color(1.0, 0.9, 0.25) if is_crit else Color(1.0, 0.95, 0.95))
	var label: String = ("%d CRIT!%s" % [final_dmg, extra_tag]) if is_crit else ("%d%s" % [final_dmg, extra_tag])
	EventBus.floating_text_requested.emit(label, global_position + Vector2(0, -52), col)

	if is_boss and boss_phase == 1 and hp > 0 and hp <= int(max_hp * 0.5):
		boss_phase = 2
		AudioManager.play_sfx("energy_shot", -1.5, 0.12)
		EventBus.screen_shake_requested.emit(8.0, 0.35)
		EventBus.toast_message.emit("FASE 2: MUTANTE ALFA EM SOBRECARGA!", Color(1.0, 0.32, 0.38))

	if is_boss:
		EventBus.boss_status_changed.emit(hp > 0, enemy_name, hp, max_hp, boss_phase)

	# Trigger Executiva Deformada shock/stagger animation on strong/crit hits
	if hp > 0 and atlas != null and not is_dot and (is_crit or final_dmg >= 42):
		state = AIState.SHOCK
		state_timer = 0.42
		anim_elapsed = 0.0

	queue_redraw()

	if hp <= 0:
		if enemy_key != "":
			GameState.defeated_enemy_keys[enemy_key] = true
		GameState.register_bestiary_kill(bestiary_id)
		remove_from_group("enemies")
		collision_layer = 0
		collision_mask = 0
		EventBus.enemy_defeated.emit(enemy_name, exp_reward, bp_reward, global_position)
		GameState.award_exp_and_bp(exp_reward, bp_reward, global_position)
		if atlas != null:
			state = AIState.DYING
			anim_elapsed = 0.0
			death_fade_timer = 0.0
			var facing_up: bool = (dir8 == 1 or dir8 == 6 or dir8 == 7)
			if is_crit or final_dmg >= 45:
				death_anim_name = "morte_forte_forte_cima_1" if facing_up else "morte_forte_forte_baixo_1"
			else:
				death_anim_name = "morte_death_baixo"
			queue_redraw()
		else:
			queue_free()


func _get_player() -> ElisabethPlayer:
	var nodes: Array[Node] = get_tree().get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	return nodes[0] as ElisabethPlayer


func _draw() -> void:
	if state == AIState.DYING:
		return

	draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 17.0, Color(0.0, 0.0, 0.0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if state == AIState.WINDUP:
		draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 32, Color(1.0, 0.2, 0.2, 0.88), 2.5, true)
	elif state == AIState.SPIT_WINDUP:
		draw_arc(Vector2(0, -24), 22.0, 0.0, TAU, 24, Color(0.4, 1.0, 0.35, 0.9), 2.2, true)
	elif state == AIState.SHOCKWAVE_WINDUP:
		var prog: float = clampf(1.0 - (state_timer / 0.85), 0.0, 1.0)
		var rad: float = lerpf(32.0, 120.0, prog)
		draw_circle(Vector2.ZERO, rad, Color(1.0, 0.15, 0.35, 0.16))
		draw_arc(Vector2.ZERO, 120.0, 0.0, TAU, 48, Color(1.0, 0.2, 0.3, 0.85), 2.5, true)
		draw_arc(Vector2.ZERO, rad, 0.0, TAU, 48, Color(1.0, 0.8, 0.3, 0.9), 2.0, true)

	# Tactical reticle (cyan inside range = 100% dmg; amber outside range = reduced falloff dmg!)
	if GameState.is_tactical_paused:
		var reticle_col: Color = Color(0.2, 1.0, 0.9, 0.9) if is_in_tactical_range else Color(1.0, 0.62, 0.2, 0.72)
		draw_arc(Vector2(0, -24), 26.0, 0.0, TAU, 32, reticle_col, 2.5, true)
		draw_line(Vector2(-32, -24), Vector2(-18, -24), reticle_col, 2.0)
		draw_line(Vector2(18, -24), Vector2(32, -24), reticle_col, 2.0)
		draw_line(Vector2(0, -56), Vector2(0, -42), reticle_col, 2.0)
		draw_line(Vector2(0, -6), Vector2(0, 8), reticle_col, 2.0)

	if not is_boss and (hp < max_hp or GameState.is_tactical_paused):
		var bar_w: float = 44.0
		var bar_h: float = 5.0
		var top_left: Vector2 = Vector2(-bar_w * 0.5, -72.0)
		draw_rect(Rect2(top_left, Vector2(bar_w, bar_h)), Color(0.08, 0.08, 0.12, 0.85))
		var ratio: float = clampf(float(hp) / float(max_hp), 0.0, 1.0)
		draw_rect(Rect2(top_left, Vector2(bar_w * ratio, bar_h)), Color(0.92, 0.22, 0.28, 0.95))
