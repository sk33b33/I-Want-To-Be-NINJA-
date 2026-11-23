extends TestCase
## Remote crash diagnosis: a session that did not end cleanly is detected at the next launch and
## the dojo shows the end of that session's log with a Copy button.

const MARKER := "user://test_session_open.marker"


func _reset() -> void:
	CrashReport.marker_path = MARKER
	CrashReport.reset_for_tests()
	if FileAccess.file_exists(MARKER):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MARKER))


func _done() -> void:
	for n in tree.root.get_children():
		if n is CrashReport:
			n.queue_free()
	if FileAccess.file_exists(MARKER):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MARKER))
	CrashReport.marker_path = "user://session_open.marker"
	CrashReport.reset_for_tests()


func test_clean_launch_reports_nothing_and_leaves_a_marker() -> void:
	_reset()
	CrashReport.begin_session(tree)
	check(not CrashReport.previous_crashed, "no crash after a clean exit")
	check(FileAccess.file_exists(MARKER), "session marker written while running")
	_done()


func test_marker_left_behind_means_the_last_session_crashed() -> void:
	_reset()
	var f := FileAccess.open(MARKER, FileAccess.WRITE)
	f.store_string("x")
	f.close()
	CrashReport.begin_session(tree)
	check(CrashReport.previous_crashed, "crash detected")
	check(CrashReport.previous_log_tail != "", "a log tail (or a clear 'not found' line) to show")
	_done()


func test_going_to_the_background_or_quitting_clears_the_marker() -> void:
	_reset()
	CrashReport.begin_session(tree)
	await process_frames(2)
	var watch: CrashReport = null
	for n in tree.root.get_children():
		if n is CrashReport:
			watch = n
	check(watch != null, "watcher running")
	watch.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(not FileAccess.file_exists(MARKER), "backgrounded app is not reported as a crash if the OS closes it")
	watch.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(FileAccess.file_exists(MARKER), "marker back when resumed")
	watch.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(not FileAccess.file_exists(MARKER), "clean quit")
	_done()


func test_dojo_shows_the_report_with_a_copy_button() -> void:
	_reset()
	CrashReport.previous_crashed = true
	CrashReport.previous_log_tail = "line one\nline two"
	PlayerProfile.path = "user://test_profile_crash.json"
	var board := instantiate("res://scenes/ui/hunt_board.tscn") as HuntBoard
	await process_frames(3)
	var overlay := board.get_node_or_null("CrashReport")
	check(overlay != null, "report shown")
	var copied := false
	for b in overlay.find_children("*", "Button", true, false):
		if (b as Button).text == "Copy report":
			copied = true
	check(copied, "copy button")
	PlayerProfile.path = PlayerProfile.DEFAULT_PATH
	_done()
