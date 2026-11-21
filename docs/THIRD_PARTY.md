# Third-party material

## Claude-Code-Game-Studios (MIT)
Source: https://github.com/Donchitos/Claude-Code-Game-Studios — Copyright (c) 2026 Donchitos, MIT License.
Copied (unmodified unless noted):
- `.claude/agents/godot-specialist.md`, `godot-gdscript-specialist.md`, `godot-shader-specialist.md`
- `.claude/rules/gameplay-code.md` (path list extended with `project/scripts/**`), `scene-files.md`, `test-standards.md`

The rest of that framework (its `/prototype` browser-game flow, hooks, `project.yaml`) was not installed, because this project follows the Godot phase plan in `docs/PHASES.md`. It can be added later if wanted.

## zomdroid
https://github.com/liamelui/zomdroid is an Android launcher for Project Zomboid. No code from it is used here.
Its takeaway for this project is that the game must run well on Android phones, which this
project gets from Godot's native Android export (no emulation layer needed).

## Godot Engine
Godot is MIT-licensed (https://godotengine.org/license). Exported builds must include Godot's license notice.
