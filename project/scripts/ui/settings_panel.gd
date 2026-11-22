class_name SettingsPanel
extends VBoxContainer
## Player settings (Phase 11): graphics preset, volumes, comfort and readability options.
## Used by the dojo's Settings tab and the pause menu. Every change is saved at once
## (GameSettings, user://settings.cfg). Graphics changes apply from the next expedition.

signal benchmark_requested

var quality_button: Button
var difficulty_button: Button
var touch_slider: HSlider
var shake_button: Button
var warnings_button: Button
var sliders: Dictionary = {}  # bus name -> HSlider
var benchmark_button: Button
var _show_benchmark: bool = false


func _init(show_benchmark: bool = false) -> void:
	_show_benchmark = show_benchmark


func _ready() -> void:
	GameSettings.ensure_loaded()
	add_theme_constant_override("separation", 10)
	quality_button = UiStyle.button("")
	quality_button.pressed.connect(cycle_quality)
	add_child(quality_button)
	difficulty_button = UiStyle.button("")
	difficulty_button.pressed.connect(cycle_difficulty)
	add_child(difficulty_button)
	add_child(UiStyle.label("Graphics and difficulty changes apply when the next expedition starts. The 45:00 countdown is the same on every difficulty.", 15, UiStyle.MUTED))
	for bus in ["Master", "Music", "SFX"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := UiStyle.label("%s volume" % ("Sound effects" if bus == "SFX" else bus), 18)
		l.custom_minimum_size.x = 200
		row.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.custom_minimum_size = Vector2(260, 44)  # Big enough for a thumb.
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.value = _volume(bus)
		s.value_changed.connect(func(v: float) -> void: GameSettings.set_volume(bus, v))
		row.add_child(s)
		sliders[bus] = s
		add_child(row)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 12)
	var tl := UiStyle.label("Touch button size", 18)
	tl.custom_minimum_size.x = 200
	trow.add_child(tl)
	touch_slider = HSlider.new()
	touch_slider.min_value = 0.8
	touch_slider.max_value = 1.4
	touch_slider.step = 0.05
	touch_slider.custom_minimum_size = Vector2(260, 44)
	touch_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	touch_slider.value = GameSettings.touch_scale
	touch_slider.value_changed.connect(func(v: float) -> void: GameSettings.set_touch_scale(v))
	trow.add_child(touch_slider)
	add_child(trow)
	shake_button = UiStyle.button("")
	shake_button.pressed.connect(func() -> void:
		GameSettings.set_screen_shake(not GameSettings.screen_shake)
		refresh())
	add_child(shake_button)
	warnings_button = UiStyle.button("")
	warnings_button.pressed.connect(func() -> void:
		GameSettings.set_bold_warnings(not GameSettings.bold_warnings)
		refresh())
	add_child(warnings_button)
	if _show_benchmark:
		benchmark_button = UiStyle.button("Run benchmark (about 1 minute)", UiStyle.WARNING)
		benchmark_button.pressed.connect(func() -> void: benchmark_requested.emit())
		add_child(benchmark_button)
	refresh()


func cycle_quality() -> void:
	var order := ["auto", "low", "medium", "high"]
	var i := order.find(GameSettings.get_quality())
	GameSettings.set_quality(order[(i + 1) % order.size()])
	refresh()


func cycle_difficulty() -> void:
	var order := ["easy", "normal", "hard"]
	var i := order.find(GameSettings.difficulty)
	GameSettings.set_difficulty(order[(i + 1) % order.size()])
	refresh()


func refresh() -> void:
	var d := GameSettings.difficulty_preset()
	difficulty_button.text = "Difficulty: %s — %s" % [d.display_name, d.description]
	var q := GameSettings.get_quality()
	var label := "Auto (%s)" % String(QualityProfile.auto_tier()).capitalize() if q == "auto" else q.capitalize()
	quality_button.text = "Graphics: %s" % label
	shake_button.text = "Screen shake: %s" % ("On" if GameSettings.screen_shake else "Off")
	warnings_button.text = "Bold attack warnings: %s" % ("On" if GameSettings.bold_warnings else "Off")


static func _volume(bus: String) -> float:
	match bus:
		"Master": return GameSettings.master_volume
		"Music": return GameSettings.music_volume
	return GameSettings.sfx_volume
