extends Control
## Star Wars-style text crawl over a starfield. The text is drawn flat into a
## SubViewport, then crawl.gdshader lays it on a plane tilting away from the
## viewer. Enter, Space or a click skips it.

signal finished

const SPEED := 70.0          # texture pixels per second
const TEXT_WIDTH := 900
const TITLE_SIZE := 52
const BODY_SIZE := 38
const TITLE_GAP := 70.0      # space between title and body
const DEPTH_SCALE := 700.0    # text pixels per unit of depth (how steeply the plane recedes)
const TRAIL := 2.0           # depth units the last line travels before the crawl ends
const FADE_OUT := 0.15       # share of the crawl spent fading out at the end
const STARS := 160
const COLOR_TEXT := Color(1.0, 0.85, 0.25)

const SHADER := preload("res://scripts/crawl.gdshader")

var _title := ""
var _body := ""
var _scroll := 0.0
var _end := 1.0
var _stars := PackedVector2Array()
var _viewport: SubViewport
var _page: Control
var _plane: ColorRect


func _ready() -> void:
	visible = false
	var rng := RandomNumberGenerator.new()
	for i in STARS:
		_stars.append(Vector2(rng.randf(), rng.randf()))

	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_page = Control.new()
	_page.draw.connect(_draw_page)
	_viewport.add_child(_page)

	_plane = ColorRect.new()
	_plane.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plane.material = ShaderMaterial.new()
	_plane.material.shader = SHADER
	_plane.material.set_shader_parameter("text_tex", _viewport.get_texture())
	_plane.material.set_shader_parameter("depth_scale", DEPTH_SCALE)
	add_child(_plane)


## Shows a crawl; `finished` is emitted when it has scrolled away or is skipped.
func play(title: String, body: String) -> void:
	_title = title
	_body = body
	var font := ThemeDB.fallback_font
	var height := _title_height() + TITLE_GAP \
		+ font.get_multiline_string_size(_body, HORIZONTAL_ALIGNMENT_FILL, TEXT_WIDTH, BODY_SIZE).y
	_viewport.size = Vector2i(TEXT_WIDTH, ceili(height))
	_page.size = Vector2(_viewport.size)
	_page.queue_redraw()
	_plane.material.set_shader_parameter("tex_size", Vector2(_viewport.size))
	_scroll = 0.0
	_end = height + DEPTH_SCALE * TRAIL
	_plane.modulate.a = 1.0
	visible = true


func _title_height() -> float:
	return ThemeDB.fallback_font.get_multiline_string_size(
		_title, HORIZONTAL_ALIGNMENT_CENTER, TEXT_WIDTH, TITLE_SIZE).y


func _process(delta: float) -> void:
	if not visible:
		return
	_scroll += SPEED * delta
	queue_redraw()  # twinkling stars
	_plane.material.set_shader_parameter("scroll", _scroll)
	var left := 1.0 - _scroll / _end
	_plane.modulate.a = clampf(left / FADE_OUT, 0.0, 1.0)
	if _scroll >= _end:
		_finish()


func _finish() -> void:
	visible = false
	finished.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var skip: bool = (event is InputEventKey and event.pressed and not event.echo
		and event.keycode in [KEY_ENTER, KEY_SPACE]) \
		or (event is InputEventMouseButton and event.pressed)
	if skip:
		get_viewport().set_input_as_handled()
		_finish()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	for i in _stars.size():
		var twinkle := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * (1.0 + i % 5) + i)
		draw_circle(_stars[i] * size, 1.0 + (i % 3) * 0.4, Color(1, 1, 1, 0.25 + 0.5 * twinkle))
	draw_string(ThemeDB.fallback_font, Vector2(0, size.y - 16.0), "Enter: skip",
		HORIZONTAL_ALIGNMENT_RIGHT, size.x - 16.0, 14, Color(1, 1, 1, 0.4))


## The flat page that the shader tilts: centred title, justified body.
func _draw_page() -> void:
	var font := ThemeDB.fallback_font
	_page.draw_multiline_string(font, Vector2(0, font.get_ascent(TITLE_SIZE)), _title,
		HORIZONTAL_ALIGNMENT_CENTER, TEXT_WIDTH, TITLE_SIZE, -1, COLOR_TEXT)
	_page.draw_multiline_string(font, Vector2(0, _title_height() + TITLE_GAP + font.get_ascent(BODY_SIZE)), _body,
		HORIZONTAL_ALIGNMENT_FILL, TEXT_WIDTH, BODY_SIZE, -1, COLOR_TEXT)
