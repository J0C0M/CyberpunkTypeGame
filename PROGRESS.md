# Progress

Living status file so work can be picked up in a new session. Updated with every commit.

## Branches
- `main`: initial commit only (releases are done by hand from `Development`).
- `Development`: prototypes 1 and 2 merged.
- `Build-Second-Prototype`: prototype 2 (merged into `Development`).
- `Build-Third-Prototype`: prototype 3 = finishing prototype 2 + Part 1 (music); merged into `Development`.
- `Build-Fourth-Prototype`: prototype 4; merged into `Development`.
- `Fix-Dialogue-Scroll`: scrolling dialogue choices; merged into `Development`.
- `Build-Fifth-Prototype`: prototype 5; merged into `Development`.
- Next: `Build-Sixth-Prototype` (clothing and armour; see "Prototype 6 preparation" and HANDOFF.md).

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
## Prototype 4 (branch `Build-Fourth-Prototype`): done and merged
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
- Part C: bug hunt (BUGFIX_NOTES.md): **done**
  - [x] Errors/warnings: exit leaks (audio) fixed via `SaveGame.quit_game()`; stale deferred ammo signal.
  - [x] Screenshot tour `-- --tour=<prefix>` (`scripts/debug/screenshot_tour.gd`), 27 viewpoints; fixed door
    orientation, sign poles through text, dark lobby/hallway/cyberware/gun shop, stale prompts.
  - [x] Pedestrians: props cut out of their navmesh + unstick (`tests/test_crowd.tscn`: 14.8 % -> <1 % stuck).
  - [x] Explosions blocked by walls; seated look-around; flatline while seated / in the elevator.
  - [x] Performance (`tests/perf_bench.tscn`: 1.3-1.6 ms average, worst 2.7 ms), UI at 4:3 and 21:9,
    walk-through test (`tests/test_world.tscn`), hallway end window/lining.
  - [x] Final re-tour of all viewpoints; merged into `Development`.

## Prototype 5 (branch `Build-Fifth-Prototype`): done and merged
Brief: main menu, character creator, multi-character save slots, seeing your own character
(first-person body, inventory paper doll, mirrors, photo booth, third person, lobby monitor, NPC
comments) and preparation for prototype 6's clothing/armour. Order: model, creator, menu + saves,
first person, paper doll, mirrors, small extras, p6 prep.

- [x] Step 1: rigged player model (`scripts/character/`)
  - `CharacterRig`: 18-bone Skeleton3D table, body regions (box per region with slim size, muscle
    growth/shift and frame growth), attachment slots (BoneAttachment3D `Slot_<slot>`), wear slots and
    `WearLayer` (UNDERWEAR, CLOTHING, OUTER, ARMOR with inflate offsets), first-person-hidden regions.
  - `CharacterModel` (Node3D): builds skeleton + one skinned MeshInstance3D per region and layer
    (`Skin_<region>`, `Wear_<region>`, `Hair`), body masks (fully covered skin hidden), muscle =
    "muscle" blend shape (NORMALIZED mode!), frame/height rebuild the skeleton, `pose()` walk/run/aim/
    crouch/breathing, `slot()`, `eye_height()`. Head/neck/hair/arms on render layer 3 (bit 4).
  - `CharacterData` (Resource, to_dict/from_dict/randomize_look), `CharacterOptions` (all choices),
    `CharacterAtlas` (fixed 512x512 layout, 160 px/m), `CharacterTexture` (skin, face, white heart
    underpants, tattoos, glow map), `TattooDesigns` (8 invented pixel designs), `CharacterMeshBuilder`,
    `Wearables` (15 clothing pieces) and `Outfits` (5 presets). Shader `shaders/character.gdshader`.
  - 15 clothing items (`assets/items/wear_*.tres`, category "clothing", `wear_slot`/`wear_layer`),
    CLOTHING tab in the inventory.
  - Tests: `tests/test_character.tscn` (headless), `tests/shot_character.tscn` (lineup screenshots).
- [x] Step 2: character creator (`scenes/character_creator.tscn`, `ui/character_creator.gd`,
  `scripts/world/body_shop.gd`): neon clinic room with a turntable, retro-filtered 3D + sharp UI, tabs
  Identity/Face/Hair/Body/Tattoos/Outfit, selectors/swatches/sliders (controller focusable, LB/RB tabs,
  right stick turns/zooms), drag/wheel/F/B/Q/E/U, underwear preview, Randomize/Reset/Back/Confirm.
  Confirm -> `SaveGame.start_new_character()` (starts main.tscn). Menu music `assets/music/menu.ogg`
  (`Music.play_menu()`; `python3 tools/generate_music.py menu` regenerates one track).
  `GameState.character` (CharacterData) and `GameState.play_seconds`. Screenshots: `tests/shot_creator.tscn`.
- [x] Step 3: main menu, settings, save slots
  - `scenes/main_menu.tscn` (`ui/main_menu.gd`) is the main scene: live backdrop `scenes/ui/menu_backdrop.tscn`
    (city + skyline + two dragons + rain + drifting camera `scripts/world/menu_camera.gd`) through the
    retro filter; Continue / New Game / Load Game (characters with portraits, slots with label, location,
    date, playtime, in-game time; load, delete with confirmation) / Settings / Credits / Quit.
  - `SettingsMenu` (`ui/settings_menu.gd`) shared by main and pause menu: graphics (resolution, window mode,
    retro strength -> `RetroScreen.apply_settings`, VSync, FPS cap), audio, controls (sensitivity, invert Y,
    rebind keys/mouse/pad, reset), gameplay (FOV, head bob). Stored by `Settings` in settings.cfg.
  - Pause menu: Resume, Save Game (new manual slot), Settings, Back to Main Menu (warns, save/not/cancel),
    Save & Quit. Controller: focus everywhere, pad bindings for all actions, right stick look, LB/RB weapons.
  - `SaveGame` v2: `user://saves/<character id>/<slot>.json` with meta/character/game/player/world;
    `save_game(slot, label)`, `save_manual()` (max 10 manual), `list_characters()`, `list_slots()`,
    `newest_save()`, `delete_slot()`, `load_slot()` -> Main `apply_pending()`, `return_to_menu()`,
    `quit_game()`. Prototype-4 `savegame.json` converts to character "Tenant" (backup kept as
    `savegame_v1_backup.json`); prototype 3 had no saves. Locations from `GameState.register_area()`.
    Portrait: `CharacterPortrait.render()` until the photo booth (step 7).
  - Tests: `tests/test_save.tscn` (slots, characters, delete, migration; uses user://test_saves),
    `tests/test_flow.tscn` (menu -> creator -> game -> menu -> continue), `tests/shot_menu.tscn`.
  - Fixed: HUD lambdas on GameState signals outlived the HUD across scene changes (now methods).
- [x] Step 4: first-person arms, body, shadow
  - `Player.apply_character(data)`: a `CharacterModel` body 0.13 m behind the camera (looking down shows the
    chest and legs), camera at `eye_height()`, camera cull mask without render layer 3 (head, neck, hair,
    arms: still cast shadows and show in mirrors), walk/run/aim poses from the footsteps, the gun in hand
    as an item model in `Slot_hand_r` (layer 3). Body hidden while seated on the couch.
  - `ViewArms` (`scripts/character/view_arms.gd`, child of the WeaponHolder, render layer 2): hands,
    forearms and upper arms from `CharacterModel.part_mesh()` (same skin, tattoos, glow, muscle, sleeves,
    gloves), placed on the gun models' `right_hand`/`left_hand` markers with two-bone IK to fixed shoulder
    points; drawn 1.25x like most shooters. Gun view models lost their baked gloves and sleeves.
  - `ShadowLights` (world.tscn): every 0.5 s the 3 nearest bright lights get shadows.
  - Shots: `tests/shot_firstperson.tscn`; checks in `tests/test_world.tscn`.
- [x] Step 5: inventory paper doll: `ui/inventory_screen.gd` `_build_doll()` (SubViewport, own world, neon
  rim lights, stage, half resolution), the character in its outfit with the gun in hand, drag to turn,
  WORN list. Prototype 6 equips clothes here.
- [x] Step 6: mirrors: `Mirror` (`scripts/world/mirror.gd`, `shaders/mirror.gdshader`): reflected camera with an
  off-centre frustum (near plane = glass) into a 160 px SubViewport, sees layer 3 (head/arms) but not the
  view model, renders only when the player is within 7 m in front; frame + vanity light. Placed in the new
  bathroom of 1107 (`ApartmentBlock._build_bathroom`, doorway in the west wall), Lucky Pawn ("TRY IT ON")
  and Cyberware ("CHECK YOUR CHROME"). Shots: `tests/shot_mirrors.tscn`; checks in `tests/test_world.tscn`.
- [-] Step 7: photo booth, third person / photo mode (V), lobby security monitor, NPC comments on your look:
  **moved to a later prototype at the user's request.** Save-slot portraits use the rendered headshot
  (`CharacterPortrait`) until the photo booth exists.
- [x] Step 8: prototype 6 preparation (below), README/CREDITS/HANDOFF, merge into `Development`.

### Prototype 6 preparation (Morrowind-style clothing and armour)
Not built yet; the player model is set up for it:
- **Attachment points:** `CharacterRig.SLOTS` -> a `BoneAttachment3D` "Slot_<slot>" with a "Mount" child per
  slot (helmet, face, neck, chest, back, shoulder_l/r, forearm_l/r, hand_l/r, waist, hip_r, thigh_l/r,
  shin_l/r, foot_l/r); `CharacterModel.slot(name)` returns the mount. The gun in hand already uses hand_r.
- **Wear slots:** `CharacterRig.WEAR_SLOTS`: shirt, pants, shoes, gloves (CLOTHING), jacket (OUTER),
  helmet, chest_armor, shoulders, gauntlets, greaves, boots (ARMOR), each with the regions it covers.
- **Layer order:** `CharacterRig.WearLayer` UNDERWEAR (painted on the skin texture: the white underpants
  with hearts, always there) -> CLOTHING (+1.2 cm) -> OUTER (+2.6 cm) -> ARMOR (+4.5 cm). Each region's
  pieces of every layer are merged into one `Wear_<region>` mesh per region, so the first-person rules
  (head/arms on render layer 3) and body masks work per region.
- **Body masks:** `Wearables.covered_regions(worn)`: skin regions fully covered by a piece (share 1.0) are
  hidden (`Skin_<region>.visible = false`); partial pieces (sleeves rolled up, boots over the shin) keep the
  skin. `CharacterModel.is_covered(region)`; the first-person arms (`ViewArms`) follow the same rule.
- **Items:** every clothing piece is an `ItemData` (category "clothing", `wear_slot`, `wear_layer`,
  `assets/items/wear_*.tres`) with its geometry in `Wearables.PIECES` under the same id (regions + share,
  colour, extras such as collars, studs and neon trim). The five starting outfits (`Outfits.PRESETS`) are
  sets of these items; a new character gets them in the inventory (not sellable or droppable yet).
- **What the model wears:** `CharacterData.worn` (item ids, saved with the character); empty = the starting
  outfit's pieces. `CharacterModel` builds from `data.worn_items()` and `rebuild()` applies changes, so
  equipping = edit `worn` + rebuild (the player body, the paper doll and the first-person arms).
- Still to do in prototype 6: equip/unequip in the inventory (paper doll drop targets per wear slot), one
  item per slot with layer rules, armour pieces (new Wearables entries + items, maybe stats), shops selling
  clothes, and dropping/selling worn items.
