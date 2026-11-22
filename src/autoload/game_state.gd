extends Node

## Global state manager for Elisabeth Shelley (ATB, PE, Inventory, Tune, Status Timers, Save/Load).

const SAVE_PATH: String = "user://bio_crisis_save_1.json"

var level: int = 1
var exp: int = 0
var exp_to_next: int = 3
var hp: int = 445
var max_hp: int = 445
var pe: float = 100.0
var max_pe: float = 100.0
var atb: float = 0.0
var atb_rate: float = 34.0
var base_attack: int = 25
var bp: int = 0
var play_time_seconds: float = 0.0

var medkits: int = 3
var pe_lights: int = 2
var tools: int = 2

var ammo_by_caliber: Dictionary = {
	"9mm": 120,
	"12G": 24,
	"5.56mm": 90,
}

var haste_timer: float = 0.0
var barrier_timer: float = 0.0
var slow_timer: float = 0.0

var poison_timer: float = 0.0
var darkness_timer: float = 0.0
var stiff_timer: float = 0.0
var _poison_accum: float = 0.0

var selected_boss_part: String = "body" # "arms", "body", "core"

var in_safe_room: bool = false
var is_tactical_paused: bool = false
var is_menu_open: bool = false
var is_dialogue_open: bool = false
var tactical_action_mode: String = "attack"
var is_game_over: bool = false
var is_victory: bool = false
var crt_enabled: bool = true

var current_room_id: String = "gala_hall"
var saved_player_pos: Vector2 = Vector2(-1, -1)
var pending_load_from_save: bool = false
var has_keycard: bool = false
var collected_pickups: Dictionary = {}
var defeated_enemy_keys: Dictionary = {}
var seen_dialogues: Dictionary = {}

var virtual_move_vector: Vector2 = Vector2.ZERO

var weapons: Array[WeaponData] = []
var equipped_weapon_index: int = 0
var armors: Array[ArmorData] = []
var equipped_armor_index: int = 0
var bestiary_kills: Dictionary = {}

const PE_EXP_CHART: Dictionary = {
	1: 3, 2: 8, 3: 19, 4: 28, 5: 45, 6: 70, 7: 105, 8: 150, 9: 210, 10: 290,
	11: 390, 12: 520, 13: 680, 14: 870, 15: 1100
}


func _ready() -> void:
	reset_run()


func reset_run() -> void:
	weapons = BioDatabase.create_starter_weapons()
	armors = BioDatabase.create_starter_armors()
	equipped_weapon_index = 0
	equipped_armor_index = 0

	level = 1
	exp = 0
	exp_to_next = get_exp_for_next_level(level)
	max_hp = get_hp_for_level(level) + get_equipped_armor().hp_bonus
	hp = max_hp
	max_pe = 100.0
	pe = max_pe
	atb = 100.0
	base_attack = 25
	bp = 0
	play_time_seconds = 0.0
	medkits = 3
	pe_lights = 2
	tools = 2
	ammo_by_caliber = {
		"9mm": 120,
		"12G": 24,
		"5.56mm": 90,
	}
	bestiary_kills = {}

	haste_timer = 0.0
	barrier_timer = 0.0
	slow_timer = 0.0
	poison_timer = 0.0
	darkness_timer = 0.0
	stiff_timer = 0.0
	_poison_accum = 0.0
	selected_boss_part = "body"
	in_safe_room = false
	is_tactical_paused = false
	is_menu_open = false
	is_dialogue_open = false
	tactical_action_mode = "attack"
	is_game_over = false
	is_victory = false
	current_room_id = "gala_hall"
	saved_player_pos = Vector2(-1, -1)
	has_keycard = false
	collected_pickups = {}
	defeated_enemy_keys = {}
	seen_dialogues = {}
	virtual_move_vector = Vector2.ZERO
	EventBus.player_stats_changed.emit()


func is_world_paused() -> bool:
	return is_tactical_paused or is_menu_open or is_dialogue_open or is_game_over or is_victory


func get_equipped_weapon() -> WeaponData:
	if weapons.is_empty():
		weapons = BioDatabase.create_starter_weapons()
	equipped_weapon_index = clampi(equipped_weapon_index, 0, weapons.size() - 1)
	return weapons[equipped_weapon_index]


func get_equipped_armor() -> ArmorData:
	if armors.is_empty():
		armors = BioDatabase.create_starter_armors()
	equipped_armor_index = clampi(equipped_armor_index, 0, armors.size() - 1)
	return armors[equipped_armor_index]


func equip_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	equipped_weapon_index = index
	var w: WeaponData = get_equipped_weapon()
	EventBus.toast_message.emit("Arma equipada: %s (%s)" % [w.display_name, w.caliber], Color(0.45, 0.9, 1.0))
	EventBus.player_stats_changed.emit()


func equip_armor(index: int) -> void:
	if index < 0 or index >= armors.size():
		return
	var old_bonus: int = get_equipped_armor().hp_bonus
	equipped_armor_index = index
	var new_armor: ArmorData = get_equipped_armor()
	max_hp = maxi(100, max_hp - old_bonus + new_armor.hp_bonus)
	hp = mini(hp + maxi(0, new_armor.hp_bonus - old_bonus), max_hp)
	EventBus.toast_message.emit("Armadura equipada: %s (DEF +%d)" % [new_armor.display_name, new_armor.defense_bonus], Color(0.45, 1.0, 0.72))
	EventBus.player_stats_changed.emit()


func cycle_weapon() -> void:
	if weapons.is_empty():
		return
	equip_weapon((equipped_weapon_index + 1) % weapons.size())


func has_weapon_perk(perk_id: String) -> bool:
	return get_equipped_weapon().perks.has(perk_id)


func has_armor_perk(perk_id: String) -> bool:
	return get_equipped_armor().perks.has(perk_id)


func get_current_ammo() -> int:
	var cal: String = get_equipped_weapon().caliber
	return int(ammo_by_caliber.get(cal, 0))


func reload_equipped_weapon() -> bool:
	var w: WeaponData = get_equipped_weapon()
	var needed: int = w.capacity - w.mag_current
	if needed <= 0:
		EventBus.toast_message.emit("Pente de %s já está cheio!" % w.display_name, Color(0.6, 0.85, 1.0))
		return false
	var reserve: int = int(ammo_by_caliber.get(w.caliber, 0))
	if reserve <= 0:
		EventBus.toast_message.emit("Sem munição reserva %s!" % w.caliber, Color(1.0, 0.35, 0.35))
		return false
	var loaded: int = mini(needed, reserve)
	w.mag_current += loaded
	ammo_by_caliber[w.caliber] = reserve - loaded
	AudioManager.play_sfx("reload", -2.0, 0.04)
	EventBus.toast_message.emit("Recarregado: %s (%d/%d)" % [w.display_name, w.mag_current, w.capacity], Color(0.45, 0.95, 1.0))
	EventBus.player_stats_changed.emit()
	return true


func consume_mag_ammo(count: int) -> int:
	var w: WeaponData = get_equipped_weapon()
	var used: int = mini(count, w.mag_current)
	w.mag_current -= used
	EventBus.player_stats_changed.emit()
	return used


func tune_weapon(target_idx: int, donor_idx: int) -> String:
	if tools <= 0:
		return "Você precisa de 1 Tool para fazer Tune."
	if target_idx == donor_idx:
		return "Escolha uma arma doadora diferente da arma alvo."
	if target_idx < 0 or target_idx >= weapons.size() or donor_idx < 0 or donor_idx >= weapons.size():
		return "Seleção de arma inválida."

	var target: WeaponData = weapons[target_idx]
	var donor: WeaponData = weapons[donor_idx]
	var atk_gain: int = maxi(3, int(floor(float(donor.attack_bonus) * 0.4)))
	var rng_gain: float = 14.0 if donor.range_px >= target.range_px else 6.0

	target.attack_bonus += atk_gain
	target.range_px = minf(380.0, target.range_px + rng_gain)
	var transferred_perks: PackedStringArray = PackedStringArray()
	for p in donor.perks:
		if not target.perks.has(p) and target.perks.size() < 3:
			target.perks.append(p)
			transferred_perks.append(p.to_upper())

	if not target.display_name.ends_with("+"):
		target.display_name += "+"

	tools -= 1
	weapons.remove_at(donor_idx)
	if equipped_weapon_index == donor_idx:
		equipped_weapon_index = target_idx if target_idx < donor_idx else maxi(0, target_idx - 1)
	elif equipped_weapon_index > donor_idx:
		equipped_weapon_index -= 1

	AudioManager.play_sfx("level_up", -3.0, 0.05)
	EventBus.player_stats_changed.emit()
	var perk_str: String = (" | Perks: " + ", ".join(transferred_perks)) if not transferred_perks.is_empty() else ""
	return "TUNE! %s +%d ATK, +%dpx%s" % [target.display_name, atk_gain, int(rng_gain), perk_str]


func apply_status(status_id: String, duration: float, world_pos: Vector2) -> void:
	match status_id:
		"poison":
			if has_armor_perk("nopois"):
				EventBus.floating_text_requested.emit("IMUNE A POISON!", world_pos + Vector2(0, -52), Color(0.4, 1.0, 0.7))
				return
			poison_timer = maxf(poison_timer, duration)
			EventBus.floating_text_requested.emit("POISON!", world_pos + Vector2(0, -52), Color(0.4, 0.95, 0.35))
		"darkness":
			if has_armor_perk("nodark"):
				EventBus.floating_text_requested.emit("IMUNE A DARKNESS!", world_pos + Vector2(0, -52), Color(0.4, 1.0, 0.7))
				return
			darkness_timer = maxf(darkness_timer, duration)
			EventBus.floating_text_requested.emit("DARKNESS!", world_pos + Vector2(0, -52), Color(0.6, 0.5, 0.85))
		"stiff":
			if has_armor_perk("nostiff"):
				EventBus.floating_text_requested.emit("IMUNE A STIFF!", world_pos + Vector2(0, -52), Color(0.4, 1.0, 0.7))
				return
			stiff_timer = maxf(stiff_timer, duration)
			EventBus.floating_text_requested.emit("STIFF (LENTO)!", world_pos + Vector2(0, -52), Color(0.5, 0.75, 1.0))
	EventBus.player_stats_changed.emit()


func purify_statuses(world_pos: Vector2) -> void:
	poison_timer = 0.0
	darkness_timer = 0.0
	stiff_timer = 0.0
	_poison_accum = 0.0
	EventBus.floating_text_requested.emit("STATUS PURIFICADO!", world_pos + Vector2(0, -54), Color(0.35, 1.0, 0.8))
	EventBus.player_stats_changed.emit()


func use_medkit() -> bool:
	if medkits <= 0 or hp >= max_hp:
		return false
	medkits -= 1
	var healed: int = mini(max_hp - hp, 160)
	hp += healed
	AudioManager.play_sfx("heal", -2.5, 0.03)
	EventBus.toast_message.emit("Medkit usado! +%d HP" % healed, Color(0.3, 1.0, 0.55))
	EventBus.player_stats_changed.emit()
	return true


func use_pe_light() -> bool:
	if pe_lights <= 0 or pe >= max_pe:
		return false
	pe_lights -= 1
	pe = minf(max_pe, pe + 55.0)
	AudioManager.play_sfx("haste", -3.5, 0.04)
	EventBus.toast_message.emit("PE Light usado! +55 PE", Color(0.75, 0.5, 1.0))
	EventBus.player_stats_changed.emit()
	return true


func spend_bp_upgrade(stat_type: String) -> String:
	var cost: int = 10
	match stat_type:
		"hp":
			cost = 10
			if bp < cost:
				return "BP insuficiente (precisa de %d BP)." % cost
			bp -= cost
			max_hp += 15
			hp += 15
		"pe":
			cost = 10
			if bp < cost:
				return "BP insuficiente (precisa de %d BP)." % cost
			bp -= cost
			max_pe += 10.0
			pe = minf(max_pe, pe + 10.0)
		"atk":
			cost = 15
			if bp < cost:
				return "BP insuficiente (precisa de %d BP)." % cost
			bp -= cost
			base_attack += 3
		"atb":
			cost = 15
			if bp < cost:
				return "BP insuficiente (precisa de %d BP)." % cost
			bp -= cost
			atb_rate += 3.5
		_:
			return ""
	AudioManager.play_sfx("level_up", -3.0, 0.05)
	EventBus.player_stats_changed.emit()
	return "Evolução Bio-Celular aplicada!"


func get_current_range_px() -> float:
	var base_range: float = get_equipped_weapon().range_px
	if tactical_action_mode == "energy_shot":
		return base_range + 90.0
	return base_range


func get_total_attack() -> int:
	return base_attack + get_equipped_weapon().attack_bonus


func get_total_defense() -> int:
	return 4 + level * 2 + get_equipped_armor().defense_bonus


func get_exp_for_next_level(lvl: int) -> int:
	if PE_EXP_CHART.has(lvl):
		return int(PE_EXP_CHART[lvl])
	return 1100 + (lvl - 15) * 450


func get_hp_for_level(lvl: int) -> int:
	if lvl <= 1:
		return 445
	return int(floor(445.0 + (9999.0 - 445.0) * pow(float(lvl - 1) / 98.0, 1.1)))


func get_formatted_play_time() -> String:
	var total: int = int(play_time_seconds)
	var hrs: int = total / 3600
	var mins: int = (total % 3600) / 60
	var secs: int = total % 60
	return "%02d:%02d:%02d" % [hrs, mins, secs]


func tick_realtime(delta: float) -> void:
	if not is_game_over and not is_victory:
		play_time_seconds += delta

	if is_world_paused():
		return

	var changed: bool = false

	if haste_timer > 0.0:
		haste_timer = maxf(0.0, haste_timer - delta)
		changed = true

	if barrier_timer > 0.0:
		barrier_timer = maxf(0.0, barrier_timer - delta)
		changed = true

	if slow_timer > 0.0:
		slow_timer = maxf(0.0, slow_timer - delta)
		changed = true

	if poison_timer > 0.0:
		poison_timer = maxf(0.0, poison_timer - delta)
		_poison_accum += delta
		if _poison_accum >= 1.0:
			_poison_accum -= 1.0
			hp = maxi(1, hp - 10)
		changed = true

	if darkness_timer > 0.0:
		darkness_timer = maxf(0.0, darkness_timer - delta)
		changed = true

	if stiff_timer > 0.0:
		stiff_timer = maxf(0.0, stiff_timer - delta)
		changed = true

	var atb_mult: float = 2.0 if haste_timer > 0.0 else 1.0
	if atb < 100.0:
		var was_ready: bool = atb >= 99.9
		atb = minf(100.0, atb + atb_rate * atb_mult * delta)
		if not was_ready and atb >= 99.9:
			AudioManager.play_sfx("atb_ready", -5.0, 0.02)
		changed = true

	var pe_regen: float = 12.0 if in_safe_room else 2.2
	if pe < max_pe:
		pe = minf(max_pe, pe + pe_regen * delta)
		changed = true

	if in_safe_room:
		if poison_timer > 0.0 or darkness_timer > 0.0 or stiff_timer > 0.0:
			poison_timer = 0.0
			darkness_timer = 0.0
			stiff_timer = 0.0
			changed = true
		if hp < max_hp:
			hp = mini(max_hp, hp + int(ceil(18.0 * delta)))
			changed = true

	if changed:
		EventBus.player_stats_changed.emit()


func is_atb_ready() -> bool:
	return atb >= 99.9


func consume_atb() -> void:
	atb = 0.0
	EventBus.player_stats_changed.emit()


func apply_damage(amount: int, world_pos: Vector2) -> void:
	if is_game_over or is_victory:
		return
	var mitigated: int = maxi(8, amount - int(floor(float(get_total_defense()) * 0.55)))
	if level >= 4:
		mitigated = int(round(float(mitigated) * 0.75))
	if barrier_timer > 0.0:
		mitigated = int(round(float(mitigated) * 0.65))

	hp = maxi(0, hp - mitigated)
	AudioManager.play_sfx("player_hurt", -2.0, 0.05)
	EventBus.floating_text_requested.emit("-%d" % mitigated, world_pos + Vector2(0, -40), Color(1.0, 0.28, 0.32))
	EventBus.screen_shake_requested.emit(7.0, 0.22)

	# Auto-Heal armor perk: auto-triggers Medkit below 25% HP
	if hp > 0 and hp < int(max_hp * 0.25) and has_armor_perk("autoheal") and medkits > 0:
		use_medkit()
		EventBus.floating_text_requested.emit("AUTO-HEAL!", world_pos + Vector2(0, -64), Color(0.3, 1.0, 0.6))

	EventBus.player_stats_changed.emit()

	if hp <= 0:
		is_game_over = true
		set_tactical_pause(false)
		EventBus.game_over_triggered.emit()


func heal_player(amount: int, world_pos: Vector2) -> void:
	var healed: int = mini(max_hp - hp, amount)
	hp += healed
	EventBus.floating_text_requested.emit("+%d HP" % healed, world_pos + Vector2(0, -44), Color(0.25, 1.0, 0.55))
	EventBus.player_stats_changed.emit()


func register_bestiary_kill(bestiary_id: String) -> void:
	bestiary_kills[bestiary_id] = int(bestiary_kills.get(bestiary_id, 0)) + 1


func award_exp_and_bp(exp_gain: int, bp_gain: int, world_pos: Vector2) -> void:
	exp += exp_gain
	bp += bp_gain
	while exp >= exp_to_next:
		exp -= exp_to_next
		level += 1
		exp_to_next = get_exp_for_next_level(level)
		var new_max: int = get_hp_for_level(level) + get_equipped_armor().hp_bonus
		var hp_diff: int = maxi(20, new_max - max_hp)
		max_hp += hp_diff
		hp = max_hp
		max_pe += 15.0
		pe = max_pe
		base_attack += 4
		AudioManager.play_sfx("level_up", -1.5, 0.0)
		EventBus.floating_text_requested.emit("LEVEL UP! LV.%d" % level, world_pos + Vector2(0, -64), Color(1.0, 0.88, 0.3))
		EventBus.toast_message.emit("Nível %d alcançado! HP e PE restaurados." % level, Color(1.0, 0.85, 0.3))
	EventBus.player_stats_changed.emit()


func set_tactical_pause(active: bool, mode_type: String = "attack") -> void:
	if active and (not is_atb_ready() or is_menu_open or is_dialogue_open):
		if not is_menu_open and not is_dialogue_open:
			EventBus.toast_message.emit("Barra ATB carregando...", Color(1.0, 0.7, 0.3))
		return
	is_tactical_paused = active
	tactical_action_mode = mode_type
	EventBus.tactical_mode_changed.emit(active, mode_type)
	EventBus.player_stats_changed.emit()


func set_menu_open(open: bool) -> void:
	is_menu_open = open
	if open and is_tactical_paused:
		is_tactical_paused = false
		EventBus.tactical_mode_changed.emit(false, "attack")
	EventBus.player_stats_changed.emit()


func set_dialogue_open(open: bool) -> void:
	is_dialogue_open = open
	if open and is_tactical_paused:
		is_tactical_paused = false
		EventBus.tactical_mode_changed.emit(false, "attack")
	EventBus.player_stats_changed.emit()


# --- SAVE / LOAD SYSTEM (persists on desktop & mobile Web IndexedDB) ---

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game(player_world_pos: Vector2 = Vector2(-1, -1)) -> bool:
	var serialized_weapons: Array = []
	for w in weapons:
		serialized_weapons.append({
			"id": w.id,
			"display_name": w.display_name,
			"caliber": w.caliber,
			"attack_bonus": w.attack_bonus,
			"range_px": w.range_px,
			"rate_of_fire": w.rate_of_fire,
			"capacity": w.capacity,
			"icon_path": w.icon_path,
			"description": w.description,
		})

	var room_data: Dictionary = RoomDatabase.get_room(current_room_id)
	var payload: Dictionary = {
		"version": 1,
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"room_id": current_room_id,
		"room_title": str(room_data.get("title", current_room_id)),
		"player_x": player_world_pos.x,
		"player_y": player_world_pos.y,
		"level": level,
		"exp": exp,
		"exp_to_next": exp_to_next,
		"hp": hp,
		"max_hp": max_hp,
		"pe": pe,
		"max_pe": max_pe,
		"base_attack": base_attack,
		"bp": bp,
		"play_time_seconds": play_time_seconds,
		"medkits": medkits,
		"pe_lights": pe_lights,
		"tools": tools,
		"ammo_by_caliber": ammo_by_caliber,
		"weapons": serialized_weapons,
		"equipped_weapon_index": equipped_weapon_index,
		"equipped_armor_index": equipped_armor_index,
		"has_keycard": has_keycard,
		"collected_pickups": collected_pickups,
		"defeated_enemy_keys": defeated_enemy_keys,
		"seen_dialogues": seen_dialogues,
		"bestiary_kills": bestiary_kills,
	}

	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	AudioManager.play_sfx("heal", -3.0, 0.0)
	EventBus.toast_message.emit("Progresso salvo no Terminal de Segurança!", Color(0.35, 1.0, 0.7))
	return true


func get_save_summary() -> Dictionary:
	if not has_save_file():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func load_game() -> bool:
	var data: Dictionary = get_save_summary()
	if data.is_empty():
		return false

	reset_run()
	level = int(data.get("level", 1))
	exp = int(data.get("exp", 0))
	exp_to_next = int(data.get("exp_to_next", get_exp_for_next_level(level)))
	max_hp = int(data.get("max_hp", 445))
	hp = clampi(int(data.get("hp", max_hp)), 1, max_hp)
	max_pe = float(data.get("max_pe", 100.0))
	pe = clampf(float(data.get("pe", max_pe)), 0.0, max_pe)
	base_attack = int(data.get("base_attack", 25))
	bp = int(data.get("bp", 0))
	play_time_seconds = float(data.get("play_time_seconds", 0.0))
	medkits = int(data.get("medkits", 3))
	pe_lights = int(data.get("pe_lights", 2))
	tools = int(data.get("tools", 2))

	if data.get("ammo_by_caliber") is Dictionary:
		ammo_by_caliber = (data["ammo_by_caliber"] as Dictionary).duplicate()

	if data.get("weapons") is Array:
		var loaded_weapons: Array[WeaponData] = []
		for wd in (data["weapons"] as Array):
			if wd is Dictionary:
				var d: Dictionary = wd as Dictionary
				var w := WeaponData.new()
				w.id = str(d.get("id", "m93r"))
				w.display_name = str(d.get("display_name", "M93R"))
				w.caliber = str(d.get("caliber", "9mm"))
				w.attack_bonus = int(d.get("attack_bonus", 15))
				w.range_px = float(d.get("range_px", 230.0))
				w.rate_of_fire = int(d.get("rate_of_fire", 2))
				w.capacity = int(d.get("capacity", 15))
				w.icon_path = str(d.get("icon_path", "res://assets/icons/Pe1_icon_inv_pistol.png"))
				w.description = str(d.get("description", ""))
				loaded_weapons.append(w)
		if not loaded_weapons.is_empty():
			weapons = loaded_weapons

	equipped_weapon_index = clampi(int(data.get("equipped_weapon_index", 0)), 0, maxi(0, weapons.size() - 1))
	equipped_armor_index = clampi(int(data.get("equipped_armor_index", 0)), 0, maxi(0, armors.size() - 1))
	current_room_id = str(data.get("room_id", "gala_hall"))
	saved_player_pos = Vector2(float(data.get("player_x", -1.0)), float(data.get("player_y", -1.0)))
	has_keycard = bool(data.get("has_keycard", false))

	if data.get("collected_pickups") is Dictionary:
		collected_pickups = (data["collected_pickups"] as Dictionary).duplicate()
	if data.get("defeated_enemy_keys") is Dictionary:
		defeated_enemy_keys = (data["defeated_enemy_keys"] as Dictionary).duplicate()
	if data.get("seen_dialogues") is Dictionary:
		seen_dialogues = (data["seen_dialogues"] as Dictionary).duplicate()
	if data.get("bestiary_kills") is Dictionary:
		bestiary_kills = (data["bestiary_kills"] as Dictionary).duplicate()

	EventBus.player_stats_changed.emit()
	return true
