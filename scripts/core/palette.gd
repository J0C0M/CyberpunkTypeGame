class_name Palette
extends RefCounted
## Shared colours for the city: saturated neons plus dark base tones.

const PINK := Color(1.0, 0.16, 0.62)
const CYAN := Color(0.1, 0.88, 1.0)
const PURPLE := Color(0.62, 0.28, 1.0)
const AMBER := Color(1.0, 0.58, 0.12)
const LIME := Color(0.45, 1.0, 0.3)
const RED := Color(1.0, 0.1, 0.16)
const WARM_WHITE := Color(1.0, 0.86, 0.68)
const COOL_WHITE := Color(0.75, 0.88, 1.0)

const NEONS: Array[Color] = [PINK, CYAN, PURPLE, AMBER, LIME, RED]

const ASPHALT := Color(0.045, 0.045, 0.06)
const CONCRETE := Color(0.13, 0.13, 0.16)
const CONCRETE_DARK := Color(0.07, 0.07, 0.095)
const METAL := Color(0.22, 0.23, 0.27)
const METAL_DARK := Color(0.08, 0.085, 0.1)
const WOOD := Color(0.32, 0.18, 0.1)
const WOOD_LIGHT := Color(0.55, 0.38, 0.22)


static func random_neon(rng: RandomNumberGenerator) -> Color:
	return NEONS[rng.randi() % NEONS.size()]
