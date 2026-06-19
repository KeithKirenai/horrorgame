extends StaticBody3D

var is_open = false

func _ready():
	# Create a "Prison Cell" Door Appearance that fills a 5.0 unit gap
	
	var frame_mat = StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.2, 0.2, 0.2) # Dark Grey Metal
	frame_mat.metallic = 0.8
	frame_mat.roughness = 0.4
	
	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.3, 0.25, 0.2) # Match maze wall color
	
	# --- FILLER WALLS (To fit 5.0 width) ---
	# Door aperture will be 2.4 wide.
	# 5.0 total width. 2.6 remaining / 2 = 1.3 each side.
	
	# Left Filler
	_add_mesh(BoxMesh.new(), Vector3(1.3, 4.0, 0.4), Vector3(-1.85, 2.0, 0), wall_mat)
	# Right Filler
	_add_mesh(BoxMesh.new(), Vector3(1.3, 4.0, 0.4), Vector3(1.85, 2.0, 0), wall_mat)
	# Top Filler (Lintel)
	# Spans the center 2.4 gap, above door height (say 3.5)
	_add_mesh(BoxMesh.new(), Vector3(2.4, 0.5, 0.4), Vector3(0, 3.75, 0), wall_mat)

	# --- THE DOOR FRAME ---
	# Left Post
	_add_mesh(BoxMesh.new(), Vector3(0.2, 3.5, 0.2), Vector3(-1.1, 1.75, 0), frame_mat)
	# Right Post
	_add_mesh(BoxMesh.new(), Vector3(0.2, 3.5, 0.2), Vector3(1.1, 1.75, 0), frame_mat)
	# Top Bar
	_add_mesh(BoxMesh.new(), Vector3(2.4, 0.2, 0.2), Vector3(0, 3.4, 0), frame_mat)
	# Bottom Bar
	_add_mesh(BoxMesh.new(), Vector3(2.4, 0.2, 0.2), Vector3(0, 0.1, 0), frame_mat)
	
	# --- MOVING PARTS (Pivot Node) ---
	# We parent bars to a node so we can rotate the whole "door"
	var door_pivot = Node3D.new()
	door_pivot.name = "DoorPivot"
	door_pivot.position = Vector3(-1.1, 0, 0) # Hinge on left post
	add_child(door_pivot)
	
	# Door Content (Offset relative to pivot)
	# Center of door is at x=1.1 (relative to pivot)
	
	# Middle Horizontal Bar
	_add_mesh_to(door_pivot, BoxMesh.new(), Vector3(2.2, 0.1, 0.1), Vector3(1.1, 2.0, 0), frame_mat)
	
	# Lower Panel
	var panel_mat = StandardMaterial3D.new()
	panel_mat.albedo_color = Color(0.15, 0.15, 0.15)
	_add_mesh_to(door_pivot, BoxMesh.new(), Vector3(2.2, 1.8, 0.05), Vector3(1.1, 1.0, 0), panel_mat)
	
	# Upper Bars
	for i in range(4):
		var offset = 0.35 + (i * 0.5) # Spaced out
		_add_mesh_to(door_pivot, CylinderMesh.new(), Vector3(0.05, 1.3, 0.05), Vector3(offset, 2.7, 0), frame_mat)
		
	# --- VIEW OUTSIDE ---
	var view_mesh = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(3.0, 4.0)
	view_mesh.mesh = quad
	
	var view_mat = StandardMaterial3D.new()
	view_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	view_mat.albedo_color = Color(0.05, 0.05, 0.2)
	
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.0, 0.05, 0.1))
	gradient.set_color(1, Color(0.0, 0.0, 0.05))
	
	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = gradient
	grad_tex.fill_from = Vector2(0.5, 1.0)
	grad_tex.fill_to = Vector2(0.5, 0.0)
	view_mat.albedo_texture = grad_tex
	
	view_mesh.material_override = view_mat
	view_mesh.position = Vector3(0, 2.0, -0.5) # Centered vertically
	view_mesh.rotation.y = 0.0 # Fix: Face -Z (forward for door)
	add_child(view_mesh)
	
	# Collision
	var col = CollisionShape3D.new()
	col.name = "DoorCollision"
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.4, 3.5, 0.2)
	col.shape = shape
	col.position = Vector3(0, 1.75, 0)
	add_child(col)
	
	# Side Wall Collisions
	var col_l = CollisionShape3D.new()
	var shape_l = BoxShape3D.new()
	shape_l.size = Vector3(1.3, 4.0, 0.4)
	col_l.shape = shape_l
	col_l.position = Vector3(-1.85, 2.0, 0)
	add_child(col_l)
	
	var col_r = CollisionShape3D.new()
	var shape_r = BoxShape3D.new()
	shape_r.size = Vector3(1.3, 4.0, 0.4)
	col_r.shape = shape_r
	col_r.position = Vector3(1.85, 2.0, 0)
	add_child(col_r)
	
	# --- AUTO OPEN AREA ---
	var area = Area3D.new()
	var area_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(3.0, 2.0, 2.0) # Detect in front of door
	area_shape.shape = box
	area_shape.position = Vector3(0, 1.0, 1.0) # In front
	area.add_child(area_shape)
	area.body_entered.connect(_on_body_entered)
	add_child(area)
	
	collision_layer = 3

func _on_body_entered(body):
	if body.is_in_group("player"):
		EventBus.log_debug("Player entered exit door trigger zone at: %s" % global_position)
		interact()

func _add_mesh(mesh_res, size, pos, mat):
	_add_mesh_to(self, mesh_res, size, pos, mat)

func _add_mesh_to(parent, mesh_res, size, pos, mat):
	var mi = MeshInstance3D.new()
	if mesh_res is BoxMesh: mesh_res.size = size
	elif mesh_res is CylinderMesh:
		mesh_res.top_radius = size.x
		mesh_res.bottom_radius = size.x
		mesh_res.height = size.y
		
	mi.mesh = mesh_res
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

func unlock():
	is_open = true
	
	var col = get_node_or_null("DoorCollision")
	if col:
		col.set_deferred("disabled", true)
		
	var pivot = get_node("DoorPivot")
	var tween = create_tween()
	# Rotate open (outwards or inwards? -90 is outwards into void, 90 is inwards)
	tween.tween_property(pivot, "rotation:y", deg_to_rad(100), 2.0).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func get_interaction_text() -> String:
	return "Escape" if is_open else "Open Exit Door"

func interact():
	if is_open:
		print("YOU ESCAPED!")
		GameStateManager.request_win_game()
	else:
		var pages_left = GameStateManager.TOTAL_PAGES - GameStateManager.pages_collected
		var gens_left = GameStateManager.TOTAL_GENERATORS - GameStateManager.generators_activated
		if pages_left > 0 and gens_left > 0:
			EventBus.request_notification("LOCKED: NEED %d PAGES AND %d GENERATORS" % [pages_left, gens_left])
		elif pages_left > 0:
			EventBus.request_notification("LOCKED: NEED %d MORE PAGES" % pages_left)
		elif gens_left > 0:
			EventBus.request_notification("LOCKED: RESTORE POWER (%d GENERATORS LEFT)" % gens_left)
		else:
			EventBus.request_notification("LOCKED: RESTART GENERATORS & PAGES")

