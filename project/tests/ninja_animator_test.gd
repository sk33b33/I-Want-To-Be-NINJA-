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


func test_climbing_plays_the_climb_clip() -> void:
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
	var cfg := (player.get_node("NinjaAnimator") as NinjaAnimator).config
	check(player.traversal.state == TraversalComponent.State.CLIMB, "climbing")
	check(anim.current_animation == cfg.climb_clip, "climb clip playing (got %s)" % anim.current_animation)
