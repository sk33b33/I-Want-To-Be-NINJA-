extends SceneTree
## Art pass stage 4: rebuild every beast's body and breakable-part meshes in smooth mode
## (ProceduralMeshes.smooth_level = 2) in place in scenes/bosses/*.tscn, keeping each mesh's
## material. Shapes, sizes, hitboxes and hurtboxes are unchanged (only the mesh resolution and
## the small surface lumps). Re-run after tools/generate_visual_pass.gd / generate_beasts.gd.
##   godot --headless --path project -s ../tools/rebuild_beast_meshes.gd

## scene -> [[mesh node under Visual, builder, broken flag or null for bodies], ...]
const BEASTS := {
	"kurogale": [["Body", "kurogale_body", null], ["Antlers", "kurogale_antlers", false], ["AntlerStubs", "kurogale_antlers", true]],
	"ashen_oni_tortoise": [["Body", "oni_tortoise_body", null], ["Horns", "oni_horns", false], ["HornStubs", "oni_horns", true]],
	"nami": [["Body", "serpent_body", null], ["Lantern", "serpent_lantern", false], ["LanternStub", "serpent_lantern", true]],
	"raijins_echo": [["Body", "sky_roc_body", null], ["Crest", "roc_crest", false], ["CrestStub", "roc_crest", true]],
	"kamakiri": [["Body", "mantis_body", null], ["Part", "mantis_scythes", false], ["PartStub", "mantis_scythes", true]],
	"kasai": [["Body", "salamander_body", null], ["Part", "salamander_tail", false], ["PartStub", "salamander_tail", true]],
	"gamakage": [["Body", "toad_body", null], ["Part", "toad_sac", false], ["PartStub", "toad_sac", true]],
	"kazekiri": [["Body", "wolf_body", null], ["Part", "wolf_fangs", false], ["PartStub", "wolf_fangs", true]],
}


func _initialize() -> void:
	ProceduralMeshes.smooth_level = 2
	var builder := ProceduralMeshes.new()  # callv() needs an instance; the builders are static.
	for id: String in BEASTS:
		var path := "res://scenes/bosses/%s.tscn" % id
		var root_node := (load(path) as PackedScene).instantiate()
		for row: Array in BEASTS[id]:
			var mi := root_node.get_node("Visual/" + row[0]) as MeshInstance3D
			var before := mi.mesh.get_faces().size() / 3
			var mat := mi.mesh.surface_get_material(0)
			var args: Array = [mat] if row[2] == null else [mat, row[2]]
			mi.mesh = builder.callv(row[1], args)
			print("%s/%s: %d -> %d triangles" % [id, row[0], before, mi.mesh.get_faces().size() / 3])
		var packed := PackedScene.new()
		packed.pack(root_node)
		ResourceSaver.save(packed, path)
		root_node.free()
	ProceduralMeshes.smooth_level = 1
	quit()
