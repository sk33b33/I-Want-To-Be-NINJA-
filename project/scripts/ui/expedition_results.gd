class_name ExpeditionResults
extends Control
## End-of-expedition screen: timeout ("the beast escaped") or victory (time used, parts broken,
## materials earned — already saved to the player profile by ExpeditionManager).

@export var manager_path: NodePath

var _manager: ExpeditionManager
var _title: Label
var _body: Label
var _retry: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	visible = false
	_manager = get_node_or_null(manager_path) as ExpeditionManager
	if _manager:
		_manager.expedition_ended.connect(show_result)


func show_result(result: Dictionary) -> void:
	var hunt := result.get("hunt") as HuntDefinition
	var who := hunt.beast_name if hunt else "The beast"
	match result.get("outcome", ""):
		"victory":
			_title.text = "Hunt complete"
			_title.add_theme_color_override("font_color", UiStyle.SPIRIT)
			var lines: PackedStringArray = ["%s has fallen." % who,
					"Time in the jungle: %s" % ExpeditionTimer.format_time(float(result.get("elapsed", 0.0)))]
			var parts: Array = result.get("parts_broken", [])
			lines.append("Parts broken: %s" % (", ".join(parts.map(func(p: StringName) -> String: return String(p).capitalize())) if not parts.is_empty() else "none"))
			var rewards: Dictionary = result.get("rewards", {})
			var items: Dictionary = result.get("items", {})
			lines.append("Materials:")
			for id in rewards:
				var item := items.get(id) as ItemDefinition
				lines.append("  + %d  %s" % [int(rewards[id]), item.display_name if item else String(id)])
			_body.text = "\n".join(lines)
			_retry.text = "Hunt again"
		"escaped":
			_title.text = "The trail went cold"
			_body.text = "%s escaped into the jungle.\nYou searched for %s." % [
				who, ExpeditionTimer.format_time(float(result.get("elapsed", 0.0)))]
		_:
			_title.text = "Expedition over"
			_body.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_retry.grab_focus()


func _build() -> void:
	add_child(UiStyle.dim_backdrop(0.7))
	var panel := UiStyle.panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(520, 0)
	panel.add_child(col)
	_title = UiStyle.label("", 40, UiStyle.DANGER)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	_body = UiStyle.label("", 22)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_body)
	_retry = UiStyle.button("Retry the hunt")
	_retry.pressed.connect(func() -> void: _manager.restart())
	col.add_child(_retry)
	var board := UiStyle.button("Back to hunt board", UiStyle.MUTED)
	board.pressed.connect(func() -> void: _manager.return_to_hunt_board())
	col.add_child(board)
	add_child(UiStyle.centered(panel))
