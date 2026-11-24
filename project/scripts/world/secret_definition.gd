class_name SecretDefinition
extends Resource
## Phase 13 part 3 (secrets & exploration): one hidden spirit shrine. Placed by SecretSpots from
## its jungle's SecretSet; found once per save (PlayerProfile.secrets_found).

enum Kind {
	## A carved, climbable stone pillar with the relic on top (layers world + climbable).
	PILLAR,
	## A ring of boulders with one narrow gap facing `gap_direction`; the relic sits inside.
	NOOK,
}

@export var id: StringName
@export var display_name: String = ""
## Riddle shown in the pause menu until it is found.
@export_multiline var hint: String = ""
@export var kind: Kind = Kind.PILLAR
## Ground position (x, z); the height comes from the terrain.
@export var position: Vector2 = Vector2.ZERO
## PILLAR: height of the pillar (metres). NOOK: unused.
@export var height: float = 5.0
## NOOK: the side the gap opens towards (usually the route).
@export var gap_direction: Vector2 = Vector2(1, 0)
