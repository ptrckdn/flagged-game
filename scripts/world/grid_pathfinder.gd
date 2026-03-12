extends RefCounted
class_name GridPathfinder

static func find_path(
	start: Vector2i,
	goal: Vector2i,
	is_walkable: Callable,
	get_neighbors: Callable,
	max_expansions: int = 1500
) -> Array[Vector2i]:
	if start == goal:
		return [start]

	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var cost_so_far: Dictionary = {start: 0.0}
	var expansions: int = 0

	while (not frontier.is_empty()) and (expansions < max_expansions):
		expansions += 1
		frontier.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return float(cost_so_far[a]) + _heuristic(a, goal) < float(cost_so_far[b]) + _heuristic(b, goal)
		)

		var current: Vector2i = frontier.pop_front()
		if current == goal:
			break

		var neighbors: Array[Vector2i] = get_neighbors.call(current)
		for next_cell: Vector2i in neighbors:
			if not is_walkable.call(next_cell):
				continue
			var new_cost: float = float(cost_so_far[current]) + 1.0
			if (not cost_so_far.has(next_cell)) or (new_cost < float(cost_so_far[next_cell])):
				cost_so_far[next_cell] = new_cost
				came_from[next_cell] = current
				if not frontier.has(next_cell):
					frontier.append(next_cell)

	if not came_from.has(goal):
		return []

	var path: Array[Vector2i] = []
	var curr: Vector2i = goal
	while curr != start:
		path.push_front(curr)
		curr = came_from[curr]
	path.push_front(start)
	return path

static func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return float(abs(a.x - b.x) + abs(a.y - b.y))
