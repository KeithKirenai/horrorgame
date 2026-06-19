extends RefCounted
class_name SetPieceSpawner

static func spawn_steam_vent(parent, cx: float, cz: float, grid, CELL_SIZE: float):
	var root = Node3D.new(); root.name = "SteamVent"
	var pipe := MeshFactory.cylinder(0.06, 0.08, 0.6, 6, MaterialFactory.make_unshaded(Color(0.25, 0.25, 0.25), load("res://assets/textures/metal_rust.png")))
	pipe.position.y = 0.3; root.add_child(pipe)
	var puff := MeshFactory.sphere(0.08, 0.16, 6, 4)
	var puff_mat := MaterialFactory.make_unshaded(Color(0.7, 0.7, 0.75, 0.0))
	puff.material_override = puff_mat
	puff.position.y = 0.7; root.add_child(puff)
	var puff_sm := puff.mesh as SphereMesh
	var st = Timer.new(); st.wait_time = randf_range(3.0, 6.0); st.autostart = true
	root.add_child(st)
	var puff_time = 0.0
	st.timeout.connect(func():
		puff_time = 0.0
		puff_mat.albedo_color = Color(0.7, 0.7, 0.75, 0.4)
		puff_sm.radius = 0.08; puff_sm.height = 0.16
		st.wait_time = randf_range(3.0, 6.0)
	)
	var at = Timer.new(); at.wait_time = 0.05; at.autostart = true
	root.add_child(at)
	at.timeout.connect(func():
		if puff_mat.albedo_color.a > 0.01:
			puff_time += 0.05
			var progress = puff_time / 2.0
			puff_sm.radius = 0.08 + progress * 0.25
			puff_sm.height = 0.16 + progress * 0.5
			puff_mat.albedo_color.a = max(0.0, 0.4 * (1.0 - progress))
	)
	root.position = Vector3(cx, 0.0, cz)
	parent.nav_region.add_child(root)

static func spawn_page_shrine(parent, cx: float, cz: float, CELL_SIZE: float):
	var lamp = OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.98, 0.92)
	lamp.light_energy = 2.5
	lamp.omni_range = 7.0
	lamp.shadow_enabled = false
	lamp.position = Vector3(cx, parent.WALL_HEIGHT - 0.5, cz)
	parent.nav_region.add_child(lamp)
	var candle_root = Node3D.new()
	var candle := MeshFactory.cylinder(0.025, 0.025, 0.18, 5, MaterialFactory.make_unshaded(Color(0.95, 0.92, 0.82)))
	candle.position.y = 0.09; candle_root.add_child(candle)
	var flame = OmniLight3D.new()
	flame.light_color = Color(1.0, 0.6, 0.2)
	flame.light_energy = 0.8; flame.omni_range = 2.5; flame.shadow_enabled = false
	flame.position.y = 0.23; candle_root.add_child(flame)
	candle_root.position = Vector3(cx + randf_range(-0.8, 0.8), 0.0, cz + randf_range(-0.8, 0.8))
	parent.nav_region.add_child(candle_root)

static func spawn_generator_room_marker(parent, cx: float, cz: float, gen_index: int, CELL_SIZE: float):
	var cell_y = 0.0
	var marker := MeshFactory.quad(Vector2(1.8, 0.4), MaterialFactory.make_unshaded(Color(0.9, 0.7, 0.1)))
	marker.rotation.x = -PI * 0.5
	marker.position = Vector3(cx, cell_y + 0.01, cz)
	parent.nav_region.add_child(marker)
	var warn_light = OmniLight3D.new()
	warn_light.light_color = Color(0.8, 0.3, 0.1)
	warn_light.light_energy = 1.0
	warn_light.omni_range = 4.0
	warn_light.shadow_enabled = false
	warn_light.position = Vector3(cx, parent.WALL_HEIGHT - 0.4, cz)
	parent.nav_region.add_child(warn_light)

	if gen_index == 2:
		var floor_plate := MeshFactory.plane(Vector2(CELL_SIZE - 0.1, CELL_SIZE - 0.1), MaterialFactory.make_unshaded(Color(0.4, 0.4, 0.4), load("res://assets/textures/metal_rust.png")))
		floor_plate.position = Vector3(cx, cell_y + 0.004, cz)
		parent.nav_region.add_child(floor_plate)
		var grid = parent.grid
		var cell_x = int(cx / CELL_SIZE)
		var cell_z = int(cz / CELL_SIZE)
		var cell = grid[cell_x][cell_z]
		var sign_sides = []
		if cell.n: sign_sides.append("n")
		if cell.s: sign_sides.append("s")
		if cell.w: sign_sides.append("w")
		if cell.e: sign_sides.append("e")
		if not sign_sides.is_empty():
			var side = sign_sides.pick_random()
			var sx = cx; var sz = cz; var s_rot_y = 0.0
			match side:
				"n": sz = cz - CELL_SIZE/2.0 + parent.WALL_THICKNESS + 0.03
				"s": sz = cz + CELL_SIZE/2.0 - parent.WALL_THICKNESS - 0.03; s_rot_y = PI
				"w": sx = cx - CELL_SIZE/2.0 + parent.WALL_THICKNESS + 0.03; s_rot_y = PI/2.0
				"e": sx = cx + CELL_SIZE/2.0 - parent.WALL_THICKNESS - 0.03; s_rot_y = -PI/2.0
			var w_sign := MeshFactory.quad(Vector2(0.9, 0.4), MaterialFactory.make_unshaded(Color(1.0, 1.0, 1.0), load("res://assets/textures/poster_warning.png")))
			w_sign.position = Vector3(sx, cell_y + 1.8, sz)
			w_sign.rotation = Vector3(0.0, s_rot_y, 0.0)
			parent.nav_region.add_child(w_sign)

static func spawn_courtyard_centerpiece(parent, cx: float, cz: float, CELL_SIZE: float):
	var seg_mat := MaterialFactory.make_unshaded(Color(0.50, 0.48, 0.45), load("res://assets/textures/metal_rust.png"))
	for i in range(3):
		var seg := MeshFactory.cylinder(0.18 - i * 0.04, 0.22 - i * 0.04, 0.5, 6, seg_mat)
		seg.position = Vector3(cx, 0.5 * (i + 0.5), cz)
		parent.nav_region.add_child(seg)
	var ring_count = 6
	for i in range(ring_count):
		var angle = float(i) / ring_count * PI * 2
		var radius = 1.6
		var rx = cx + cos(angle) * radius
		var rz = cz + sin(angle) * radius
		var debris_color = Color(0.25, 0.25, 0.25)
		var debris_tex = load("res://assets/textures/metal_rust.png")
		var ds := Vector3(randf_range(0.08, 0.15), randf_range(0.04, 0.10), randf_range(0.08, 0.15))
		var debris := MeshFactory.box(ds, MaterialFactory.make_unshaded(debris_color, debris_tex))
		debris.position = Vector3(rx, ds.y * 0.5, rz)
		debris.rotation.y = randf_range(0, PI)
		parent.nav_region.add_child(debris)
