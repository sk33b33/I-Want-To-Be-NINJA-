class_name SecretSpots
extends Node3D
## Places a jungle's hidden spirit shrines (SecretSet) on the terrain when the level loads
## (before ShaderWarmup, so their visuals are warmed up). Shrines already found in this save show
## their stones but no relic or beam.

@export var secret_set: SecretSet
@export var terrain_path: NodePath = ^"../Terrain"
@export var climb_material: Material
@export var rock_material: Material
@export var beam_material: Material
@export var relic_color: Color = Color(0.6, 0.95, 1.0)
## Strength of the spirit beam (the jungle's light-shaft shader, recoloured): visible between
## the trees from the route, so players can spot and chase shrines.
@export var beam_strength: float = 0.22

var sites: Array[SecretSite] = []


func _ready() -> void:
	add_to_group("secret_spots")
	if secret_set == null:
		return
	var terrain := get_node_or_null(terrain_path) as BiomeTerrain
	if terrain and not terrain.is_built():
		terrain.rebuild()
	var relic_mat := StandardMaterial3D.new()
	relic_mat.albedo_color = relic_color * 0.6
	relic_mat.emission_enabled = true
	relic_mat.emission = relic_color
	relic_mat.emission_energy_multiplier = 2.5
	var beam := beam_material
	if beam_material is ShaderMaterial:  # Own copy: never changes the jungle's light shafts.
		beam = beam_material.duplicate()
		(beam as ShaderMaterial).set_shader_parameter("color", Vector3(relic_color.r, relic_color.g, relic_color.b))
		(beam as ShaderMaterial).set_shader_parameter("strength", beam_strength)
	var profile := PlayerProfile.load_profile()
	for def in secret_set.secrets:
		var site := SecretSite.new()
		var ground := terrain.get_height(def.position.x, def.position.y) if terrain else 0.0
		site.build(def, secret_set, ground, climb_material, rock_material, beam, relic_mat, profile.has_secret(def.id))
		add_child(site)
		sites.append(site)
