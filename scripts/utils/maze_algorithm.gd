extends RefCounted
class_name MazeAlgorithm

static func init_grid(grid, width: int, depth: int):
	grid.clear()
	for x in range(width):
		var col = []
		for z in range(depth):
			col.append({
				"n": z == 0,
				"s": z == depth - 1,
				"e": x == width - 1,
				"w": x == 0
			})
		grid.append(col)

static func _recursive_division(grid, x, z, w, d):
	if w < 2 or d < 2:
		return

	var horizontal = d > w
	if w == d:
		horizontal = randi() % 2 == 0

	var width = grid.size()
	var depth = grid[0].size() if width > 0 else 0

	if horizontal:
		var split_z = randi_range(z, z + d - 2)
		for i in range(x, x + w):
			if randf() > 0.35:
				grid[i][split_z]["s"] = true
				grid[i][split_z + 1]["n"] = true
		var gap_x = randi_range(x, x + w - 1)
		grid[gap_x][split_z]["s"] = false
		grid[gap_x][split_z + 1]["n"] = false
		_recursive_division(grid, x, z, w, split_z - z + 1)
		_recursive_division(grid, x, split_z + 1, w, z + d - (split_z + 1))
	else:
		var split_x = randi_range(x, x + w - 2)
		for i in range(z, z + d):
			if randf() > 0.35:
				grid[split_x][i]["e"] = true
				grid[split_x + 1][i]["w"] = true
		var gap_z = randi_range(z, z + d - 1)
		grid[split_x][gap_z]["e"] = false
		grid[split_x + 1][gap_z]["w"] = false
		_recursive_division(grid, x, z, split_x - x + 1, d)
		_recursive_division(grid, split_x + 1, z, x + w - (split_x + 1), d)

static func generate(grid, width: int, depth: int):
	init_grid(grid, width, depth)
	_recursive_division(grid, 0, 0, width, depth)

static func apply_braiding(grid, width: int, depth: int):
	for x in range(width):
		for z in range(depth):
			var cell = grid[x][z]
			var wall_count = 0
			if cell.n: wall_count += 1
			if cell.s: wall_count += 1
			if cell.e: wall_count += 1
			if cell.w: wall_count += 1
			if wall_count >= 3 and randf() < 0.6:
				_remove_random_wall(grid, x, z, width, depth)

static func _remove_random_wall(grid, x, z, width, depth):
	var cell = grid[x][z]
	var candidates = []
	if cell.n and z > 0: candidates.append("n")
	if cell.s and z < depth - 1: candidates.append("s")
	if cell.e and x < width - 1: candidates.append("e")
	if cell.w and x > 0: candidates.append("w")
	if candidates.size() > 0:
		var pick = candidates.pick_random()
		if pick == "n":
			grid[x][z].n = false
			grid[x][z-1].s = false
		elif pick == "s":
			grid[x][z].s = false
			grid[x][z+1].n = false
		elif pick == "e":
			grid[x][z].e = false
			grid[x+1][z].w = false
		elif pick == "w":
			grid[x][z].w = false
			grid[x-1][z].e = false

static func carve_open_rooms(grid, width: int, depth: int, courtyard_centers, spawn_location: Vector2i, door_location: Vector2i, CELL_SIZE: float):
	var num_courtyards = max(1, (width * depth) / 16)
	var attempts = 0
	var carved = 0
	while carved < num_courtyards and attempts < 50:
		attempts += 1
		var rx = randi_range(0, width - 2)
		var rz = randi_range(0, depth - 2)
		if (rx == 0 and rz == 0): continue
		if (rx == width-1 or rx+1 == width-1) and (rz == depth-1 or rz+1 == depth-1): continue
		grid[rx][rz]["s"] = false
		grid[rx][rz+1]["n"] = false
		grid[rx+1][rz]["s"] = false
		grid[rx+1][rz+1]["n"] = false
		grid[rx][rz]["e"] = false
		grid[rx+1][rz]["w"] = false
		grid[rx][rz+1]["e"] = false
		grid[rx+1][rz+1]["w"] = false
		courtyard_centers.append(Vector2(
			(rx + 0.5) * CELL_SIZE + CELL_SIZE * 0.5,
			(rz + 0.5) * CELL_SIZE + CELL_SIZE * 0.5
		))
		carved += 1

static func merge_wide_corridors(grid, width: int, depth: int, skip_columns):
	for x in range(width - 1):
		for z in range(depth):
			var a = grid[x][z]
			var b = grid[x+1][z]
			if a.e and b.w:
				var a_walls = (1 if a.n else 0) + (1 if a.s else 0) + (1 if a.e else 0) + (1 if a.w else 0)
				var b_walls = (1 if b.n else 0) + (1 if b.s else 0) + (1 if b.e else 0) + (1 if b.w else 0)
				if a_walls <= 2 and b_walls <= 2 and randf() < 0.4:
					a.e = false; b.w = false
					skip_columns.append(Vector2i(x+1, z))
	for x in range(width):
		for z in range(depth - 1):
			var a = grid[x][z]
			var b = grid[x][z+1]
			if a.s and b.n:
				var a_walls = (1 if a.n else 0) + (1 if a.s else 0) + (1 if a.e else 0) + (1 if a.w else 0)
				var b_walls = (1 if b.n else 0) + (1 if b.s else 0) + (1 if b.e else 0) + (1 if b.w else 0)
				if a_walls <= 2 and b_walls <= 2 and randf() < 0.4:
					a.s = false; b.n = false
					skip_columns.append(Vector2i(x, z+1))

static func mark_dead_end_rooms(grid, width: int, depth: int, spawn_location: Vector2i, door_location: Vector2i, courtyard_centers, CELL_SIZE: float):
	for x in range(width):
		for z in range(depth):
			var cell = grid[x][z]
			var wc = (1 if cell.n else 0) + (1 if cell.s else 0) + (1 if cell.e else 0) + (1 if cell.w else 0)
			if wc >= 3:
				var pos = Vector2i(x, z)
				if pos == spawn_location or pos == door_location:
					continue
				var in_courtyard = false
				for cp in courtyard_centers:
					var ccx = (x + 0.5) * CELL_SIZE; var ccz = (z + 0.5) * CELL_SIZE
					if Vector2(ccx, ccz).distance_to(cp) < CELL_SIZE * 1.5:
						in_courtyard = true; break
				if in_courtyard: continue
				cell["dead_end_extra"] = true

static func merge_rooms(grid, width: int, depth: int, courtyard_centers, skip_columns, CELL_SIZE: float):
	var possible_blocks = []
	for x in range(width - 1):
		for z in range(depth - 1):
			var skip = false
			for dx in range(2):
				for dz in range(2):
					var cell = grid[x+dx][z+dz]
					for pos in courtyard_centers:
						var ccx = ((x+dx) + 0.5) * CELL_SIZE
						var ccz = ((z+dz) + 0.5) * CELL_SIZE
						if Vector2(ccx, ccz).distance_to(pos) < CELL_SIZE * 1.5:
							skip = true
			if not skip:
				possible_blocks.append(Vector2i(x, z))
	possible_blocks.shuffle()
	var num_rooms = mini(possible_blocks.size(), 2 + (randi() % 2))
	for i in range(num_rooms):
		if i >= possible_blocks.size(): break
		var blk = possible_blocks[i]
		var bx = blk.x; var bz = blk.y
		grid[bx][bz].e = false; grid[bx+1][bz].w = false
		grid[bx][bz+1].e = false; grid[bx+1][bz+1].w = false
		grid[bx][bz].s = false; grid[bx][bz+1].n = false
		grid[bx+1][bz].s = false; grid[bx+1][bz+1].n = false
		skip_columns.append(Vector2i(bx+1, bz+1))

static func post_process(grid, width: int, depth: int, spawn_location: Vector2i, door_location: Vector2i, courtyard_centers, skip_columns, CELL_SIZE: float):
	apply_braiding(grid, width, depth)
	carve_open_rooms(grid, width, depth, courtyard_centers, spawn_location, door_location, CELL_SIZE)
	merge_wide_corridors(grid, width, depth, skip_columns)
	merge_rooms(grid, width, depth, courtyard_centers, skip_columns, CELL_SIZE)
	mark_dead_end_rooms(grid, width, depth, spawn_location, door_location, courtyard_centers, CELL_SIZE)
