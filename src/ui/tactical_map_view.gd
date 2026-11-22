class_name TacticalMapView
extends Control

## Live tactical map canvas rendered inside the ModernMenu MAP tab (matching prototype screenshot).

var level_ref: ChildrenFirstHall = null


func set_level(lvl: ChildrenFirstHall) -> void:
	level_ref = lvl
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05, 0.92))
	if level_ref == null or level_ref.layout_rows.is_empty():
		return

	var cols: int = level_ref.map_cols
	var rows: int = level_ref.map_rows
	var pad: float = 24.0
	var cell: float = minf((size.x - pad * 2.0) / float(cols), (size.y - pad * 2.0) / float(rows))
	var map_w: float = cell * float(cols)
	var map_h: float = cell * float(rows)
	var origin: Vector2 = Vector2((size.x - map_w) * 0.5, (size.y - map_h) * 0.5)

	# Room floor background
	draw_rect(Rect2(origin, Vector2(map_w, map_h)), Color(0.06, 0.07, 0.09, 1.0))

	for y in range(rows):
		var row: String = str(level_ref.layout_rows[y])
		for x in range(cols):
			var ch: String = row[x]
			var r := Rect2(origin + Vector2(x * cell, y * cell), Vector2(cell, cell))
			if ch == "#":
				draw_rect(r, Color(0.14, 0.16, 0.2, 1.0))
				draw_rect(r, Color(0.22, 0.25, 0.3, 0.5), false, 1.0)
			elif ch == "S":
				draw_rect(r, Color(0.06, 0.45, 0.3, 0.55))
				draw_rect(r, Color(0.1, 0.9, 0.55, 0.85), false, 1.0)
			elif ch == "D":
				draw_rect(r, Color(0.1, 0.65, 0.85, 0.65))

	# Draw doors
	for door in level_ref.active_doors:
		var dd: Dictionary = door as Dictionary
		var t: Vector2 = dd["tile"] as Vector2
		var p: Vector2 = origin + t * cell
		var locked: bool = bool(dd.get("requires_keycard", false)) and not GameState.has_keycard
		var col: Color = Color(1.0, 0.3, 0.3) if locked else Color(0.2, 0.9, 1.0)
		draw_rect(Rect2(p - Vector2(cell * 0.35, cell * 0.25), Vector2(cell * 0.7, cell * 0.5)), col)

	# Draw pickups / supplies
	for p_item in level_ref.active_pickups:
		var pd: Dictionary = p_item as Dictionary
		var t: Vector2 = pd["tile"] as Vector2
		var p: Vector2 = origin + t * cell
		draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), Color(1.0, 0.72, 0.15))

	# Draw Elisabeth position
	if level_ref.player != null:
		var pt: Vector2 = level_ref.player.global_position / float(ChildrenFirstHall.TILE_SIZE)
		var pp: Vector2 = origin + pt * cell
		draw_circle(pp, 7.0, Color(0.1, 0.85, 0.95, 0.35))
		draw_circle(pp, 4.5, Color(0.2, 0.95, 1.0, 1.0))
		draw_arc(pp, 6.0, 0.0, TAU, 24, Color(0.8, 0.98, 1.0, 0.9), 1.5, true)
