class_name ShopCatalog
extends RefCounted
## What each kind of merchant sells and buys. `stock` is what they restock to every night,
## `credits` their cash float, `likes` the item categories they pay a fair price for (anything
## else they buy cheaply, if at all), `markup` and `buyback` scale ItemDB base prices.

const PROFILES := {
	&"noodles": {
		"stock": {&"noodles": 12, &"onigiri": 10, &"synth_soda": 16, &"volt_can": 8},
		"credits": 450, "likes": [&"food", &"drink"], "markup": 1.15, "buyback": 0.45,
	},
	&"sushi": {
		"stock": {&"sushi": 10, &"onigiri": 8, &"synth_soda": 12, &"sake": 4},
		"credits": 500, "likes": [&"food", &"drink"], "markup": 1.2, "buyback": 0.45,
	},
	&"bar": {
		"stock": {&"sake": 10, &"synth_soda": 14, &"volt_can": 12, &"lucky_cat": 1},
		"credits": 650, "likes": [&"drink", &"valuable"], "markup": 1.3, "buyback": 0.5,
	},
	&"cyberware": {
		"stock": {&"optic_lens": 2, &"neural_implant": 2, &"reflex_wire": 1, &"focus_stim": 3},
		"credits": 1600, "likes": [&"cyberware", &"junk"], "markup": 1.3, "buyback": 0.6,
	},
	&"clinic": {
		"stock": {&"med_patch": 10, &"focus_stim": 5, &"volt_can": 6},
		"credits": 800, "likes": [&"medical"], "markup": 1.25, "buyback": 0.5,
	},
	&"guns": {
		"stock": {&"ammo_ks47": 900},
		"credits": 1000, "likes": [&"ammo", &"cyberware"], "markup": 1.2, "buyback": 0.5,
	},
	&"pawn": {
		"stock": {&"jade_koi": 1, &"gold_lighter": 1, &"vinyl": 2, &"lucky_cat": 3, &"deck_board": 1, &"scrap": 6},
		"credits": 1400, "likes": [&"junk", &"valuable", &"cyberware", &"food", &"drink", &"medical", &"ammo"], "markup": 1.35, "buyback": 0.55,
	},
}


static func profile(id: StringName) -> Dictionary:
	return PROFILES.get(id, PROFILES[&"pawn"])
