---
name: godot-workflow
description: Safe workflow for implementing and validating Godot 4 projects with Claude Code.
---
1. Inspect project and current phase before editing.
2. Read architecture docs and relevant agent profile.
3. Confirm Godot version and available executable.
4. Prefer small scene/script changes with typed GDScript and signals.
5. Do not invent API methods; check Godot docs or project usage when uncertain.
6. Run headless import/parse or project checks where possible.
7. Report commands and results truthfully; if Godot isn't installed, provide a manual checklist.
8. Avoid mass edits and keep the project runnable.
