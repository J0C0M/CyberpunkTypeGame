class_name ShopCatalog
extends RefCounted
## Merchant stock profiles: one ShopProfile resource per kind of shop in res://assets/shops/
## (file name = profile id, e.g. "guns"). Unknown ids fall back to the pawn shop.

const FOLDER := "res://assets/shops/"

static var _profiles := {}


static func profile(id: StringName) -> ShopProfile:
	if not _profiles.has(id):
		var path := FOLDER + String(id) + ".tres"
		_profiles[id] = load(path) if ResourceLoader.exists(path) else null
	var result: ShopProfile = _profiles[id]
	return result if result else profile(&"pawn")
