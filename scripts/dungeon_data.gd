class_name DungeonData
extends Node

## Pure-data tile model. Rendering and actors consume this; nothing here
## knows about nodes or meshes. ASCII map doubles as the level-editing format:
##   '#' wall   '.' floor   'D' door (open)   'E' exit   'P' player start
##   's' slime   'w' wisp   'G' guardian

enum TileType { WALL, FLOOR, DOOR, EXIT }

## Enemy spawn table: ascii char -> stats.
const ENEMY_TYPES := {
	"s": {"name": "Slime", "speed": 50, "hp": 40, "attack": 4, "color": Color(0.3, 0.8, 0.3)},
	"w": {"name": "Wisp", "speed": 200, "hp": 15, "attack": 2, "color": Color(0.4, 0.7, 1.0)},
	"G": {"name": "Guardian", "speed": 80, "hp": 80, "attack": 12, "color": Color(0.9, 0.2, 0.2)},
}

@export_multiline var ascii_map := ""

var tiles: Dictionary = {}  # Vector2i -> TileType
var player_start := Vector2i(1, 1)
var guardian_pos := Vector2i.ZERO
var enemy_spawns: Array[Dictionary] = []  # {pos, type_key}
var map_size := Vector2i.ZERO

func _ready() -> void:
	_parse()

func _parse() -> void:
	var lines := ascii_map.split("\n", false)
	for y in lines.size():
		var line := lines[y]
		map_size.x = maxi(map_size.x, line.length())
		for x in line.length():
			var ch := line[x]
			match ch:
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
				_:
					if ENEMY_TYPES.has(ch):
						tiles[Vector2i(x, y)] = TileType.FLOOR
						enemy_spawns.append({"pos": Vector2i(x, y), "type": ch})
						if ch == "G":
							guardian_pos = Vector2i(x, y)
	map_size.y = lines.size()

func tile_at(pos: Vector2i) -> int:
	return tiles.get(pos, TileType.WALL)

func is_walkable(pos: Vector2i) -> bool:
	return tile_at(pos) != TileType.WALL

func grid_to_world(pos: Vector2i) -> Vector3:
	return Vector3(pos.x * Constants.TILE_SIZE, 0.0, pos.y * Constants.TILE_SIZE)
