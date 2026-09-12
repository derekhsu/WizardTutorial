class_name HUD
extends CanvasLayer

## Minimal HUD: HP/mana bars, message log, spell list, turn indicator,
## win/lose overlay. Listens to Player and TurnManager signals.

@onready var _hp_bar: ProgressBar = $Margin/VBox/TopRow/HPBar
@onready var _mana_bar: ProgressBar = $Margin/VBox/TopRow/ManaBar
@onready var _log: Label = $Margin/VBox/Log
@onready var _spells: RichTextLabel = $Margin/VBox/TopRow/Spells
@onready var _turn: Label = $Margin/VBox/TopRow/Turn
var _overlay: ColorRect
var _overlay_text: Label
var _overlay_hint: Label

var _messages: Array[String] = []
var _player: Player
var _manager: TurnManager

func _ready() -> void:
	_overlay = get_node("Overlay")
	_overlay_text = get_node("Overlay/Center/Text")
	_overlay_hint = get_node("Overlay/Center/Hint")
	_player = get_parent().get_node("Player")
	_manager = get_parent().get_node("TurnManager")
	_player.hp_changed.connect(_on_hp)
	_player.mana_changed.connect(_on_mana)
	_player.died.connect(_on_died)
	_player.won.connect(_on_won)
	_manager.message_logged.connect(_on_message)
	_manager.player_turn_started.connect(func(): _turn.text = "Your turn")
	_manager.player_turn_ended.connect(func(): _turn.text = "Enemies acting...")
	_on_hp(_player.hp, _player.max_hp)
	_on_mana(_player.mana, _player.max_mana)
	_update_spells()
	_overlay.hide()

func _on_hp(hp: int, max_hp: int) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp

func _on_mana(mana: int, max_mana: int) -> void:
	_mana_bar.max_value = max_mana
	_mana_bar.value = mana
	_update_spells()

func _on_message(text: String) -> void:
	_messages.append(text)
	if _messages.size() > 5:
		_messages.pop_front()
	_log.text = "\n".join(_messages)

func _update_spells() -> void:
	var parts: Array[String] = []
	for i in SpellSystem.SPELLS.size():
		var s: Dictionary = SpellSystem.SPELLS[i]
		var afford: bool = _player.mana >= s["mana"]
		var color := "white" if afford else "gray"
		parts.append("[color=%s]%d %s (%d)[/color]" % [color, i + 1, s["name"], s["mana"]])
	_spells.text = "  ".join(parts)

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
