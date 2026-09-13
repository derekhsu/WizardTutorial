extends SceneTree

## Launches the real main scene and dumps scheduler state over time.
##   godot --path . -s tests/observe.gd

func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var player: Player = main.get_node("Player")
	var mgr: TurnManager = main.get_node("TurnManager")
	for i in 300:
		await process_frame
		if i % 60 == 0:
			var states := ""
			for a in mgr.actors:
				states += "%s(e=%d) " % [a.name, a.energy]
			print("f%d input=%s busy=%s | %s" % [i, player.input_enabled, player.is_busy(), states])
	quit()
