class_name PauseMenu
extends Control
## Pause menu (Esc / Start / on-screen pause button). Pausing freezes the game tree and the
## expedition countdown (docs/GAME_DESIGN.md: pause must not consume the timer).
## Runs while the tree is paused (process_mode ALWAYS).

@export var manager_path: NodePath

var _manager: ExpeditionManager
var _resume: Button
var settings: SettingsPanel
## Shortcuts to the comfort toggles (tests and gamepad focus).
var shake_button: Button:
	get: return settings.shake_button
var warnings_button: Button:
	get: return settings.warnings_button
var _mouse_mode_before: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_manager = get_node_or_null(manager_path) as ExpeditionManager
	GameSettings.ensure_loaded()
	_build()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()


## Switching to another app (or a phone call) pauses the hunt so the countdown is not lost.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if not visible:
			open()


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
	_refresh_secrets()
	visible = true
	_resume.grab_focus()  # Gamepad navigation.


func close() -> void:
	visible = false
	if _manager:
		_manager.set_paused(false)
	Input.mouse_mode = _mouse_mode_before


var secrets_label: Label


func _refresh_secrets() -> void:
	if secrets_label == null:
		return
	var spots := get_tree().get_first_node_in_group("secret_spots") as SecretSpots
	var set_data := spots.secret_set if spots else null
	secrets_label.visible = set_data != null
	if set_data == null:
		return
	var profile := PlayerProfile.load_profile()
	var lines: PackedStringArray = ["Spirit shrines: %d / %d%s" % [set_data.found_count(profile), set_data.secrets.size(),
			"  —  %s (+%d max health)" % [set_data.blessing_name, int(set_data.blessing_health)] if set_data.is_complete(profile) else ""]]
	for d in set_data.secrets:
		if not profile.has_secret(d.id):
			lines.append("• " + d.hint)
	secrets_label.text = "\n".join(lines)


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
	# Phase 13: this jungle's hidden spirit shrines — count, and a riddle for each still missing.
	secrets_label = UiStyle.label("", 18, UiStyle.MUTED)
	secrets_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	secrets_label.custom_minimum_size = Vector2(520, 0)
	col.add_child(secrets_label)
	_resume = UiStyle.button("Resume")
	_resume.pressed.connect(close)
	col.add_child(_resume)
	# Settings (graphics, volume, comfort / readability) — saved immediately.
	settings = SettingsPanel.new()
	col.add_child(settings)
	var restart := UiStyle.button("Restart expedition", UiStyle.WARNING)
	restart.pressed.connect(func() -> void: _manager.restart())
	col.add_child(restart)
	var board := UiStyle.button("Back to hunt board", UiStyle.MUTED)
	board.pressed.connect(func() -> void: _manager.return_to_hunt_board())
	col.add_child(board)
	add_child(UiStyle.centered(panel))

