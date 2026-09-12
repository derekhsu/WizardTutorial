extends SceneTree

func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	var mgr: TurnManager = main.get_node("TurnManager")
	print("running=%s actors=%d" % [mgr.running, mgr.actors.size()])
	for a in mgr.actors:
		print("  %s energy=%d speed=%d" % [a.name, a.energy, a.speed])
	quit()
