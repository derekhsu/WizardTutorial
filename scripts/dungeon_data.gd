class_name DungeonData
extends Node

## Pure-data tile model. Rendering and actors consume this; nothing here
## knows about nodes or meshes. ASCII map doubles as the level-editing format:
##   '#' wall   '.' floor   'D' door (open)   'E' exit   'P' player start   'G' guardian

enum TileType { WALL, FLOOR, DOOR, EXIT }

@export_multiline var ascii_map := ""

var tiles: Dictionary = {}  # Vector2i -> TileType
var player_start := Vector2i(1, 1)
var guardian_pos := Vector2i.ZERO
var map_size := Vector2i.ZERO

func _ready() -> void:
	_parse()

func _parse() -> void:
	var lines := ascii_map.split("\n", false)
	for y in lines.size():
		var line := lines[y]
		map_size.x = maxi(map_size.x, line.length())
		for x in line.length():
			match line[x]:
				"#":
					tiles[Vector2i(x, y)] = TileType.WALL
				".":
					tiles[Vector2i(x, y)] = TileType.FLOOR
				"D":
					tiles[Vector2i(x, y)] = TileType.DOOR
				"E":
					tiles[Vector2i(x, y)] = TileType.EXIT
				"P":
					tiles[Vector2i(x, y)] = TileType.FLOOR
					player_start = Vector2i(x, y)
				"G":
					tiles[Vector2i(x, y)] = TileType.FLOOR
					guardian_pos = Vector2i(x, y)
	map_size.y = lines.size()

func tile_at(pos: Vector2i) -> int:
	return tiles.get(pos, TileType.WALL)

func is_walkable(pos: Vector2i) -> bool:
	return tile_at(pos) != TileType.WALL

func grid_to_world(pos: Vector2i) -> Vector3:
	return Vector3(pos.x * Constants.TILE_SIZE, 0.0, pos.y * Constants.TILE_SIZE)
