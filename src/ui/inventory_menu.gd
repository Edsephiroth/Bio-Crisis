class_name InventoryMenu
extends Control

## ModernMenu ported from the original Bio Crisis prototype:
## 6 tabs (Inventory, Map, PE Energy, Status, Extras [Documents/Bestiary], Settings) over Menu_Background.webp.

const BUST_TEX: Texture2D = preload("res://assets/ui/elisabeth_bust.png")

@onready var tab_inventory_btn: Button = %TabInventory
@onready var tab_map_btn: Button = %TabMap
@onready var tab_pe_btn: Button = %TabPE
@onready var tab_status_btn: Button = %TabStatus
@onready var tab_extras_btn: Button = %TabExtras
@onready var tab_settings_btn: Button = %TabSettings
@onready var btn_close: Button = %BtnClose
@onready var status_summary: Label = %StatusSummary
@onready var content_vbox: VBoxContainer = %ContentVBox
@onready var feedback_label: Label = %FeedbackLabel

var current_tab: String = "inventory"
var inv_sub_tab: String = "weapons" # "weapons", "armors", "supplies"
var extras_sub_tab: String = "docs" # "docs", "bestiary"
var tune_mode_active: bool = false


func _ready() -> void:
	visible = false
	tab_inventory_btn.pressed.connect(func() -> void: _switch_tab("inventory"))
	tab_map_btn.pressed.connect(func() -> void: _switch_tab("map"))
	tab_pe_btn.pressed.connect(func() -> void: _switch_tab("pe"))
	tab_status_btn.pressed.connect(func() -> void: _switch_tab("status"))
	tab_extras_btn.pressed.connect(func() -> void: _switch_tab("extras"))
	tab_settings_btn.pressed.connect(func() -> void: _switch_tab("settings"))
	btn_close.pressed.connect(close_menu)


func open_menu(initial_tab: String = "inventory") -> void:
	current_tab = initial_tab
	visible = true
	tune_mode_active = false
	feedback_label.text = ""
	GameState.set_menu_open(true)
	AudioManager.play_sfx("tactical_open", -6.0, 0.02)
	_refresh()


func close_menu() -> void:
	visible = false
	tune_mode_active = false
	GameState.set_menu_open(false)


func _get_level() -> ChildrenFirstHall:
	var hud_node: Node = get_parent()
	if hud_node != null:
		return hud_node.get_parent() as ChildrenFirstHall
	return null


func _switch_tab(tab_id: String) -> void:
	current_tab = tab_id
	tune_mode_active = false
	feedback_label.text = ""
	_refresh()


func _refresh() -> void:
	var room_data: Dictionary = RoomDatabase.get_room(GameState.current_room_id)
	status_summary.text = "ELISABETH LV.%d  |  HP %d/%d  |  PE %d/%d  |  BP %d  |  %s  |  Tempo %s" % [
		GameState.level,
		GameState.hp, GameState.max_hp,
		int(GameState.pe), int(GameState.max_pe),
		GameState.bp,
		str(room_data.get("title", "ONG Children First")),
		GameState.get_formatted_play_time(),
	]

	for child in content_vbox.get_children():
		child.queue_free()

	match current_tab:
		"inventory":
			_build_inventory_tab()
		"map":
			_build_map_tab()
		"pe":
			_build_pe_tab()
		"status":
			_build_status_tab()
		"extras":
			_build_extras_tab()
		"settings":
			_build_settings_tab()


# --- TAB 1: INVENTORY (Weapons & Tune / Armors / Supplies) ---

func _build_inventory_tab() -> void:
	var sub_row := HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 8)
	for pair in [["weapons", "ARMAS & TUNE"], ["armors", "ARMADURAS"], ["supplies", "ITENS & MUNIÇÃO"]]:
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 34)
		var sid: String = str(pair[0])
		btn.text = ("▶ " + str(pair[1])) if inv_sub_tab == sid else str(pair[1])
		btn.pressed.connect(func() -> void:
			inv_sub_tab = sid
			tune_mode_active = false
			_refresh()
		)
		sub_row.add_child(btn)
	content_vbox.add_child(sub_row)

	match inv_sub_tab:
		"weapons":
			_build_weapons_section()
		"armors":
			_build_armors_section()
		"supplies":
			_build_supplies_section()


func _build_weapons_section() -> void:
	var equipped: WeaponData = GameState.get_equipped_weapon()
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 13)
	if tune_mode_active:
		lbl.text = "MODO TUNE: Escolha a arma DOADORA para transferir bônus para %s (usa 1 Tool)." % equipped.display_name
		lbl.modulate = Color(1.0, 0.85, 0.3)
	else:
		lbl.text = "Equipada: %s (%s) — ATK +%d | Alcance %dpx | Rajada %dx" % [
			equipped.display_name, equipped.caliber, equipped.attack_bonus, int(equipped.range_px), equipped.rate_of_fire
		]
		lbl.modulate = Color(0.5, 0.92, 1.0)
	header.add_child(lbl)

	var btn_tune := Button.new()
	btn_tune.custom_minimum_size = Vector2(165, 34)
	btn_tune.text = "CANCELAR TUNE" if tune_mode_active else "TUNE ARMA (Tools: %d)" % GameState.tools
	btn_tune.disabled = (not tune_mode_active) and (GameState.tools <= 0 or GameState.weapons.size() < 2)
	btn_tune.pressed.connect(func() -> void:
		tune_mode_active = not tune_mode_active
		_refresh()
	)
	header.add_child(btn_tune)
	content_vbox.add_child(header)

	for i in range(GameState.weapons.size()):
		var weapon: WeaponData = GameState.weapons[i]
		var is_eq: bool = (i == GameState.equipped_weapon_index)
		var row := PanelContainer.new()
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		row.add_child(hbox)

		if ResourceLoader.exists(weapon.icon_path):
			var tex := TextureRect.new()
			tex.texture = load(weapon.icon_path) as Texture2D
			tex.custom_minimum_size = Vector2(36, 36)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hbox.add_child(tex)

		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_font_size_override("font_size", 12)
		var ammo_cnt: int = int(GameState.ammo_by_caliber.get(weapon.caliber, 0))
		info.text = "%s%s  [%s: %d]  |  ATK +%d  |  Alcance %dpx  |  %dx\n%s" % [
			"[EQUIPADA] " if is_eq else "",
			weapon.display_name, weapon.caliber, ammo_cnt,
			weapon.attack_bonus, int(weapon.range_px), weapon.rate_of_fire,
			weapon.description
		]
		if is_eq:
			info.modulate = Color(0.45, 1.0, 0.78)
		hbox.add_child(info)

		var action_btn := Button.new()
		action_btn.custom_minimum_size = Vector2(124, 36)
		if tune_mode_active:
			if is_eq:
				action_btn.text = "ALVO"
				action_btn.disabled = true
			else:
				action_btn.text = "USAR NO TUNE"
				var donor_idx: int = i
				action_btn.pressed.connect(func() -> void:
					var msg: String = GameState.tune_weapon(GameState.equipped_weapon_index, donor_idx)
					tune_mode_active = false
					feedback_label.text = msg
					feedback_label.modulate = Color(1.0, 0.88, 0.35)
					_refresh()
				)
		else:
			action_btn.text = "EQUIPADA" if is_eq else "EQUIPAR"
			action_btn.disabled = is_eq
			var idx: int = i
			action_btn.pressed.connect(func() -> void:
				GameState.equip_weapon(idx)
				_refresh()
			)
		hbox.add_child(action_btn)
		content_vbox.add_child(row)


func _build_armors_section() -> void:
	var equipped_armor: ArmorData = GameState.get_equipped_armor()
	var sec_lbl := Label.new()
	sec_lbl.text = "Armadura Equipada: %s — DEF Total: %d" % [equipped_armor.display_name, GameState.get_total_defense()]
	sec_lbl.modulate = Color(0.5, 0.92, 1.0)
	sec_lbl.add_theme_font_size_override("font_size", 13)
	content_vbox.add_child(sec_lbl)

	for i in range(GameState.armors.size()):
		var armor: ArmorData = GameState.armors[i]
		var is_eq: bool = (i == GameState.equipped_armor_index)
		var row := PanelContainer.new()
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		row.add_child(hbox)

		if ResourceLoader.exists(armor.icon_path):
			var tex := TextureRect.new()
			tex.texture = load(armor.icon_path) as Texture2D
			tex.custom_minimum_size = Vector2(36, 36)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hbox.add_child(tex)

		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_font_size_override("font_size", 12)
		info.text = "%s%s  |  DEF +%d  |  PE-DEF +%d  |  HP +%d\n%s" % [
			"[EQUIPADA] " if is_eq else "",
			armor.display_name, armor.defense_bonus, armor.pe_defense_bonus, armor.hp_bonus, armor.description
		]
		if is_eq:
			info.modulate = Color(0.45, 1.0, 0.78)
		hbox.add_child(info)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(110, 36)
		btn.text = "EQUIPADA" if is_eq else "EQUIPAR"
		btn.disabled = is_eq
		var idx: int = i
		btn.pressed.connect(func() -> void:
			GameState.equip_armor(idx)
			_refresh()
		)
		hbox.add_child(btn)
		content_vbox.add_child(row)


func _build_supplies_section() -> void:
	var sup_row := HBoxContainer.new()
	sup_row.add_theme_constant_override("separation", 10)

	var btn_med := Button.new()
	btn_med.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_med.custom_minimum_size = Vector2(0, 44)
	btn_med.text = "USAR MEDKIT (+160 HP)  [x%d]" % GameState.medkits
	btn_med.disabled = GameState.medkits <= 0 or GameState.hp >= GameState.max_hp
	btn_med.pressed.connect(func() -> void:
		if GameState.use_medkit():
			feedback_label.text = "HP restaurado com Medkit!"
			feedback_label.modulate = Color(0.35, 1.0, 0.6)
			_refresh()
	)
	sup_row.add_child(btn_med)

	var btn_pe := Button.new()
	btn_pe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_pe.custom_minimum_size = Vector2(0, 44)
	btn_pe.text = "USAR PE LIGHT (+55 PE)  [x%d]" % GameState.pe_lights
	btn_pe.disabled = GameState.pe_lights <= 0 or GameState.pe >= GameState.max_pe
	btn_pe.pressed.connect(func() -> void:
		if GameState.use_pe_light():
			feedback_label.text = "Energia Bio-Celular (PE) restaurada!"
			feedback_label.modulate = Color(0.78, 0.55, 1.0)
			_refresh()
	)
	sup_row.add_child(btn_pe)
	content_vbox.add_child(sup_row)

	var ammo_card := PanelContainer.new()
	var ammo_lbl := Label.new()
	ammo_lbl.add_theme_font_size_override("font_size", 13)
	ammo_lbl.text = "MUNIÇÕES EM ESTOQUE:\n• 9mm (Pistolas/SMG): %d    • 12G (Shotgun): %d    • 5.56mm (Rifle): %d\n\nITENS-CHAVE & FERRAMENTAS:\n• Tools (para Tune): %d    • Keycard de Evacuação: %s" % [
		int(GameState.ammo_by_caliber.get("9mm", 0)),
		int(GameState.ammo_by_caliber.get("12G", 0)),
		int(GameState.ammo_by_caliber.get("5.56mm", 0)),
		GameState.tools,
		"OBTIDO ✓" if GameState.has_keycard else "Não encontrado (Corredor Leste)",
	]
	ammo_card.add_child(ammo_lbl)
	content_vbox.add_child(ammo_card)


# --- TAB 2: TACTICAL MAP ---

func _build_map_tab() -> void:
	var title := Label.new()
	title.text = "PLANTA TÁTICA — SEDE DA ONG CHILDREN FIRST (PRÓLOGO)"
	title.modulate = Color(0.45, 0.92, 1.0)
	title.add_theme_font_size_override("font_size", 14)
	content_vbox.add_child(title)

	var rooms_order: Array = [
		["main_hall", "3. HALL PRINCIPAL — ROTA DE EVACUAÇÃO (BOSS: MUTANTE ALFA)", "Exige Keycard de Evacuação na porta norte do Corredor."],
		["corridor", "2. CORREDOR LESTE — ALA DE SEGURANÇA", "Contém o Keycard de Evacuação e caixa de Tools/Munição."],
		["gala_hall", "1. SALÃO DE GALA — PONTO INICIAL", "Contém a Safe Room (cura HP/PE + Terminal de Save) e bilhete inicial."],
	]

	for entry in rooms_order:
		var rid: String = str(entry[0])
		var is_here: bool = (GameState.current_room_id == rid)
		var card := PanelContainer.new()
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.text = "%s%s\n%s" % ["[VOCÊ ESTÁ AQUI]  " if is_here else "", str(entry[1]), str(entry[2])]
		if is_here:
			lbl.modulate = Color(0.35, 1.0, 0.65)
		card.add_child(lbl)
		content_vbox.add_child(card)


# --- TAB 3: PARASITE ENERGY (PE) ---

func _build_pe_tab() -> void:
	var header := Label.new()
	header.text = "ENERGIA BIO-CELULAR (PE: %d / %d) — Clique em USAR para ativar imediatamente:" % [int(GameState.pe), int(GameState.max_pe)]
	header.modulate = Color(0.8, 0.55, 1.0)
	header.add_theme_font_size_override("font_size", 13)
	content_vbox.add_child(header)

	var skills: Array = [
		["heal", "HEAL 1", 30, "Recuperação", "Restaura HP usando regeneração celular mitocondrial."],
		["haste", "HASTE", 25, "Suporte", "Dobra velocidade da barra ATB e movimento por 18s."],
		["barrier", "BARRIER", 35, "Suporte", "Campo genético reduzindo -35% de todo dano recebido por 20s."],
		["slow", "SLOW", 30, "Suporte", "Reduz em 50% a velocidade de todos os inimigos na sala por 14s."],
		["scan", "SCAN", 15, "Suporte", "Escaneia HP exato e poder de ataque do inimigo mais próximo."],
		["energy_shot", "ENERGY SHOT", 30, "Ataque", "Feixe fotônico perfurante (ative no modo Tático)."],
		["liberate", "LIBERATE", 80, "Ataque Supremo", "Sobrecarga mitocondrial devastando todos os inimigos ao redor!"],
	]

	for sk in skills:
		var sid: String = str(sk[0])
		var sname: String = str(sk[1])
		var cost: int = int(sk[2])
		var cat: String = str(sk[3])
		var desc: String = str(sk[4])

		var card := PanelContainer.new()
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		card.add_child(hb)

		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.text = "%s  [%d PE • %s]\n%s" % [sname, cost, cat, desc]
		hb.add_child(lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(105, 36)
		btn.text = "USAR"
		btn.disabled = GameState.pe < float(cost)
		btn.pressed.connect(func() -> void: _cast_pe_from_menu(sid))
		hb.add_child(btn)
		content_vbox.add_child(card)


func _cast_pe_from_menu(skill_id: String) -> void:
	var lvl: ChildrenFirstHall = _get_level()
	if lvl == null:
		return
	close_menu()
	match skill_id:
		"heal":
			lvl.cast_heal()
		"haste":
			lvl.cast_haste()
		"barrier":
			lvl.cast_barrier()
		"slow":
			lvl.cast_slow()
		"scan":
			lvl.cast_scan()
		"energy_shot":
			GameState.set_tactical_pause(true, "energy_shot")
		"liberate":
			lvl.cast_liberate()


# --- TAB 4: STATUS ---

func _build_status_tab() -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)

	var portrait := TextureRect.new()
	portrait.texture = BUST_TEX
	portrait.custom_minimum_size = Vector2(150, 180)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(portrait)

	var w: WeaponData = GameState.get_equipped_weapon()
	var a: ArmorData = GameState.get_equipped_armor()
	var info := Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("font_size", 13)
	info.text = (
		"ELISABETH SHELLEY — Professora de Inglês\n"
		+ "Nível: %d   |   EXP: %d / %d   |   BP: %d\n"
		+ "HP: %d / %d   |   PE: %d / %d\n"
		+ "Ataque Total: %d   |   Defesa Total: %d\n\n"
		+ "Arma Equipada: %s (%s, +%d ATK)\n"
		+ "Armadura Equipada: %s (+%d DEF)\n\n"
		+ "Passivas Bio-Celulares:\n"
		+ "• LV.4 Gene Barrier (-25%% dano): %s\n"
		+ "• LV.5 Mitochondria Burst (+30%% crítico): %s"
	) % [
		GameState.level, GameState.exp, GameState.exp_to_next, GameState.bp,
		GameState.hp, GameState.max_hp, int(GameState.pe), int(GameState.max_pe),
		GameState.get_total_attack(), GameState.get_total_defense(),
		w.display_name, w.caliber, w.attack_bonus,
		a.display_name, a.defense_bonus,
		"ATIVA ✓" if GameState.level >= 4 else "Bloqueada (LV.4)",
		"ATIVA ✓" if GameState.level >= 5 else "Bloqueada (LV.5)",
	]
	hb.add_child(info)
	content_vbox.add_child(hb)


# --- TAB 5: EXTRAS (Documents + Bestiary) ---

func _build_extras_tab() -> void:
	var sub_row := HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 8)
	for pair in [["docs", "DOCUMENTOS & DOSSIÊS"], ["bestiary", "BESTIÁRIO BIOLÓGICO"]]:
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 34)
		var sid: String = str(pair[0])
		btn.text = ("▶ " + str(pair[1])) if extras_sub_tab == sid else str(pair[1])
		btn.pressed.connect(func() -> void:
			extras_sub_tab = sid
			_refresh()
		)
		sub_row.add_child(btn)
	content_vbox.add_child(sub_row)

	if extras_sub_tab == "docs":
		for doc in BioDatabase.get_documents():
			var card := PanelContainer.new()
			var vb := VBoxContainer.new()
			vb.add_theme_constant_override("separation", 4)
			card.add_child(vb)

			var title := Label.new()
			title.text = "%s  (%s)" % [str(doc["title"]), str(doc["date"])]
			title.modulate = Color(0.45, 0.9, 1.0)
			title.add_theme_font_size_override("font_size", 13)
			vb.add_child(title)

			var body := Label.new()
			body.text = str(doc["content"])
			body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.add_theme_font_size_override("font_size", 12)
			vb.add_child(body)
			content_vbox.add_child(card)
	else:
		for entry in BioDatabase.get_bestiary_entries():
			var bid: String = str(entry["id"])
			var kills: int = int(GameState.bestiary_kills.get(bid, 0))
			var card := PanelContainer.new()
			var vb := VBoxContainer.new()
			vb.add_theme_constant_override("separation", 3)
			card.add_child(vb)

			var title := Label.new()
			title.text = "%s (%s)  •  Ameaça: %s  •  Abates: %d" % [
				str(entry["name"]), str(entry["scientific"]), str(entry["threat"]), kills
			]
			title.modulate = Color(1.0, 0.45, 0.45) if str(entry["threat"]) == "OMEGA" else Color(0.95, 0.85, 0.45)
			title.add_theme_font_size_override("font_size", 13)
			vb.add_child(title)

			var desc := Label.new()
			desc.text = "Fraqueza: %s\n%s" % [str(entry["weakness"]), str(entry["description"])]
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc.add_theme_font_size_override("font_size", 12)
			vb.add_child(desc)
			content_vbox.add_child(card)


# --- TAB 6: SETTINGS & SAVE/LOAD ---

func _build_settings_tab() -> void:
	var audio_btn := Button.new()
	audio_btn.custom_minimum_size = Vector2(0, 42)
	audio_btn.text = "Áudio / SFX: DESLIGADO (Mudo)" if AudioManager.is_muted else "Áudio / SFX: LIGADO"
	audio_btn.pressed.connect(func() -> void:
		AudioManager.toggle_mute()
		_refresh()
	)
	content_vbox.add_child(audio_btn)

	var crt_btn := Button.new()
	crt_btn.custom_minimum_size = Vector2(0, 42)
	crt_btn.text = "Filtro CRT / Vinheta PS1: LIGADO" if GameState.crt_enabled else "Filtro CRT / Vinheta PS1: DESLIGADO"
	crt_btn.pressed.connect(func() -> void:
		var lvl: ChildrenFirstHall = _get_level()
		if lvl != null:
			lvl.set_crt_visible(not GameState.crt_enabled)
		_refresh()
	)
	content_vbox.add_child(crt_btn)

	var save_btn := Button.new()
	save_btn.custom_minimum_size = Vector2(0, 44)
	save_btn.text = "SALVAR PROGRESSO AGORA (Safe Room)" if GameState.in_safe_room else "SALVAR PROGRESSO (Disponível na Safe Room)"
	save_btn.disabled = not GameState.in_safe_room
	save_btn.pressed.connect(func() -> void:
		var lvl: ChildrenFirstHall = _get_level()
		var pos: Vector2 = lvl.player.global_position if lvl != null else Vector2(-1, -1)
		if GameState.save_game(pos):
			feedback_label.text = "Jogo salvo com sucesso!"
			feedback_label.modulate = Color(0.35, 1.0, 0.65)
			_refresh()
	)
	content_vbox.add_child(save_btn)

	var title_btn := Button.new()
	title_btn.custom_minimum_size = Vector2(0, 42)
	title_btn.text = "VOLTAR À TELA DE TÍTULO"
	title_btn.pressed.connect(func() -> void:
		close_menu()
		get_tree().change_scene_to_file("res://src/ui/title_screen.tscn")
	)
	content_vbox.add_child(title_btn)
