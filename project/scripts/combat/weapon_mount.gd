class_name WeaponMount
extends Node
## Attaches the ninja's twin blades to the Mixamo hand bones at runtime (nodes added inside an
## imported model are not saved with the scene, so they are created here instead).

@export var skeleton_path: NodePath = ^"../Visual/NinjaModel/Armature/Skeleton3D"
@export var blade_material: Material
@export var hand_bones: PackedStringArray = PackedStringArray(["mixamorig_RightHand", "mixamorig_LeftHand"])
## Blade placement in hand-bone space (bone units are centimetres: the armature is scaled 0.01).
@export var grip_offset: Vector3 = Vector3(0, 8, 2)
@export var grip_rotation_degrees: Vector3 = Vector3(-90, 0, 0)

var blades: Array[MeshInstance3D] = []


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
