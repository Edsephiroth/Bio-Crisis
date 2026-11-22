extends CanvasLayer

@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var pe_bar: ProgressBar = %PeBar
@onready var pe_label: Label = %PeLabel
@onready var atb_bar: ProgressBar = %AtbBar
@onready var atb_label: Label = %AtbLabel
@onready var level_label: Label = %LevelLabel
@onready var status_badge: Label = %StatusBadge
@onready var weapon_icon: TextureRect = %WeaponIcon
@onready var weapon_label: Label = %WeaponLabel
@onready var ammo_label: Label = %AmmoLabel
@onready var enemies_label: Label = %EnemiesLabel
@onready var toast_label: Label = %ToastLabel

@onready var tactical_panel: PanelContainer = %TacticalPanel
@onready var btn_tactical: Button = %BtnTactical
@onready var btn_fire: Button = %BtnFire
@onready var btn_energy: Button = %BtnEnergy
@onready var btn_heal: Button = %BtnHeal
@onready var btn_haste: Button = %BtnHaste
@onready var btn_cancel: Button = %BtnCancel
@onready var btn_switch_weapon: Button = %BtnSwitchWeapon
@onready var btn_mute: Button = %BtnMute
@onready var btn_menu: Button = %BtnMenu
@onready var inventory_menu: InventoryMenu = %InventoryMenu

@onready var end_overlay: ColorRect = %EndOverlay
@onready var end_title: Label = %EndTitle
@onready var end_subtitle: Label = %EndSubtitle
@onready var btn_restart: Button = %BtnRestart

var toast_timer: float = 0.0


func _ready() -> void:
	EventBus.player_stats_changed.connect(_refresh_hud)
	EventBus.tactical_mode_changed.connect(_on_tactical_changed)
	EventBus.toast_message.connect(_on_toast)
	EventBus.enemy_defeated.connect(_on_enemy_defeated)
	EventBus.game_over_triggered.connect(_on_game_over)
	EventBus.victory_triggered.connect(_on_victory)

	btn_tactical.pressed.connect(_on_btn_tactical_pressed)
	btn_fire.pressed.connect(_on_btn_fire_pressed)
	btn_energy.pressed.connect(_on_btn_energy_pressed)
	btn_heal.pressed.connect(_on_btn_heal_pressed)
	btn_haste.pressed.connect(_on_btn_haste_pressed)
	btn_cancel.pressed.connect(_on_btn_cancel_pressed)
	btn_switch_weapon.pressed.connect(func() -> void: GameState.cycle_weapon())
	btn_mute.pressed.connect(_on_btn_mute_pressed)
	btn_menu.pressed.connect(func() -> void: inventory_menu.open_menu())
	btn_restart.pressed.connect(_on_restart_pressed)

	tactical_panel.visible = false
	end_overlay.visible = false
	_refresh_hud()


func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			toast_label.text = ""


func _get_level() -> ChildrenFirstHall:
	return get_parent() as ChildrenFirstHall


func _refresh_hud() -> void:
	hp_bar.max_value = GameState.max_hp
	hp_bar.value = GameState.hp
	hp_label.text = "HP %d / %d" % [GameState.hp, GameState.max_hp]

	pe_bar.max_value = GameState.max_pe
	pe_bar.value = GameState.pe
	pe_label.text = "PE %d / %d" % [int(GameState.pe), int(GameState.max_pe)]

	atb_bar.max_value = 100.0
	atb_bar.value = GameState.atb
	atb_label.text = "ATB READY!" if GameState.is_atb_ready() else "ATB %d%%" % int(GameState.atb)

	level_label.text = "ELISABETH  LV.%d  |  BP %d" % [GameState.level, GameState.bp]

	var badges: PackedStringArray = PackedStringArray()
	if GameState.in_safe_room:
		badges.append("SAFE ROOM")
	if GameState.haste_timer > 0.0:
		badges.append("HASTE %ds" % int(ceil(GameState.haste_timer)))
	status_badge.text = "  •  ".join(badges)

	var weapon: WeaponData = GameState.get_equipped_weapon()
	weapon_label.text = "%s (%s)" % [weapon.display_name, weapon.caliber]
	ammo_label.text = "Mun %s: %d  |  ATK %d" % [weapon.caliber, GameState.get_current_ammo(), GameState.get_total_attack()]
	if ResourceLoader.exists(weapon.icon_path):
		weapon_icon.texture = load(weapon.icon_path) as Texture2D

	var remaining: int = get_tree().get_nodes_in_group("enemies").size()
	enemies_label.text = "Ameaças: %d" % remaining

	btn_tactical.disabled = not GameState.is_atb_ready() and not GameState.is_tactical_paused
	btn_tactical.text = "FECHAR\nTÁTICO" if GameState.is_tactical_paused else ("TÁTICO\nATB PRONTO" if GameState.is_atb_ready() else "ATB %d%%" % int(GameState.atb))


func _on_enemy_defeated(_n: String, _e: int, _b: int, _p: Vector2) -> void:
	call_deferred("_refresh_hud")


func _on_tactical_changed(active: bool, mode_type: String) -> void:
	tactical_panel.visible = active
	if active:
		btn_energy.text = "ENERGY SHOT (30 PE) [ATIVO]" if mode_type == "energy_shot" else "ENERGY SHOT (30 PE)"
	_refresh_hud()


func _on_toast(text: String, color: Color) -> void:
	toast_label.text = text
	toast_label.modulate = color
	toast_timer = 3.2


func _on_btn_tactical_pressed() -> void:
	if GameState.is_tactical_paused:
		GameState.set_tactical_pause(false)
	else:
		GameState.set_tactical_pause(true, "attack")


func _on_btn_fire_pressed() -> void:
	var lvl: ChildrenFirstHall = _get_level()
	if lvl != null:
		GameState.tactical_action_mode = "attack"
		lvl.execute_quick_tactical_fire()


func _on_btn_energy_pressed() -> void:
	if GameState.pe < 30.0:
		EventBus.toast_message.emit("PE insuficiente (30 PE).", Color(1.0, 0.45, 0.45))
		return
	var lvl: ChildrenFirstHall = _get_level()
	if lvl != null:
		GameState.set_tactical_pause(true, "energy_shot")
		lvl.execute_quick_tactical_fire()


func _on_btn_heal_pressed() -> void:
	var lvl: ChildrenFirstHall = _get_level()
	if lvl != null:
		lvl.cast_heal()


func _on_btn_haste_pressed() -> void:
	var lvl: ChildrenFirstHall = _get_level()
	if lvl != null:
		lvl.cast_haste()


func _on_btn_cancel_pressed() -> void:
	GameState.set_tactical_pause(false)


func _on_game_over() -> void:
	end_overlay.visible = true
	end_title.text = "SINAL VITAL PERDIDO"
	end_title.modulate = Color(1.0, 0.3, 0.35)
	end_subtitle.text = "Elisabeth caiu no Salão de Gala da ONG Children First."


func _on_victory() -> void:
	end_overlay.visible = true
	end_title.text = "SALÃO DE GALA LIMPO!"
	end_title.modulate = Color(0.35, 1.0, 0.65)
	end_subtitle.text = "Vertical Slice concluído — LV.%d | %d BP acumulados." % [GameState.level, GameState.bp]


func _on_btn_mute_pressed() -> void:
	var muted: bool = AudioManager.toggle_mute()
	btn_mute.text = "Som: OFF" if muted else "Som: ON"


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
