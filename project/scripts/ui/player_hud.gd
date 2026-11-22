class_name PlayerHud
extends Control
## Player health bar (top left), red screen flash when hurt, and a "Defeated" message while
## waiting to respawn. Listens to the player's HealthComponent / PlayerCombat only.

@export var player_path: NodePath

var _combat: PlayerCombat
var _health: HealthComponent
var _bar: ProgressBar
var _trail: ProgressBar
var _flash: ColorRect
var _lock: Label
var _down: Label
var _skill: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	var player := get_node_or_null(player_path) as PlayerController
	if player == null or player.combat == null:
		return
	_combat = player.combat
	_health = _combat.health
	_health.changed.connect(_on_health_changed)
	_combat.hurt.connect(func(_i: DamageInfo) -> void: _flash.color.a = 0.35)
	_combat.player_died.connect(func() -> void: _down.visible = true)
	_combat.player_respawned.connect(func() -> void: _down.visible = false)
	_combat.lock_target_changed.connect(func(t: Node3D) -> void: _lock.visible = t != null)
	_skill.visible = _combat.config.skill != null
	_on_health_changed(_health.current, _health.max_health)


func _process(delta: float) -> void:
	_flash.color.a = maxf(_flash.color.a - delta * 1.2, 0.0)
	# The pale "recent damage" trail catches up after a moment.
	_trail.value = move_toward(_trail.value, _bar.value, delta * 40.0)
	if _combat and _skill.visible:
		var left := _combat.skill_cooldown_left
		_skill.text = "Ember Talisman: ready" if left <= 0.0 else "Ember Talisman: %.1fs" % left
		_skill.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2) if left <= 0.0 else UiStyle.MUTED)


func shown_health() -> float:
	return _bar.value


func _on_health_changed(current: float, maximum: float) -> void:
	_bar.max_value = maximum
	_trail.max_value = maximum
	_bar.value = current
	if current > _trail.value:
		_trail.value = current


func _build() -> void:
	_flash = ColorRect.new()
	_flash.color = Color(0.7, 0.0, 0.0, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	var box := VBoxContainer.new()
	box.position = Vector2(20, 16)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(300, 18)
	box.add_child(stack)
	_trail = _make_bar(Color(0.9, 0.85, 0.75, 0.6), true)
	stack.add_child(_trail)
	_bar = _make_bar(Color(0.75, 0.12, 0.1), false)
	stack.add_child(_bar)
	_lock = UiStyle.label("LOCKED ON", 16, Color(1.0, 0.45, 0.3))
	_lock.visible = false
	box.add_child(_lock)
	_skill = UiStyle.label("", 16, Color(1.0, 0.6, 0.2))
	_skill.visible = false
	box.add_child(_skill)
	_down = UiStyle.label("Defeated — returning to the last shrine…", 30, UiStyle.DANGER)
	_down.set_anchors_preset(Control.PRESET_CENTER)
	_down.position = Vector2(-360, 60)
	_down.custom_minimum_size = Vector2(720, 0)
	_down.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_down.visible = false
	add_child(_down)


func _make_bar(fill: Color, background: bool) -> ProgressBar:
	var b := ProgressBar.new()
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.03, 0.03, 0.75) if background else Color(0, 0, 0, 0)
	bg.border_color = Color(1, 1, 1, 0.25) if background else Color(0, 0, 0, 0)
	bg.set_border_width_all(2 if background else 0)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b
