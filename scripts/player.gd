class_name Player
extends Node3D

## Grid-discrete first-person controller. Logic lives on Vector2i grid
## coordinates; Tween only interpolates the presentation. Emits
## `action_taken(cost)` after every completed action — the TurnManager
## consumes it to advance the energy schedule.

signal action_taken(cost: int)
signal hp_changed(hp: int, max_hp: int)
signal mana_changed(mana: int, max_mana: int)
signal died
signal won

const MOVE_TIME := 0.18
const TURN_TIME := 0.15
const ATTACK_TIME := 0.22
const ACTION_COST := 100

@onready var dungeon_data: DungeonData = get_parent().get_node("DungeonData")
@onready var spells: SpellSystem = $SpellSystem

var grid_pos := Vector2i.ZERO
var facing := Vector2i(0, -1)  # -Y = north
var input_enabled := false  # TurnManager grants input on the player's turn
var speed := 100
var energy := 0
var hp := 50
var max_hp := 50
var mana := 30
var max_mana := 30
var attack_power := 10
var alive := true

var _busy := false
var _queued_action := ""
var _last_polled := ""
var _torch: OmniLight3D
var _turn_manager: TurnManager

@onready var _camera: Camera3D = $Camera3D

func _ready() -> void:
	grid_pos = dungeon_data.player_start
	_sync_transform()
	_torch = $Camera3D/Torch
	_flicker()
	_turn_manager = get_parent().get_node_or_null("TurnManager")

func _process(_delta: float) -> void:
	# Consume a buffered action the moment the player's turn starts.
	if input_enabled and not _busy and alive and not _queued_action.is_empty():
		var queued := _queued_action
		_queued_action = ""
		_dispatch(queued)
		return
	var action := _poll_input()
	if action.is_empty():
		_last_polled = ""
		return
	if not input_enabled or _busy or not alive:
		# Buffer only on a fresh press (action changed since last frame).
		# "wait" is meaningless to queue — it's already a no-op.
		if action != _last_polled and action != "wait":
			_queued_action = action
		_last_polled = action
		return
	_last_polled = action
	_queued_action = ""
	_dispatch(action)

func _poll_input() -> String:
	if Input.is_action_pressed("move_forward"):
		return "move_forward"
	if Input.is_action_pressed("move_back"):
		return "move_back"
	if Input.is_action_pressed("strafe_left"):
		return "strafe_left"
	if Input.is_action_pressed("strafe_right"):
		return "strafe_right"
	if Input.is_action_pressed("turn_left"):
		return "turn_left"
	if Input.is_action_pressed("turn_right"):
		return "turn_right"
	if Input.is_action_pressed("wait"):
		return "wait"
	if Input.is_action_pressed("spell_1"):
		return "spell_1"
	if Input.is_action_pressed("spell_2"):
		return "spell_2"
	if Input.is_action_pressed("spell_3"):
		return "spell_3"
	return ""

func _dispatch(action: String) -> void:
	match action:
		"move_forward": move_forward()
		"move_back": move_back()
		"strafe_left": strafe_left()
		"strafe_right": strafe_right()
		"turn_left": turn_left()
		"turn_right": turn_right()
		"wait": wait()
		"spell_1": cast_spell(0)
		"spell_2": cast_spell(1)
		"spell_3": cast_spell(2)

func is_busy() -> bool:
	return _busy

func move_forward() -> void:
	_try_move_or_attack(facing)

func move_back() -> void:
	_try_move_or_attack(-facing)

func strafe_left() -> void:
	_try_move_or_attack(Vector2i(facing.y, -facing.x))

func strafe_right() -> void:
	_try_move_or_attack(Vector2i(-facing.y, facing.x))

func turn_left() -> void:
	_turn(Vector2i(facing.y, -facing.x))

func turn_right() -> void:
	_turn(Vector2i(-facing.y, facing.x))

func wait() -> void:
	if _busy:
		return
	_busy = true
	_finish_action(ACTION_COST)

func cast_spell(index: int) -> void:
	if _busy or not spells.can_cast(index):
		if not spells.can_cast(index):
			_turn_manager.log_message("Not enough mana.")
		return
	spells.cast(index)

func _try_move_or_attack(dir: Vector2i) -> void:
	if _busy:
		return
	var target := grid_pos + dir
	var occupant := _occupant_at(target)
	if occupant != null:
		_attack(occupant)
		return
	if not dungeon_data.is_walkable(target):
		return
	_busy = true
	grid_pos = target
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", dungeon_data.grid_to_world(target), MOVE_TIME)
	tween.parallel().tween_property(_camera, "position:y", Constants.EYE_HEIGHT + 0.05, MOVE_TIME * 0.5)
	tween.tween_property(_camera, "position:y", Constants.EYE_HEIGHT, MOVE_TIME * 0.5)
	tween.finished.connect(_on_action_done, CONNECT_ONE_SHOT)

func _occupant_at(pos: Vector2i) -> Node:
	if _turn_manager == null:
		_turn_manager = get_parent().get_node_or_null("TurnManager")
	if _turn_manager == null:
		return null
	return _turn_manager.actor_at(pos)

func _attack(target: Node) -> void:
	_busy = true
	var dir := Vector3(float(target.grid_pos.x - grid_pos.x), 0.0, float(target.grid_pos.y - grid_pos.y)) * 0.35
	var start := position
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position", start + dir, ATTACK_TIME * 0.4)
	tween.tween_property(self, "position", start, ATTACK_TIME * 0.6)
	tween.finished.connect(func() -> void:
		target.take_damage(attack_power, _turn_manager)
		_finish_action(ACTION_COST)
	, CONNECT_ONE_SHOT)

func take_damage(amount: int) -> void:
	if not alive:
		return
	hp -= amount
	hp_changed.emit(hp, max_hp)
	_flash_damage()
	var hud := get_parent().get_node_or_null("HUD")
	if hud:
		hud.flash_damage()
	if hp <= 0:
		alive = false
		died.emit()

func _turn(new_facing: Vector2i) -> void:
	if _busy:
		return
	_busy = true
	facing = new_facing
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation:y", _yaw_for(facing), TURN_TIME)
	tween.finished.connect(_on_action_done, CONNECT_ONE_SHOT)

func _on_action_done() -> void:
	# Mana regen: +1 per player action.
	mana = mini(mana + 1, max_mana)
	mana_changed.emit(mana, max_mana)
	# Win check: stepping on the exit after the guardian is dead.
	if dungeon_data.tile_at(grid_pos) == DungeonData.TileType.EXIT:
		if _turn_manager.guardian_alive():
			_turn_manager.log_message("The exit is sealed by the Guardian.")
		else:
			won.emit()
	_finish_action(ACTION_COST)

func _finish_action(cost: int) -> void:
	_busy = false
	action_taken.emit(cost)


func _flash_damage() -> void:
	var tween := create_tween()
	tween.tween_property(_torch, "light_color", Color.RED, 0.05)
	tween.tween_property(_torch, "light_color", Color(1, 0.75, 0.45), 0.3)

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
