class_name MazeGenerator
extends RefCounted
## Grid maze. Each cell is a bitmask of the directions that are open.

const N := 1
const E := 2
const S := 4
const W := 8
const DIRS := {N: Vector2i(0, -1), E: Vector2i(1, 0), S: Vector2i(0, 1), W: Vector2i(-1, 0)}
const OPPOSITE := {N: S, E: W, S: N, W: E}


## Recursive backtracker, then braided: every dead end is joined to a neighbour,
## so each cell has at least two exits and you can always keep moving without
## turning back. Extra walls are knocked out for more loops and junctions.
static func generate(size: Vector2i, rng: RandomNumberGenerator, loop_chance := 0.12) -> Array:
	var grid := []
	for y in size.y:
		var row := []
		row.resize(size.x)
		row.fill(0)
		grid.append(row)

	var visited := {Vector2i.ZERO: true}
	var stack: Array[Vector2i] = [Vector2i.ZERO]
	while not stack.is_empty():
		var cur: Vector2i = stack.back()
		var options := []
		for d in DIRS:
			var nxt: Vector2i = cur + DIRS[d]
			if in_bounds(nxt, size) and not visited.has(nxt):
				options.append(d)
		if options.is_empty():
			stack.pop_back()
			continue
		var pick: int = options[rng.randi_range(0, options.size() - 1)]
		var target: Vector2i = cur + DIRS[pick]
		grid[cur.y][cur.x] |= pick
		grid[target.y][target.x] |= OPPOSITE[pick]
		visited[target] = true
		stack.append(target)

	_braid(grid, size, rng)

	for y in size.y:
		for x in size.x:
			for d in [E, S]:
				var nxt: Vector2i = Vector2i(x, y) + DIRS[d]
				if in_bounds(nxt, size) and not (grid[y][x] & d) and rng.randf() < loop_chance:
					grid[y][x] |= d
					grid[nxt.y][nxt.x] |= OPPOSITE[d]
	return grid


## Removes every dead end. Prefers opening into another dead end (fixing two at
## once) and otherwise picks a closed wall that turns a corner, not one that
## just extends a straight corridor.
static func _braid(grid: Array, size: Vector2i, rng: RandomNumberGenerator) -> void:
	for y in size.y:
		for x in size.x:
			var bits: int = grid[y][x]
			if _exit_count(bits) != 1:
				continue
			var cur := Vector2i(x, y)
			var dead_ends := []
			var turns := []
			var others := []
			for d in DIRS:
				var nxt: Vector2i = cur + DIRS[d]
				if (bits & d) or not in_bounds(nxt, size):
					continue
				if _exit_count(grid[nxt.y][nxt.x]) == 1:
					dead_ends.append(d)
				elif d != OPPOSITE[bits]:
					turns.append(d)
				else:
					others.append(d)
			var pool: Array = dead_ends if not dead_ends.is_empty() else (turns if not turns.is_empty() else others)
			var pick: int = pool[rng.randi_range(0, pool.size() - 1)]
			var target: Vector2i = cur + DIRS[pick]
			grid[y][x] |= pick
			grid[target.y][target.x] |= OPPOSITE[pick]


static func _exit_count(bits: int) -> int:
	return int(bits & N != 0) + int(bits & E != 0) + int(bits & S != 0) + int(bits & W != 0)


## Shortest path from a to b (BFS), inclusive of both ends.
static func solve(grid: Array, size: Vector2i, a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var prev := {a: a}
	var queue: Array[Vector2i] = [a]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == b:
			break
		for d in DIRS:
			var nxt: Vector2i = cur + DIRS[d]
			if (grid[cur.y][cur.x] & d) and not prev.has(nxt):
				prev[nxt] = cur
				queue.append(nxt)

	var path: Array[Vector2i] = []
	var c := b
	while c != a:
		path.push_front(c)
		c = prev[c]
	path.push_front(a)
	return path


static func in_bounds(c: Vector2i, size: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y
