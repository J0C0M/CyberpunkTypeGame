class_name ItemModels
extends RefCounted
## Low-poly models of the items, built from primitives like the rest of the city. Used for the
## inventory icons (ItemIcons), the inspect view and pickups lying in the world. Models sit on
## their origin (resting on the ground) at real-world size, in metres.


## A MeshInstance3D of item `id`. `min_size` scales small items up so their longest side is at
## least that long (pickups stay visible on the ground).
static func build(id: StringName, min_size := 0.0) -> MeshInstance3D:
	var data := ItemDB.item(id)
	var shape := data.model if data else &"box"
	var tint := ItemDB.tint(id)
	var geo := GeoBatch.new()
	_add_shape(geo, shape, tint)
	var mesh := geo.build("ItemModel", false)
	if min_size > 0.0:
		var longest := mesh.mesh.get_aabb().get_longest_axis_size()
		if longest > 0.0 and longest < min_size:
			mesh.scale = Vector3.ONE * (min_size / longest)
	return mesh


static func _add_shape(geo: GeoBatch, shape: StringName, tint: Color) -> void:
	var dark := MatLib.surface(Color(0.06, 0.06, 0.07), 0.5, 0.3, 0.0)
	var metal := MatLib.surface(Color(0.5, 0.52, 0.56), 0.3, 0.8, 0.0)
	var paper := MatLib.surface(Color(0.9, 0.86, 0.76), 0.9, 0.0, 0.0)
	var glow := MatLib.neon(tint, 2.5)
	match shape:
		&"bowl":
			geo.add_cylinder(0.08, 0.13, 0.085, 10, Transform3D(Basis.IDENTITY, Vector3(0, 0.0425, 0)), MatLib.surface(Color(0.92, 0.9, 0.86), 0.4, 0.0, 0.0))
			geo.add_cylinder(0.122, 0.122, 0.01, 10, Transform3D(Basis.IDENTITY, Vector3(0, 0.075, 0)), MatLib.neon(Color(0.95, 0.6, 0.3), 1.6))
			geo.add_box_at(Vector3(0.1, 0.012, 0.05), Vector3(0.02, 0.083, 0.02), MatLib.surface(Color(0.95, 0.5, 0.55), 0.6, 0.0, 0.0))
			geo.add_box_at(Vector3(0.025, 0.01, 0.025), Vector3(-0.04, 0.083, -0.03), MatLib.surface(Color(0.2, 0.5, 0.15), 0.8, 0.0, 0.0))
			geo.add_bar(Vector3(-0.12, 0.09, 0.08), Vector3(0.14, 0.12, -0.02), 0.008, MatLib.surface(Palette.WOOD_LIGHT, 0.7, 0.0, 0.0))
			geo.add_bar(Vector3(-0.12, 0.09, 0.1), Vector3(0.14, 0.12, 0.0), 0.008, MatLib.surface(Palette.WOOD_LIGHT, 0.7, 0.0, 0.0))
			geo.add_cylinder(0.131, 0.131, 0.012, 10, Transform3D(Basis.IDENTITY, Vector3(0, 0.07, 0)), glow, false)
		&"sushi":
			geo.add_box_at(Vector3(0.26, 0.02, 0.13), Vector3(0, 0.01, 0), dark)
			geo.add_box_at(Vector3(0.262, 0.004, 0.132), Vector3(0, 0.021, 0), MatLib.neon(Palette.RED, 2.0))
			var tops := [Color(1.0, 0.45, 0.25), Color(0.85, 0.12, 0.18), Color(1.0, 0.75, 0.6), Color(0.95, 0.85, 0.2)]
			for i in 4:
				var x := -0.09 + i * 0.06
				geo.add_box_at(Vector3(0.045, 0.026, 0.07), Vector3(x, 0.035, 0), MatLib.surface(Color(0.95, 0.95, 0.92), 0.9, 0.0, 0.0))
				geo.add_box_at(Vector3(0.05, 0.012, 0.08), Vector3(x, 0.054, 0), MatLib.surface(tops[i], 0.5, 0.0, 0.0))
		&"onigiri":
			var facing := Basis(Vector3.RIGHT, PI * 0.5)
			geo.add_cylinder(0.065, 0.065, 0.04, 3, Transform3D(facing.rotated(Vector3.FORWARD, PI), Vector3(0, 0.035, 0)), MatLib.surface(Color(0.96, 0.96, 0.93), 0.9, 0.0, 0.0))
			geo.add_box_at(Vector3(0.05, 0.035, 0.044), Vector3(0, 0.018, 0), MatLib.surface(Color(0.04, 0.1, 0.06), 0.6, 0.0, 0.0))
		&"can":
			geo.add_cylinder(0.033, 0.033, 0.11, 10, Transform3D(Basis.IDENTITY, Vector3(0, 0.055, 0)), MatLib.surface(tint.darkened(0.25), 0.3, 0.6, 0.0))
			geo.add_cylinder(0.034, 0.034, 0.03, 10, Transform3D(Basis.IDENTITY, Vector3(0, 0.06, 0)), glow, false)
			geo.add_cylinder(0.03, 0.03, 0.008, 10, Transform3D(Basis.IDENTITY, Vector3(0, 0.114, 0)), metal)
		&"bottle":
			geo.add_cylinder(0.042, 0.042, 0.17, 8, Transform3D(Basis.IDENTITY, Vector3(0, 0.085, 0)), MatLib.surface(Color(0.85, 0.9, 0.92), 0.2, 0.1, 0.0))
			geo.add_cylinder(0.042, 0.016, 0.04, 8, Transform3D(Basis.IDENTITY, Vector3(0, 0.19, 0)), MatLib.surface(Color(0.85, 0.9, 0.92), 0.2, 0.1, 0.0))
			geo.add_cylinder(0.016, 0.016, 0.05, 8, Transform3D(Basis.IDENTITY, Vector3(0, 0.235, 0)), MatLib.surface(Color(0.85, 0.9, 0.92), 0.2, 0.1, 0.0))
			geo.add_cylinder(0.017, 0.017, 0.02, 8, Transform3D(Basis.IDENTITY, Vector3(0, 0.265, 0)), MatLib.surface(Palette.RED, 0.5, 0.0, 0.0))
			geo.add_box_at(Vector3(0.05, 0.07, 0.01), Vector3(0, 0.09, 0.04), paper)
			geo.add_box_at(Vector3(0.03, 0.03, 0.004), Vector3(0, 0.095, 0.047), MatLib.surface(Palette.RED, 0.6, 0.0, 0.0))
		&"patch":
			geo.add_box_at(Vector3(0.11, 0.008, 0.08), Vector3(0, 0.004, 0), MatLib.surface(Color(0.92, 0.94, 0.92), 0.6, 0.0, 0.0))
			geo.add_box_at(Vector3(0.05, 0.004, 0.014), Vector3(0, 0.01, 0), MatLib.neon(Palette.LIME, 3.0))
			geo.add_box_at(Vector3(0.014, 0.004, 0.05), Vector3(0, 0.01, 0), MatLib.neon(Palette.LIME, 3.0))
		&"injector":
			var lying := Basis(Vector3.FORWARD, PI * 0.5)
			geo.add_cylinder(0.014, 0.014, 0.12, 8, Transform3D(lying, Vector3(0, 0.014, 0)), MatLib.surface(Color(0.85, 0.85, 0.9), 0.3, 0.2, 0.0))
			geo.add_cylinder(0.015, 0.015, 0.04, 8, Transform3D(lying, Vector3(0.01, 0.014, 0)), MatLib.neon(Palette.CYAN, 3.0))
			geo.add_cylinder(0.008, 0.004, 0.02, 6, Transform3D(lying, Vector3(-0.07, 0.014, 0)), metal)
			geo.add_cylinder(0.016, 0.016, 0.02, 8, Transform3D(lying, Vector3(0.07, 0.014, 0)), MatLib.surface(Palette.RED, 0.5, 0.0, 0.0))
		&"scrap":
			var rust := MatLib.surface(Color(0.4, 0.22, 0.12), 0.9, 0.4, 0.3)
			geo.add_box(Vector3(0.16, 0.012, 0.05), Transform3D(Basis(Vector3.UP, 0.4), Vector3(0, 0.006, 0)), rust)
			geo.add_box(Vector3(0.1, 0.05, 0.012), Transform3D(Basis(Vector3.UP, -0.7), Vector3(0.02, 0.025, 0.02)), metal)
			geo.add_bar(Vector3(-0.07, 0.01, -0.03), Vector3(0.05, 0.06, -0.05), 0.012, rust)
		&"chip":
			geo.add_box_at(Vector3(0.05, 0.008, 0.05), Vector3(0, 0.006, 0), dark)
			for i in 5:
				for side: float in [-1.0, 1.0]:
					geo.add_box_at(Vector3(0.006, 0.003, 0.012), Vector3(-0.02 + i * 0.01, 0.003, side * 0.03), MatLib.surface(Color(0.9, 0.7, 0.2), 0.3, 0.9, 0.0))
			geo.add_box_at(Vector3(0.02, 0.002, 0.016), Vector3(0.006, 0.011, -0.004), MatLib.surface(Color(0.02, 0.01, 0.01), 0.9, 0.0, 0.0))
		&"shard":
			geo.add_box_at(Vector3(0.03, 0.02, 0.03), Vector3(0, 0.01, 0), metal)
			geo.add_cylinder(0.014, 0.004, 0.08, 6, Transform3D(Basis.IDENTITY, Vector3(0, 0.06, 0)), MatLib.neon(Palette.CYAN, 2.2))
		&"board":
			geo.add_box_at(Vector3(0.16, 0.008, 0.1), Vector3(0, 0.004, 0), MatLib.surface(Color(0.05, 0.3, 0.15), 0.6, 0.0, 0.0))
			geo.add_box_at(Vector3(0.04, 0.008, 0.04), Vector3(-0.03, 0.012, 0.0), dark)
			geo.add_box_at(Vector3(0.025, 0.006, 0.05), Vector3(0.045, 0.011, 0.01), dark)
			geo.add_bar(Vector3(-0.08, 0.01, -0.03), Vector3(0.07, 0.01, 0.04), 0.004, MatLib.neon(Palette.RED, 3.0))
		&"cat":
			var gold := MatLib.surface(Color(0.95, 0.75, 0.2), 0.3, 0.8, 0.0)
			geo.add_box_at(Vector3(0.07, 0.07, 0.05), Vector3(0, 0.035, 0), gold)
			geo.add_box_at(Vector3(0.065, 0.055, 0.05), Vector3(0, 0.1, 0), gold)
			for side: float in [-1.0, 1.0]:
				geo.add_box(Vector3(0.015, 0.02, 0.01), Transform3D(Basis(Vector3.FORWARD, side * 0.3), Vector3(side * 0.022, 0.135, 0)), gold)
			geo.add_box_at(Vector3(0.015, 0.045, 0.015), Vector3(0.04, 0.11, 0.01), gold)
			geo.add_box_at(Vector3(0.04, 0.012, 0.004), Vector3(0, 0.045, 0.026), MatLib.surface(Palette.RED, 0.5, 0.0, 0.0))
			geo.add_box_at(Vector3(0.012, 0.006, 0.003), Vector3(-0.012, 0.105, 0.026), dark)
			geo.add_box_at(Vector3(0.012, 0.006, 0.003), Vector3(0.012, 0.105, 0.026), dark)
		&"vinyl":
			geo.add_box(Vector3(0.3, 0.3, 0.008), Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, 0.15, 0)), MatLib.surface(Color(0.9, 0.4, 0.3), 0.8, 0.0, 0.0))
			geo.add_cylinder(0.14, 0.14, 0.004, 14, Transform3D(Basis(Vector3.RIGHT, PI * 0.5 - 0.25), Vector3(0.06, 0.17, 0.012)), MatLib.surface(Color(0.02, 0.02, 0.02), 0.2, 0.0, 0.0))
			geo.add_cylinder(0.045, 0.045, 0.006, 10, Transform3D(Basis(Vector3.RIGHT, PI * 0.5 - 0.25), Vector3(0.06, 0.17, 0.012)), MatLib.surface(Palette.AMBER, 0.6, 0.0, 0.0))
		&"lighter":
			var gold := MatLib.surface(Color(0.95, 0.78, 0.3), 0.2, 0.9, 0.0)
			geo.add_box_at(Vector3(0.038, 0.045, 0.014), Vector3(0, 0.0225, 0), gold)
			geo.add_box_at(Vector3(0.038, 0.016, 0.014), Vector3(0, 0.055, 0), gold)
			geo.add_box_at(Vector3(0.026, 0.003, 0.0145), Vector3(0, 0.0465, 0), dark)
		&"koi":
			var jade := MatLib.surface(Color(0.2, 0.6, 0.38), 0.3, 0.0, 0.0)
			geo.add_box_at(Vector3(0.09, 0.02, 0.06), Vector3(0, 0.01, 0), MatLib.surface(Color(0.15, 0.4, 0.28), 0.4, 0.0, 0.0))
			geo.add_sphere(0.05, Transform3D(Basis(Vector3.FORWARD, 0.6).scaled(Vector3(1.6, 0.8, 0.7)), Vector3(0, 0.07, 0)), jade, 8, 5)
			geo.add_box(Vector3(0.04, 0.05, 0.008), Transform3D(Basis(Vector3.FORWARD, 0.3), Vector3(-0.07, 0.03, 0)), jade)
		&"lens":
			geo.add_cylinder(0.035, 0.035, 0.02, 12, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.035, 0)), metal)
			geo.add_cylinder(0.022, 0.022, 0.022, 12, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.035, 0.002)), MatLib.neon(Palette.RED, 2.5))
			geo.add_box_at(Vector3(0.05, 0.012, 0.03), Vector3(0, 0.006, 0), dark)
		&"implant":
			geo.add_box_at(Vector3(0.12, 0.025, 0.05), Vector3(0, 0.0125, 0), metal)
			geo.add_box_at(Vector3(0.122, 0.006, 0.02), Vector3(0, 0.026, 0), MatLib.neon(Palette.PURPLE, 3.0))
			for i in 3:
				geo.add_cylinder(0.006, 0.006, 0.03, 6, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.07, 0.0125, -0.015 + i * 0.015)), dark)
		&"wire_kit":
			geo.add_box_at(Vector3(0.18, 0.05, 0.12), Vector3(0, 0.025, 0), dark)
			for i in 3:
				var neon := MatLib.neon([Palette.CYAN, Palette.PINK, Palette.LIME][i], 2.5)
				geo.add_cylinder(0.025, 0.025, 0.012, 10, Transform3D(Basis.IDENTITY, Vector3(-0.05 + i * 0.05, 0.056, 0)), neon)
		&"ammo_box":
			# An open box with rows of rounds poking out.
			geo.add_box_at(Vector3(0.13, 0.06, 0.08), Vector3(0, 0.03, 0), MatLib.surface(Color(0.3, 0.3, 0.32), 0.6, 0.6, 0.0))
			geo.add_box_at(Vector3(0.132, 0.012, 0.082), Vector3(0, 0.04, 0), MatLib.neon(tint, 2.5))
			geo.add_box_at(Vector3(0.05, 0.025, 0.002), Vector3(-0.025, 0.02, 0.041), paper)
			var brass := MatLib.surface(Color(0.85, 0.6, 0.2), 0.3, 0.9, 0.0)
			for row in 3:
				for col in 6:
					var at := Vector3(-0.05 + col * 0.02, 0.07, -0.022 + row * 0.022)
					geo.add_cylinder(0.007, 0.004, 0.026, 5, Transform3D(Basis.IDENTITY, at), brass)
		&"rifle":
			var steel := MatLib.surface(Color(0.2, 0.2, 0.22), 0.35, 0.7, 0.0)
			var wood := MatLib.surface(Color(0.5, 0.26, 0.11), 0.5, 0.0, 0.0)
			geo.add_box_at(Vector3(0.32, 0.07, 0.05), Vector3(0, 0.08, 0), steel)
			geo.add_box_at(Vector3(0.24, 0.04, 0.05), Vector3(0.27, 0.08, 0), wood)
			geo.add_cylinder(0.011, 0.011, 0.36, 8, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.5, 0.09, 0)), steel)
			geo.add_box(Vector3(0.26, 0.06, 0.04), Transform3D(Basis(Vector3.FORWARD, -0.1), Vector3(-0.29, 0.065, 0)), wood)
			geo.add_box(Vector3(0.06, 0.12, 0.03), Transform3D(Basis(Vector3.FORWARD, -0.35), Vector3(0.06, 0.0, 0)), steel)
			geo.add_box(Vector3(0.03, 0.08, 0.03), Transform3D(Basis(Vector3.FORWARD, 0.3), Vector3(-0.1, 0.02, 0)), steel)
			geo.add_box_at(Vector3(0.16, 0.006, 0.052), Vector3(0.27, 0.088, 0), MatLib.neon(Palette.CYAN, 3.0))
			geo.add_box_at(Vector3(0.08, 0.035, 0.035), Vector3(0.0, 0.135, 0), steel)
		&"keycard":
			geo.add_box_at(Vector3(0.086, 0.004, 0.054), Vector3(0, 0.002, 0), MatLib.surface(tint.darkened(0.3), 0.4, 0.2, 0.0))
			geo.add_box_at(Vector3(0.086, 0.002, 0.01), Vector3(0, 0.0045, 0.015), MatLib.neon(tint, 3.0))
			geo.add_box_at(Vector3(0.016, 0.002, 0.012), Vector3(-0.025, 0.0045, -0.01), MatLib.surface(Color(0.9, 0.75, 0.3), 0.3, 0.9, 0.0))
		&"coupon":
			geo.add_box_at(Vector3(0.13, 0.003, 0.065), Vector3(0, 0.0015, 0), paper)
			geo.add_box_at(Vector3(0.025, 0.002, 0.025), Vector3(0.04, 0.004, 0), MatLib.surface(Palette.RED, 0.6, 0.0, 0.0))
			geo.add_box_at(Vector3(0.06, 0.002, 0.008), Vector3(-0.02, 0.004, 0.012), MatLib.neon(tint, 2.0))
		_:
			geo.add_box_at(Vector3(0.18, 0.12, 0.14), Vector3(0, 0.06, 0), MatLib.surface(tint.darkened(0.6), 0.4, 0.3, 0.0))
			geo.add_box_at(Vector3(0.19, 0.03, 0.15), Vector3(0, 0.09, 0), glow)
