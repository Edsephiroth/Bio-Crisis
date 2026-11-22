extends Node

## Global state manager for Elisabeth Shelley (ATB, PE, Inventory, Armors, Ammo by Caliber, Tune, Bestiary).

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

var medkits: int = 3
var pe_lights: int = 2
var tools: int = 2

var ammo_by_caliber: Dictionary = {
	"9mm": 120,
	"12G": 24,
	"5.56mm": 90,
}

var haste_timer: float = 0.0
var in_safe_room: bool = false
var is_tactical_paused: bool = false
var is_menu_open: bool = false
var is_dialogue_open: bool = false
var tactical_action_mode: String = "attack"
var is_game_over: bool = false
var is_victory: bool = false

var current_room_id: String = "gala_hall"
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
	in_safe_room = false
	is_tactical_paused = false
	is_menu_open = false
	is_dialogue_open = false
	tactical_action_mode = "attack"
	is_game_over = false
	is_victory = false
	current_room_id = "gala_hall"
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


func get_current_ammo() -> int:
	var cal: String = get_equipped_weapon().caliber
	return int(ammo_by_caliber.get(cal, 0))


func consume_current_ammo(count: int) -> int:
	var cal: String = get_equipped_weapon().caliber
	var avail: int = int(ammo_by_caliber.get(cal, 0))
	var used: int = mini(count, avail)
	ammo_by_caliber[cal] = avail - used
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
	return "TUNE concluído! %s ganhou +%d ATK e +%dpx alcance." % [target.display_name, atk_gain, int(rng_gain)]


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


func tick_realtime(delta: float) -> void:
	if is_world_paused():
		return

	var changed: bool = false

	if haste_timer > 0.0:
		haste_timer = maxf(0.0, haste_timer - delta)
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

	if in_safe_room and hp < max_hp:
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

	hp = maxi(0, hp - mitigated)
	AudioManager.play_sfx("player_hurt", -2.0, 0.05)
	EventBus.floating_text_requested.emit("-%d" % mitigated, world_pos + Vector2(0, -40), Color(1.0, 0.28, 0.32))
	EventBus.screen_shake_requested.emit(7.0, 0.22)
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
