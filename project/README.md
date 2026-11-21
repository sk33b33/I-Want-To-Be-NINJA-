# Godot project — I want to be NINJA

Godot **4.5** (validated with 4.5.1-stable), GDScript, `gl_compatibility` renderer (runs on phones and PCs).

## Run it on a PC
1. Install Godot 4.5.x (standard build, not .NET) from https://godotengine.org/download.
2. Godot Project Manager → **Import** → pick `project/project.godot`.
3. Press **F5**. Click the window to capture the mouse.
   - Try the phone controls on a PC: Project → Project Settings → General → Editor → Run → Main Run Args = `-- --touch`
     (or run `godot --path project -- --touch`).

## Run it on an Android phone
1. In Godot: Editor → **Manage Export Templates** → Download and install.
2. Install the Android SDK/JDK 17 as described in Godot's "Exporting for Android" doc, and set their paths in Editor Settings → Export → Android.
3. Project → **Export** → Add… → **Android**. Keep defaults (landscape is already set in project settings).
4. With the phone in USB-debugging mode, click the Android "Remote Debug / One-click deploy" icon in the editor toolbar,
   or export an `.apk` and install it on the phone.

## Layout
```text
data/        tunable Resources (.tres): player movement, camera
scenes/      main/, player/, biomes/ (Verdant Canopy graybox), tests/ (boot test)
scripts/     player/, camera/, ui/ (HUD, touch controls), main/, tests/
tests/       headless test runner + suites
```

## Checks
From the repo root: `GODOT=/path/to/godot tools/check.sh` (import, boot test, test suite, smoke run).
