class_name WeaponMount
extends Node
## Attaches the ninja's twin blades to the Mixamo hand bones at runtime (nodes added inside an
## imported model are not saved with the scene, so they are created here instead).
## Also builds the sheathed pair at the left hip and shows one pair or the other, following
## PlayerCombat.sword_state_changed (draw / sheathe).

@export var skeleton_path: NodePath = ^"../Visual/NinjaModel/Armature/Skeleton3D"
@export var blade_material: Material
@export var hand_bones: PackedStringArray = PackedStringArray(["mixamorig_RightHand", "mixamorig_LeftHand"])
## The fist: finger pose copied from this clip/time (a clip animated holding weapons).
@export var grip_pose_clip: StringName = &"Dual_Weapon_Combo"
@export var grip_pose_time: float = 0.1
@export var anim_player_path: NodePath = ^"../Visual/NinjaModel/AnimationPlayer"
## Where along the blade mesh (its +Y, metres) the fist closes: the middle of the handle.
@export var handle_centre: float = -0.02
## Slash trails (one per hand blade).
@export var trail_config: TrailConfig = preload("res://data/combat/blade_trail.tres")

var trails: Array[WeaponTrail] = []
## Equipped weapon type (set_weapon_type); null = katana.
var weapon_type: WeaponType

## Sheath placement in the player's own frame (the "Visual" node: forward = -Z, left = -X, up = +Y;
## metres from the feet): at the left hip, handles forward, blades sloping down and back.
## Calibrated against the standing pose, then carried by the hip bone (it sways with the hips).
@export var sheath_bone: String = "mixamorig_Hips"
@export var sheath_position: Vector3 = Vector3(-0.21, 0.9, -0.06)
@export var sheath_direction: Vector3 = Vector3(-0.12, -0.5, 0.86)
@export var visual_path: NodePath = ^"../Visual"
@export var combat_path: NodePath = ^"../Combat"

var blades: Array[MeshInstance3D] = []
var grip: HandGrip
## The pair worn at the hip while sheathed.
var sheathed_blades: Array[MeshInstance3D] = []
var sheathed: bool = false


func _ready() -> void:
	var skeleton := get_node_or_null(skeleton_path) as Skeleton3D
	if skeleton == null:
		push_warning("WeaponMount: skeleton not found")
		return
	var mesh := ProceduralMeshes.ninja_blade(blade_material)
	# The fist first: the grip is computed from the closed fingers (baked into the clips later).
	grip = HandGrip.new()
	grip.capture(skeleton, get_node_or_null(anim_player_path) as AnimationPlayer, grip_pose_clip, grip_pose_time)
	for bone in hand_bones:
		var att := BoneAttachment3D.new()
		att.name = bone.trim_prefix("mixamorig_") + "Attachment"
		att.bone_name = bone
		skeleton.add_child(att)
		var blade := MeshInstance3D.new()
		blade.name = "Blade"
		blade.mesh = mesh
		att.add_child(blade)
		blade.transform = grip_transform(skeleton, bone)
		blades.append(blade)
	_build_sheath(skeleton, mesh)
	_hook_combat.call_deferred()


## Blade placement in hand-bone space, from the hand's own bones in the fist pose (so the
## mirrored left hand is right too): the handle runs across the knuckles (pinky -> index) through
## the centre of the closed fingers, the blade leaves the fist on the thumb side, its edge faces
## the way the fingers point.
func grip_transform(skeleton: Skeleton3D, hand: String) -> Transform3D:
	var side := hand.trim_prefix("mixamorig_").trim_suffix("Hand")  # "Right" / "Left"
	var knuckles := {}
	var centre := Vector3.ZERO
	for f in ["Index", "Middle", "Ring", "Pinky"]:
		var chain := _finger_chain(skeleton, "mixamorig_%sHand%s" % [side, f])
		knuckles[f] = chain[0]
		centre += chain[0] + chain[2]
	centre /= 8.0
	var across: Vector3 = (knuckles["Index"] - knuckles["Pinky"]).normalized()
	var fingers: Vector3 = ((knuckles["Index"] + knuckles["Pinky"]) * 0.5).normalized()
	var edge := (fingers - across * fingers.dot(across)).normalized()
	var basis := Basis(across.cross(edge).normalized(), across, edge)
	var s := 100.0  # Hand-bone space is in centimetres (armature scale 0.01); the mesh is in metres.
	return Transform3D(basis.scaled(Vector3.ONE * s), centre - across * handle_centre * s)


## Joint positions (hand-bone space) of finger bones 1..3 with the fist rotations applied.
func _finger_chain(skeleton: Skeleton3D, prefix: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var t := Transform3D.IDENTITY
	for n in 3:
		var b := skeleton.find_bone("%s%d" % [prefix, n + 1])
		if b < 0:
			out.append(t.origin)
			continue
		var rest := skeleton.get_bone_rest(b)
		var rot: Quaternion = grip.fist.get(b, rest.basis.get_rotation_quaternion()) if grip else rest.basis.get_rotation_quaternion()
		t = t * Transform3D(Basis(rot), rest.origin)
		out.append(t.origin)
	return out


## Two blades in the hip sheath (placed by _calibrate_sheath once the model is posed).
func _build_sheath(skeleton: Skeleton3D, mesh: Mesh) -> void:
	if skeleton.find_bone(sheath_bone) < 0:
		return
	var att := BoneAttachment3D.new()
	att.name = "SheathAttachment"
	att.bone_name = sheath_bone
	skeleton.add_child(att)
	for i in 2:
		var b := MeshInstance3D.new()
		b.name = "SheathedBlade%d" % i
		b.mesh = mesh
		b.visible = false
		att.add_child(b)
		sheathed_blades.append(b)


## Place the sheathed pair from player-frame numbers, using the hip bone's current (standing)
## pose — the bone's rest pose is rotated differently from how the ninja actually stands.
func _calibrate_sheath() -> void:
	var visual := get_node_or_null(visual_path) as Node3D
	if visual == null or sheathed_blades.is_empty():
		return
	var att := sheathed_blades[0].get_parent() as Node3D
	var tip := sheath_direction.normalized()
	var side := tip.cross(Vector3.UP).normalized()
	var basis := Basis(side, tip, side.cross(tip).normalized())  # Blade +Y = towards the tip.
	for i in sheathed_blades.size():
		var origin := sheath_position + Vector3(-0.03 * i, 0.02 * i, 0.04 * i) - tip * 0.06
		var world := visual.global_transform * Transform3D(basis, origin)
		var local := att.global_transform.affine_inverse() * world
		sheathed_blades[i].transform = local


func _hook_combat() -> void:
	# Bake the fist into every clip once the animator has built its Idle pose, then wait for the
	# model to be posed (Idle) and place the sheath.
	await get_tree().process_frame
	grip.bake(get_node_or_null(anim_player_path) as AnimationPlayer)
	await get_tree().process_frame
	_calibrate_sheath()
	var combat := get_node_or_null(combat_path) as PlayerCombat
	if combat == null:
		return
	for blade in blades:
		var trail := WeaponTrail.new()
		trail.name = "Trail" + blade.get_parent().name
		add_child(trail)
		trail.setup(blade, combat, trail_config)
		_fit_trail(trail)
		trails.append(trail)
	combat.sword_state_changed.connect(func(drawn: bool) -> void: set_sheathed(not drawn))
	set_sheathed(not combat.sword_drawn)


## Show the blades in hand (false) or at the hip (true).
func set_sheathed(value: bool) -> void:
	sheathed = value
	for b in blades:
		b.visible = not value
	for b in sheathed_blades:
		b.visible = value


## Swap both hand blades and the sheathed pair to a weapon type's blade shape, and move the
## slash trails to its length (GearLoadout, once at expedition start). null = katana.
func set_weapon_type(type: WeaponType) -> void:
	weapon_type = type
	var builder := type.blade_mesh if type else &"ninja_blade"
	var mesh: Mesh = ProceduralMeshes.new().call(builder, blade_material)
	for b in blades + sheathed_blades:
		b.mesh = mesh
	for t in trails:
		_fit_trail(t)
	CrashReport.note("weapon: %s" % (type.id if type else &"katana"))


## The trails are made a few frames after the mount (after the fist is baked), which is AFTER
## the loadout equips the weapon at expedition start — so each new trail fits itself here too.
func _fit_trail(t: WeaponTrail) -> void:
	t.base_override = weapon_type.trail_base if weapon_type else -1.0
	t.tip_override = weapon_type.trail_tip if weapon_type else -1.0


## Recolour the blades (forged weapons). Multiplies the blade's vertex colours.
func set_tint(color: Color) -> void:
	for blade in blades + sheathed_blades:
		var mat := (blade_material as StandardMaterial3D).duplicate() as StandardMaterial3D
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color * 0.25
		blade.material_override = mat


func current_tint() -> Color:
	if blades.is_empty() or blades[0].material_override == null:
		return Color(1, 1, 1)
	return (blades[0].material_override as StandardMaterial3D).albedo_color
