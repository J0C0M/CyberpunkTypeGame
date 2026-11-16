# Credits

## Engine

- [Godot Engine](https://godotengine.org) 4.7, MIT license.

## Assets

No third-party asset packs are used. Everything is original to this project:

| Asset | Source | License |
| --- | --- | --- |
| All 3D models (city, cafe, rifle, NPCs, dragons, props) | Generated from primitives by the scripts in `scripts/` | Project |
| All textures (bullet holes, steam puffs) | Generated at runtime in code | Project |
| Shaders | Written for this project (`shaders/`) | Project |
| Sound effects, footsteps and TV audio (`assets/audio/**`) | Synthesised by `tools/generate_sfx.py` | Project |
| TV channels, brands and shows (NEO-7 News, Vantalume, Mecha-Koi Strike!!) | Invented for this project | Project |
| Icon (`icon.svg`) | Made for this project | Project |

## Fonts

- Sign text uses Godot's built-in default font, with system fonts as fallback for Japanese
  characters. Nothing is bundled.
- The HUD asks the system for a monospace font (`SystemFont`: JetBrains Mono, DejaVu Sans Mono,
  Liberation Mono or Noto Sans Mono) and falls back to Godot's default font. Nothing is bundled.

## Adding assets later

CC0 packs such as [Kenney](https://kenney.nl) fit the low-poly style. When adding any external
asset, list it here with its source URL and license.
