class_name HandGrip
extends RefCounted
## Closes the ninja's hands around the blades (owner playtest fix). The run/jump/climb clips were
## made without weapons, so their fingers are open. The finger pose of a clip that does hold
## weapons (Dual_Weapon_Combo: fingers ~70° curled) is captured and BAKED into every other clip's
## finger tracks once, at load — nothing touches the skeleton at runtime.
## (The first version was a SkeletonModifier3D rewriting 30 finger bones every frame; the Godot app
## crashed on the owner's Android phone a few seconds into an expedition after it was added.)

## Clips that already animate their own hands (weapon clips): left as they are.
const KEEP_OWN_HANDS: Array[StringName] = [&"Dual_Weapon_Combo", &"Draw_Sword", &"Sheath_Sword"]

## bone index -> Quaternion (the fist pose), and bone index -> track path.
var fist: Dictionary = {}
var paths: Dictionary = {}


## Sample the finger rotations of `clip` at `time` (bone tracks "<skeleton path>:<bone>").
func capture(skeleton: Skeleton3D, anim_player: AnimationPlayer, clip: StringName, time: float) -> void:
	fist.clear()
	paths.clear()
	if skeleton == null or anim_player == null or not anim_player.has_animation(clip):
		return
	var a := anim_player.get_animation(clip)
	for i in a.get_track_count():
		if a.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		var bone_name := String(a.track_get_path(i).get_concatenated_subnames())
		if not HandGrip.is_finger(bone_name):
			continue
		var b := skeleton.find_bone(bone_name)
		if b >= 0:
			fist[b] = a.rotation_track_interpolate(i, time)
			paths[b] = a.track_get_path(i)


static func is_finger(bone_name: String) -> bool:
	if not "Hand" in bone_name:
		return false
	for f in ["Thumb", "Index", "Middle", "Ring", "Pinky"]:
		if f in bone_name:
			return true
	return false


## Write the fist into every clip's finger tracks (except the weapon clips). Idempotent.
func bake(anim_player: AnimationPlayer) -> int:
	var changed := 0
	if anim_player == null or fist.is_empty():
		return 0
	for clip in anim_player.get_animation_list():
		if KEEP_OWN_HANDS.has(StringName(clip)):
			continue
		var a := anim_player.get_animation(clip)
		for b: int in fist:
			var path: NodePath = paths[b]
			var t := a.find_track(path, Animation.TYPE_ROTATION_3D)
			if t < 0:
				t = a.add_track(Animation.TYPE_ROTATION_3D)
				a.track_set_path(t, path)
			for k in range(a.track_get_key_count(t) - 1, -1, -1):
				a.track_remove_key(t, k)
			a.rotation_track_insert_key(t, 0.0, fist[b])
		changed += 1
	return changed
