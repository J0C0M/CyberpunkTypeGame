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

The renderer is Forward+ (Vulkan). You spawn inside a sushi cafe; walk out onto the street.

## Controls

| Action | Key |
| --- | --- |
| Move | W A S D (or arrow keys) |
| Sprint | Shift |
| Jump | Space |
| Shoot (full auto) | Left mouse button |
| Reload | R |
| Interact (talk, trade, doors, elevator, bed, couch, pick up) | E |
| Free / capture the mouse, leave menus | Esc (clicking the game also captures it) |
| Change TV channel (while seated) | A / D |
| Dialogue choices | 1-8 or click |
| Toggle PS1 vertex wobble | F2 |
| Toggle the retro filter (pixelation + dithering) | F3 |

You start in the noodle bar. Talk to **Ren** behind the counter: Ren gives you some starting money,
explains the block and can mark shops and your apartment on the HUD. Ammo is no longer free; buy
it by the box at Iron Lotus Arms.

## What's in the game

### Prototype 1
- First-person controller with sprint, jump and head bob; retro low-res filter; an always-night
  neon city block with wet streets, skyline, flying-car traffic and robot dragons; wandering NPCs;
  the KS-47 hitscan rifle; HUD.

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
- **Neo-Heights:** a lobby with a doorman robot, an elevator to the 11th floor, a hallway and the
  player's apartment 1107. Sleep in the bed to skip six hours (the city repairs itself, merchants
  restock, bodies and loot are cleared), sit on the couch to watch four invented TV channels, grab
  a soda from the fridge.

## Project structure

```
project.godot          Input map, physics layers, autoloads (EventBus, GameState), shader globals
scenes/
  main.tscn            Root: low-res RetroScreen viewport with the world, HUD, trade and dialogue screens
  world/world.tscn     Environment, city, skyline, dragons, crowd, player, effect pools, ambience
  world/*.tscn         City, skyline, sushi cafe and the Neo-Heights apartment block
  shops/*.tscn         The six shops (ShopInterior + a Merchant)
  actors/              Robot dragon, NPC and merchant scenes
  player/, weapons/    First-person player and the KS-47
scripts/
  core/                EventBus and GameState autoloads, RetroScreen, MatLib, Palette, SfxPool
  combat/              HitInfo, Damageable, GlassPane, BreakableProp, Car, Explosions, DebrisPool
  actors/              Person (health, death, panic), Npc, NpcCrowd, Merchant, NpcModel, RobotDragon
  interaction/         Interactable, Door
  items/               ItemDB, Inventory, ShopCatalog, Pickup
  dialogue/            GuideDialogue (Ren's dialogue tree)
  world/               CityBuilder, Skyline, SushiCafe, ShopInterior, ApartmentBlock, FlightPath, ...
  props/               TvSet
  player/, weapons/    Player, Footsteps, Rifle, RifleModel, ImpactEffects
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

## Known limitations

- No enemies or player health yet; the dragons are ambient only.
- Credits and inventory are not saved between sessions yet.
- Sounds are simple synthesised placeholders.
- Text on signs uses Godot's default font plus your system fonts for Japanese characters. If no
  CJK font is installed, those signs show empty boxes.
