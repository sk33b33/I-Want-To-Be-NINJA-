class_name HandGrip
extends SkeletonModifier3D
## Closes the ninja's hands around the blades (owner playtest fix). The run/jump/climb clips were
## made without weapons, so their fingers are open. While active, this copies the finger pose of
## a clip that does hold weapons (Dual_Weapon_Combo: fingers ~70° curled) onto every finger bone
## of both hands, on top of whatever animation is playing. WeaponMount turns it on while the
## blades are drawn and off when they are sheathed.

## bone index -> Quaternion (the fist pose).
var fist: Dictionary = {}


## Sample the finger rotations of `clip` at `time` (bone tracks "<skeleton path>:<bone>").
func capture(anim_player: AnimationPlayer, clip: StringName, time: float) -> void:
	fist.clear()
	var sk := get_skeleton()
	if sk == null or anim_player == null or not anim_player.has_animation(clip):
		return
	var a := anim_player.get_animation(clip)
	for i in a.get_track_count():
		if a.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		var bone_name := String(a.track_get_path(i).get_concatenated_subnames())
		if not HandGrip.is_finger(bone_name):
			continue
		var b := sk.find_bone(bone_name)
		if b >= 0:
			fist[b] = a.rotation_track_interpolate(i, time)


static func is_finger(bone_name: String) -> bool:
	if not "Hand" in bone_name:
		return false
	for f in ["Thumb", "Index", "Middle", "Ring", "Pinky"]:
		if f in bone_name:
			return true
	return false


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for b: int in fist:
		sk.set_bone_pose_rotation(b, fist[b])
