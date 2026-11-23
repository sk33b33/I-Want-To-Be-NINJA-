extends SceneTree
## Synthesizes every sound in the game from scratch (oscillators, filtered noise, Karplus-Strong
## plucks) and writes them as AudioStreamWAV resources plus data/audio/sound_bank.tres.
## Original content — no samples or third-party files. Deterministic (fixed seeds).
## Usage (repo root): godot --headless --path project -s ../tools/generate_audio.gd

const SR := 22050
const OUT := "res://assets/audio/"

var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	for d in ["sfx", "ambience", "music"]:
		DirAccess.make_dir_recursive_absolute(OUT + d)
	DirAccess.make_dir_recursive_absolute("res://data/audio")
	var bank := SoundBank.new()
	var specs := [
		# id, builder, volume_db, jitter, positional
		["swing", _swing, -6.0, 0.08, false],
		["hit", _hit.bind(1.0), -3.0, 0.06, true],
		["hit_heavy", _hit.bind(1.8), -1.0, 0.05, true],
		["hurt", _hurt, -4.0, 0.05, false],
		["dodge", _dodge, -7.0, 0.06, false],
		["jump", _jump, -10.0, 0.06, false],
		["land", _land, -8.0, 0.08, false],
		["step", _step, -16.0, 0.15, false],
		["talisman", _talisman, -5.0, 0.05, false],
		["telegraph", _telegraph, -4.0, 0.0, true],
		["boss_roar", _roar, -2.0, 0.04, true],
		["boss_attack", _slam, -2.0, 0.06, true],
		["part_break", _crack, 0.0, 0.03, true],
		["eruption", _eruption, -4.0, 0.08, true],
		["pickup", _pickup, -6.0, 0.0, false],
		["checkpoint", _bell, -4.0, 0.0, false],
		["ui_click", _click, -10.0, 0.05, false],
		["lightning", _lightning, -2.0, 0.08, true],
		["gust", _gust, -6.0, 0.05, false],
		["splash", _splash, -5.0, 0.08, false],
		["vent", _vent, -5.0, 0.08, true],
		["victory", _victory, -3.0, 0.0, false],
		["timer_warning", _beep, -6.0, 0.0, false],
		["death", _death, -3.0, 0.0, false],
	]
	for s in specs:
		rng.seed = hash(s[0])
		var samples: PackedFloat32Array = _fade_out((s[1] as Callable).call(), 0.02)
		var stream := _save(samples, OUT + "sfx/%s.res" % s[0], false)
		var c := SoundCue.new()
		c.stream = stream
		c.volume_db = s[2]
		c.pitch_jitter = s[3]
		c.positional = s[4]
		bank.cues[StringName(s[0])] = c
	# Keyed by biome scene file name (scenes/biomes/<key>.tscn).
	for a in [["verdant_canopy", _amb_verdant], ["emberwild", _amb_ember], ["moonfen", _amb_fen], ["stormcrag", _amb_storm]]:
		rng.seed = hash(a[0])
		bank.ambience[a[0]] = _save(_seamless((a[1] as Callable).call()), OUT + "ambience/%s.res" % a[0], true)
	rng.seed = 7
	bank.music_explore = _save(_seamless(_music_explore()), OUT + "music/explore.res", true)
	rng.seed = 8
	bank.music_boss = _save(_music_boss(), OUT + "music/boss_drums.res", true)
	ResourceSaver.save(bank, "res://data/audio/sound_bank.tres")
	print("AUDIO GENERATED: %d cues" % bank.cues.size())
	quit(0)


# ---------------------------------------------------------------- output

func _save(samples: PackedFloat32Array, path: String, loop: bool) -> AudioStreamWAV:
	var peak := 0.0001
	for v in samples:
		peak = maxf(peak, absf(v))
	var gain := 0.9 / peak
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = bytes
	# Loops are NOT marked as WAV loops: the engine's WAV loop wrap crashed the Godot app on the
	# owner's Android phone (Mali-G77 / S20) exactly when the 8 s ambience first looped.
	# AudioDirector restarts loop streams itself when they finish; `loop` only shapes the
	# content (seamless crossfaded ends).
	w.loop_mode = AudioStreamWAV.LOOP_DISABLED
	ResourceSaver.save(w, path)
	return load(path) as AudioStreamWAV


## Short fade at the end of one-shots so a ringing tail never stops with a click.
func _fade_out(s: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var n := mini(int(seconds * SR), s.size())
	for i in n:
		s[s.size() - n + i] *= 1.0 - float(i) / n
	return s


## Crossfade the tail into the head so a loop has no click.
func _seamless(s: PackedFloat32Array) -> PackedFloat32Array:
	var fade := int(SR * 0.25)
	var n := s.size() - fade
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = s[i]
	for i in fade:
		var t := float(i) / fade
		out[i] = s[i] * t + s[n + i] * (1.0 - t)
	return out


# ---------------------------------------------------------------- building blocks

func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * SR))
	return b


func _noise() -> float:
	return rng.randf_range(-1.0, 1.0)


## Attack/decay envelope (seconds), exponential decay.
func _env(t: float, attack: float, decay: float) -> float:
	if t < attack:
		return t / maxf(attack, 0.0001)
	return exp(-(t - attack) / maxf(decay, 0.0001))


## State-variable filter; returns [low, band, high] and keeps state in `st`.
func _svf(st: PackedFloat32Array, x: float, cutoff: float, q: float = 0.7) -> Vector3:
	var f := 2.0 * sin(PI * clampf(cutoff, 20.0, SR * 0.45) / SR)
	st[0] += f * st[1]
	var high := x - st[0] - q * st[1]
	st[1] += f * high
	return Vector3(st[0], st[1], high)


func _sf() -> PackedFloat32Array:
	return PackedFloat32Array([0.0, 0.0])


## Filtered-noise whoosh: band sweep from f0 to f1 over the sound.
func _whoosh(seconds: float, f0: float, f1: float, attack: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	var st := _sf()
	for i in b.size():
		var t := float(i) / SR
		var k := t / seconds
		var env := sin(PI * pow(minf(k / (attack / seconds) * 0.5, 1.0) if k < attack / seconds else 0.5 + 0.5 * (k - attack / seconds) / (1.0 - attack / seconds), 1.0))
		b[i] = _svf(st, _noise(), lerpf(f0, f1, k), 0.5).y * env
	return b


## Decaying sine with pitch glide (drums, thumps).
func _thump(seconds: float, f0: float, f1: float, decay: float, noise_amt: float = 0.3) -> PackedFloat32Array:
	var b := _buf(seconds)
	var phase := 0.0
	var st := _sf()
	for i in b.size():
		var t := float(i) / SR
		var f := lerpf(f1, f0, exp(-t / (decay * 0.5)))
		phase += TAU * f / SR
		var n := _svf(st, _noise(), 900.0).x * exp(-t / 0.03) * noise_amt
		b[i] = (sin(phase) * exp(-t / decay)) + n
	return b


## Bell/chime partials.
func _tone(b: PackedFloat32Array, start: float, freq: float, decay: float, amp: float, partials: Array = [[1.0, 1.0]]) -> void:
	var s0 := int(start * SR)
	for i in range(s0, b.size()):
		var t := float(i - s0) / SR
		var v := 0.0
		for p in partials:
			v += sin(TAU * freq * float(p[0]) * t) * float(p[1]) * exp(-t / (decay / float(p[0]) * 1.5))
		b[i] += v * amp * minf(t / 0.004, 1.0)


## Karplus-Strong plucked string (koto-like).
func _pluck(b: PackedFloat32Array, start: float, freq: float, amp: float, damping: float = 0.996) -> void:
	var period := maxi(2, int(SR / freq))
	var line := PackedFloat32Array()
	line.resize(period)
	for i in period:
		line[i] = _noise()
	var s0 := int(start * SR)
	var idx := 0
	var n := mini(b.size() - s0, int(SR * 3.0))
	for i in n:
		var a := line[idx]
		var c := line[(idx + 1) % period]
		line[idx] = (a + c) * 0.5 * damping
		b[s0 + i] += a * amp
		idx = (idx + 1) % period


func _mix(a: PackedFloat32Array, bsig: PackedFloat32Array, gain: float = 1.0, offset: float = 0.0) -> PackedFloat32Array:
	var o := int(offset * SR)
	for i in bsig.size():
		if o + i < a.size():
			a[o + i] += bsig[i] * gain
	return a


# ---------------------------------------------------------------- sound effects

func _swing() -> PackedFloat32Array:
	return _whoosh(0.24, 600.0, 2800.0, 0.06)


func _hit(weight: float) -> PackedFloat32Array:
	var b := _thump(0.25 * weight, 130.0 / weight, 55.0 / weight, 0.07 * weight, 0.6)
	var st := _sf()
	for i in int(0.03 * SR):  # Bright slice transient.
		b[i] += _svf(st, _noise(), 4000.0).z * (1.0 - float(i) / (0.03 * SR)) * 0.6
	return b


func _hurt() -> PackedFloat32Array:
	var b := _buf(0.35)
	var st := _sf()
	var phase := 0.0
	for i in b.size():
		var t := float(i) / SR
		phase += TAU * lerpf(220.0, 120.0, t / 0.35) / SR
		var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
		b[i] = _svf(st, saw * 0.7 + _noise() * 0.3, 700.0, 0.3).y * _env(t, 0.01, 0.12)
	return b


func _dodge() -> PackedFloat32Array:
	return _whoosh(0.38, 300.0, 1400.0, 0.12)


func _jump() -> PackedFloat32Array:
	return _whoosh(0.18, 500.0, 1800.0, 0.04)


func _land() -> PackedFloat32Array:
	return _thump(0.16, 90.0, 50.0, 0.05, 0.8)


func _step() -> PackedFloat32Array:
	var b := _buf(0.07)
	var st := _sf()
	for i in b.size():
		var t := float(i) / SR
		b[i] = _svf(st, _noise(), 1400.0).x * _env(t, 0.003, 0.02)
	return b


func _talisman() -> PackedFloat32Array:
	var b := _buf(0.55)
	var st := _sf()
	var st2 := _sf()
	for i in b.size():
		var t := float(i) / SR
		var flutter := (0.5 + 0.5 * sin(TAU * 38.0 * t)) * exp(-t / 0.12)
		var roar := _svf(st2, _noise(), lerpf(300.0, 1600.0, t / 0.55)).y * sin(PI * t / 0.55)
		b[i] = _svf(st, _noise(), 3000.0).y * flutter * 0.6 + roar
	return b


## The "danger" cue for every boss/enemy telegraph: a rising two-tone chime with tremolo.
func _telegraph() -> PackedFloat32Array:
	var b := _buf(0.5)
	for i in b.size():
		var t := float(i) / SR
		var f := 520.0 if t < 0.16 else 780.0
		var trem := 0.75 + 0.25 * sin(TAU * 18.0 * t)
		b[i] = (sin(TAU * f * t) + 0.35 * sin(TAU * f * 2.0 * t)) * trem * _env(fmod(t, 0.16) if t < 0.16 else t - 0.16, 0.005, 0.14 if t < 0.16 else 0.22)
	return b


func _roar() -> PackedFloat32Array:
	var b := _buf(1.4)
	var st := _sf()
	var st2 := _sf()
	var phase := 0.0
	for i in b.size():
		var t := float(i) / SR
		phase += TAU * (85.0 + 8.0 * sin(TAU * 6.0 * t) - 20.0 * t) / SR
		var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
		var growl := _svf(st, saw, 600.0 + 300.0 * sin(PI * t / 1.4), 0.4).y
		var breath := _svf(st2, _noise(), 1200.0).y * 0.4
		b[i] = (growl + breath) * sin(PI * minf(t / 1.4 * 1.3, 1.0)) * minf((1.4 - t) * 4.0, 1.0)
	return b


func _slam() -> PackedFloat32Array:
	var b := _thump(0.8, 70.0, 38.0, 0.22, 0.2)
	var st := _sf()
	for i in b.size():
		var t := float(i) / SR
		b[i] += _svf(st, _noise(), 250.0).x * exp(-t / 0.3) * 1.5
	return b


func _crack() -> PackedFloat32Array:
	var b := _buf(0.6)
	var st := _sf()
	for i in b.size():
		var t := float(i) / SR
		b[i] = _svf(st, _noise(), 2500.0, 0.2).z * exp(-t / 0.04)
	_tone(b, 0.0, 1180.0, 0.18, 0.5, [[1.0, 1.0], [2.7, 0.4]])
	for k in 8:  # Debris.
		var at := rng.randf_range(0.05, 0.45)
		_mix(b, _thump(0.05, 900.0, 600.0, 0.01, 0.5), 0.3, at)
	return b


func _eruption() -> PackedFloat32Array:
	var b := _buf(0.75)
	var st := _sf()
	var st2 := _sf()
	for i in b.size():
		var t := float(i) / SR
		var rumble := _svf(st, _noise(), 180.0).x * 2.5
		var hiss := _svf(st2, _noise(), 3500.0).z * 0.25
		b[i] = (rumble + hiss) * _env(t, 0.05, 0.3)
	return b


func _pickup() -> PackedFloat32Array:
	var b := _buf(0.5)
	_tone(b, 0.0, 659.3, 0.25, 0.6, [[1.0, 1.0], [2.76, 0.3]])
	_tone(b, 0.09, 880.0, 0.35, 0.6, [[1.0, 1.0], [2.76, 0.3]])
	return b


func _bell() -> PackedFloat32Array:
	var b := _buf(1.6)
	_tone(b, 0.0, 392.0, 1.2, 0.7, [[1.0, 1.0], [2.0, 0.5], [3.0, 0.25], [4.2, 0.2], [5.4, 0.1]])
	return b


func _click() -> PackedFloat32Array:
	var b := _buf(0.05)
	_tone(b, 0.0, 1800.0, 0.01, 0.8)
	return b


func _lightning() -> PackedFloat32Array:
	var b := _buf(1.5)
	var st := _sf()
	var st2 := _sf()
	for i in b.size():
		var t := float(i) / SR
		var crack := _svf(st, _noise(), 5000.0, 0.3).z * exp(-t / 0.035) * 1.4
		var rumble := _svf(st2, _noise(), 140.0).x * (1.0 - exp(-t / 0.05)) * exp(-t / 0.5) * 4.0
		b[i] = crack + rumble
	return b


func _gust() -> PackedFloat32Array:
	return _whoosh(1.2, 200.0, 900.0, 0.4)


func _splash() -> PackedFloat32Array:
	var b := _buf(0.55)
	var st := _sf()
	for i in b.size():
		var t := float(i) / SR
		b[i] = _svf(st, _noise(), 1200.0, 0.5).y * _env(t, 0.005, 0.12)
	for k in 6:
		var at := rng.randf_range(0.08, 0.45)
		var f := rng.randf_range(500.0, 1100.0)
		var s0 := int(at * SR)
		for i in int(0.04 * SR):
			if s0 + i < b.size():
				var t := float(i) / SR
				b[s0 + i] += sin(TAU * (f + 6000.0 * t) * t) * exp(-t / 0.01) * 0.3
	return b


func _vent() -> PackedFloat32Array:
	var b := _eruption()
	var st := _sf()
	for i in b.size():
		b[i] += _svf(st, _noise(), 2200.0).y * 0.4 * exp(-float(i) / SR / 0.4)
	return b


func _victory() -> PackedFloat32Array:
	var b := _buf(2.6)
	var notes := [293.7, 349.2, 392.0, 440.0, 523.3, 587.3]  # D minor pentatonic rising.
	for i in notes.size():
		_pluck(b, i * 0.14, notes[i], 0.5)
	_pluck(b, 0.95, 587.3, 0.4)
	_pluck(b, 0.95, 440.0, 0.35)
	_pluck(b, 0.95, 293.7, 0.35)
	return b


func _beep() -> PackedFloat32Array:
	var b := _buf(0.32)
	_tone(b, 0.0, 988.0, 0.05, 0.6)
	_tone(b, 0.16, 988.0, 0.05, 0.6)
	return b


func _death() -> PackedFloat32Array:
	var b := _buf(1.2)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / SR
		phase += TAU * lerpf(220.0, 70.0, t / 1.2) / SR
		b[i] = (sin(phase) + 0.3 * sin(phase * 2.0)) * _env(t, 0.02, 0.45)
	return b


# ---------------------------------------------------------------- ambience (loops)

func _wind(b: PackedFloat32Array, amount: float, cutoff: float, speed: float) -> void:
	var st := _sf()
	for i in b.size():
		var t := float(i) / SR
		var lfo := 0.6 + 0.4 * sin(TAU * speed * t) * sin(TAU * speed * 0.37 * t + 1.0)
		b[i] += _svf(st, _noise(), cutoff * (0.7 + 0.5 * lfo)).y * amount * lfo


func _amb_verdant() -> PackedFloat32Array:
	var b := _buf(8.25)
	_wind(b, 0.6, 500.0, 0.25)
	for k in 26:  # Crickets: short 4.6 kHz chirp trains.
		var at := rng.randf_range(0.0, 7.6)
		for c in 3:
			var s0 := int((at + c * 0.045) * SR)
			for i in int(0.03 * SR):
				if s0 + i < b.size():
					var t := float(i) / SR
					b[s0 + i] += sin(TAU * 4600.0 * t) * sin(PI * t / 0.03) * 0.12
	return b


func _amb_ember() -> PackedFloat32Array:
	var b := _buf(8.25)
	var st := _sf()
	for i in b.size():
		var t := float(i) / SR
		b[i] = _svf(st, _noise(), 90.0).x * (2.2 + 0.8 * sin(TAU * 0.2 * t))
	for k in 140:  # Crackles.
		var s0 := int(rng.randf_range(0.0, 8.1) * SR)
		var amp := rng.randf_range(0.05, 0.35)
		for i in int(0.006 * SR):
			if s0 + i < b.size():
				b[s0 + i] += _noise() * amp * (1.0 - float(i) / (0.006 * SR))
	return b


func _amb_fen() -> PackedFloat32Array:
	var b := _buf(8.25)
	_wind(b, 0.25, 400.0, 0.15)
	for k in 9:  # Frogs: pulsed low croaks.
		var at := rng.randf_range(0.0, 7.3)
		var f := rng.randf_range(130.0, 210.0)
		var s0 := int(at * SR)
		for i in int(0.45 * SR):
			if s0 + i < b.size():
				var t := float(i) / SR
				var pulse := maxf(sin(TAU * 22.0 * t), 0.0)
				b[s0 + i] += (sin(TAU * f * t) + 0.5 * sin(TAU * f * 2.0 * t)) * pulse * sin(PI * t / 0.45) * 0.3
	for k in 16:  # Drips.
		_tone(b, rng.randf_range(0.0, 8.0), rng.randf_range(1100.0, 1900.0), 0.05, 0.12)
	return b


func _amb_storm() -> PackedFloat32Array:
	var b := _buf(8.25)
	var st := _sf()
	for i in b.size():
		b[i] = _svf(st, _noise(), 2500.0).z * 0.5  # Rain hiss.
	_wind(b, 0.9, 350.0, 0.3)
	for k in 400:  # Patter.
		var s0 := int(rng.randf_range(0.0, 8.2) * SR)
		var amp := rng.randf_range(0.02, 0.1)
		for i in int(0.003 * SR):
			if s0 + i < b.size():
				b[s0 + i] += _noise() * amp
	return b


# ---------------------------------------------------------------- music (loops)

## Exploration: a low two-note drone with sparse koto plucks in D minor pentatonic.
func _music_explore() -> PackedFloat32Array:
	var b := _buf(16.25)
	var st := _sf()
	for i in b.size():
		var t := float(i) / SR
		var drone := sin(TAU * 73.4 * t) * 0.5 + sin(TAU * 110.0 * t + 0.3 * sin(TAU * 0.1 * t)) * 0.35
		b[i] = _svf(st, drone, 300.0).x * (0.8 + 0.2 * sin(TAU * 0.0625 * t))
	var scale := [146.8, 174.6, 196.0, 220.0, 261.6, 293.7, 349.2]
	var beat := 0.75
	for k in 21:
		if rng.randf() < 0.55:
			_pluck(b, k * beat, scale[rng.randi_range(0, scale.size() - 1)], 0.45, 0.995)
	return b


## Boss: a taiko pattern at 120 bpm (8 s), big drums, rim clicks and a low pulse. Rendered with
## a second of spare tail that is folded back onto the start, so the loop rings on seamlessly.
func _music_boss() -> PackedFloat32Array:
	var b := _buf(9.0)
	var eighth := 0.25
	var pattern := "X.x.X.x.X.xxX.x.X.x.X.x.XxX.X.xx"  # X big drum, x small drum, . rest
	for i in pattern.length():
		var at := i * eighth
		match pattern[i]:
			"X": _mix(b, _thump(0.6, 95.0, 48.0, 0.18, 0.5), 1.0, at)
			"x": _mix(b, _thump(0.25, 180.0, 120.0, 0.06, 0.6), 0.5, at)
		if i % 2 == 1:  # Shime rim clicks on the off-beats.
			var c := _buf(0.04)
			_tone(c, 0.0, 2400.0, 0.008, 0.6)
			_mix(b, c, 0.3, at)
	for k in 16:  # Low pulse.
		_pluck(b, k * 0.5, 73.4, 0.25, 0.99)
	var n := 8 * SR
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = b[i]
	for i in range(n, b.size()):
		out[i - n] += b[i]
	return out
