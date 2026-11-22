class_name ExpeditionTimer
extends RefCounted
## Pure countdown logic for a hunt expedition (no nodes, fully unit-testable).
## States: IDLE -> RUNNING <-> PAUSED -> STOPPED (boss arena reached) or EXPIRED (time ran out).
## STOPPED and EXPIRED are final for the run: further ticks, pauses and resumes are ignored.
##
## Transition table:
##   IDLE    --start-->   RUNNING
##   RUNNING --pause-->   PAUSED     PAUSED --resume--> RUNNING
##   RUNNING/PAUSED --stop-->  STOPPED (emits stopped(remaining))
##   RUNNING --tick reaches 0--> EXPIRED (emits expired once)

signal started(duration: float)
signal paused
signal resumed
signal stopped(remaining: float)
signal expired

enum State { IDLE, RUNNING, PAUSED, STOPPED, EXPIRED }

var state: State = State.IDLE
var duration: float = 0.0
var remaining: float = 0.0


func start(seconds: float) -> void:
	duration = maxf(seconds, 0.0)
	remaining = duration
	state = State.RUNNING
	started.emit(duration)


## Advance by `delta` seconds. Only counts down while RUNNING.
func tick(delta: float) -> void:
	if state != State.RUNNING or delta <= 0.0:
		return
	remaining = maxf(remaining - delta, 0.0)
	if remaining <= 0.0:
		state = State.EXPIRED
		expired.emit()


func pause() -> void:
	if state == State.RUNNING:
		state = State.PAUSED
		paused.emit()


func resume() -> void:
	if state == State.PAUSED:
		state = State.RUNNING
		resumed.emit()


## Permanently stop the countdown for this run (boss arena entered).
func stop() -> void:
	if state == State.RUNNING or state == State.PAUSED:
		state = State.STOPPED
		stopped.emit(remaining)


func is_active() -> bool:
	return state == State.RUNNING or state == State.PAUSED


func elapsed() -> float:
	return duration - remaining


## "MM:SS" (minutes can exceed 59, e.g. "75:00"). Rounds up so 0.2 s left still shows "00:01".
static func format_time(seconds: float) -> String:
	var total := int(ceil(maxf(seconds, 0.0)))
	return "%02d:%02d" % [total / 60, total % 60]
