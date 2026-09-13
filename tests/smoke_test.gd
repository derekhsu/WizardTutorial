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

	# Spell: teleport next to the wisp's current position and cast magic missile.
	var wisp_pos := wisp.grid_pos
	_player.teleport(wisp_pos + Vector2i(0, -1), Vector2i(0, 1))
	var mana_before: int = _player.mana
	await _press("spell_1")
	# Wait for the cast to finish (projectile tween + action_taken).
	for i in 60:
		await process_frame
		if _player.mana < mana_before:
			break
	_assert(_player.mana == mana_before - 5, "spell_1 costs 5 mana, got %d" % _player.mana)
	_assert(not is_instance_valid(wisp) or wisp.hp < 15, "wisp took damage or died")

	# Win condition: exit sealed while guardian alive.
	_player.teleport(Vector2i(12, 12), Vector2i(0, -1))
	var won := [false]
	_player.won.connect(func(): won[0] = true)
	await _press("move_forward")  # step onto exit (12,12)? exit is (12,12)? map row 12: "#......#...#E.#" -> E at x=12
	_assert(not won[0], "exit sealed while guardian alive")

	# Death: set hp low and let the guardian hit.
	_player.hp = 1
	var died := [false]
	_player.died.connect(func(): died[0] = true)
	# Teleport next to guardian (12,11) and wait for it to attack.
	_player.teleport(Vector2i(11, 11), Vector2i(1, 0))
	for i in 20:
		await _press("wait")
		if died[0]:
			break
	_assert(died[0], "player died to guardian")

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
		"spell_1": return KEY_1
		"spell_2": return KEY_2
		"spell_3": return KEY_3
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

