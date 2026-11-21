extends Label
## Prototype HUD: shows the build phase, camera mode, FPS and a controls hint.
## Listens to CameraRig.mode_changed; it never drives gameplay.

@export var camera_rig_path: NodePath

var _mode_text: String = "Third-person"


func _ready() -> void:
	var rig := get_node_or_null(camera_rig_path) as CameraRig
	if rig:
		rig.mode_changed.connect(_on_mode_changed)


func _process(_delta: float) -> void:
	text = "I want to be NINJA - Phase 1 prototype (Verdant Canopy, placeholder art)\nCamera: %s   FPS: %d\n%s" % [
		_mode_text, Engine.get_frames_per_second(), _hint()]


func _on_mode_changed(mode: CameraRig.Mode) -> void:
	_mode_text = "Top-down" if mode == CameraRig.Mode.TOP_DOWN else "Third-person"


func _hint() -> String:
	if DisplayServer.is_touchscreen_available() or Input.emulate_touch_from_mouse:
		return "Left: move   Right: drag to look   JUMP / DASH / CAM"
	return "WASD move  Mouse look (click)  Space jump  Shift dash  V camera  Esc free mouse"
