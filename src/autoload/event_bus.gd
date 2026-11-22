extends Node

## Central signal bus for decoupled communication across systems.

signal player_stats_changed
signal tactical_mode_changed(active: bool, mode_type: String)
signal target_selected(enemy: Node2D)
signal enemy_defeated(enemy_name: String, exp_reward: int, bp_reward: int, world_pos: Vector2)
signal floating_text_requested(text: String, world_pos: Vector2, color: Color)
signal toast_message(text: String, color: Color)
signal weapon_fired(from_pos: Vector2, to_pos: Vector2, is_energy_shot: bool)
signal screen_shake_requested(intensity: float, duration: float)
signal safe_room_state_changed(in_safe_room: bool)
signal dialogue_requested(lines: Array)
signal dialogue_finished
signal interaction_prompt_changed(visible: bool, label: String)
signal room_changed(room_title: String)
signal boss_status_changed(active: bool, boss_name: String, hp: int, max_hp: int, phase: int)
signal game_over_triggered
signal victory_triggered
