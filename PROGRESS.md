# Progress

Living status file so work can be picked up in a new session. Updated with every commit.

## Branches
- `main`: initial commit only (releases are done by hand from `Development`).
- `Development`: prototypes 1 and 2 merged.
- `Build-Second-Prototype`: prototype 2 (merged into `Development`).
- `Build-Third-Prototype`: prototype 3 (created after Part 0 is merged).

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

## Prototype 3 (branch `Build-Third-Prototype`): in progress
- Part 1: music + audio buses + settings menu: **done**
  - `tools/generate_music.py` (numpy + ffmpeg) makes 10 original looping OGG tracks in `assets/music/`.
  - Buses in `default_bus_layout.tres`: Master, Music (low-pass "muffle" effect), SFX, Ambience, UI.
  - `Music` autoload (scripts/audio/music_director.gd): street music, ducking per `GameState.ui_mode`,
    muffle after nearby danger. `MusicZone` (scripts/audio/music_zone.gd): diegetic speakers,
    muffled outside / clear inside; zones in every shop, cafe, lobby, elevator cab, hallway (quiet),
    apartment radio (fades while the TV is on).
  - `Settings` autoload + `ui/pause_menu.gd` (Esc): bus volumes, mouse sensitivity, saved to user://settings.cfg.
- Part 2: inventory screen, item resources, hotbar, pickups, save system
- Part 3: bug hunt, screenshot tour, BUGFIX_NOTES.md
