extends Node
class_name MeshFactory

static func box(size: Vector3, material: Material = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	if material:
		m.material_override = material
	return m

static func cylinder(top_radius: float, bottom_radius: float, height: float,
		radial_segments: int = 8, material: Material = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_radius
	cm.bottom_radius = bottom_radius
	cm.height = height
	cm.radial_segments = radial_segments
	m.mesh = cm
	if material:
		m.material_override = material
	return m

static func quad(size: Vector2, material: Material = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	m.mesh = qm
	if material:
		m.material_override = material
	return m

static func plane(size: Vector2, material: Material = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	m.mesh = pm
	if material:
		m.material_override = material
	return m

static func sphere(radius: float, height: float = -1.0,
		radial_segments: int = 6, rings: int = 4, material: Material = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = height if height > 0 else radius * 2.0
	sm.radial_segments = radial_segments
	sm.rings = rings
	m.mesh = sm
	if material:
		m.material_override = material
	return m
