class_name ChildrenFirstHall
extends Node2D

const TILE_SIZE: int = 48
const MAP_COLS: int = 22
const MAP_ROWS: int = 16

const ENEMY_SCENE: PackedScene = preload("res://src/entities/enemies/deformed_common.tscn")
const GROUND_TEX: Texture2D = preload("res://assets/tilesets/hall_ground_48.png")
const STRUCT_TEX: Texture2D = preload("res://assets/tilesets/hall_structures_48.png")
const PROPS_TEX: Texture2D = preload("res://assets/tilesets/hall_props_48.png")

# Layout of Children First NGO Gala Hall:
# '#' = wall, '.' = parquet, 'C' = wine carpet, 'X' = checkered dance floor
# 'S' = safe room, 'P' = player start, 'E' = Deformed Attendee, 'B' = Alpha Mutant (Mini-Boss)
const LAYOUT: Array[String] = [
	"######################",
	"#....#..........#....#",
	"#....#....B.....#....#",
	"#....#..........#....#",
	"##..###..CCCC..###..##",
	"#.......CCCCCC.......#",
	"#..E...XXXXXXXX...E..#",
	"#......XXXXXXXX......#",
	"#......XXXXXXXX......#",
	"#..E...XXXXXXXX...E..#",
	"#.......CCCCCC.......#",
	"#####...CCCCCC...#####",
	"#SSS#....CCCC........#",
	"#SSS......P..........#",
	"#SSS#................#",
	"######################",
]

@onready var player: ElisabethPlayer = $Entities/Elisabeth
@onready var entities_root: Node2D = $Entities
@onready var fx_layer: Node2D = $FxLayer
@onready var emergency_light: PointLight2D = $Lights/EmergencyLight
@onready var safe_light: PointLight2D = $Lights/SafeRoomLight
@onready var walls_body: StaticBody2D = $WallsBody
@onready var nav_region: NavigationRegion2D = $NavigationRegion2D
@onready var occluders_root: Node2D = $Occluders

var safe_room_rect: Rect2 = Rect2(1 * TILE_SIZE, 12 * TILE_SIZE, 3 * TILE_SIZE, 3 * TILE_SIZE)
var tracer_lines: Array[Dictionary] = []
var floating_texts: Array[Dictionary] = []
var emergency_time: float = 0.0


func _ready() -> void:
	GameState.reset_run()
	_build_map_collisions_and_spawns()
	_bake_navigation_mesh()
	AudioManager.start_ambient_bgm()
	EventBus.enemy_defeated.connect(_on_enemy_defeated)
	EventBus.floating_text_requested.connect(_on_floating_text)
	EventBus.weapon_fired.connect(_on_weapon_fired)
	EventBus.toast_message.emit("ONG Children First — Salão de Gala. Sobreviva!", Color(0.75, 0.9, 1.0))


func _build_map_collisions_and_spawns() -> void:
	var enemy_idx: int = 0
	for y in range(MAP_ROWS):
		var row: String = LAYOUT[y]
		for x in range(MAP_COLS):
			var ch: String = row[x]
			var center: Vector2 = Vector2((x + 0.5) * TILE_SIZE, (y + 0.5) * TILE_SIZE)
			if ch == "#":
				var col_shape := CollisionShape2D.new()
				var rect := RectangleShape2D.new()
				rect.size = Vector2(TILE_SIZE, TILE_SIZE)
				col_shape.shape = rect
				col_shape.position = center
				walls_body.add_child(col_shape)

				# Add dynamic 2D shadow occluders on interior walls/pillars
				if x > 0 and x < MAP_COLS - 1 and y > 0 and y < MAP_ROWS - 1:
					_add_wall_occluder(x, y)
			elif ch == "P":
				player.global_position = center
			elif ch == "E":
				_spawn_enemy(center, false, enemy_idx)
				enemy_idx += 1
			elif ch == "B":
				_spawn_enemy(center, true, enemy_idx)
				enemy_idx += 1

	safe_light.position = safe_room_rect.get_center()
	emergency_light.position = Vector2(11 * TILE_SIZE, 7.5 * TILE_SIZE)


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

	# Full interior traversable outline
	var w: float = float(MAP_COLS * TILE_SIZE)
	var h: float = float(MAP_ROWS * TILE_SIZE)
	source_data.add_traversable_outline(PackedVector2Array([
		Vector2(TILE_SIZE, TILE_SIZE),
		Vector2(w - TILE_SIZE, TILE_SIZE),
		Vector2(w - TILE_SIZE, h - TILE_SIZE),
		Vector2(TILE_SIZE, h - TILE_SIZE),
	]))

	# Carve out wall tiles as navigation obstructions
	for y in range(1, MAP_ROWS - 1):
		var row: String = LAYOUT[y]
		for x in range(1, MAP_COLS - 1):
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


func _spawn_enemy(pos: Vector2, is_alpha: bool, idx: int) -> void:
	var enemy: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
	enemy.global_position = pos
	if is_alpha:
		enemy.bestiary_id = "alpha_mutant"
		enemy.enemy_name = "Alpha Deformed (Organism)"
		enemy.max_hp = 260
		enemy.move_speed = 92.0
		enemy.attack_damage = 55
		enemy.exp_reward = 14
		enemy.bp_reward = 60
		enemy.scale = Vector2(1.28, 1.28)
	else:
		enemy.enemy_name = "Deformed Attendee #%d" % (idx + 1)
		enemy.max_hp = 95 + (idx % 2) * 20
		enemy.move_speed = 74.0 + float(idx % 3) * 6.0
	entities_root.add_child(enemy)


func _process(delta: float) -> void:
	GameState.tick_realtime(delta)

	# Pulse emergency red light
	emergency_time += delta * 2.8
	emergency_light.energy = 0.75 + 0.45 * sin(emergency_time)

	# Check safe room
	var now_safe: bool = safe_room_rect.has_point(player.global_position)
	if now_safe != GameState.in_safe_room:
		GameState.in_safe_room = now_safe
		EventBus.safe_room_state_changed.emit(now_safe)
		if now_safe:
			EventBus.toast_message.emit("SAFE ROOM: Recuperando HP e PE...", Color(0.3, 1.0, 0.55))

	# Update visual tracers & floating texts
	var redraw_fx: bool = false
	for i in range(tracer_lines.size() - 1, -1, -1):
		tracer_lines[i]["ttl"] = float(tracer_lines[i]["ttl"]) - delta
		redraw_fx = true
		if float(tracer_lines[i]["ttl"]) <= 0.0:
			tracer_lines.remove_at(i)

	for i in range(floating_texts.size() - 1, -1, -1):
		floating_texts[i]["ttl"] = float(floating_texts[i]["ttl"]) - delta
		floating_texts[i]["pos"] = (floating_texts[i]["pos"] as Vector2) + Vector2(0, -34.0 * delta)
		redraw_fx = true
		if float(floating_texts[i]["ttl"]) <= 0.0:
			floating_texts.remove_at(i)

	if redraw_fx:
		fx_layer.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_game_over or GameState.is_victory:
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

	# Click / Touch directly on an enemy in tactical mode
	if GameState.is_tactical_paused:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var world_pos: Vector2 = get_global_mouse_position()
			var target: EnemyBase = _find_enemy_near_point(world_pos, 52.0)
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

		# Piercing damage along the line: 100%, 60%, 40%, 20%
		var hit_enemies: Array[EnemyBase] = []
		for node in get_tree().get_nodes_in_group("enemies"):
			var en: EnemyBase = node as EnemyBase
			if en == null:
				continue
			var rel: Vector2 = en.global_position - player.global_position
			var proj: float = rel.dot(dir)
			if proj > 0.0 and proj <= GameState.get_current_range_px() + 20.0:
				var perp: float = absf(rel.cross(dir))
				if perp <= 38.0:
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
	# Check remaining enemies on next frame
	call_deferred("_check_victory")


func _check_victory() -> void:
	if get_tree().get_nodes_in_group("enemies").is_empty() and not GameState.is_game_over:
		GameState.is_victory = true
		GameState.set_tactical_pause(false)
		EventBus.victory_triggered.emit()


func _draw() -> void:
	# Render the Gala Hall using real 48x48 tiles from Raw.zip
	for y in range(MAP_ROWS):
		var row: String = LAYOUT[y]
		for x in range(MAP_COLS):
			var ch: String = row[x]
			var dst := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var ground_src: Rect2 = Rect2(0, 0, 48, 48) # honey parquet

			if ch == "C":
				ground_src = Rect2(5 * 48, 0, 48, 48) # wine carpet
			elif ch == "X":
				ground_src = Rect2(2 * 48, 0, 48, 48) # checkered dance floor
			elif ch == "S":
				ground_src = Rect2(3 * 48, 0, 48, 48) # cream ceramic (safe room)
			elif (x + y) % 5 == 0:
				ground_src = Rect2(1 * 48, 0, 48, 48) # dark parquet accent

			draw_texture_rect_region(GROUND_TEX, dst, ground_src)

			if ch == "S":
				draw_rect(dst, Color(0.1, 0.85, 0.45, 0.14))
			elif ch == "#":
				var wall_src: Rect2 = Rect2(0, 0, 48, 48) # cream wall
				if y == 0 and (x == 9 or x == 10 or x == 11 or x == 12):
					wall_src = Rect2(2 * 48, 2 * 48, 48, 48) # stage curtain
				elif y == 0 and x % 4 == 2:
					wall_src = Rect2(0, 1 * 48, 48, 48) # window
				elif y == 4 and (x == 4 or x == 17):
					wall_src = Rect2(6 * 48, 1 * 48, 48, 48) # column
				draw_texture_rect_region(STRUCT_TEX, dst, wall_src)

	# Decorative gala props (tables / debris)
	draw_texture_rect_region(PROPS_TEX, Rect2(2 * TILE_SIZE, 2 * TILE_SIZE, 48, 48), Rect2(0, 0, 48, 48))
	draw_texture_rect_region(PROPS_TEX, Rect2(19 * TILE_SIZE, 2 * TILE_SIZE, 48, 48), Rect2(48, 0, 48, 48))
	draw_texture_rect_region(PROPS_TEX, Rect2(18 * TILE_SIZE, 13 * TILE_SIZE, 48, 48), Rect2(96, 0, 48, 48))


func draw_fx_layer() -> void:
	for line_data in tracer_lines:
		fx_layer.draw_line(
			line_data["from"] as Vector2,
			line_data["to"] as Vector2,
			line_data["color"] as Color,
			float(line_data["width"]),
			true
		)

	var font: Font = ThemeDB.fallback_font
	for ft in floating_texts:
		var alpha: float = clampf(float(ft["ttl"]) / 0.35, 0.0, 1.0)
		var col: Color = ft["color"] as Color
		col.a = alpha
		var pos: Vector2 = ft["pos"] as Vector2
		var txt: String = str(ft["text"])
		fx_layer.draw_string(font, pos + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(0, 0, 0, alpha * 0.85))
		fx_layer.draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, col)
