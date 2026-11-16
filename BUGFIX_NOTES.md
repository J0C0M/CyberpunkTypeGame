# Bug fix notes (prototype 4, Part C)

A systematic pass over errors, visuals, lighting, gameplay/physics and performance. Each entry says
what was wrong, how it was found and what changed. Tools used for the pass (all in the repo):

- `godot --path . -- --tour=/tmp/tour [--only=a,b] [--frames=N]`: flies the camera through 27 fixed
  viewpoints (spawn, streets, every shop inside and out, sushi cafe, lobby, elevator, hallway,
  apartment, the gang corner, the skyline) and saves a screenshot of each (`scripts/debug/screenshot_tour.gd`).
- Headless tests in `tests/` (`test_*.tscn`), screenshot scenes (`shot_*.tscn`), `tests/test_crowd.tscn`
  (pedestrian stuck rate) and `tests/test_quit.tscn` (clean exit).

## Errors and warnings

| # | Problem | Found by | Fix |
| --- | --- | --- | --- |
| 1 | Every exit printed "51 ObjectDB instances were leaked" and "23 resources still in use". `--verbose` showed they were all audio streams (music, ambience, hums) still playing when the engine shut down. | Headless and windowed runs, `--verbose` | Quitting now goes through `SaveGame.quit_game()` (pause menu and closing the window): it saves, stops every audio player and quits a few frames later, once the audio thread has released the stopped streams. `tests/test_quit.tscn` exits cleanly headless and windowed. Runs cut off by `--quit-after` can still print the leak lines; that is the engine shutting down mid-playback, not a game bug. |
| 2 | `ammo_changed.emit.call_deferred(a, b)` captured the ammo numbers when it was called, so a change in the same frame (picking up ammo, loading a save) was overwritten by stale numbers on the HUD. | Inventory screenshot showed "/ 060" with 260 rounds carried | The deferred call now runs a method that reads the current values. |
| 3 | `--verbose` prints "Image format RGBFloat not supported by hardware" for particle curve textures. | Verbose windowed run | Harmless engine conversion (only shown in verbose mode); left as is. |

## Visual and lighting

| # | Problem | Found by | Fix |
| --- | --- | --- | --- |
| 4 | Apartment door numbers, lock lights and trim faced into the apartments, so from the hallway every door was a blank slab. `Door` is built facing its local +Z, but the apartment block rotated all six doors the wrong way round. | Tour: `hallway_doors` | The apartment block turns the doors to face the hallway; the 1107 key-card check uses the door's real hallway side again. |
| 5 | Street name signs: the pole ran through the middle of the plates, cutting a letter out of "CROW ST" and "KABUKI AVE". | Tour: `crossing_sidewalk` | Plates and lettering now hang beside the pole. |
| 6 | The Neo-Heights lobby and the 11th-floor hallway were nearly black (one weak light per room). | Tour: `lobby`, `hallway` | A general fill light in the lobby; three brighter lights along the hallway. |
| 7 | Cyberware's interior was too dark (near-black walls, no light over the shop floor); Iron Lotus Arms was lit only from behind the counter, all red. | Tour: `shop_cyberware_inside`, `shop_guns_inside` | Lighter walls and a cold ceiling light in Cyberware; a work light by the door in the gun shop. |
| 8 | Screenshot tours and tests that freeze the player showed a stale "[E] Talk to Ren" prompt in every image. | Every tour image | The HUD only shows a prompt for a player whose physics is running. (In normal play the focus already cleared when a menu opened.) |
| 9 | Damage vignette covered most of the screen in red during a firefight. | `tests/shot_gang.tscn` | Smaller, weaker vignette that fades faster. |
| 10 | The pistol and shotgun view models were dark, small shapes, nearly invisible at night. | `tests/shot_weapons.tscn` | Lighter two-tone materials, wood on the shotgun, stronger fill lights, pistol held a little higher. |
| 11 | Police drones read as floating lights, not machines. | `tests/shot_police.tscn` | A third bigger, with a light belt and red/blue side bars. |

## Gameplay and physics

| # | Problem | Found by | Fix |
| --- | --- | --- | --- |
| 12 | Pedestrians got stuck on lamp posts, bins and sign poles near busy corners (14.8 % of walking time spent pushing against something, 16 people stuck 3 s or more in 40 s with one panic). Props weren't part of their navmesh, and crowd avoidance pushed people off the walkable band. | `tests/test_crowd.tscn` (stuck-rate measurement, `-- --no-obstacles` for the old behaviour, `-- --where` for hotspots) | Every prop, car and small static obstacle is cut out of the pedestrian navmesh, and a pedestrian stuck for 1.2 s steps back onto the navmesh and picks a new route. Now 0.3-0.8 %, nobody stuck 3 s. |
| 13 | Explosions damaged everything in range, through walls: a car blowing up outside a shop hurt the shopkeeper (and now the player) inside. | Code review of `Explosions._apply_damage` | A line-of-sight check against the static world; glass and props (other layers) still break. |
| 14 | Merchants lost reputation with the player and got angry about gunfire the player didn't cause (any shot near the shop counted). | Code review while adding the gang | Danger events pass on who caused them; merchants only blame the player's shots and hits. |
| 15 | The couch view was a fixed camera. | Known issue from the handoff | Seated, the mouse turns the head a little (about 40 degrees each way). |
| 16 | Flatlining while seated would have left the camera stuck at the couch; flatlining during an elevator ride would have handed control back early when the ride finished. | Code review of the new death sequence | The seat lets go of the camera when the player dies; the elevator ride stops quietly if something else takes over input. |
| 17 | The 1107 door's interact box sat mostly on one side of the door, only a centimetre ahead of the panel's collider from the other side. | Writing the key-card test | The box is centred on the door, so both sides reach it before the panel. |
