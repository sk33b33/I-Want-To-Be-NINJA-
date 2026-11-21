extends TestCase
## The Mixamo ninja model is wired up: idle pose built, run/sprint loop, jump clips played and
## their root motion removed.


func _setup() -> Array:
	make_floor()
	var player := make_player(Vector3(0, 0.05, 0))
	var animator := player.get_node("NinjaAnimator") as NinjaAnimator
	return [player, animator]


func test_ninja_model_and_all_nine_clips_are_present() -> void:
	var nodes := _setup()
	var player: PlayerController = nodes[0]
	var anim := player.get_node("Visual/NinjaModel/AnimationPlayer") as AnimationPlayer
	check(anim != null, "AnimationPlayer found inside the ninja model")
	if anim == null:
		return
	for clip in ["Run", "Sprint", "Jump", "Front_Flip", "Front_Flip_2", "Quick_Roll_To_Run",
			"Dual_Weapon_Combo", "Crouch_Walk", "Death_Backward"]:
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
