extends Node2D
## Tung Tung: stalks Demen through the final map. Paths around the walls with
## an AStarGrid2D built from the level, and stomps out a footstep (the hit
## sound) with every step, heard louder the closer he is. main.gd decides when
## he's visible (only in line of sight) and when his touch hurts.

const SPEED := 125.0          # pixels per second; Demen (190) can outrun him
const RADIUS := 14.0          # collision size used to find where he fits
const GRID := 10              # pathfinding resolution, in map pixels
const REPATH_TIME := 0.3      # how often the path to Demen is recomputed
const STEP_TIME := 0.42       # seconds between footsteps while walking
const PAUSE_AFTER_HIT := 0.9  # he stands still for a moment after landing a hit
const SCALE := 0.75

const SPRITE: Texture2D = preload("res://public/assets/Tung_Tung-1.png_1.png")

var active := false
var _astar := AStarGrid2D.new()
var _path: PackedVector2Array = []
var _repath_timer := 0.0
var _step_timer := 0.0
var _pause := 0.0
var _time := 0.0
var _walking := false

@onready var footsteps: AudioStreamPlayer2D = $Footsteps


## Builds the walkable grid for `level` and puts him at its spawn point.
func setup(level: MapLevel) -> void:
	active = level.has_tung_tung
	visible = false
	_path.clear()
	if not active:
		return
	var cols := ceili(level.size.x / GRID)
	var rows := ceili(level.size.y / GRID)
	_astar.region = Rect2i(0, 0, cols, rows)
	_astar.cell_size = Vector2(GRID, GRID)
	_astar.offset = Vector2(GRID, GRID) / 2.0
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for y in rows:
		for x in cols:
			if level.blocked(_astar.get_point_position(Vector2i(x, y)), RADIUS, false):
				_astar.set_point_solid(Vector2i(x, y))
	position = level.tung_tung_spawn
	_pause = 0.0


## Called every frame of play with Demen's position.
func chase(target: Vector2, delta: float) -> void:
	_time += delta
	_walking = false
	if _pause > 0.0:
		_pause -= delta
		return
	_repath_timer -= delta
	if _repath_timer <= 0.0 or _path.is_empty():
		_repath_timer = REPATH_TIME
		_path = _astar.get_point_path(_cell_of(position), _cell_of(target), true)
		if not _path.is_empty():
			_path.remove_at(0)  # the cell he's already in
	var goal := target if _path.is_empty() else _path[0]
	var to_goal := goal - position
	var move := SPEED * delta
	if to_goal.length() <= move:
		position = goal
		if not _path.is_empty():
			_path.remove_at(0)
	else:
		position += to_goal.normalized() * move
	_walking = to_goal.length() > 1.0
	if _walking:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = STEP_TIME
			footsteps.play()


## After a hit he stops for a moment so Demen can get away.
func pause_after_hit() -> void:
	_pause = PAUSE_AFTER_HIT


func _cell_of(p: Vector2) -> Vector2i:
	return _astar.region.position + Vector2i((p / GRID).floor()).clamp(
		Vector2i.ZERO, _astar.region.size - Vector2i.ONE)


func _process(_delta: float) -> void:
	if active:
		queue_redraw()


## Bobs up and down while walking.
func _draw() -> void:
	var bob := absf(sin(_time * PI / STEP_TIME)) * 4.0 if _walking else 0.0
	draw_set_transform(Vector2(0, -bob), 0.0, Vector2(SCALE, SCALE))
	draw_texture(SPRITE, -SPRITE.get_size() / 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
