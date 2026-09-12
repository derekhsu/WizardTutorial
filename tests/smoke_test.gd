extends SceneTree

## Phase 1 smoke test. Run:
##   godot --headless --path . -s tests/smoke_test.gd          (logic asserts)
##   godot --path . -s tests/smoke_test.gd -- --shots          (windowed, writes shots/*.png)

var _failures: Array[String] = []
var _player: Player

func _initialize() -> void:
	var shots := "--shots" in OS.get_cmdline_user_args()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	_player = main.get_node("Player")
	var data: DungeonData = main.get_node("DungeonData")

	_assert(data.player_start == Vector2i(2, 2), "player_start parsed")
	_assert(data.guardian_pos == Vector2i(12, 11), "guardian_pos parsed")
	_assert(_player.grid_pos == Vector2i(2, 2), "player at start")

	# Simulated input: forward once -> (2,1); second press hits north wall
	await _press("move_forward")
	_assert(_player.grid_pos == Vector2i(2, 1), "forward -> (2,1), got %s" % _player.grid_pos)
	await _press("move_forward")
	_assert(_player.grid_pos == Vector2i(2, 1), "wall blocks move")

	# Turn right (east), forward -> (3,1)
	await _press("turn_right")
	_assert(_player.facing == Vector2i(1, 0), "turn_right faces east")
	await _press("move_forward")
	_assert(_player.grid_pos == Vector2i(3, 1), "east move -> (3,1), got %s" % _player.grid_pos)

	# Strafe right (south) -> (3,2)
	await _press("strafe_right")
	_assert(_player.grid_pos == Vector2i(3, 2), "strafe -> (3,2), got %s" % _player.grid_pos)

	# Direct-call path (input-independent)
	_player.teleport(Vector2i(2, 2), Vector2i(0, -1))
	_player.move_back()
	await _idle()
	_assert(_player.grid_pos == Vector2i(2, 3), "move_back -> (2,3), got %s" % _player.grid_pos)

	if shots:
		await _shoot(Vector2i(2, 7), Vector2i(0, -1), "shots/corridor.png")
		await _shoot(Vector2i(7, 5), Vector2i(0, -1), "shots/midroom.png")
		await _shoot(Vector2i(11, 11), Vector2i(1, 0), "shots/exit.png")

	if _failures.is_empty():
		print("SMOKE: all assertions passed")
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		quit(1)
		return
	quit(0)

func _press(action: String) -> void:
	await _idle()
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
