class_name ItemDB
extends RefCounted
## Every item in the game. Prices are base prices in credits (¢) per unit; merchants add their
## markup when selling and pay less when buying. Ammo is counted in rounds but traded in packs.

const CATEGORY_COLORS := {
	&"ammo": Color(1.0, 0.58, 0.12),
	&"food": Color(1.0, 0.35, 0.3),
	&"drink": Color(0.1, 0.88, 1.0),
	&"medical": Color(0.45, 1.0, 0.3),
	&"junk": Color(0.6, 0.6, 0.65),
	&"valuable": Color(1.0, 0.85, 0.2),
	&"cyberware": Color(0.62, 0.28, 1.0),
}

const ITEMS := {
	&"ammo_ks47": {"name": "KS-47 rounds", "category": &"ammo", "price": 2, "pack": 30, "desc": "7.62 caseless, boxed in thirties."},
	&"noodles": {"name": "Neon Ramen Bowl", "category": &"food", "price": 18, "desc": "Synth-pork broth. Glows faintly."},
	&"sushi": {"name": "Sushi Set", "category": &"food", "price": 26, "desc": "Eight pieces, mostly real fish."},
	&"onigiri": {"name": "Onigiri", "category": &"food", "price": 7, "desc": "Rice triangle, kelp filling."},
	&"synth_soda": {"name": "Synth-Soda", "category": &"drink", "price": 6, "desc": "Tastes like blue."},
	&"volt_can": {"name": "Volt Energy", "category": &"drink", "price": 9, "desc": "Legal in most districts."},
	&"sake": {"name": "Cheap Sake", "category": &"drink", "price": 22, "desc": "Rice spirit from a vat in Ward 3."},
	&"med_patch": {"name": "Med Patch", "category": &"medical", "price": 40, "desc": "Stick on, bleed less."},
	&"focus_stim": {"name": "Focus Stim", "category": &"medical", "price": 75, "desc": "Sharp edges for one hour."},
	&"scrap": {"name": "Scrap Metal", "category": &"junk", "price": 4, "desc": "Somebody will melt it down."},
	&"burnt_chip": {"name": "Burnt Chip", "category": &"junk", "price": 12, "desc": "The gold traces are still worth something."},
	&"data_shard": {"name": "Data Shard", "category": &"junk", "price": 35, "desc": "Encrypted. Brokers pay for the maybe."},
	&"deck_board": {"name": "Cracked Deck Board", "category": &"junk", "price": 60, "desc": "Cyberdeck mainboard, one crack too many."},
	&"lucky_cat": {"name": "Lucky Cat Charm", "category": &"valuable", "price": 45, "desc": "Waves at you. Probably lucky."},
	&"vinyl": {"name": "Pre-Collapse Vinyl", "category": &"valuable", "price": 95, "desc": "Nobody owns a player. Everybody wants one."},
	&"gold_lighter": {"name": "Gold-Plated Lighter", "category": &"valuable", "price": 110, "desc": "Engraved initials, not yours."},
	&"jade_koi": {"name": "Jade Koi Figurine", "category": &"valuable", "price": 180, "desc": "Old, green, heavy."},
	&"optic_lens": {"name": "Optic Lens Mk.II", "category": &"cyberware", "price": 220, "desc": "Low-light zoom. Fits most sockets."},
	&"neural_implant": {"name": "Used Neural Implant", "category": &"cyberware", "price": 260, "desc": "Previous owner's settings included."},
	&"reflex_wire": {"name": "Reflex Wire Kit", "category": &"cyberware", "price": 340, "desc": "Faster hands. Twitchier nights."},
}


static func has(id: StringName) -> bool:
	return ITEMS.has(id)


static func display_name(id: StringName) -> String:
	return ITEMS[id]["name"] if ITEMS.has(id) else String(id)


static func category(id: StringName) -> StringName:
	return ITEMS[id]["category"] if ITEMS.has(id) else &"junk"


static func base_price(id: StringName) -> int:
	return ITEMS[id]["price"] if ITEMS.has(id) else 1


## How many units change hands per trade (30 rounds of ammo, otherwise 1).
static func pack_size(id: StringName) -> int:
	return ITEMS[id].get("pack", 1) if ITEMS.has(id) else 1


static func description(id: StringName) -> String:
	return ITEMS[id]["desc"] if ITEMS.has(id) else ""


static func color(id: StringName) -> Color:
	return CATEGORY_COLORS.get(category(id), Color.WHITE)
