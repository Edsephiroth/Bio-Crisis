extends Node

## Global state manager for Elisabeth Shelley (migrated from Bio Crisis prototype).

var level: int = 1
var exp: int = 0
var exp_to_next: int = 3
var hp: int = 445
var max_hp: int = 445
var pe: float = 100.0
var max_pe: float = 100.0
var atb: float = 0.0
var atb_rate: float = 34.0 # % per second (~2.9s to fill)
var base_attack: int = 25
var bp: int = 0
var ammo: int = 120
var medkits: int = 2

var haste_timer: float = 0.0
var in_safe_room: bool = false
var is_tactical_paused: bool = false
var tactical_action_mode: String = "attack" # "attack" or "energy_shot"
var is_game_over: bool = false
var is_victory: bool = false

## Virtual joystick input vector (populated by touch controls on mobile)
var virtual_move_vector: Vector2 = Vector2.ZERO

var weapons: Array[WeaponData] = []
var equipped_weapon_index: int = 0

const PE_EXP_CHART: Dictionary = {
	1: 3, 2: 8, 3: 19, 4: 28, 5: 45, 6: 70, 7: 105, 8: 150, 9: 210, 10: 290,
	11: 390, 12: 520, 13: 680, 14: 870, 15: 1100
}


func _ready() -> void:
	_init_starter_weapons()
	reset_run()


func _init_starter_weapons() -> void:
	weapons.clear()

	var m93r := WeaponData.new()
	m93r.id = "m93r"
	m93r.display_name = "M93R"
	m93r.caliber = "9mm"
	m93r.attack_bonus = 18
	m93r.range_px = 230.0
	m93r.rate_of_fire = 3
	m93r.capacity = 20
	m93r.icon_path = "res://assets/icons/Pe1_icon_inv_pistol.png"
	m93r.description = "Pistola 9mm com rajada de 3 tiros."
	weapons.append(m93r)

	var m870 := WeaponData.new()
	m870.id = "m870"
	m870.display_name = "M870 Shotgun"
	m870.caliber = "12G"
	m870.attack_bonus = 36
	m870.range_px = 165.0
	m870.rate_of_fire = 1
	m870.capacity = 6
	m870.icon_path = "res://assets/icons/Pe1_icon_inv_shotgun.png"
	m870.description = "Curto alcance, impacto devastador."
	weapons.append(m870)

	var m4a1 := WeaponData.new()
	m4a1.id = "m4a1"
	m4a1.display_name = "M4A1 Rifle"
	m4a1.caliber = "5.56mm"
	m4a1.attack_bonus = 28
	m4a1.range_px = 300.0
	m4a1.rate_of_fire = 2
	m4a1.capacity = 30
	m4a1.icon_path = "res://assets/icons/Pe1_icon_inv_rifle.png"
	m4a1.description = "Longo alcance tático e alta precisão."
	weapons.append(m4a1)


func reset_run() -> void:
	level = 1
	exp = 0
	exp_to_next = get_exp_for_next_level(level)
	max_hp = get_hp_for_level(level)
	hp = max_hp
	max_pe = 100.0
	pe = max_pe
	atb = 100.0 # Starts ready so player can immediately test tactical sphere
	base_attack = 25
	bp = 0
	ammo = 120
	medkits = 2
	haste_timer = 0.0
	in_safe_room = false
	is_tactical_paused = false
	tactical_action_mode = "attack"
	is_game_over = false
	is_victory = false
	equipped_weapon_index = 0
	virtual_move_vector = Vector2.ZERO
	EventBus.player_stats_changed.emit()


func get_equipped_weapon() -> WeaponData:
	if weapons.is_empty():
		_init_starter_weapons()
	return weapons[equipped_weapon_index % weapons.size()]


func cycle_weapon() -> void:
	if weapons.is_empty():
		return
	equipped_weapon_index = (equipped_weapon_index + 1) % weapons.size()
	var w: WeaponData = get_equipped_weapon()
	EventBus.toast_message.emit("Arma equipada: %s (%s)" % [w.display_name, w.caliber], Color(0.45, 0.9, 1.0))
	EventBus.player_stats_changed.emit()


func get_current_range_px() -> float:
	var base_range: float = get_equipped_weapon().range_px
	if tactical_action_mode == "energy_shot":
		return base_range + 90.0
	return base_range


func get_total_attack() -> int:
	return base_attack + get_equipped_weapon().attack_bonus


func get_exp_for_next_level(lvl: int) -> int:
	if PE_EXP_CHART.has(lvl):
		return int(PE_EXP_CHART[lvl])
	return 1100 + (lvl - 15) * 450


func get_hp_for_level(lvl: int) -> int:
	if lvl <= 1:
		return 445
	return int(floor(445.0 + (9999.0 - 445.0) * pow(float(lvl - 1) / 98.0, 1.1)))


func tick_realtime(delta: float) -> void:
	if is_tactical_paused or is_game_over or is_victory:
		return

	var changed: bool = false

	if haste_timer > 0.0:
		haste_timer = maxf(0.0, haste_timer - delta)
		changed = true

	var atb_mult: float = 2.0 if haste_timer > 0.0 else 1.0
	if atb < 100.0:
		atb = minf(100.0, atb + atb_rate * atb_mult * delta)
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
	# Passive Gene Barrier at Level 4+ (-25% damage)
	var final_dmg: int = amount
	if level >= 4:
		final_dmg = int(round(float(amount) * 0.75))

	hp = maxi(0, hp - final_dmg)
	EventBus.floating_text_requested.emit("-%d" % final_dmg, world_pos + Vector2(0, -40), Color(1.0, 0.28, 0.32))
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


func award_exp_and_bp(exp_gain: int, bp_gain: int, world_pos: Vector2) -> void:
	exp += exp_gain
	bp += bp_gain
	while exp >= exp_to_next:
		exp -= exp_to_next
		level += 1
		exp_to_next = get_exp_for_next_level(level)
		var new_max: int = get_hp_for_level(level)
		var hp_diff: int = maxi(20, new_max - max_hp)
		max_hp += hp_diff
		hp = max_hp
		max_pe += 15.0
		pe = max_pe
		base_attack += 4
		EventBus.floating_text_requested.emit("LEVEL UP! LV.%d" % level, world_pos + Vector2(0, -64), Color(1.0, 0.88, 0.3))
		EventBus.toast_message.emit("Nível %d alcançado! HP e PE restaurados." % level, Color(1.0, 0.85, 0.3))
	EventBus.player_stats_changed.emit()


func set_tactical_pause(active: bool, mode_type: String = "attack") -> void:
	if active and not is_atb_ready():
		EventBus.toast_message.emit("Barra ATB carregando...", Color(1.0, 0.7, 0.3))
		return
	is_tactical_paused = active
	tactical_action_mode = mode_type
	EventBus.tactical_mode_changed.emit(active, mode_type)
	EventBus.player_stats_changed.emit()
