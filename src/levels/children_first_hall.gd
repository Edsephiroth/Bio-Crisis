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
var emergency_time: float = 0.0
var pending_victory_after_dialogue: bool = false


func _ready() -> void:
	GameState.reset_run()
	AudioManager.start_ambient_bgm()
	EventBus.enemy_defeated.connect(_on_enemy_defeated)
	EventBus.floating_text_requested.connect(_on_floating_text)
	EventBus.weapon_fired.connect(_on_weapon_fired)
	EventBus.dialogue_finished.connect(_on_dialogue_finished)
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

	# Clear previous room physics, occluders, and enemies
	for child in walls_body.get_children():
		child.queue_free()
	for child in occluders_root.get_children():
		child.queue_free()
	for node in get_tree().get_nodes_in_group("enemies"):
		node.queue_free()

	tracer_lines.clear()
	floating_texts.clear()
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
		if kind == "dialogue":
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
	var max_r: float = GameState.get_current_range_px()
	var best: EnemyBase = null
	var best_dist: float = max_r
	for node in get_tree().get_nodes_in_group("enemies"):
		var en: EnemyBase = node as EnemyBase
		if en == null:
			continue
		var d: float = player.global_position.distance_to(en.global_position)
		if d <= best_dist:
			best_dist = d
			best = en
	return best


func execute_quick_tactical_fire() -> void:
	var target: EnemyBase = get_nearest_enemy_in_range()
	if target == null:
		EventBus.toast_message.emit("Nenhum inimigo dentro da esfera de alcance!", Color(1.0, 0.72, 0.3))
		return
	execute_tactical_attack_on(target)


func execute_tactical_attack_on(target: EnemyBase) -> void:
	if not GameState.is_atb_ready():
		return

	var dist: float = player.global_position.distance_to(target.global_position)
	if dist > GameState.get_current_range_px():
		EventBus.toast_message.emit("Alvo fora do alcance da arma!", Color(1.0, 0.65, 0.3))
		return

	var is_energy: bool = GameState.tactical_action_mode == "energy_shot"

	if is_energy:
		if GameState.pe < 30.0:
			EventBus.toast_message.emit("PE insuficiente (precisa de 30 PE).", Color(1.0, 0.45, 0.45))
			return
		GameState.pe -= 30.0
		var dir: Vector2 = (target.global_position - player.global_position).normalized()
		var beam_end: Vector2 = player.global_position + dir * GameState.get_current_range_px()
		EventBus.weapon_fired.emit(player.global_position + Vector2(0, -24), beam_end + Vector2(0, -24), true)
		EventBus.screen_shake_requested.emit(6.5, 0.2)

		var hit_enemies: Array[EnemyBase] = []
		for node in get_tree().get_nodes_in_group("enemies"):
			var en: EnemyBase = node as EnemyBase
			if en == null:
				continue
			var rel: Vector2 = en.global_position - player.global_position
			var proj: float = rel.dot(dir)
			if proj > 0.0 and proj <= GameState.get_current_range_px() + 20.0:
				var perp: float = absf(rel.cross(dir))
				if perp <= 40.0:
					hit_enemies.append(en)
		hit_enemies.sort_custom(func(a: EnemyBase, b: EnemyBase) -> bool:
			return player.global_position.distance_squared_to(a.global_position) < player.global_position.distance_squared_to(b.global_position)
		)
		var falloff: Array[float] = [1.0, 0.6, 0.4, 0.2]
		var base_pwr: float = float(GameState.get_total_attack()) * 1.65
		for i in range(hit_enemies.size()):
			var mult: float = falloff[mini(i, falloff.size() - 1)]
			hit_enemies[i].take_damage(int(round(base_pwr * mult)), i == 0)
	else:
		var weapon: WeaponData = GameState.get_equipped_weapon()
		if GameState.get_current_ammo() <= 0:
			EventBus.toast_message.emit("Sem munição %s!" % weapon.caliber, Color(1.0, 0.35, 0.35))
			return
		var shots: int = GameState.consume_current_ammo(weapon.rate_of_fire)
		var crit_chance: float = 0.45 if GameState.level >= 5 else 0.15
		var is_crit: bool = randf() < crit_chance
		var per_shot: float = float(GameState.get_total_attack()) * (0.72 if shots > 1 else 1.25)
		var total_dmg: int = int(round(per_shot * float(shots) * (1.5 if is_crit else 1.0)))
		EventBus.weapon_fired.emit(player.global_position + Vector2(0, -24), target.global_position + Vector2(0, -24), false)
		EventBus.screen_shake_requested.emit(4.0, 0.14)
		target.take_damage(total_dmg, is_crit)

	GameState.consume_atb()
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


func _on_enemy_defeated(e_name: String, exp_r: int, bp_r: int, _pos: Vector2) -> void:
	EventBus.toast_message.emit("%s eliminado! +%d EXP / +%d BP" % [e_name, exp_r, bp_r], Color(0.55, 1.0, 0.72))
	if GameState.current_room_id == "main_hall" and GameState.defeated_enemy_keys.has("main_hall_boss"):
		pending_victory_after_dialogue = true
		call_deferred("_trigger_dialogue_by_id", "prologue_victory")


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
	for p in active_pickups:
		var pd: Dictionary = p as Dictionary
		var pos: Vector2 = (pd["tile"] as Vector2) * float(TILE_SIZE)
		var col: Color = pd.get("color", Color(0.4, 1.0, 0.7)) as Color
		fx_layer.draw_circle(pos, 10.0, Color(col.r, col.g, col.b, 0.35 * pulse))
		fx_layer.draw_circle(pos, 5.5, Color(col.r, col.g, col.b, 0.95))
		fx_layer.draw_arc(pos, 14.0 + 3.0 * pulse, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.85), 2.0, true)

	# Weapon tracers
	for line_data in tracer_lines:
		fx_layer.draw_line(
			line_data["from"] as Vector2,
			line_data["to"] as Vector2,
			line_data["color"] as Color,
			float(line_data["width"]),
			true
		)

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
