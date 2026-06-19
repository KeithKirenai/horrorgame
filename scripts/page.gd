extends Area3D

signal page_collected

var collected = false

func _ready():
	var tex = load("res://assets/textures/page_note.png")
	var mat := MaterialFactory.make_unshaded(Color(1.0, 1.0, 1.0), tex)
	mat.emission_enabled = true
	mat.emission_texture = tex
	mat.emission = Color(1.0, 1.0, 1.0)
	mat.emission_energy_multiplier = 0.25
	var mesh_inst := MeshFactory.plane(Vector2(0.4, 0.6), mat)
	add_child(mesh_inst)
	
	# Collision
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.8 # Easier to grab
	col.shape = shape
	col.position.y = 0.25 # Lift hitbox slightly above floor
	add_child(col)
	collision_layer = 1 # Allow RayCast3D to detect it (since player raycast collide_with_areas is enabled)
	collision_mask = 1 # Layer 1 is Player (default)

func get_interaction_text() -> String:
	return "Pick Up Page"

func interact():
	collect()

func collect():
	if collected: return
	collected = true
	EventBus.log_debug("Page collected at: %s" % global_position)
	emit_signal("page_collected")
	queue_free()

