class_name ChildrenFirstHall
extends Node2D

## Multi-room Prologue controller for Children First NGO (Gala Hall -> East Corridor -> Main Hall Boss).

const TILE_SIZE: int = 48
const ENEMY_SCENE: PackedScene = preload("res://src/entities/enemies/deformed_common.tscn")

@onready var player: ElisabethPlayer = $Entities/Elisabeth
@onready var entities_root: Node2D = $Entities
@onready var fx_layer: Node2D = $FxLayer
@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var emergency_light: PointLight2D = $Lights/EmergencyLight
@onready var safe_light: PointLight2D = $Lights/SafeRoomLight
@onready var walls_body: StaticBody2D = $WallsBody
@onready var nav_region: NavigationRegion2D = $NavigationRegion2D
@onready var occluders_root: Node2D = $Occluders
@onready var vignette_rect: ColorRect = $PostProcess/Vignette

var current_room: Dictionary = {}
var layout_rows: Array = []
var map_cols: int = 22
var map_rows: int = 16
var src_tile_size: int = 48
var ground_tex: Texture2D = null
var struct_tex: Texture2D = null
var props_tex: Texture2D = null

var safe_room_rect: Rect2 = Rect2()
var active_doors: Array = []
var active_pickups: Array = []
var nearby_interactable: Dictionary = {}

var tracer_lines: Array[Dictionary] = []
var floating_texts: Array[Dictionary] = []
var enemy_projectiles: Array[Dictionary] = []
var pending_burst_shots: Array[Dictionary] = []
var emergency_time: float = 0.0
var pending_victory_after_dialogue: bool = false


func _ready() -> void:
	var loaded_from_save: bool = false
	if GameState.pending_load_from_save:
		GameState.pending_load_from_save = false
		loaded_from_save = GameState.load_game()
	if not loaded_from_save:
		GameState.reset_run()

	AudioManager.start_ambient_bgm()
	EventBus.enemy_defeated.connect(_on_enemy_defeated)
	EventBus.floating_text_requested.connect(_on_floating_text)
	EventBus.weapon_fired.connect(_on_weapon_fired)
	EventBus.enemy_projectile_spawned.connect(_on_enemy_projectile_spawned)
	EventBus.dialogue_finished.connect(_on_dialogue_finished)

	if loaded_from_save:
		var spawn_t: Vector2 = Vector2(-1, -1)
		if GameState.saved_player_pos.x > 0.0:
			spawn_t = GameState.saved_player_pos / float(TILE_SIZE)
		load_room(GameState.current_room_id, spawn_t)
		EventBus.toast_message.emit("Jogo carregado com sucesso!", Color(0.4, 1.0, 0.72))
	else:
		load_room("gala_hall", Vector2(-1, -1))


func load_room(room_id: String, custom_spawn_tile: Vector2) -> void:
	current_room = RoomDatabase.get_room(room_id)
	GameState.current_room_id = room_id
	layout_rows = current_room["layout"] as Array
	map_rows = layout_rows.size()
	map_cols = str(layout_rows[0]).length()
	src_tile_size = int(current_room.get("src_tile_size", 48))

	ground_tex = load(str(current_room["ground_tex"])) as Texture2D
	struct_tex = load(str(current_room["struct_tex"])) as Texture2D
	props_tex = load(str(current_room["props_tex"])) as Texture2D

	canvas_modulate.color = current_room.get("ambient_color", Color(0.32, 0.36, 0.46, 1.0)) as Color
	emergency_light.color = current_room.get("emergency_color", Color(1.0, 0.25, 0.25, 1.0)) as Color
	var epos: Vector2 = current_room.get("emergency_pos", Vector2(11, 7)) as Vector2
	emergency_light.position = epos * float(TILE_SIZE)

	var has_safe: bool = bool(current_room.get("has_safe_room", false))
	safe_light.visible = has_safe
	if has_safe:
		var sr: Rect2 = current_room["safe_room_tiles"] as Rect2
		safe_room_rect = Rect2(sr.position * float(TILE_SIZE), sr.size * float(TILE_SIZE))
		safe_light.position = safe_room_rect.get_center()
	else:
		safe_room_rect = Rect2()
		GameState.in_safe_room = false

	for child in walls_body.get_children():
		child.queue_free()
	for child in occluders_root.get_children():
		child.queue_free()
	for node in get_tree().get_nodes_in_group("enemies"):
		node.queue_free()

	tracer_lines.clear()
	floating_texts.clear()
	enemy_projectiles.clear()
	EventBus.boss_status_changed.emit(false, "", 0, 1, 1)

	active_doors = (current_room.get("doors", []) as Array).duplicate(true)
	active_pickups = []
	for p in (current_room.get("pickups", []) as Array):
		var pd: Dictionary = p as Dictionary
		if not GameState.collected_pickups.has(str(pd["id"])):
			active_pickups.append(pd.duplicate(true))

	var spawn_tile: Vector2 = custom_spawn_tile
	if spawn_tile.x < 0.0:
		spawn_tile = current_room.get("default_spawn", Vector2(10.5, 12.5)) as Vector2
	player.global_position = spawn_tile * float(TILE_SIZE)

	_build_room_geometry_and_spawns(room_id)
	_bake_navigation_mesh()
	queue_redraw()
	fx_layer.queue_redraw()

	# Quickdraw perk fills ATB when entering a room with active threats
	var has_threats: bool = not get_tree().get_nodes_in_group("enemies").is_empty()
	AudioManager.set_combat_music(has_threats)
	if has_threats and GameState.has_weapon_perk("quickdraw"):
		GameState.atb = 100.0
		EventBus.player_stats_changed.emit()

	var title: String = str(current_room.get("title", room_id))
	EventBus.room_changed.emit(title)
	EventBus.toast_message.emit(title, Color(0.75, 0.92, 1.0))

	# Trigger one-time room intro dialogue
	var intro_id: String = str(current_room.get("intro_dialogue", ""))
	if intro_id != "" and not GameState.seen_dialogues.has(intro_id):
		GameState.seen_dialogues[intro_id] = true
		call_deferred("_trigger_dialogue_by_id", intro_id)


func _trigger_dialogue_by_id(dialogue_id: String) -> void:
	var lines: Array[Dictionary] = RoomDatabase.get_dialogue(dialogue_id)
	if not lines.is_empty():
		EventBus.dialogue_requested.emit(lines)


func _build_room_geometry_and_spawns(room_id: String) -> void:
	var enemy_idx: int = 0
	for y in range(map_rows):
		var row: String = str(layout_rows[y])
		for x in range(map_cols):
			var ch: String = row[x]
			var center: Vector2 = Vector2((x + 0.5) * TILE_SIZE, (y + 0.5) * TILE_SIZE)
			if ch == "#":
				var col_shape := CollisionShape2D.new()
				var rect := RectangleShape2D.new()
				rect.size = Vector2(TILE_SIZE, TILE_SIZE)
				col_shape.shape = rect
				col_shape.position = center
				walls_body.add_child(col_shape)

				if x > 0 and x < map_cols - 1 and y > 0 and y < map_rows - 1:
					_add_wall_occluder(x, y)
			elif ch == "E":
				var key: String = "%s_e_%d_%d" % [room_id, x, y]
				if not GameState.defeated_enemy_keys.has(key):
					_spawn_enemy(center, false, enemy_idx, key)
				enemy_idx += 1
			elif ch == "B":
				var bkey: String = "%s_boss" % room_id
				if not GameState.defeated_enemy_keys.has(bkey):
					_spawn_enemy(center, true, enemy_idx, bkey)
				enemy_idx += 1


func _add_wall_occluder(tx: int, ty: int) -> void:
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	var x0: float = float(tx * TILE_SIZE) + 2.0
	var y0: float = float(ty * TILE_SIZE) + 2.0
	var x1: float = float((tx + 1) * TILE_SIZE) - 2.0
	var y1: float = float((ty + 1) * TILE_SIZE) - 2.0
	poly.polygon = PackedVector2Array([
		Vector2(x0, y0),
		Vector2(x1, y0),
		Vector2(x1, y1),
		Vector2(x0, y1),
	])
	occ.occluder = poly
	occluders_root.add_child(occ)


func _bake_navigation_mesh() -> void:
	var nav_poly := NavigationPolygon.new()
	nav_poly.agent_radius = 16.0
	var source_data := NavigationMeshSourceGeometryData2D.new()

	var w: float = float(map_cols * TILE_SIZE)
	var h: float = float(map_rows * TILE_SIZE)
	source_data.add_traversable_outline(PackedVector2Array([
		Vector2(TILE_SIZE, TILE_SIZE),
		Vector2(w - TILE_SIZE, TILE_SIZE),
		Vector2(w - TILE_SIZE, h - TILE_SIZE),
		Vector2(TILE_SIZE, h - TILE_SIZE),
	]))

	for y in range(1, map_rows - 1):
		var row: String = str(layout_rows[y])
		for x in range(1, map_cols - 1):
			if row[x] == "#":
				var x0: float = float(x * TILE_SIZE)
				var y0: float = float(y * TILE_SIZE)
				var x1: float = float((x + 1) * TILE_SIZE)
				var y1: float = float((y + 1) * TILE_SIZE)
				source_data.add_obstruction_outline(PackedVector2Array([
					Vector2(x0, y0),
					Vector2(x1, y0),
					Vector2(x1, y1),
					Vector2(x0, y1),
				]))

	NavigationServer2D.bake_from_source_geometry_data(nav_poly, source_data)
	nav_region.navigation_polygon = nav_poly


func _spawn_enemy(pos: Vector2, is_alpha: bool, idx: int, key: String) -> void:
	var enemy: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
	enemy.global_position = pos
	enemy.enemy_key = key
	if is_alpha:
		enemy.is_boss = true
		enemy.bestiary_id = "alpha_mutant"
		enemy.enemy_name = "MUTANTE ALFA (ORGANISMUS PRIMUS)"
		enemy.max_hp = 520
		enemy.move_speed = 86.0
		enemy.attack_damage = 58
		enemy.detection_range = 700.0
		enemy.exp_reward = 25
		enemy.bp_reward = 120
		enemy.scale = Vector2(1.42, 1.42)
	else:
		enemy.enemy_name = "Deformed Attendee #%d" % (idx + 1)
		enemy.max_hp = 95 + (idx % 2) * 20
		enemy.move_speed = 74.0 + float(idx % 3) * 6.0
	entities_root.add_child(enemy)


func _process(delta: float) -> void:
	GameState.tick_realtime(delta)

	emergency_time += delta * 2.8
	emergency_light.energy = 0.75 + 0.45 * sin(emergency_time)

	# Check safe room
	var now_safe: bool = safe_room_rect.size.x > 0.0 and safe_room_rect.has_point(player.global_position)
	if now_safe != GameState.in_safe_room:
		GameState.in_safe_room = now_safe
		EventBus.safe_room_state_changed.emit(now_safe)
		if now_safe:
			EventBus.toast_message.emit("SAFE ROOM: Recuperando HP e PE...", Color(0.3, 1.0, 0.55))

	# Detect nearby interactable (pickup or door)
	_update_nearby_interactable()

	# Update visual tracers & floating texts
	var redraw_fx: bool = true # keep pulsing markers smooth
	for i in range(tracer_lines.size() - 1, -1, -1):
		tracer_lines[i]["ttl"] = float(tracer_lines[i]["ttl"]) - delta
		if float(tracer_lines[i]["ttl"]) <= 0.0:
			tracer_lines.remove_at(i)

	for i in range(floating_texts.size() - 1, -1, -1):
		floating_texts[i]["ttl"] = float(floating_texts[i]["ttl"]) - delta
		floating_texts[i]["pos"] = (floating_texts[i]["pos"] as Vector2) + Vector2(0, -34.0 * delta)
		if float(floating_texts[i]["ttl"]) <= 0.0:
			floating_texts.remove_at(i)

	# Update enemy projectiles
	if not GameState.is_world_paused():
		for i in range(enemy_projectiles.size() - 1, -1, -1):
			var pr: Dictionary = enemy_projectiles[i]
			pr["ttl"] = float(pr["ttl"]) - delta
			var ppos: Vector2 = (pr["pos"] as Vector2) + (pr["vel"] as Vector2) * delta
			pr["pos"] = ppos
			var tx: int = int(ppos.x / float(TILE_SIZE))
			var ty: int = int(ppos.y / float(TILE_SIZE))
			var hit_wall: bool = ty < 0 or ty >= map_rows or tx < 0 or tx >= map_cols or str(layout_rows[ty])[tx] == "#"
			if hit_wall or float(pr["ttl"]) <= 0.0:
				enemy_projectiles.remove_at(i)
				continue
			if ppos.distance_to(player.global_position + Vector2(0, -18)) <= 20.0:
				if not player.is_invulnerable():
					GameState.apply_damage(int(pr["damage"]), player.global_position)
					var st: String = str(pr.get("status", ""))
					if st != "" and randf() < 0.65:
						GameState.apply_status(st, 7.0, player.global_position)
				else:
					EventBus.floating_text_requested.emit("ESQUIVOU!", player.global_position + Vector2(0, -52), Color(0.35, 0.95, 1.0))
				enemy_projectiles.remove_at(i)

	# Process sequential weapon burst shots (SMG / M93R / Rifle / Pistol)
	if not GameState.is_world_paused():
		for i in range(pending_burst_shots.size() - 1, -1, -1):
			var shot: Dictionary = pending_burst_shots[i]
			shot["delay"] = float(shot["delay"]) - delta
			if float(shot["delay"]) <= 0.0:
				_execute_single_queued_bullet(shot)
				pending_burst_shots.remove_at(i)

	if redraw_fx:
		fx_layer.queue_redraw()


func _update_nearby_interactable() -> void:
	if GameState.is_world_paused():
		if not nearby_interactable.is_empty():
			nearby_interactable = {}
			EventBus.interaction_prompt_changed.emit(false, "")
		return

	var found: Dictionary = {}
	var best_dist: float = 78.0

	for p in active_pickups:
		var pd: Dictionary = p as Dictionary
		var pos: Vector2 = (pd["tile"] as Vector2) * float(TILE_SIZE)
		var d: float = player.global_position.distance_to(pos)
		if d < best_dist:
			best_dist = d
			found = {"type": "pickup", "data": pd}

	for door in active_doors:
		var dd: Dictionary = door as Dictionary
		var pos: Vector2 = (dd["tile"] as Vector2) * float(TILE_SIZE)
		var d: float = player.global_position.distance_to(pos)
		if d < best_dist:
			best_dist = d
			found = {"type": "door", "data": dd}

	var prev_id: String = str(nearby_interactable.get("data", {}).get("id", ""))
	var new_id: String = str(found.get("data", {}).get("id", ""))
	nearby_interactable = found
	if prev_id != new_id:
		if found.is_empty():
			EventBus.interaction_prompt_changed.emit(false, "")
		else:
			var data: Dictionary = found["data"] as Dictionary
			var lbl: String = str(data.get("label", "Interagir"))
			if found["type"] == "door" and bool(data.get("requires_keycard", false)) and not GameState.has_keycard:
				lbl = "TRANCADA (Precisa do Keycard)"
			EventBus.interaction_prompt_changed.emit(true, lbl)


func trigger_interact() -> void:
	if GameState.is_world_paused() or nearby_interactable.is_empty():
		return

	var itype: String = str(nearby_interactable["type"])
	var data: Dictionary = nearby_interactable["data"] as Dictionary

	if itype == "pickup":
		var pid: String = str(data["id"])
		var kind: String = str(data.get("kind", "supply"))
		if kind == "char_switcher":
			var ch: Dictionary = GameState.cycle_playable_character()
			player.apply_active_character()
			AudioManager.play_sfx("atb_ready", -2.5, 0.04)
			var cname: String = str(ch["name"])
			EventBus.floating_text_requested.emit("PERSONAGEM: %s" % cname.to_upper(), player.global_position + Vector2(0, -58), Color(1.0, 0.88, 0.28))
			EventBus.toast_message.emit("Testando personagem: %s (interaja novamente para trocar)" % cname, Color(1.0, 0.88, 0.3))
			return
		elif kind == "save_terminal":
			GameState.save_game(player.global_position)
			EventBus.floating_text_requested.emit("JOGO SALVO!", player.global_position + Vector2(0, -56), Color(0.35, 1.0, 0.8))
			return
		elif kind == "dialogue":
			GameState.collected_pickups[pid] = true
			active_pickups.erase(data)
			AudioManager.play_sfx("atb_ready", -4.0, 0.02)
			_trigger_dialogue_by_id(str(data.get("dialogue_id", "")))
		elif kind == "keycard":
			GameState.collected_pickups[pid] = true
			GameState.has_keycard = true
			active_pickups.erase(data)
			AudioManager.play_sfx("level_up", -2.5, 0.0)
			EventBus.player_stats_changed.emit()
			EventBus.floating_text_requested.emit("KEYCARD OBTIDO!", player.global_position + Vector2(0, -56), Color(1.0, 0.88, 0.25))
			_trigger_dialogue_by_id(str(data.get("dialogue_id", "")))
		elif kind == "supply":
			GameState.collected_pickups[pid] = true
			active_pickups.erase(data)
			var parts: PackedStringArray = PackedStringArray()
			if data.has("medkits"):
				GameState.medkits += int(data["medkits"])
				parts.append("+%d Medkit" % int(data["medkits"]))
			if data.has("pe_lights"):
				GameState.pe_lights += int(data["pe_lights"])
				parts.append("+%d PE Light" % int(data["pe_lights"]))
			if data.has("tools"):
				GameState.tools += int(data["tools"])
				parts.append("+%d Tool" % int(data["tools"]))
			if data.has("ammo_caliber"):
				var cal: String = str(data["ammo_caliber"])
				var amt: int = int(data["ammo_amount"])
				GameState.ammo_by_caliber[cal] = int(GameState.ammo_by_caliber.get(cal, 0)) + amt
				parts.append("+%d Mun %s" % [amt, cal])
			AudioManager.play_sfx("heal", -4.0, 0.05)
			EventBus.player_stats_changed.emit()
			EventBus.toast_message.emit("Coletado: %s" % ", ".join(parts), Color(0.4, 1.0, 0.65))
		nearby_interactable = {}
		EventBus.interaction_prompt_changed.emit(false, "")

	elif itype == "door":
		if GameState.current_room_id == "main_hall" and not GameState.defeated_enemy_keys.has("main_hall_boss"):
			AudioManager.play_sfx("player_hurt", -6.0, 0.1)
			EventBus.toast_message.emit("LOCKDOWN ATIVO! Derrote o Mutante Alfa para destrancar a saída!", Color(1.0, 0.35, 0.35))
			return
		if bool(data.get("requires_keycard", false)) and not GameState.has_keycard:
			AudioManager.play_sfx("player_hurt", -6.0, 0.1)
			EventBus.toast_message.emit("Porta selada! Encontre o Keycard de Evacuação no Corredor Leste.", Color(1.0, 0.45, 0.35))
			return
		AudioManager.play_sfx("tactical_open", -3.0, 0.04)
		var target_room: String = str(data["target_room"])
		var target_spawn: Vector2 = data["target_spawn"] as Vector2
		nearby_interactable = {}
		EventBus.interaction_prompt_changed.emit(false, "")
		load_room(target_room, target_spawn)


func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_game_over or GameState.is_victory or GameState.is_dialogue_open or GameState.is_menu_open:
		return

	if event.is_action_pressed("reload") and not GameState.is_tactical_paused:
		GameState.reload_equipped_weapon()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("interact") and not GameState.is_tactical_paused:
		trigger_interact()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("tactical_toggle"):
		if GameState.is_tactical_paused:
			GameState.set_tactical_pause(false)
		else:
			GameState.set_tactical_pause(true, "attack")
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("pe_heal"):
		cast_heal()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("pe_haste"):
		cast_haste()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("pe_energy_shot"):
		if GameState.pe < 30.0:
			EventBus.toast_message.emit("PE insuficiente para Energy Shot (30 PE).", Color(1.0, 0.5, 0.5))
		else:
			GameState.set_tactical_pause(true, "energy_shot")
		get_viewport().set_input_as_handled()
		return

	if GameState.is_tactical_paused:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var world_pos: Vector2 = get_global_mouse_position()
			var target: EnemyBase = _find_enemy_near_point(world_pos, 56.0)
			if target != null:
				execute_tactical_attack_on(target)
				get_viewport().set_input_as_handled()


func _find_enemy_near_point(world_pos: Vector2, pick_radius: float) -> EnemyBase:
	var best: EnemyBase = null
	var best_dist: float = pick_radius
	for node in get_tree().get_nodes_in_group("enemies"):
		var en: EnemyBase = node as EnemyBase
		if en == null:
			continue
		var d: float = en.global_position.distance_to(world_pos)
		if d < best_dist:
			best_dist = d
			best = en
	return best


func get_nearest_enemy_in_range() -> EnemyBase:
	var best: EnemyBase = null
	var best_dist: float = 99999.0
	for node in get_tree().get_nodes_in_group("enemies"):
		var en: EnemyBase = node as EnemyBase
		if en == null:
			continue
		var d: float = player.global_position.distance_to(en.global_position)
		if d < best_dist:
			best_dist = d
			best = en
	return best


func execute_quick_tactical_fire() -> void:
	var target: EnemyBase = get_nearest_enemy_in_range()
	if target == null:
		EventBus.toast_message.emit("Nenhuma ameaça na sala!", Color(1.0, 0.72, 0.3))
		return
	execute_tactical_attack_on(target)


func execute_tactical_attack_on(target: EnemyBase) -> void:
	if not GameState.is_atb_ready():
		return

	var dist: float = player.global_position.distance_to(target.global_position)
	var max_r: float = GameState.get_current_range_px()
	var in_range: bool = dist <= max_r
	var falloff_mult: float = 1.0 if in_range else clampf(1.0 - ((dist - max_r) / 220.0), 0.35, 0.82)
	var is_energy: bool = GameState.tactical_action_mode == "energy_shot"

	if is_energy:
		if GameState.pe < 30.0:
			EventBus.toast_message.emit("PE insuficiente (precisa de 30 PE).", Color(1.0, 0.45, 0.45))
			return
		GameState.pe -= 30.0
		var dir: Vector2 = (target.global_position - player.global_position).normalized()
		var beam_end: Vector2 = player.global_position + dir * (max_r + 60.0)
		EventBus.weapon_fired.emit(player.global_position + Vector2(0, -24), beam_end + Vector2(0, -24), true)
		EventBus.screen_shake_requested.emit(6.5, 0.2)

		var hit_enemies: Array[EnemyBase] = []
		for node in get_tree().get_nodes_in_group("enemies"):
			var en: EnemyBase = node as EnemyBase
			if en == null:
				continue
			var rel: Vector2 = en.global_position - player.global_position
			var proj: float = rel.dot(dir)
			if proj > 0.0 and proj <= max_r + 80.0:
				var perp: float = absf(rel.cross(dir))
				if perp <= 42.0:
					hit_enemies.append(en)
		hit_enemies.sort_custom(func(a: EnemyBase, b: EnemyBase) -> bool:
			return player.global_position.distance_squared_to(a.global_position) < player.global_position.distance_squared_to(b.global_position)
		)
		var falloff: Array[float] = [1.0, 0.6, 0.4, 0.2]
		var base_pwr: float = float(GameState.get_total_attack()) * 1.65
		for i in range(hit_enemies.size()):
			var en: EnemyBase = hit_enemies[i]
			var mult: float = falloff[mini(i, falloff.size() - 1)]
			# BIO-RESONANCE COMBO: Chilled/Slowed enemy hit by Energy Shot takes +50% bonus!
			if en.is_chilled():
				mult *= 1.5
				EventBus.floating_text_requested.emit("BIO-RESSONÂNCIA +50%!", en.global_position + Vector2(0, -76), Color(0.45, 0.95, 1.0))
			en.take_damage(int(round(base_pwr * mult)), i == 0, GameState.selected_boss_part)
		GameState.consume_atb()
	else:
		var weapon: WeaponData = GameState.get_equipped_weapon()
		if weapon.mag_current <= 0:
			if GameState.reload_equipped_weapon():
				GameState.consume_atb()
				GameState.set_tactical_pause(false)
			return
		var shots: int = GameState.consume_mag_ammo(weapon.rate_of_fire)
		if GameState.darkness_timer > 0.0 and randf() < 0.35:
			EventBus.weapon_fired.emit(player.global_position + Vector2(0, -24), target.global_position + Vector2(24, -40), false)
			EventBus.floating_text_requested.emit("ERROU (DARKNESS)!", target.global_position + Vector2(0, -56), Color(0.65, 0.55, 0.9))
			GameState.consume_atb()
			GameState.set_tactical_pause(false)
			return

		var crit_chance: float = 0.45 if GameState.level >= 5 else 0.15
		if weapon.perks.has("critup"):
			crit_chance += 0.22
		if weapon.fire_pattern == "precision":
			crit_chance += 0.12

		# Compute total expected burst damage and divide across individual shots/pellets
		var base_total: float = float(GameState.get_total_attack()) * 1.45 * falloff_mult
		if weapon.perks.has("heat"):
			base_total *= 1.25
		if not in_range:
			EventBus.floating_text_requested.emit("OUT OF RANGE", target.global_position + Vector2(0, -72), Color(1.0, 0.65, 0.25))
		var hit_part: String = GameState.selected_boss_part if in_range else "body"

		var fam: float = GameState.get_weapon_familiarity(weapon)
		var shot_dir: Vector2 = (target.global_position - player.global_position).normalized()

		if weapon.fire_pattern == "spread":
			# SHOTGUN: Heavy physical recoil & wider spread when inexperienced; tightens organically with practice
			var pellet_count: int = 5
			var dmg_per_pellet: int = maxi(4, int(round(base_total / float(pellet_count))))
			AudioManager.play_weapon_sfx(weapon.id, false)
			var recoil_push: float = lerpf(265.0, 90.0, fam)
			var recoil_rec: float = lerpf(0.34, 0.10, fam)
			var shake_pwr: float = lerpf(8.5, 4.5, fam)
			var spread_scale: float = lerpf(1.25, 0.75, fam)
			player.apply_recoil(shot_dir, recoil_push, recoil_rec)
			EventBus.screen_shake_requested.emit(shake_pwr, 0.24)
			var angles: Array[float] = [-0.28 * spread_scale, -0.14 * spread_scale, 0.0, 0.14 * spread_scale, 0.28 * spread_scale]
			var enemies_hit: Dictionary = {}
			for ang in angles:
				var pdir: Vector2 = shot_dir.rotated(ang)
				var end_p: Vector2 = player.global_position + pdir * (max_r + 18.0)
				tracer_lines.append({
					"from": player.global_position + Vector2(0, -24),
					"to": end_p + Vector2(0, -24),
					"color": Color(1.0, 0.65, 0.22, 1.0),
					"width": 2.8,
					"ttl": 0.18,
				})
				for node in get_tree().get_nodes_in_group("enemies"):
					var en: EnemyBase = node as EnemyBase
					if en == null:
						continue
					var rel: Vector2 = en.global_position - player.global_position
					if rel.length() <= max_r + 36.0 and absf(pdir.angle_to(rel.normalized())) <= 0.19:
						enemies_hit[en] = int(enemies_hit.get(en, 0)) + 1
			if enemies_hit.is_empty():
				enemies_hit[target] = 3
			for en_key in enemies_hit.keys():
				var en: EnemyBase = en_key as EnemyBase
				if is_instance_valid(en):
					var pellets_landed: int = int(enemies_hit[en_key])
					var is_c: bool = in_range and (randf() < crit_chance)
					var total_en_dmg: int = int(round(float(dmg_per_pellet * pellets_landed) * (1.45 if is_c else 1.0)))
					en.take_damage(total_en_dmg, is_c, hit_part)
					if is_instance_valid(en) and en.hp > 0:
						en.apply_weapon_perks(weapon.perks)
			GameState.record_weapon_fire(weapon)
			fx_layer.queue_redraw()
		else:
			# SEQUENTIAL SHOTS (SMG 5x auto / M93R 3x burst / Rifle 2x precision / Pistol 2x semi)
			var num_bullets: int = maxi(1, shots)
			var per_bullet_base: float = base_total / float(num_bullets)
			var tracer_col: Color = Color(1.0, 0.92, 0.55, 1.0)
			if weapon.perks.has("frost"):
				tracer_col = Color(0.45, 0.9, 1.0, 1.0)
			elif weapon.perks.has("acid"):
				tracer_col = Color(0.6, 1.0, 0.35, 1.0)
			elif weapon.fire_pattern == "precision":
				tracer_col = Color(1.0, 0.98, 0.85, 1.0)

			# Cadence steadies slightly (~18%) and spread tightens organically as Elisabeth gets used to the gun
			var interval: float = maxf(0.055, weapon.shot_interval * lerpf(1.0, 0.82, fam))
			var base_jit: float = 16.0 if weapon.fire_pattern == "auto" else (8.0 if weapon.fire_pattern == "burst" else 4.0)
			var jit: float = base_jit * lerpf(1.25, 0.65, fam)
			var per_recoil: float = 0.0
			var per_rec_t: float = 0.0
			if weapon.fire_pattern == "precision":
				per_recoil = lerpf(115.0, 40.0, fam)
				per_rec_t = lerpf(0.16, 0.05, fam)
			elif weapon.fire_pattern == "auto":
				per_recoil = lerpf(55.0, 18.0, fam)
				per_rec_t = lerpf(0.06, 0.02, fam)

			for b_i in range(num_bullets):
				var is_c: bool = in_range and (randf() < crit_chance)
				var b_dmg: int = maxi(3, int(round(per_bullet_base * (1.45 if is_c else 1.0))))
				var bullet_data: Dictionary = {
					"delay": float(b_i) * interval,
					"target": target,
					"damage": b_dmg,
					"is_crit": is_c,
					"hit_part": hit_part,
					"perks": weapon.perks,
					"weapon_id": weapon.id,
					"color": tracer_col,
					"width": 2.2 if weapon.fire_pattern == "precision" else 2.5,
					"jitter": jit,
					"recoil_push": per_recoil,
					"recoil_rec": per_rec_t,
					"apply_perks": b_i == num_bullets - 1,
				}
				if b_i == 0:
					_execute_single_queued_bullet(bullet_data)
				else:
					pending_burst_shots.append(bullet_data)
			GameState.record_weapon_fire(weapon)

		GameState.consume_atb()
		if weapon.perks.has("2comm"):
			GameState.atb = 45.0
			EventBus.floating_text_requested.emit("2x COMMAND!", player.global_position + Vector2(0, -60), Color(1.0, 0.85, 0.3))
			EventBus.player_stats_changed.emit()

	GameState.set_tactical_pause(false)


func _execute_single_queued_bullet(shot: Dictionary) -> void:
	var target_var: Variant = shot.get("target")
	if not is_instance_valid(target_var):
		return
	var target: EnemyBase = target_var as EnemyBase
	if target == null or target.hp <= 0:
		return
	var jit: float = float(shot.get("jitter", 5.0))
	var offset := Vector2(randf_range(-jit, jit), randf_range(-jit, jit))
	var rec_push: float = float(shot.get("recoil_push", 0.0))
	if rec_push > 0.0:
		var sdir: Vector2 = (target.global_position - player.global_position).normalized()
		player.apply_recoil(sdir, rec_push, float(shot.get("recoil_rec", 0.04)))
	AudioManager.play_weapon_sfx(str(shot.get("weapon_id", "m93r")), false)
	EventBus.screen_shake_requested.emit(2.6, 0.08)
	tracer_lines.append({
		"from": player.global_position + Vector2(0, -24),
		"to": target.global_position + Vector2(0, -24) + offset,
		"color": shot.get("color", Color(1.0, 0.92, 0.55, 1.0)) as Color,
		"width": float(shot.get("width", 2.4)),
		"ttl": 0.12,
	})
	target.take_damage(int(shot["damage"]), bool(shot["is_crit"]), str(shot["hit_part"]))
	if bool(shot.get("apply_perks", false)) and is_instance_valid(target) and target.hp > 0:
		target.apply_weapon_perks(shot["perks"] as PackedStringArray)
	fx_layer.queue_redraw()


func cast_detox() -> void:
	if GameState.pe < 20.0:
		EventBus.toast_message.emit("PE insuficiente para DETOX (20 PE).", Color(1.0, 0.5, 0.5))
		return
	GameState.pe -= 20.0
	AudioManager.play_sfx("heal", -2.5, 0.08)
	GameState.purify_statuses(player.global_position)
	GameState.set_tactical_pause(false)


func cast_heal() -> void:
	if GameState.pe < 30.0:
		EventBus.toast_message.emit("PE insuficiente para HEAL (30 PE).", Color(1.0, 0.5, 0.5))
		return
	GameState.pe -= 30.0
	AudioManager.play_sfx("heal", -2.5, 0.02)
	var heal_amt: int = 85 + GameState.level * 15
	GameState.heal_player(heal_amt, player.global_position)
	GameState.set_tactical_pause(false)


func cast_haste() -> void:
	if GameState.pe < 25.0:
		EventBus.toast_message.emit("PE insuficiente para HASTE (25 PE).", Color(1.0, 0.5, 0.5))
		return
	GameState.pe -= 25.0
	AudioManager.play_sfx("haste", -2.5, 0.02)
	GameState.haste_timer = 18.0
	EventBus.floating_text_requested.emit("HASTE!", player.global_position + Vector2(0, -54), Color(0.4, 0.95, 1.0))
	EventBus.toast_message.emit("HASTE ativo: ATB e velocidade aumentados!", Color(0.4, 0.95, 1.0))
	GameState.set_tactical_pause(false)


func cast_barrier() -> void:
	if GameState.pe < 35.0:
		EventBus.toast_message.emit("PE insuficiente para BARRIER (35 PE).", Color(1.0, 0.5, 0.5))
		return
	GameState.pe -= 35.0
	AudioManager.play_sfx("heal", -3.0, 0.06)
	GameState.barrier_timer = 20.0
	EventBus.floating_text_requested.emit("BARRIER (-35% DANO)", player.global_position + Vector2(0, -54), Color(0.35, 0.95, 0.85))
	EventBus.toast_message.emit("BARRIER ativo: -35% de dano recebido por 20s!", Color(0.35, 0.95, 0.85))
	GameState.set_tactical_pause(false)


func cast_slow() -> void:
	if GameState.pe < 30.0:
		EventBus.toast_message.emit("PE insuficiente para SLOW (30 PE).", Color(1.0, 0.5, 0.5))
		return
	GameState.pe -= 30.0
	AudioManager.play_sfx("tactical_open", -2.5, 0.08)
	GameState.slow_timer = 14.0
	EventBus.floating_text_requested.emit("SLOW!", player.global_position + Vector2(0, -54), Color(0.55, 0.78, 1.0))
	EventBus.toast_message.emit("SLOW ativo: inimigos 50% mais lentos por 14s!", Color(0.55, 0.78, 1.0))
	GameState.set_tactical_pause(false)


func cast_scan() -> void:
	if GameState.pe < 15.0:
		EventBus.toast_message.emit("PE insuficiente para SCAN (15 PE).", Color(1.0, 0.5, 0.5))
		return
	var target: EnemyBase = get_nearest_enemy_in_range()
	if target == null:
		var all_en: Array[Node] = get_tree().get_nodes_in_group("enemies")
		if not all_en.is_empty():
			target = all_en[0] as EnemyBase
	if target == null:
		EventBus.toast_message.emit("Nenhuma ameaça detectada nesta sala.", Color(0.7, 0.85, 1.0))
		return
	GameState.pe -= 15.0
	AudioManager.play_sfx("atb_ready", -3.0, 0.0)
	EventBus.floating_text_requested.emit("SCAN: %d/%d HP" % [target.hp, target.max_hp], target.global_position + Vector2(0, -64), Color(0.45, 0.95, 1.0))
	EventBus.toast_message.emit("SCAN — %s | HP: %d/%d | ATK: %d" % [target.enemy_name, target.hp, target.max_hp, target.attack_damage], Color(0.45, 0.95, 1.0))
	GameState.set_tactical_pause(false)


func cast_liberate() -> void:
	if GameState.pe < 80.0:
		EventBus.toast_message.emit("PE insuficiente para LIBERATE (80 PE).", Color(1.0, 0.5, 0.5))
		return
	var max_r: float = GameState.get_current_range_px() + 110.0
	var targets: Array[EnemyBase] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var en: EnemyBase = node as EnemyBase
		if en != null and player.global_position.distance_to(en.global_position) <= max_r:
			targets.append(en)
	if targets.is_empty():
		EventBus.toast_message.emit("Nenhum alvo próximo para LIBERATE!", Color(1.0, 0.7, 0.3))
		return
	GameState.pe -= 80.0
	AudioManager.play_sfx("energy_shot", -0.5, 0.05)
	EventBus.screen_shake_requested.emit(10.0, 0.4)
	EventBus.floating_text_requested.emit("LIBERATE!!", player.global_position + Vector2(0, -64), Color(1.0, 0.45, 1.0))
	var dmg: int = int(round(float(GameState.get_total_attack()) * 3.1))
	for en in targets:
		EventBus.weapon_fired.emit(player.global_position + Vector2(0, -24), en.global_position + Vector2(0, -24), true)
		en.take_damage(dmg, true)
	GameState.consume_atb()
	GameState.set_tactical_pause(false)


func set_crt_visible(enabled: bool) -> void:
	GameState.crt_enabled = enabled
	if vignette_rect != null:
		vignette_rect.visible = enabled


func _on_weapon_fired(from_pos: Vector2, to_pos: Vector2, is_energy_shot: bool) -> void:
	AudioManager.play_weapon_sfx(GameState.get_equipped_weapon().id, is_energy_shot)
	tracer_lines.append({
		"from": from_pos,
		"to": to_pos,
		"color": Color(0.88, 0.35, 1.0, 1.0) if is_energy_shot else Color(1.0, 0.92, 0.55, 1.0),
		"width": 5.5 if is_energy_shot else 2.5,
		"ttl": 0.24 if is_energy_shot else 0.14,
	})
	fx_layer.queue_redraw()


func _on_floating_text(text: String, world_pos: Vector2, color: Color) -> void:
	floating_texts.append({
		"text": text,
		"pos": world_pos,
		"color": color,
		"ttl": 0.95,
	})
	fx_layer.queue_redraw()


func _on_enemy_projectile_spawned(origin: Vector2, dir: Vector2, damage: int, status_effect: String) -> void:
	enemy_projectiles.append({
		"pos": origin,
		"vel": dir * 195.0,
		"damage": damage,
		"status": status_effect,
		"ttl": 3.0,
	})


func _on_enemy_defeated(e_name: String, exp_r: int, bp_r: int, pos: Vector2) -> void:
	EventBus.toast_message.emit("%s eliminado! +%d EXP / +%d BP" % [e_name, exp_r, bp_r], Color(0.55, 1.0, 0.72))

	# 60% chance to drop a glowing supply pickup on defeat
	if randf() < 0.60:
		var drop_tile: Vector2 = pos / float(TILE_SIZE)
		var drop_id: String = "drop_%d_%d" % [int(pos.x), Time.get_ticks_msec()]
		var roll: float = randf()
		if roll < 0.55:
			var cal: String = GameState.get_equipped_weapon().caliber
			active_pickups.append({
				"id": drop_id, "tile": drop_tile, "kind": "supply",
				"label": "Pegar Drop: Munição %s" % cal,
				"ammo_caliber": cal, "ammo_amount": 18,
				"color": Color(1.0, 0.85, 0.25),
			})
		elif roll < 0.85:
			active_pickups.append({
				"id": drop_id, "tile": drop_tile, "kind": "supply",
				"label": "Pegar Drop: Medkit",
				"medkits": 1, "color": Color(0.35, 1.0, 0.6),
			})
		else:
			active_pickups.append({
				"id": drop_id, "tile": drop_tile, "kind": "supply",
				"label": "Pegar Drop: Weapon Tool",
				"tools": 1, "color": Color(0.95, 0.68, 0.25),
			})

	call_deferred("_check_room_cleared")
	if GameState.current_room_id == "main_hall" and GameState.defeated_enemy_keys.has("main_hall_boss"):
		pending_victory_after_dialogue = true
		call_deferred("_trigger_dialogue_by_id", "prologue_victory")


func _check_room_cleared() -> void:
	if get_tree().get_nodes_in_group("enemies").is_empty():
		AudioManager.set_combat_music(false)
		EventBus.toast_message.emit("AFTERMATH: Área limpa! +15 BP bônus de sobrevivência.", Color(0.35, 1.0, 0.72))
		GameState.bp += 15
		EventBus.player_stats_changed.emit()


func _on_dialogue_finished() -> void:
	if pending_victory_after_dialogue:
		pending_victory_after_dialogue = false
		GameState.is_victory = true
		EventBus.victory_triggered.emit()


func _draw() -> void:
	if ground_tex == null or struct_tex == null:
		return
	var s: float = float(src_tile_size)

	for y in range(map_rows):
		var row: String = str(layout_rows[y])
		for x in range(map_cols):
			var ch: String = row[x]
			var dst := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var ground_src: Rect2 = Rect2(0, 0, s, s)

			if ch == "C":
				ground_src = Rect2(5 * s, 0, s, s)
			elif ch == "X":
				ground_src = Rect2(2 * s, 0, s, s)
			elif ch == "S":
				ground_src = Rect2(3 * s, 0, s, s)
			elif (x + y) % 5 == 0:
				ground_src = Rect2(1 * s, 0, s, s)

			draw_texture_rect_region(ground_tex, dst, ground_src)

			if ch == "S":
				draw_rect(dst, Color(0.1, 0.85, 0.45, 0.14))
			elif ch == "D":
				var door_src := Rect2(4 * s, 1 * s, s, s)
				draw_texture_rect_region(struct_tex, dst, door_src)
			elif ch == "#":
				var wall_src: Rect2 = Rect2(0, 0, s, s)
				if y == 0 and x % 4 == 2:
					wall_src = Rect2(0, 1 * s, s, s)
				elif y == 4 and (x == 4 or x == 17):
					wall_src = Rect2(6 * s, 1 * s, s, s)
				draw_texture_rect_region(struct_tex, dst, wall_src)

	if props_tex != null:
		for prop in (current_room.get("props", []) as Array):
			var pd: Dictionary = prop as Dictionary
			var pt: Vector2 = pd["tile"] as Vector2
			var ps: Vector2 = pd["src"] as Vector2
			draw_texture_rect_region(
				props_tex,
				Rect2(pt.x * TILE_SIZE, pt.y * TILE_SIZE, TILE_SIZE, TILE_SIZE),
				Rect2(ps.x * 48.0, ps.y * 48.0, 48.0, 48.0)
			)


func draw_fx_layer() -> void:
	var pulse: float = 0.6 + 0.4 * sin(emergency_time * 1.8)

	# Door interaction beacons
	for door in active_doors:
		var dd: Dictionary = door as Dictionary
		var pos: Vector2 = (dd["tile"] as Vector2) * float(TILE_SIZE)
		var locked: bool = bool(dd.get("requires_keycard", false)) and not GameState.has_keycard
		var col: Color = Color(1.0, 0.35, 0.28, 0.85 * pulse) if locked else Color(0.25, 0.92, 1.0, 0.85 * pulse)
		fx_layer.draw_arc(pos, 18.0 + 4.0 * pulse, 0.0, TAU, 28, col, 2.5, true)

	# Glowing pickup items on floor
	var fx_font: Font = ThemeDB.fallback_font
	for p in active_pickups:
		var pd: Dictionary = p as Dictionary
		var pos: Vector2 = (pd["tile"] as Vector2) * float(TILE_SIZE)
		var col: Color = pd.get("color", Color(0.4, 1.0, 0.7)) as Color
		fx_layer.draw_circle(pos, 10.0, Color(col.r, col.g, col.b, 0.35 * pulse))
		fx_layer.draw_circle(pos, 5.5, Color(col.r, col.g, col.b, 0.95))
		fx_layer.draw_arc(pos, 14.0 + 3.0 * pulse, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.85), 2.0, true)
		if str(pd.get("kind", "")) == "char_switcher":
			fx_layer.draw_string(fx_font, pos + Vector2(-58, -22), "TROCAR PERSONAGEM", HORIZONTAL_ALIGNMENT_CENTER, 116, 11, Color(1.0, 0.9, 0.35, 0.95))

	# Weapon tracers + muzzle flash & impact burst
	for line_data in tracer_lines:
		var from_p: Vector2 = line_data["from"] as Vector2
		var to_p: Vector2 = line_data["to"] as Vector2
		var col: Color = line_data["color"] as Color
		var ttl: float = float(line_data["ttl"])
		fx_layer.draw_line(from_p, to_p, col, float(line_data["width"]), true)
		var burst_r: float = clampf(ttl * 70.0, 4.0, 18.0)
		fx_layer.draw_circle(from_p, burst_r * 0.65, Color(1.0, 0.96, 0.72, clampf(ttl * 5.0, 0.0, 0.9)))
		fx_layer.draw_arc(to_p, burst_r, 0.0, TAU, 16, col, 2.0, true)

	# Enemy acid / darkness projectiles
	for pr in enemy_projectiles:
		var ppos: Vector2 = pr["pos"] as Vector2
		var is_dark: bool = str(pr.get("status", "")) == "darkness"
		var pcol: Color = Color(0.75, 0.35, 1.0) if is_dark else Color(0.35, 1.0, 0.35)
		fx_layer.draw_circle(ppos, 10.0, Color(pcol.r, pcol.g, pcol.b, 0.35))
		fx_layer.draw_circle(ppos, 5.5, pcol)
		fx_layer.draw_arc(ppos, 9.0, 0.0, TAU, 16, Color.WHITE, 1.2, true)

	# Floating combat numbers
	var font: Font = ThemeDB.fallback_font
	for ft in floating_texts:
		var alpha: float = clampf(float(ft["ttl"]) / 0.35, 0.0, 1.0)
		var col: Color = ft["color"] as Color
		col.a = alpha
		var pos: Vector2 = ft["pos"] as Vector2
		var txt: String = str(ft["text"])
		fx_layer.draw_string(font, pos + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(0, 0, 0, alpha * 0.85))
		fx_layer.draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, col)
