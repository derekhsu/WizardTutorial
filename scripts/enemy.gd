class_name Enemy
extends Node3D

## Grid actor with energy-based scheduling. AI: attack if the player is
## adjacent, otherwise step along the AStar path. Movement tween mirrors the
## player's presentation; the scheduler awaits it before continuing.

signal died(enemy: Enemy)
signal acted(enemy: Enemy)

const MOVE_TIME := 0.18
const ATTACK_TIME := 0.22

var display_name := "Enemy"
var speed := 100
var energy := 0
var hp := 30
var attack_power := 5
var grid_pos := Vector2i.ZERO
var color := Color.RED

var _busy := false
var _mesh: MeshInstance3D
var _light: OmniLight3D

func configure(p_display_name: String, p_speed: int, p_hp: int, p_attack: int, p_color: Color) -> void:
	display_name = p_display_name
	speed = p_speed
	hp = p_hp
	attack_power = p_attack
	color = p_color

func _ready() -> void:
	_build_visuals()

func _build_visuals() -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.45
	capsule.height = 1.6
	_mesh = MeshInstance3D.new()
	_mesh.mesh = capsule
	_mesh.position.y = 0.8
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.4
	_mesh.material_override = mat
	add_child(_mesh)

	_light = OmniLight3D.new()
	_light.light_color = color
	_light.light_energy = 0.5
	_light.omni_range = 4.0
	_light.position.y = 1.2
	add_child(_light)

func take_turn(manager: TurnManager) -> int:
	acted.emit(self)
	var player := manager.player
	var to_player: Vector2i = player.grid_pos - grid_pos
	# Adjacent (including diagonal-free Manhattan distance 1) -> attack.
	if absi(to_player.x) + absi(to_player.y) == 1:
		await _attack(player, manager)
		return 100
	# Otherwise path toward the player.
	var path := manager.path_to(grid_pos, player.grid_pos)
	if path.size() >= 2:
		var next := Vector2i(path[1])
		if not manager.is_occupied(next):
			await _move_to(next)
		else:
			# Blocked by another actor; wait this turn.
			await get_tree().create_timer(0.05).timeout
	else:
		await get_tree().create_timer(0.05).timeout
	return 100

func _move_to(target: Vector2i) -> void:
	_busy = true
	grid_pos = target
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", _world_pos(target), MOVE_TIME)
	await tween.finished
	_busy = false

func _attack(player: Player, manager: TurnManager) -> void:
	_busy = true
	# Lunge toward the player and back.
	var dir := Vector3(float(player.grid_pos.x - grid_pos.x), 0.0, float(player.grid_pos.y - grid_pos.y)) * 0.4
	var start := position
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position", start + dir, ATTACK_TIME * 0.4)
	tween.tween_property(self, "position", start, ATTACK_TIME * 0.6)
	await tween.finished
	player.take_damage(attack_power)
	manager.log_message("%s hits you for %d." % [display_name, attack_power])
	_busy = false

func take_damage(amount: int, manager: TurnManager) -> void:
	hp -= amount
	manager.log_message("%s takes %d damage." % [display_name, amount])
	if hp <= 0:
		die(manager)

func die(manager: TurnManager) -> void:
	manager.log_message("%s dies." % display_name)
	manager.actors.erase(self)
	died.emit(self)
	queue_free()

func _world_pos(pos: Vector2i) -> Vector3:
	return Vector3(pos.x * Constants.TILE_SIZE, 0.0, pos.y * Constants.TILE_SIZE)

func is_busy() -> bool:
	return _busy
