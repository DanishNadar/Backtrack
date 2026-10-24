extends Control
## Star Wars-style text crawl on plain black. The text is drawn flat into a
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
const COLOR_TEXT := Color(0.35, 0.7, 1.0)
## Tried in order; the first one installed is used.
const FONT_NAMES := ["Georgia", "Palatino Linotype", "Times New Roman", "serif"]

const SHADER := preload("res://scripts/crawl.gdshader")

var _title := ""
var _body := ""
var _scroll := 0.0
var _end := 1.0
var _font := SystemFont.new()
var _viewport: SubViewport
var _page: Control
var _plane: ColorRect
var _voice := AudioStreamPlayer.new()


func _ready() -> void:
	visible = false
	add_child(_voice)
	_font.font_names = PackedStringArray(FONT_NAMES)

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


## Shows a crawl, narrated by the recording for `voice_id` if there is one.
## `finished` is emitted once it has scrolled away and the narration is over,
## or when it's skipped.
func play(title: String, body: String, voice_id: String) -> void:
	_voice.stream = Voice.load_line(voice_id)
	if _voice.stream:
		_voice.play()
	_title = title
	_body = body
	var font := _font
	var height := _title_height() + TITLE_GAP \
		+ font.get_multiline_string_size(_body, HORIZONTAL_ALIGNMENT_CENTER, TEXT_WIDTH, BODY_SIZE).y
	_viewport.size = Vector2i(TEXT_WIDTH, ceili(height))
	_page.size = Vector2(_viewport.size)
	_page.queue_redraw()
	_plane.material.set_shader_parameter("tex_size", Vector2(_viewport.size))
	_scroll = 0.0
	_end = height + DEPTH_SCALE * TRAIL
	_plane.modulate.a = 1.0
	visible = true


func _title_height() -> float:
	return _font.get_multiline_string_size(
		_title, HORIZONTAL_ALIGNMENT_CENTER, TEXT_WIDTH, TITLE_SIZE).y


func _process(delta: float) -> void:
	if not visible:
		return
	_scroll += SPEED * delta
	_plane.material.set_shader_parameter("scroll", _scroll)
	var left := 1.0 - _scroll / _end
	_plane.modulate.a = clampf(left / FADE_OUT, 0.0, 1.0)
	if _scroll >= _end and not _voice.playing:
		_finish()


func _finish() -> void:
	_voice.stop()
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
	draw_string(ThemeDB.fallback_font, Vector2(0, size.y - 16.0), "Enter: skip",
		HORIZONTAL_ALIGNMENT_RIGHT, size.x - 16.0, 14, Color(1, 1, 1, 0.4))


## The flat page that the shader tilts: centred title and body.
func _draw_page() -> void:
	var font := _font
	_page.draw_multiline_string(font, Vector2(0, font.get_ascent(TITLE_SIZE)), _title,
		HORIZONTAL_ALIGNMENT_CENTER, TEXT_WIDTH, TITLE_SIZE, -1, COLOR_TEXT)
	_page.draw_multiline_string(font, Vector2(0, _title_height() + TITLE_GAP + font.get_ascent(BODY_SIZE)), _body,
		HORIZONTAL_ALIGNMENT_CENTER, TEXT_WIDTH, BODY_SIZE, -1, COLOR_TEXT)
