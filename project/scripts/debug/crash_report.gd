class_name CrashReport
extends Node
## Remote crash diagnosis (owner's Android phone, Godot app). Godot writes its log to
## user://logs/godot.log (file logging enabled for all platforms) and keeps the previous sessions
## as godot<date>.log. While the game runs, a "session open" marker exists in user://; it is
## removed on a clean exit and whenever the app goes to the background (the OS may then kill it
## quietly). If the marker is still there at the next launch, the last session crashed: the dojo
## shows the end of that session's log with a Copy button.

const LOG_DIR := "user://logs"
const TAIL_LINES := 40

static var marker_path: String = "user://session_open.marker"
## Set at launch when the previous session ended without a clean exit.
static var previous_crashed: bool = false
static var previous_log_tail: String = ""
static var _started: bool = false


## Call once when the game boots (the dojo does this when it is the main scene).
static func begin_session(tree: SceneTree) -> void:
	if _started:
		return
	_started = true
	previous_crashed = FileAccess.file_exists(marker_path)
	if previous_crashed:
		previous_log_tail = _tail(_previous_log(), TAIL_LINES)
	_write_marker()
	var watch := CrashReport.new()
	watch.name = "CrashWatch"
	watch.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(watch)
	print("[session] start %s %s | %s | quality %s" % [ProjectSettings.get_setting("application/config/version", "?"),
			OS.get_name(), OS.get_model_name(), QualityProfile.tier()])


## Breadcrumb in the log (shows up in the report if the game dies soon after).
static func note(text: String) -> void:
	print("[note] ", text)


## Tests: allow begin_session() again.
static func reset_for_tests() -> void:
	_started = false
	dismiss()


static func dismiss() -> void:
	previous_crashed = false
	previous_log_tail = ""


static func _write_marker() -> void:
	var f := FileAccess.open(marker_path, FileAccess.WRITE)
	if f:
		f.store_string(Time.get_datetime_string_from_system())
		f.close()


static func _clear_marker() -> void:
	if FileAccess.file_exists(marker_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(marker_path))


## The newest rotated log (the session before this one).
static func _previous_log() -> String:
	var newest := ""
	for f in DirAccess.get_files_at(LOG_DIR):
		if f.begins_with("godot") and f.ends_with(".log") and f != "godot.log" and f > newest:
			newest = f
	return LOG_DIR.path_join(newest) if newest != "" else ""


static func _tail(path: String, lines: int) -> String:
	if path == "" or not FileAccess.file_exists(path):
		return "(no log from the previous session was found)"
	var all := FileAccess.get_file_as_string(path).strip_edges().split("\n")
	return "\n".join(all.slice(maxi(all.size() - lines, 0)))


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_EXIT_TREE:
			CrashReport._clear_marker()
		NOTIFICATION_APPLICATION_RESUMED:
			CrashReport._write_marker()
