class_name MatLib
extends RefCounted
## Material factory. Everything in the world uses a handful of shared shaders so the retro
## look (vertex wobble, fog, glow) stays consistent. Identical requests share one material.

const SURFACE_SHADER := preload("res://shaders/ps1_surface.gdshader")
const NEON_SHADER := preload("res://shaders/neon.gdshader")
const GLASS_SHADER := preload("res://shaders/glass.gdshader")

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
