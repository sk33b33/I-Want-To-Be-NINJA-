extends TestCase
## ExpeditionTimer logic and ExpeditionConfig rules (no scene needed).


func test_start_shows_full_duration() -> void:
	var t := ExpeditionTimer.new()
	t.start(2700.0)
	check(t.state == ExpeditionTimer.State.RUNNING, "running after start")
	check(ExpeditionTimer.format_time(t.remaining) == "45:00", "shows 45:00 (got %s)" % ExpeditionTimer.format_time(t.remaining))


func test_tick_counts_down_only_while_running() -> void:
	var t := ExpeditionTimer.new()
	t.tick(5.0)
	check_near(t.remaining, 0.0, 0.001, "idle timer does not move")
	t.start(100.0)
	t.tick(10.0)
	check_near(t.remaining, 90.0, 0.001, "counts down while running")
	t.pause()
	t.tick(30.0)
	check_near(t.remaining, 90.0, 0.001, "frozen while paused")
	check(t.state == ExpeditionTimer.State.PAUSED, "paused state")
	t.resume()
	t.tick(5.0)
	check_near(t.remaining, 85.0, 0.001, "continues after resume")


func test_stop_is_final_and_reports_remaining() -> void:
	var t := ExpeditionTimer.new()
	var stopped_with := [-1.0]
	t.stopped.connect(func(r: float) -> void: stopped_with[0] = r)
	t.start(100.0)
	t.tick(40.0)
	t.stop()
	check(t.state == ExpeditionTimer.State.STOPPED, "stopped state")
	check_near(stopped_with[0], 60.0, 0.001, "stop reports remaining time")
	t.tick(500.0)
	t.resume()
	t.tick(500.0)
	check_near(t.remaining, 60.0, 0.001, "no ticking, resuming or expiring after stop")
	check(t.state == ExpeditionTimer.State.STOPPED, "still stopped")


func test_expires_once_at_zero() -> void:
	var t := ExpeditionTimer.new()
	var count := [0]
	t.expired.connect(func() -> void: count[0] += 1)
	t.start(3.0)
	t.tick(2.0)
	check(count[0] == 0, "not expired early")
	t.tick(5.0)
	t.tick(5.0)
	check(count[0] == 1, "expired exactly once (got %d)" % count[0])
	check_near(t.remaining, 0.0, 0.001, "clamped at zero")
	check(t.state == ExpeditionTimer.State.EXPIRED, "expired state")
	t.stop()
	check(t.state == ExpeditionTimer.State.EXPIRED, "stop after expiry changes nothing")


func test_paused_timer_can_be_stopped_by_arena_entry() -> void:
	var t := ExpeditionTimer.new()
	t.start(60.0)
	t.pause()
	t.stop()
	check(t.state == ExpeditionTimer.State.STOPPED, "stop works from paused")


func test_format_time() -> void:
	check(ExpeditionTimer.format_time(0.0) == "00:00", "zero")
	check(ExpeditionTimer.format_time(0.2) == "00:01", "rounds up partial seconds")
	check(ExpeditionTimer.format_time(59.0) == "00:59", "59 s")
	check(ExpeditionTimer.format_time(61.0) == "01:01", "61 s")
	check(ExpeditionTimer.format_time(2699.5) == "45:00", "just under 45 min still reads 45:00")
	check(ExpeditionTimer.format_time(4500.0) == "75:00", "over an hour keeps counting minutes")
	check(ExpeditionTimer.format_time(-5.0) == "00:00", "negative clamps")


func test_shipped_expedition_is_at_least_45_minutes() -> void:
	var cfg := load("res://data/expedition/default_expedition.tres") as ExpeditionConfig
	check(cfg != null, "default expedition config loads")
	check(cfg.duration_seconds >= ExpeditionConfig.MIN_DURATION_SECONDS, "design minimum of 45 minutes respected")
	for id in ["kurogale", "ashen_oni_tortoise", "nami", "raijins_echo"]:
		var hunt := load("res://data/hunts/%s.tres" % id) as HuntDefinition
		check(hunt != null and hunt.config != null, "%s has an expedition config" % id)
		if hunt and hunt.config:
			check(hunt.config.duration_seconds >= ExpeditionConfig.MIN_DURATION_SECONDS, "%s lasts at least 45 min" % id)


func test_config_never_resolves_below_minimum_without_debug_flag() -> void:
	var cfg := ExpeditionConfig.new()
	cfg.duration_seconds = 60.0
	var r := cfg.resolve_duration(PackedStringArray())
	check_near(r[0], ExpeditionConfig.MIN_DURATION_SECONDS, 0.001, "clamped up to 45 min")
	check(not r[1], "not a debug run")
	var d := cfg.resolve_duration(PackedStringArray(["--expedition-seconds=90"]))
	check_near(d[0], 90.0, 0.001, "debug flag overrides for testing")
	check(d[1], "flagged as debug")
