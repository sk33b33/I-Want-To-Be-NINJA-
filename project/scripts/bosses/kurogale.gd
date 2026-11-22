class_name Kurogale
extends BossController
## Kurogale, the Thornback Stag — the Verdant Canopy hunt target (docs/PHASES.md Phase 5).
## Original creature. Nature element, weak to Fire. Breakable part: antlers.
## All behaviour is data (data/bosses/kurogale.tres) run by BossController:
##   antler_sweep (FRONT)     head lowers, antlers glow, red arc in front -> roll away / get behind
##   root_snare  (ERUPTIONS)  glowing rings under the player             -> step out of the rings
##   charge      (DASH)       paws the ground, long red strip            -> roll sideways; stuns on pillars
##   thorn_burst (RADIAL)     enraged: spines glow, red ring around it    -> leave the ring
