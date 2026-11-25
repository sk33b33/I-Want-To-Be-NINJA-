class_name PlayerHud
extends Control
## Player health bar (top left: green, with red showing only the health just lost, which drains
## away after a moment), a stamina bar under it (sprint drains it), red screen flash when hurt, and
## a "Defeated" message while waiting to respawn. Listens to the player's HealthComponent /
## PlayerCombat / PlayerController only.

@export var player_path: NodePath

var _combat: PlayerCombat
var _health: HealthComponent
var _bar: ProgressBar
var _trail: ProgressBar
var _trail_hold: float = 0.0
var _stamina_bar: ProgressBar
var _player: PlayerController
var _flash: ColorRect
var _lock: Label
var _down: Label
var _skill: Label
var _gear: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	var player := get_node_or_null(player_path) as PlayerController
	if player == null or player.combat == null:
		return
	_player = player
	_stamina_bar.max_value = player.config.stamina_max
	_stamina_bar.value = player.stamina
	player.stamina_changed.connect(func(cur: float, maximum: float) -> void:
		_stamina_bar.max_value = maximum
		_stamina_bar.value = cur)
	_combat = player.combat
	_health = _combat.health
	_health.changed.connect(_on_health_changed)
	_combat.hurt.connect(func(_i: DamageInfo) -> void: _flash.color.a = 0.35)
	_combat.player_died.connect(func() -> void: _down.visible = true)
	_combat.player_respawned.connect(func() -> void: _down.visible = false)
	_combat.lock_target_changed.connect(func(t: Node3D) -> void: _lock.visible = t != null)
	_skill.visible = _combat.config.skill != null
	var names: PackedStringArray = []
	for g in _combat.equipped_gear:
		names.append(g.display_name)
	_gear.text = " · ".join(names)
	_gear.visible = not names.is_empty()
	_on_health_changed(_health.current, _health.max_health)


## The talisman is named and coloured after its element, so a charm swap is visible at a glance.
const TALISMAN_NAMES := {&"fire": "Ember Talisman", &"water": "Mist Talisman", &"lightning": "Storm Talisman", &"earth": "Stone Talisman"}
const TALISMAN_COLORS := {&"fire": Color(1.0, 0.6, 0.2), &"water": Color(0.45, 0.75, 1.0), &"lightning": Color(0.8, 0.85, 1.0), &"earth": Color(0.9, 0.7, 0.4)}


## Current talisman line (for tests and accessibility checks).
func skill_text() -> String:
	return _skill.text


func _process(delta: float) -> void:
	_flash.color.a = maxf(_flash.color.a - delta * 1.2, 0.0)
	# The red "just lost" part waits a moment, then drains down to the green bar.
	_trail_hold = maxf(_trail_hold - delta, 0.0)
	if _trail_hold <= 0.0:
		_trail.value = move_toward(_trail.value, _bar.value, delta * 40.0)
	# Red only exists while there is lost health to show (no red fringe around a full green bar).
	var fill := _trail.get_theme_stylebox("fill") as StyleBoxFlat
	var want := 1.0 if _trail.value > _bar.value + 0.01 else 0.0
	if fill and not is_equal_approx(fill.bg_color.a, want):
		fill.bg_color.a = want
	if _player:
		# An empty stamina bar blinks pale until sprint is allowed again.
		var tired := _player.is_exhausted()
		_stamina_bar.modulate = Color(1, 1, 1, 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.012)) if tired else Color.WHITE
	if _combat and _skill.visible:
		var left := _combat.skill_cooldown_left
		var element := _combat.skill_element()
		var title: String = TALISMAN_NAMES.get(element, "Talisman")
		_skill.text = "%s: ready" % title if left <= 0.0 else "%s: %.1fs" % [title, left]
		_skill.add_theme_color_override("font_color", TALISMAN_COLORS.get(element, Color(1.0, 0.6, 0.2)) if left <= 0.0 else UiStyle.MUTED)


const TRAIL_HOLD := 0.6  # Seconds the red "lost health" stays before draining.


## For tests: the health bar's colour, whether red (lost health) is on screen, the stamina shown.
func health_colour() -> Color:
	return (_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color


func red_showing() -> bool:
	return (_trail.get_theme_stylebox("fill") as StyleBoxFlat).bg_color.a > 0.5 and _trail.value > _bar.value + 0.01


func shown_stamina() -> float:
	return _stamina_bar.value


func shown_health() -> float:
	return _bar.value


func _on_health_changed(current: float, maximum: float) -> void:
	_bar.max_value = maximum
	_trail.max_value = maximum
	if current < _bar.value:
		_trail_hold = TRAIL_HOLD  # Damage: show the lost health in red for a moment.
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
	# Dark bar at the back, red "just lost" behind the green health: red only shows after damage.
	_trail = _make_bar(Color(0.85, 0.1, 0.08), true)
	stack.add_child(_trail)
	_bar = _make_bar(Color(0.2, 0.75, 0.25), false)
	stack.add_child(_bar)
	var stamina_stack := Control.new()
	stamina_stack.custom_minimum_size = Vector2(300, 10)
	box.add_child(stamina_stack)
	_stamina_bar = _make_bar(Color(0.95, 0.78, 0.25), true)
	_stamina_bar.show_percentage = false
	stamina_stack.add_child(_stamina_bar)
	_lock = UiStyle.label("LOCKED ON", 16, Color(1.0, 0.45, 0.3))
	_lock.visible = false
	box.add_child(_lock)
	_skill = UiStyle.label("", 16, Color(1.0, 0.6, 0.2))
	_skill.visible = false
	box.add_child(_skill)
	_gear = UiStyle.label("", 14, UiStyle.MUTED)
	_gear.visible = false
	box.add_child(_gear)
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
