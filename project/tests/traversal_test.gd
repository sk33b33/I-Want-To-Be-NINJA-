extends TestCase
## Phase 2 traversal: climb only on climbable walls, climb up and over the top, ledge grab and
## mantle on any ledge, wall jump, drop, and no grabbing low obstacles.


## A box wall in front of the player (player stands at the origin facing -Z).
func _wall(size: Vector3, centre: Vector3, climbable: bool) -> StaticBody3D:
	var body := make_floor(size, centre)
	body.collision_layer = 1 | (4 if climbable else 0)
	return body


func _player() -> PlayerController:
	make_floor()
	return make_player(Vector3(0, 0.05, 0))


func _state(p: PlayerController) -> TraversalComponent.State:
	return p.traversal.state


func test_jumping_into_climbable_wall_starts_climb() -> void:
	var p := _player()
	_wall(Vector3(8, 8, 1), Vector3(0, 4, -2.0), true)
	await physics_frames(10)
	press("move_forward")
	await physics_frames(5)
	press("jump")
	var climbed := false
	for i in 40:
		await tree.physics_frame
		if _state(p) == TraversalComponent.State.CLIMB:
			climbed = true
			break
	check(climbed, "attached to the climbable wall")


func test_plain_wall_is_not_climbable() -> void:
	var p := _player()
	_wall(Vector3(8, 8, 1), Vector3(0, 4, -2.0), false)
	await physics_frames(10)
	press("move_forward")
	await physics_frames(5)
	press("jump")
	var climbed := false
	for i in 50:
		await tree.physics_frame
		climbed = climbed or _state(p) == TraversalComponent.State.CLIMB
	check(not climbed, "no climbing on an unmarked wall")
	check(p.global_position.y < 0.3, "back on the ground")


func test_climb_up_and_mantle_onto_top() -> void:
	var p := _player()
	# 3.5 m climbable block with a walkable top.
	_wall(Vector3(8, 3.5, 4), Vector3(0, 1.75, -3.0), true)
	await physics_frames(10)
	press("move_forward")
	await physics_frames(5)
	press("jump")
	var saw := {}
	for i in 240:
		await tree.physics_frame
		saw[_state(p)] = true
		if p.is_on_floor() and p.global_position.y > 3.0:
			break
	check(saw.has(TraversalComponent.State.CLIMB), "climbed")
	check(saw.has(TraversalComponent.State.MANTLE), "mantled over the top")
	check(p.global_position.y > 3.4 and p.is_on_floor(), "standing on top (y=%.2f)" % p.global_position.y)


func test_falling_past_ledge_grabs_it_then_mantles() -> void:
	var p := _player()
	# Unclimbable block whose top (2.6 m) is too high to jump onto: must grab the ledge.
	_wall(Vector3(8, 2.6, 4), Vector3(0, 1.3, -3.0), false)
	var hung := [false]
	p.traversal.state_changed.connect(func(s: TraversalComponent.State) -> void:
		if s == TraversalComponent.State.HANG: hung[0] = true)
	await physics_frames(10)
	press("move_forward")
	await physics_frames(5)
	press("jump")
	for i in 120:
		await tree.physics_frame
		if p.is_on_floor() and p.global_position.y > 2.0:
			break
	check(hung[0], "grabbed the ledge")
	check(p.global_position.y > 2.5, "pulled up onto the block (y=%.2f)" % p.global_position.y)


func test_hang_then_drop_with_back() -> void:
	var p := _player()
	_wall(Vector3(8, 2.6, 4), Vector3(0, 1.3, -3.0), false)
	await physics_frames(10)
	press("move_forward")
	await physics_frames(5)
	press("jump")
	for i in 60:
		await tree.physics_frame
		if _state(p) == TraversalComponent.State.HANG:
			break
	check(_state(p) == TraversalComponent.State.HANG, "hanging")
	release("move_forward")
	press("move_back")
	await physics_frames(40)
	check(_state(p) == TraversalComponent.State.NONE, "let go")
	check(p.global_position.y < 0.3, "dropped to the ground (y=%.2f)" % p.global_position.y)


func test_low_obstacle_is_not_grabbed() -> void:
	var p := _player()
	# 1 m step: a plain jump clears it, no ledge grab.
	_wall(Vector3(8, 1.0, 14), Vector3(0, 0.5, -8.0), false)
	var grabbed := [false]
	p.traversal.state_changed.connect(func(s: TraversalComponent.State) -> void:
		if s != TraversalComponent.State.NONE: grabbed[0] = true)
	await physics_frames(10)
	press("move_forward")
	await physics_frames(5)
	press("jump")
	await physics_frames(60)
	check(not grabbed[0], "jumped onto the step without grabbing")
	check(p.global_position.y > 0.9, "standing on the step (y=%.2f)" % p.global_position.y)


func test_wall_jump_pushes_away_from_wall() -> void:
	var p := _player()
	_wall(Vector3(8, 8, 1), Vector3(0, 4, -2.0), true)
	await physics_frames(10)
	press("move_forward")
	await physics_frames(5)
	press("jump")
	for i in 40:
		await tree.physics_frame
		if _state(p) == TraversalComponent.State.CLIMB:
			break
	release("jump")
	release("move_forward")
	await physics_frames(10)
	var z0 := p.global_position.z
	press("jump")
	await physics_frames(10)
	check(_state(p) == TraversalComponent.State.NONE, "left the wall")
	check(p.global_position.z > z0 + 0.5, "pushed away from the wall (dz=%.2f)" % (p.global_position.z - z0))
