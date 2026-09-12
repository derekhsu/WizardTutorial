class_name Player
extends Node3D

## Grid-discrete first-person controller. Logic lives on Vector2i grid
## coordinates; Tween only interpolates the presentation. Emits
## `action_taken(cost)` after every completed action — the Phase 2
## TurnManager will consume it; nothing listens yet.

signal action_taken(cost: int)

const MOVE_TIME := 0.18
const TURN_TIME := 0.15
const ACTION_COST := 100

@onready var dungeon_data: DungeonData = get_parent().get_node("DungeonData")

var grid_pos := Vector2i.ZERO
var facing := Vector2i(0, -1)  # -Y = north
var input_enabled := true

var _busy := false
var _torch: OmniLight3D

@onready var _camera: Camera3D = $Camera3D

func _ready() -> void:
	grid_pos = dungeon_data.player_start
	_sync_transform()
	_torch = $Camera3D/Torch
	_flicker()

func _process(_delta: float) -> void:
	if not input_enabled or _busy:
		return
	if Input.is_action_pressed("move_forward"):
		move_forward()
	elif Input.is_action_pressed("move_back"):
		move_back()
	elif Input.is_action_pressed("strafe_left"):
		strafe_left()
	elif Input.is_action_pressed("strafe_right"):
		strafe_right()
	elif Input.is_action_pressed("turn_left"):
		turn_left()
	elif Input.is_action_pressed("turn_right"):
		turn_right()

func is_busy() -> bool:
	return _busy

func move_forward() -> void:
	_try_move(facing)

func move_back() -> void:
	_try_move(-facing)

func strafe_left() -> void:
	_try_move(Vector2i(facing.y, -facing.x))

func strafe_right() -> void:
	_try_move(Vector2i(-facing.y, facing.x))

func turn_left() -> void:
	_turn(Vector2i(facing.y, -facing.x))

func turn_right() -> void:
	_turn(Vector2i(-facing.y, facing.x))

func _try_move(dir: Vector2i) -> void:
	if _busy:
		return
	var target := grid_pos + dir
	if not dungeon_data.is_walkable(target):
		return
	_busy = true
	grid_pos = target
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", dungeon_data.grid_to_world(target), MOVE_TIME)
	tween.parallel().tween_property(_camera, "position:y", Constants.EYE_HEIGHT + 0.05, MOVE_TIME * 0.5)
	tween.tween_property(_camera, "position:y", Constants.EYE_HEIGHT, MOVE_TIME * 0.5)
	tween.finished.connect(_on_action_done, CONNECT_ONE_SHOT)

func _turn(new_facing: Vector2i) -> void:
	if _busy:
		return
	_busy = true
	facing = new_facing
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation:y", _yaw_for(facing), TURN_TIME)
	tween.finished.connect(_on_action_done, CONNECT_ONE_SHOT)

func _on_action_done() -> void:
	_busy = false
	action_taken.emit(ACTION_COST)

func _yaw_for(dir: Vector2i) -> float:
	return atan2(-float(dir.x), -float(dir.y))

func _sync_transform() -> void:
	position = dungeon_data.grid_to_world(grid_pos)
	rotation.y = _yaw_for(facing)

## Instant placement for tests and future spawn logic. No animation, no cost.
func teleport(pos: Vector2i, dir: Vector2i) -> void:
	grid_pos = pos
	facing = dir
	_sync_transform()

func _flicker() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_torch, "light_energy", 1.35, 0.12)
	tween.tween_property(_torch, "light_energy", 1.1, 0.17)
