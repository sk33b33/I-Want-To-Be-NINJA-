class_name CameraRigConfig
extends Resource
## Tunable camera values for third-person and top-down modes (docs/GAME_DESIGN.md "Camera").
## Edit `res://data/camera/default_camera.tres` to tune.

@export_group("Framing")
## Height above the player's feet that the camera orbits around.
@export var pivot_height: float = 1.5
## Vertical field of view in degrees.
@export var fov: float = 70.0

@export_group("Third person")
@export var tp_distance: float = 5.0
@export var tp_default_pitch_deg: float = -15.0
@export var tp_min_pitch_deg: float = -70.0
@export var tp_max_pitch_deg: float = 35.0

@export_group("Top down")
@export var td_distance: float = 16.0
@export var td_min_distance: float = 8.0
@export var td_max_distance: float = 28.0
@export var td_pitch_deg: float = -62.0
## Distance change per mouse-wheel notch in top-down mode.
@export var td_zoom_step: float = 1.5

@export_group("Input")
## Radians per pixel of mouse motion.
@export var mouse_sensitivity: float = 0.0025
## Radians per pixel of touch drag.
@export var touch_sensitivity: float = 0.006
## Right-stick turn rate in degrees per second at full deflection.
@export var stick_speed_deg: float = 180.0
@export var invert_y: bool = false

@export_group("Smoothing")
## How tightly the rig follows the player (higher = tighter).
@export var follow_sharpness: float = 14.0
## How quickly pitch/distance blend when switching modes.
@export var mode_blend_sharpness: float = 6.0
## Gap the spring arm keeps from walls it collides with.
@export var collision_margin: float = 0.3
