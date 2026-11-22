class_name RoomDatabase
extends RefCounted

## Data-driven room definitions and story dialogues for the Children First NGO Prologue.

static func get_room(room_id: String) -> Dictionary:
	match room_id:
		"corridor":
			return _corridor_room()
		"main_hall":
			return _main_hall_room()
		_:
			return _gala_hall_room()


static func _gala_hall_room() -> Dictionary:
	return {
		"id": "gala_hall",
		"title": "ONG Children First — Salão de Gala",
		"ground_tex": "res://assets/tilesets/hall_ground_48.png",
		"struct_tex": "res://assets/tilesets/hall_structures_48.png",
		"props_tex": "res://assets/tilesets/hall_props_48.png",
		"src_tile_size": 48,
		"ambient_color": Color(0.32, 0.36, 0.46, 1.0),
		"emergency_pos": Vector2(11, 7.5),
		"emergency_color": Color(1.0, 0.25, 0.25, 1.0),
		"has_safe_room": true,
		"safe_room_tiles": Rect2(1, 12, 3, 3),
		"default_spawn": Vector2(10.5, 13.5),
		"intro_dialogue": "intro_gala",
		"layout": [
			"#########DD###########",
			"#....#..........#....#",
			"#....#..........#....#",
			"#....#..........#....#",
			"##..###..CCCC..###..##",
			"#.......CCCCCC.......#",
			"#..E...XXXXXXXX...E..#",
			"#......XXXXXXXX......#",
			"#......XXXXXXXX......#",
			"#......XXXXXXXX...E..#",
			"#.......CCCCCC.......#",
			"#####...CCCCCC...#####",
			"#SSS#....CCCC........#",
			"#SSS......P..........#",
			"#SSS#................#",
			"######################",
		],
		"doors": [
			{
				"id": "gala_to_corridor",
				"tile": Vector2(10, 0.8),
				"label": "Entrar no Corredor Leste",
				"target_room": "corridor",
				"target_spawn": Vector2(10.5, 11.8),
				"requires_keycard": false,
			}
		],
		"pickups": [
			{
				"id": "gala_char_switcher",
				"tile": Vector2(8.0, 13.5),
				"kind": "char_switcher",
				"label": "Trocar Personagem (Teste)",
				"color": Color(1.0, 0.85, 0.25),
			},
			{
				"id": "gala_save_terminal",
				"tile": Vector2(2.2, 13.5),
				"kind": "save_terminal",
				"label": "Terminal de Save (Salvar Jogo)",
				"color": Color(0.25, 0.85, 1.0),
			},
			{
				"id": "gala_note",
				"tile": Vector2(12.5, 12.5),
				"kind": "dialogue",
				"label": "Ler Bilhete no Chão",
				"dialogue_id": "note_stranger",
				"color": Color(0.45, 0.9, 1.0),
			},
			{
				"id": "gala_supply_crate",
				"tile": Vector2(2.5, 2.5),
				"kind": "supply",
				"label": "Pegar Suprimentos (Medkit + 9mm)",
				"medkits": 1,
				"ammo_caliber": "9mm",
				"ammo_amount": 40,
				"color": Color(0.35, 1.0, 0.6),
			},
		],
		"props": [
			{"tile": Vector2(19, 2), "src": Vector2(1, 0)},
			{"tile": Vector2(18, 13), "src": Vector2(2, 0)},
		],
	}


static func _corridor_room() -> Dictionary:
	return {
		"id": "corridor",
		"title": "Corredor Leste — Ala de Segurança",
		"ground_tex": "res://assets/tilesets/corridor_ground_48.png",
		"struct_tex": "res://assets/tilesets/corridor_structures_48.png",
		"props_tex": "res://assets/tilesets/corridor_props_48.png",
		"src_tile_size": 48,
		"ambient_color": Color(0.24, 0.28, 0.38, 1.0),
		"emergency_pos": Vector2(11, 6.5),
		"emergency_color": Color(1.0, 0.45, 0.18, 1.0),
		"has_safe_room": false,
		"safe_room_tiles": Rect2(0, 0, 0, 0),
		"default_spawn": Vector2(10.5, 11.8),
		"intro_dialogue": "enter_corridor",
		"layout": [
			"#########DD###########",
			"#.......CCCC.........#",
			"#..E....CCCC....#....#",
			"#.......CCCC....#....#",
			"####..######....###..#",
			"#....................#",
			"#....#..........E....#",
			"#....#...............#",
			"#..###....CCCC..####.#",
			"#.........CCCC.......#",
			"#...E.....CCCC.......#",
			"#.........CCCC.......#",
			"#....................#",
			"#########DD###########",
		],
		"doors": [
			{
				"id": "corridor_to_gala",
				"tile": Vector2(10, 12.6),
				"label": "Voltar ao Salão de Gala",
				"target_room": "gala_hall",
				"target_spawn": Vector2(10.5, 1.8),
				"requires_keycard": false,
			},
			{
				"id": "corridor_to_main_hall",
				"tile": Vector2(10, 0.8),
				"label": "Abrir Porta do Hall Principal",
				"target_room": "main_hall",
				"target_spawn": Vector2(10.5, 13.5),
				"requires_keycard": true,
			},
		],
		"pickups": [
			{
				"id": "corridor_keycard",
				"tile": Vector2(19.0, 2.5),
				"kind": "keycard",
				"label": "Pegar Keycard de Evacuação",
				"dialogue_id": "keycard_found",
				"color": Color(1.0, 0.85, 0.22),
			},
			{
				"id": "corridor_tool_box",
				"tile": Vector2(2.2, 6.5),
				"kind": "supply",
				"label": "Pegar Tool + Munição 12G/5.56mm",
				"tools": 1,
				"ammo_caliber": "12G",
				"ammo_amount": 12,
				"color": Color(0.95, 0.72, 0.3),
			},
		],
		"props": [
			{"tile": Vector2(1, 1), "src": Vector2(0, 0)},
			{"tile": Vector2(20, 11), "src": Vector2(1, 0)},
		],
	}


static func _main_hall_room() -> Dictionary:
	return {
		"id": "main_hall",
		"title": "Hall Principal — Rota de Evacuação",
		"ground_tex": "res://assets/tilesets/hall_ground_64.png",
		"struct_tex": "res://assets/tilesets/hall_structures_64_alpha.png",
		"props_tex": "res://assets/tilesets/hall_props_48.png",
		"src_tile_size": 64,
		"ambient_color": Color(0.28, 0.24, 0.34, 1.0),
		"emergency_pos": Vector2(11, 5.5),
		"emergency_color": Color(1.0, 0.16, 0.22, 1.0),
		"has_safe_room": false,
		"safe_room_tiles": Rect2(0, 0, 0, 0),
		"default_spawn": Vector2(10.5, 13.5),
		"intro_dialogue": "boss_intro",
		"layout": [
			"######################",
			"#....................#",
			"#....#..........#....#",
			"#....#....B.....#....#",
			"#....................#",
			"#.......XXXXXX.......#",
			"#..E....XXXXXX....E..#",
			"#.......XXXXXX.......#",
			"#.......XXXXXX.......#",
			"#....#..........#....#",
			"#....#...CCCC...#....#",
			"#........CCCC........#",
			"#........CCCC........#",
			"#........CCCC........#",
			"#....................#",
			"#########DD###########",
		],
		"doors": [
			{
				"id": "main_hall_to_corridor",
				"tile": Vector2(10, 14.6),
				"label": "Voltar ao Corredor Leste",
				"target_room": "corridor",
				"target_spawn": Vector2(10.5, 1.8),
				"requires_keycard": false,
			},
		],
		"pickups": [
			{
				"id": "main_hall_med",
				"tile": Vector2(2.5, 13.5),
				"kind": "supply",
				"label": "Pegar Medkit + PE Light",
				"medkits": 1,
				"pe_lights": 1,
				"color": Color(0.35, 1.0, 0.6),
			},
		],
		"props": [],
	}


static func get_dialogue(dialogue_id: String) -> Array[Dictionary]:
	match dialogue_id:
		"intro_gala":
			return [
				{
					"speaker": "Elisabeth Shelley",
					"text": "O que aconteceu aqui...? Num segundo estávamos brindando pela ONG Children First, no outro... as pessoas começaram a se deformar.",
					"show_bust": true,
				},
				{
					"speaker": "Elisabeth Shelley",
					"text": "Aquele estranho me tirou da emboscada e deixou esta pistola... Preciso atravessar o Salão de Gala para chegar aos corredores de saída.",
					"show_bust": true,
				},
			]
		"note_stranger":
			return [
				{
					"speaker": "Bilhete do Desconhecido",
					"text": "\"Elisabeth, sua bio-ressonância celular está intacta. As portas do Hall Principal foram seladas — encontre o Keycard de Evacuação no Corredor Leste.\"",
					"show_bust": false,
				},
				{
					"speaker": "Elisabeth Shelley",
					"text": "Bio-ressonância...? Seja quem for, ele sabe o que está causando isso. Vou pegar o Keycard no Corredor Leste!",
					"show_bust": true,
				},
			]
		"enter_corridor":
			return [
				{
					"speaker": "Elisabeth Shelley",
					"text": "O Corredor Leste está quase sem energia... A porta do Hall Principal fica ao norte, mas o leitor exige um Keycard.",
					"show_bust": true,
				},
			]
		"keycard_found":
			return [
				{
					"speaker": "Elisabeth Shelley",
					"text": "Consegui o Keycard de Evacuação! Agora posso destrancar a porta norte para o Hall Principal.",
					"show_bust": true,
				},
			]
		"boss_intro":
			return [
				{
					"speaker": "Elisabeth Shelley",
					"text": "A saída está logo ali... mas aquela coisa gigante está bloqueando o Hall Principal!",
					"show_bust": true,
				},
				{
					"speaker": "Alerta Bio-Celular",
					"text": "ANOMALIA CLASSE OMEGA DETECTADA: MUTANTE ALFA (ORGANISMUS PRIMUS). Prepare sua esfera tática ATB e sua Energia PE!",
					"show_bust": false,
				},
			]
		"prologue_victory":
			return [
				{
					"speaker": "Elisabeth Shelley",
					"text": "Acabou... o Organismo Alfa caiu. Mas esse surto não pode ter começado só aqui na ONG Children First...",
					"show_bust": true,
				},
				{
					"speaker": "Elisabeth Shelley",
					"text": "Preciso sair deste prédio agora e descobrir quem era aquele desconhecido.",
					"show_bust": true,
				},
			]
		_:
			return []
