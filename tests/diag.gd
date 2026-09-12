extends SceneTree

func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var data: DungeonData = main.get_node("DungeonData")
	var lines := data.ascii_map.split("\n", false)
	print("lines=", lines.size())
	for i in lines.size():
		print(i, " len=", lines[i].length(), " '", lines[i], "'")
	var player: Player = main.get_node("Player")
	print("player.dungeon_data=", player.dungeon_data)
	print("builder.data=", main.get_node("DungeonBuilder").data)
	quit()
