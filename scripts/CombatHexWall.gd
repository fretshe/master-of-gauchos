extends Node3D

class_name CombatHexWall

@export var default_thickness: float = 0.05
@export var default_color: Color = Color(0.24, 0.88, 1.0, 0.94)
@export var default_roughness: float = 0.18
@export var default_emission_energy: float = 0.45

var _mesh_instance: MeshInstance3D = null


func _ready() -> void:
	_ensure_mesh_instance()


func configure_from_side(side_geometry: Dictionary, wall_height: float, wall_thickness: float = default_thickness) -> void:
	if side_geometry.is_empty():
		return

	_ensure_mesh_instance()
	var side_transform: Transform3D = side_geometry.get("transform", Transform3D.IDENTITY)
	var length: float = float(side_geometry.get("length", 0.0))
	if length <= 0.0001:
		return

	global_transform = side_transform

	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, wall_height, wall_thickness)
	_mesh_instance.mesh = mesh
	# The edge transform sits exactly on the hex side plane and exposes +Z outward.
	# Offset the box inward so its outer face matches the hex wall angle precisely.
	_mesh_instance.position = Vector3(0.0, wall_height * 0.5, -wall_thickness * 0.5)
	_mesh_instance.material_override = _build_material()


func _ensure_mesh_instance() -> void:
	if _mesh_instance != null and is_instance_valid(_mesh_instance):
		return

	if has_node("Mesh"):
		_mesh_instance = get_node("Mesh") as MeshInstance3D
	else:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "Mesh"
		add_child(_mesh_instance)

	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _build_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = default_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.roughness = default_roughness
	material.emission_enabled = true
	material.emission = default_color
	material.emission_energy_multiplier = default_emission_energy
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
