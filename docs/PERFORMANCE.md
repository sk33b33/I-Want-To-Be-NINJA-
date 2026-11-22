# Performance (Phase 11)

## Agreed target (owner, 2026-11-22)
| Platform | Preset | Target |
|---|---|---|
| Mid-range Android phone (~2021, Snapdragon 7-series / Mali-G57 class) | **Low** (Auto picks it on Android) | **30 fps** |
| Typical PC | **High** (Auto picks it on PC) | **60 fps** |
| In between | Medium | 45 fps |

## Budgets per frame (worst viewpoint)
Frame rate depends on the device, so we hold the game to budgets that are set by the content and
measured the same way everywhere, and the owner confirms the frame rate on the real phone.

| Preset | Draw calls | Triangles | CPU (game code + physics) |
|---|---|---|---|
| Low | ≤ 250 | ≤ 250k | ≤ 7 ms on PC (phone CPUs ~3–4× slower → ≤ ~25 ms, under the 33 ms of 30 fps) |
| Medium | ≤ 350 | ≤ 600k | ≤ 7 ms on PC |
| High | ≤ 500 | ≤ 1.2M | ≤ 7 ms on PC |

## What each preset changes (`project/data/quality/*.tres`)
| | Low | Medium | High |
|---|---|---|---|
| 3D render scale | 0.70 | 0.85 | 1.00 |
| Moon shadows | off | 1 cascade, 32 m | 2 cascades, 55 m |
| Glow | off | on | on |
| Flora density / trees | 35% / 65% | 65% / 85% | 100% |
| Flora draw distance | 45% | 80% | 100% |
| Terrain render mesh | every 2nd height sample (¼ triangles; collision unchanged) | full | full |
| Small lights fade beyond | 22 m | 32 m | 45 m |
| Mist cards / rain drops / particle bursts | 50% / 22% / 40% | 75% / 55% / 70% | 100% |
| Lightning flash lights | off | on | on |

Choosing: dojo → **Settings** → Graphics (Auto / Low / Medium / High), or the pause menu. Command line: `-- --quality=low|medium|high`.

## Measured results (2026-11-22)
Fixed viewpoints in every jungle (spawn, mid-route at z −46, boss arena at z −106), camera facing
down the route. Render counts via `xvfb-run godot --path project -s ../tools/benchmark.gd -- --quality=<tier>`
(software renderer, so its fps is meaningless — the counts are what any GPU has to draw).

### Before (Phase 10, old LOW/HIGH switch)
| | Draw calls | Triangles |
|---|---|---|
| High | 194 – 378 | 572k – 926k |
| Low | 129 – 280 | 301k – 434k (over budget) |

Where the Low triangles went (Verdant spawn): flora 284k, moon-shadow pass 201k (the shadow pass
re-draws the scene), terrain 119k (1 m grid), route boxes 68 draw calls; small lights ~0.

### After (Phase 11 presets) — worst viewpoint per jungle
| Jungle | Low draws / tris | Medium draws / tris | High draws / tris |
|---|---|---|---|
| Verdant Canopy | 189 / 169k | 297 / 530k | 378 / 926k |
| Emberwild | 174 / 138k | 272 / 443k | 350 / 753k |
| Moonfen | 218 / 153k | 309 / 471k | 380 / 800k |
| Stormcrag | 163 / 106k | 255 / 360k | 345 / 626k |
| **Budget** | **250 / 250k ✔** | **350 / 600k ✔** | **500 / 1.2M ✔** |

Low now draws **61–83% fewer triangles** than the old Low at the same viewpoints, and roughly a
third of High. On the same (software) renderer a Low frame costs ~2.5× less than Medium and ~3×
less than High.

CPU: headless runs (`godot --headless ... benchmark.gd`) average **≤ 6.9 ms per frame in every
jungle and preset** (6.9 ms is Godot's headless frame-pacing floor, so the true cost is lower);
worst single frames 8–13 ms (one-off spikes). Physics ticks measured 1–2.4 ms.

## Gate status
**Not passed yet:** the budgets are met, but the target is a frame rate on the owner's phone.
To confirm: install the Android build, open the dojo → **Settings → Run benchmark** (about a
minute; tours all four jungles on the current preset). The result screen shows every viewpoint's
fps and says **TARGET MET** or **below target**; the same text is saved to `benchmark.txt` in the
app's user folder. Send that text back and this section gets the real-device row.

## Rules for new content
- Every heavy feature reads a `QualityPreset` field (and Low must cut it).
- Re-run `tools/benchmark.gd` with `--quality=low` after adding scenery; stay inside the budgets above.
- Keep shaders `gl_compatibility`-safe (no screen/depth reads); prefer MultiMesh for repeated props.
