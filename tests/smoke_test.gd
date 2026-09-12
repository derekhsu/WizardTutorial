extends SceneTree

## Phase 1+2 smoke test. Run:
##   godot --headless --path . -s tests/smoke_test.gd          (logic asserts)
##   godot --path . -s tests/smoke_test.gd -- --shots          (windowed, writes shots/*.png)

var _failures: Array[String] = []
var _player: Player
var _manager: TurnManager
var _main: Node

func _initialize() -> void:
	var shots := "--shots" in OS.get_cmdline_user_args()
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	await process_frame
	await process_frame

	_player = _main.get_node("Player")
	_manager = _main.get_node("TurnManager")
	var data: DungeonData = _main.get_node("DungeonData")

	_assert(data.player_start == Vector2i(2, 2), "player_start parsed")
	_assert(data.guardian_pos == Vector2i(12, 11), "guardian_pos parsed")
	_assert(data.enemy_spawns.size() == 3, "3 enemy spawns parsed, got %d" % data.enemy_spawns.size())
	_assert(_player.grid_pos == Vector2i(2, 2), "player at start")

	# Enemies spawned and registered
	var enemies := _enemies()
	_assert(enemies.size() == 3, "3 enemies spawned, got %d" % enemies.size())
	_assert(_manager.actors.size() == 4, "4 actors registered, got %d" % _manager.actors.size())

	# Movement still works under the scheduler
	await _press("move_forward")
	_assert(_player.grid_pos == Vector2i(2, 1), "forward -> (2,1), got %s" % _player.grid_pos)
	await _press("move_forward")
	_assert(_player.grid_pos == Vector2i(2, 1), "wall blocks move")

	# Speed difference: wisp (200) should act ~2x per player turn vs slime (50).
	var wisp := _enemy_of_type("w")
	var slime := _enemy_of_type("s")
	var wisp_acts := [0]
	var slime_acts := [0]
	wisp.acted.connect(func(_e): wisp_acts[0] += 1)
	slime.acted.connect(func(_e): slime_acts[0] += 1)
	for i in 10:
		await _press("wait")
	print("acts over 10 waits: wisp=%d slime=%d" % [wisp_acts[0], slime_acts[0]])
	_assert(wisp_acts[0] >= 12, "wisp acted >=12 times, got %d" % wisp_acts[0])
	_assert(slime_acts[0] >= 3 and slime_acts[0] <= 7, "slime acted 3-7 times, got %d" % slime_acts[0])

	if shots:
		await _shoot(Vector2i(2, 7), Vector2i(0, -1), "shots/corridor.png")
		await _shoot(Vector2i(7, 5), Vector2i(0, -1), "shots/midroom.png")
		await _shoot(Vector2i(11, 11), Vector2i(1, 0), "shots/exit.png")
		await _shoot(Vector2i(7, 5), Vector2i(0, 1), "shots/enemy.png")

	if _failures.is_empty():
		print("SMOKE: all assertions passed")
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		quit(1)
		return
	quit(0)

func _enemies() -> Array:
	var out: Array = []
	for child in _main.get_children():
		if child is Enemy:
			out.append(child)
	return out

func _enemy_of_type(type_key: String) -> Enemy:
	for e in _enemies():
		if e.display_name == DungeonData.ENEMY_TYPES[type_key]["name"]:
			return e
	return null

func _press(action: String) -> void:
	await _idle()
	# Wait until the scheduler grants the player a turn.
	for i in 120:
		await process_frame
		if _player.input_enabled:
			break
	var key := _key_for(action)
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	for i in 3:
		await process_frame
	var up := InputEventKey.new()
	up.physical_keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	await _idle()

func _key_for(action: String) -> Key:
	match action:
		"move_forward": return KEY_W
		"move_back": return KEY_S
		"strafe_left": return KEY_A
		"strafe_right": return KEY_D
		"turn_left": return KEY_Q
		"turn_right": return KEY_E
		"wait": return KEY_SPACE
	return KEY_NONE

func _idle() -> void:
	for i in 90:
		await process_frame
		if not _player.is_busy():
			return
	_failures.append("player still busy after 90 frames")

func _shoot(pos: Vector2i, dir: Vector2i, path: String) -> void:
	_player.teleport(pos, dir)
	for i in 10:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("shot: " + path)

func _assert(cond: bool, name: String) -> void:
	if cond:
		print("ok: " + name)
	else:
		_failures.append(name)
		printerr("FAIL: " + name)

