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
| Free / capture the mouse | Esc (clicking the game also captures it) |
| Toggle PS1 vertex wobble | F2 |
| Toggle the retro filter (pixelation + dithering) | F3 |

Walk into the green-lit **AMMO** crate just inside the cafe door to refill your reserve ammo.

## What's in prototype 1

- **First-person controller**: walk, sprint (with FOV kick), jump, mouse look, head bob, footsteps.
- **Sushi cafe spawn**: counter with a moving conveyor belt of sushi plates, stools, standing
  tables, paper lanterns, a neon koi, menu boards, shop front with awning and neon signs.
- **City block**: a crossroads of wet streets (puddles reflect the neon through SSR), sidewalks,
  crosswalks, glowing lane markings, buildings with procedural lit windows, storefronts, neon and
  vertical blade signs, holographic adverts, street lamps, traffic lights, vending machines, parked
  cars, steam vents, cables with festival lights and overpasses. Police barricades with invisible
  walls close the streets about 68 m from the crossing.
- **Endless skyline**: about 900 instanced towers out to 2.5 km, arcologies, aviation lights,
  billboards, flying-car traffic, searchlights and a silhouette backdrop, all fading into fog.
- **Robot dragons**: five segmented mechanical serpents on looping flight paths. Two fly low
  through the street canyons (with head lights and an engine hum), three circle higher up.
- **NPCs**: about 44 low-poly pedestrians with random outfits (coats, hoods, neon visors, glowing
  umbrellas) walking the sidewalks and crosswalks with `NavigationAgent3D` and local avoidance.
  Shooting near them does nothing yet.
- **Rifle**: an AK-style hitscan rifle with blooming spread, recoil, muzzle flash, tracers,
  sparks, bullet-hole decals, 30-round magazine plus reserve, reloading and sound.
- **HUD**: crosshair, ammo counter with bullet bar and reload progress, controls hint, messages.

## Project structure

```
project.godot          Input map, physics layer names, rendering settings, ps1_wobble global
scenes/
  main.tscn            Root: low-res RetroScreen viewport containing the world, plus the HUD
  world/world.tscn     Environment, city, skyline, cafe, dragons, crowd, player, effects, ambience
  world/*.tscn         City, skyline and sushi cafe (each a builder script on a Node3D)
  player/player.tscn   First-person controller with the rifle attached
  weapons/rifle.tscn   Rifle logic, model, muzzle flash light and sounds
  actors/              Robot dragon and NPC scenes
  props/ammo_crate.tscn
scripts/
  main.gd              Mouse capture and mouse look routing
  core/                RetroScreen (pixelation/toggles), MatLib (material factory), Palette
  world/               CityBuilder, Skyline, SushiCafe, FlightPath, GeoBatch, BuildKit
  actors/              RobotDragon, Npc, NpcModel, NpcCrowd
  weapons/             Rifle, RifleModel, ImpactEffects
  props/               AmmoCrate
  debug/               Screenshot helper for development
shaders/               Retro post filter, PS1 surface/neon/glass, facades, wet street, sky,
                       holo adverts, sky traffic, light beams, skyline backdrop
assets/audio/          Generated sound effects (see tools/generate_sfx.py)
assets/environment/    Night WorldEnvironment (sky, fog, volumetric fog, glow, SSR)
ui/                    HUD, crosshair and ammo bar
tools/generate_sfx.py  Regenerates the placeholder sounds (python3 tools/generate_sfx.py)
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

- No enemies, damage or NPC reactions yet; the dragons are ambient only.
- Sounds are simple synthesised placeholders.
- Text on signs uses Godot's default font plus your system fonts for Japanese characters. If no
  CJK font is installed, those signs show empty boxes.
