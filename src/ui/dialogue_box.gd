class_name DialogueBox
extends Control

## Classic RPG dialogue box with Elisabeth bust portrait, typewriter effect, and touch-to-advance.

@onready var bust_rect: TextureRect = %BustRect
@onready var speaker_label: Label = %SpeakerLabel
@onready var body_label: Label = %BodyLabel
@onready var btn_next: Button = %BtnNext

const BUST_TEX: Texture2D = preload("res://assets/ui/elisabeth_bust.png")

var queue_lines: Array = []
var current_index: int = 0
var full_text: String = ""
var visible_chars_f: float = 0.0
var is_typing: bool = false


func _ready() -> void:
	visible = false
	btn_next.pressed.connect(_advance)
	EventBus.dialogue_requested.connect(start_dialogue)


func start_dialogue(lines: Array) -> void:
	if lines.is_empty():
		return
	queue_lines = lines.duplicate()
	current_index = 0
	visible = true
	GameState.set_dialogue_open(true)
	_show_line(0)


func _show_line(idx: int) -> void:
	var line: Dictionary = queue_lines[idx] as Dictionary
	speaker_label.text = str(line.get("speaker", ""))
	full_text = str(line.get("text", ""))
	var show_bust: bool = bool(line.get("show_bust", false))
	bust_rect.visible = show_bust
	if show_bust:
		bust_rect.texture = BUST_TEX
	visible_chars_f = 0.0
	body_label.text = full_text
	body_label.visible_characters = 0
	is_typing = true
	btn_next.text = "CONTINUAR ▶" if idx < queue_lines.size() - 1 else "FECHAR ✓"


func _process(delta: float) -> void:
	if not visible or not is_typing:
		return
	visible_chars_f += delta * 58.0
	var count: int = int(visible_chars_f)
	if count >= full_text.length():
		body_label.visible_characters = -1
		is_typing = false
	else:
		body_label.visible_characters = count


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("tactical_toggle") or event.is_action_pressed("interact"):
		_advance()
		get_viewport().set_input_as_handled()


func _advance() -> void:
	if is_typing:
		body_label.visible_characters = -1
		is_typing = false
		return

	current_index += 1
	if current_index < queue_lines.size():
		_show_line(current_index)
	else:
		visible = false
		GameState.set_dialogue_open(false)
		EventBus.dialogue_finished.emit()
