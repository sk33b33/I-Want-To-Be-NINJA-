class_name PauseMenu
extends Control
## Pause menu (Esc / Start / on-screen pause button). Pausing freezes the game tree and the
## expedition countdown (docs/GAME_DESIGN.md: pause must not consume the timer).
## Runs while the tree is paused (process_mode ALWAYS).

@export var manager_path: NodePath

var _manager: ExpeditionManager
var _resume: Button
var _mouse_mode_before: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_manager = get_node_or_null(manager_path) as ExpeditionManager
	_build()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if _manager == null or _manager.ended:
		return
	_mouse_mode_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_manager.set_paused(true)
	visible = true
	_resume.grab_focus()  # Gamepad navigation.


func close() -> void:
	visible = false
	if _manager:
		_manager.set_paused(false)
	Input.mouse_mode = _mouse_mode_before


func _build() -> void:
	add_child(UiStyle.dim_backdrop(0.55))
	var panel := UiStyle.panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var title := UiStyle.label("Paused", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var note := UiStyle.label("The trail waits for you. The timer is frozen.", 20, UiStyle.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(note)
	_resume = UiStyle.button("Resume")
	_resume.pressed.connect(close)
	col.add_child(_resume)
	var restart := UiStyle.button("Restart expedition", UiStyle.WARNING)
	restart.pressed.connect(func() -> void: _manager.restart())
	col.add_child(restart)
	var board := UiStyle.button("Back to hunt board", UiStyle.MUTED)
	board.pressed.connect(func() -> void: _manager.return_to_hunt_board())
	col.add_child(board)
	add_child(UiStyle.centered(panel))
