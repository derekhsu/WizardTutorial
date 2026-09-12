extends SceneTree

func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	var mgr: TurnManager = main.get_node("TurnManager")
	var hud: HUD = main.get_node("HUD")
	print("hud=%s children=%s" % [hud, hud.get_children()])
	print("hud._overlay=%s" % hud._overlay)
	print("hud.get_node(Overlay)=%s" % hud.get_node_or_null("Overlay"))
	print("hud._hp_bar=%s" % hud._hp_bar)
	print("running=%s actors=%d" % [mgr.running, mgr.actors.size()])
	for a in mgr.actors:
		print("  %s energy=%d speed=%d" % [a.name, a.energy, a.speed])
	quit()
