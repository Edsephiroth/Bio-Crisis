extends Node2D

func _draw() -> void:
	var level := get_parent() as ChildrenFirstHall
	if level != null:
		level.draw_fx_layer()
