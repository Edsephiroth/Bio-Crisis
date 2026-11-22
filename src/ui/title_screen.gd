extends Control

@onready var btn_continue: Button = %BtnContinue
@onready var btn_start: Button = %BtnStart
@onready var save_info_label: Label = %SaveInfoLabel


func _ready() -> void:
	btn_start.pressed.connect(_on_start_pressed)
	btn_continue.pressed.connect(_on_continue_pressed)

	if GameState.has_save_file():
		var summary: Dictionary = GameState.get_save_summary()
		btn_continue.visible = true
		var lvl: int = int(summary.get("level", 1))
		var room_title: String = str(summary.get("room_title", "ONG Children First"))
		var ts: String = str(summary.get("timestamp", ""))
		btn_continue.text = "CONTINUAR (LV.%d)" % lvl
		save_info_label.text = "Último Save: %s  •  %s" % [room_title, ts]
		save_info_label.visible = true
	else:
		btn_continue.visible = false
		save_info_label.visible = false


func _on_continue_pressed() -> void:
	GameState.pending_load_from_save = true
	get_tree().change_scene_to_file("res://src/levels/children_first_hall.tscn")


func _on_start_pressed() -> void:
	GameState.pending_load_from_save = false
	get_tree().change_scene_to_file("res://src/levels/children_first_hall.tscn")
