class_name RainFX
extends CPUParticles3D
## Rain that follows the active camera (Stormcrag). CPU particles so it runs on the
## gl_compatibility renderer; fewer drops on the phone tier.

@export var amount_high: int = 1400
@export var amount_low: int = 300
@export var height: float = 9.0


func _ready() -> void:
	add_to_group("rain_fx")
	amount = amount_low if QualityProfile.is_low() else amount_high
	local_coords = false
	emitting = true


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_position = cam.global_position + Vector3.UP * height
