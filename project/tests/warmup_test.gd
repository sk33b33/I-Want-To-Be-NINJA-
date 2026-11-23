extends TestCase
## Shader warm-up (Android crash diagnosis): every distinct visual is drawn once at load, each
## step written to the crash breadcrumbs first; the scene comes back exactly as it was.


func test_warmup_visits_every_visual_logs_it_and_restores_the_scene() -> void:
	PlayerProfile.path = "user://test_profile_warmup.json"
	CrashReport.breadcrumbs_path = "user://test_breadcrumbs_warmup.log"
	var main := instantiate("res://scenes/main/main.tscn")
	await physics_frames(5)
	await process_frames(10)  # Let late-created visuals (slash trails, sheath) appear first.
	var m := main.get_node("Expedition") as ExpeditionManager
	var hidden_before := main.find_children("*", "GeometryInstance3D", true, false).filter(
			func(g: Node) -> bool: return not (g as GeometryInstance3D).visible).size()
	var cam_before := main.get_viewport().get_camera_3d()
	var remaining := m.timer.remaining
	var w := ShaderWarmup.new()
	add_node(w)
	await w.run(main)
	check(w.targets.size() >= 25, "found the distinct visuals (%d)" % w.targets.size())
	check(w.warmed == w.targets.size(), "drew every one (%d/%d)" % [w.warmed, w.targets.size()])
	var crumbs := FileAccess.get_file_as_string(CrashReport.breadcrumbs_path)
	check(crumbs.contains("warm 1/") and crumbs.contains("creature.gdshader") and crumbs.contains("warm-up done"),
			"each step is in the breadcrumbs before it is drawn")
	var hidden_after := main.find_children("*", "GeometryInstance3D", true, false).filter(
			func(g: Node) -> bool: return not (g as GeometryInstance3D).visible).size()
	check(hidden_after == hidden_before, "hidden things hidden again (%d/%d)" % [hidden_after, hidden_before])
	check(main.get_viewport().get_camera_3d() == cam_before, "game camera restored")
	check(not tree.paused, "game unpaused")
	check(absf(m.timer.remaining - remaining) < 0.5, "the countdown did not run during the warm-up")
	CrashReport.breadcrumbs_path = "user://breadcrumbs.log"
	PlayerProfile.path = PlayerProfile.DEFAULT_PATH
