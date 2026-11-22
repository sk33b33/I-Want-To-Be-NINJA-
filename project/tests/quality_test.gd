extends TestCase
## Phase 11: graphics presets — data sanity, tier selection, and that each preset really cuts
## the heavy work (terrain triangles, flora instances, shadows, render scale, lights, particles).

const SETTINGS := "user://test_settings_phase11.cfg"
const SCENE := "res://scenes/main/expedition_moonfen.tscn"


func _fresh() -> void:
	GameSettings.path = SETTINGS
	if FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	GameSettings.load_settings()
	PlayerProfile.path = "user://test_profile_phase11.json"


func _done() -> void:
	QualityProfile.force_tier(&"")
	GameSettings.quality = "auto"
	GameSettings.path = GameSettings.DEFAULT_PATH
	GameSettings.load_settings()
	PlayerProfile.path = PlayerProfile.DEFAULT_PATH
	var vp := tree.root.get_viewport()
	vp.scaling_3d_scale = 1.0


func _flora_instances(main: Node) -> int:
	var n := 0
	for mmi in main.get_node("Level/Flora").find_children("*", "MultiMeshInstance3D", true, false):
		n += (mmi as MultiMeshInstance3D).multimesh.instance_count
	return n


func test_presets_are_ordered_from_cheap_to_rich() -> void:
	var low := load("res://data/quality/low.tres") as QualityPreset
	var med := load("res://data/quality/medium.tres") as QualityPreset
	var high := load("res://data/quality/high.tres") as QualityPreset
	check(low.id == &"low" and med.id == &"medium" and high.id == &"high", "ids match files")
	for f in ["render_scale", "flora_density", "tree_density", "draw_distance_scale", "mist_scale", "rain_scale", "particle_scale", "light_fade_distance", "shadow_distance"]:
		check(float(low.get(f)) <= float(med.get(f)) and float(med.get(f)) <= float(high.get(f)), "%s rises low -> medium -> high" % f)
	check(not low.moon_shadows and high.moon_shadows, "phones skip moon shadows")
	check(low.terrain_mesh_step >= 2 and high.terrain_mesh_step == 1, "coarser terrain mesh on phones")
	check(low.render_scale <= 0.75, "phones render at reduced resolution")


func test_tier_follows_the_setting_then_auto() -> void:
	_fresh()
	check(QualityProfile.tier() == QualityProfile.auto_tier(), "auto by default")
	GameSettings.set_quality("medium")
	check(QualityProfile.tier() == &"medium", "pause-menu choice wins over auto")
	QualityProfile.force_tier(&"low")
	check(QualityProfile.tier() == &"low" and QualityProfile.is_low(), "forced tier (tests / command line)")
	_done()


func test_low_preset_cuts_terrain_flora_shadows_and_resolution() -> void:
	_fresh()
	QualityProfile.force_tier(&"high")
	var high_main := instantiate(SCENE)
	await physics_frames(3)
	var high_tris := (high_main.get_node("Level/Terrain") as BiomeTerrain).render_triangle_count()
	var high_flora := _flora_instances(high_main)
	high_main.free()
	_nodes.erase(high_main)
	QualityProfile.force_tier(&"low")
	var low_main := instantiate(SCENE)
	await physics_frames(3)
	var terrain := low_main.get_node("Level/Terrain") as BiomeTerrain
	var low_tris := terrain.render_triangle_count()
	check(low_tris * 3 < high_tris, "terrain triangles cut to under a third (%d vs %d)" % [low_tris, high_tris])
	var low_flora := _flora_instances(low_main)
	check(low_flora * 2 < high_flora, "flora instances cut by more than half (%d vs %d)" % [low_flora, high_flora])
	var sun := low_main.get_node("Level/Moonlight") as DirectionalLight3D
	check(not sun.shadow_enabled, "no moon shadows on LOW")
	check_near(tree.root.get_viewport().scaling_3d_scale, QualityProfile.current().render_scale, 0.001, "render scale applied")
	var lights := low_main.find_children("*", "OmniLight3D", true, false)
	check(not lights.is_empty(), "scene has small lights")
	for l: OmniLight3D in lights:
		check(l.distance_fade_enabled and l.distance_fade_begin <= QualityProfile.current().light_fade_distance + 0.01, "%s fades out with distance" % l.name)
	# Collision keeps full resolution whatever the preset: the player still stands on the ground.
	check_near(terrain.get_height(0.0, -20.0), terrain.get_height_interpolated(0.0, -20.0), 0.05, "height queries unaffected")
	_done()


func test_particles_scale_with_the_preset() -> void:
	_fresh()
	QualityProfile.force_tier(&"low")
	var fx := CombatFx.new()
	add_node(fx)
	await process_frames(2)
	var low_amount := (fx.get_child(1) as CPUParticles3D).amount
	QualityProfile.force_tier(&"high")
	var fx2 := CombatFx.new()
	add_node(fx2)
	await process_frames(2)
	check(low_amount < (fx2.get_child(1) as CPUParticles3D).amount, "fewer sparks on LOW (%d)" % low_amount)
	_done()


func test_landing_and_rolling_raise_dust() -> void:
	_fresh()
	var main := instantiate("res://scenes/main/main.tscn")
	var p := main.get_node("Player") as PlayerController
	await physics_frames(10)
	var fx := main.get_tree().get_first_node_in_group("combat_fx") as CombatFx
	var before := fx.dust_spawned
	p.global_position += Vector3.UP * 2.0
	await physics_frames(60)
	check(fx.dust_spawned > before, "dust on landing")
	before = fx.dust_spawned
	BotHelpers.tap(self, "dodge")
	await physics_frames(10)
	check(fx.dust_spawned > before, "dust on a roll")
	_done()
