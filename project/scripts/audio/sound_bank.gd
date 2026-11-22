class_name SoundBank
extends Resource
## All game audio, as data (Phase 11). Every sound is synthesized by tools/generate_audio.gd —
## original content, no third-party files (assets/ASSET_LEDGER.md).

## Cue id -> SoundCue.
@export var cues: Dictionary = {}
## Biome scene file name (e.g. "moonfen" for scenes/biomes/moonfen.tscn) -> looping ambience.
@export var ambience: Dictionary = {}
@export var music_explore: AudioStream
@export var music_boss: AudioStream
@export var music_volume_db: float = -8.0
@export var ambience_volume_db: float = -10.0


func cue(id: StringName) -> SoundCue:
	return cues.get(id) as SoundCue
