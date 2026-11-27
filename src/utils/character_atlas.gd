class_name CharacterAtlas
extends RefCounted

## Loads and caches Bio Crisis character texture atlases (<char>_atlas.json + <char>_atlas_N.png).
## Reconstructs exact Godot 4 AtlasTexture frames with region + margin and foot anchor metadata,
## avoiding mirrored duplicate rows (uses flip_h) to minimize VRAM footprint.

static var _cache: Dictionary = {}

var character_id: String = ""
var pages: Array[Texture2D] = []
## anim_name -> { fps: float, tipo: String, anchor: Vector2, frames: Array[AtlasTexture] }
var animations: Dictionary = {}


static func get_atlas(char_id: String) -> CharacterAtlas:
	if _cache.has(char_id):
		return _cache[char_id] as CharacterAtlas
	var atlas := CharacterAtlas.new()
	if atlas.load_from_folder("res://assets/atlases/%s" % char_id, char_id):
		_cache[char_id] = atlas
		return atlas
	return null


func load_from_folder(folder_path: String, char_id: String) -> bool:
	character_id = char_id
	var json_path: String = "%s/%s_atlas.json" % [folder_path, char_id]
	if not FileAccess.file_exists(json_path):
		push_warning("CharacterAtlas: JSON not found at %s" % json_path)
		return false

	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return false
	var data: Dictionary = parsed as Dictionary

	# Load PNG pages referenced by the JSON
	pages.clear()
	var paginas_raw: Array = data.get("paginas", []) as Array
	for p_entry in paginas_raw:
		var filename: String = ""
		if p_entry is Dictionary:
			filename = str((p_entry as Dictionary).get("arquivo", ""))
		elif p_entry is String:
			filename = str(p_entry)
		if filename == "":
			continue
		var tex_path: String = "%s/%s" % [folder_path, filename]
		var tex: Texture2D = load(tex_path) as Texture2D
		pages.append(tex)

	# Build AtlasTexture arrays per animation
	animations.clear()
	var anims_raw: Dictionary = data.get("animacoes", {}) as Dictionary
	for anim_name_var in anims_raw.keys():
		var anim_name: String = str(anim_name_var)
		var ad: Dictionary = anims_raw[anim_name_var] as Dictionary
		var fps: float = float(ad.get("fps_sugerido", ad.get("fps_original", 24.0)))
		var tipo: String = str(ad.get("tipo", "loop"))
		var anc_arr: Array = ad.get("ancora", [64.0, 180.0]) as Array
		var anchor := Vector2(float(anc_arr[0]), float(anc_arr[1])) if anc_arr.size() >= 2 else Vector2(64.0, 180.0)

		var tex_frames: Array[AtlasTexture] = []
		var raw_frames: Array = ad.get("frames", []) as Array
		for fr_var in raw_frames:
			if not (fr_var is Dictionary):
				continue
			var fr: Dictionary = fr_var as Dictionary
			var page_idx: int = int(fr.get("pagina", 0))
			if page_idx < 0 or page_idx >= pages.size() or pages[page_idx] == null:
				continue
			var reg: Array = fr.get("regiao", [0, 0, 1, 1]) as Array
			var orig: Array = fr.get("tamanho_original", [reg[2], reg[3]]) as Array
			var mx: float = float(fr.get("margem_x", 0.0))
			var my: float = float(fr.get("margem_y", 0.0))
			var rw: float = float(reg[2])
			var rh: float = float(reg[3])
			var ow: float = float(orig[0])
			var oh: float = float(orig[1])

			var at := AtlasTexture.new()
			at.atlas = pages[page_idx]
			at.region = Rect2(float(reg[0]), float(reg[1]), rw, rh)
			at.margin = Rect2(mx, my, maxf(0.0, ow - rw), maxf(0.0, oh - rh))
			at.filter_clip = true
			tex_frames.append(at)

		if not tex_frames.is_empty():
			animations[anim_name] = {
				"fps": fps,
				"tipo": tipo,
				"anchor": anchor,
				"frames": tex_frames,
			}

	return not animations.is_empty()


func has_anim(anim_name: String) -> bool:
	return animations.has(anim_name)


func get_anim_fps(anim_name: String) -> float:
	if not animations.has(anim_name):
		return 12.0
	return float((animations[anim_name] as Dictionary).get("fps", 12.0))


func get_frame_count(anim_name: String) -> int:
	if not animations.has(anim_name):
		return 0
	return ((animations[anim_name] as Dictionary)["frames"] as Array).size()


func get_frame_index(anim_name: String, elapsed_sec: float, speed_mult: float = 1.0) -> int:
	if not animations.has(anim_name):
		return 0
	var ad: Dictionary = animations[anim_name] as Dictionary
	var n: int = (ad["frames"] as Array).size()
	if n <= 1:
		return 0
	var fps: float = float(ad["fps"]) * speed_mult
	var tipo: String = str(ad["tipo"])
	var raw_idx: int = int(floor(maxf(0.0, elapsed_sec) * fps))
	match tipo:
		"one_shot":
			return mini(raw_idx, n - 1)
		"ping_pong":
			var period: int = (n - 1) * 2
			var step: int = raw_idx % period
			return step if step < n else (period - step)
		_:
			return raw_idx % n


func is_one_shot_finished(anim_name: String, elapsed_sec: float, speed_mult: float = 1.0) -> bool:
	if not animations.has(anim_name):
		return true
	var ad: Dictionary = animations[anim_name] as Dictionary
	var n: int = (ad["frames"] as Array).size()
	var fps: float = float(ad["fps"]) * speed_mult
	return elapsed_sec * fps >= float(n)


func apply_to_sprite(sprite: Sprite2D, anim_name: String, frame_idx: int, flip_h: bool) -> bool:
	if not animations.has(anim_name):
		return false
	var ad: Dictionary = animations[anim_name] as Dictionary
	var frames: Array = ad["frames"] as Array
	if frames.is_empty():
		return false
	var safe_idx: int = clampi(frame_idx, 0, frames.size() - 1)
	var anchor: Vector2 = ad["anchor"] as Vector2
	sprite.hframes = 1
	sprite.vframes = 1
	sprite.frame = 0
	sprite.centered = false
	sprite.offset = Vector2(-anchor.x, -anchor.y)
	sprite.flip_h = flip_h
	sprite.texture = frames[safe_idx] as AtlasTexture
	return true


func _pick_first_existing(candidates: Array) -> String:
	for c in candidates:
		var s: String = str(c)
		if animations.has(s):
			return s
	return ""


## Resolves 8-direction index (0=D, 1=U, 2=L, 3=R, 4=DL, 5=DR, 6=UL, 7=UR) to {anim, flip_h}.
## Per LEIA-ME.txt: lateral & diagonal frames face LEFT by default (except Elisabeth's run_lateral_PLACEHOLDER which faces RIGHT).
func resolve_8dir(action: String, dir8: int) -> Dictionary:
	var anim: String = ""
	var flip_h: bool = false

	match action:
		"walk":
			match dir8:
				0: anim = _pick_first_existing(["walk_baixo", "caminhada_baixo"])
				1: anim = _pick_first_existing(["walk_cima", "caminhada_cima"])
				2:
					anim = _pick_first_existing(["walk_lateral", "caminhada_lateral"])
					flip_h = false
				3:
					anim = _pick_first_existing(["walk_lateral", "caminhada_lateral"])
					flip_h = true
				4:
					anim = _pick_first_existing(["walk_diagonal_baixo", "walk_diag_baixo", "caminhada_diagonal_walk_diag_baixo"])
					flip_h = false
				5:
					anim = _pick_first_existing(["walk_diagonal_baixo", "walk_diag_baixo", "caminhada_diagonal_walk_diag_baixo"])
					flip_h = true
				6:
					anim = _pick_first_existing(["walk_diagonal_cima", "walk_diag_cima", "caminhada_diagonal_walk_diag_cima"])
					flip_h = false
				7:
					anim = _pick_first_existing(["walk_diagonal_cima", "walk_diag_cima", "caminhada_diagonal_walk_diag_cima"])
					flip_h = true
		"run":
			match dir8:
				0: anim = _pick_first_existing(["run_baixo", "walk_baixo", "caminhada_baixo"])
				1: anim = _pick_first_existing(["run_cima", "run_cima_PLACEHOLDER", "walk_cima", "caminhada_cima"])
				2:
					anim = _pick_first_existing(["run_lateral", "run_lateral_PLACEHOLDER", "walk_lateral", "caminhada_lateral"])
					flip_h = (anim == "run_lateral_PLACEHOLDER")
				3:
					anim = _pick_first_existing(["run_lateral", "run_lateral_PLACEHOLDER", "walk_lateral", "caminhada_lateral"])
					flip_h = (anim != "run_lateral_PLACEHOLDER")
				4:
					anim = _pick_first_existing(["run_diagonal_baixo", "run_diag_baixo", "walk_diagonal_baixo", "walk_diag_baixo"])
					flip_h = false
				5:
					anim = _pick_first_existing(["run_diagonal_baixo", "run_diag_baixo", "walk_diagonal_baixo", "walk_diag_baixo"])
					flip_h = true
				6:
					anim = _pick_first_existing(["run_diagonal_cima", "run_diag_cima", "walk_diagonal_cima", "walk_diag_cima"])
					flip_h = false
				7:
					anim = _pick_first_existing(["run_diagonal_cima", "run_diag_cima", "walk_diagonal_cima", "walk_diag_cima"])
					flip_h = true
		"attack":
			match dir8:
				0: anim = _pick_first_existing(["ataque_baixo"])
				1: anim = _pick_first_existing(["ataque_cima"])
				2:
					anim = _pick_first_existing(["ataque_lateral"])
					flip_h = false
				3:
					anim = _pick_first_existing(["ataque_lateral"])
					flip_h = true
				4:
					anim = _pick_first_existing(["ataque_diagonal_atk_diag_baixo"])
					flip_h = false
				5:
					anim = _pick_first_existing(["ataque_diagonal_atk_diag_baixo"])
					flip_h = true
				6:
					anim = _pick_first_existing(["ataque_diagonal_atk_diag_cima"])
					flip_h = false
				7:
					anim = _pick_first_existing(["ataque_diagonal_atk_diag_cima"])
					flip_h = true
		"idle":
			var is_up: bool = (dir8 == 1 or dir8 == 6 or dir8 == 7)
			anim = _pick_first_existing(["idle_idle_cima", "idle_idle_baixo"] if is_up else ["idle_idle_baixo", "idle_idle_cima"])
			flip_h = false

	return {"anim": anim, "flip_h": flip_h}
