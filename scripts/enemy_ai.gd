extends CharacterBody3D

const SPEED = 2.0
const ACCELERATION = 6.0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
var player_ref: Node3D = null

# Visual
var _enemy_mat: StandardMaterial3D = null
var visual_root: Node3D = null
var visual_torso_upper: MeshInstance3D = null
var visual_head: MeshInstance3D = null
var pivot_shoulder_l: Node3D = null
var pivot_shoulder_r: Node3D = null
var pivot_elbow_l: Node3D = null
var pivot_elbow_r: Node3D = null
var pivot_hip_l: Node3D = null
var pivot_hip_r: Node3D = null
var pivot_knee_l: Node3D = null
var pivot_knee_r: Node3D = null
var pivot_ankle_l: Node3D = null
var pivot_ankle_r: Node3D = null
var eye_light_l: OmniLight3D = null
var eye_light_r: OmniLight3D = null
var anim_time: float = 0.0
var anim_speed: float = 0.0

func _ready():
	add_to_group("enemy")
	nav_agent.path_desired_distance = 2.0
	nav_agent.target_desired_distance = 2.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	player_ref = get_tree().get_first_node_in_group("player")
	if player_ref:
		nav_agent.target_position = player_ref.global_position
	_build_enemy_visuals()

func _physics_process(delta):
	if not player_ref: return
	nav_agent.target_position = player_ref.global_position

	if global_position.distance_to(player_ref.global_position) < 1.8:
		EventBus.log_debug("Enemy killed player at distance: %s" % global_position.distance_to(player_ref.global_position))
		GameStateManager.request_game_over()
		return

	_move_enemy(delta)
	_animate_visuals(delta)

func _move_enemy(delta):
	if not is_on_floor():
		velocity.y -= 9.8 * delta

	if nav_agent.is_navigation_finished():
		velocity.x = move_toward(velocity.x, 0, SPEED * delta)
		velocity.z = move_toward(velocity.z, 0, SPEED * delta)
		move_and_slide()
		return

	var dir = (nav_agent.get_next_path_position() - global_position)
	dir.y = 0
	var new_velocity = dir.normalized() * SPEED
	velocity.x = lerp(velocity.x, new_velocity.x, ACCELERATION * delta)
	velocity.z = lerp(velocity.z, new_velocity.z, ACCELERATION * delta)
	move_and_slide()

	var slide_count = get_slide_collision_count()
	if slide_count > 0:
		for i in range(slide_count):
			var col = get_slide_collision(i)
			if col and col.get_collider():
				var cname = col.get_collider().name
				var cpos = col.get_position()
				EventBus.log_debug("Enemy collided with: %s at %s" % [cname, cpos])

	var h_vel = Vector2(velocity.x, velocity.z)
	if h_vel.length() > 0.1:
		var look_target = global_position + velocity
		var target_xform = global_transform.looking_at(Vector3(look_target.x, global_position.y, look_target.z), Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(target_xform.basis, 10.0 * delta).orthonormalized()

func _build_enemy_visuals():
	_enemy_mat = StandardMaterial3D.new()
	_enemy_mat.albedo_color = Color(0.0, 0.0, 0.0)
	_enemy_mat.roughness = 1.0
	_enemy_mat.metallic = 0.0

	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	visual_root.position = Vector3(0.0, -0.95, 0.0)
	add_child(visual_root)

	var mk_box = func(w: float, h: float, d: float,
					  pos: Vector3, parent: Node3D) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, h, d)
		mi.mesh = bm
		mi.material_override = _enemy_mat
		mi.position = pos
		parent.add_child(mi)
		return mi

	var mk_pivot = func(pos: Vector3, parent: Node3D) -> Node3D:
		var n := Node3D.new()
		n.position = pos
		parent.add_child(n)
		return n

	mk_box.call(0.42, 0.22, 0.22, Vector3(0.0, 0.97, 0.0), visual_root)
	visual_torso_upper = mk_box.call(0.54, 0.40, 0.24, Vector3(0.0, 1.22, 0.0), visual_root)
	mk_box.call(0.15, 0.16, 0.15, Vector3(0.0, 1.50, 0.0), visual_root)
	visual_head = mk_box.call(0.30, 0.32, 0.28, Vector3(0.0, 1.68, 0.0), visual_root)

	pivot_shoulder_l = mk_pivot.call(Vector3(-0.355, 1.38, 0.0), visual_root)
	mk_box.call(0.17, 0.32, 0.17, Vector3(0.0, -0.16, 0.0), pivot_shoulder_l)
	pivot_elbow_l = mk_pivot.call(Vector3(0.0, -0.32, 0.0), pivot_shoulder_l)
	mk_box.call(0.14, 0.28, 0.14, Vector3(0.0, -0.14, 0.0), pivot_elbow_l)

	pivot_shoulder_r = mk_pivot.call(Vector3(0.355, 1.38, 0.0), visual_root)
	mk_box.call(0.17, 0.32, 0.17, Vector3(0.0, -0.16, 0.0), pivot_shoulder_r)
	pivot_elbow_r = mk_pivot.call(Vector3(0.0, -0.32, 0.0), pivot_shoulder_r)
	mk_box.call(0.14, 0.28, 0.14, Vector3(0.0, -0.14, 0.0), pivot_elbow_r)

	pivot_hip_l = mk_pivot.call(Vector3(-0.13, 0.80, 0.0), visual_root)
	mk_box.call(0.21, 0.36, 0.20, Vector3(0.0, -0.18, 0.0), pivot_hip_l)
	pivot_knee_l = mk_pivot.call(Vector3(0.0, -0.36, 0.0), pivot_hip_l)
	mk_box.call(0.19, 0.34, 0.18, Vector3(0.0, -0.17, 0.0), pivot_knee_l)
	pivot_ankle_l = mk_pivot.call(Vector3(0.0, -0.34, 0.0), pivot_knee_l)
	mk_box.call(0.20, 0.09, 0.28, Vector3(0.0, -0.045, 0.06), pivot_ankle_l)

	pivot_hip_r = mk_pivot.call(Vector3(0.13, 0.80, 0.0), visual_root)
	mk_box.call(0.21, 0.36, 0.20, Vector3(0.0, -0.18, 0.0), pivot_hip_r)
	pivot_knee_r = mk_pivot.call(Vector3(0.0, -0.36, 0.0), pivot_hip_r)
	mk_box.call(0.19, 0.34, 0.18, Vector3(0.0, -0.17, 0.0), pivot_knee_r)
	pivot_ankle_r = mk_pivot.call(Vector3(0.0, -0.34, 0.0), pivot_knee_r)
	mk_box.call(0.20, 0.09, 0.28, Vector3(0.0, -0.045, 0.06), pivot_ankle_r)

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.0, 0.0)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.0, 0.0)
	eye_mat.emission_energy_multiplier = 2.0

	var eye_mesh := BoxMesh.new()
	eye_mesh.size = Vector3(0.06, 0.06, 0.02)

	var eye_l := MeshInstance3D.new()
	eye_l.mesh = eye_mesh
	eye_l.material_override = eye_mat
	eye_l.position = Vector3(-0.08, 1.67, -0.14)
	visual_root.add_child(eye_l)

	var eye_r := MeshInstance3D.new()
	eye_r.mesh = eye_mesh
	eye_r.material_override = eye_mat
	eye_r.position = Vector3(0.08, 1.67, -0.14)
	visual_root.add_child(eye_r)

	eye_light_l = OmniLight3D.new()
	eye_light_l.name = "EyeLightL"
	eye_light_l.light_color = Color(1.0, 0.05, 0.05)
	eye_light_l.light_energy = 1.5
	eye_light_l.omni_range = 6.0
	eye_light_l.shadow_enabled = false
	eye_light_l.position = Vector3(-0.08, 1.67, -0.13)
	visual_root.add_child(eye_light_l)

	eye_light_r = OmniLight3D.new()
	eye_light_r.name = "EyeLightR"
	eye_light_r.light_color = Color(1.0, 0.05, 0.05)
	eye_light_r.light_energy = 1.5
	eye_light_r.omni_range = 6.0
	eye_light_r.shadow_enabled = false
	eye_light_r.position = Vector3(0.08, 1.67, -0.13)
	visual_root.add_child(eye_light_r)

	var flicker_timer := Timer.new()
	flicker_timer.wait_time = 0.12
	flicker_timer.autostart = true
	add_child(flicker_timer)
	flicker_timer.timeout.connect(func():
		var e: float = randf_range(1.8, 3.2)
		if eye_light_l: eye_light_l.light_energy = e
		if eye_light_r: eye_light_r.light_energy = e
	)

func _animate_visuals(delta: float) -> void:
	if not visual_root: return

	var h_speed: float = Vector2(velocity.x, velocity.z).length()
	anim_speed = lerp(anim_speed, h_speed, delta * 10.0)
	var move_blend: float = clamp(anim_speed / 0.4, 0.0, 1.0)

	var freq: float = 5.0
	var leg_amp: float = deg_to_rad(50.0)
	var knee_amp: float = deg_to_rad(55.0)
	var arm_amp: float = deg_to_rad(45.0)
	var elbow_amp: float = deg_to_rad(38.0)

	if move_blend > 0.01:
		anim_time += delta * freq

	var phase_l: float = anim_time
	var phase_r: float = anim_time + PI

	if pivot_hip_l and pivot_knee_l and pivot_ankle_l:
		var hip_x: float = sin(phase_l) * leg_amp * move_blend
		var knee_x: float = max(0.0, -sin(phase_l)) * knee_amp * move_blend
		var ankle_x: float = -knee_x * 0.45
		pivot_hip_l.rotation.x = lerp(pivot_hip_l.rotation.x, hip_x, delta * 18.0)
		pivot_knee_l.rotation.x = lerp(pivot_knee_l.rotation.x, knee_x, delta * 18.0)
		pivot_ankle_l.rotation.x = lerp(pivot_ankle_l.rotation.x, ankle_x, delta * 18.0)

	if pivot_hip_r and pivot_knee_r and pivot_ankle_r:
		var hip_x: float = sin(phase_r) * leg_amp * move_blend
		var knee_x: float = max(0.0, -sin(phase_r)) * knee_amp * move_blend
		var ankle_x: float = -knee_x * 0.45
		pivot_hip_r.rotation.x = lerp(pivot_hip_r.rotation.x, hip_x, delta * 18.0)
		pivot_knee_r.rotation.x = lerp(pivot_knee_r.rotation.x, knee_x, delta * 18.0)
		pivot_ankle_r.rotation.x = lerp(pivot_ankle_r.rotation.x, ankle_x, delta * 18.0)

	if pivot_shoulder_l and pivot_elbow_l:
		var sh_x: float = sin(phase_r) * arm_amp * move_blend
		var el_x: float = max(0.0, -sin(phase_r)) * elbow_amp * move_blend
		pivot_shoulder_l.rotation.x = lerp(pivot_shoulder_l.rotation.x, sh_x, delta * 14.0)
		pivot_elbow_l.rotation.x = lerp(pivot_elbow_l.rotation.x, el_x, delta * 14.0)

	if pivot_shoulder_r and pivot_elbow_r:
		var sh_x: float = sin(phase_l) * arm_amp * move_blend
		var el_x: float = max(0.0, -sin(phase_l)) * elbow_amp * move_blend
		pivot_shoulder_r.rotation.x = lerp(pivot_shoulder_r.rotation.x, sh_x, delta * 14.0)
		pivot_elbow_r.rotation.x = lerp(pivot_elbow_r.rotation.x, el_x, delta * 14.0)

	if visual_torso_upper:
		var sway_z: float = sin(anim_time) * deg_to_rad(3.5) * move_blend
		visual_torso_upper.rotation.z = lerp(visual_torso_upper.rotation.z, sway_z, delta * 10.0)

	if visual_head:
		var base_y: float = 1.68
		var bob: float = sin(anim_time * 2.0) * 0.022 * move_blend
		visual_head.position.y = lerp(visual_head.position.y, base_y + bob, delta * 12.0)
