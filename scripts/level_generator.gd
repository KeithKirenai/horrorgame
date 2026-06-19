extends Node3D

signal level_generated

var texture_style: String = "ai_ps1"

var MAZE_WIDTH = 8
var MAZE_DEPTH = 8
const CELL_SIZE = 5.0
const WALL_HEIGHT = 4.0
const WALL_THICKNESS = 0.2

var grid = []

var PageScript = preload("res://scripts/page.gd")
var DoorScript = preload("res://scripts/exit_door.gd")
var GeneratorScript = preload("res://scripts/generator.gd")

var page_locations = []
var door_location = Vector2i.ZERO
var spawn_location: Vector2i = Vector2i.ZERO
var _courtyard_centers = []
var _skip_columns = []
var _generating = false

var nav_region: NavigationRegion3D
var _wall_mat_ref: StandardMaterial3D
var _floor_mat: StandardMaterial3D
var _ceil_mat: StandardMaterial3D
var _accent_mat: StandardMaterial3D

func reload_textures():
	ThemeManager.reload_textures(texture_style, _floor_mat, _ceil_mat, _wall_mat_ref, _accent_mat)

func cleanup_level():
	_generating = false
	for child in get_children():
		remove_child(child)
		child.queue_free()
	page_locations.clear()
	door_location = Vector2i.ZERO
	spawn_location = Vector2i.ZERO
	_courtyard_centers.clear()
	_skip_columns.clear()

func generate_level():
	if _generating:
		EventBus.log_debug("WARNING: generate_level called while already generating, skipping")
		return
	_generating = true
	EventBus.log_debug("=== LEVEL GENERATION STARTED ===")
	EventBus.log_debug("Theme: INDUSTRIAL, Size: %dx%d" % [MAZE_WIDTH, MAZE_DEPTH])
	var corners = [
		Vector2i(0, 0),
		Vector2i(MAZE_WIDTH - 1, 0),
		Vector2i(0, MAZE_DEPTH - 1),
		Vector2i(MAZE_WIDTH - 1, MAZE_DEPTH - 1)
	]
	spawn_location = corners.pick_random()
	EventBus.log_debug("Spawn location: %s" % spawn_location)

	var exit_candidates = []
	for x in range(MAZE_WIDTH):
		for z in range(MAZE_DEPTH):
			if (x == 0 or x == MAZE_WIDTH - 1 or z == 0 or z == MAZE_DEPTH - 1):
				if not (x == 0 and z == 0) and not (x == MAZE_WIDTH - 1 and z == 0) and not (x == 0 and z == MAZE_DEPTH - 1) and not (x == MAZE_WIDTH - 1 and z == MAZE_DEPTH - 1):
					var dx = abs(x - spawn_location.x)
					var dz = abs(z - spawn_location.y)
					var dist = dx + dz
					var min_dist = 10 if (MAZE_WIDTH >= 12) else int((MAZE_WIDTH + MAZE_DEPTH) / 2.0)
					if dist >= min_dist:
						exit_candidates.append(Vector2i(x, z))

	if exit_candidates.is_empty():
		door_location = Vector2i(MAZE_WIDTH - 1 - spawn_location.x, MAZE_DEPTH - 1 - spawn_location.y)
	else:
		door_location = exit_candidates.pick_random()
	EventBus.log_debug("Exit location: %s" % door_location)

	MazeAlgorithm.generate(grid, MAZE_WIDTH, MAZE_DEPTH)
	EventBus.log_debug("Maze generated: %dx%d cells" % [MAZE_WIDTH, MAZE_DEPTH])

	nav_region = NavigationRegion3D.new()
	nav_region.name = "NavigationRegion3D"
	var nav_mesh = NavigationMesh.new()
	nav_mesh.agent_radius = 0.5
	nav_mesh.cell_height = 0.25
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_region.navigation_mesh = nav_mesh
	add_child(nav_region)

	MazeAlgorithm.post_process(grid, MAZE_WIDTH, MAZE_DEPTH, spawn_location, door_location, _courtyard_centers, _skip_columns, CELL_SIZE)
	_build_geometry()

	nav_region.bake_finished.connect(spawn_game_objects)
	nav_region.bake_navigation_mesh()

func get_start_position() -> Vector3:
	return Vector3(
		spawn_location.x * CELL_SIZE + CELL_SIZE / 2.0,
		1.5,
		spawn_location.y * CELL_SIZE + CELL_SIZE / 2.0
	)

func get_start_rotation() -> float:
	var cell = grid[spawn_location.x][spawn_location.y]
	if not cell.has("s") or not cell.s:
		return PI
	if not cell.has("n") or not cell.n:
		return 0.0
	if not cell.has("e") or not cell.e:
		return -PI / 2.0
	if not cell.has("w") or not cell.w:
		return PI / 2.0
	return 0.0

func get_enemy_start_position() -> Vector3:
	var enemy_cell = Vector2i(MAZE_WIDTH - 1 - spawn_location.x, MAZE_DEPTH - 1 - spawn_location.y)
	return Vector3(
		enemy_cell.x * CELL_SIZE + CELL_SIZE / 2.0,
		1.5,
		enemy_cell.y * CELL_SIZE + CELL_SIZE / 2.0
	)

func spawn_game_objects():
	EventBus.log_debug("Spawning game objects...")
	page_locations.clear()

	var door = DoorScript.new()
	door.name = "ExitDoor"
	var px = door_location.x * CELL_SIZE + CELL_SIZE / 2.0
	var pz = door_location.y * CELL_SIZE + CELL_SIZE / 2.0
	var inward_dir = Vector3.LEFT

	if door_location.x == MAZE_WIDTH - 1:
		px = door_location.x * CELL_SIZE + CELL_SIZE
		inward_dir = Vector3.LEFT
	elif door_location.x == 0:
		px = 0.0
		inward_dir = Vector3.RIGHT
	elif door_location.y == MAZE_DEPTH - 1:
		pz = door_location.y * CELL_SIZE + CELL_SIZE
		inward_dir = Vector3.FORWARD
	elif door_location.y == 0:
		pz = 0.0
		inward_dir = Vector3.BACK

	door.position = Vector3(px, 0.0, pz)
	add_child(door)
	EventBus.log_debug("Exit door spawned at cell: %s, world: %s" % [door_location, door.position])
	door.look_at(door.position + inward_dir, Vector3.UP)

	var possible_spots = []
	for x in range(MAZE_WIDTH):
		for z in range(MAZE_DEPTH):
			if Vector2i(x, z) == spawn_location or Vector2i(x, z) == door_location:
				continue
			possible_spots.append(Vector2i(x, z))

	possible_spots.shuffle()

	for i in range(5):
		if possible_spots.is_empty(): break
		var loc = possible_spots.pop_back()
		page_locations.append(loc)
		var spawn_on_wall = randf() < 0.5
		var wall_candidates = []
		var cell = grid[loc.x][loc.y]
		if cell.n: wall_candidates.append("n")
		if cell.s: wall_candidates.append("s")
		if cell.w: wall_candidates.append("w")
		if cell.e: wall_candidates.append("e")

		var page = Area3D.new()
		page.set_script(PageScript)
		page.add_to_group("pages")

		if spawn_on_wall and not wall_candidates.is_empty():
			var wall_side = wall_candidates.pick_random()
			var cx = loc.x * CELL_SIZE + CELL_SIZE / 2.0
			var cz = loc.y * CELL_SIZE + CELL_SIZE / 2.0
			var py = randf_range(1.3, 1.7)

			var page_x = cx
			var page_z = cz
			var rot_y = 0.0

			match wall_side:
				"n":
					page_z = cz - CELL_SIZE / 2.0 + WALL_THICKNESS + 0.02
					rot_y = 0.0
				"s":
					page_z = cz + CELL_SIZE / 2.0 - WALL_THICKNESS - 0.02
					rot_y = PI
				"w":
					page_x = cx - CELL_SIZE / 2.0 + WALL_THICKNESS + 0.02
					rot_y = PI / 2.0
				"e":
					page_x = cx + CELL_SIZE / 2.0 - WALL_THICKNESS - 0.02
					rot_y = -PI / 2.0

			page.position = Vector3(page_x, py, page_z)
			page.rotation = Vector3(PI / 2.0, rot_y, 0.0)
		else:
			page.position = Vector3(
				loc.x * CELL_SIZE + CELL_SIZE / 2.0,
				0.02,
				loc.y * CELL_SIZE + CELL_SIZE / 2.0
			)
			page.rotation = Vector3(0.0, randf_range(0.0, PI * 2.0), 0.0)

		add_child(page)
		EventBus.log_debug("Page %d spawned at cell: %s, world: %s" % [i, loc, page.position])
		SetPieceSpawner.spawn_page_shrine(self,
				loc.x * CELL_SIZE + CELL_SIZE / 2.0,
				loc.y * CELL_SIZE + CELL_SIZE / 2.0,
				CELL_SIZE
			)

		var chain_height := randf_range(1.5, 2.5)
		var chain := MeshFactory.cylinder(0.015, 0.015, chain_height, 4, MaterialFactory.make_unshaded(Color(0.6, 0.6, 0.6), load("res://assets/textures/metal_rust.png")))
		var offset = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		chain.position = Vector3(
			loc.x * CELL_SIZE + CELL_SIZE / 2.0 + offset.x,
			WALL_HEIGHT - chain_height / 2.0,
			loc.y * CELL_SIZE + CELL_SIZE / 2.0 + offset.z
		)
		add_child(chain)

	for i in range(3):
		if possible_spots.is_empty(): break
		var loc = possible_spots.pop_back()
		var gen = GeneratorScript.new()
		gen.name = "Generator_%d" % i
		var gen_cx = loc.x * CELL_SIZE + CELL_SIZE / 2.0
		var gen_cz = loc.y * CELL_SIZE + CELL_SIZE / 2.0
		gen.position = Vector3(gen_cx, 0.0, gen_cz)
		add_child(gen)
		SetPieceSpawner.spawn_generator_room_marker(self, gen_cx, gen_cz, i, CELL_SIZE)

	_generating = false
	level_generated.emit()

func _build_geometry():
	var theme_tex = ThemeManager.get_theme_textures(texture_style)
	var wall_tex_path  = theme_tex.get("wall",    "res://assets/textures/wall_concrete.png")
	var floor_tex_path = theme_tex.get("floor",   "res://assets/textures/floor_concrete.png")
	var ceil_tex_path  = theme_tex.get("ceiling", "res://assets/textures/ceiling_concrete.png")

	var floor_tex = load(floor_tex_path) if FileAccess.file_exists(floor_tex_path) else load("res://assets/textures/floor_concrete.png")
	var wall_tex  = load(wall_tex_path)  if FileAccess.file_exists(wall_tex_path)  else load("res://assets/textures/wall_concrete.png")
	var ceil_tex  = (load(ceil_tex_path) if (ceil_tex_path != "" and FileAccess.file_exists(ceil_tex_path)) else load("res://assets/textures/ceiling_concrete.png")) if ceil_tex_path != "" else null

	var wall_tint  = Color(0.75, 0.75, 0.70)
	var floor_tint = Color(0.55, 0.55, 0.55)
	var ceil_tint  = Color(0.45, 0.45, 0.45)

	var total_w = MAZE_WIDTH * CELL_SIZE
	var total_d = MAZE_DEPTH * CELL_SIZE

	_floor_mat = MaterialFactory.make_unshaded(floor_tint, floor_tex)
	var floor_mat: StandardMaterial3D = _floor_mat

	var ceil_tex_final = ceil_tex if ceil_tex else load("res://assets/textures/ceiling_concrete.png")
	_ceil_mat = MaterialFactory.make_unshaded(ceil_tint, ceil_tex_final, Vector3(MAZE_WIDTH, MAZE_DEPTH, 1))
	var ceil_mat: StandardMaterial3D = _ceil_mat

	_wall_mat_ref = MaterialFactory.make_unshaded(wall_tint, wall_tex, Vector3(2.0, 2.0, 1.0))
	var wall_mat: StandardMaterial3D = _wall_mat_ref

	var floor_node := MeshFactory.plane(Vector2(total_w, total_d), floor_mat)
	floor_node.position = Vector3(total_w / 2.0, -0.05, total_d / 2.0)
	CollisionHelper.add_box_collision(floor_node, Vector3(total_w, 0.1, total_d))
	nav_region.add_child(floor_node)

	var ceil_node := MeshFactory.plane(Vector2(total_w, total_d), ceil_mat)
	ceil_node.position = Vector3(total_w / 2.0, WALL_HEIGHT, total_d / 2.0)
	ceil_node.rotation.x = PI
	nav_region.add_child(ceil_node)

	var accent_tex_path = theme_tex.get("wall_accent", wall_tex_path)
	var accent_tex = load(accent_tex_path) if FileAccess.file_exists(accent_tex_path) else wall_tex
	_accent_mat = MaterialFactory.make_unshaded(wall_tint, accent_tex, Vector3(2.0, 2.0, 1.0))
	var accent_mat: StandardMaterial3D = _accent_mat

	for x in range(MAZE_WIDTH):
		for z in range(MAZE_DEPTH):
			var cell = grid[x][z]
			var cx = x * CELL_SIZE + CELL_SIZE / 2.0
			var cz = z * CELL_SIZE + CELL_SIZE / 2.0

			var wall_count = 0
			if cell.n: wall_count += 1
			if cell.s: wall_count += 1
			if cell.e: wall_count += 1
			if cell.w: wall_count += 1
			var chosen_wall_mat = accent_mat if wall_count <= 1 else wall_mat

			if z == 0 and cell.n:
				_spawn_wall(cx, cz - CELL_SIZE/2.0, true, chosen_wall_mat)
			if x == 0 and cell.w:
				_spawn_wall(cx - CELL_SIZE/2.0, cz, false, chosen_wall_mat)
			if cell.s:
				_spawn_wall(cx, cz + CELL_SIZE/2.0, true, chosen_wall_mat)
			if cell.e:
				if not (x == MAZE_WIDTH - 1 and z == MAZE_DEPTH - 1):
					_spawn_wall(cx + CELL_SIZE/2.0, cz, false, chosen_wall_mat)



			var quadrant = int(float(x * 2) / MAZE_WIDTH) + int(float(z * 2) / MAZE_DEPTH) * 2
			var zone_colors = [
				Color(0.95, 0.90, 0.85),
				Color(0.85, 0.88, 0.95),
				Color(0.90, 0.95, 0.88),
				Color(0.90, 0.85, 0.90)
			]
			var zc = zone_colors[quadrant % zone_colors.size()]
			var zone_quad := MeshFactory.quad(Vector2(CELL_SIZE * 0.3, CELL_SIZE * 0.3), MaterialFactory.make_unshaded(Color(zc.r, zc.g, zc.b, 0.03)))
			zone_quad.rotation.x = -PI * 0.5
			zone_quad.position = Vector3(cx, 0.003, cz)
			nav_region.add_child(zone_quad)

			if randf() < 0.025:
				SetPieceSpawner.spawn_steam_vent(self, cx, cz, grid, CELL_SIZE)
			if randf() < 0.25:
				var lantern_root = Node3D.new()
				var pole := MeshFactory.cylinder(0.03, 0.04, 0.6, 5, MaterialFactory.make_unshaded(Color(0.15, 0.15, 0.15)))
				pole.position.y = 0.3; lantern_root.add_child(pole)
				var lantern := MeshFactory.sphere(0.08, 0.12, 4, 3, MaterialFactory.make_unshaded(Color(0.95, 0.80, 0.30)))
				lantern.position.y = 0.65; lantern_root.add_child(lantern)
				var glow := OmniLight3D.new()
				glow.light_color = Color(0.95, 0.80, 0.30)
				glow.light_energy = 0.6; glow.omni_range = 3.0; glow.shadow_enabled = false
				glow.position.y = 0.65; lantern_root.add_child(glow)
				lantern_root.position = Vector3(cx + randf_range(-1.5, 1.5), 0.0, cz + randf_range(-1.5, 1.5))
				nav_region.add_child(lantern_root)

			var wall_count_intersection = 0
			if cell.n: wall_count_intersection += 1
			if cell.s: wall_count_intersection += 1
			if cell.e: wall_count_intersection += 1
			if cell.w: wall_count_intersection += 1
			if wall_count_intersection <= 1 or randf() < 0.15:
				var lamp_root = Node3D.new()
				var lamp_mat := MaterialFactory.make_unshaded(Color(0.12, 0.12, 0.12))
				var socket := MeshFactory.cylinder(0.04, 0.06, 0.08, 5, lamp_mat)
				socket.position.y = -0.04; lamp_root.add_child(socket)
				var chord_len := randf_range(0.3, 1.2)
				var shade := MeshFactory.cylinder(0.08, 0.12, 0.12, 6, lamp_mat)
				shade.position.y = -chord_len - 0.06; lamp_root.add_child(shade)
				var bulb_light := OmniLight3D.new()
				bulb_light.light_color = Color(0.95, 0.88, 0.70)
				bulb_light.light_energy = 1.0; bulb_light.omni_range = 4.0; bulb_light.shadow_enabled = false
				bulb_light.position.y = -chord_len - 0.12; lamp_root.add_child(bulb_light)
				lamp_root.position = Vector3(cx, WALL_HEIGHT, cz)
				lamp_root.rotation.y = randf_range(-0.1, 0.1)
				bulb_light.light_energy = 0.2
				nav_region.add_child(lamp_root)

	for center in _courtyard_centers:
		SetPieceSpawner.spawn_courtyard_centerpiece(self, center.x, center.y, CELL_SIZE)

	for cx_i in range(MAZE_WIDTH + 1):
		for cz_i in range(MAZE_DEPTH + 1):
			var sv = Vector2i(cx_i, cz_i)
			if sv in _skip_columns:
				continue
			var px = cx_i * CELL_SIZE
			var pz = cz_i * CELL_SIZE
			var pillar := MeshFactory.box(Vector3(0.2, WALL_HEIGHT, 0.2), wall_mat)
			pillar.position = Vector3(px, WALL_HEIGHT / 2.0, pz)
			nav_region.add_child(pillar)

			if randf() < 0.1:
				var poster_tex_path = ThemeManager.tex_path("poster_warning", texture_style)
				var poster_tex := load(poster_tex_path) if FileAccess.file_exists(poster_tex_path) else null
				if poster_tex:
					var poster := MeshFactory.quad(Vector2(0.2, 0.3), MaterialFactory.make_unshaded(Color(0.9, 0.7, 0.2), poster_tex))
					var side = randi() % 4
					var ppos = Vector3(px, randf_range(1.0, 2.5), pz)
					match side:
						0: poster.position = ppos + Vector3(-0.11, 0, 0); poster.rotation.y = 0
						1: poster.position = ppos + Vector3(0.11, 0, 0); poster.rotation.y = PI
						2: poster.position = ppos + Vector3(0, 0, -0.11); poster.rotation.y = PI / 2
						3: poster.position = ppos + Vector3(0, 0, 0.11); poster.rotation.y = -PI / 2
					nav_region.add_child(poster)

func _spawn_wall(bx: float, bz: float, horizontal: bool, mat: StandardMaterial3D):
	var wall_size = Vector3(CELL_SIZE + 0.05, WALL_HEIGHT, WALL_THICKNESS) if horizontal else Vector3(WALL_THICKNESS, WALL_HEIGHT, CELL_SIZE + 0.05)
	var wall := MeshFactory.box(wall_size, mat)
	wall.position = Vector3(bx, WALL_HEIGHT / 2.0, bz)
	CollisionHelper.add_box_collision(wall, wall_size)
	nav_region.add_child(wall)
