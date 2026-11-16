class_name Merchant
extends Person
## Shopkeeper behind a counter. Trades with the player (TradeScreen), barters with a mood that
## sours on lowball offers, remembers the player's reputation, and reacts to violence: cowers
## behind the counter and refuses to trade while scared, and stays angry (and pricier) for a
## while if the player fired in or near the shop. The guide can't be killed; other merchants can,
## and come back (restocked) after the player sleeps.

signal trade_requested(merchant: Merchant)

## How a merchant answers a haggled offer.
enum Verdict { ACCEPT, COUNTER, REFUSE }

## Lowball offers a merchant puts up with before getting annoyed.
const MAX_PATIENCE := 3

@export var merchant_id := &"merchant"
@export var display_name := "Merchant"
@export var shop_name := "Shop"
## Key into ShopCatalog.PROFILES.
@export var catalog := &"pawn"
@export var look_seed := 0
## The friendly guide: can't be killed, talks instead of trading straight away.
@export var is_guide := false
@export_multiline var greeting := "Take a look."

var stock := Inventory.new()
var cash := 0
## Seconds left during which the merchant refuses to trade (scared or offended).
var refuse_time := 0.0
## Seconds left of anger after violence in or near the shop (prices go up, mood is bad).
var anger_time := 0.0
## Lowball patience left; refills slowly. At 0 the merchant is annoyed.
var patience := MAX_PATIENCE
var annoyed_time := 0.0

var _interact: Interactable
var _home := Transform3D.IDENTITY
var _patience_regen := 0.0


func _ready() -> void:
	killable = not is_guide
	model.look_seed = look_seed
	add_to_group("merchants")
	add_to_group("saveable")
	super()
	_home = transform
	_interact = Interactable.create(self, Vector3(1.6, 1.1, 2.0), Vector3(0, 1.5, -0.9), "")
	_interact.prompt_source = _prompt
	_interact.interacted.connect(_on_interacted)
	restock()


func _process(delta: float) -> void:
	super(delta)
	if is_dead:
		return
	refuse_time = maxf(0.0, refuse_time - delta)
	anger_time = maxf(0.0, anger_time - delta)
	annoyed_time = maxf(0.0, annoyed_time - delta)
	if patience < MAX_PATIENCE and annoyed_time <= 0.0:
		_patience_regen += delta
		if _patience_regen > 25.0:
			_patience_regen = 0.0
			patience += 1
	cower_amount = move_toward(cower_amount, 1.0 if is_panicking() else 0.0, delta * 4.0)
	# Keep an eye on the player when they're close.
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var target := _home.basis.get_euler().y
	if player and player.global_position.distance_to(global_position) < 7.0 and not is_panicking():
		var to_player := player.global_position - global_position
		target = atan2(-to_player.x, -to_player.z)
	rotation.y = lerp_angle(rotation.y, target, 1.0 - exp(-4.0 * delta))
	model.pose(_time(), 0.0, 0.0, cower_amount)


## Restocks to the catalogue and refills the cash float (done every night).
func restock() -> void:
	var profile := ShopCatalog.profile(catalog)
	stock.clear()
	for id in profile.stock:
		stock.add(id, profile.stock[id])
	cash = profile.credits


## What the merchant asks for one pack of `id` (markup, mood and reputation included).
func sell_price(id: StringName) -> int:
	var profile := ShopCatalog.profile(catalog)
	var mood := 1.0 + (0.25 if anger_time > 0.0 else 0.0) + (0.15 if annoyed_time > 0.0 else 0.0)
	var price := ItemDB.base_price(id) * ItemDB.pack_size(id) * profile.markup * mood * (1.0 - 0.12 * reputation())
	return maxi(1, roundi(price))


## What the merchant pays for one pack of `id`. Items they don't deal in fetch half as much.
func buy_price(id: StringName) -> int:
	var profile := ShopCatalog.profile(catalog)
	var rate := profile.buyback
	if not profile.likes.has(ItemDB.category(id)):
		rate *= 0.5
	var mood := 0.8 if anger_time > 0.0 else 1.0
	var price := ItemDB.base_price(id) * ItemDB.pack_size(id) * rate * mood * (1.0 + 0.12 * reputation())
	return maxi(1, roundi(price))


## The player offers `offer` for one pack of `id`, below the asking price. Returns
## {"verdict": Verdict, "price": int, "line": String}. Accepts close offers (more readily with good
## reputation and patience left), counters middling ones and refuses lowballs, which costs patience.
func judge_purchase_offer(id: StringName, offer: int) -> Dictionary:
	var asking := sell_price(id)
	if offer >= asking:
		return _verdict(Verdict.ACCEPT, offer, "Deal.")
	if annoyed_time > 0.0:
		return _verdict(Verdict.REFUSE, asking, "Price is the price. %d ¢." % asking)
	var ratio := float(offer) / asking
	var rep := reputation()
	if ratio >= 0.93 - 0.06 * rep - 0.02 * patience:
		return _verdict(Verdict.ACCEPT, offer, ["Fine. %d ¢.", "You drive a hard bargain. %d.", "For you? %d."].pick_random() % offer)
	if ratio >= 0.68 - 0.05 * rep:
		var counter := roundi(asking - (asking - offer) * (0.35 + 0.2 * rep))
		return _verdict(Verdict.COUNTER, counter, ["Meet me at %d ¢.", "%d. That's as low as I go.", "Can't do that. %d ¢?"].pick_random() % counter)
	return _lowballed(asking)


## The player asks `ask` for one pack of `id`, above what the merchant offered. Same rules mirrored.
func judge_sale_offer(id: StringName, ask: int) -> Dictionary:
	var price := buy_price(id)
	if ask <= price:
		return _verdict(Verdict.ACCEPT, ask, "Deal.")
	if annoyed_time > 0.0:
		return _verdict(Verdict.REFUSE, price, "I said %d ¢. Take it or leave it." % price)
	var ratio := float(ask) / price
	var rep := reputation()
	if ratio <= 1.06 + 0.06 * rep + 0.02 * patience:
		return _verdict(Verdict.ACCEPT, ask, ["Alright, %d ¢.", "Sure, %d. Don't tell anyone."].pick_random() % ask)
	if ratio <= 1.45 + 0.1 * rep:
		var counter := roundi(price + (ask - price) * (0.35 + 0.2 * rep))
		return _verdict(Verdict.COUNTER, counter, ["I'll go to %d ¢.", "%d, and you're robbing me.", "How about %d?"].pick_random() % counter)
	return _lowballed(price)


func _verdict(verdict: Verdict, price: int, line: String) -> Dictionary:
	if verdict == Verdict.ACCEPT:
		GameState.change_reputation(merchant_id, 0.01)
	return {"verdict": verdict, "price": price, "line": line}


func _lowballed(price: int) -> Dictionary:
	patience -= 1
	_patience_regen = 0.0
	GameState.change_reputation(merchant_id, -0.03)
	if patience <= 0:
		patience = 0
		annoyed_time = 45.0
		return _verdict(Verdict.REFUSE, price, "That's it. You're wasting my time. Prices just went up.")
	return _verdict(Verdict.REFUSE, price, ["Insulting.", "Is that a joke?", "No. Try again, seriously this time.", "You're not even close."].pick_random())


## Moves one pack from the merchant to the player for `price`. Returns an error line or "".
func sell_to_player(id: StringName, price: int) -> String:
	var pack := ItemDB.pack_size(id)
	if stock.count(id) < pack:
		return "Sold out."
	if GameState.credits < price:
		return "You're short. That's %d ¢." % price
	if GameState.inventory.room_for(id) < pack:
		return "Your pockets are full. Sell something first."
	GameState.spend_credits(price)
	cash += price
	stock.remove(id, pack)
	GameState.inventory.add(id, pack)
	GameState.change_reputation(merchant_id, 0.02)
	return ""


## Moves one pack from the player to the merchant for `price`. Returns an error line or "".
func buy_from_player(id: StringName, price: int) -> String:
	var pack := ItemDB.pack_size(id)
	if GameState.inventory.count(id) < pack:
		return "That's not a full box." if pack > 1 else "You don't have that."
	if cash < price:
		return "Can't afford it. Till's down to %d ¢." % cash
	cash -= price
	stock.add(id, pack)
	GameState.inventory.remove(id, pack)
	GameState.add_credits(price)
	GameState.change_reputation(merchant_id, 0.02)
	return ""


## Comes back to life behind the counter, calm and restocked (after the player sleeps).
func revive() -> void:
	if is_dead:
		is_dead = false
		health.restore()
		collision_layer = 4
		_head.collision_layer = 16
		_sinking = -1.0
		_death_time = 0.0
		visible = true
		model.transform = Transform3D.IDENTITY
		_interact.enabled = true
		set_process(true)
	transform = _home
	refuse_time = 0.0
	anger_time = 0.0
	annoyed_time = 0.0
	panic_time = 0.0
	patience = MAX_PATIENCE
	restock()


func save_key() -> String:
	return "merchant:" + String(merchant_id)


func save_data() -> Dictionary:
	return {
		"cash": cash,
		"stock": stock.to_dict(),
		"anger": anger_time,
		"annoyed": annoyed_time,
		"refuse": refuse_time,
		"patience": patience,
		"dead": is_dead,
	}


func load_data(data: Dictionary) -> void:
	cash = int(data.get("cash", cash))
	stock.load_dict(data.get("stock", stock.to_dict()))
	anger_time = float(data.get("anger", 0.0))
	annoyed_time = float(data.get("annoyed", 0.0))
	refuse_time = float(data.get("refuse", 0.0))
	patience = int(data.get("patience", MAX_PATIENCE))
	if data.get("dead", false) and not is_dead:
		_vanish()


## Gone until the next night (loading a save where this merchant had been killed).
func _vanish() -> void:
	is_dead = true
	health.is_dead = true
	health.health = 0.0
	collision_layer = 0
	_head.collision_layer = 0
	_interact.enabled = false
	visible = false
	set_process(false)


func can_trade() -> bool:
	return not is_dead and refuse_time <= 0.0 and not is_panicking()


func mood_text() -> String:
	if is_panicking():
		return "terrified"
	if anger_time > 0.0:
		return "furious"
	if annoyed_time > 0.0:
		return "annoyed"
	if patience < MAX_PATIENCE:
		return "impatient"
	return "friendly" if reputation() > 0.25 else "calm"


## Player standing with this merchant, -1..1.
func reputation() -> float:
	return GameState.reputation_with(merchant_id)


## Line the merchant says when the player tries to trade but they won't.
func refusal_line() -> String:
	if is_panicking():
		return "Get down! I'm not opening the till with bullets flying!"
	if anger_time > 0.0:
		return "You shoot up my street and want a discount? Get out."
	return "Not now. Come back later."


func _prompt() -> String:
	if is_dead:
		return ""
	if is_guide:
		return "Talk to " + display_name
	return ("Trade with " if can_trade() else "") + display_name + ("" if can_trade() else " (won't trade)")


func _on_interacted(_player: Player) -> void:
	if is_guide:
		var start := &"hub" if GameState.flags.get("met_guide", false) else &"first"
		if anger_time > 0.0 or is_panicking():
			start = &"upset"
		get_tree().call_group("dialogue_screen", "open_dialogue", display_name, GuideDialogue.build(), start, self)
		return
	if not can_trade():
		say(refusal_line())
		return
	_open_trade()


func _open_trade() -> void:
	trade_requested.emit(self)
	get_tree().call_group("trade_screen", "open_for", self)


## Runs an action from a dialogue tree ("trade", "first_meeting", "waypoint:<place id>").
func handle_dialogue(action: String) -> void:
	if action == "trade":
		get_tree().call_group("dialogue_screen", "close")
		_open_trade.call_deferred()
	elif action == "first_meeting":
		GameState.flags["met_guide"] = true
		GameState.add_credits(150)
		GameState.change_reputation(merchant_id, 0.2)
		get_tree().call_group("hud", "show_message", "+150 ¢")
	elif action == "give_key":
		for id: StringName in [&"keycard_1107", &"ren_coupon"]:
			if GameState.inventory.count(id) == 0 and GameState.inventory.add(id, 1) > 0:
				get_tree().call_group("hud", "notify_item", "+ " + ItemDB.display_name(id), ItemDB.color(id))
	elif action == "redeem_coupon":
		# The coupon's slot frees up first, so the bowl always fits.
		if GameState.inventory.remove(&"ren_coupon", 1):
			GameState.inventory.add(&"noodles", 1)
			get_tree().call_group("hud", "notify_item", "+ " + ItemDB.display_name(&"noodles"), ItemDB.color(&"noodles"))
	elif action.begins_with("waypoint:"):
		var place := StringName(action.trim_prefix("waypoint:"))
		if GameState.places.has(place):
			GameState.set_waypoint(place)
			get_tree().call_group("hud", "show_message", "Marked: " + GameState.places[place]["label"])


## Conditions on dialogue choices: "has:<item id>", "flag:<flag>" or "!flag:<flag>".
func dialogue_condition(condition: String) -> bool:
	if condition.begins_with("has:"):
		return GameState.inventory.count(StringName(condition.trim_prefix("has:"))) > 0
	if condition.begins_with("!flag:"):
		return not GameState.flags.get(condition.trim_prefix("!flag:"), false)
	if condition.begins_with("flag:"):
		return GameState.flags.get(condition.trim_prefix("flag:"), false)
	return true


## Shows a line of speech as a HUD message.
func say(line: String) -> void:
	get_tree().call_group("hud", "show_message", "%s: %s" % [display_name, line], 3.5)


func _on_danger_noticed(origin: Vector3, severity: float, _was_calm: bool, source: Node) -> void:
	refuse_time = maxf(refuse_time, panic_time + 10.0)
	# The player's gunfire in or right outside the shop is taken personally (a gang shootout isn't
	# the player's fault).
	if origin.distance_to(global_position) < 12.0 and (source == null or source is Player):
		_offend(40.0 * severity, 0.05 * severity)


func _on_hurt(hit: HitInfo) -> void:
	super(hit)
	if hit.source == null or hit.source is Player:
		_offend(150.0, 0.4)
		say("Are you insane?!" if is_guide else "Out! Get out of my shop!")


func _offend(seconds: float, reputation_loss: float) -> void:
	anger_time = maxf(anger_time, seconds)
	GameState.change_reputation(merchant_id, -reputation_loss)


func _on_died(hit: HitInfo) -> void:
	super(hit)
	_interact.enabled = false
	Pickup.spawn(get_parent(), global_position + global_basis.z * -0.5, &"", mini(cash, randi_range(60, 160)))


## Merchants don't vanish for good: the body sinks away and they're back after the next sleep.
func _despawn() -> void:
	visible = false
	set_process(false)
	despawned.emit()


func _time() -> float:
	return Time.get_ticks_msec() / 1000.0
