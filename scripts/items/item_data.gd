@tool
class_name ItemData
extends Resource
## One item type. Every item is a .tres file in res://assets/items/ (see ItemDB), used by the
## inventory, the inventory screen, shops, trading, loot and world pickups. Prices are base
## prices in credits (¢) per unit; merchants add their markup when selling and pay less when buying.

@export var id := &""
@export var display_name := ""
## weapon, ammo, food, drink, medical, junk, valuable, cyberware, clothing or key.
@export var category := &"junk"
@export var price := 1
## Units that change hands per trade (ammo comes in boxes).
@export var pack := 1
## Most units that fit in one inventory slot.
@export var stack_size := 10
@export_multiline var description := ""
## Longer text shown when the item is inspected.
@export_multiline var inspect_text := ""
## Shape built by ItemModels for icons, world pickups and the inspect view.
@export var model := &"box"
## Accent colour of the model (labels, neon trim). Black = the category colour.
@export var tint := Color.BLACK

@export_group("Use")
## What happens when the item is used: "" (can't be used), or an effect id understood by
## GameState.apply_effect (sprint, steady, tipsy, heal, regen).
@export var effect := &""
@export var effect_strength := 0.0
@export var effect_duration := 0.0
## Instant health when used (food heals a little, med patches a lot).
@export var heal := 0.0
## Button text: Eat, Drink, Use...
@export var use_verb := "Use"
## HUD tag while the effect lasts ("SUGAR RUSH").
@export var effect_label := ""

@export_group("Wearing")
## For clothing and armour: the wear slot (CharacterRig.WEAR_SLOTS) and layer
## (CharacterRig.WearLayer). The geometry is defined in Wearables under the same id.
@export var wear_slot := &""
@export var wear_layer := 0

@export_group("Rules")
@export var droppable := true
@export var sellable := true
## For weapons: the ammo item the gun loads, and the first-person scene (a Firearm) the
## WeaponHolder puts in the player's hands.
@export var ammo := &""
@export var weapon_scene: PackedScene


func is_usable() -> bool:
	return effect != &"" or heal > 0.0
