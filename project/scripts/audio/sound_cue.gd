class_name SoundCue
extends Resource
## One sound effect cue: the stream plus how to play it (Phase 11 audio).

@export var stream: AudioStream
@export var volume_db: float = 0.0
## Random pitch spread (+/- this fraction) so repeated sounds do not machine-gun.
@export var pitch_jitter: float = 0.05
## 3D (positional, at the source) or 2D (UI, the player's own sounds).
@export var positional: bool = false
@export var bus: StringName = &"SFX"
