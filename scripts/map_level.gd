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
	},
	{
		"image": "res://public/maps/3.png",
		"start": Vector2(583, 57),
		"end": Vector2(85, 1394),
		"bell": Vector2(536, 856),
		"tumors": [
			Vector2(728, 176), Vector2(412, 244), Vector2(768, 360), Vector2(560, 404),
			Vector2(356, 496), Vector2(836, 572), Vector2(392, 704), Vector2(620, 788),
			Vector2(336, 896), Vector2(204, 1124), Vector2(336, 1220),
		],
	},
	{
		"image": "res://public/maps/4.png",
		"start": Vector2(70, 1430),
		"end": Vector2(533, 708),
		"bell": Vector2(624, 96),
		"tumors": [
			Vector2(212, 224), Vector2(676, 336), Vector2(784, 476), Vector2(416, 576),
			Vector2(208, 828), Vector2(480, 952), Vector2(920, 944),
		],
	},
	# The final map: no bell, and Tung Tung hunts Demen from the middle.
	{
		"image": "res://public/maps/Final.png",
		"start": Vector2(1038, 1202),
		"end": Vector2(276, 82),
		"tung_tung": Vector2(540, 750),
		"tumors": [
			Vector2(840, 72), Vector2(440, 80), Vector2(64, 120), Vector2(1008, 184),
			Vector2(744, 240), Vector2(992, 280), Vector2(760, 332), Vector2(616, 352),
			Vector2(968, 440), Vector2(712, 480), Vector2(304, 552), Vector2(120, 600),
			Vector2(968, 676), Vector2(176, 708), Vector2(904, 792), Vector2(368, 824),
			Vector2(160, 880), Vector2(676, 912), Vector2(1000, 960), Vector2(216, 984),
			Vector2(820, 1008), Vector2(16, 1060), Vector2(464, 1144), Vector2(584, 1144),
			Vector2(912, 1152), Vector2(320, 1168), Vector2(88, 1220), Vector2(960, 1232),
			Vector2(852, 1312), Vector2(960, 1324), Vector2(196, 1368), Vector2(20, 1372),
			Vector2(640, 1376),
		],
	},
]

const CELL := 5  # collision / line-of-sight resolution, in map pixels
const WALL_CLOSING := 2  # cells; seals the gaps the painted dashes leave in walls
const MIN_SECRET_CELLS := 6  # smaller grey specks (icon outlines) are ignored

enum { OPEN, WALL, SECRET }

var texture: Texture2D
var size := Vector2.ZERO
var start := Vector2.ZERO
var end := Vector2.ZERO
var has_bell := false
var bell := Vector2.ZERO
var has_tung_tung := false
var tung_tung_spawn := Vector2.ZERO
var tumors: Array = []
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
	level.has_bell = def.has("bell")
	level.bell = def.get("bell", Vector2.ZERO)
	level.tumors = def.tumors
	level._build_cells(level.texture.get_image())
	level.has_tung_tung = def.has("tung_tung")
	if level.has_tung_tung:
		level.tung_tung_spawn = level.nearest_open(def.tung_tung, 16.0)
	return level


## The open spot closest to `p` where something of `radius` fits.
func nearest_open(p: Vector2, radius: float) -> Vector2:
	for r in range(0, 400, CELL):
		for i in maxi(1, r):
			var q := p + Vector2.from_angle(TAU * i / maxi(1, r)) * r
			if not blocked(q, radius, false):
				return q
	return p


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


## Outside the map is solid.
func _cell(gx: int, gy: int) -> int:
	if _in_grid(Vector2i(gx, gy)):
		return _cells[gy * _cols + gx]
	return WALL


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


## Line-of-sight polygon around `origin`: one point per ray, stopping a little
## inside the first wall it hits so the wall itself is lit (less for the thin
## grey secret walls, so nothing behind them shows).
func sight_polygon(origin: Vector2, secret_open: bool, rays: int, reach: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var step := CELL * 0.8
	for i in rays:
		var dir := Vector2.from_angle(TAU * i / rays)
		var d := 0.0
		while d < reach:
			var q := origin + dir * (d + step)
			var c := _cell(floori(q.x / CELL), floori(q.y / CELL))
			if c == WALL or (c == SECRET and not secret_open):
				d += CELL * (2 if c == WALL else 1)
				break
			d += step
		pts.append(origin + dir * d)
	return pts
