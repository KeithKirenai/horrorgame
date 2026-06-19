extends Node
class_name ThemeManager

static func tex_path(name: String, style: String = "ai_ps1") -> String:
	match style:
		"ai_raw":
			return "res://assets/textures/raw/" + name + ".png"
		"procedural":
			return "res://assets/textures/" + name + "_proc.png"
		_:
			return "res://assets/textures/" + name + ".png"

static func get_theme_textures(style: String) -> Dictionary:
	var t = {}
	var tp = func(name): return tex_path(name, style)
	t.wall        = tp.call("wall_concrete_dark")
	t.wall_accent = tp.call("wall_pipes")
	t.floor       = tp.call("floor_grate")
	t.ceiling     = tp.call("ceiling_panel")
	t.prop        = tp.call("crate_wood")
	t.normal_wall = tp.call("wall_concrete_dark_normal")
	t.height_wall = tp.call("wall_concrete_dark_height")
	for key in t.keys():
		if t[key] != "" and not FileAccess.file_exists(t[key]):
			t[key] = "res://assets/textures/wall_concrete.png"
	return t

static func _set_mat_texture(mat, tex):
	if mat is ShaderMaterial:
		mat.set_shader_parameter("texture_albedo", tex)
	else:
		mat.albedo_texture = tex

static func reload_textures(style: String, floor_mat, ceil_mat, wall_mat_ref, accent_mat):
	var theme_tex = get_theme_textures(style)
	var wall_tex_path  = theme_tex.get("wall",    "res://assets/textures/wall_concrete.png")
	var floor_tex_path = theme_tex.get("floor",   "res://assets/textures/floor_concrete.png")
	var ceil_tex_path  = theme_tex.get("ceiling", "res://assets/textures/ceiling_concrete.png")

	var floor_tex = load(floor_tex_path) if FileAccess.file_exists(floor_tex_path) else load("res://assets/textures/floor_concrete.png")
	var wall_tex  = load(wall_tex_path)  if FileAccess.file_exists(wall_tex_path)  else load("res://assets/textures/wall_concrete.png")
	var ceil_tex  = (load(ceil_tex_path) if (ceil_tex_path != "" and FileAccess.file_exists(ceil_tex_path)) else load("res://assets/textures/ceiling_concrete.png")) if ceil_tex_path != "" else null

	if floor_mat: _set_mat_texture(floor_mat, floor_tex)
	if ceil_mat: _set_mat_texture(ceil_mat, ceil_tex if ceil_tex else load("res://assets/textures/ceiling_concrete.png"))
	if wall_mat_ref: _set_mat_texture(wall_mat_ref, wall_tex)
	if accent_mat:
		var accent_tex_path = theme_tex.get("wall_accent", wall_tex_path)
		var accent_tex = load(accent_tex_path) if FileAccess.file_exists(accent_tex_path) else wall_tex
		_set_mat_texture(accent_mat, accent_tex)
