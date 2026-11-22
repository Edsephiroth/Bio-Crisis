class_name InventoryMenu
extends Control

## Parasite Eve style tactical menu: Weapons & Tune, Armors & Supplies, Documents, Bestiary.

@onready var tab_weapons_btn: Button = %TabWeapons
@onready var tab_items_btn: Button = %TabItems
@onready var tab_docs_btn: Button = %TabDocs
@onready var tab_bestiary_btn: Button = %TabBestiary
@onready var btn_close: Button = %BtnClose
@onready var status_summary: Label = %StatusSummary
@onready var content_vbox: VBoxContainer = %ContentVBox
@onready var feedback_label: Label = %FeedbackLabel

var current_tab: String = "weapons"
var tune_mode_active: bool = false


func _ready() -> void:
	visible = false
	tab_weapons_btn.pressed.connect(func() -> void: _switch_tab("weapons"))
	tab_items_btn.pressed.connect(func() -> void: _switch_tab("items"))
	tab_docs_btn.pressed.connect(func() -> void: _switch_tab("docs"))
	tab_bestiary_btn.pressed.connect(func() -> void: _switch_tab("bestiary"))
	btn_close.pressed.connect(close_menu)


func open_menu() -> void:
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


func _switch_tab(tab_id: String) -> void:
	current_tab = tab_id
	tune_mode_active = false
	feedback_label.text = ""
	_refresh()


func _refresh() -> void:
	var w: WeaponData = GameState.get_equipped_weapon()
	var a: ArmorData = GameState.get_equipped_armor()
	status_summary.text = "ELISABETH LV.%d  |  HP %d/%d  |  PE %d/%d  |  ATK %d  |  DEF %d  |  Tools: %d  |  BP %d" % [
		GameState.level,
		GameState.hp, GameState.max_hp,
		int(GameState.pe), int(GameState.max_pe),
		GameState.get_total_attack(),
		GameState.get_total_defense(),
		GameState.tools,
		GameState.bp,
	]

	for child in content_vbox.get_children():
		child.queue_free()

	match current_tab:
		"weapons":
			_build_weapons_tab(w)
		"items":
			_build_items_tab(a)
		"docs":
			_build_docs_tab()
		"bestiary":
			_build_bestiary_tab()


func _build_weapons_tab(equipped: WeaponData) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 13)
	if tune_mode_active:
		lbl.text = "MODO TUNE ATIVO: Escolha uma arma DOADORA para sacrificar e melhorar %s (consome 1 Tool)." % equipped.display_name
		lbl.modulate = Color(1.0, 0.85, 0.3)
	else:
		lbl.text = "Equipada: %s (%s) — ATK +%d | Alcance %dpx | Rajada %dx" % [
			equipped.display_name, equipped.caliber, equipped.attack_bonus, int(equipped.range_px), equipped.rate_of_fire
		]
		lbl.modulate = Color(0.5, 0.92, 1.0)
	header.add_child(lbl)

	var btn_tune := Button.new()
	btn_tune.custom_minimum_size = Vector2(160, 36)
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
		info.add_theme_font_size_override("font_size", 13)
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
		action_btn.custom_minimum_size = Vector2(128, 38)
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


func _build_items_tab(equipped_armor: ArmorData) -> void:
	# Consumables row
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

	var sec_lbl := Label.new()
	sec_lbl.text = "ARMADURAS DISPONÍVEIS (Equipada: %s — DEF +%d)" % [equipped_armor.display_name, equipped_armor.defense_bonus]
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
		info.add_theme_font_size_override("font_size", 13)
		info.text = "%s%s  |  DEF +%d  |  PE-DEF +%d  |  HP +%d\n%s" % [
			"[EQUIPADA] " if is_eq else "",
			armor.display_name, armor.defense_bonus, armor.pe_defense_bonus, armor.hp_bonus, armor.description
		]
		if is_eq:
			info.modulate = Color(0.45, 1.0, 0.78)
		hbox.add_child(info)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(110, 38)
		btn.text = "EQUIPADA" if is_eq else "EQUIPAR"
		btn.disabled = is_eq
		var idx: int = i
		btn.pressed.connect(func() -> void:
			GameState.equip_armor(idx)
			_refresh()
		)
		hbox.add_child(btn)
		content_vbox.add_child(row)


func _build_docs_tab() -> void:
	for doc in BioDatabase.get_documents():
		var card := PanelContainer.new()
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 4)
		card.add_child(vb)

		var title := Label.new()
		title.text = "%s  (%s)" % [str(doc["title"]), str(doc["date"])]
		title.modulate = Color(0.45, 0.9, 1.0)
		title.add_theme_font_size_override("font_size", 14)
		vb.add_child(title)

		var body := Label.new()
		body.text = str(doc["content"])
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_size_override("font_size", 12)
		vb.add_child(body)

		content_vbox.add_child(card)


func _build_bestiary_tab() -> void:
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
