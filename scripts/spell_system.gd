class_name SpellSystem
extends Node

## Spell definitions and casting. Spells are the player's primary action:
## each has an energy cost (paid to the TurnManager) and a mana cost.
## Targeting is facing-direction raycast; fireball adds a 3x3 AoE around the
## first enemy hit.

const SPELLS := [
	{"name": "Magic Missile", "energy": 100, "mana": 5, "damage": 15, "aoe": false, "color": Color(0.5, 0.8, 1.0)},
	{"name": "Fireball", "energy": 200, "mana": 10, "damage": 20, "aoe": true, "color": Color(1.0, 0.5, 0.1)},
	{"name": "Lightning Bolt", "energy": 300, "mana": 15, "damage": 35, "aoe": false, "color": Color(1.0, 1.0, 0.3)},
]

var player: Player
var manager: TurnManager

func _ready() -> void:
	player = get_parent()
	manager = get_parent().get_parent().get_node("TurnManager")

func can_cast(index: int) -> bool:
	return index >= 0 and index < SPELLS.size() and player.mana >= SPELLS[index]["mana"]

func cast(index: int) -> void:
	if player.is_busy() or not can_cast(index):
		return
	var spell: Dictionary = SPELLS[index]
	player.mana -= spell["mana"]
	player.mana_changed.emit(player.mana, player.max_mana)
	player._busy = true
	manager.log_message("You cast %s." % spell["name"])
	await _projectile(spell)
	player._finish_action(spell["energy"])

func _projectile(spell: Dictionary) -> void:
	# Find first enemy in facing direction.
	var target: Enemy = null
	var pos := player.grid_pos
	for i in 8:
		pos += player.facing
		if not player.dungeon_data.is_walkable(pos):
			break
		var occ := manager.actor_at(pos)
		if occ is Enemy:
			target = occ
			break
	if target == null:
		# No target: still pay the cost (wasted cast).
		await get_tree().create_timer(0.15).timeout
		return

	# Visual: glowing sphere tweened to the target tile.
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	orb.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = spell["color"]
	mat.emission_enabled = true
	mat.emission = spell["color"]
	mat.emission_energy_multiplier = 2.0
	orb.material_override = mat
	orb.position = player.position + Vector3(0, 1.4, 0)
	get_tree().root.add_child(orb)

	var target_pos := Vector3(target.grid_pos.x * Constants.TILE_SIZE, 1.0, target.grid_pos.y * Constants.TILE_SIZE)
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(orb, "position", target_pos, 0.18)
	await tween.finished
	orb.queue_free()

	# Damage.
	if spell["aoe"]:
		var center := target.grid_pos
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				var occ := manager.actor_at(center + Vector2i(dx, dy))
				if occ is Enemy:
					occ.take_damage(spell["damage"], manager)
	else:
		target.take_damage(spell["damage"], manager)
