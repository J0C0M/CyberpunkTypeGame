class_name Merchant
extends Person
## Shopkeeper behind a counter. Trades with the player (TradeScreen), barters with a mood that
## sours on lowball offers, remembers the player's reputation, and reacts to violence: cowers
## behind the counter and refuses to trade while scared, and stays angry (and pricier) for a
## while if the player fired in or near the shop. The guide can't be killed; other merchants can,
## and come back (restocked) after the player sleeps.

signal trade_requested(merchant: Merchant)

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
	if patience < MAX_PATIENCE:
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
	for id in profile["stock"]:
		stock.add(id, profile["stock"][id])
	cash = profile["credits"]


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
	if not is_guide and not can_trade():
		say(refusal_line())
		return
	trade_requested.emit(self)
	get_tree().call_group("trade_screen", "open_for", self)


## Shows a line of speech as a HUD message.
func say(line: String) -> void:
	get_tree().call_group("hud", "show_message", "%s: %s" % [display_name, line], 3.5)


func _on_danger_noticed(origin: Vector3, severity: float, _was_calm: bool) -> void:
	refuse_time = maxf(refuse_time, panic_time + 10.0)
	# Gunfire in or right outside the shop is taken personally.
	if origin.distance_to(global_position) < 12.0:
		_offend(40.0 * severity, 0.05 * severity)


func _on_hurt(hit: HitInfo) -> void:
	super(hit)
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
