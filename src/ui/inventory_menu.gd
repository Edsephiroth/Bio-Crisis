class_name InventoryMenu
extends Control

## Faithful Godot 4 port of the Bio-Crisis OS ModernMenu prototype layout.

const BUST_TEX: Texture2D = preload("res://assets/ui/elisabeth_bust.png")
const ICON_MED: Texture2D = preload("res://assets/icons/Pe1_icon_inv_med.png")
const ICON_CURE: Texture2D = preload("res://assets/icons/Pe1_icon_inv_cure.png")
const ICON_TOOL: Texture2D = preload("res://assets/icons/Pe1_icon_inv_tool.png")
const ICON_AMMO: Texture2D = preload("res://assets/icons/Pe1_icon_inv_ammo.png")
const ICON_CARD: Texture2D = preload("res://assets/icons/Pe1_icon_inv_card.png")

@onready var location_label: Label = %LocationLabel
@onready var play_time_label: Label = %PlayTimeLabel
@onready var l1_badge: Label = %L1Badge
@onready var btn_close: Button = %BtnClose

@onready var tab_inventory_btn: Button = %TabInventory
@onready var tab_map_btn: Button = %TabMap
@onready var tab_pe_btn: Button = %TabPE
@onready var tab_status_btn: Button = %TabStatus
@onready var tab_extras_btn: Button = %TabExtras
@onready var tab_settings_btn: Button = %TabSettings

@onready var left_main_panel: PanelContainer = %LeftMainPanel
@onready var left_container: VBoxContainer = %LeftContainer
@onready var right_agent_panel: PanelContainer = %RightAgentPanel
@onready var agent_stats_card: PanelContainer = %AgentStatsCard
@onready var bp_box: PanelContainer = %BpBox

@onready var bust_rect: TextureRect = %BustRect
@onready var agent_role_label: Label = %AgentRoleLabel
@onready var right_hp_val: Label = %RightHpVal
@onready var right_hp_bar: ProgressBar = %RightHpBar
@onready var right_pe_val: Label = %RightPeVal
@onready var right_pe_bar: ProgressBar = %RightPeBar
@onready var right_exp_val: Label = %RightExpVal
@onready var right_exp_bar: ProgressBar = %RightExpBar
@onready var right_bp_val: Label = %RightBpVal

var current_tab: String = "inventory"
var inv_category: String = "item" # "item", "gun", "armor"
var selected_row_index: int = 0
var extras_sub_tab: String = "docs" # "docs", "bestiary"
var selected_extra_index: int = 0
var tune_mode_active: bool = false
var feedback_msg: String = ""


func _ready() -> void:
	visible = false
	bust_rect.texture = BUST_TEX
	_apply_base_theme_styles()

	tab_inventory_btn.pressed.connect(func() -> void: _switch_tab("inventory"))
	tab_map_btn.pressed.connect(func() -> void: _switch_tab("map"))
	tab_pe_btn.pressed.connect(func() -> void: _switch_tab("pe"))
	tab_status_btn.pressed.connect(func() -> void: _switch_tab("status"))
	tab_extras_btn.pressed.connect(func() -> void: _switch_tab("extras"))
	tab_settings_btn.pressed.connect(func() -> void: _switch_tab("settings"))
	btn_close.pressed.connect(close_menu)


func _make_box(bg: Color, border: Color, border_w: int = 1, radius: int = 6, pad_h: int = 8, pad_v: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


func _style_button(btn: Button, bg: Color, border: Color, text_col: Color = Color.WHITE, border_w: int = 1, radius: int = 4) -> void:
	btn.add_theme_stylebox_override("normal", _make_box(bg, border, border_w, radius, 8, 4))
	btn.add_theme_stylebox_override("hover", _make_box(bg.lightened(0.12), border.lightened(0.15), border_w, radius, 8, 4))
	btn.add_theme_stylebox_override("pressed", _make_box(bg.darkened(0.1), border, border_w, radius, 8, 4))
	btn.add_theme_stylebox_override("disabled", _make_box(Color(0.08, 0.09, 0.12, 0.6), Color(0.2, 0.22, 0.26, 0.5), 1, radius, 8, 4))
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)


func _apply_base_theme_styles() -> void:
	left_main_panel.add_theme_stylebox_override("panel", _make_box(Color(0.02, 0.03, 0.05, 0.78), Color(0.22, 0.26, 0.32, 0.75), 1, 8, 10, 10))
	right_agent_panel.add_theme_stylebox_override("panel", _make_box(Color(0.02, 0.03, 0.05, 0.48), Color(0.22, 0.26, 0.32, 0.75), 1, 8, 12, 10))
	agent_stats_card.add_theme_stylebox_override("panel", _make_box(Color(0.02, 0.03, 0.05, 0.85), Color(0.25, 0.28, 0.35, 0.8), 1, 6, 10, 8))
	bp_box.add_theme_stylebox_override("panel", _make_box(Color(0.06, 0.05, 0.03, 0.85), Color(0.65, 0.5, 0.15, 0.75), 1, 4, 8, 5))
	l1_badge.add_theme_stylebox_override("normal", _make_box(Color(0.08, 0.1, 0.14, 0.9), Color(0.35, 0.4, 0.48, 0.8), 1, 4, 4, 2))
	_style_button(btn_close, Color(0.22, 0.04, 0.06, 0.85), Color(0.85, 0.22, 0.26, 0.9), Color(1.0, 0.6, 0.6), 1, 4)

	# Thin styled bars matching prototype
	right_hp_bar.add_theme_stylebox_override("background", _make_box(Color(0.12, 0.05, 0.07, 0.9), Color(0.25, 0.1, 0.12, 0.6), 1, 2, 0, 0))
	right_hp_bar.add_theme_stylebox_override("fill", _make_box(Color(0.95, 0.12, 0.28, 1.0), Color(1.0, 0.3, 0.45, 1.0), 0, 2, 0, 0))
	right_pe_bar.add_theme_stylebox_override("background", _make_box(Color(0.06, 0.08, 0.14, 0.9), Color(0.18, 0.22, 0.32, 0.6), 1, 2, 0, 0))
	right_pe_bar.add_theme_stylebox_override("fill", _make_box(Color(0.1, 0.85, 0.95, 1.0), Color(0.3, 0.95, 1.0, 1.0), 0, 2, 0, 0))
	right_exp_bar.add_theme_stylebox_override("background", _make_box(Color(0.08, 0.09, 0.12, 0.9), Color(0.22, 0.24, 0.28, 0.6), 1, 2, 0, 0))
	right_exp_bar.add_theme_stylebox_override("fill", _make_box(Color(0.75, 0.8, 0.88, 1.0), Color(0.9, 0.95, 1.0, 1.0), 0, 2, 0, 0))


func open_menu(initial_tab: String = "inventory") -> void:
	current_tab = initial_tab
	visible = true
	tune_mode_active = false
	feedback_msg = ""
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
	feedback_msg = ""
	_refresh()


func _refresh() -> void:
	# Header & Right Agent Card (always live)
	var room_data: Dictionary = RoomDatabase.get_room(GameState.current_room_id)
	location_label.text = str(room_data.get("title", "ONG Children First"))
	play_time_label.text = GameState.get_formatted_play_time()

	agent_role_label.text = "ENGLISH TEACHER  •  LV. %02d" % GameState.level
	right_hp_val.text = "%d / %d" % [GameState.hp, GameState.max_hp]
	right_hp_bar.max_value = GameState.max_hp
	right_hp_bar.value = GameState.hp
	right_pe_val.text = "%d / %d" % [int(GameState.pe), int(GameState.max_pe)]
	right_pe_bar.max_value = GameState.max_pe
	right_pe_bar.value = GameState.pe
	right_exp_val.text = "%d / %d" % [GameState.exp, GameState.exp_to_next]
	right_exp_bar.max_value = maxf(1.0, float(GameState.exp_to_next))
	right_exp_bar.value = GameState.exp
	right_bp_val.text = "%d" % GameState.bp

	# Style top tabs (cyan underline on active tab)
	var tab_map: Dictionary = {
		"inventory": tab_inventory_btn,
		"map": tab_map_btn,
		"pe": tab_pe_btn,
		"status": tab_status_btn,
		"extras": tab_extras_btn,
		"settings": tab_settings_btn,
	}
	for tid in tab_map.keys():
		var btn: Button = tab_map[tid] as Button
		if tid == current_tab:
			var active_sb := _make_box(Color(0.06, 0.16, 0.22, 0.85), Color(0.12, 0.88, 0.96, 1.0), 0, 2, 8, 4)
			active_sb.border_width_bottom = 2
			btn.add_theme_stylebox_override("normal", active_sb)
			btn.add_theme_stylebox_override("hover", active_sb)
			btn.add_theme_color_override("font_color", Color.WHITE)
		else:
			var idle_sb := _make_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 2, 8, 4)
			btn.add_theme_stylebox_override("normal", idle_sb)
			btn.add_theme_stylebox_override("hover", _make_box(Color(0.08, 0.1, 0.14, 0.5), Color(0, 0, 0, 0), 0, 2, 8, 4))
			btn.add_theme_color_override("font_color", Color(0.62, 0.67, 0.74, 1.0))

	# Rebuild Left Main Area
	for child in left_container.get_children():
		child.queue_free()

	if feedback_msg != "":
		var fb := Label.new()
		fb.text = feedback_msg
		fb.modulate = Color(1.0, 0.85, 0.3)
		fb.add_theme_font_size_override("font_size", 11)
		left_container.add_child(fb)

	match current_tab:
		"inventory":
			_build_inventory_tab()
		"map":
			_build_map_tab()
		"pe":
			_build_pe_tab()
		"status":
			_build_status_tune_tab()
		"extras":
			_build_extras_tab()
		"settings":
			_build_settings_tab()


# ==============================================================================
# TAB 1: INVENTORY (Sidebar + Table + Active Equipment / Bio-Energy + Details)
# ==============================================================================

func _build_inventory_tab() -> void:
	var top_hbox := HBoxContainer.new()
	top_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_hbox.add_theme_constant_override("separation", 8)
	left_container.add_child(top_hbox)

	# 1. Left vertical category sidebar (ITEM / PE / GUN / ARMOR / BP)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size = Vector2(58, 0)
	sidebar.add_theme_constant_override("separation", 6)
	top_hbox.add_child(sidebar)

	for pair in [["item", "ITEM"], ["pe", "BIO-\nENERGY"], ["gun", "GUN"], ["armor", "ARMOR"], ["bp", "BP"]]:
		var cid: String = str(pair[0])
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(56, 46)
		btn.add_theme_font_size_override("font_size", 10)
		btn.text = str(pair[1])
		var is_sel: bool = (cid == inv_category)
		if is_sel:
			_style_button(btn, Color(0.06, 0.32, 0.42, 0.95), Color(0.15, 0.9, 1.0, 1.0), Color.WHITE, 2, 5)
		else:
			_style_button(btn, Color(0.05, 0.06, 0.09, 0.85), Color(0.24, 0.27, 0.34, 0.8), Color(0.72, 0.76, 0.82), 1, 5)
		btn.pressed.connect(func() -> void:
			inv_category = cid
			selected_row_index = 0
			tune_mode_active = false
			_refresh()
		)
		sidebar.add_child(btn)

	# 2. Center table panel (NAME | TYPE | QTY | BP)
	var table_panel := PanelContainer.new()
	table_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table_panel.size_flags_stretch_ratio = 1.65
	table_panel.add_theme_stylebox_override("panel", _make_box(Color(0.03, 0.04, 0.06, 0.85), Color(0.2, 0.24, 0.3, 0.8), 1, 6, 8, 6))
	top_hbox.add_child(table_panel)

	var table_vbox := VBoxContainer.new()
	table_vbox.add_theme_constant_override("separation", 4)
	table_panel.add_child(table_vbox)

	# Table header
	var hdr := HBoxContainer.new()
	for hpair in [["NAME", 3.0], ["TYPE", 1.3], ["QTY", 0.7], ["BP", 0.7]]:
		var hl := Label.new()
		hl.text = str(hpair[0])
		hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hl.size_flags_stretch_ratio = float(hpair[1])
		hl.modulate = Color(0.55, 0.6, 0.68)
		hl.add_theme_font_size_override("font_size", 10)
		hdr.add_child(hl)
	table_vbox.add_child(hdr)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_vbox.add_child(scroll)

	var rows_vbox := VBoxContainer.new()
	rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(rows_vbox)

	var items_list: Array[Dictionary] = _get_inventory_rows()
	selected_row_index = clampi(selected_row_index, 0, maxi(0, items_list.size() - 1))

	for i in range(items_list.size()):
		var it: Dictionary = items_list[i]
		var is_sel: bool = (i == selected_row_index)
		var row_btn := Button.new()
		row_btn.custom_minimum_size = Vector2(0, 34)
		row_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row_btn.add_theme_font_size_override("font_size", 11)
		var eq_tag: String = "[E] " if bool(it.get("equipped", false)) else ""
		row_btn.text = "%s%s   •   %s   •   %03d   •   %d BP" % [
			eq_tag, str(it["name"]), str(it["type"]), int(it["qty"]), int(it["bp"])
		]
		if ResourceLoader.exists(str(it.get("icon", ""))):
			row_btn.icon = load(str(it["icon"])) as Texture2D
			row_btn.expand_icon = true
		if is_sel:
			_style_button(row_btn, Color(0.06, 0.24, 0.32, 0.92), Color(0.15, 0.88, 0.98, 1.0), Color(0.85, 0.98, 1.0), 1, 4)
		else:
			_style_button(row_btn, Color(0.05, 0.06, 0.08, 0.7), Color(0.16, 0.18, 0.22, 0.5), Color(0.82, 0.85, 0.9), 1, 4)
		var idx: int = i
		row_btn.pressed.connect(func() -> void:
			selected_row_index = idx
			_refresh()
		)
		rows_vbox.add_child(row_btn)

	# 3. Auxiliary right column inside Inventory (ACTIVE EQUIPMENT + BIO-ENERGY STATUS)
	var aux_vbox := VBoxContainer.new()
	aux_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aux_vbox.size_flags_stretch_ratio = 0.85
	aux_vbox.add_theme_constant_override("separation", 6)
	top_hbox.add_child(aux_vbox)

	# Active Equipment Card
	var eq_panel := PanelContainer.new()
	eq_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	eq_panel.add_theme_stylebox_override("panel", _make_box(Color(0.03, 0.04, 0.06, 0.85), Color(0.2, 0.24, 0.3, 0.8), 1, 6, 8, 6))
	aux_vbox.add_child(eq_panel)

	var eq_vb := VBoxContainer.new()
	eq_vb.add_theme_constant_override("separation", 6)
	eq_panel.add_child(eq_vb)

	var eq_title := Label.new()
	eq_title.text = "ACTIVE EQUIPMENT"
	eq_title.add_theme_font_size_override("font_size", 10)
	eq_title.modulate = Color(0.85, 0.9, 0.95)
	eq_vb.add_child(eq_title)

	var w: WeaponData = GameState.get_equipped_weapon()
	var a: ArmorData = GameState.get_equipped_armor()
	eq_vb.add_child(_make_equip_mini_card(w.icon_path, w.display_name, "%s (%d)" % [w.caliber, GameState.get_current_ammo()], Color(0.98, 0.78, 0.22)))
	eq_vb.add_child(_make_equip_mini_card(a.icon_path, a.display_name, "Biophysical Def +%d" % a.defense_bonus, Color(0.25, 0.92, 0.6)))

	# Bio-Energy Status 2x2 Card
	var bio_panel := PanelContainer.new()
	bio_panel.add_theme_stylebox_override("panel", _make_box(Color(0.04, 0.03, 0.07, 0.85), Color(0.32, 0.2, 0.45, 0.8), 1, 6, 8, 6))
	aux_vbox.add_child(bio_panel)

	var bio_vb := VBoxContainer.new()
	bio_vb.add_theme_constant_override("separation", 4)
	bio_panel.add_child(bio_vb)

	var bio_title := Label.new()
	bio_title.text = "BIO-ENERGY STATUS"
	bio_title.add_theme_font_size_override("font_size", 10)
	bio_title.modulate = Color(0.82, 0.55, 1.0)
	bio_vb.add_child(bio_title)

	var bio_grid := GridContainer.new()
	bio_grid.columns = 2
	bio_grid.add_theme_constant_override("h_separation", 4)
	bio_grid.add_theme_constant_override("v_separation", 4)
	for elem in [
		["FIRE  LV.%d" % GameState.level, Color(0.95, 0.3, 0.35), Color(0.22, 0.05, 0.07, 0.85)],
		["WIND  LV.%d" % GameState.level, Color(0.25, 0.92, 0.65), Color(0.05, 0.18, 0.14, 0.85)],
		["WATER LV.%d" % GameState.level, Color(0.35, 0.72, 1.0), Color(0.05, 0.12, 0.24, 0.85)],
		["EARTH LV.%d" % GameState.level, Color(0.95, 0.65, 0.22), Color(0.2, 0.12, 0.04, 0.85)],
	]:
		var ep := PanelContainer.new()
		ep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ep.add_theme_stylebox_override("panel", _make_box(elem[2] as Color, elem[1] as Color, 1, 3, 4, 2))
		var el := Label.new()
		el.text = str(elem[0])
		el.modulate = elem[1] as Color
		el.add_theme_font_size_override("font_size", 9)
		ep.add_child(el)
		bio_grid.add_child(ep)
	bio_vb.add_child(bio_grid)

	# 4. Bottom Selected Item Detail Bar (Icon + Description + USE/TUNE/EXAMINE buttons)
	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(0, 86)
	detail_panel.add_theme_stylebox_override("panel", _make_box(Color(0.03, 0.04, 0.06, 0.9), Color(0.22, 0.26, 0.32, 0.85), 1, 6, 8, 6))
	left_container.add_child(detail_panel)

	var det_hb := HBoxContainer.new()
	det_hb.add_theme_constant_override("separation", 10)
	detail_panel.add_child(det_hb)

	if not items_list.is_empty():
		var cur: Dictionary = items_list[selected_row_index]
		var icon_box := PanelContainer.new()
		icon_box.custom_minimum_size = Vector2(68, 68)
		icon_box.add_theme_stylebox_override("panel", _make_box(Color(0.06, 0.09, 0.13, 0.9), Color(0.25, 0.35, 0.45, 0.8), 1, 4, 6, 6))
		if ResourceLoader.exists(str(cur.get("icon", ""))):
			var tr := TextureRect.new()
			tr.texture = load(str(cur["icon"])) as Texture2D
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_box.add_child(tr)
		det_hb.add_child(icon_box)

		var desc_vb := VBoxContainer.new()
		desc_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_vb.add_theme_constant_override("separation", 4)
		var d_lbl := Label.new()
		d_lbl.text = "\"%s\"" % str(cur.get("desc", ""))
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d_lbl.add_theme_font_size_override("font_size", 11)
		desc_vb.add_child(d_lbl)

		var stat_lbl := Label.new()
		stat_lbl.text = str(cur.get("stats", ""))
		stat_lbl.modulate = Color(0.35, 0.95, 0.72)
		stat_lbl.add_theme_font_size_override("font_size", 10)
		desc_vb.add_child(stat_lbl)
		det_hb.add_child(desc_vb)

		var act_grid := GridContainer.new()
		act_grid.columns = 2
		act_grid.add_theme_constant_override("h_separation", 6)
		act_grid.add_theme_constant_override("v_separation", 6)
		det_hb.add_child(act_grid)

		var btn_primary := Button.new()
		btn_primary.custom_minimum_size = Vector2(92, 30)
		btn_primary.add_theme_font_size_override("font_size", 11)
		btn_primary.text = "EQUIP" if inv_category in ["gun", "armor"] else "USE"
		if bool(cur.get("equipped", false)):
			btn_primary.text = "EQUIPPED"
			btn_primary.disabled = true
		_style_button(btn_primary, Color(0.06, 0.55, 0.72, 0.95), Color(0.2, 0.92, 1.0, 1.0), Color.WHITE, 1, 4)
		btn_primary.pressed.connect(func() -> void: _execute_inventory_primary(cur))
		act_grid.add_child(btn_primary)

		var btn_sec := Button.new()
		btn_sec.custom_minimum_size = Vector2(92, 30)
		btn_sec.add_theme_font_size_override("font_size", 11)
		if inv_category == "gun":
			btn_sec.text = "TUNE (1 Tool)"
			btn_sec.disabled = GameState.tools <= 0 or bool(cur.get("equipped", false))
			_style_button(btn_sec, Color(0.35, 0.25, 0.06, 0.9), Color(0.95, 0.75, 0.2, 0.9), Color(1.0, 0.9, 0.5), 1, 4)
			btn_sec.pressed.connect(func() -> void:
				var donor_idx: int = int(cur.get("index", -1))
				if donor_idx >= 0:
					feedback_msg = GameState.tune_weapon(GameState.equipped_weapon_index, donor_idx)
					selected_row_index = GameState.equipped_weapon_index
					_refresh()
			)
		else:
			btn_sec.text = "EXAMINE"
			_style_button(btn_sec, Color(0.12, 0.14, 0.18, 0.9), Color(0.32, 0.36, 0.44, 0.9), Color.WHITE, 1, 4)
			btn_sec.pressed.connect(func() -> void:
				feedback_msg = "%s: %s" % [str(cur["name"]), str(cur.get("desc", ""))]
				_refresh()
			)
		act_grid.add_child(btn_sec)


func _make_equip_mini_card(icon_path: String, title: String, subtitle: String, sub_col: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _make_box(Color(0.05, 0.06, 0.09, 0.9), Color(0.22, 0.26, 0.32, 0.7), 1, 4, 6, 4))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	pc.add_child(hb)
	if ResourceLoader.exists(icon_path):
		var tr := TextureRect.new()
		tr.texture = load(icon_path) as Texture2D
		tr.custom_minimum_size = Vector2(28, 28)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hb.add_child(tr)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_size_override("font_size", 11)
	vb.add_child(tl)
	var sl := Label.new()
	sl.text = subtitle
	sl.modulate = sub_col
	sl.add_theme_font_size_override("font_size", 9)
	vb.add_child(sl)
	hb.add_child(vb)
	return pc


func _get_inventory_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if inv_category == "gun":
		for i in range(GameState.weapons.size()):
			var w: WeaponData = GameState.weapons[i]
			rows.append({
				"kind": "gun",
				"index": i,
				"name": w.display_name,
				"type": "WEAPON",
				"qty": 1,
				"bp": w.attack_bonus * 15,
				"equipped": i == GameState.equipped_weapon_index,
				"icon": w.icon_path,
				"desc": w.description,
				"stats": "Caliber: %s | Cap: %d | Range: %dpx | Rate: %dx | ATK: +%d" % [w.caliber, w.capacity, int(w.range_px), w.rate_of_fire, w.attack_bonus],
			})
	elif inv_category == "armor":
		for i in range(GameState.armors.size()):
			var a: ArmorData = GameState.armors[i]
			rows.append({
				"kind": "armor",
				"index": i,
				"name": a.display_name,
				"type": "ARMOR",
				"qty": 1,
				"bp": a.defense_bonus * 20,
				"equipped": i == GameState.equipped_armor_index,
				"icon": a.icon_path,
				"desc": a.description,
				"stats": "DEF: +%d | PE-DEF: +%d | Bonus HP: +%d" % [a.defense_bonus, a.pe_defense_bonus, a.hp_bonus],
			})
	elif inv_category == "pe":
		var quick_skills: Array = [
			["heal", "HEAL 1", 30, "Restaura HP com soro celular."],
			["haste", "HASTE", 25, "Acelera movimento e barra ATB."],
			["barrier", "BARRIER", 35, "Campo defensivo (-35% dano por 20s)."],
			["slow", "SLOW", 30, "Reduz velocidade dos inimigos em 50%."],
			["scan", "SCAN", 15, "Escaneia HP e ataque do alvo mais próximo."],
			["energy_shot", "ENERGY SHOT", 30, "Disparo perfurante em linha reta."],
			["liberate", "LIBERATE", 80, "Descarga de área contra todos ao redor."],
		]
		for sk in quick_skills:
			rows.append({
				"kind": "pe_skill",
				"skill_id": str(sk[0]),
				"name": str(sk[1]),
				"type": "TECH",
				"qty": int(sk[2]),
				"bp": 0,
				"icon": "res://assets/icons/Pe1_icon_inv_cure.png",
				"desc": str(sk[3]),
				"stats": "Custo: %d PE  |  Disponível: %d PE" % [int(sk[2]), int(GameState.pe)],
			})
	elif inv_category == "bp":
		for upg in [
			["hp", "+15 MAX HP", 10, "Aumenta permanentemente o HP máximo de Elisabeth."],
			["pe", "+10 MAX PE", 10, "Aumenta a capacidade máxima da bateria tática."],
			["atk", "+3 ATAQUE", 15, "Aumenta o poder ofensivo base."],
			["atb", "+0.2 VELOCIDADE TA", 15, "Acelera o preenchimento da barra ATB."],
		]:
			rows.append({
				"kind": "bp_upgrade",
				"stat_id": str(upg[0]),
				"name": str(upg[1]),
				"type": "UPGRADE",
				"qty": 1,
				"bp": int(upg[2]),
				"icon": "res://assets/icons/Pe1_icon_inv_boost1.png",
				"desc": str(upg[3]),
				"stats": "Custo: %d BP  |  Seu BP: %d" % [int(upg[2]), GameState.bp],
			})
	else:
		rows.append({
			"kind": "medkit", "name": "Medicine 1 (Medkit)", "type": "MEDICINE", "qty": GameState.medkits, "bp": 50,
			"icon": "res://assets/icons/Pe1_icon_inv_med.png",
			"desc": "Soro celular médico de emergência. Restaura 160 HP.", "stats": "Heal HP: +160 HP",
		})
		rows.append({
			"kind": "pe_light", "name": "PE Light", "type": "MEDICINE", "qty": GameState.pe_lights, "bp": 75,
			"icon": "res://assets/icons/Pe1_icon_inv_cure.png",
			"desc": "Catalisador bioelétrico. Restaura 55 de Energia PE.", "stats": "Restore PE: +55 PE",
		})
		rows.append({
			"kind": "tool", "name": "Weapon Tool", "type": "TOOL", "qty": GameState.tools, "bp": 200,
			"icon": "res://assets/icons/Pe1_icon_inv_tool.png",
			"desc": "Ferramenta tática usada na aba GUN para transferir bônus via TUNE.", "stats": "Used for Weapon Tune",
		})
		for cal in ["9mm", "12G", "5.56mm"]:
			rows.append({
				"kind": "ammo", "name": "Ammo %s" % cal, "type": "AMMO", "qty": int(GameState.ammo_by_caliber.get(cal, 0)), "bp": 20,
				"icon": "res://assets/icons/Pe1_icon_inv_ammo.png",
				"desc": "Munição tática calibre %s." % cal, "stats": "Caliber: %s" % cal,
			})
		if GameState.has_keycard:
			rows.append({
				"kind": "keycard", "name": "Keycard de Evacuação", "type": "SPECIAL", "qty": 1, "bp": 0,
				"icon": "res://assets/icons/Pe1_icon_inv_card.png",
				"desc": "Cartão magnético de segurança que destranca a porta norte para o Hall Principal.", "stats": "Key Item — Children First NGO",
			})
	return rows


func _execute_inventory_primary(item: Dictionary) -> void:
	var kind: String = str(item.get("kind", ""))
	if kind == "gun":
		GameState.equip_weapon(int(item["index"]))
	elif kind == "armor":
		GameState.equip_armor(int(item["index"]))
	elif kind == "medkit":
		if GameState.use_medkit():
			feedback_msg = "Medkit utilizado (+160 HP)!"
		else:
			feedback_msg = "Sem Medkits ou HP já está cheio."
	elif kind == "pe_light":
		if GameState.use_pe_light():
			feedback_msg = "PE Light utilizado (+55 PE)!"
		else:
			feedback_msg = "Sem PE Light ou PE já está cheio."
	elif kind == "pe_skill":
		_cast_pe_from_menu(str(item.get("skill_id", "")))
		return
	elif kind == "bp_upgrade":
		feedback_msg = GameState.spend_bp_upgrade(str(item.get("stat_id", "")))
	else:
		feedback_msg = str(item.get("desc", ""))
	_refresh()


# ==============================================================================
# TAB 2: TACTICAL NAVIGATION MAP (Live blueprint + Legend)
# ==============================================================================

func _build_map_tab() -> void:
	var lvl: ChildrenFirstHall = _get_level()
	var room_data: Dictionary = RoomDatabase.get_room(GameState.current_room_id)
	var pos_str: String = "[0, 0]"
	if lvl != null and lvl.player != null:
		var t: Vector2 = lvl.player.global_position / float(ChildrenFirstHall.TILE_SIZE)
		pos_str = "[%d, %d]" % [int(t.x), int(t.y)]

	var hdr := HBoxContainer.new()
	var tl := Label.new()
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.text = "TACTICAL NAVIGATION MAP - %s" % str(room_data.get("title", "")).to_upper()
	tl.modulate = Color(0.15, 0.88, 0.98)
	tl.add_theme_font_size_override("font_size", 11)
	hdr.add_child(tl)

	var pl := Label.new()
	pl.text = "POS: %s" % pos_str
	pl.modulate = Color(0.65, 0.72, 0.8)
	pl.add_theme_font_size_override("font_size", 11)
	hdr.add_child(pl)
	left_container.add_child(hdr)

	var map_view := TacticalMapView.new()
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.set_level(lvl)
	left_container.add_child(map_view)

	var legend := PanelContainer.new()
	legend.add_theme_stylebox_override("panel", _make_box(Color(0.03, 0.04, 0.06, 0.9), Color(0.2, 0.24, 0.3, 0.7), 1, 4, 10, 5))
	var ll := Label.new()
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ll.add_theme_font_size_override("font_size", 10)
	ll.text = "● ELISABETH (Ciano)     ■ SAFE ROOM (Verde)     ■ SUPPLIES (Dourado)     ■ DOORS (Azul/Vermelho)"
	ll.modulate = Color(0.78, 0.86, 0.92)
	legend.add_child(ll)
	left_container.add_child(legend)


# ==============================================================================
# TAB 3: BIO-ENERGY ABILITIES (2-column Purple Cards)
# ==============================================================================

func _build_pe_tab() -> void:
	var hdr := HBoxContainer.new()
	var tl := Label.new()
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.text = "⚡ BIO-ENERGY ABILITIES"
	tl.modulate = Color(0.8, 0.52, 1.0)
	tl.add_theme_font_size_override("font_size", 12)
	hdr.add_child(tl)

	var al := Label.new()
	al.text = "AGENT LEVEL: %d" % GameState.level
	al.modulate = Color(0.7, 0.75, 0.82)
	al.add_theme_font_size_override("font_size", 11)
	hdr.add_child(al)
	left_container.add_child(hdr)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_container.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	var skills: Array = [
		["heal", "HEAL 1", 30, 1, "Restores HP using cellular regeneration."],
		["energy_shot", "ENERGY SHOT", 30, 1, "Fires a photonic beam penetrating targets."],
		["haste", "HASTE", 25, 1, "Doubles ATB gauge speed and movement."],
		["scan", "SCAN", 15, 1, "Scans nearest monster HP and attack power."],
		["slow", "SLOW", 30, 1, "Reduces enemy movement speed by 50%."],
		["barrier", "BARRIER", 35, 1, "Genetic forcefield absorbing 35% physical damage."],
		["liberate", "LIBERATE", 80, 1, "Mitochondrial overload hitting all nearby foes!"],
	]

	for sk in skills:
		var sid: String = str(sk[0])
		var sname: String = str(sk[1])
		var cost: int = int(sk[2])
		var req_lvl: int = int(sk[3])
		var desc: String = str(sk[4])
		var unlocked: bool = GameState.level >= req_lvl

		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bg_col: Color = Color(0.11, 0.04, 0.18, 0.88) if unlocked else Color(0.05, 0.05, 0.08, 0.75)
		var bd_col: Color = Color(0.65, 0.25, 0.95, 0.9) if unlocked else Color(0.22, 0.24, 0.28, 0.7)
		card.add_theme_stylebox_override("panel", _make_box(bg_col, bd_col, 1, 6, 10, 8))

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 4)
		card.add_child(vb)

		var row1 := HBoxContainer.new()
		var nl := Label.new()
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.text = sname
		nl.add_theme_font_size_override("font_size", 12)
		row1.add_child(nl)

		var cl := Label.new()
		cl.text = "%d PE  [LVL %d]" % [cost, req_lvl]
		cl.modulate = Color(0.2, 0.9, 1.0)
		cl.add_theme_font_size_override("font_size", 10)
		row1.add_child(cl)
		vb.add_child(row1)

		var dl := Label.new()
		dl.text = desc
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.modulate = Color(0.75, 0.78, 0.84)
		dl.add_theme_font_size_override("font_size", 10)
		vb.add_child(dl)

		var row2 := HBoxContainer.new()
		var ul := Label.new()
		ul.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ul.text = "✓ UNLOCKED" if unlocked else "🔒 REQUIRES LVL %d" % req_lvl
		ul.modulate = Color(0.25, 0.95, 0.65) if unlocked else Color(0.95, 0.72, 0.22)
		ul.add_theme_font_size_override("font_size", 10)
		row2.add_child(ul)

		if unlocked:
			var cast_btn := Button.new()
			cast_btn.custom_minimum_size = Vector2(70, 24)
			cast_btn.add_theme_font_size_override("font_size", 10)
			cast_btn.text = "CAST"
			cast_btn.disabled = GameState.pe < float(cost)
			_style_button(cast_btn, Color(0.32, 0.12, 0.52, 0.95), Color(0.78, 0.42, 1.0, 1.0), Color.WHITE, 1, 4)
			cast_btn.pressed.connect(func() -> void: _cast_pe_from_menu(sid))
			row2.add_child(cast_btn)

		vb.add_child(row2)
		grid.add_child(card)


func _cast_pe_from_menu(skill_id: String) -> void:
	var lvl: ChildrenFirstHall = _get_level()
	if lvl == null:
		return
	close_menu()
	match skill_id:
		"heal": lvl.cast_heal()
		"haste": lvl.cast_haste()
		"barrier": lvl.cast_barrier()
		"slow": lvl.cast_slow()
		"scan": lvl.cast_scan()
		"energy_shot": GameState.set_tactical_pause(true, "energy_shot")
		"liberate": lvl.cast_liberate()


# ==============================================================================
# TAB 4: STATUS / BP TUNE & BIOLOGICAL EVOLUTION SYSTEM
# ==============================================================================

func _build_status_tune_tab() -> void:
	var tl := Label.new()
	tl.text = "AGENT STATUS & BP TUNE SYSTEM"
	tl.modulate = Color(0.15, 0.88, 0.98)
	tl.add_theme_font_size_override("font_size", 12)
	left_container.add_child(tl)

	# Top stats summary box
	var top_card := PanelContainer.new()
	top_card.add_theme_stylebox_override("panel", _make_box(Color(0.03, 0.04, 0.06, 0.85), Color(0.22, 0.26, 0.32, 0.8), 1, 6, 10, 8))
	left_container.add_child(top_card)

	var top_hb := HBoxContainer.new()
	top_hb.add_theme_constant_override("separation", 12)
	top_card.add_child(top_hb)

	var id_lbl := Label.new()
	id_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_lbl.add_theme_font_size_override("font_size", 11)
	id_lbl.text = "ELISABETH SHELLEY\nENGLISH TEACHER\nLevel: %d\nEXP: %d / %d\nDEF Total: %d" % [
		GameState.level, GameState.exp, GameState.exp_to_next, GameState.get_total_defense()
	]
	top_hb.add_child(id_lbl)

	var stat_grid := GridContainer.new()
	stat_grid.columns = 2
	stat_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_grid.size_flags_stretch_ratio = 1.8
	stat_grid.add_theme_constant_override("h_separation", 8)
	stat_grid.add_theme_constant_override("v_separation", 6)
	top_hb.add_child(stat_grid)

	for sc in [
		["HP (HEALTH POINTS)", "%d / %d" % [GameState.hp, GameState.max_hp], Color(0.25, 0.95, 0.6)],
		["PE (BIO-ENERGY)", "%d / %d" % [int(GameState.pe), int(GameState.max_pe)], Color(0.78, 0.48, 1.0)],
		["ATTACK POWER", "%d ATK" % GameState.get_total_attack(), Color(0.98, 0.35, 0.42)],
		["ATB GAUGE SPEED", "%.1fx" % (GameState.atb_rate / 13.6), Color(0.98, 0.8, 0.22)],
	]:
		var box := PanelContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_stylebox_override("panel", _make_box(Color(0.05, 0.06, 0.09, 0.9), Color(0.2, 0.22, 0.28, 0.8), 1, 4, 8, 5))
		var vb := VBoxContainer.new()
		var l1 := Label.new()
		l1.text = str(sc[0])
		l1.modulate = Color(0.6, 0.65, 0.72)
		l1.add_theme_font_size_override("font_size", 9)
		var l2 := Label.new()
		l2.text = str(sc[1])
		l2.modulate = sc[2] as Color
		l2.add_theme_font_size_override("font_size", 13)
		vb.add_child(l1)
		vb.add_child(l2)
		box.add_child(vb)
		stat_grid.add_child(box)

	# Purple-bordered BP TUNE & BIOLOGICAL EVOLUTION SYSTEM
	var bp_panel := PanelContainer.new()
	bp_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bp_panel.add_theme_stylebox_override("panel", _make_box(Color(0.08, 0.03, 0.14, 0.85), Color(0.62, 0.24, 0.92, 0.9), 1, 6, 10, 8))
	left_container.add_child(bp_panel)

	var bp_vb := VBoxContainer.new()
	bp_vb.add_theme_constant_override("separation", 8)
	bp_panel.add_child(bp_vb)

	var bp_hdr := HBoxContainer.new()
	var btitle := Label.new()
	btitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btitle.text = "BP TUNE & BIOLOGICAL EVOLUTION SYSTEM"
	btitle.modulate = Color(0.85, 0.6, 1.0)
	btitle.add_theme_font_size_override("font_size", 11)
	bp_hdr.add_child(btitle)

	var bval := Label.new()
	bval.text = "BP: %d" % GameState.bp
	bval.modulate = Color(0.98, 0.8, 0.22)
	bval.add_theme_font_size_override("font_size", 12)
	bp_hdr.add_child(bval)
	bp_vb.add_child(bp_hdr)

	var upg_grid := GridContainer.new()
	upg_grid.columns = 2
	upg_grid.add_theme_constant_override("h_separation", 8)
	upg_grid.add_theme_constant_override("v_separation", 8)
	bp_vb.add_child(upg_grid)

	for upg in [
		["hp", "+15 MAX HP", "Increases Max HP", 10, Color(0.25, 0.95, 0.6)],
		["pe", "+10 MAX PE", "Increases Max PE", 10, Color(0.78, 0.48, 1.0)],
		["atk", "+3 ATAQUE", "Increases Base Attack", 15, Color(0.98, 0.35, 0.42)],
		["atb", "+0.2 VELOCIDADE TA", "Increases ATB Speed", 15, Color(0.98, 0.8, 0.22)],
	]:
		var uid: String = str(upg[0])
		var cost: int = int(upg[3])
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _make_box(Color(0.05, 0.06, 0.09, 0.9), Color(0.26, 0.28, 0.35, 0.8), 1, 5, 8, 6))
		var chb := HBoxContainer.new()
		card.add_child(chb)

		var cvb := VBoxContainer.new()
		cvb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ul1 := Label.new()
		ul1.text = str(upg[1])
		ul1.modulate = upg[4] as Color
		ul1.add_theme_font_size_override("font_size", 11)
		var ul2 := Label.new()
		ul2.text = str(upg[2])
		ul2.modulate = Color(0.62, 0.66, 0.72)
		ul2.add_theme_font_size_override("font_size", 9)
		cvb.add_child(ul1)
		cvb.add_child(ul2)
		chb.add_child(cvb)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(68, 30)
		btn.add_theme_font_size_override("font_size", 10)
		btn.text = "%d BP" % cost
		btn.disabled = GameState.bp < cost
		_style_button(btn, Color(0.16, 0.18, 0.24, 0.95), Color(0.45, 0.48, 0.58, 0.9), Color.WHITE, 1, 4)
		btn.pressed.connect(func() -> void:
			feedback_msg = GameState.spend_bp_upgrade(uid)
			_refresh()
		)
		chb.add_child(btn)
		upg_grid.add_child(card)


# ==============================================================================
# TAB 5: EXTRAS & FILES (2-column Documents / Bestiary)
# ==============================================================================

func _build_extras_tab() -> void:
	var hdr := HBoxContainer.new()
	var tl := Label.new()
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.text = "EXTRAS & FILES"
	tl.modulate = Color(0.98, 0.78, 0.22)
	tl.add_theme_font_size_override("font_size", 12)
	hdr.add_child(tl)

	var btn_docs := Button.new()
	btn_docs.custom_minimum_size = Vector2(110, 28)
	btn_docs.add_theme_font_size_override("font_size", 10)
	btn_docs.text = "DOCUMENTS"
	if extras_sub_tab == "docs":
		_style_button(btn_docs, Color(0.88, 0.48, 0.08, 0.95), Color(1.0, 0.72, 0.25, 1.0), Color.WHITE, 1, 4)
	else:
		_style_button(btn_docs, Color(0.08, 0.1, 0.14, 0.85), Color(0.25, 0.28, 0.34, 0.8), Color(0.75, 0.8, 0.86), 1, 4)
	btn_docs.pressed.connect(func() -> void:
		extras_sub_tab = "docs"
		selected_extra_index = 0
		_refresh()
	)
	hdr.add_child(btn_docs)

	var btn_best := Button.new()
	btn_best.custom_minimum_size = Vector2(110, 28)
	btn_best.add_theme_font_size_override("font_size", 10)
	btn_best.text = "BESTIARY"
	if extras_sub_tab == "bestiary":
		_style_button(btn_best, Color(0.88, 0.48, 0.08, 0.95), Color(1.0, 0.72, 0.25, 1.0), Color.WHITE, 1, 4)
	else:
		_style_button(btn_best, Color(0.08, 0.1, 0.14, 0.85), Color(0.25, 0.28, 0.34, 0.8), Color(0.75, 0.8, 0.86), 1, 4)
	btn_best.pressed.connect(func() -> void:
		extras_sub_tab = "bestiary"
		selected_extra_index = 0
		_refresh()
	)
	hdr.add_child(btn_best)
	left_container.add_child(hdr)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 10)
	left_container.add_child(split)

	var list_vb := VBoxContainer.new()
	list_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vb.size_flags_stretch_ratio = 0.85
	list_vb.add_theme_constant_override("separation", 6)
	split.add_child(list_vb)

	var reader_panel := PanelContainer.new()
	reader_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reader_panel.size_flags_stretch_ratio = 1.6
	reader_panel.add_theme_stylebox_override("panel", _make_box(Color(0.02, 0.03, 0.05, 0.9), Color(0.22, 0.26, 0.32, 0.8), 1, 6, 12, 10))
	split.add_child(reader_panel)

	var reader_vb := VBoxContainer.new()
	reader_vb.add_theme_constant_override("separation", 8)
	reader_panel.add_child(reader_vb)

	var entries: Array[Dictionary] = BioDatabase.get_documents() if extras_sub_tab == "docs" else BioDatabase.get_bestiary_entries()
	selected_extra_index = clampi(selected_extra_index, 0, maxi(0, entries.size() - 1))

	for i in range(entries.size()):
		var ent: Dictionary = entries[i]
		var is_sel: bool = (i == selected_extra_index)
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 42)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 10)
		b.text = str(ent.get("title", ent.get("name", "")))
		if is_sel:
			_style_button(b, Color(0.28, 0.16, 0.04, 0.92), Color(0.98, 0.65, 0.12, 1.0), Color(1.0, 0.92, 0.72), 1, 4)
		else:
			_style_button(b, Color(0.05, 0.06, 0.09, 0.8), Color(0.2, 0.23, 0.28, 0.7), Color(0.75, 0.78, 0.84), 1, 4)
		var idx: int = i
		b.pressed.connect(func() -> void:
			selected_extra_index = idx
			_refresh()
		)
		list_vb.add_child(b)

	if not entries.is_empty():
		var cur: Dictionary = entries[selected_extra_index]
		var rt := Label.new()
		rt.modulate = Color(0.98, 0.78, 0.22)
		rt.add_theme_font_size_override("font_size", 12)
		rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var rb := Label.new()
		rb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rb.add_theme_font_size_override("font_size", 12)
		if extras_sub_tab == "docs":
			rt.text = "%s  (%s)" % [str(cur["title"]).to_upper(), str(cur["date"])]
			rb.text = str(cur["content"])
		else:
			var kills: int = int(GameState.bestiary_kills.get(str(cur["id"]), 0))
			rt.text = "%s  (%s)" % [str(cur["name"]), str(cur["scientific"])]
			rb.text = "Nível de Ameaça: %s\nFraqueza: %s\nAbates Registrados: %d\n\n%s" % [
				str(cur["threat"]), str(cur["weakness"]), kills, str(cur["description"])
			]
		reader_vb.add_child(rt)
		reader_vb.add_child(rb)


# ==============================================================================
# TAB 6: OPTIONS (Settings & System matching screenshot 7)
# ==============================================================================

func _build_settings_tab() -> void:
	var tl := Label.new()
	tl.text = "SETTINGS & SYSTEM"
	tl.add_theme_font_size_override("font_size", 12)
	left_container.add_child(tl)

	var opt_vb := VBoxContainer.new()
	opt_vb.custom_minimum_size = Vector2(360, 0)
	opt_vb.add_theme_constant_override("separation", 10)
	left_container.add_child(opt_vb)

	# Audio row
	opt_vb.add_child(_make_toggle_row(
		"Audio / SFX & Ambient",
		"OFF" if AudioManager.is_muted else "ON",
		not AudioManager.is_muted,
		func() -> void:
			AudioManager.toggle_mute()
			_refresh()
	))

	# CRT Filter row
	opt_vb.add_child(_make_toggle_row(
		"Retro CRT Filter / Scanlines",
		"ON" if GameState.crt_enabled else "OFF",
		GameState.crt_enabled,
		func() -> void:
			var lvl: ChildrenFirstHall = _get_level()
			if lvl != null:
				lvl.set_crt_visible(not GameState.crt_enabled)
			_refresh()
	))

	# Green SAVE TO MEMORY CARD button
	var save_btn := Button.new()
	save_btn.custom_minimum_size = Vector2(0, 42)
	save_btn.add_theme_font_size_override("font_size", 12)
	save_btn.text = "✓  SAVE TO MEMORY CARD" if GameState.in_safe_room else "✓  SAVE TO MEMORY CARD (Vá para a Safe Room)"
	save_btn.disabled = not GameState.in_safe_room
	_style_button(save_btn, Color(0.03, 0.24, 0.16, 0.92), Color(0.12, 0.88, 0.55, 1.0), Color(0.45, 1.0, 0.78), 1, 5)
	save_btn.pressed.connect(func() -> void:
		var lvl: ChildrenFirstHall = _get_level()
		var pos: Vector2 = lvl.player.global_position if lvl != null else Vector2(-1, -1)
		if GameState.save_game(pos):
			feedback_msg = "Progresso salvo no Memory Card!"
			_refresh()
	)
	opt_vb.add_child(save_btn)

	# Red EXIT TO MAIN MENU button
	var exit_btn := Button.new()
	exit_btn.custom_minimum_size = Vector2(0, 42)
	exit_btn.add_theme_font_size_override("font_size", 12)
	exit_btn.text = "✕  EXIT TO MAIN MENU"
	_style_button(exit_btn, Color(0.28, 0.05, 0.07, 0.92), Color(0.9, 0.22, 0.26, 1.0), Color(1.0, 0.65, 0.68), 1, 5)
	exit_btn.pressed.connect(func() -> void:
		close_menu()
		get_tree().change_scene_to_file("res://src/ui/title_screen.tscn")
	)
	opt_vb.add_child(exit_btn)


func _make_toggle_row(label_text: String, btn_text: String, is_on: bool, callback: Callable) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _make_box(Color(0.05, 0.06, 0.09, 0.9), Color(0.22, 0.26, 0.32, 0.8), 1, 5, 12, 8))
	var hb := HBoxContainer.new()
	pc.add_child(hb)
	var lbl := Label.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 12)
	hb.add_child(lbl)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(72, 28)
	btn.add_theme_font_size_override("font_size", 11)
	btn.text = btn_text
	if is_on:
		_style_button(btn, Color(0.06, 0.55, 0.72, 0.95), Color(0.2, 0.92, 1.0, 1.0), Color.WHITE, 1, 4)
	else:
		_style_button(btn, Color(0.14, 0.16, 0.2, 0.9), Color(0.32, 0.36, 0.44, 0.8), Color(0.75, 0.8, 0.85), 1, 4)
	btn.pressed.connect(callback)
	hb.add_child(btn)
	return pc
