class_name GuideDialogue
extends RefCounted
## What Ren, the noodle cook who looks out for the player, has to say. A dialogue tree is a
## dictionary of nodes: {"text": String or Array (one picked at random), "action": optional
## action run when the node opens, "choices": [{"text", "next" (node id or "" to end),
## "action" (optional), "if" (optional condition: "has:<item>", "flag:<flag>", "!flag:<flag>")}]}.
## Actions and conditions are handled by the speaker (Merchant.handle_dialogue / dialogue_condition).

const TIPS := [
	"Don't shoot in the street. People panic, shopkeepers lock the till, and nobody here forgets a face.",
	"Cars around here run on cheap cells. Put a few rounds into the hood and... well. Stand back. Far back.",
	"The dragons? Corporate drones. They circle the towers all night, looking pretty. Don't stare too long.",
	"People drop what they carry when they go down. I didn't tell you that. Mo at the pawn shop buys junk, Doc Ichi pays well for chips and shards.",
	"Ammo isn't free anymore since the Ban. Kaz at Iron Lotus sells it by the box. Haggle, he likes that.",
	"Go home and sleep now and then. Shops restock overnight, and the city has a short memory by morning.",
	"Glass is cheap, getting it replaced is not. Mind where you aim inside a shop.",
	"The Rust Jackals hold the west end, by the barricade with the burning barrel. Walk onto their corner and they warn you. Once.",
	"Start shooting people and the police send drones. Get out of their sight and the heat dies down. Or go home and sleep it off.",
	"Bleeding? Clinic 24H sells med patches. Slap one on and keep moving. H, if you're the type who likes shortcuts.",
]


static func build() -> Dictionary:
	return {
		&"first": {
			"text": "Ah! A new face. Sit, sit, the bowl's hot. I'm Ren, this is my noodle bar. You look like you slept in a vending machine... Here, take a little something to get started. Everybody needs a start in Kabukicho.",
			"action": "first_meeting",
			"choices": [{"text": "Thanks, Ren.", "next": &"key"}],
		},
		&"key": {
			"text": "Oh, and before I forget: your landlord dropped this off. Key card for Neo-Heights, unit 1107. Rent's paid, the note says, nothing else. And here, a coupon. First bowl is on me, whenever you want it.",
			"action": "give_key",
			"choices": [{"text": "Rent's paid? By whom?", "next": &"intro"}],
		},
		&"intro": {
			"text": "Didn't say. In Block 7 you don't ask twice. Neon, puddles that never dry, dragons overhead. You can buy, sell, haggle. Folks here respect a little haggling. A little.",
			"choices": [{"text": "Good to know.", "next": &"hub"}],
		},
		&"hub": {
			"text": ["Back again? The broth's been going since noon.", "What can I do for you?", "Hungry? Or just lonely? Both are fine here."],
			"choices": [
				{"text": "Any tips about the city?", "next": &"tips"},
				{"text": "Tell me about the shops.", "next": &"shops"},
				{"text": "How does haggling work?", "next": &"barter"},
				{"text": "Who are the Rust Jackals?", "next": &"jackals"},
				{"text": "Where's my apartment?", "next": &"apartment"},
				{"text": "I've got your coupon.", "next": &"coupon", "if": "has:ren_coupon"},
				{"text": "What have you got to eat?", "next": "", "action": "trade"},
				{"text": "See you, Ren.", "next": ""},
			],
		},
		&"tips": {
			"text": TIPS,
			"choices": [{"text": "Another one.", "next": &"tips"}, {"text": "Back.", "next": &"hub"}],
		},
		&"shops": {
			"text": "Kaz at Iron Lotus Arms sells ammo, rude but fair. Doc Ichi at Cyberware buys data shards and chips. The Clinic's always open, Lucky Pawn buys anything, Vex pours at the Koi Bar, and Hiro next door does sushi. Want me to mark one for you?",
			"choices": [
				{"text": "Mark Iron Lotus Arms.", "next": &"marked", "action": "waypoint:guns"},
				{"text": "Mark Lucky Pawn.", "next": &"marked", "action": "waypoint:pawn"},
				{"text": "Mark Cyberware.", "next": &"marked", "action": "waypoint:cyberware"},
				{"text": "Mark the Clinic.", "next": &"marked", "action": "waypoint:clinic"},
				{"text": "Mark the Koi Bar.", "next": &"marked", "action": "waypoint:bar"},
				{"text": "Back.", "next": &"hub"},
			],
		},
		&"marked": {
			"text": "There. Follow the marker, you can't miss it. Well. You can, but try not to.",
			"choices": [{"text": "Thanks.", "next": &"hub"}],
		},
		&"barter": {
			"text": "Everybody has an asking price. Offer a bit less and most will meet you somewhere in the middle. Lowball too often and they'll get annoyed and charge you more for a while. Be a regular, be polite, and they go easy on you.",
			"choices": [{"text": "Got it.", "next": &"hub"}],
		},
		&"apartment": {
			"text": "Your place? Neo-Heights, the tall one with the purple sign on the corner across the crossing. Lobby's open all night, take the elevator up to the eleventh floor, unit 1107. Your key card opens the door. I'll mark it.",
			"action": "waypoint:apartment",
			"choices": [{"text": "Thanks, Ren.", "next": &"hub"}],
		},
		&"coupon": {
			"text": "My coupon! One Neon Ramen, extra glow. Careful, it's hot. Take it with you if you're in a hurry.",
			"action": "redeem_coupon",
			"choices": [{"text": "Thanks, Ren.", "next": &"hub"}],
		},
		&"jackals": {
			"text": "Corner crew at the west end of the street, by the barricade. Masks, cheap pistols, bad manners. Walk onto their corner and they tell you to walk away. Listen to them. Or don't, and bring more than a bowl of noodles. Kaz sells them ammo. Don't tell him I told you.",
			"choices": [{"text": "Noted.", "next": &"hub"}],
		},
		&"heat": {
			"text": ["Drones! I can hear them from here. What did you do? ...No. Don't tell me. Get off the street, get out of their sight, and they'll lose interest. Or go home and sleep it off.", "Police lights all over my window again. Lie low for a bit, will you? Not in here."],
			"choices": [{"text": "I'm going.", "next": ""}, {"text": "Just tell me something useful.", "next": &"tips"}],
		},
		&"upset": {
			"text": ["You shot at me! In my own shop! ...Give me a minute. Don't talk to me right now.", "Not now. My hands are still shaking."],
			"choices": [{"text": "Sorry.", "next": ""}],
		},
	}
