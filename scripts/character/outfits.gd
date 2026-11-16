@tool
class_name Outfits
extends RefCounted
## The starting outfits offered by the character creator. Each is a set of wearable items
## (Wearables / ItemData with category "clothing") that a new character starts out wearing.

## preset id -> [label, wearable item ids]
const PRESETS := {
	&"outfit_street_runner": ["Street-runner jacket", [&"wear_runner_jacket", &"wear_cargo_pants", &"wear_sneakers"]],
	&"outfit_corporate": ["Corporate suit", [&"wear_suit_jacket", &"wear_suit_trousers", &"wear_oxfords"]],
	&"outfit_mechanic": ["Mechanic overalls", [&"wear_overalls", &"wear_work_boots"]],
	&"outfit_techwear": ["Techwear hoodie", [&"wear_tech_hoodie", &"wear_tech_joggers", &"wear_tech_gloves", &"wear_black_sneakers"]],
	&"outfit_punk": ["Punk vest", [&"wear_punk_vest", &"wear_ripped_jeans", &"wear_combat_boots"]],
}


static func ids() -> Array:
	return PRESETS.keys()


static func label(id: StringName) -> String:
	return PRESETS[id][0] if PRESETS.has(id) else "Underwear only"


static func items(id: StringName) -> Array:
	return (PRESETS[id][1] as Array).duplicate() if PRESETS.has(id) else []
