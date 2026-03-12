extends Control

var world_root: Node2D

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if world_root == null:
		return
	var city_map: CityMap = world_root.get("city_map") as CityMap
	if city_map == null:
		return
	var player: Node2D = world_root.get("player") as Node2D
	var police_vehicles: Array = world_root.get("police_vehicles")
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5), true)
	var sx: float = w / float(city_map.grid[0].size())
	var sy: float = h / float(city_map.grid.size())
	for y in range(0, city_map.grid.size(), 2):
		for x in range(0, city_map.grid[y].size(), 2):
			var t: int = int(city_map.grid[y][x])
			var c: Color = Color(0.2, 0.2, 0.2, 0.35)
			if t == CityMap.TileType.WATER:
				c = Color(0.1, 0.25, 0.45, 0.5)
			draw_rect(Rect2(Vector2(x * sx, y * sy), Vector2(2 * sx, 2 * sy)), c, true)
	if player:
		var pcell: Vector2i = city_map.world_to_cell(player.global_position)
		draw_circle(Vector2(pcell.x * sx, pcell.y * sy), 3, Color(0.2, 0.4, 1.0))
	for police in police_vehicles:
		if not is_instance_valid(police):
			continue
		var police_node: Node2D = police as Node2D
		if police_node == null:
			continue
		var cell: Vector2i = city_map.world_to_cell(police_node.global_position)
		draw_circle(Vector2(cell.x * sx, cell.y * sy), 2, Color(1, 0.2, 0.2))
	if MissionSystem.active_mission_id != "":
		draw_circle(Vector2(0.85 * w, 0.18 * h), 2, Color(1, 1, 0.2))
