class_name NinjaAnimationConfig
extends Resource
## Maps the ninja's Mixamo clips (assets/models/ninja/ninja.glb) to locomotion states.
## Clip times were measured from the hips curve of each clip.

@export_group("Clips")
@export var run_clip: StringName = &"Run"
@export var sprint_clip: StringName = &"Sprint"
@export var jump_clip: StringName = &"Jump"
## Played instead of `jump_clip` when jumping at sprint speed.
@export var sprint_jump_clip: StringName = &"Front_Flip"
## There is no idle clip in the GLB yet: an "Idle" pose is built from this clip at `idle_pose_time`.
## Export an Idle animation from Mixamo and set `idle_clip` to use it instead.
@export var idle_clip: StringName = &""
@export var idle_pose_clip: StringName = &"Jump"
@export var idle_pose_time: float = 0.0

@export_group("Traversal (Phase 2)")
## The GLB has no climbing clips yet; these are stand-ins. Add Mixamo "Climbing" /
## "Hanging Idle" / "Climbing To Top" clips to ninja.glb and put their names here.
@export var climb_clip: StringName = &"Crouch_Walk"
## Climb speed (m/s) at which climb_clip plays at 1x.
@export var climb_reference_speed: float = 2.4
@export var hang_clip: StringName = &"Jump"
@export var hang_pose_time: float = 0.62
@export var mantle_clip: StringName = &"Jump"
@export var mantle_start_time: float = 1.15

@export_group("Combat (Phase 4)")
## Attack clips/slices come from AttackDefinition resources; these cover the rest.
@export var roll_clip: StringName = &"Quick_Roll_To_Run"
## The roll part of Quick_Roll_To_Run ends here (the rest is the run-out).
@export var roll_end_time: float = 0.9
@export var hurt_clip: StringName = &"Death_Backward"
@export var hurt_end_time: float = 0.35
@export var death_clip: StringName = &"Death_Backward"
## Clips whose forward root motion is removed (the code moves the body instead).
@export var strip_forward_motion: Array[StringName] = [&"Dual_Weapon_Combo", &"Quick_Roll_To_Run", &"Death_Backward"]

@export_group("Jump timing (seconds into the clip)")
@export var jump_takeoff_time: float = 0.45
## While airborne the clip pauses here (tucked pose) until landing.
@export var jump_hold_time: float = 0.85
@export var jump_land_time: float = 1.25
@export var flip_takeoff_time: float = 0.45
@export var flip_end_time: float = 1.45

@export_group("Blending and speed")
@export var blend_time: float = 0.15
## Ground speed (m/s) at which Run plays at 1x. Faster/slower movement scales playback.
@export var run_reference_speed: float = 6.5
@export var sprint_reference_speed: float = 10.0
## Below this horizontal speed the ninja is considered idle.
@export var idle_speed_threshold: float = 0.4
## The hips of in-place Mixamo jumps still rise; clamp them to this height (m) so the physics
## jump is not doubled. Also removes forward root motion from the flip.
@export var max_hips_height: float = 0.95
@export var hips_bone_track: NodePath = ^"Armature/Skeleton3D:mixamorig_Hips"
