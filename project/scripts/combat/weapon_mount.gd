class_name WeaponMount
extends Node
## Attaches the ninja's twin blades to the Mixamo hand bones at runtime (nodes added inside an
## imported model are not saved with the scene, so they are created here instead).
## Also builds the sheathed pair at the left hip and shows one pair or the other, following
## PlayerCombat.sword_state_changed (draw / sheathe).

@export var skeleton_path: NodePath = ^"../Visual/NinjaModel/Armature/Skeleton3D"
@export var blade_material: Material
@export var hand_bones: PackedStringArray = PackedStringArray(["mixamorig_RightHand", "mixamorig_LeftHand"])
## Blade placement in hand-bone space (bone units are centimetres: the armature is scaled 0.01).
@export var grip_offset: Vector3 = Vector3(0, 8, 2)
@export var grip_rotation_degrees: Vector3 = Vector3(-90, 0, 0)

## Sheath placement in the player's own frame (the "Visual" node: forward = -Z, left = -X, up = +Y;
## metres from the feet): at the left hip, handles forward, blades sloping down and back.
## Calibrated against the standing pose, then carried by the hip bone (it sways with the hips).
@export var sheath_bone: String = "mixamorig_Hips"
@export var sheath_position: Vector3 = Vector3(-0.21, 0.9, -0.06)
@export var sheath_direction: Vector3 = Vector3(-0.12, -0.5, 0.86)
@export var visual_path: NodePath = ^"../Visual"
@export var combat_path: NodePath = ^"../Combat"

var blades: Array[MeshInstance3D] = []
## The pair worn at the hip while sheathed.
var sheathed_blades: Array[MeshInstance3D] = []
var sheathed: bool = false


func _ready() -> void:
	var skeleton := get_node_or_null(skeleton_path) as Skeleton3D
	if skeleton == null:
		push_warning("WeaponMount: skeleton not found")
		return
	var mesh := ProceduralMeshes.ninja_blade(blade_material)
	for bone in hand_bones:
		var att := BoneAttachment3D.new()
		att.name = bone.trim_prefix("mixamorig_") + "Attachment"
		att.bone_name = bone
		skeleton.add_child(att)
		var blade := MeshInstance3D.new()
		blade.name = "Blade"
		blade.mesh = mesh
		blade.scale = Vector3.ONE * 100.0  # Undo the armature's 0.01 scale.
		blade.position = grip_offset
		blade.rotation_degrees = grip_rotation_degrees
		att.add_child(blade)
		blades.append(blade)
	_build_sheath(skeleton, mesh)
	_hook_combat.call_deferred()


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
	# Wait for the animator to pose the model (Idle), then place the sheath.
	await get_tree().process_frame
	await get_tree().process_frame
	_calibrate_sheath()
	var combat := get_node_or_null(combat_path) as PlayerCombat
	if combat == null:
		return
	combat.sword_state_changed.connect(func(drawn: bool) -> void: set_sheathed(not drawn))
	set_sheathed(not combat.sword_drawn)


## Show the blades in hand (false) or at the hip (true).
func set_sheathed(value: bool) -> void:
	sheathed = value
	for b in blades:
		b.visible = not value
	for b in sheathed_blades:
		b.visible = value


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
