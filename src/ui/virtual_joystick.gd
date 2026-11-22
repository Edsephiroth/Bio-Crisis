class_name VirtualJoystick
extends Control

@export var max_radius: float = 52.0

var active_touch_index: int = -1
var knob_offset: Vector2 = Vector2.ZERO


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and active_touch_index == -1:
			active_touch_index = touch.index
			_update_knob(touch.position)
			accept_event()
		elif not touch.pressed and touch.index == active_touch_index:
			_reset_knob()
			accept_event()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == active_touch_index:
			_update_knob(drag.position)
			accept_event()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				active_touch_index = 999
				_update_knob(mb.position)
				accept_event()
			elif active_touch_index == 999:
				_reset_knob()
				accept_event()
	elif event is InputEventMouseMotion and active_touch_index == 999:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_update_knob(mm.position)
		accept_event()


func _update_knob(local_pos: Vector2) -> void:
	var center: Vector2 = size * 0.5
	var delta: Vector2 = local_pos - center
	if delta.length() > max_radius:
		delta = delta.normalized() * max_radius
	knob_offset = delta
	GameState.virtual_move_vector = knob_offset / max_radius
	queue_redraw()


func _reset_knob() -> void:
	active_touch_index = -1
	knob_offset = Vector2.ZERO
	GameState.virtual_move_vector = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	draw_circle(center, max_radius, Color(0.06, 0.12, 0.18, 0.45))
	draw_arc(center, max_radius, 0.0, TAU, 40, Color(0.25, 0.85, 0.95, 0.55), 2.0, true)
	draw_circle(center + knob_offset, 22.0, Color(0.25, 0.9, 1.0, 0.72))
	draw_arc(center + knob_offset, 22.0, 0.0, TAU, 24, Color(0.85, 0.98, 1.0, 0.9), 2.0, true)
