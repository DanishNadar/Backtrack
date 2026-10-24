extends Control
## Simon Says, started by the bell tumor and drawn on public/assets/simonSays.png.
## The left (black) board plays a sequence; repeat it on the right (pink) board
## by clicking it or with Q W E / A S D / Z X C. One round of SEQUENCE_LENGTH
## steps; a wrong note replays the same sequence. Dots above the left board count
## steps shown; dots above the right board count steps entered.

signal mistake
signal finished

const ART: Texture2D = preload("res://public/assets/simonSays.png")
const SEQUENCE_LENGTH := 5  # one dot per step above each board
const START_DELAY := 0.8   # pause before a sequence plays
const SHOW_TIME := 0.45    # how long each cell stays lit
const GAP_TIME := 0.15
const PRESS_FLASH := 0.2
const END_DELAY := 1.4     # time to read the result before closing

# Board geometry in the art's pixel coordinates: cell boundary lines.
const LEFT_COLS := [90, 156, 248, 312]
const LEFT_ROWS := [149, 218, 308, 390]
const RIGHT_COLS := [518, 587, 664, 736]
const RIGHT_ROWS := [144, 223, 315, 399]
const LEFT_DOTS := [Vector2(110, 101), Vector2(155, 99), Vector2(203, 98), Vector2(251, 100), Vector2(295, 100)]
const RIGHT_DOTS := [Vector2(537, 98), Vector2(583, 100), Vector2(631, 101), Vector2(672, 101), Vector2(716, 98)]

const KEYS := [KEY_Q, KEY_W, KEY_E, KEY_A, KEY_S, KEY_D, KEY_Z, KEY_X, KEY_C]

const COLOR_LIT := Color(1.0, 0.55, 0.85)
const COLOR_PRESS := Color(0.55, 0.0, 0.0, 0.6)
const COLOR_DOT := Color(1.0, 0.85, 0.25)

enum Phase { IDLE, SHOWING, INPUT, DONE }

var phase := Phase.IDLE
var rng := RandomNumberGenerator.new()
var sequence: Array[int] = []
var entered := 0
var show_index := 0
var timer := 0.0
var lit_left := -1
var lit_right := -1
var press_timer := 0.0
var message := ""

@onready var press_sound: AudioStreamPlayer = $PressSound


func start() -> void:
	rng.randomize()
	sequence.clear()
	for i in SEQUENCE_LENGTH:
		sequence.append(rng.randi_range(0, 8))
	visible = true
	_play_sequence("Watch the black board...")


func stop() -> void:
	visible = false
	phase = Phase.IDLE


func _play_sequence(text: String) -> void:
	phase = Phase.SHOWING
	message = text
	entered = 0
	show_index = 0
	lit_left = -1
	timer = START_DELAY


func _process(delta: float) -> void:
	if not visible:
		return
	press_timer = maxf(0.0, press_timer - delta)
	if press_timer <= 0.0:
		lit_right = -1
	timer -= delta
	if timer <= 0.0:
		match phase:
			Phase.SHOWING:
				if lit_left >= 0:
					lit_left = -1
					timer = GAP_TIME
				elif show_index < sequence.size():
					lit_left = sequence[show_index]
					show_index += 1
					timer = SHOW_TIME
				else:
					phase = Phase.INPUT
					message = "Your turn. Repeat it on the pink board."
			Phase.DONE:
				stop()
				finished.emit()
	queue_redraw()


func _press(cell: int) -> void:
	if phase != Phase.INPUT:
		return
	lit_right = cell
	press_timer = PRESS_FLASH
	press_sound.play()
	if cell != sequence[entered]:
		_play_sequence("Wrong note. Watch again...")
		# Emitted last so listeners can replace the message (or stop the game).
		mistake.emit()
		return
	entered += 1
	if entered < sequence.size():
		return
	phase = Phase.DONE
	timer = END_DELAY
	message = "The bell falls silent. A pattern remembered."


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _cell_at(_to_art(event.position), RIGHT_COLS, RIGHT_ROWS)
		if cell >= 0:
			_press(cell)
		accept_event()


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var cell := KEYS.find(event.keycode)
	if cell >= 0:
		_press(cell)
		get_viewport().set_input_as_handled()


# --- Layout ------------------------------------------------------------------

## Leaves room for the game HUD along the top edge.
func _art_scale() -> float:
	return minf((size.x - 80.0) / ART.get_width(), (size.y - 200.0) / ART.get_height())


func _art_offset() -> Vector2:
	return (size - ART.get_size() * _art_scale()) / 2.0 + Vector2(0, 20)


func _to_art(p: Vector2) -> Vector2:
	return (p - _art_offset()) / _art_scale()


func _from_art(p: Vector2) -> Vector2:
	return _art_offset() + p * _art_scale()


func _cell_rect(cell: int, cols: Array, rows: Array) -> Rect2:
	var x := cell % 3
	var y := cell / 3
	var a := _from_art(Vector2(cols[x], rows[y]))
	var b := _from_art(Vector2(cols[x + 1], rows[y + 1]))
	return Rect2(a, b - a)


func _cell_at(p: Vector2, cols: Array, rows: Array) -> int:
	for y in 3:
		for x in 3:
			if p.x >= cols[x] and p.x < cols[x + 1] and p.y >= rows[y] and p.y < rows[y + 1]:
				return y * 3 + x
	return -1


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.8))
	var s := _art_scale()
	draw_texture_rect(ART, Rect2(_art_offset(), ART.get_size() * s), false)

	if lit_left >= 0:
		draw_rect(_cell_rect(lit_left, LEFT_COLS, LEFT_ROWS).grow(-4.0 * s), COLOR_LIT)
	if lit_right >= 0:
		draw_rect(_cell_rect(lit_right, RIGHT_COLS, RIGHT_ROWS).grow(-3.0 * s), COLOR_PRESS)

	for i in SEQUENCE_LENGTH:
		if i < show_index:
			draw_circle(_from_art(LEFT_DOTS[i]), 11.0 * s, COLOR_DOT)
		if i < entered:
			draw_circle(_from_art(RIGHT_DOTS[i]), 14.0 * s, COLOR_DOT)

	var font := ThemeDB.fallback_font
	var top := _art_offset().y
	var bottom := top + ART.get_height() * s
	draw_string(font, Vector2(0, top - 40.0), "SIMON SAYS",
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color.WHITE)
	draw_string(font, Vector2(0, bottom + 40.0), message,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, COLOR_LIT)
	draw_string(font, Vector2(0, bottom + 66.0), "Click the pink board, or use  Q W E  /  A S D  /  Z X C",
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(1, 1, 1, 0.6))
