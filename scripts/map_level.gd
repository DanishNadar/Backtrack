class_name MapLevel
extends RefCounted
## A hand-drawn level. Walls (pink) and secret walls (grey) are read straight
## from the map image's pixels, so the PNG *is* the level. Landmarks are listed
## per map below, in map pixel coordinates.

const MAPS := [
	{
		"image": "res://public/maps/1.png",
		"start": Vector2(66, 38),
		"end": Vector2(989, 89),
		"bell": Vector2(976, 1236),
		"tumors": [
			Vector2(720, 376), Vector2(496, 484), Vector2(908, 608), Vector2(744, 708),
			Vector2(568, 732), Vector2(132, 772), Vector2(564, 1004), Vector2(28, 1480),
		],
		# Walking off this edge of the map leads onto the Ragebait Road.
		"road_edge": SIDE_BOTTOM,
	},
	{
		"image": "res://public/maps/2.png",
		"start": Vector2(33, 36),
		"end": Vector2(1042, 1462),
		"bell": Vector2(284, 1068),
		"tumors": [
			Vector2(860, 120), Vector2(252, 416), Vector2(784, 596),
			Vector2(496, 648), Vector2(808, 924), Vector2(660, 1212),
		],
		"road_edge": SIDE_BOTTOM,
	},
]

const CELL := 5  # collision / line-of-sight resolution, in map pixels
const WALL_CLOSING := 2  # cells; seals the gaps the painted dashes leave in walls
const MIN_SECRET_CELLS := 4  # smaller grey specks are ignored

enum { OPEN, WALL, SECRET }

var texture: Texture2D
var size := Vector2.ZERO
var start := Vector2.ZERO
var end := Vector2.ZERO
var bell := Vector2.ZERO
var tumors: Array = []
var road_edge := SIDE_BOTTOM
var secret_rects: Array[Rect2] = []
var _cols := 0
var _rows := 0
var _cells := PackedByteArray()


## Nights beyond the number of drawn maps cycle back through them.
static func for_night(night: int) -> MapLevel:
	var def: Dictionary = MAPS[(night - 1) % MAPS.size()]
	var level := MapLevel.new()
	level.texture = load(def.image)
	level.size = level.texture.get_size()
	level.start = def.start
	level.end = def.end
	level.bell = def.bell
	level.tumors = def.tumors
	level.road_edge = def.road_edge
	level._build_cells(level.texture.get_image())
	return level


func _build_cells(img: Image) -> void:
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	_cols = ceili(w / float(CELL))
	_rows = ceili(h / float(CELL))
	_cells.resize(_cols * _rows)
	_cells.fill(OPEN)
	var walls := BitMap.new()
	walls.create(Vector2i(_cols, _rows))

	for gy in _rows:
		for gx in _cols:
			var pink := 0
			var grey := 0
			for oy in range(0, CELL, 2):
				for ox in range(0, CELL, 2):
					var i := (mini(gy * CELL + oy, h - 1) * w + mini(gx * CELL + ox, w - 1)) * 4
					var r := data[i]
					var g := data[i + 1]
					var b := data[i + 2]
					if r >= 192 and b >= 144:
						pink += 1
					elif absi(r - g) < 14 and absi(g - b) < 14 and r > 90 and r < 180:
						grey += 1
			if pink >= 3:
				walls.set_bit(gx, gy, true)
			elif grey >= 1:
				_cells[gy * _cols + gx] = SECRET

	# The dark dashes painted across the walls leave see-through gaps. A
	# morphological closing (grow, then shrink) seals gaps narrower than
	# ~2 cells without touching the much wider corridors.
	var rect := Rect2i(Vector2i.ZERO, Vector2i(_cols, _rows))
	walls.grow_mask(WALL_CLOSING, rect)
	walls.grow_mask(-WALL_CLOSING, rect)
	for gy in _rows:
		for gx in _cols:
			if walls.get_bit(gx, gy) and _cells[gy * _cols + gx] == OPEN:
				_cells[gy * _cols + gx] = WALL

	_find_secret_rects()


## Groups secret cells into bars so they can be highlighted as whole shapes.
func _find_secret_rects() -> void:
	var seen := {}
	for gy in _rows:
		for gx in _cols:
			var c := Vector2i(gx, gy)
			if _cells[gy * _cols + gx] != SECRET or seen.has(c):
				continue
			var lo := c
			var hi := c
			var stack: Array[Vector2i] = [c]
			var members: Array[Vector2i] = []
			seen[c] = true
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				members.append(p)
				lo = lo.min(p)
				hi = hi.max(p)
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var q: Vector2i = p + d
					if _in_grid(q) and not seen.has(q) and _cells[q.y * _cols + q.x] == SECRET:
						seen[q] = true
						stack.append(q)
			# Stray grey pixels (e.g. on an icon's outline) aren't secret walls.
			if members.size() < MIN_SECRET_CELLS:
				for p in members:
					_cells[p.y * _cols + p.x] = OPEN
				continue
			secret_rects.append(Rect2(Vector2(lo * CELL), Vector2(hi - lo + Vector2i.ONE) * CELL))


func _in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < _cols and c.y < _rows


## Outside the map is solid, except past the Ragebait Road edge.
func _cell(gx: int, gy: int) -> int:
	if _in_grid(Vector2i(gx, gy)):
		return _cells[gy * _cols + gx]
	match road_edge:
		SIDE_BOTTOM: return OPEN if gy >= _rows and gx >= 0 and gx < _cols else WALL
		SIDE_TOP: return OPEN if gy < 0 and gx >= 0 and gx < _cols else WALL
		SIDE_LEFT: return OPEN if gx < 0 and gy >= 0 and gy < _rows else WALL
		_: return OPEN if gx >= _cols and gy >= 0 and gy < _rows else WALL


func _cells_under(p: Vector2, radius: float) -> Array[int]:
	var found: Array[int] = []
	for gy in range(floori((p.y - radius) / CELL), floori((p.y + radius) / CELL) + 1):
		for gx in range(floori((p.x - radius) / CELL), floori((p.x + radius) / CELL) + 1):
			found.append(_cell(gx, gy))
	return found


func blocked(p: Vector2, radius: float, secret_open: bool) -> bool:
	var cells := _cells_under(p, radius)
	return cells.has(WALL) or (not secret_open and cells.has(SECRET))


func overlaps_secret(p: Vector2, radius: float) -> bool:
	return _cells_under(p, radius).has(SECRET)


func past_road_edge(p: Vector2) -> bool:
	match road_edge:
		SIDE_BOTTOM: return p.y > size.y
		SIDE_TOP: return p.y < 0.0
		SIDE_LEFT: return p.x < 0.0
		_: return p.x > size.x


## Line-of-sight polygon around `origin`: one point per ray, stopping just
## inside the first wall it hits so the wall face itself is lit.
func sight_polygon(origin: Vector2, secret_open: bool, rays: int, reach: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var step := CELL * 0.8
	var bounds := Rect2(Vector2.ZERO, size)
	for i in rays:
		var dir := Vector2.from_angle(TAU * i / rays)
		var d := 0.0
		while d < reach:
			var q := origin + dir * (d + step)
			if not bounds.has_point(q):
				break
			var c := _cell(floori(q.x / CELL), floori(q.y / CELL))
			if c == WALL or (c == SECRET and not secret_open):
				d += CELL
				break
			d += step
		pts.append((origin + dir * d).clamp(Vector2.ZERO, size))
	return pts
