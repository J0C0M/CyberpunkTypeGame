class_name GuideDialogue
extends RefCounted
## What Ren, the noodle cook who looks out for the player, has to say. A dialogue tree is a
## dictionary of nodes: {"text": String or Array (one picked at random), "action": optional
## action run when the node opens, "choices": [{"text", "next" (node id or "" to end),
## "action" (optional)}]}. Actions are handled by the speaker (Merchant.handle_dialogue).

const TIPS := [
	"Don't shoot in the street. People panic, shopkeepers lock the till, and nobody here forgets a face.",
	"Cars around here run on cheap cells. Put a few rounds into the hood and... well. Stand back. Far back.",
	"The dragons? Corporate drones. They circle the towers all night, looking pretty. Don't stare too long.",
	"People drop what they carry when they go down. I didn't tell you that. Mo at the pawn shop buys junk, Doc Ichi pays well for chips and shards.",
	"Ammo isn't free anymore since the Ban. Kaz at Iron Lotus sells it by the box. Haggle, he likes that.",
	"Go home and sleep now and then. Shops restock overnight, and the city has a short memory by morning.",
	"Glass is cheap, getting it replaced is not. Mind where you aim inside a shop.",
]


static func build() -> Dictionary:
	return {
		&"first": {
			"text": "Ah! A new face. Sit, sit, the bowl's hot. I'm Ren, this is my noodle bar. You look like you slept in a vending machine... Here, take a little something to get started. Everybody needs a start in Kabukicho.",
			"action": "first_meeting",
			"choices": [{"text": "Thanks, Ren.", "next": &"intro"}],
		},
		&"intro": {
			"text": "This is Block 7. Neon, puddles that never dry, dragons overhead. You can buy, sell, haggle. Folks here respect a little haggling. A little.",
			"choices": [{"text": "Good to know.", "next": &"hub"}],
		},
		&"hub": {
			"text": ["Back again? The broth's been going since noon.", "What can I do for you?", "Hungry? Or just lonely? Both are fine here."],
			"choices": [
				{"text": "Any tips about the city?", "next": &"tips"},
				{"text": "Tell me about the shops.", "next": &"shops"},
				{"text": "How does haggling work?", "next": &"barter"},
				{"text": "Where's my apartment?", "next": &"apartment"},
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
			"text": "Your place? Neo-Heights, the tall one with the purple sign on the corner across the crossing. Lobby's open all night, take the elevator up to the eleventh floor, unit 1107. I'll mark it.",
			"action": "waypoint:apartment",
			"choices": [{"text": "Thanks, Ren.", "next": &"hub"}],
		},
		&"upset": {
			"text": ["You shot at me! In my own shop! ...Give me a minute. Don't talk to me right now.", "Not now. My hands are still shaking."],
			"choices": [{"text": "Sorry.", "next": ""}],
		},
	}
