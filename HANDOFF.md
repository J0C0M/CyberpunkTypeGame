# Handoff: context for the next Claude Code session

Read this file, `PROGRESS.md`, `README.md`, `git log --oneline -40` and `git status` before doing anything.
This file explains how the project is built and the rules for working in it. Prototype 4 (inventory +
save system, combat, bug hunt) is done; section 5 keeps its brief for reference and section 6 has a
proposal for prototype 5 that still needs the user's go-ahead.

## 1. Project at a glance
- Godot **4.7.2**, GDScript, Forward+ renderer. The binary is **not on PATH**:
  `~/Downloads/Godot_v4.7.2-stable_linux.x86_64`. Machine: Linux (Wayland, DISPLAY=:0), RTX 4070 SUPER.
- A low-poly, always-night neon city block ("Neo-Kabukicho // Block 7") seen through a 360p retro filter.
  Almost everything visual is **generated in code** by `@tool` builder scripts (no imported models).
- Prototypes 1 to 4 are merged into `Development`. `main` holds only the initial commit.

## 2. Git rules (follow exactly)
1. Commit after every meaningful step; small commits, clear English messages.
2. All commits authored by GitHub account **J0C0M**. `git config user.name/user.email` are **empty** on this
   machine. Before the first commit, check them; if they are not J0C0M, **stop and ask the user**. The user has
   so far always chosen per-commit flags:
   `git -c user.name="J0C0M" -c user.email="caviagamer.2018@gmail.com" commit ...` (also for merges).
3. Never change the git identity, never turn off commit signing.
4. Never add "Co-Authored-By: Claude" or any mention of Claude/Anthropic to commits or PRs.
5. Branches: create one branch from `Development` per request, English words with hyphens, every word
   capitalised (next one: `Build-Fifth-Prototype`). When finished and tested, merge it into `Development`
   with `--no-ff` and push. **Never commit, push or merge to `main`.**
6. Push to `origin` (git@github.com:J0C0M/CyberpunkTypeGame.git).
7. Keep `PROGRESS.md` updated with every commit (done / in progress / left), so a new chat can resume.

## 3. How to run and test
```bash
G=~/Downloads/Godot_v4.7.2-stable_linux.x86_64
$G --headless --path . --import                 # after adding assets (then re-run once)
$G --headless --path . --quit-after 120         # smoke test; must print no errors
$G --path . -- --shots=/tmp/s --views="x,y,z,yaw,pitch;..." --frames=40 [--fire-frames=5]   # screenshots
```
- Headless runs print harmless `AudioStreamPlayback ... leaked` lines at exit (dummy audio driver); ignore them.
- Tests live in `tests/` (`test_*.tscn` headless, `shot_*.tscn` windowed screenshots, `perf_bench.tscn`);
  run every `test_*.tscn` before merging. After adding a script with a new `class_name`, run `--import`
  once or the tests can't see the class. Whole-block screenshot tour: `$G --path . -- --tour=/tmp/tour`.
- `--script` mode does **not** load autoloads. For scripted tests, wrap a `extends Node` test script in a tiny
  `.tscn` and run that scene (`$G --headless --path . /path/to/test_runner.tscn`); for screenshots run it
  without `--headless`. Set `get_tree().set_meta("screenshot_mode", true)` to hide the "click to play" overlay.
- Sounds: `python3 tools/generate_sfx.py` (stdlib only, each sound seeded by its file name).
  Music: `python3 tools/generate_music.py` (numpy + ffmpeg, writes `assets/music/*.ogg`).
  After importing new looping audio, set `edit/loop_mode=2` (WAV) or `loop=true` (OGG) in its `.import` file and re-import.

## 4. Architecture (where things live)
- `scenes/main.tscn`: root. `RetroScreen` (SubViewportContainer, low-res SubViewport with the 3D world),
  then CanvasLayers: `HUD`, `TradeScreen`, `DialogueScreen`, `PauseMenu` (UI stays sharp, outside the filter).
  Mouse motion is routed from `scripts/main.gd` to the player (captured motion doesn't cross the container).
- **Autoloads** (project.godot): `EventBus` (danger events with a `source` + `person_killed`), `GameState`
  (ui_mode, credits, `inventory: Inventory` (30 slots), reputation, places/waypoints, flags, clock,
  `pass_night()`, timed `effects`, `use_item()`, `wanted`), `Settings` (bus volumes, mouse sensitivity,
  user://settings.cfg), `Music` (street music, MusicZones, ducking, muffle), `SaveGame` (user://savegame.json,
  "saveable" group, `quit_game()` saves and exits cleanly).
- **Input ownership:** `GameState.claim_ui(mode, free_mouse)` / `release_ui()`. While `ui_mode != ""` the player
  can't move or interact and Main ignores Esc. Modes in use: trade, dialogue, paused, seated, sleeping, elevator.
- **Damage:** `scripts/combat/` — `HitInfo`, `Damageable` (`register(collider, target, zone, multiplier)`,
  `deliver(collider, hit)`), `GlassPane`, `BreakableProp`, `Car`, `Explosions.explode(node, pos, radius, damage,
  source)`, `DebrisPool`. `ImpactEffects` (bullet holes, sparks, blood bursts, stains) in `scripts/weapons/`.
- **People:** `scripts/actors/person.gd` (health, head hitbox area on layer 5, hit/death/collapse, panic timer fed
  by EventBus), `npc.gd` (wander/flee/cower on a runtime-baked sidewalk navmesh, `npc_crowd.gd`),
  `merchant.gd` (trade, bartering `judge_*_offer`, mood, reputation, revive/restock), `npc_model.gd`
  (box humanoid, `pose(phase, walk, run, cower, limp)`).
- **Weapons:** `scripts/weapons/firearm.gd` (`Firearm`: any hitscan gun, settings per scene: rifle/pistol/
  shotgun `.tscn`), bullets through `Hitscan.shoot` (`scripts/combat/hitscan.gd`, also used by enemies).
  `WeaponHolder` (hotbar, keys 1-3/wheel) under `Player/Head/RecoilPivot/Camera3D`; it syncs to weapon items
  (`ItemData.weapon_scene`). The player exposes `weapon` (gun in hand), `weapon_holder`, `health` (Damageable).
- **Items/economy:** one `ItemData` resource per item in `assets/items/`, loaded by `ItemDB` (static helpers);
  `ShopProfile` resources in `assets/shops/` loaded by `ShopCatalog`; `ItemModels` (low-poly item models),
  `ItemIcons` (renders icons once), `Pickup`, `ItemScatter`. UI: `ui/inventory_screen.gd`, `ui/item_slot.gd`.
- **Enemies:** `GangMember` (Person subclass) + `GangTurf` (Rust Jackals, west end of the main street) on the
  `EnemyNav` navmesh (layer 2, baked from colliders); `PoliceDispatch` (heat/wanted stars) + `PoliceDrone`.
  Cover = "cover" group (`Car`, `BreakableProp` >= 0.8 m, `CoverBlock`) with `cover_outline()`.
- **Interaction:** `scripts/interaction/interactable.gd` (Area3D on layer 6 with prompt / `prompt_source`),
  `door.gd`. Player casts a ray (mask world|props|interact) and shows `[E] prompt`.
- **World builders:** `scripts/world/city_builder.gd` (streets, frontages, `INTERIOR_LOTS` table that places
  interior scenes and leaves floors hollow, props, cars, lamps, metal footstep zones, walkable faces),
  `shop_interior.gd` (six themed shops), `sushi_cafe.gd`, `apartment_block.gd` (lobby, elevator, 11th floor,
  apartment 1107 with bed/couch/TV/fridge), `skyline.gd`, `flight_path.gd`, `geo_batch.gd` (merges primitives),
  `build_kit.gd` (lights, neon text, colliders, glass panes, steam), `mat_lib.gd` + `palette.gd`.
- **Audio:** buses Master / Music (low-pass "muffle" effect) / SFX / Ambience / UI in `default_bus_layout.tres`.
  `scripts/audio/music_zone.gd` = Area3D + diegetic speaker. Footsteps: `scripts/player/footsteps.gd`.
- **UI:** `ui/hud.gd` (crosshair, ammo, credits, clock, prompt, messages, fade, waypoint marker),
  `ui/trade_screen.gd`, `ui/dialogue_screen.gd` (+ `scripts/dialogue/guide_dialogue.gd` tree format),
  `ui/pause_menu.gd`, shared look in `ui/ui_style.gd` (monospace SystemFont, neon panels).
- **Physics layers:** 1 world, 2 player, 3 npc, 4 props (breakables, cars, glass), 5 hitbox (heads, car engines),
  6 interact, 7 debris. Rifle ray mask = 1|4|8|16 with `collide_with_areas = true`.
- **Groups used by systems:** player, hud, city, resettable (`reset()`), merchants (`revive()`),
  night_cleanup (`clear_for_new_night()`), music_zones, impact_effects, debris_pool, sfx_pool, explosions,
  trade_screen, dialogue_screen, pause_menu, inventory_screen, saveable (`save_key/save_data/load_data`),
  cover, enemies (`on_player_respawned()`), police (`clear_heat()`), police_drones, gang_turf, seat.
- **Gotchas learned the hard way:** don't name enums after native classes (`Theme`, `Material`); type loop
  variables over literal arrays (`for side: float in [-1.0, 1.0]`); avoid multi-line lambdas inside call
  arguments; PS1 vertex snapping fades with distance (big triangles warp otherwise); use `flat` varyings for
  values that feed hashes; `get_tree().paused` pauses the HUD unless it is `PROCESS_MODE_ALWAYS`.

## 5. Brief for prototype 4
Build in this order and finish each part (working, tested, committed) before the next.

### Part A: Inventory system
There's already an inventory in the background for trading (`GameState.inventory`, `ItemDB`). Make it a full system:
- An **inventory screen** opened with `Tab` or `I` (add it to the Input Map). The game pauses or the mouse is freed
  while it's open, and the UI matches the neon/monospace HUD style (`UiStyle`).
- A grid or list with **categories** (weapons, ammo, food/drinks, junk/sellables, valuables, key items), and
  **stacking** with maximum stack sizes.
- An **item detail panel:** name, icon (simple generated low-poly render or pixel icon), description, value, stack count.
- **Actions:** use/eat/drink (food gives a short, small effect, e.g. faster sprinting or less weapon sway, or is
  just flavour with a sound), drop (spawns a pickup in the world), inspect.
- **Key items:** the apartment key card for 1107, anything Ren gives you, etc.
- **Weapon/hotbar slot** with the KS-47, set up so more weapons are easy to add.
- **Item pickups in the world:** loot from bodies plus a few items scattered around the city, with a
  `[E] Pick up` prompt and a small HUD notification ("+ Synth-soda").
- A single **item database**, e.g. `Resource` files per item, used by the inventory, shops, loot and trade UI
  (migrate `ItemDB`'s dictionary and `ShopCatalog`).
- **Save system:** save credits, inventory, the clock, Ren's state (first meeting, waypoints) and merchant
  mood/reputation to `user://`. **Sleeping in the bed = save.** Also autosave on quit. Loading puts you back
  where you were (or in the apartment after sleeping).

### Part B: Combat (new this prototype; design it with the user's direction in mind)
Keep it in the same low-poly neon style and build on the existing systems:
- Enemies as a `Person` subclass (e.g. street gang or corporate security/police drones) using the existing
  navmesh, `Damageable` hit zones and EventBus danger. Perception (sight cone + hearing gunshots), states
  (patrol, alert, chase, take cover behind cars/props/barricades, shoot, flee when hurt).
- **Player health** (HUD bar, damage vignette, regen or med patches from the inventory), death/respawn in the
  apartment or at Ren's, with a small credit penalty.
- Enemy weapons through the same hitscan/HitInfo path; more player weapons via the hotbar from Part A
  (e.g. a pistol and a shotgun) with ammo items in `ItemDB`/item resources and a weapon switch.
- Hooks: police/heat reacting to violence (wanted level), merchants/Ren reacting, loot from enemies.

### Part C: Bug hunt and polish
Do a systematic pass for small bugs, visual bugs and lighting bugs and fix them. **Go through everything
methodically**, and record what you find and how you fixed it in `BUGFIX_NOTES.md`.
- **Errors/warnings:** run the project (headless and normally) and fix every error and warning: null references,
  orphaned nodes, signals never disconnected, missing resources, shader warnings.
- **Visual check with screenshots:** write a debug script/scene that flies the camera along fixed points (spawn in
  the noodle bar, the main street, every shop interior, the sushi cafe, the lobby, the elevator, the hallway, the
  apartment, the skyline) and saves screenshots. Look at them, fix what's wrong, re-shoot after fixing.
- **Lighting:** neon/street light leaking into interiors (and back), interiors too dark or too bright, light limits
  per mesh/cluster (popping or flickering at distance), harsh or missing shadows, glow too strong, exposure jumps
  between inside and outside, black or wrong reflections.
- **Visual:** z-fighting, floating or sunken props, gaps or seams, mirrored or stretched signs/textures, pop-in,
  the retro filter on the UI (UI must stay sharp), HUD/UI scaling at different resolutions and aspect ratios.
- **Gameplay/physics:** falling through floors, getting stuck on doors/thresholds/elevator, NPCs walking through
  walls or into shops, panicking NPCs stuck on corners, prompts through walls, [E] picking the wrong target,
  trade/inventory screens opened twice or while in the elevator, the mouse staying free after closing a menu,
  debris or bodies that never despawn, explosions breaking things through walls.
- **Performance:** check FPS in the busiest places (street during an explosion with panic, and combat with several
  enemies). Fix spikes from physics debris, too many lights or particles.
- Known issues to check first: test scripts that freeze player physics leave a stale `[E]` prompt (not a game
  bug, but verify focus clears when UIs open); the lobby and gun shop were only lightly lit-checked; the TV view
  from the couch is a fixed camera; NPCs can still clip props near busy corners.

### When done
Merge `Build-Fourth-Prototype` into `Development`, push, and give the user a short summary: what's built, new
controls, bugs fixed, known remaining problems, and a proposal for the next prototype (story, new levels and
other atmospheres). **Done:** see PROGRESS.md and BUGFIX_NOTES.md.

## 6. Proposal for prototype 5 (not agreed with the user yet; ask before starting)
- **Story, act 1, "Rent Paid":** who paid the rent on 1107? A short quest line through Ren, the terminal in
  the apartment and Doc Ichi's data shards: a data shard with a message for "the tenant of 1107", a
  courier job for Kaz, and a deal with (or against) the Rust Jackals. Needs a small quest system (quest log
  in the inventory screen, objectives on the HUD waypoint, flags in GameState) and a few new dialogue trees.
- **A second level with its own atmosphere:** the "Undercity" below Block 7: a flooded maintenance tunnel and
  night market under the overpass (green and amber light, steam, dripping water, a different music track),
  reached through a service door by the Jackals' barricade or the Neo-Heights basement. Loaded as its own
  scene with a transition, which needs the save system to remember which level the player is in.
- **Rooftops:** the Neo-Heights roof via the elevator (a third stop): wind, rain, the dragons up close, a
  sniper-perch encounter with police drones.
- **Smaller follow-ups:** the gang reacting to the player's reputation (a truce after the courier job), a
  bounty board at the Koi Bar, weather (rain on/off per night), and controller support.
