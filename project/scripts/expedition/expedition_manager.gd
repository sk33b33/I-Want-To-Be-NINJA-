class_name ExpeditionManager
extends Node
## Runs one hunt expedition (docs/ARCHITECTURE.md HuntManager + ExpeditionTimer):
## starts the 45:00 countdown, pauses it with the game, stops and hides it for good when the
## player enters the boss arena, and applies the timeout rule. UI listens to its signals.
## Implements docs/PHASES.md Phase 3.

signal expedition_started(hunt: HuntDefinition, duration: float)
signal pause_changed(paused: bool)
signal boss_arena_entered(remaining: float)
signal timer_expired
## result: {"outcome": "escaped", "hunt": HuntDefinition, "elapsed": float}
signal expedition_ended(result: Dictionary)

@export var hunt: HuntDefinition
## Used when the hunt has no config of its own.
@export var default_config: ExpeditionConfig
@export var player_path: NodePath = ^"../Player"
@export var arena_trigger_path: NodePath = ^"../Level/BossArenaTrigger"
## The biome scene this expedition runs in (for Retry).
@export_file("*.tscn") var scene_path: String = ""

var timer := ExpeditionTimer.new()
var config: ExpeditionConfig
var is_debug_duration: bool = false
var arena_entered: bool = false
var ended: bool = false

var _player: PlayerController


func _ready() -> void:
	_player = get_node_or_null(player_path) as PlayerController
	var trigger := get_node_or_null(arena_trigger_path) as BossArenaTrigger
	if trigger:
		trigger.player_entered.connect(enter_boss_arena)
	timer.expired.connect(_on_timer_expired)
	start_expedition()


func _process(delta: float) -> void:
	# This node is pausable: while the tree is paused (pause menu) the countdown cannot advance.
	timer.tick(delta)


func start_expedition() -> void:
	config = hunt.config if hunt and hunt.config else default_config
	var resolved := config.resolve_duration(OS.get_cmdline_user_args())
	is_debug_duration = resolved[1]
	arena_entered = false
	ended = false
	timer.start(resolved[0])
	expedition_started.emit(hunt, timer.duration)


## Pause or resume the whole game (and the countdown). Called by the pause menu.
func set_paused(paused: bool) -> void:
	if ended:
		return
	get_tree().paused = paused
	if paused:
		timer.pause()
	else:
		timer.resume()
	pause_changed.emit(paused)


func is_paused() -> bool:
	return get_tree().paused


## The BossArenaEntered event: stop and hide the expedition timer permanently for this run.
func enter_boss_arena() -> void:
	if arena_entered or ended:
		return
	arena_entered = true
	timer.stop()
	boss_arena_entered.emit(timer.remaining)


## Test/debug hook: jump the countdown to `seconds` remaining.
func debug_set_remaining(seconds: float) -> void:
	timer.remaining = seconds


## Restart this expedition from scratch with the same hunt.
func restart() -> void:
	SceneFlow.start_expedition(get_tree(), scene_path, hunt)


func return_to_hunt_board() -> void:
	SceneFlow.go_to_hunt_board(get_tree())


func _on_timer_expired() -> void:
	timer_expired.emit()
	match config.timeout_behavior:
		ExpeditionConfig.TimeoutBehavior.RETURN_TO_CHECKPOINT:
			if _player:
				_player.respawn()
			timer.start(timer.duration)
		_:
			ended = true
			if _player:
				_player.input_enabled = false
			expedition_ended.emit({"outcome": "escaped", "hunt": hunt, "elapsed": timer.elapsed()})
