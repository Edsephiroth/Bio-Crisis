extends Node

## Centralized audio engine with SFX pooling, pitch jitter, and looping survival horror BGM.

const SFX_PATHS: Dictionary = {
	"pistol": "res://assets/audio/sfx_pistol.wav",
	"shotgun": "res://assets/audio/sfx_shotgun.wav",
	"rifle": "res://assets/audio/sfx_rifle.wav",
	"energy_shot": "res://assets/audio/sfx_energy_shot.wav",
	"heal": "res://assets/audio/sfx_heal.wav",
	"haste": "res://assets/audio/sfx_haste.wav",
	"atb_ready": "res://assets/audio/sfx_atb_ready.wav",
	"tactical_open": "res://assets/audio/sfx_tactical_open.wav",
	"hit_enemy": "res://assets/audio/sfx_hit_enemy.wav",
	"player_hurt": "res://assets/audio/sfx_player_hurt.wav",
	"enemy_die": "res://assets/audio/sfx_enemy_die.wav",
	"step": "res://assets/audio/sfx_step.wav",
	"level_up": "res://assets/audio/sfx_level_up.wav",
}

const BGM_AMBIENT_PATH: String = "res://assets/audio/bgm_gala_ambient.wav"
const POOL_SIZE: int = 10

var sfx_streams: Dictionary = {}
var bgm_ambient: AudioStream = null
var sfx_pool: Array[AudioStreamPlayer] = []
var bgm_player: AudioStreamPlayer
var is_muted: bool = false
var _pool_cursor: int = 0


func _ready() -> void:
	for key in SFX_PATHS.keys():
		var path: String = str(SFX_PATHS[key])
		if ResourceLoader.exists(path):
			sfx_streams[key] = load(path) as AudioStream

	if ResourceLoader.exists(BGM_AMBIENT_PATH):
		bgm_ambient = load(BGM_AMBIENT_PATH) as AudioStream

	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.volume_db = -4.0
		add_child(player)
		sfx_pool.append(player)

	bgm_player = AudioStreamPlayer.new()
	bgm_player.volume_db = -14.0
	bgm_player.finished.connect(_on_bgm_finished)
	add_child(bgm_player)

	EventBus.tactical_mode_changed.connect(_on_tactical_mode_changed)
	EventBus.enemy_defeated.connect(_on_enemy_defeated)


func start_ambient_bgm() -> void:
	if bgm_player == null or bgm_ambient == null:
		return
	if bgm_player.stream != bgm_ambient:
		bgm_player.stream = bgm_ambient
	if not bgm_player.playing and not is_muted:
		bgm_player.play()


func stop_bgm() -> void:
	if bgm_player != null and bgm_player.playing:
		bgm_player.stop()


func _on_bgm_finished() -> void:
	if not is_muted and bgm_player != null and bgm_player.stream != null:
		bgm_player.play()


func toggle_mute() -> bool:
	is_muted = not is_muted
	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_mute(master_idx, is_muted)
	if not is_muted and bgm_player != null and bgm_player.stream != null and not bgm_player.playing:
		bgm_player.play()
	return is_muted


func play_sfx(key: String, volume_db: float = -3.0, pitch_jitter: float = 0.06) -> void:
	if is_muted or not sfx_streams.has(key) or sfx_pool.is_empty():
		return
	var player: AudioStreamPlayer = sfx_pool[_pool_cursor % sfx_pool.size()]
	_pool_cursor = (_pool_cursor + 1) % sfx_pool.size()
	player.stream = sfx_streams[key] as AudioStream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter) if pitch_jitter > 0.0 else 1.0
	player.play()


func play_weapon_sfx(weapon_id: String, is_energy_shot: bool) -> void:
	if is_energy_shot:
		play_sfx("energy_shot", -2.0, 0.03)
		return
	match weapon_id:
		"m870":
			play_sfx("shotgun", -1.5, 0.05)
		"m4a1":
			play_sfx("rifle", -2.5, 0.06)
		_:
			play_sfx("pistol", -2.5, 0.07)


func _on_tactical_mode_changed(active: bool, _mode_type: String) -> void:
	if active:
		play_sfx("tactical_open", -4.0, 0.02)
		if bgm_player != null:
			bgm_player.volume_db = -20.0
	else:
		if bgm_player != null:
			bgm_player.volume_db = -14.0


func _on_enemy_defeated(_name: String, _exp: int, _bp: int, _pos: Vector2) -> void:
	play_sfx("enemy_die", -2.5, 0.05)
