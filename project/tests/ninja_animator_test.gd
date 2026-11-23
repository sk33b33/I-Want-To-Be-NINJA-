extends TestCase
## The Mixamo ninja model is wired up: idle pose built, run/sprint loop, jump clips played and
## their root motion removed.


func _setup() -> Array:
	make_floor()
	var player := make_player(Vector3(0, 0.05, 0))
	var animator := player.get_node("NinjaAnimator") as NinjaAnimator
	return [player, animator]


func test_ninja_model_and_all_fourteen_clips_are_present() -> void:
	var nodes := _setup()
	var player: PlayerController = nodes[0]
	var anim := player.get_node("Visual/NinjaModel/AnimationPlayer") as AnimationPlayer
	check(anim != null, "AnimationPlayer found inside the ninja model")
	if anim == null:
		return
	for clip in ["Run", "Sprint", "Jump", "Front_Flip", "Front_Flip_2", "Quick_Roll_To_Run",
			"Dual_Weapon_Combo", "Crouch_Walk", "Death_Backward", "Climb_Up_Wall", "Climb_Down_Wall", "Climb_On", "Draw_Sword", "Sheath_Sword"]:
		check(anim.has_animation(clip), "clip %s imported" % clip)
	check(anim.has_animation("Idle"), "Idle pose generated (the GLB has no idle clip)")


func test_idle_when_standing_then_run_when_moving() -> void:
	var nodes := _setup()
	var animator: NinjaAnimator = nodes[1]
	await physics_frames(50)  # Spawn drop + landing recovery (0.35 s) finish first.
	check(animator.state == NinjaAnimator.State.IDLE, "idle while standing")
	check(animator.current_clip() == &"Idle", "Idle clip playing (got %s)" % animator.current_clip())
	press("move_forward")
	await physics_frames(30)
	check(animator.state == NinjaAnimator.State.RUN, "run state while moving")
	check(animator.current_clip() == &"Run", "Run clip playing (got %s)" % animator.current_clip())
	press("sprint")
	await physics_frames(40)
	check(animator.current_clip() == &"Sprint", "Sprint clip while sprinting (got %s)" % animator.current_clip())


func test_jump_plays_air_clip_and_returns_to_ground_state() -> void:
	var nodes := _setup()
	var animator: NinjaAnimator = nodes[1]
	await physics_frames(20)
	press("jump")
	await physics_frames(5)
	check(animator.state == NinjaAnimator.State.AIR, "air state after jumping")
	check(animator.current_clip() == &"Jump", "Jump clip playing (got %s)" % animator.current_clip())
	release("jump")
	await physics_frames(90)
	check(animator.state == NinjaAnimator.State.IDLE or animator.state == NinjaAnimator.State.LAND,
			"back on the ground (state %d)" % animator.state)


func test_sprint_jump_uses_front_flip() -> void:
	var nodes := _setup()
	var animator: NinjaAnimator = nodes[1]
	await physics_frames(10)
	press("move_forward")
	press("sprint")
	await physics_frames(45)
	press("jump")
	await physics_frames(4)
	check(animator.current_clip() == &"Front_Flip", "flip on sprint jump (got %s)" % animator.current_clip())


func test_jump_clips_have_no_root_motion() -> void:
	var nodes := _setup()
	var player: PlayerController = nodes[0]
	var anim := player.get_node("Visual/NinjaModel/AnimationPlayer") as AnimationPlayer
	var cfg := (nodes[1] as NinjaAnimator).config
	for clip in ["Jump", "Front_Flip"]:
		var a := anim.get_animation(clip)
		var track := a.find_track(cfg.hips_bone_track, Animation.TYPE_POSITION_3D)
		var first: Vector3 = a.track_get_key_value(track, 0)
		var last: Vector3 = a.track_get_key_value(track, a.track_get_key_count(track) - 1)
		check_near(last.y, first.y, 0.01, "%s hips do not travel forward" % clip)
		var highest := 0.0
		for k in a.track_get_key_count(track):
			highest = maxf(highest, -(a.track_get_key_value(track, k) as Vector3).z)
		check(highest <= cfg.max_hips_height * 100.0 + 0.01, "%s hips rise is clamped (%.1f cm)" % [clip, highest])


# Regression: the animator connected to PlayerCombat/TraversalComponent before the player had
# resolved them (child _ready runs before the parent's @onready), so attack, roll and climb
# animations never played even though the combat state changed.

func test_light_attack_plays_the_combo_clip() -> void:
	var nodes := _setup()
	var player: PlayerController = nodes[0]
	var anim := player.get_node("Visual/NinjaModel/AnimationPlayer") as AnimationPlayer
	await physics_frames(50)
	press("attack_light")
	await physics_frames(6)
	release("attack_light")
	check(player.combat.state == PlayerCombat.State.ATTACK, "attacking")
	check(anim.current_animation == &"Dual_Weapon_Combo", "combo clip playing (got %s)" % anim.current_animation)
	var a := player.combat.config.light_combo[0]
	check(anim.current_animation_position >= a.clip_start - 0.01 and anim.current_animation_position <= a.clip_end + 0.01,
			"inside the light-1 slice (pos %.2f)" % anim.current_animation_position)


func test_dodge_plays_the_roll_clip() -> void:
	var nodes := _setup()
	var player: PlayerController = nodes[0]
	var anim := player.get_node("Visual/NinjaModel/AnimationPlayer") as AnimationPlayer
	await physics_frames(50)
	press("dodge")
	await physics_frames(6)
	release("dodge")
	check(player.combat.state == PlayerCombat.State.DODGE, "dodging")
	check(anim.current_animation == &"Quick_Roll_To_Run", "roll clip playing (got %s)" % anim.current_animation)


func test_heavy_attack_plays_its_slice() -> void:
	var nodes := _setup()
	var player: PlayerController = nodes[0]
	var anim := player.get_node("Visual/NinjaModel/AnimationPlayer") as AnimationPlayer
	await physics_frames(50)
	press("attack_heavy")
	await physics_frames(6)
	release("attack_heavy")
	var h := player.combat.config.heavy
	check(anim.current_animation == h.clip, "heavy uses %s (got %s)" % [h.clip, anim.current_animation])
	check(anim.current_animation_position >= h.clip_start - 0.01, "inside the heavy slice (pos %.2f)" % anim.current_animation_position)


func _climb_setup() -> Array:
	make_floor()
	var wall := make_floor(Vector3(8, 8, 1), Vector3(0, 4, -2.0))
	wall.collision_layer = 1 | 4
	var player := make_player(Vector3(0, 0.05, 0))
	var anim := player.get_node("Visual/NinjaModel/AnimationPlayer") as AnimationPlayer
	await physics_frames(10)
	press("move_forward")
	await physics_frames(5)
	press("jump")
	for i in 40:
		await tree.physics_frame
		if player.traversal.state == TraversalComponent.State.CLIMB:
			break
	await physics_frames(3)
	return [player, anim, (player.get_node("NinjaAnimator") as NinjaAnimator).config]


## Owner's model update (Phase 12+): the GLB now has real climbing clips.
func test_climbing_up_and_down_play_the_wall_climb_clips() -> void:
	var r: Array = await _climb_setup()
	var player: PlayerController = r[0]
	var anim: AnimationPlayer = r[1]
	var cfg: NinjaAnimationConfig = r[2]
	check(player.traversal.state == TraversalComponent.State.CLIMB, "climbing")
	check(anim.current_animation == cfg.climb_clip and cfg.climb_clip == &"Climb_Up_Wall", "climbing up plays Climb_Up_Wall (got %s)" % anim.current_animation)
	check(anim.speed_scale > 1.0, "plays faster when climbing at full speed (%.2f)" % anim.speed_scale)
	await physics_frames(60)  # Climb well clear of the ground first.
	release("move_forward")
	press("move_back")
	await physics_frames(8)
	check(anim.current_animation == &"Climb_Down_Wall", "climbing down plays Climb_Down_Wall (got %s)" % anim.current_animation)
	release("move_back")
	await physics_frames(5)
	check(player.traversal.state == TraversalComponent.State.CLIMB, "still on the wall")
	check(is_zero_approx(anim.speed_scale), "holding still on the wall pauses the clip")


func test_climb_clips_loop_in_place() -> void:
	var nodes := _setup()
	var anim := (nodes[0] as PlayerController).get_node("Visual/NinjaModel/AnimationPlayer") as AnimationPlayer
	await physics_frames(2)
	for clip in [&"Climb_Up_Wall", &"Climb_Down_Wall"]:
		var a := anim.get_animation(clip)
		var t := a.find_track(^"Armature/Skeleton3D:mixamorig_Hips", Animation.TYPE_POSITION_3D)
		var start := a.position_track_interpolate(t, 0.0)
		var end := a.position_track_interpolate(t, a.length)
		check(absf(end.z - start.z) < 2.0, "%s ends where it starts (rise %.0f cm)" % [clip, start.z - end.z])
		check(absf(start.z) < 120.0, "%s hips at standing height (%.0f cm)" % [clip, -start.z])
		check(a.loop_mode == Animation.LOOP_LINEAR, "%s loops" % clip)


func test_hang_and_mantle_use_the_climb_on_clip() -> void:
	var nodes := _setup()
	var player: PlayerController = nodes[0]
	var animator: NinjaAnimator = nodes[1]
	var anim := player.get_node("Visual/NinjaModel/AnimationPlayer") as AnimationPlayer
	await physics_frames(5)
	var cfg := animator.config
	animator.call("_on_traversal_state", TraversalComponent.State.HANG)
	check(anim.assigned_animation == &"Climb_On" and not anim.is_playing(), "hanging holds the first Climb_On pose")
	animator.call("_on_traversal_state", TraversalComponent.State.MANTLE)
	check(anim.current_animation == &"Climb_On" and anim.is_playing(), "mantle plays Climb_On")
	var expected: float = (cfg.mantle_end_time - cfg.mantle_start_time) / player.traversal.config.mantle_time
	check_near(anim.speed_scale, expected, 0.01, "pull-up fitted to the mantle time")
	var a := anim.get_animation(&"Climb_On")
	var t := a.find_track(^"Armature/Skeleton3D:mixamorig_Hips", Animation.TYPE_POSITION_3D)
	var p0 := a.position_track_interpolate(t, cfg.mantle_start_time)
	var p1 := a.position_track_interpolate(t, cfg.mantle_end_time)
	check(p0.distance_to(p1) < 5.0, "no root motion over the pull-up (%.0f cm)" % p0.distance_to(p1))
