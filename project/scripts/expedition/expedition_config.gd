class_name ExpeditionConfig
extends Resource
## Rules for a hunt expedition's countdown (docs/GAME_DESIGN.md "Timer rules").
## The design requires a minimum of 45 minutes per run; do not lower `duration_seconds`
## below MIN_DURATION_SECONDS without the project owner's approval.

const MIN_DURATION_SECONDS: float = 45.0 * 60.0

enum TimeoutBehavior {
	## The expedition ends ("the beast escaped") and the results screen offers Retry / Hunt board.
	END_EXPEDITION,
	## The player is sent back to their last checkpoint and the timer restarts at full length.
	RETURN_TO_CHECKPOINT,
}

@export var duration_seconds: float = MIN_DURATION_SECONDS
## Below this remaining time the HUD timer turns amber.
@export var warning_seconds: float = 300.0
## Below this remaining time the HUD timer turns red and pulses.
@export var critical_seconds: float = 60.0
@export var timeout_behavior: TimeoutBehavior = TimeoutBehavior.END_EXPEDITION
## Command-line flag that overrides the duration for testing only, e.g. `-- --expedition-seconds=90`.
@export var debug_override_flag: String = "--expedition-seconds="


## Duration to use for this run, honouring a debug command-line override.
## Returns [seconds, is_debug_override].
func resolve_duration(cmdline_args: PackedStringArray) -> Array:
	for arg in cmdline_args:
		if arg.begins_with(debug_override_flag):
			var v := arg.trim_prefix(debug_override_flag).to_float()
			if v > 0.0:
				return [v, true]
	return [maxf(duration_seconds, MIN_DURATION_SECONDS), false]
