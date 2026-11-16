@tool
class_name MatLib
extends RefCounted
## Material factory. Everything in the world uses a handful of shared shaders so the retro
## look (vertex wobble, fog, glow) stays consistent. Identical requests share one material.

const SURFACE_SHADER := preload("res://shaders/ps1_surface.gdshader")
const NEON_SHADER := preload("res://shaders/neon.gdshader")
const GLASS_SHADER := preload("res://shaders/glass.gdshader")
const FACADE_SHADER := preload("res://shaders/building_facade.gdshader")
const STREET_SHADER := preload("res://shaders/street_ground.gdshader")
const HOLO_AD_SHADER := preload("res://shaders/holo_ad.gdshader")

static var _cache := {}


## Lit, opaque surface (walls, props, metal, wood).
static func surface(color: Color, roughness := 0.8, metallic := 0.0, grime := 0.15) -> ShaderMaterial:
	var key := "surface|%s|%.2f|%.2f|%.2f" % [color.to_html(), roughness, metallic, grime]
	if not _cache.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = SURFACE_SHADER
		mat.set_shader_parameter("albedo", color)
		mat.set_shader_parameter("roughness", roughness)
		mat.set_shader_parameter("metallic", metallic)
		mat.set_shader_parameter("grime", grime)
		_cache[key] = mat
	return _cache[key]


## Lit surface that also glows faintly (screens, lit panels, eyes behind glass).
static func glowing_surface(color: Color, glow: Color, energy := 1.5) -> ShaderMaterial:
	var key := "glowing|%s|%s|%.2f" % [color.to_html(), glow.to_html(), energy]
	if not _cache.has(key):
		var mat := surface(color, 0.4, 0.0, 0.0).duplicate() as ShaderMaterial
		mat.set_shader_parameter("emission_color", glow)
		mat.set_shader_parameter("emission_energy", energy)
		_cache[key] = mat
	return _cache[key]


## Unshaded neon. energy > 1 makes it bloom; flicker/blink animate it in the shader.
static func neon(color: Color, energy := 4.0, flicker := 0.0, blink_rate := 0.0, seed := 0.0, pulse := 0.0) -> ShaderMaterial:
	var key := "neon|%s|%.2f|%.2f|%.2f|%.2f|%.2f" % [color.to_html(), energy, flicker, blink_rate, seed, pulse]
	if not _cache.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = NEON_SHADER
		mat.set_shader_parameter("color", color)
		mat.set_shader_parameter("energy", energy)
		mat.set_shader_parameter("flicker", flicker)
		mat.set_shader_parameter("blink_rate", blink_rate)
		mat.set_shader_parameter("seed", seed)
		mat.set_shader_parameter("pulse", pulse)
		_cache[key] = mat
	return _cache[key]


static func glass(tint: Color) -> ShaderMaterial:
	var key := "glass|%s" % tint.to_html()
	if not _cache.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = GLASS_SHADER
		mat.set_shader_parameter("tint", tint)
		_cache[key] = mat
	return _cache[key]


## Building facade with procedural windows. `variation_source`: 0 uniforms, 1 vertex colour,
## 2 MultiMesh custom data (see building_facade.gdshader).
static func facade(variation_source := 1, ground_floor_height := 5.0, window_energy := 1.4) -> ShaderMaterial:
	var key := "facade|%d|%.2f|%.2f" % [variation_source, ground_floor_height, window_energy]
	if not _cache.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = FACADE_SHADER
		mat.set_shader_parameter("variation_source", variation_source)
		mat.set_shader_parameter("ground_floor_height", ground_floor_height)
		mat.set_shader_parameter("window_energy", window_energy)
		_cache[key] = mat
	return _cache[key]


## Wet street surface. tile_size > 0 draws paving tiles.
static func street(color: Color, roughness := 0.5, tile_size := 0.0, puddles := 0.55) -> ShaderMaterial:
	var key := "street|%s|%.2f|%.2f|%.2f" % [color.to_html(), roughness, tile_size, puddles]
	if not _cache.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = STREET_SHADER
		mat.set_shader_parameter("base_color", color)
		mat.set_shader_parameter("base_roughness", roughness)
		mat.set_shader_parameter("tile_size", tile_size)
		mat.set_shader_parameter("puddle_amount", puddles)
		_cache[key] = mat
	return _cache[key]


## Animated holographic advert (not cached: each billboard gets its own pattern and seed).
static func holo_ad(color_a: Color, color_b: Color, pattern: int, seed: float, energy := 2.5) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = HOLO_AD_SHADER
	mat.set_shader_parameter("color_a", color_a)
	mat.set_shader_parameter("color_b", color_b)
	mat.set_shader_parameter("pattern", pattern)
	mat.set_shader_parameter("seed", seed)
	mat.set_shader_parameter("energy", energy)
	return mat
