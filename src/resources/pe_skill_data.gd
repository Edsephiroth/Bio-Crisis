class_name PeSkillData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var pe_cost: int = 25
@export var min_level: int = 1
@export_enum("attack", "support", "recovery") var category: String = "recovery"
@export var description: String = ""
