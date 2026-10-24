extends Control
## A hospital-room cutscene with placeholder stick figures. Plays a list of
## beats from story.gd: each shows a caption (Enter, Space or a click goes to
## the next) and may trigger an event: "cry" makes everyone weep, and
## "doctor_butterflies" / "daughter_butterflies" dissolve that character into a
## swarm of small Demens.

signal finished

const FIGURE_HEIGHT := 190.0
const LINE_WIDTH := 4.0
const SWARM_SIZE := 18
const BUTTERFLY_SCALE := 0.32
const VANISH_TIME := 0.8         # seconds for a figure to fade into its swarm
const TEAR_INTERVAL := 0.35
const LYING_SCALE := 0.75      # Demen is drawn a little smaller in bed

const COLOR_BG := Color(0.03, 0.03, 0.06)
const COLOR_FLOOR := Color(0.25, 0.22, 0.3)
const COLOR_BED := Color(0.55, 0.6, 0.75)
const COLOR_DEMEN := Color(0.55, 0.85, 1.0)
const COLOR_DOCTOR := Color(0.95, 0.95, 0.95)
const COLOR_DAUGHTER := Color(1.0, 0.55, 0.8)
const COLOR_TEAR := Color(0.45, 0.75, 1.0)
const COLOR_CAPTION := Color(1.0, 0.85, 0.25)

## Set by main.gd: Demen's sprite (with its background removed).
var demen: Texture2D

var _beats: Array = []
var _index := 0
var _lying := true           # Demen in bed (awakening) or sitting up (finale)
var _crying := false
var _time := 0.0
var _tear_timer := 0.0
var _tears: Array = []       # [position, velocity]
var _butterflies: Array = [] # [position, velocity, phase]
var _alpha := {"doctor": 1.0, "daughter": 1.0}
var _vanishing := {}
var _rng := RandomNumberGenerator.new()
var _scene := ""
var _voice := AudioStreamPlayer.new()


func _ready() -> void:
	visible = false
	add_child(_voice)


## Plays `beats`; Demen lies in bed if `lying`, otherwise sits up. `scene`
## names the cutscene's voice lines (see Voice.beat_id).
func play(beats: Array, lying: bool, scene: String) -> void:
	_beats = beats
	_scene = scene
	_lying = lying
	_index = 0
	_crying = false
	_tears.clear()
	_butterflies.clear()
	_alpha = {"doctor": 1.0, "daughter": 1.0}
	_vanishing.clear()
	_rng.randomize()
	visible = true
	_start_beat()


func _start_beat() -> void:
	_voice.stream = Voice.load_line(Voice.beat_id(_scene, _index, _beats[_index]))
	if _voice.stream:
		_voice.play()
	match _beats[_index].get("event", ""):
		"cry":
			_crying = true
		"doctor_butterflies":
			_vanish("doctor")
		"daughter_butterflies":
			_vanish("daughter")


func _vanish(who: String) -> void:
	_vanishing[who] = true
	var center := _figure_pos(who) + Vector2(0, -FIGURE_HEIGHT * 0.5)
	for i in SWARM_SIZE:
		var p := center + Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-80, 80))
		var v := Vector2(_rng.randf_range(-90, 90), _rng.randf_range(-160, -50))
		_butterflies.append([p, v, _rng.randf() * TAU])


func _advance() -> void:
	_voice.stop()
	_index += 1
	if _index >= _beats.size():
		visible = false
		finished.emit()
	else:
		_start_beat()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var next: bool = (event is InputEventKey and event.pressed and not event.echo
		and event.keycode in [KEY_ENTER, KEY_SPACE]) \
		or (event is InputEventMouseButton and event.pressed)
	if next:
		get_viewport().set_input_as_handled()
		_advance()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	for who in _vanishing:
		_alpha[who] = maxf(0.0, _alpha[who] - delta / VANISH_TIME)
	for b in _butterflies:
		b[1].y -= 20.0 * delta
		b[0] += (b[1] + Vector2(sin(_time * 6.0 + b[2]) * 60.0, 0)) * delta
	if _crying:
		_tear_timer -= delta
		if _tear_timer <= 0.0:
			_tear_timer = TEAR_INTERVAL
			for who in ["demen", "doctor", "daughter"]:
				if who == "demen" or _alpha[who] > 0.5:
					for side in [-1.0, 1.0]:
						_tears.append([_eye_pos(who, side), Vector2(side * 20.0, 0)])
		for t in _tears:
			t[1].y += 500.0 * delta
			t[0] += t[1] * delta
		_tears = _tears.filter(func(t): return t[0].y < size.y)
	queue_redraw()


# --- Layout ------------------------------------------------------------------

func _floor_y() -> float:
	return size.y * 0.72


func _bed_rect() -> Rect2:
	return Rect2(size.x * 0.2, _floor_y() - 70.0, 300.0, 70.0)


## Feet position of a standing figure.
func _figure_pos(who: String) -> Vector2:
	match who:
		"doctor": return Vector2(size.x * 0.68, _floor_y())
		"daughter": return Vector2(size.x * 0.54, _floor_y())
	return Vector2.ZERO


func _head_pos(who: String) -> Vector2:
	if who == "demen":
		var bed := _bed_rect()
		if _lying:
			return _lying_feet() + Vector2(-FIGURE_HEIGHT * LYING_SCALE * 0.88, 0)
		return _seat() + Vector2(0, -FIGURE_HEIGHT * 0.48)
	return _figure_pos(who) + Vector2(0, -FIGURE_HEIGHT * 0.88)


func _lying_feet() -> Vector2:
	var bed := _bed_rect()
	return Vector2(bed.end.x - 30.0, bed.position.y - 18.0)


func _seat() -> Vector2:
	var bed := _bed_rect()
	return Vector2(bed.end.x - FIGURE_HEIGHT * 0.2 + 2.0, bed.position.y)  # knees just past the edge


func _eye_pos(who: String, side: float) -> Vector2:
	return _head_pos(who) + Vector2(side * 8.0, 2.0)


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	draw_line(Vector2(0, _floor_y()), Vector2(size.x, _floor_y()), COLOR_FLOOR, 3.0)
	# A window with a few stars, to say "night, hospital".
	var window := Rect2(size.x * 0.78, size.y * 0.14, 160.0, 120.0)
	draw_rect(window, Color(0.08, 0.1, 0.2))
	draw_rect(window, COLOR_FLOOR, false, 3.0)

	var bed := _bed_rect()
	draw_rect(bed, Color(COLOR_BED, 0.35))
	draw_rect(bed, COLOR_BED, false, 3.0)
	draw_line(bed.position, bed.position + Vector2(0, -60), COLOR_BED, 4.0)

	if _lying:
		_draw_stick(_lying_feet(), -PI / 2.0, COLOR_DEMEN, 1.0, LYING_SCALE)
	else:
		_draw_sitting(_seat(), COLOR_DEMEN)
	_draw_name("Demen", _head_pos("demen") + Vector2(0, -40), COLOR_DEMEN, 1.0)

	for who in ["daughter", "doctor"]:
		var color := COLOR_DOCTOR if who == "doctor" else COLOR_DAUGHTER
		_draw_stick(_figure_pos(who), 0.0, color, _alpha[who], 1.0 if who == "doctor" else 0.85)
		_draw_name(who.capitalize(), _figure_pos(who) + Vector2(0, 28), color, _alpha[who])

	for t in _tears:
		draw_circle(t[0], 3.5, COLOR_TEAR)
	for b in _butterflies:
		_draw_butterfly(b[0], b[2])

	_draw_caption()


## A standing stick figure with its feet at `feet`, rotated by `angle`.
func _draw_stick(feet: Vector2, angle: float, color: Color, alpha: float, scale_: float) -> void:
	if alpha <= 0.0:
		return
	var c := Color(color, alpha)
	var h := FIGURE_HEIGHT * scale_
	draw_set_transform(feet, angle, Vector2.ONE)
	var head := Vector2(0, -h * 0.88)
	draw_arc(head, h * 0.1, 0.0, TAU, 24, c, LINE_WIDTH, true)
	draw_line(Vector2(0, -h * 0.78), Vector2(0, -h * 0.4), c, LINE_WIDTH, true)
	draw_line(Vector2(0, -h * 0.4), Vector2(-h * 0.14, 0), c, LINE_WIDTH, true)
	draw_line(Vector2(0, -h * 0.4), Vector2(h * 0.14, 0), c, LINE_WIDTH, true)
	draw_line(Vector2(0, -h * 0.7), Vector2(-h * 0.2, -h * 0.45), c, LINE_WIDTH, true)
	draw_line(Vector2(0, -h * 0.7), Vector2(h * 0.2, -h * 0.45), c, LINE_WIDTH, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Demen sitting up on the edge of the bed, legs over the side.
func _draw_sitting(seat: Vector2, color: Color) -> void:
	var h := FIGURE_HEIGHT
	var hip := seat
	var neck := hip + Vector2(0, -h * 0.38)
	draw_arc(_head_pos("demen"), h * 0.1, 0.0, TAU, 24, color, LINE_WIDTH, true)
	draw_line(neck, hip, color, LINE_WIDTH, true)
	draw_line(hip, hip + Vector2(h * 0.2, 0), color, LINE_WIDTH, true)
	draw_line(hip + Vector2(h * 0.2, 0), hip + Vector2(h * 0.2, h * 0.36), color, LINE_WIDTH, true)
	draw_line(neck + Vector2(0, h * 0.08), neck + Vector2(h * 0.18, h * 0.22), color, LINE_WIDTH, true)
	draw_line(neck + Vector2(0, h * 0.08), neck + Vector2(-h * 0.14, h * 0.25), color, LINE_WIDTH, true)


func _draw_name(text: String, at: Vector2, color: Color, alpha: float) -> void:
	if alpha <= 0.0:
		return
	draw_string(ThemeDB.fallback_font, at - Vector2(100, 0), text,
		HORIZONTAL_ALIGNMENT_CENTER, 200, 16, Color(color, 0.8 * alpha))


func _draw_butterfly(p: Vector2, phase: float) -> void:
	if demen == null:
		return
	var flap := 0.55 + 0.45 * absf(sin(_time * 10.0 + phase))
	draw_set_transform(p, 0.0, Vector2(BUTTERFLY_SCALE * flap, BUTTERFLY_SCALE))
	draw_texture(demen, -demen.get_size() / 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_caption() -> void:
	var beat: Dictionary = _beats[_index]
	var text: String = beat.text
	if beat.has("speaker"):
		text = "%s: \"%s\"" % [beat.speaker, beat.text]
	var font := ThemeDB.fallback_font
	var big := text == "THE END"
	draw_multiline_string(font, Vector2(size.x * 0.1, size.y * 0.84), text,
		HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.8, 44 if big else 26, -1, COLOR_CAPTION)
	draw_string(font, Vector2(0, size.y - 16.0), "Enter: continue",
		HORIZONTAL_ALIGNMENT_RIGHT, size.x - 16.0, 14, Color(1, 1, 1, 0.4))
