# CyberpunkTypeGame

A small open-world cyberpunk shooter prototype made with **Godot 4.7** (GDScript).
Low-poly 3D seen through a retro filter: a 360p internal resolution upscaled with
nearest-neighbour filtering, ordered dithering, colour quantization, PS1-style vertex wobble
and a cool night colour grade. It is always night, the streets are wet, everything glows, and
robot dragons fly between the towers.

## Running the game

1. Install Godot **4.7.x** (standard build, not .NET). The project was made with 4.7.2.
2. Run from the project folder:

   ```bash
   godot --path .
   ```

   Or open `project.godot` in the Godot editor and press **F5**.

The renderer is Forward+ (Vulkan). The game starts on the title screen: New Game opens the character
creator, Continue loads your most recent save.

## Controls

| Action | Key |
| --- | --- |
| Move | W A S D (or arrow keys) |
| Sprint | Shift |
| Jump | Space |
| Shoot | Left mouse button (KS-47 full auto, pistol and shotgun one shot per click) |
| Reload | R (the shotgun loads shell by shell; shooting interrupts) |
| Switch weapon | 1 / 2 / 3 or the mouse wheel |
| Inventory (use, drop, inspect, hotbar) | Tab or I |
| Quick heal (best healing item: med patch first) | H |
| Controller | Left stick move, right stick look, RT fire, A jump, X reload, Y interact, B heal, LB/RB weapons, Back inventory, Start pause |
| Interact (talk, trade, doors, elevator, bed, couch, pick up) | E |
| Pause menu (save, settings, back to the title screen, quit), leave menus | Esc (clicking the game captures the mouse) |
| Character creator | drag or Q/E turn, wheel zoom, F face, B body, U underwear preview, LB/RB tabs |
| Change TV channel (while seated) | A / D |
| Dialogue choices | 1-8 or click |
| Toggle PS1 vertex wobble | F2 |
| Toggle the retro filter (pixelation + dithering) | F3 |

You start in the noodle bar. Talk to **Ren** behind the counter: Ren gives you some starting money,
the key card to your apartment and a noodle coupon, explains the block and can mark shops and your
apartment on the HUD. Ammo is no longer free; buy it by the box at Iron Lotus Arms (which also sells
a pistol and a shotgun). The game autosaves when you sleep in your bed, go back to the title screen
or quit; Save Game in the pause menu adds a slot. Every character has its own save slots.

Keys can be rebound in Settings > Controls (keyboard, mouse or controller). Settings also has the
resolution, window mode, retro-filter strength, VSync, an FPS cap, volumes, invert Y, field of view and
head bob; the same menu opens from the title screen and the pause menu.

## What's in the game

### Prototype 1
- First-person controller with sprint, jump and head bob; retro low-res filter; an always-night
  neon city block with wet streets, skyline, flying-car traffic and robot dragons; wandering NPCs;
  the KS-47 hitscan rifle; HUD.

### Prototype 5
- **Title screen:** a live, rainy shot of the city through the retro filter, with its own music:
  Continue, New Game, Load Game (characters with portraits; each slot shows the place, date, playtime and
  in-game time; load or delete), Settings, Credits, Quit. Menus work with mouse, keyboard and controller.
- **Character creator** in a neon body-shop clinic with a turntable: name, skin, head shape, eyes, brows,
  nose, mouth, facial hair, face cyberware, hair style and colour (neon colours glow), muscularity, build,
  height, up to eight tattoos (invented designs, ten zones, nine inks, optional glowing neon ink) and five
  starting outfits. Every character wears white underpants with hearts under everything (toggle the
  preview with U).
- **The player model** is a rigged low-poly character (18-bone skeleton, one skinned part per body region,
  muscle as a blend shape, attachment slots and wear layers for clothing and armour).
- **Seeing yourself:** your own arms and hands hold every gun (skin, tattoos, glowing ink, sleeves and
  gloves); look down to see your body and legs; the nearest lights cast your shadow; a turnable paper doll
  in the inventory; working mirrors in the new bathroom of 1107, at Lucky Pawn and at Cyberware.
- **Saves** are per character and slot (version 2); the prototype 4 save is converted into a character
  called "Tenant" on first start.

### Prototype 4
- **Inventory:** every item is a resource file (`assets/items/*.tres`, `ItemData`) with a generated
  low-poly model and icon. Tab/I opens the inventory: category tabs, 30 slots with stacking, a detail
  panel with value and effects, eat/drink/use, drop, inspect (a rotating 3D view) and the weapon hotbar.
  Food and drinks heal a little and give short effects (faster sprint, steadier aim, a tipsy sway).
  Items lie around the city and drop from bodies; the HUD lists what you pick up.
- **Save system:** credits, inventory, the clock, Ren's state, waypoints, merchants' cash, stock and
  mood, your position and loaded magazines go to `user://savegame.json` (sleep = save, quit = save).
- **Health and death:** an HP bar, a red damage vignette, arcs that point at whoever is shooting you,
  regeneration after a few quiet seconds and med patches. At zero you flatline and wake up in your
  apartment (or at Ren's) with a small clinic bill.
- **Weapons:** the KS-47, the Kitsune P9 pistol and the Oni-12 pump shotgun on a three-slot hotbar.
- **The Rust Jackals:** a gang that holds the west end of the main street. They warn you off their
  corner, then take cover behind cars and crates, fire short bursts, chase, search and flee when hurt.
- **Police drones:** violence earns wanted stars; each star sends a drone that hunts you from above the
  street. Lose them, or go home and sleep it off. Shopkeepers won't trade while drones are on you.

### Prototype 2
- **Damage system:** `Damageable` health components with hit zones (`HitInfo`, `Damageable.deliver`)
  used by bullets and explosions. An `EventBus` autoload broadcasts danger events.
- **Things react to gunfire:** shop windows, the cafe front and bus-stop panels shatter; NPCs have
  health (headshots x3), collapse when killed, drop loot and panic (flee or cower) at shots, bodies
  and explosions; street furniture (vending machines, bins, lamps, signs, barriers, crates,
  planters) shows damage stages and breaks; parked cars smoke, burn and explode with chain
  reactions, camera shake and knockback. Debris, decals and bodies are pooled and capped.
- **Interaction, inventory and credits:** look at things and press E. Credits and an inventory
  (ammo included) live in the `GameState` autoload; the HUD shows credits and the clock.
- **Shops and bartering:** noodle bar, Koi Bar, Cyberware, Clinic 24H, Iron Lotus Arms (ammo),
  Lucky Pawn and the sushi cafe, each with a merchant and their own stock. Pay the price or haggle
  with the offer slider: merchants accept, counter or refuse, get annoyed by lowballs and remember
  your reputation. They cower and refuse to trade after violence.
- **Ren, the guide:** dialogue with choices, tips, shop explanations and HUD waypoints. Can't be killed.
- **Footsteps:** per surface (concrete, wet puddles, metal, wood, tile), distance-timed and soft.
- **Music (prototype 3):** generated ambient street soundtrack, elevator muzak and a track per shop played from
  in-world speakers (muffled from outside, clear inside), an apartment radio, ducking during dialogue/TV and a
  muffle after gunfire. Audio buses Master/Music/SFX/Ambience/UI with sliders in the pause menu.
- **Neo-Heights:** a lobby with a doorman robot, an elevator to the 11th floor, a hallway and the
  player's apartment 1107. Sleep in the bed to skip six hours (the city repairs itself, merchants
  restock, bodies and loot are cleared), sit on the couch to watch four invented TV channels, grab
  a soda from the fridge.

## Project structure

```
project.godot          Input map, physics layers, autoloads (EventBus, GameState), shader globals
scenes/
  main_menu.tscn       Title screen (main scene); ui/menu_backdrop.tscn is its live city backdrop
  character_creator.tscn  The character creator (body shop)
  main.tscn            The game: low-res RetroScreen viewport with the world, HUD, trade and dialogue screens
  world/world.tscn     Environment, city, skyline, dragons, crowd, player, effect pools, ambience
  world/*.tscn         City, skyline, sushi cafe and the Neo-Heights apartment block
  shops/*.tscn         The six shops (ShopInterior + a Merchant)
  actors/              Robot dragon, NPC and merchant scenes
  player/, weapons/    First-person player and the KS-47
scripts/
  core/                EventBus, GameState, Settings and SaveGame autoloads, RetroScreen, MatLib, Palette, SfxPool
  combat/              HitInfo, Damageable, Hitscan, GlassPane, BreakableProp, Car, CoverBlock, Explosions,
                       DebrisPool, PoliceDispatch
  actors/              Person (health, death, panic), Npc, NpcCrowd, Merchant, NpcModel, RobotDragon,
                       GangMember, GangTurf, PoliceDrone, EnemyNav
  interaction/         Interactable, Door
  items/               ItemData, ItemDB, Inventory, ShopProfile, ShopCatalog, ItemModels, ItemIcons,
                       Pickup, ItemScatter
  character/           CharacterData, CharacterOptions, CharacterRig, CharacterModel, CharacterTexture,
                       CharacterAtlas, CharacterMeshBuilder, TattooDesigns, Wearables, Outfits,
                       CharacterPortrait, ViewArms
  dialogue/            GuideDialogue (Ren's dialogue tree)
  world/               CityBuilder, Skyline, SushiCafe, ShopInterior, ApartmentBlock, FlightPath, ...
  props/               TvSet
  player/, weapons/    Player, Footsteps, Firearm, WeaponHolder, Rifle/Pistol/ShotgunModel, ImpactEffects
assets/items/          One ItemData resource per item; assets/shops/: one ShopProfile per kind of shop
tests/                 Headless test scenes (test_*.tscn) and screenshot scenes (shot_*.tscn), see below
shaders/               Retro filter, PS1 surfaces, facades, wet street, sky, TV channels, ...
assets/audio/          Generated sounds (tools/generate_sfx.py)
ui/                    HUD, waypoint marker, trade and dialogue screens, shared UiStyle
tools/generate_sfx.py  Regenerates every sound (python3 tools/generate_sfx.py)
```

## How the world is built (and how to swap things out)

Everything visual is generated from primitives in code, so there are no external models yet:

- The builders (`CityBuilder`, `Skyline`, `SushiCafe`, `RobotDragon`, `NpcModel`, `RifleModel`,
  `AmmoCrate`) are `@tool` scripts. They generate their geometry in `_ready()`, both in the
  editor and in game, so you can see the result when you open a scene. Generated nodes are not
  saved into the scene files. City and skyline have a **Rebuild** button in the inspector.
- `GeoBatch` merges many boxes, cylinders and neon bars into one mesh with one surface per
  material, which keeps node counts and draw calls low.
- All materials come from `MatLib` and share a few shaders, so the PS1 wobble, fog and glow look
  the same everywhere. Colours live in `Palette`.
- To replace something with a real model, swap the node that runs the builder script for an
  imported scene: for example replace the `Model` node in `npc.tscn` (keep an `animate(phase,
  amount)` method or switch to an AnimationPlayer), the `Model` node in `rifle.tscn`, or the
  `SushiCafe` instance in `world.tscn`.
- Flight paths are `FlightPath` nodes (a `Path3D`) under `World/Dragons`. Change their radius,
  lobes, waypoints and altitude in the inspector, or turn off `auto_generate` and draw your own
  curve.

Physics layers: 1 world, 2 player, 3 NPCs, 4 props. The first-person rifle renders on visual
layer 2 so a small fill light keeps it readable in dark streets.

## Development helpers

Render screenshots from fixed viewpoints without playing (each view is
`x,y,z,yaw_degrees,pitch_degrees`; images are saved as `<prefix>_<index>.png`):

```bash
godot --path . -- --shots=/tmp/shot --views="24,1.7,2,90,10;0,1.7,14,0,8" --frames=60
```

Add `--fire-frames=5` to fire the rifle just before each capture.

Quick headless smoke test:

```bash
godot --headless --path . --quit-after 120
```

Headless tests (each prints PASS/FAIL lines and exits with 1 on a failure). Run `--import` once
after adding scripts with a new `class_name`:

```bash
godot --headless --path . res://tests/test_inventory.tscn
```

The tests are `test_inventory`, `test_save` (slots, characters, converting old saves),
`test_health`, `test_weapons`, `test_gang`, `test_police`, `test_world` (doors, elevator, first-person
body, mirrors), `test_bounds` (no way out of the streets and interiors), `test_crowd` (how often pedestrians get stuck), `test_character` (the player model) and
`test_flow` (title screen -> creator -> game -> title screen -> continue). The `shot_*.tscn` scenes render screenshots instead (run them windowed with
`-- --out=/tmp/prefix`), `perf_bench.tscn` prints frame times for an explosion and a firefight, and
`test_quit.tscn` checks for a clean exit. Tests and screenshot runs never read or write your save.

Screenshot tour of the whole block (27 viewpoints: spawn, streets, every shop inside and out, the
cafe, lobby, elevator, hallway, apartment, the gang corner, the skyline), saved as
`<prefix>_<nn>_<name>.png`:

```bash
godot --path . -- --tour=/tmp/tour
```

Add `--only=lobby,hallway` to shoot just those views. Bugs found with it are in `BUGFIX_NOTES.md`.

## Known limitations

- The dragons are ambient only. Enemies are limited to one gang corner and the police drones.
- Clothing can't be changed after the creator yet (prototype 6), and there is no third-person view yet.
- Sounds are simple synthesised placeholders.
- Text on signs uses Godot's default font plus your system fonts for Japanese characters. If no
  CJK font is installed, those signs show empty boxes.
