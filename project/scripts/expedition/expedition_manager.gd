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
## Emitted when a boss part breaks and its reward is granted (once per part per run).
signal part_reward_granted(part: BossPartDefinition, item: ItemDefinition, count: int)
## A material was gathered from a Pickup.
signal item_collected(item: ItemDefinition, count: int)
## Boss defeated (the victory results follow after the death animation).
signal hunt_completed
## result: {"outcome": "escaped"|"victory", "hunt", "elapsed", and for victory:
##          "parts_broken": Array[StringName], "rewards": {item id: count}, "items": {item id: ItemDefinition}}
signal expedition_ended(result: Dictionary)

@export var hunt: HuntDefinition
## Used when the hunt has no config of its own.
@export var default_config: ExpeditionConfig
@export var player_path: NodePath = ^"../Player"
@export var arena_trigger_path: NodePath = ^"../Level/BossArenaTrigger"
@export var boss_path: NodePath = ^"../Level/Boss"
## Where the HUD's objective arrow points before the arena (the boss gate).
@export var objective_path: NodePath = ^"../Level/ArenaGateMarker"
## Gear catalog used to apply the player's equipped (forged) gear at the start.
@export var crafting: CraftingCatalog
## The biome scene this expedition runs in (for Retry).
@export_file("*.tscn") var scene_path: String = ""

var timer := ExpeditionTimer.new()
## Sound for this expedition (Phase 11); listens to gameplay signals.
var audio: AudioDirector
var difficulty: DifficultyPreset
var config: ExpeditionConfig
var is_debug_duration: bool = false
var arena_entered: bool = false
var ended: bool = false
var boss: BossController
## Rewards earned this run: item id -> count, and their definitions.
var run_rewards: Dictionary = {}
var run_items: Dictionary = {}
var parts_broken: Array[StringName] = []
## True once victory rewards were written to the player profile.
var rewards_recorded: bool = false
## Countdown left when the arena was entered (for the results screen).
var remaining_at_arena: float = -1.0
var gathered: Dictionary = {}
var objective: Node3D

var _player: PlayerController


func _ready() -> void:
	add_to_group("expedition")
	QualityProfile.apply_to_scene.call_deferred(get_parent())  # Graphics preset (Phase 11).
	audio = AudioDirector.new()
	audio.name = "Audio"
	add_child(audio)
	objective = get_node_or_null(objective_path) as Node3D
	_player = get_node_or_null(player_path) as PlayerController
	var trigger := get_node_or_null(arena_trigger_path) as BossArenaTrigger
	if trigger:
		trigger.player_entered.connect(enter_boss_arena)
	timer.expired.connect(_on_timer_expired)
	if _player and crafting:
		GearLoadout.apply(_player, Forge.equipped_gear(PlayerProfile.load_profile(), crafting))
	boss = get_node_or_null(boss_path) as BossController
	_apply_difficulty(GameSettings.difficulty_preset())
	if boss:
		boss.part_broken.connect(_on_part_broken)
		boss.defeated.connect(_on_boss_defeated)
	start_expedition()
	audio.setup.call_deferred(get_parent(), self)  # After every sibling is ready.
	if ShaderWarmup.is_needed():
		_warm_up.call_deferred()


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
	CrashReport.note("expedition %s, quality %s, difficulty %s" % [hunt.id if hunt else &"?", QualityProfile.tier(), GameSettings.difficulty])
	expedition_started.emit(hunt, timer.duration)


## Compile every shader up front (see ShaderWarmup) — paused, behind a loading screen.
func _warm_up() -> void:
	var w := ShaderWarmup.new()
	w.name = "ShaderWarmup"
	add_child(w)
	await w.run(get_parent())
	w.queue_free()


## Difficulty (Phase 12): after gear, so armor and difficulty multiply. Never touches the timer.
func _apply_difficulty(d: DifficultyPreset) -> void:
	difficulty = d
	if _player and _player.combat and _player.combat.health:
		_player.combat.health.damage_taken_multiplier *= d.damage_taken_multiplier
	if boss:
		var h := boss.get_health()
		h.max_health *= d.boss_health_multiplier
		h.current = h.max_health
		boss.telegraph_scale = maxf(d.telegraph_multiplier, 1.0)


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
	remaining_at_arena = timer.remaining
	boss_arena_entered.emit(timer.remaining)
	CrashReport.note("arena entered")
	if boss:
		boss.awaken()


## Test/debug hook: jump the countdown to `seconds` remaining.
func debug_set_remaining(seconds: float) -> void:
	timer.remaining = seconds


## Restart this expedition from scratch with the same hunt. What was gathered (and any part
## already broken) is kept, exactly as when the beast escapes.
func restart() -> void:
	abandon()
	SceneFlow.start_expedition(get_tree(), scene_path, hunt)


func return_to_hunt_board() -> void:
	abandon()
	SceneFlow.go_to_hunt_board(get_tree())


## Leaving mid-hunt (dojo, restart, closing the app): save this run's gathered materials and
## part rewards once; no hunt credit. No-op if the run already ended and saved.
func abandon() -> void:
	if not ended:
		ended = true
		_record_rewards()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		abandon()  # Closing the game window / app keeps what was gathered.


## Gather a material on the way (Pickup). Kept even if the beast escapes.
func collect(item: ItemDefinition, count: int) -> void:
	if item == null or ended:
		return
	gathered[item.id] = int(gathered.get(item.id, 0)) + count
	_grant(item, count)
	item_collected.emit(item, count)


func _grant(item: ItemDefinition, count: int) -> void:
	if item == null or count <= 0:
		return
	run_rewards[item.id] = int(run_rewards.get(item.id, 0)) + count
	run_items[item.id] = item


func _on_part_broken(part: BossPartDefinition) -> void:
	if parts_broken.has(part.id):
		return  # A part can only reward once.
	parts_broken.append(part.id)
	_grant(part.reward, part.reward_count)
	part_reward_granted.emit(part, part.reward, part.reward_count)


func _on_boss_defeated() -> void:
	if ended:
		return
	ended = true
	for item in boss.definition.victory_rewards:
		_grant(item, 1)
	_record_rewards()
	hunt_completed.emit()
	await get_tree().create_timer(boss.definition.death_time, false, true).timeout
	if _player:
		_player.input_enabled = false
	expedition_ended.emit({"outcome": "victory", "hunt": hunt, "elapsed": timer.elapsed(),
			"remaining_at_arena": remaining_at_arena, "parts_broken": parts_broken.duplicate(),
			"rewards": run_rewards.duplicate(), "items": run_items.duplicate()})


## Write this run's rewards to the persistent player profile (exactly once per run).
func _record_rewards() -> void:
	if rewards_recorded:
		return
	rewards_recorded = true
	var profile := PlayerProfile.load_profile()
	for id in run_rewards:
		profile.add_material(id, int(run_rewards[id]))
	if hunt and boss and not boss.is_alive():
		profile.record_hunt(hunt.id)
	profile.save()


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
			_record_rewards()  # Gathered materials are kept even though the beast escaped.
			expedition_ended.emit({"outcome": "escaped", "hunt": hunt, "elapsed": timer.elapsed(),
					"rewards": run_rewards.duplicate(), "items": run_items.duplicate()})
