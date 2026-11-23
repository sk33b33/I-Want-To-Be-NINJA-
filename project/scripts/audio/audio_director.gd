class_name AudioDirector
extends Node
## Plays the game's sound (Phase 11) by listening to gameplay signals — gameplay code never
## calls audio. Created by ExpeditionManager. All streams and levels come from SoundBank data.
##   Player: swing, hit, dodge, hurt, death, talisman, jump, land, footsteps.
##   Boss/enemies: roar on awakening and enrage, a telegraph chime on every telegraph (an audio
##   cue for the visual warning), attack impacts, part break.
##   World: biome ambience loop, lightning, gusts, vents, bog/lava falls, shrines, pickups.
##   Music: exploration theme on the route, taiko drums in the arena, a victory sting.

const BANK_PATH := "res://data/audio/sound_bank.tres"
const VOICES := 10
## Seconds between footsteps (run / sprint).
const STEP_RUN := 0.33
const STEP_SPRINT := 0.25
## Remaining-time warnings (seconds) — a beep when the countdown passes each.
const TIMER_WARNINGS: Array[float] = [300.0, 60.0]

var bank: SoundBank
## Cue ids played, oldest first (capped) — for tests and debugging.
var played: Array[StringName] = []
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer

var _players_2d: Array[AudioStreamPlayer] = []
var _players_3d: Array[AudioStreamPlayer3D] = []
var _next_2d: int = 0
var _next_3d: int = 0
var _player: PlayerController
var _manager: ExpeditionManager
var _step_t: float = 0.0
var _warned: Dictionary = {}
var _gusts: Dictionary = {}  # GustZone -> last phase
var _vents: Dictionary = {}  # FireVent -> last phase
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if bank == null:
		bank = load(BANK_PATH) as SoundBank
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players_2d.append(p)
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = &"SFX"
		p3.unit_size = 8.0
		p3.max_distance = 60.0
		add_child(p3)
		_players_3d.append(p3)
	music = AudioStreamPlayer.new()
	music.name = "Music"
	music.finished.connect(_restart.bind("music"))
	music.bus = &"Music"
	music.volume_db = bank.music_volume_db
	add_child(music)
	ambience = AudioStreamPlayer.new()
	ambience.name = "Ambience"
	ambience.finished.connect(_restart.bind("ambience"))
	ambience.bus = &"Ambience"
	ambience.volume_db = bank.ambience_volume_db
	add_child(ambience)
	GameSettings.apply_volumes()


## Hook up to an expedition scene (its root holds Player, Level and Expedition).
func setup(scene_root: Node, manager: ExpeditionManager) -> void:
	_manager = manager
	_player = scene_root.get_node_or_null("Player") as PlayerController
	_start_ambience(scene_root.get_node_or_null("Level"))
	_play_music(bank.music_explore)
	if _player:
		_player.jumped.connect(func() -> void: play(&"jump"))
		_player.landed.connect(func() -> void: play(&"land"))
		var c := _player.combat
		if c:
			c.attack_started.connect(func(a: AttackDefinition, _i: int) -> void:
				if a.projectile_scene == null:
					play(&"swing", null, 0.85 if a.damage >= 20.0 else 1.0))  # Heavy = lower whoosh.
			c.hit_stopped.connect(func(seconds: float) -> void: play(&"hit_heavy" if seconds > 0.07 else &"hit"))
			c.dodge_started.connect(func(_d: Vector3) -> void: play(&"dodge"))
			c.hurt.connect(func(_info: DamageInfo) -> void: play(&"hurt"))
			c.player_died.connect(func() -> void: play(&"death"))
			c.skill_used.connect(func(_cd: float) -> void: play(&"talisman"))
	if manager:
		manager.boss_arena_entered.connect(func(_r: float) -> void: _play_music(bank.music_boss))
		manager.item_collected.connect(func(_it: ItemDefinition, _n: int) -> void: play(&"pickup"))
		manager.hunt_completed.connect(func() -> void:
			music_stopped = true
			music.stop()
			play(&"victory"))
		manager.timer_expired.connect(func() -> void:
			music_stopped = true
			music.stop()
			play(&"death"))
		var boss := manager.boss
		if boss:
			boss.awakened.connect(func() -> void: play(&"boss_roar", boss))
			boss.enraged.connect(func() -> void: play(&"boss_roar", boss, 1.15))
			boss.attack_telegraphed.connect(func(_a: BossAttackDefinition) -> void: play(&"telegraph", boss))
			boss.attack_started.connect(func(a: BossAttackDefinition) -> void:
				play(&"eruption" if a.kind == BossAttackDefinition.Kind.ERUPTIONS else &"boss_attack", boss))
			boss.part_broken.connect(func(_p: BossPartDefinition) -> void: play(&"part_break", boss))
	var tree := scene_root.get_tree()
	for e in tree.get_nodes_in_group("enemies"):
		if e is Thornling:
			var t := e as Thornling
			t.telegraph_started.connect(func(_d: Vector3) -> void: play(&"telegraph", t, 1.4, -6.0))
	for cp in scene_root.find_children("*", "Checkpoint", true, false):
		(cp as Checkpoint).activated.connect(func(_c: Checkpoint) -> void: play(&"checkpoint"))
	for z in scene_root.find_children("*", "LavaZone", true, false):
		var lz := z as LavaZone
		lz.burned.connect(func(_p: PlayerController) -> void: play(&"splash" if lz.element == &"water" else &"vent"))
	for s in tree.get_nodes_in_group("storm_callers"):
		(s as StormCaller).struck.connect(func(at: Vector3, _hit: bool) -> void: play(&"lightning", at))
	for g in tree.get_nodes_in_group("gust_zones"):
		_gusts[g] = (g as GustZone).phase
	for v in tree.get_nodes_in_group("fire_vents"):
		_vents[v] = (v as FireVent).phase


## Ambience is keyed by the biome scene file ("moonfen" for scenes/biomes/moonfen.tscn).
func _start_ambience(level: Node) -> void:
	if level == null:
		return
	var key := level.scene_file_path.get_file().get_basename()
	if bank.ambience.has(key):
		ambience.stream = bank.ambience[key]
		ambience.play()


## Ambience and music loop by restarting when they end (no engine WAV looping — see
## tools/generate_audio.gd). Stopped players (victory, timeout) are not restarted.
var music_stopped: bool = false
var loops_restarted: int = 0


func _restart(which: String) -> void:
	var p := music if which == "music" else ambience
	if p.stream == null or (which == "music" and music_stopped) or not is_inside_tree():
		return
	loops_restarted += 1
	CrashReport.note("%s loop restart" % which)
	p.play()


func _play_music(stream: AudioStream) -> void:
	if stream == null or music.stream == stream and music.playing:
		return
	music.stream = stream
	music.play()


## Play a cue. `at` = a Node3D or Vector3 for positional cues (else 2D).
func play(id: StringName, at: Variant = null, pitch: float = 1.0, extra_db: float = 0.0) -> void:
	var c := bank.cue(id) if bank else null
	if c == null or c.stream == null:
		return
	played.append(id)
	if played.size() > 64:
		played.pop_front()
	var p := pitch * (1.0 + _rng.randf_range(-c.pitch_jitter, c.pitch_jitter))
	var pos: Variant = null
	if at is Node3D and is_instance_valid(at):
		pos = (at as Node3D).global_position
	elif at is Vector3:
		pos = at
	if c.positional and pos != null:
		var s3 := _players_3d[_next_3d]
		_next_3d = (_next_3d + 1) % _players_3d.size()
		s3.stream = c.stream
		s3.volume_db = c.volume_db + extra_db
		s3.pitch_scale = p
		s3.bus = c.bus
		s3.global_position = pos
		s3.play()
	else:
		var s2 := _players_2d[_next_2d]
		_next_2d = (_next_2d + 1) % _players_2d.size()
		s2.stream = c.stream
		s2.volume_db = c.volume_db + extra_db
		s2.pitch_scale = p
		s2.bus = c.bus
		s2.play()


func count(id: StringName) -> int:
	return played.count(id)


## Footsteps follow movement, so they tick with physics (real time even when rendering stalls).
func _physics_process(delta: float) -> void:
	_update_steps(delta)


func _process(_delta: float) -> void:
	_update_polled()
	if _manager and _manager.timer.state == ExpeditionTimer.State.RUNNING:
		for w in TIMER_WARNINGS:
			if _manager.timer.remaining <= w and not _warned.has(w):
				_warned[w] = true
				play(&"timer_warning")


func _update_steps(delta: float) -> void:
	if _player == null or not _player.is_on_floor() or _player.get_horizontal_speed() < 1.5:
		_step_t = 0.0
		return
	_step_t += delta
	var gap := STEP_SPRINT if _player.get_horizontal_speed() > 8.5 else STEP_RUN
	if _step_t >= gap:
		_step_t = 0.0
		play(&"step")


## Hazards without signals: play on the phase change into WARNING (gusts) / ERUPT (vents).
func _update_polled() -> void:
	for g: GustZone in _gusts.keys():
		if g.phase != _gusts[g]:
			if g.phase == GustZone.Phase.WARNING and _player and g.global_position.distance_to(_player.global_position) < 30.0:
				play(&"gust")
			_gusts[g] = g.phase
	for v: FireVent in _vents.keys():
		if v.phase != _vents[v]:
			if v.phase == FireVent.Phase.ERUPT:
				play(&"vent", v)
			_vents[v] = v.phase


## Release every playback on the way out (scene change or quit), so no stream outlives the scene.
func _exit_tree() -> void:
	for p in _players_2d:
		p.stop()
		p.stream = null
	for p in _players_3d:
		p.stop()
		p.stream = null
	music.stop()
	music.stream = null
	ambience.stop()
	ambience.stream = null
