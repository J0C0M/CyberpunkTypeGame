@tool
class_name ShopProfile
extends Resource
## What a kind of merchant sells and buys (res://assets/shops/<id>.tres). `stock` is what they
## restock to every night (item id -> units), `credits` their cash float, `likes` the item
## categories they pay a fair price for (anything else they buy at half rate), `markup` and
## `buyback` scale the items' base prices.

@export var stock: Dictionary[StringName, int] = {}
@export var credits := 500
@export var likes: Array[StringName] = []
@export var markup := 1.2
@export var buyback := 0.5
