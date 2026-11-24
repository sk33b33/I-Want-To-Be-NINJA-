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
var _objective: Label
var _arrow: Label
var _toast: Label
var _toast_t: float = 0.0
var _lore: PanelContainer
var _lore_title: Label
var _lore_text: Label
var _lore_t: float = 0.0


func _ready() -> void:
	add_to_group("lore_display")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_manager = get_node_or_null(manager_path) as ExpeditionManager
	if _manager:
		_manager.expedition_started.connect(_on_started)
		_manager.boss_arena_entered.connect(_on_arena)
		_manager.timer_expired.connect(_on_expired)
		_manager.pause_changed.connect(func(p: bool) -> void: _status.text = "PAUSED" if p else "")
		_manager.item_collected.connect(func(item: ItemDefinition, n: int) -> void:
			_toast.text = "+%d %s" % [n, item.display_name]
			_toast.add_theme_color_override("font_color", item.color.lightened(0.3))
			_toast_t = 2.5)
		_manager.secret_found.connect(_on_secret_found)
		if _manager.timer.is_active():
			_on_started(_manager.hunt, _manager.timer.duration)


func _process(delta: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer -= delta
		_banner.modulate.a = clampf(_banner_timer, 0.0, 1.0)
		_banner.visible = _banner_timer > 0.0
	_toast_t = maxf(_toast_t - delta, 0.0)
	_toast.modulate.a = clampf(_toast_t, 0.0, 1.0)
	if _lore_t > 0.0:
		_lore_t -= delta
		_lore.modulate.a = clampf(_lore_t, 0.0, 1.0)
		_lore.visible = _lore_t > 0.0
	if _manager == null or not _box.visible:
		return
	_update_objective()
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


## Show a lore tablet's text (called by LoreStone through the "lore_display" group).
func show_lore(title: String, text: String) -> void:
	_lore_title.text = title
	_lore_text.text = text
	_lore.visible = true
	_lore.modulate.a = 1.0
	_lore_t = 7.0


func objective_text() -> String:
	return _objective.text


func _update_objective() -> void:
	var target := _manager.objective
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if target == null or player == null:
		_objective.text = ""
		_arrow.text = ""
		return
	var to := target.global_position - player.global_position
	to.y = 0.0
	_objective.text = "Arena  %d m" % int(round(to.length()))
	# Arrow relative to the camera: up = straight ahead on screen.
	var cam_fwd := -player.get_camera_basis().z
	var angle := atan2(cam_fwd.x * to.z - cam_fwd.z * to.x, cam_fwd.x * to.x + cam_fwd.z * to.z)
	_arrow.text = "▲"
	_arrow.pivot_offset = _arrow.size * 0.5
	_arrow.rotation = angle


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
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(row)
	_arrow = UiStyle.label("▲", 20, UiStyle.SPIRIT)
	_arrow.custom_minimum_size = Vector2(26, 26)
	_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_arrow.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_arrow)
	_objective = UiStyle.label("", 18, UiStyle.SPIRIT)
	_objective.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_objective)
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
	_toast = UiStyle.label("", 24, UiStyle.BONE)
	_toast.set_anchors_preset(Control.PRESET_CENTER)
	_toast.position = Vector2(-300, -40)  # Above the lore panel and below the banners.
	_toast.custom_minimum_size = Vector2(600, 0)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	add_child(_toast)
	_lore = UiStyle.panel(Color(0.03, 0.04, 0.045, 0.82), Color(0.6, 0.55, 0.4, 0.4))
	_lore.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_lore.position = Vector2(-330, -250)
	_lore.custom_minimum_size = Vector2(660, 0)
	_lore.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lcol := VBoxContainer.new()
	_lore.add_child(lcol)
	_lore_title = UiStyle.label("", 22, Color(0.85, 0.75, 0.5))
	lcol.add_child(_lore_title)
	_lore_text = UiStyle.label("", 18, UiStyle.BONE)
	lcol.add_child(_lore_text)
	_lore.visible = false
	add_child(_lore)


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


## Phase 13 secrets: "Spirit shrine found (2/3)", then the jungle's blessing when it completes.
func _on_secret_found(secret: SecretDefinition, completed: bool) -> void:
	var set_data := _manager.find_secret_set(secret.id)
	var profile := PlayerProfile.load_profile()
	if completed and set_data:
		_show_banner("%s\nAll spirit shrines found: +%d max health" % [set_data.blessing_name, int(set_data.blessing_health)], 5.0, Color(0.7, 1.0, 0.95))
	else:
		var n := set_data.found_count(profile) if set_data else 1
		var total := set_data.secrets.size() if set_data else 1
		_show_banner("Spirit shrine found: %s (%d/%d)" % [secret.display_name, n, total], 3.5, Color(0.6, 0.95, 1.0))
	_toast.text = "+1 Spirit Relic"
	_toast.add_theme_color_override("font_color", Color(0.7, 1.0, 1.0))
	_toast_t = 2.5


func _show_banner(text: String, seconds: float, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner_timer = seconds
	_banner.visible = true
