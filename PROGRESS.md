# Progress

Living status file so work can be picked up in a new session. Updated with every commit.

## Branches
- `main`: initial commit only (releases are done by hand from `Development`).
- `Development`: prototype 1 merged.
- `Build-Second-Prototype`: prototype 2 (finishing Part 0 here, then merge into `Development`).
- `Build-Third-Prototype`: prototype 3 (created after Part 0 is merged).

Commits are authored as J0C0M via one-off `git -c user.name=... -c user.email=...` flags
(git config itself is empty on this machine). Godot 4.7.2 binary: `~/Downloads/Godot_v4.7.2-stable_linux.x86_64`.

## Prototype 2: done
Damage system + EventBus, breakable glass, NPC deaths and panic, breakable props, exploding cars,
interaction system, inventory + credits + loot, six shops + sushi chef with trade UI and bartering,
Ren the guide with dialogue and waypoints, reworked footsteps, Neo-Heights lobby/elevator/hallway.

## Part 0 (finish prototype 2): in progress
- [x] Apartment 1107 interior (bed, couch, TV, kitchenette, clutter, window view)
- [x] Sleep: fade, clock skip, night reset (restock merchants, repair glass/props/cars, clear bodies)
- [x] Couch + TV with four invented channels
- [ ] README + CREDITS updated
- [x] Visual checks (apartment block, gun shop, props): lobby brightened, TV enlarged
- [ ] Merge `Build-Second-Prototype` into `Development`

## Prototype 3: not started
- Part 1: music + audio buses + settings menu
- Part 2: inventory screen, item resources, hotbar, pickups, save system
- Part 3: bug hunt, screenshot tour, BUGFIX_NOTES.md
