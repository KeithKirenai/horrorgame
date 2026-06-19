extends Node
class_name MaterialFactory

static func make_unshaded(albedo: Color, texture: Texture2D = null, uv_scale: Vector3 = Vector3(1, 1, 1)) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = albedo
	if texture:
		mat.albedo_texture = texture
	if albedo.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if uv_scale != Vector3(1, 1, 1):
		mat.uv1_scale = uv_scale
	return mat
