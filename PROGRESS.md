# Progress

Living status file so work can be picked up in a new session. Updated with every commit.

## Branches
- `main`: initial commit only (releases are done by hand from `Development`).
- `Development`: prototypes 1 and 2 merged.
- `Build-Second-Prototype`: prototype 2 (merged into `Development`).
- `Build-Third-Prototype`: prototype 3 = finishing prototype 2 + Part 1 (music); merged into `Development`.
- `Build-Fourth-Prototype`: prototype 4 (in progress, see below).

Commits are authored as J0C0M via one-off `git -c user.name=... -c user.email=...` flags
(git config itself is empty on this machine). Godot 4.7.2 binary: `~/Downloads/Godot_v4.7.2-stable_linux.x86_64`.

## Prototype 2: done
Damage system + EventBus, breakable glass, NPC deaths and panic, breakable props, exploding cars,
interaction system, inventory + credits + loot, six shops + sushi chef with trade UI and bartering,
Ren the guide with dialogue and waypoints, reworked footsteps, Neo-Heights lobby/elevator/hallway.

## Part 0 (finish prototype 2): done
- [x] Apartment 1107 interior (bed, couch, TV, kitchenette, clutter, window view)
- [x] Sleep: fade, clock skip, night reset (restock merchants, repair glass/props/cars, clear bodies)
- [x] Couch + TV with four invented channels
- [x] README + CREDITS updated
- [x] Visual checks (apartment block, gun shop, props): lobby brightened, TV enlarged
- [x] Merge `Build-Second-Prototype` into `Development`

## Prototype 3 (branch `Build-Third-Prototype`): done and merged
- Part 1: music + audio buses + settings menu: **done**
  - `tools/generate_music.py` (numpy + ffmpeg) makes 10 original looping OGG tracks in `assets/music/`.
  - Buses in `default_bus_layout.tres`: Master, Music (low-pass "muffle" effect), SFX, Ambience, UI.
  - `Music` autoload (scripts/audio/music_director.gd): street music, ducking per `GameState.ui_mode`,
    muffle after nearby danger. `MusicZone` (scripts/audio/music_zone.gd): diegetic speakers,
    muffled outside / clear inside; zones in every shop, cafe, lobby, elevator cab, hallway (quiet),
    apartment radio (fades while the TV is on).
  - `Settings` autoload + `ui/pause_menu.gd` (Esc): bus volumes, mouse sensitivity, saved to user://settings.cfg.
## Prototype 4 (branch `Build-Fourth-Prototype`): in progress
User's combat direction (asked at the start): **street gang + police drones**, **forgiving** difficulty,
**pistol + shotgun** next to the KS-47.

- Part A: inventory + save system: **done**
  - Items are `ItemData` resources in `assets/items/<id>.tres` (loaded by `ItemDB`, same static API as before);
    shop stock profiles are `ShopProfile` resources in `assets/shops/<id>.tres` (loaded by `ShopCatalog`).
  - `Inventory`: stacks per `stack_size`, 30 slots for the player (`room_for`, `stacks`, `to_dict/load_dict`).
  - `ItemModels` builds a low-poly model per item (`model` field); `ItemIcons` renders them all once into icons
    (headless: placeholder squares). Pickups show the real model.
  - Inventory screen (`ui/inventory_screen.gd`, Tab or I): category tabs, 6x5 grid (`ui/item_slot.gd`), detail
    panel, use/eat/drink, drop one/stack, inspect (rotating 3D view), hotbar slot buttons. Pauses the game.
  - Effects from food/drinks/stims in `GameState.effects` (sprint, steady, tipsy, regen); HUD shows them.
  - Weapons: `Rifle` became the generic `Firearm` (`scripts/weapons/firearm.gd`); `WeaponHolder` keeps a 3-slot
    hotbar (keys 1-3, mouse wheel) synced to weapon items (`ItemData.weapon_scene`).
  - HUD: hotbar strip, item feed ("+ Synth-Soda"), effects line, weapon name follows the gun in hand.
  - Key items: key card 1107 (needed from the hallway side of the 1107 door) and Ren's noodle coupon, both
    given by Ren at the first meeting; the coupon is redeemed through a conditional dialogue choice ("if").
  - `ItemScatter` (in world.tscn): 10 items around the city, back every night.
  - Save system: `SaveGame` autoload, JSON in `user://savegame.json`; GameState + player + "saveable" group
    (merchants, apartment fridge, item scatter). Saves on sleeping and on quit (pause menu or window close);
    Main loads on start (not in screenshot mode). Pause menu has NEW GAME (click twice).
  - Tests: `tests/test_inventory.tscn`, `tests/test_save.tscn` (headless), `tests/shot_ui.tscn` and
    `tests/shot_pickups.tscn` (windowed screenshots, `-- --out=<prefix>`). New class_names need one
    `--import` run before tests can see them.
- Part B: combat: **done**
  - [x] B1 Player health: `Damageable` on the player body (layer 2; explosions now reach the player at half
    damage via `Damageable.explosion_multiplier`), regen after 5 s quiet, H = quick heal (med patch first),
    food heals a little. HUD: HP bar, red vignette, damage-direction arcs (`ui/damage_indicator.gd`).
    Flatline: fade, "FLATLINED", clinic bill 10 % (max 150 ¢), +2 h, wake up in 1107 (with key card,
    `GameState.places[&"respawn_home"]`) or at Ren's; calls groups "police" `clear_heat` and "enemies"
    `on_player_respawned`. Sleeping restores health. Test: `tests/test_health.tscn`.
  - [x] B2 Pistol + shotgun: `scenes/weapons/pistol.tscn` (Kitsune P9, semi, 12 rounds, `ammo_9mm`) and
    `shotgun.tscn` (Oni-12, pump, 9 pellets, 6 shells loaded one by one, `ammo_shells`), view models
    `pistol_model.gd` / `shotgun_model.gd` (slide/pump animate on `Firearm.fired`). Item resources + icons +
    pickup models; Iron Lotus Arms stocks both guns and both ammo types. Bullets for every gun go through
    `Hitscan.shoot` (`scripts/combat/hitscan.gd`). Test: `tests/test_weapons.tscn`, shots: `tests/shot_weapons.tscn`.
  - [x] B3 Street gang "Rust Jackals": `EnemyNav` (world.tscn) bakes a navmesh on layer 2 from every static
    collider in the play area (roads walkable, cars/props/posts are holes, ~0.1 s, async). `GangMember`
    (`scripts/actors/gang_member.gd`, scene `scenes/actors/gang_member.tscn`, extends Person): sight cone +
    LOS, hears the player's shots, states PATROL/WARN/INVESTIGATE/COVER/ATTACK/CHASE/SEARCH/FLEE, cover from
    the "cover" group (Car, BreakableProp >= 0.8 m, `CoverBlock`), bursts through `Hitscan`, loot on death.
    `GangTurf` (`JackalTurf` at x = -56 by the west barricade): crew of 4, warnings, `go_hostile`, fire barrel,
    crates, neon tag, fresh crew every night. `NpcModel` got `outfit`/`armed` and aim/crouch poses. Person
    passes the danger `source` on, so merchants only blame the player for the player's gunfire.
    Tuning (forgiving): 4 dmg, 6.5° spread, 3-round bursts, 2-3.2 s pauses -> ~5 HP/s against all four in
    the open. Test: `tests/test_gang.tscn`; shots: `tests/shot_gang.tscn`.
  - [x] B4 Wanted level + police drones: `PoliceDispatch` (world.tscn, group "police") turns the player's
    violence into heat (shots 0.07, 0.015 on Jackal turf; kills: pedestrian 1.2, merchant 1.6, Jackal 0.3;
    explosions 0.8; hitting a drone 0.15), cools 0.14/s after 15 s quiet while no drone sees the player;
    one `PoliceDrone` per star (max 3, `scripts/actors/police_drone.gd`): flies over the streets only, circles
    at 11-16 m, 4-zap bursts (3 dmg), searchlight, core weak spot x2.5, retreats at 30 %, crashes in a small
    sourceless explosion with salvage. HUD: `ui/wanted_stars.gd`. `GameState.wanted` mirrors the stars:
    merchants refuse to trade at 2+, Ren has a "heat" scene; Ren has new Jackal/police/med patch tips and a
    "Who are the Rust Jackals?" topic. Test: `tests/test_police.tscn`; shots: `tests/shot_police.tscn`.
  - [x] B5 Balance (forgiving: ~5 HP/s from all four Jackals in the open, ~3 HP/s from two drones, 5 s
    regen delay), README controls/features/tests, CREDITS.
- Part C: bug hunt (BUGFIX_NOTES.md): **in progress**
  - [x] Errors/warnings: exit leaks (audio) fixed via `SaveGame.quit_game()`; stale deferred ammo signal.
  - [x] Screenshot tour `-- --tour=<prefix>` (`scripts/debug/screenshot_tour.gd`), 27 viewpoints; fixed door
    orientation, sign poles through text, dark lobby/hallway/cyberware/gun shop, stale prompts.
  - [x] Pedestrians: props cut out of their navmesh + unstick (`tests/test_crowd.tscn`: 14.8 % -> <1 % stuck).
  - [x] Explosions blocked by walls; seated look-around; flatline while seated / in the elevator.
  - [x] Performance (`tests/perf_bench.tscn`: 1.3-1.6 ms average, worst 2.7 ms), UI at 4:3 and 21:9,
    walk-through test (`tests/test_world.tscn`), hallway end window/lining.
  - [ ] Final re-tour of all viewpoints, merge.
