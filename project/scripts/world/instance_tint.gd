class_name InstanceTint
extends GeometryInstance3D
## Sets an instance shader parameter (e.g. a spirit flame's colour) when the node enters the
## tree. Generated scenes need this: instance parameters set on a node before it is in a tree
## are not saved into the .tscn.

@export var parameter: StringName = &"flame_color"
@export var color: Color = Color.WHITE


func _ready() -> void:
	set_instance_shader_parameter(parameter, color)
