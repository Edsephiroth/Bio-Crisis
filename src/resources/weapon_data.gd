class_name WeaponData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var caliber: String = "9mm"
@export var attack_bonus: int = 15
@export var range_px: float = 240.0
@export var rate_of_fire: int = 2
@export var capacity: int = 15
@export var mag_current: int = 15
@export_enum("semi", "burst", "auto", "spread", "precision") var fire_pattern: String = "burst"
@export var shot_interval: float = 0.10
@export var perks: PackedStringArray = PackedStringArray()
@export var icon_path: String = "res://assets/icons/Pe1_icon_inv_pistol.png"
@export var description: String = ""
