extends TestCase
## Owner playtest report: "the swords are not placed properly in the hands when unsheathed".
## Both blades must sit in a closed fist (finger pose borrowed from the Dual_Weapon_Combo clip),
## mirrored left/right, with the handle through the fist and the blade out of the thumb side.

const FINGERS := ["Index", "Middle", "Ring", "Pinky"]


func _player() -> PlayerController:
	make_floor()
	var p := make_player(Vector3(0, 0.05, 0))
	p.input_enabled = false
	return p


func _sk(p: PlayerController) -> Skeleton3D:
	return p.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D


func _bone_pos(sk: Skeleton3D, name: String) -> Vector3:
	return (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(name))).origin


## Centre of the closed fingers: knuckles and middle joints of the four fingers.
func _fist_centre(sk: Skeleton3D, side: String) -> Vector3:
	var c := Vector3.ZERO
	for f in FINGERS:
		c += _bone_pos(sk, "mixamorig_%sHand%s1" % [side, f]) + _bone_pos(sk, "mixamorig_%sHand%s3" % [side, f])
	return c / 8.0


## Capture finger curls and fist centres in the final (rendered) pose: skeleton modifiers apply
## during the skeleton update, so read the bones right when it reports the final pose.
func _final(sk: Skeleton3D) -> Dictionary:
	var out := {}
	var grab := func() -> void:
		for side in ["Right", "Left"]:
			out[side + "_curl"] = _curl(sk, side)
			out[side + "_fist"] = _fist_centre(sk, side)
			out[side + "_across"] = (_bone_pos(sk, "mixamorig_%sHandIndex1" % side) - _bone_pos(sk, "mixamorig_%sHandPinky1" % side)).normalized()
	sk.skeleton_updated.connect(grab, CONNECT_ONE_SHOT)
	await sk.skeleton_updated
	return out


func _curl(sk: Skeleton3D, side: String) -> float:
	var b := sk.find_bone("mixamorig_%sHandMiddle1" % side)
	return rad_to_deg(sk.get_bone_rest(b).basis.get_rotation_quaternion().angle_to(sk.get_bone_pose_rotation(b)))


func test_blades_sit_in_closed_fists() -> void:
	var p := _player()
	await physics_frames(30)
	p.face_direction(Vector3.FORWARD)
	await physics_frames(5)
	var sk := _sk(p)
	var mount := p.get_node("WeaponMount") as WeaponMount
	var pose: Dictionary = await _final(sk)
	for i in 2:
		var side: String = ["Right", "Left"][i]
		check(pose[side + "_curl"] > 45.0, "%s fingers closed around the grip (%.0f°)" % [side, pose[side + "_curl"]])
		var blade := mount.blades[i]
		var grip := blade.global_transform * Vector3(0, -0.02, 0)  # Middle of the handle (mesh units).
		var d := grip.distance_to(pose[side + "_fist"] as Vector3)
		check(d < 0.035, "%s handle runs through the fist (%.1f cm off)" % [side, d * 100.0])


func test_left_and_right_blades_mirror_each_other() -> void:
	var p := _player()
	await physics_frames(30)
	p.face_direction(Vector3.FORWARD)
	await physics_frames(5)
	var sk := _sk(p)
	var mount := p.get_node("WeaponMount") as WeaponMount
	var pose: Dictionary = await _final(sk)
	for i in 2:
		var side: String = ["Right", "Left"][i]
		var blade_dir := mount.blades[i].global_basis.y.normalized()
		# The blade leaves the fist on the thumb/index side (away from the pinky).
		var across: Vector3 = pose[side + "_across"]
		check(blade_dir.dot(across) > 0.8, "%s blade comes out of the thumb side (%.2f)" % [side, blade_dir.dot(across)])


func test_hands_relax_when_the_blades_are_sheathed() -> void:
	var p := _player()
	await physics_frames(30)
	p.combat.start_swap(false)
	await physics_frames(int(p.combat.config.sheathe_time * 60.0) + 10)
	var sk := _sk(p)
	check(not p.combat.sword_drawn, "sheathed")
	var pose: Dictionary = await _final(sk)
	check(pose["Right_curl"] < 30.0 and pose["Left_curl"] < 30.0, "open hands (%.0f° / %.0f°)" % [pose["Right_curl"], pose["Left_curl"]])
