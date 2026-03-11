extends Control

var world_root: Node

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if world_root == null or world_root.city_map == null:
		return
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5), true)
	var sx := w / float(world_root.city_map.grid[0].size())
	var sy := h / float(world_root.city_map.grid.size())
	for y in range(0, world_root.city_map.grid.size(), 2):
		for x in range(0, world_root.city_map.grid[y].size(), 2):
			var t := int(world_root.city_map.grid[y][x])
			var c := Color(0.2, 0.2, 0.2, 0.35)
			if t == CityMap.TileType.WATER:
				c = Color(0.1, 0.25, 0.45, 0.5)
			draw_rect(Rect2(Vector2(x * sx, y * sy), Vector2(2 * sx, 2 * sy)), c, true)
	if world_root.player:
		var pcell := world_root.city_map.world_to_cell(world_root.player.global_position)
		draw_circle(Vector2(pcell.x * sx, pcell.y * sy), 3, Color(0.2, 0.4, 1.0))
	for police in world_root.police_vehicles:
		if not is_instance_valid(police):
			continue
		var cell := world_root.city_map.world_to_cell(police.global_position)
		draw_circle(Vector2(cell.x * sx, cell.y * sy), 2, Color(1, 0.2, 0.2))
	if MissionSystem.active_mission_id != "":
		draw_circle(Vector2(0.85 * w, 0.18 * h), 2, Color(1, 1, 0.2))
