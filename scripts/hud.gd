class_name HUD
extends CanvasLayer

## PoC HUD: HP/mana bars (bottom-left), message log (bottom-center),
## spell bar (bottom-right), turn indicator (top-center), turn-order preview
## (top-right), faced-enemy info (under crosshair), damage flash, win/lose
## overlay. Information design only — default theme, no custom art.

@onready var _hp_bar: ProgressBar = $BottomLeft/HPBar
@onready var _mana_bar: ProgressBar = $BottomLeft/ManaBar
@onready var _hp_text: Label
@onready var _mana_text: Label
@onready var _log: Label = $Log
@onready var _spell_bar: HBoxContainer = $SpellBar
@onready var _turn: Label = $TopCenter
@onready var _turn_order: Label = $TurnOrder
@onready var _enemy_name: Label = $EnemyInfo/Name
@onready var _enemy_hp: ProgressBar = $EnemyInfo/HPBar
@onready var _enemy_info: VBoxContainer = $EnemyInfo
@onready var _flash: ColorRect = $DamageFlash
@onready var _overlay: ColorRect = $Overlay
@onready var _overlay_text: Label = $Overlay/Center/Text
@onready var _overlay_hint: Label = $Overlay/Center/Hint

var _messages: Array[String] = []
var _player: Player
var _manager: TurnManager
var _spell_slots: Array[PanelContainer] = []

func _ready() -> void:
	_overlay = get_node("Overlay")
	_overlay_text = get_node("Overlay/Center/Text")
	_overlay_hint = get_node("Overlay/Center/Hint")
	_player = get_parent().get_node("Player")
	_manager = get_parent().get_node("TurnManager")
	_build_bar_labels()
	_build_spell_bar()
	_player.hp_changed.connect(_on_hp)
	_player.mana_changed.connect(_on_mana)
	_player.died.connect(_on_died)
	_player.won.connect(_on_won)
	_manager.message_logged.connect(_on_message)
	_manager.player_turn_started.connect(_on_turn_start)
	_manager.player_turn_ended.connect(_on_turn_end)
	_on_hp(_player.hp, _player.max_hp)
	_on_mana(_player.mana, _player.max_mana)
	_overlay.hide()
	_enemy_info.hide()

func _process(_delta: float) -> void:
	_update_enemy_info()

func _build_bar_labels() -> void:
	# Numeric readout overlaid on each bar.
	for bar: ProgressBar in [_hp_bar, _mana_bar]:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.add_theme_font_size_override("font_size", 13)
		bar.add_child(label)
	_hp_text = _hp_bar.get_child(0)
	_mana_text = _mana_bar.get_child(0)

func _build_spell_bar() -> void:
	for i in SpellSystem.SPELLS.size():
		var s: Dictionary = SpellSystem.SPELLS[i]
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(118, 58)
		var vbox := VBoxContainer.new()
		var title := Label.new()
		title.text = "%d %s" % [i + 1, s["name"]]
		title.add_theme_font_size_override("font_size", 13)
		var cost := Label.new()
		cost.text = "%d mana / %d t" % [s["mana"], s["energy"]]
		cost.add_theme_font_size_override("font_size", 11)
		vbox.add_child(title)
		vbox.add_child(cost)
		slot.add_child(vbox)
		_spell_bar.add_child(slot)
		_spell_slots.append(slot)

func _on_hp(hp: int, max_hp: int) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_text.text = "%d / %d" % [hp, max_hp]

func _on_mana(mana: int, max_mana: int) -> void:
	_mana_bar.max_value = max_mana
	_mana_bar.value = mana
	_mana_text.text = "%d / %d" % [mana, max_mana]
	_update_spell_slots()

func _update_spell_slots() -> void:
	for i in _spell_slots.size():
		var affordable: bool = _player.mana >= SpellSystem.SPELLS[i]["mana"]
		_spell_slots[i].modulate = Color.WHITE if affordable else Color(0.4, 0.4, 0.4)

func _on_message(text: String) -> void:
	_messages.append(text)
	if _messages.size() > 5:
		_messages.pop_front()
	_log.text = "\n".join(_messages)

func _on_turn_start() -> void:
	_turn.text = "— Your turn —"
	_turn.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	_update_turn_order()

func _on_turn_end() -> void:
	_turn.text = "Enemies acting..."
	_turn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_update_turn_order()

## Simulates the energy schedule forward to preview the next 3 actors.
func _update_turn_order() -> void:
	var sim: Array = []
	for a in _manager.actors:
		sim.append({"name": a.display_name if a is Enemy else "You", "energy": a.energy, "speed": a.speed})
	var order: Array[String] = []
	var guard := 0
	while order.size() < 3 and guard < 64:
		guard += 1
		# Find the actor who reaches threshold soonest.
		var best_i := -1
		var best_ticks := 1e9
		for i in sim.size():
			var need: float = maxf(0.0, 100.0 - sim[i]["energy"])
			var ticks: float = need / sim[i]["speed"]
			if ticks < best_ticks:
				best_ticks = ticks
				best_i = i
		if best_i < 0:
			break
		for i in sim.size():
			sim[i]["energy"] += sim[i]["speed"] * best_ticks
		sim[best_i]["energy"] -= 100.0
		order.append(sim[best_i]["name"])
	_turn_order.text = "Next: " + " → ".join(order)

func _update_enemy_info() -> void:
	var target := _faced_enemy()
	if target == null:
		_enemy_info.hide()
		return
	_enemy_info.show()
	_enemy_name.text = target.display_name
	_enemy_hp.max_value = target.max_hp
	_enemy_hp.value = target.hp

func _faced_enemy() -> Enemy:
	var pos: Vector2i = _player.grid_pos
	for i in 8:
		pos += _player.facing
		if not _player.dungeon_data.is_walkable(pos):
			return null
		var occ := _manager.actor_at(pos)
		if occ is Enemy:
			return occ
	return null

func flash_damage() -> void:
	_flash.color.a = 0.35
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.4)

func _on_died() -> void:
	_overlay.color = Color(0.3, 0.0, 0.0, 0.85)
	_overlay_text.text = "YOU DIED"
	_overlay_hint.text = "Press R to restart"
	_overlay.show()

func _on_won() -> void:
	_overlay.color = Color(0.0, 0.25, 0.1, 0.85)
	_overlay_text.text = "YOU ESCAPED"
	_overlay_hint.text = "Press R to restart"
	_overlay.show()

func _unhandled_input(event: InputEvent) -> void:
	if _overlay == null:
		return
	if _overlay.visible and event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()
