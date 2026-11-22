class_name BioDatabase
extends RefCounted

## Static catalog migrated from the original Bio Crisis prototype (weapons, armors, lore documents, bestiary).

static func create_starter_weapons() -> Array[WeaponData]:
	var list: Array[WeaponData] = []

	list.append(_make_weapon(
		"m93r", "M93R", "9mm", 18, 230.0, 3, 18, "burst", 0.095, PackedStringArray(["quickdraw"]),
		"res://assets/icons/Pe1_icon_inv_pistol.png",
		"Pistola italiana 9mm com rajada de 3 tiros rápidos. Perk: Quickdraw."
	))
	list.append(_make_weapon(
		"glock19", "Glock 19", "9mm", 14, 215.0, 2, 16, "semi", 0.13, PackedStringArray(["frost", "critup"]),
		"res://assets/icons/Pe1_icon_inv_pistol.png",
		"Pistola leve semiautomática (2 tiros). Perks: Frost + Crit Up."
	))
	list.append(_make_weapon(
		"m870", "M870 Shotgun", "12G", 36, 165.0, 1, 6, "spread", 0.0, PackedStringArray(["heat"]),
		"res://assets/icons/Pe1_icon_inv_shotgun.png",
		"Escopeta 12G em cone (5 estilhaços simultâneos). Perk: Heat."
	))
	list.append(_make_weapon(
		"mp5a5", "MP5A5 SMG", "9mm", 22, 225.0, 5, 30, "auto", 0.065, PackedStringArray(["acid"]),
		"res://assets/icons/Pe1_icon_inv_smg.png",
		"Submetralhadora automática (rajada de 5 tiros em sequência). Perk: Acid."
	))
	list.append(_make_weapon(
		"m4a1", "M4A1 Rifle", "5.56mm", 28, 300.0, 2, 24, "precision", 0.14, PackedStringArray(["2comm"]),
		"res://assets/icons/Pe1_icon_inv_rifle.png",
		"Carabina tática de longo alcance (2 tiros precisos). Perk: 2x Command."
	))
	return list


static func create_starter_armors() -> Array[ArmorData]:
	var list: Array[ArmorData] = []
	list.append(_make_armor(
		"gala_jacket", "Jaqueta de Gala", 6, 4, 0, PackedStringArray([]),
		"res://assets/icons/Pe1_icon_inv_jacket.png",
		"Roupa civil usada por Elisabeth na gala da ONG Children First."
	))
	list.append(_make_armor(
		"kv_vest", "Colete Kevlar", 16, 8, 40, PackedStringArray(["nopois", "autoheal"]),
		"res://assets/icons/Pe1_icon_inv_vest.png",
		"Colete balístico tático. Perks: Anti-Poison + Auto-Medkit (<25% HP)."
	))
	list.append(_make_armor(
		"cm_protector", "Protetor Celular", 22, 20, 80, PackedStringArray(["nopois", "nostiff", "nodark"]),
		"res://assets/icons/Pe1_icon_inv_protector.png",
		"Revestimento bio-celular. Perks: Imune a Poison, Stiff e Darkness."
	))
	return list


static func get_documents() -> Array[Dictionary]:
	return [
		{
			"id": "doc-1",
			"title": "Relatório do Incidente de Gala — ONG Children First",
			"date": "24/10/2026 21:15",
			"content": "Registro de emergência da sede da ONG Children First. Durante a festa de gala de celebração do novo projeto, convidados e funcionários sofreram mutações grotescas e atacaram violentamente a multidão. Sobrevivente confirmada: Elisabeth Shelley, Professora de Inglês, socorrida no ataque inicial por um desconhecido misterioso.",
		},
		{
			"id": "doc-2",
			"title": "Bilhete Deixado pelo Desconhecido",
			"date": "24/10/2026 21:30",
			"content": "\"Elisabeth, você sobreviveu ao massacre inicial no salão principal porque sua bio-ressonância celular está intacta. As portas do complexo foram seladas pelo terminal central. Pegue este equipamento e os suprimentos médicos que encontrar. Cuidado com os deformados e alcance a rota de evacuação.\"",
		},
		{
			"id": "doc-3",
			"title": "Guia de Sobrevivência — Energia Bio-Celular (PE)",
			"date": "24/10/2026 21:45",
			"content": "Sob extrema adrenalina de perigo, a bio-energia celular pode ser despertada em impulsos defensivos: HEAL (Reparo Celular), HASTE (Aceleração Metabólica e ATB) e ENERGY SHOT (Descarga de Choque Bioelétrico perfurante).",
		},
	]


static func get_bestiary_entries() -> Array[Dictionary]:
	return [
		{
			"id": "deformed_common",
			"name": "CONVIDADO DEFORMADO",
			"scientific": "Homo Aberrans",
			"threat": "MÉDIO",
			"weakness": "Cinético / Rajadas Rápidas",
			"description": "Convidado ou funcionário da gala da ONG Children First corrompido pelo surto biológico súbito. Avança em perseguição implacável pelos corredores.",
		},
		{
			"id": "alpha_mutant",
			"name": "MUTANTE ALFA (ORGANISMO CENTRAL)",
			"scientific": "Organismus Primus Alfa",
			"threat": "OMEGA",
			"weakness": "Energy Shot / Alto Calibre",
			"description": "A aberração primária que comandou o massacre no salão de festas da ONG Children First. Alta resistência física e ataques devastadores.",
		},
		{
			"id": "mutant_rat",
			"name": "RATO MUTANTE",
			"scientific": "Rattus Mitochondrius",
			"threat": "BAIXO",
			"weakness": "Fogo / Calor",
			"description": "Roedor urbano sofrendo mutação mitocondrial súbita. Desenvolveu mandíbulas alongadas e agressividade extrema.",
		},
		{
			"id": "mutant_dog",
			"name": "CÃO DE PATRULHA MUTADO",
			"scientific": "Canis Aberrans",
			"threat": "MÉDIO",
			"weakness": "Frio / Energia Bio-Celular",
			"description": "Cão de guarda da segurança da ONG Children First corrompido pela mutação. Possui velocidade letal.",
		},
		{
			"id": "amorphous_mass",
			"name": "MASSA AMORFA / SLIME",
			"scientific": "Protoplasma Aberrans",
			"threat": "ALTO",
			"weakness": "Chamas Térmicas / Energia",
			"description": "Massa protoplasmática em constante diferenciação formada pela anomalia biológica. Absorve impactos cinéticos comuns.",
		},
	]


static func _make_weapon(
	id: String, dname: String, cal: String, atk: int, rng: float, rof: int, cap: int, pattern: String, interval: float, perks: PackedStringArray, icon: String, desc: String
) -> WeaponData:
	var w := WeaponData.new()
	w.id = id
	w.display_name = dname
	w.caliber = cal
	w.attack_bonus = atk
	w.range_px = rng
	w.rate_of_fire = rof
	w.capacity = cap
	w.mag_current = cap
	w.fire_pattern = pattern
	w.shot_interval = interval
	w.perks = perks
	w.icon_path = icon
	w.description = desc
	return w


static func _make_armor(
	id: String, dname: String, def: int, pe_def: int, hp_b: int, perks: PackedStringArray, icon: String, desc: String
) -> ArmorData:
	var a := ArmorData.new()
	a.id = id
	a.display_name = dname
	a.defense_bonus = def
	a.pe_defense_bonus = pe_def
	a.hp_bonus = hp_b
	a.perks = perks
	a.icon_path = icon
	a.description = desc
	return a
