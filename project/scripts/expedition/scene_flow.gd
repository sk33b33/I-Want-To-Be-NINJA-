class_name SceneFlow
extends RefCounted
## Scene switching between the hunt board and expeditions. The chosen hunt is injected into
## the expedition scene's ExpeditionManager ("Expedition" node) before it enters the tree,
## so no global game-state singleton is needed.

const HUNT_BOARD := "res://scenes/ui/hunt_board.tscn"
const MANAGER_NODE := "Expedition"


static func start_expedition(tree: SceneTree, scene_path: String, hunt: HuntDefinition) -> Node:
	var scene := (load(scene_path) as PackedScene).instantiate()
	var manager := scene.get_node_or_null(MANAGER_NODE) as ExpeditionManager
	if manager:
		manager.hunt = hunt
		manager.scene_path = scene_path
	_swap(tree, scene)
	return scene


static func go_to_hunt_board(tree: SceneTree) -> Node:
	var board := (load(HUNT_BOARD) as PackedScene).instantiate()
	_swap(tree, board)
	return board


static func _swap(tree: SceneTree, next: Node) -> void:
	tree.paused = false
	var old := tree.current_scene
	# Deferred so a button in the old scene can trigger this safely.
	(func() -> void:
		if is_instance_valid(old):
			old.free()
		tree.root.add_child(next)
		tree.current_scene = next
	).call_deferred()
