# Asset Ledger

No external assets have been added. Record every asset and license here before integrating it. Do not use ripped game assets, copyrighted characters, or unlicensed packs.

## Reference-only material (not shipped in the game)
| File | Source | License | Use |
|---|---|---|---|
| `docs/concept-art/verdant_canopy.jpg` | Supplied by project owner | Unknown — image carries an "Unreal Engine 5 Tech Demo" watermark; treat as third-party | Mood reference for Verdant Canopy only |
| `docs/concept-art/emberwild.jpg` | Supplied by project owner | Unknown | Mood reference for Emberwild only |
| `docs/concept-art/moonfen.jpg` | Supplied by project owner | Unknown | Mood reference for Moonfen only |
| `docs/concept-art/stormcrag.jpg` | Supplied by project owner | Unknown | Mood reference for Stormcrag only |

Do not import these into `project/` or trace them for in-game art until their license is confirmed.

## In-game assets
| Asset | File | Source | License / terms | Modifications | Use |
|---|---|---|---|---|---|
| Ninja player character + 15 animations (Crouch_Walk, Dual_Weapon_Combo, Front_Flip, Front_Flip_2, Jump, Quick_Roll_To_Run, Run, Sprint, Death_Backward; added 2026-11-23: Climb_Up_Wall, Climb_Down_Wall, Climb_On, Draw_Sword, Sheath_Sword, Sprint_To_Wall_Climb) | `project/assets/models/ninja/ninja.glb` | Made by the project owner on Adobe Mixamo (stock character "Ch24") | Mixamo terms: royalty-free use in games (commercial and non-commercial). The raw character/animation files must **not** be redistributed on their own — if this repository is public, consider moving the GLB to private storage or Git LFS in a private repo. | Root motion removed from Jump/Front_Flip and hips rise clamped at runtime; climb clips detrended to loop in place, Climb_On pull-up slice fitted to the mantle (`NinjaAnimator`); Idle pose generated from Jump frame 0 | Player model |

| All sound effects (24), biome ambience loops (4) and music (exploration theme, boss taiko drums, victory sting) | `project/assets/audio/**.res`, cues in `project/data/audio/sound_bank.tres` | **Original** — synthesized from scratch by our own tool `tools/generate_audio.gd` (oscillators, filtered noise, Karplus-Strong plucks; fixed seeds, regenerate any time) | Ours; no third-party samples or recordings | — | All game audio |
| Ground, rock, stone and bark textures (5 sets: colour + normal map): `forest_floor` = ambientCG **Ground037**, `mud_path` = **Ground071**, `cliff_rock` = **Rock030**, `stone_blocks` = **Rock064**, `bark` = **Bark016** | `project/assets/textures/cc0/*_albedo.jpg`, `*_normal.jpg` | [ambientCG](https://ambientcg.com) (downloaded 2026-11-23, 1K-JPG) | **CC0 1.0** (public domain; no attribution required, commercial use allowed) | Colour kept at 1024², normal (OpenGL) map downscaled to 512²; recoloured in-game by each jungle's palette (`terrain.gdshader`, `include/textured_triplanar.gdshaderinc`) | Terrain, route stone, ruins, climb walls, basalt, reed rafts (art pass stage 1) |
| Leaf-spray sprite (RGBA, 512²) | `project/assets/textures/cc0/leaf_spray.png` | Composited by our offline script `tools/art/leaf_cluster.py` from ambientCG **LeafSet024** and **LeafSet022** (downloaded 2026-11-23, 1K-PNG) | **CC0 1.0** (source leaves); the composite is ours | ~120 leaves cut out by their opacity masks, scaled, rotated outward, shaded darker toward the middle, colour bled into transparent pixels | Canopy leaf cards (`leaf_card.gdshader`, Medium/High) and canopy-core leaf detail (`foliage.gdshader`, all tiers) — art pass stage 2 |
| Beast skin textures (colour + normal map): `scales` = ambientCG **Leather008** (crocodile), `hide` = **Leather030** | `project/assets/textures/cc0/scales_*.jpg`, `hide_*.jpg` | [ambientCG](https://ambientcg.com) (downloaded 2026-11-24, 1K-JPG) | **CC0 1.0** | Colour 1024², normal 512²; recoloured per beast in `creature.gdshader` (beasts also reuse `bark` and `cliff_rock`) | Beast skins (art pass stage 4) |
| Amazon-inspired jungle trees (7 models: 3 young, 4 mature; FBX) + their bark/leaf atlas (`UVMap.png`, downsized to 1024²) | `project/assets/models/cc0/amazon_trees/` | [OpenGameArt: Amazon Inspired Tree](https://opengameart.org/content/amazon-inspired-tree) by FabinhoSC (downloaded 2026-11-25) | **CC0 1.0** (the page's licence; author states public domain) | Meshes baked at load: node transforms applied, scaled to tree height, re-centred on the trunk, one shared material; atlas tinted per jungle (`model_foliage.gdshader`); Low uses the 3 lightest variants | Big jungle trees in the Verdant Canopy (art pass 5A; other jungles to follow) |
| App icon (masked ninja and moon) | `project/icon.svg` | **Original** — drawn for this project (Phase 12) | Ours | — | Window / launcher icon |

Everything else in the game (the four Phase 13 beasts — mantis, salamander, toad, wolf — built from primitives in `procedural_meshes.gd` by `tools/generate_beasts.gd`, terrain, trees, plants, rocks, ruins, bats, frogs, eyes, water, sky, mist) is **procedurally generated by our own code** in `project/scripts/world/` and `project/shaders/` — no third-party assets.
