class_name BossHud
extends Control
## Boss health bar (top centre, where the expedition timer was), part status, enrage notice and
## the "part broken / reward" banner. Listens to ExpeditionManager and the boss only.

@export var manager_path: NodePath

var _manager: ExpeditionManager
var _boss: Kurogale
var _box: VBoxContainer
var _name: Label
var _bar: ProgressBar
var _parts: Label
var _banner: Label
var _banner_t: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_manager = get_node_or_null(manager_path) as ExpeditionManager
	if _manager == null or _manager.boss == null:
		return
	_boss = _manager.boss
	_boss.awakened.connect(func() -> void: _box.visible = true; _refresh())
	_boss.enraged.connect(func() -> void: _show_banner("%s is enraged!" % _boss.definition.display_name, UiStyle.DANGER))
	_boss.get_health().changed.connect(func(_c: float, _m: float) -> void: _refresh())
	_manager.part_reward_granted.connect(_on_part_reward)
	_manager.hunt_completed.connect(func() -> void:
		_box.visible = false
		_show_banner("Hunt complete!", UiStyle.SPIRIT))


func _process(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		_banner.modulate.a = clampf(_banner_t, 0.0, 1.0)
		_banner.visible = _banner_t > 0.0


func is_bar_visible() -> bool:
	return _box.visible


func _refresh() -> void:
	var h := _boss.get_health()
	_bar.max_value = h.max_health
	_bar.value = h.current
	var lines: PackedStringArray = []
	for part in _boss.definition.parts:
		lines.append("%s: %s" % [part.display_name, "BROKEN" if _boss.is_part_broken(part.id) else "intact"])
	_parts.text = "   ".join(lines)


func _on_part_reward(part: BossPartDefinition, item: ItemDefinition, count: int) -> void:
	_refresh()
	var reward := " — +%d %s" % [count, item.display_name] if item else ""
	_show_banner("%s broken!%s" % [part.display_name, reward], UiStyle.WARNING)


func _show_banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner_t = 3.5
	_banner.visible = true


func _build() -> void:
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_box.position = Vector2(-260, 12)
	_box.custom_minimum_size = Vector2(520, 0)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_name = UiStyle.label("Kurogale, the Thornback Stag", 22)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_name)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(520, 16)
	_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.03, 0.03, 0.8)
	bg.border_color = Color(1, 1, 1, 0.3)
	bg.set_border_width_all(2)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.7, 0.85, 0.3)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fg)
	_box.add_child(_bar)
	_parts = UiStyle.label("", 16, UiStyle.MUTED)
	_parts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_parts)
	_box.visible = false
	_banner = UiStyle.label("", 30, UiStyle.WARNING)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.position = Vector2(-400, -170)
	_banner.custom_minimum_size = Vector2(800, 0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.visible = false
	add_child(_banner)
