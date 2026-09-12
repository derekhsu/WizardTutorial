class_name DungeonBuilder
extends Node3D

## Builds primitive-mesh geometry from DungeonData. Placeholder art by design:
## flat-colored boxes keep tile boundaries readable for the PoC.

@onready var data: DungeonData = get_parent().get_node("DungeonData")
var _mats: Dictionary = {}

func _ready() -> void:
	_make_materials()
	_build()
func _make_materials() -> void:
	_mats["wall"] = _mat(Color(0.30, 0.28, 0.34))
	_mats["floor_a"] = _mat(Color(0.15, 0.14, 0.17))
	_mats["floor_b"] = _mat(Color(0.18, 0.17, 0.20))
	_mats["ceil"] = _mat(Color(0.09, 0.09, 0.11))
	_mats["door"] = _mat(Color(0.45, 0.30, 0.15))
	_mats["exit"] = _mat(Color(0.10, 0.85, 0.45), Color(0.10, 0.85, 0.45), 1.5)

func _mat(albedo: Color, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m

func _build() -> void:
	var s := Constants.TILE_SIZE
	var h := Constants.WALL_HEIGHT
	for pos: Vector2i in data.tiles:
		var t: int = data.tiles[pos]
		var center := data.grid_to_world(pos)
		match t:
			DungeonData.TileType.WALL:
				_add_box(center + Vector3(0, h * 0.5, 0), Vector3(s, h, s), _mats["wall"])
			DungeonData.TileType.FLOOR, DungeonData.TileType.DOOR, DungeonData.TileType.EXIT:
				var key := "floor_a" if (pos.x + pos.y) % 2 == 0 else "floor_b"
				_add_box(center + Vector3(0, -0.05, 0), Vector3(s, 0.1, s), _mats[key])
				_add_box(center + Vector3(0, h + 0.05, 0), Vector3(s, 0.1, s), _mats["ceil"])
				if t == DungeonData.TileType.DOOR:
					_add_box(center + Vector3(0, h - 0.3, 0), Vector3(s, 0.6, s), _mats["door"])
				elif t == DungeonData.TileType.EXIT:
					_add_box(center + Vector3(0, 0.06, 0), Vector3(s * 0.6, 0.12, s * 0.6), _mats["exit"])

func _add_box(center: Vector3, size: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = center
	inst.material_override = mat
	add_child(inst)
