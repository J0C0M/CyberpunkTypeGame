extends Node
## Global game events (autoload "EventBus"). Anything can emit; NPCs, merchants and the HUD listen.

## How alarming an event is. Panic lasts longer and spreads further the higher it is.
const SEVERITY_IMPACT := 0.6
const SEVERITY_SHOT := 1.0
const SEVERITY_DEATH := 2.0
const SEVERITY_EXPLOSION := 3.0

## Something dangerous happened at `position`: gunfire, a bullet impact, a body, an explosion.
## People inside `radius` react. `source` is who caused it (usually the player), may be null.
signal danger(position: Vector3, radius: float, severity: float, source: Node)
## A person (NPC or merchant) died.
signal person_killed(person: Node, hit: HitInfo)


func emit_danger(position: Vector3, radius: float, severity: float, source: Node = null) -> void:
	danger.emit(position, radius, severity, source)
