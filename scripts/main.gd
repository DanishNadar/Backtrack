extends Node2D
## One night = one maze. Fog of war, no turning back, random backtracks,
## a restricted shortcut offered when you're thrown back to the start,
## and the Ragebait Road: a corridor that never ends.
##
## Colour code: Purple = Puzzle, Green = Go, Red = Restricted, Blue = Ragebait Road.

const BACKTRACK_MIN := 8.0          # seconds between backtracks (random in range)
const BACKTRACK_MAX := 15.0
const RESET_TO_START_CHANCE := 0.1  # chance a backtrack sends you all the way back
const SHORTCUT_WINDOW := 5.0        # seconds the restricted shortcut stays open
const SHORTCUT_PROGRESS := 0.8      # how far along the solution it drops you
const NO_REVERSE := true            # can't walk back the way you came; wait for a backtrack
const ROAD_DIR := MazeGenerator.E   # the Ragebait Road leaves the maze through the east wall
const CELL_SIZE := 44.0             # pixels per maze cell; the camera scrolls large maps
const CAMERA_MARGIN := 40.0         # screen space kept around the maze edges (HUD / legend)

const KEY_DIRS := {
	KEY_UP: MazeGenerator.N, KEY_W: MazeGenerator.N,
	KEY_RIGHT: MazeGenerator.E, KEY_D: MazeGenerator.E,
	KEY_DOWN: MazeGenerator.S, KEY_S: MazeGenerator.S,
	KEY_LEFT: MazeGenerator.W, KEY_A: MazeGenerator.W,
}

const ROAD_HINTS: Array[String] = [
	"The light is getting closer.",
	"Almost there.",
	"Just a little further.",
	"You can feel it. Keep going.",
	"This has to be it.",
	"Any second now.",
]

# Purple = Puzzle (the maze floor, a dark gradient across the brain)
const COLOR_FLOOR_A := Color(0.08, 0.025, 0.14)
const COLOR_FLOOR_B := Color(0.16, 0.04, 0.24)
# Brain-tissue pink for the folds (walls)
const COLOR_WALL := Color(1.0, 0.55, 0.72)
# Green = Go
const COLOR_GO := Color(0.35, 1.0, 0.55)
# Red = Restricted
const COLOR_RESTRICTED := Color(1.0, 0.2, 0.25)
# Blue = Ragebait Road
const COLOR_ROAD_A := Color(0.05, 0.12, 0.35)
const COLOR_ROAD_B := Color(0.15, 0.35, 0.9)
const COLOR_START := Color(0.8, 0.7, 1.0)
const COLOR_BUTTERFLY := Color(1.0, 0.95, 0.9)

enum Mode { PLAYING, MEMORY, FADED }

var rng := RandomNumberGenerator.new()
var mode := Mode.PLAYING
var maze: Array = []
var size := Vector2i.ZERO
var cell := CELL_SIZE
var origin := Vector2.ZERO
var start := Vector2i.ZERO
var goal := Vector2i.ZERO
var road_entrance := Vector2i(-1, -1)
var player := Vector2i.ZERO
var came_from := Vector2i(-1, -1)
var history: Array[Vector2i] = []
var solution: Array[Vector2i] = []
var visible_cells := {}
var on_road := false
var road_steps := 0
var road_scroll := 0.0
var backtrack_timer := 0.0
var shortcut_timer := 0.0
var flash := 0.0
var hint := ""
var hint_timer := 0.0
var time := 0.0

@onready var hud: Label = $UI/HUD
@onready var overlay: ColorRect = $UI/Overlay
@onready var overlay_text: Label = $UI/Overlay/Text


func _ready() -> void:
	rng.randomize()
	start_night()


func start_night() -> void:
	var n := GameState.night
	size = Vector2i(mini(24 + n * 6, 90), mini(14 + n * 3, 50))
	maze = MazeGenerator.generate(size, rng)
	start = Vector2i.ZERO
	goal = size - Vector2i.ONE
	solution = MazeGenerator.solve(maze, size, start, goal)
	# Tempting spot on the east edge, away from the goal row.
	road_entrance = Vector2i(size.x - 1, rng.randi_range(size.y / 3, size.y - 3))
	player = start
	came_from = Vector2i(-1, -1)
	history = [start]
	on_road = false
	road_steps = 0
	GameState.cheats_this_night = 0
	shortcut_timer = 0.0
	backtrack_timer = rng.randf_range(BACKTRACK_MIN, BACKTRACK_MAX)
	mode = Mode.PLAYING
	overlay.visible = false
	_update_camera(0.0, true)
	_update_visibility()
	_show_hint("Night %d. Find the green light." % n)


## Maps are bigger than the screen, so `origin` pans to keep the butterfly
## centred, clamped so the view never drifts far past the maze edges.
func _update_camera(delta: float, snap := false) -> void:
	var vp := get_viewport_rect().size
	var maze_px := Vector2(size) * cell
	var target := vp / 2.0 - (Vector2(player) + Vector2(0.5, 0.5)) * cell
	var lo := vp - maze_px - Vector2(CAMERA_MARGIN, CAMERA_MARGIN + 8.0)
	var hi := Vector2(CAMERA_MARGIN, CAMERA_MARGIN + 16.0)
	for axis in 2:
		if maze_px[axis] <= vp[axis] - 2.0 * CAMERA_MARGIN:
			target[axis] = (vp[axis] - maze_px[axis]) / 2.0
		else:
			target[axis] = clampf(target[axis], lo[axis], hi[axis])
	origin = target if snap else origin.lerp(target, minf(1.0, delta * 8.0))


func _process(delta: float) -> void:
	time += delta
	flash = maxf(0.0, flash - delta)
	hint_timer = maxf(0.0, hint_timer - delta)
	road_scroll = lerpf(road_scroll, road_steps, minf(1.0, delta * 10.0))
	_update_camera(delta)
	if mode == Mode.PLAYING:
		backtrack_timer -= delta
		if backtrack_timer <= 0.0:
			_backtrack()
			backtrack_timer = rng.randf_range(BACKTRACK_MIN, BACKTRACK_MAX)
		shortcut_timer = maxf(0.0, shortcut_timer - delta)
	_update_hud()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var key: Key = event.keycode
	match mode:
		Mode.PLAYING:
			if KEY_DIRS.has(key):
				if on_road:
					_walk_road(KEY_DIRS[key])
				else:
					_try_move(KEY_DIRS[key])
			elif key == KEY_SPACE and shortcut_timer > 0.0:
				_take_shortcut()
		Mode.MEMORY:
			if key in [KEY_ENTER, KEY_SPACE] and not event.echo:
				GameState.night += 1
				start_night()
		Mode.FADED:
			if key in [KEY_ENTER, KEY_SPACE] and not event.echo:
				GameState.reset()
				start_night()


func _try_move(dir: int) -> void:
	if player == road_entrance and dir == ROAD_DIR:
		on_road = true
		road_steps = 0
		road_scroll = 0.0
		_show_hint("A long, straight road. The light must be at the end of it.")
		return
	if not (maze[player.y][player.x] & dir):
		return
	var target: Vector2i = player + MazeGenerator.DIRS[dir]
	if NO_REVERSE and target == came_from:
		_show_hint("You can't turn back. Wait for the backtrack.")
		return
	came_from = player
	player = target
	history.append(player)
	_update_visibility()
	if player == goal:
		_complete_night()


## The road only goes one way, and it never arrives.
func _walk_road(dir: int) -> void:
	if dir != ROAD_DIR:
		_show_hint("There's only forward now.")
		return
	road_steps += 1
	if road_steps % 6 == 0:
		_show_hint(ROAD_HINTS[rng.randi_range(0, ROAD_HINTS.size() - 1)])


## Throw the player back a random distance along the path they actually walked.
func _backtrack() -> void:
	var was_on_road := on_road
	if on_road:
		on_road = false
		_show_hint("The road dissolves after %d steps. It was never going anywhere." % road_steps)
	if history.size() <= 1:
		flash = 0.6
		return
	var to_start := rng.randf() < RESET_TO_START_CHANCE or history.size() == 2
	var idx := 0 if to_start else rng.randi_range(1, history.size() - 2)
	var steps := history.size() - 1 - idx
	history.resize(idx + 1)
	player = history[idx]
	came_from = Vector2i(-1, -1)
	flash = 0.6
	if to_start:
		shortcut_timer = SHORTCUT_WINDOW
		_show_hint("Back to the start... a restricted path flickers open. [SPACE]")
	elif not was_on_road:
		_show_hint("You stumble back %d step%s." % [steps, "" if steps == 1 else "s"])
	_update_visibility()


func _take_shortcut() -> void:
	shortcut_timer = 0.0
	GameState.cheats_this_night += 1
	var i := clampi(int(solution.size() * SHORTCUT_PROGRESS), 0, solution.size() - 2)
	history.assign(solution.slice(0, i + 1))
	player = solution[i]
	came_from = Vector2i(-1, -1)
	flash = 0.6
	_show_hint("You skipped ahead. Something in you grows fainter.")
	_update_visibility()


func _complete_night() -> void:
	var cheats := GameState.cheats_this_night
	GameState.strength = clampf(
		GameState.strength + GameState.GAIN_PER_NIGHT - cheats * GameState.CHEAT_PENALTY, 0.0, 1.0)
	overlay.visible = true
	if GameState.strength <= 0.0:
		mode = Mode.FADED
		overlay_text.text = "You faded away.\n\nYou tried to skip the human connection and the learning process, and faded into irrelevancy.\nYour daughter pulled the plug. You were a lost cause.\n\n[ENTER] Wake up again"
		return
	mode = Mode.MEMORY
	var status := "Your lines grow stronger." if cheats == 0 else "You cheated %d time%s. You wake up fainter." % [cheats, "" if cheats == 1 else "s"]
	overlay_text.text = "%s\n\n%s\nLine strength: %d%%\n\n[ENTER] Sleep again" % [
		GameState.memory_for(GameState.night), status, roundi(GameState.strength * 100)]


## You see your own cell plus straight lines of sight down each open corridor.
func _update_visibility() -> void:
	visible_cells.clear()
	visible_cells[player] = true
	for d in MazeGenerator.DIRS:
		var c := player
		while maze[c.y][c.x] & d:
			c += MazeGenerator.DIRS[d]
			visible_cells[c] = true


func _show_hint(text: String) -> void:
	hint = text
	hint_timer = 3.5


func _update_hud() -> void:
	var line := "Night %d   |   Line strength %d%%   |   Restricted uses tonight: %d" % [
		GameState.night, roundi(GameState.strength * 100), GameState.cheats_this_night]
	if hint_timer > 0.0:
		line += "      " + hint
	hud.text = line


func _cell_center(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	for c in visible_cells:
		_draw_cell(c)
	_draw_cell(start)
	_draw_cell(goal)

	var pulse := 0.5 + 0.5 * sin(time * 3.0)
	var g := _cell_center(goal)
	draw_circle(g, cell * (0.55 + 0.15 * pulse), Color(COLOR_GO, 0.15))
	draw_circle(g, cell * (0.28 + 0.06 * pulse), COLOR_GO)
	draw_arc(_cell_center(start), cell * 0.3, 0.0, TAU, 24, COLOR_START, 2.0)
	if shortcut_timer > 0.0:
		var r := Rect2(origin + Vector2(start) * cell, Vector2(cell, cell)).grow(-cell * 0.1)
		draw_rect(r, Color(COLOR_RESTRICTED, 0.3 + 0.4 * pulse))
		draw_rect(r, COLOR_RESTRICTED, false, 2.0)
	if visible_cells.has(road_entrance):
		_draw_road_mouth(pulse)

	if on_road:
		_draw_road()
	else:
		_draw_butterfly(_cell_center(player), cell)
		_draw_goal_pointer(pulse)

	_draw_legend()
	if flash > 0.0:
		draw_rect(get_viewport_rect(), Color(1, 1, 1, flash * 0.5))


## The exit is always "visible": when it's off-screen, a green arrow on the
## screen edge points toward it.
func _draw_goal_pointer(pulse: float) -> void:
	var vp := get_viewport_rect().size
	var g := _cell_center(goal)
	var area := Rect2(Vector2.ZERO, vp).grow(-CAMERA_MARGIN)
	if area.has_point(g):
		return
	var center := vp / 2.0
	var dir := (g - center).normalized()
	# Scale the direction until it hits the edge of the inner area.
	var reach := minf(
		absf(area.size.x / 2.0 / dir.x) if dir.x != 0.0 else INF,
		absf(area.size.y / 2.0 / dir.y) if dir.y != 0.0 else INF)
	var tip := center + dir * reach
	var side := dir.orthogonal() * 9.0
	draw_colored_polygon(PackedVector2Array([tip, tip - dir * 22.0 + side, tip - dir * 22.0 - side]),
		Color(COLOR_GO, 0.6 + 0.4 * pulse))


func _floor_color(pt: Vector2) -> Color:
	var t := (pt - origin) / (Vector2(size) * cell)
	return COLOR_FLOOR_A.lerp(COLOR_FLOOR_B, clampf((t.x + t.y) * 0.5, 0.0, 1.0))


func _draw_cell(c: Vector2i) -> void:
	var p := origin + Vector2(c) * cell
	var tl := p
	var tr := p + Vector2(cell, 0)
	var bl := p + Vector2(0, cell)
	var br := p + Vector2(cell, cell)
	var corners := PackedVector2Array([tl, tr, br, bl])
	if c == road_entrance:
		draw_polygon(corners, PackedColorArray([COLOR_ROAD_A, COLOR_ROAD_B, COLOR_ROAD_B, COLOR_ROAD_A]))
	else:
		draw_polygon(corners, PackedColorArray(
			[_floor_color(tl), _floor_color(tr), _floor_color(br), _floor_color(bl)]))
	var bits: int = maze[c.y][c.x]
	if c == road_entrance:
		bits |= ROAD_DIR
	if not (bits & MazeGenerator.N): _draw_fold(tl, tr)
	if not (bits & MazeGenerator.E): _draw_fold(tr, br)
	if not (bits & MazeGenerator.S): _draw_fold(bl, br)
	if not (bits & MazeGenerator.W): _draw_fold(tl, bl)


## A wall drawn as a soft, wobbly brain fold. Wobble depends only on world
## position, so a wall shared by two cells looks identical from both sides.
func _draw_fold(a: Vector2, b: Vector2, color := COLOR_WALL) -> void:
	var normal := (b - a).orthogonal().normalized()
	var phase := (a.x * 0.037 + a.y * 0.053)
	var amp := (b - a).length() * 0.07
	var pts := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		pts.append(a.lerp(b, t) + normal * amp * sin(t * TAU * 1.5 + phase) * sin(t * PI))
	draw_polyline(pts, Color(color, 0.18), 7.0, true)
	draw_polyline(pts, color, 2.5, true)


## A glimpse of the road from inside the maze: a blue opening fading off-screen.
func _draw_road_mouth(pulse: float) -> void:
	var p := origin + Vector2(road_entrance) * cell + Vector2(cell, 0)
	var length := cell * 3.0
	var clear := Color(COLOR_ROAD_B, 0.0)
	draw_polygon(
		PackedVector2Array([p, p + Vector2(length, 0), p + Vector2(length, cell), p + Vector2(0, cell)]),
		PackedColorArray([COLOR_ROAD_B, clear, clear, COLOR_ROAD_B]))
	draw_circle(p + Vector2(length * 0.6, cell * 0.5), cell * 0.12, Color(COLOR_GO, 0.25 + 0.25 * pulse))


## Full-screen view of the endless road. The green light always stays ahead.
func _draw_road() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.88))
	var tile := 80.0
	var top := vp.y * 0.5 - 60.0
	var bottom := vp.y * 0.5 + 60.0
	var offset := fmod(road_scroll * tile, tile)
	for i in range(-1, int(vp.x / tile) + 2):
		var x0 := i * tile - offset
		var x1 := x0 + tile
		var fade0 := Color(COLOR_ROAD_A.lerp(COLOR_ROAD_B, 0.5), 1.0 - clampf(x0 / vp.x, 0.0, 1.0))
		var fade1 := Color(COLOR_ROAD_A.lerp(COLOR_ROAD_B, 0.5), 1.0 - clampf(x1 / vp.x, 0.0, 1.0))
		draw_polygon(
			PackedVector2Array([Vector2(x0, top), Vector2(x1, top), Vector2(x1, bottom), Vector2(x0, bottom)]),
			PackedColorArray([fade0, fade1, fade1, fade0]))
		draw_line(Vector2(x0, top), Vector2(x0, bottom), Color(COLOR_ROAD_B, 0.25 * fade0.a), 1.0)
		var wall := Color(COLOR_WALL, fade0.a)
		_draw_fold(Vector2(x0, top), Vector2(x1, top), wall)
		_draw_fold(Vector2(x0, bottom), Vector2(x1, bottom), wall)
	var pulse := 0.5 + 0.5 * sin(time * 2.0)
	draw_circle(Vector2(vp.x - 70.0, vp.y * 0.5), 10.0 + 4.0 * pulse, Color(COLOR_GO, 0.35 + 0.3 * pulse))
	_draw_butterfly(Vector2(220.0, vp.y * 0.5), 64.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0, top - 24.0), "RAGEBAIT ROAD   ·   %d steps in" % road_steps,
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, 22, COLOR_ROAD_B.lightened(0.4))


func _draw_legend() -> void:
	var font := ThemeDB.fallback_font
	var entries := [["Puzzle", COLOR_FLOOR_B.lightened(0.25)], ["Go", COLOR_GO],
		["Restricted", COLOR_RESTRICTED], ["Ragebait Road", COLOR_ROAD_B]]
	var vp := get_viewport_rect().size
	var x := 16.0
	var y := vp.y - 14.0
	for e in entries:
		draw_rect(Rect2(x, y - 11.0, 12.0, 12.0), e[1])
		x += 18.0
		draw_string(font, Vector2(x, y), e[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.75))
		x += font.get_string_size(e[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 24.0


## Glow and wing opacity scale with line strength.
func _draw_butterfly(p: Vector2, unit: float) -> void:
	var s := GameState.strength
	var alpha := lerpf(0.15, 1.0, s)
	var color := Color(COLOR_BUTTERFLY, alpha)
	draw_circle(p, unit * lerpf(0.4, 1.2, s), Color(COLOR_BUTTERFLY, 0.12 * alpha))
	var flap := 0.6 + 0.4 * absf(sin(time * 8.0))
	var u := unit * 0.4
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			p, p + Vector2(side * u * flap, -u * 0.9), p + Vector2(side * u * flap * 0.9, -u * 0.1)]), color)
		draw_colored_polygon(PackedVector2Array([
			p, p + Vector2(side * u * flap * 0.7, u * 0.7), p + Vector2(side * u * flap * 0.8, u * 0.1)]), color)
	draw_line(p + Vector2(0, -u * 0.5), p + Vector2(0, u * 0.5), Color(1, 1, 1, alpha), 2.0)
