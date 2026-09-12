class_name TurnManager
extends Node

## Energy/tick scheduler. Each tick every actor gains `speed` energy; actors at
## or above ENERGY_THRESHOLD act in descending-speed order, paying their
## action's cost. The player is a special actor: when ready, the scheduler
## pauses and waits for `action_taken` instead of running AI.

signal player_turn_started
signal player_turn_ended
signal message_logged(text: String)

const ENERGY_THRESHOLD := 100

var actors: Array = []  # Player + Enemy instances
var player: Player
var dungeon_data: DungeonData
var running := false

var _astar := AStarGrid2D.new()

func _ready() -> void:
	dungeon_data = get_parent().get_node("DungeonData")
	player = get_parent().get_node("Player")
	_build_astar()
	_spawn_enemies()
	_start.call_deferred()

func _start() -> void:
	_collect_actors()
	player.action_taken.connect(_on_player_action)
	running = true
	_run()

func _spawn_enemies() -> void:
	for spawn in dungeon_data.enemy_spawns:
		var enemy := Enemy.new()
		var spec: Dictionary = DungeonData.ENEMY_TYPES[spawn["type"]]
		enemy.configure(spec["name"], spec["speed"], spec["hp"], spec["attack"], spec["color"])
		enemy.grid_pos = spawn["pos"]
		enemy.position = dungeon_data.grid_to_world(spawn["pos"])
		get_parent().add_child.call_deferred(enemy)

func _build_astar() -> void:
	_astar.region = Rect2i(Vector2i.ZERO, dungeon_data.map_size)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()
	for pos: Vector2i in dungeon_data.tiles:
		if dungeon_data.tiles[pos] == DungeonData.TileType.WALL:
			_astar.set_point_solid(pos, true)

func _collect_actors() -> void:
	actors.append(player)
	for child in get_parent().get_children():
		if child is Enemy:
			actors.append(child)

func actor_at(pos: Vector2i) -> Node:
	for a in actors:
		if a.grid_pos == pos:
			return a
	return null

func is_occupied(pos: Vector2i) -> bool:
	return actor_at(pos) != null

func _run() -> void:
	while running:
		var ready := _ready_actors()
		if ready.is_empty():
			_tick()
			await get_tree().process_frame
			continue
		for actor in ready:
			if not running:
				return
			if actor == player:
				await _player_turn()
			else:
				await _enemy_turn(actor)

func _ready_actors() -> Array:
	var ready: Array = []
	for a in actors:
		if a.energy >= ENERGY_THRESHOLD:
			ready.append(a)
	ready.sort_custom(func(a, b): return a.speed > b.speed)
	return ready

func _tick() -> void:
	for a in actors:
		a.energy += a.speed

func _player_turn() -> void:
	player.input_enabled = true
	player_turn_started.emit()
	# Wait for the player to act; action_taken carries the energy cost.
	var cost: int = await player.action_taken
	player.energy -= cost
	player.input_enabled = false
	player_turn_ended.emit()

func _enemy_turn(enemy: Enemy) -> void:
	for a in actors:
		if a != enemy and a.grid_pos != player.grid_pos:
			_astar.set_point_solid(a.grid_pos, true)
	var cost: int = await enemy.take_turn(self)
	enemy.energy -= cost
	for a in actors:
		if a != enemy:
			_astar.set_point_solid(a.grid_pos, false)

func _on_player_action(_cost: int) -> void:
	pass  # handled by the await in _player_turn

func path_to(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	return _astar.get_point_path(from, to)

func log_message(text: String) -> void:
	message_logged.emit(text)
	print("[log] " + text)
