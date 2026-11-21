class_name TestCase
extends RefCounted
## Tiny dependency-free test base used by tests/run_tests.gd.
## Each `test_*` method may `await` frames. Nodes added via add_node() are freed after the test.

var tree: SceneTree
var failed: bool = false
var messages: PackedStringArray = []
var _nodes: Array[Node] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		messages.append(message)


func check_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	check(absf(actual - expected) <= tolerance,
			"%s (expected %.3f ± %.3f, got %.3f)" % [message, expected, tolerance, actual])


func add_node(node: Node) -> Node:
	tree.root.add_child(node)
	_nodes.append(node)
	return node


func instantiate(path: String) -> Node:
	return add_node((load(path) as PackedScene).instantiate())


func physics_frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


func process_frames(count: int) -> void:
	for i in count:
		await tree.process_frame


func press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	ev.strength = 1.0
	Input.parse_input_event(ev)


func release(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)


func cleanup() -> void:
	for action in InputMap.get_actions():
		Input.action_release(action)
	for node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	_nodes.clear()


## A flat 100x100 m static floor whose top surface is at y = 0, on the "world" layer.
func make_floor(size: Vector3 = Vector3(100, 1, 100), center: Vector3 = Vector3(0, -0.5, 0)) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	add_node(body)
	return body


func make_player(at: Vector3) -> PlayerController:
	var player := instantiate("res://scenes/player/player.tscn") as PlayerController
	player.global_position = at
	player.set_safe_position(at)
	(player.get_node("CameraRig") as CameraRig).snap_to_target()
	return player
