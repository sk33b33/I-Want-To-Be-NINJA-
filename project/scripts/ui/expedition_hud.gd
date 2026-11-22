class_name ExpeditionHud
extends Control
## Top-centre expedition HUD: target beast and the MM:SS countdown. Amber under the warning
## threshold, red and pulsing under the critical threshold. Hidden for good once the boss arena
## is entered (a short message announces the hunt instead). Listens to ExpeditionManager only.

@export var manager_path: NodePath

var _manager: ExpeditionManager
var _box: VBoxContainer
var _target: Label
var _time: Label
var _status: Label
var _banner: Label
var _banner_timer: float = 0.0
var _pulse: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_manager = get_node_or_null(manager_path) as ExpeditionManager
	if _manager:
		_manager.expedition_started.connect(_on_started)
		_manager.boss_arena_entered.connect(_on_arena)
		_manager.timer_expired.connect(_on_expired)
		_manager.pause_changed.connect(func(p: bool) -> void: _status.text = "PAUSED" if p else "")
		if _manager.timer.is_active():
			_on_started(_manager.hunt, _manager.timer.duration)


func _process(delta: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer -= delta
		_banner.modulate.a = clampf(_banner_timer, 0.0, 1.0)
		_banner.visible = _banner_timer > 0.0
	if _manager == null or not _box.visible:
		return
	var remaining := _manager.timer.remaining
	_time.text = ExpeditionTimer.format_time(remaining)
	var color := UiStyle.BONE
	var scale_ := 1.0
	if remaining <= _manager.config.critical_seconds:
		_pulse += delta * 6.0
		color = UiStyle.DANGER
		scale_ = 1.0 + 0.06 * sin(_pulse)
	elif remaining <= _manager.config.warning_seconds:
		color = UiStyle.WARNING
	_time.add_theme_color_override("font_color", color)
	_time.pivot_offset = _time.size * 0.5
	_time.scale = Vector2.ONE * scale_


## For tests: the timer text currently shown, or "" when hidden.
func shown_time() -> String:
	return _time.text if _box.visible else ""


func is_timer_visible() -> bool:
	return _box.visible


func _build() -> void:
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_box.position = Vector2(-200, 10)
	_box.custom_minimum_size = Vector2(400, 0)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_target = UiStyle.label("", 18, UiStyle.MUTED)
	_target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_target)
	_time = UiStyle.label("45:00", 44)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_time)
	_status = UiStyle.label("", 18, UiStyle.SPIRIT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_status)
	_box.visible = false
	_banner = UiStyle.label("", 30, UiStyle.DANGER)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.position = Vector2(-400, -140)
	_banner.custom_minimum_size = Vector2(800, 0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.visible = false
	add_child(_banner)


func _on_started(hunt: HuntDefinition, _duration: float) -> void:
	_box.visible = true
	var who := hunt.full_name() if hunt else "Unknown beast"
	_target.text = "Hunt: %s%s" % [who, "  (debug timer)" if _manager.is_debug_duration else ""]
	_show_banner("Reach the arena before the trail goes cold", 3.5, UiStyle.BONE)


func _on_arena(_remaining: float) -> void:
	_box.visible = false
	var who := _manager.hunt.beast_name if _manager.hunt else "the beast"
	_show_banner("The arena of %s\nThe hunt has no time limit" % who, 4.0, UiStyle.DANGER)


func _on_expired() -> void:
	_box.visible = false


func _show_banner(text: String, seconds: float, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner_timer = seconds
	_banner.visible = true
