extends Node2D
## One night = one hand-drawn brain map. Demen flies freely, sees only what's
## in line of sight (the rest is darkened, not hidden), and gets thrown back
## along their own trail at random. Being thrown back to the start opens the
## grey secret walls for a while, at a cost. Walking off the bottom edge leads
## onto the Ragebait Road, which never ends.
##
## Colour code: Purple = Path, Pink = Wall, Green = Start, Yellow = End,
## Red = Tumor landmark / Restricted, Grey = Secret wall, Blue = Ragebait Road.

const BACKTRACK_MIN := 8.0          # seconds between backtracks (random in range)
const BACKTRACK_MAX := 15.0
const RESET_TO_START_CHANCE := 0.3  # share of backtracks that go all the way to the start
const SECRET_PENALTY := 0.1         # line strength lost per pass through a grey secret wall
const SIMON_PENALTY := 0.05         # line strength lost per wrong note in Simon Says
const SIMON_REWARD := 0.05          # line strength gained for finishing Simon Says
const SPEED := 190.0                # pixels per second
const RADIUS := 11.0                # Demen's collision radius
const CRUMB_INTERVAL := 0.3         # how often the trail used for backtracking is recorded
const SIGHT_RAYS := 180
const SIGHT_RANGE := 520.0
const FOG_TINT := Color.BLACK  # out of sight: nothing shows
const TRIGGER_RADIUS := 34.0        # how close to the end / bell counts as touching it
const DEMEN_SCALE := 0.55
const ROAD_STEP := 40.0             # road pixels per "step" in the road counter
const END_RINGS := 3                # rings pulsing out of the end beacon
const POINTER_ORBIT := 42.0         # distance of the end-pointer arrow from Demen

const ROAD_HINTS: Array[String] = [
	"The light is getting closer.",
	"Almost there.",
	"Just a little further.",
	"You can feel it. Keep going.",
	"This has to be it.",
	"Any second now.",
]

const COLOR_PATH := Color(0.56, 0.19, 0.44)
const COLOR_WALL := Color(0.88, 0.38, 0.75)
const COLOR_START := Color(0.35, 1.0, 0.45)
const COLOR_END := Color(1.0, 0.85, 0.25)
const COLOR_TUMOR := Color(1.0, 0.12, 0.15)
const COLOR_RESTRICTED := Color(1.0, 0.2, 0.25)
const COLOR_SECRET := Color(0.55, 0.55, 0.55)
const COLOR_ROAD_A := Color(0.05, 0.12, 0.35)
const COLOR_ROAD_B := Color(0.15, 0.35, 0.9)
const COLOR_GLOW := Color(0.6, 0.85, 1.0)

const DEMEN_SOURCE: Texture2D = preload("res://public/assets/Demen.png")

enum Mode { TITLE, PLAYING, MINIGAME, MEMORY, FADED }

var rng := RandomNumberGenerator.new()
var demen: Texture2D
var mode := Mode.TITLE
var level: MapLevel
var pos := Vector2.ZERO
var crumbs := PackedVector2Array()
var crumb_timer := 0.0
var sight := PackedVector2Array()
var secret_open := false
var in_secret := false
var bumping := false
var bell_rung := false
var on_road := false
var road_dist := 0.0
var backtrack_timer := 0.0
var flash := 0.0
var hint := ""
var hint_timer := 0.0
var time := 0.0

@onready var camera: Camera2D = $Camera
@onready var screen: Node2D = $UI/Screen
@onready var hud: Label = $UI/HUD
@onready var overlay: ColorRect = $UI/Overlay
@onready var overlay_text: Label = $UI/Overlay/Text
@onready var simon: Control = $UI/SimonSays
@onready var error_sound: AudioStreamPlayer = $ErrorSound
@onready var hurt_sound: AudioStreamPlayer = $HurtSound
@onready var walk_sound: AudioStreamPlayer = $WalkSound
@onready var title: ColorRect = $UI/Title
@onready var start_button: TextureButton = $UI/Title/StartButton


func _ready() -> void:
	rng.randomize()
	demen = _without_white_background(DEMEN_SOURCE)
	screen.draw.connect(_draw_screen)
	simon.mistake.connect(_on_simon_mistake)
	simon.finished.connect(_on_simon_finished)
	start_button.pressed.connect(_begin_game)
	# Load night 1 behind the title screen so there's a world to draw.
	start_night()
	mode = Mode.TITLE
	title.visible = true
	start_button.grab_focus()


func _begin_game() -> void:
	title.visible = false
	start_night()


## Demen.png has no alpha channel; key out its white background.
func _without_white_background(source: Texture2D) -> Texture2D:
	var img := source.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.r > 0.92 and c.g > 0.92 and c.b > 0.92:
				img.set_pixel(x, y, Color(c, 0.0))
	return ImageTexture.create_from_image(img)


func start_night() -> void:
	var n := GameState.night
	level = MapLevel.for_night(n)
	pos = level.start
	crumbs = PackedVector2Array([pos])
	crumb_timer = 0.0
	secret_open = false
	in_secret = false
	bumping = false
	bell_rung = false
	simon.stop()
	on_road = false
	road_dist = 0.0
	GameState.cheats_this_night = 0
	backtrack_timer = rng.randf_range(BACKTRACK_MIN, BACKTRACK_MAX)
	mode = Mode.PLAYING
	overlay.visible = false
	camera.limit_left = -40
	camera.limit_top = -40
	camera.limit_right = int(level.size.x) + 40
	camera.limit_bottom = int(level.size.y) + 160
	camera.position = pos
	camera.reset_smoothing()
	_update_sight()
	_show_hint("Night %d. Find the yellow light." % n)


func _process(delta: float) -> void:
	time += delta
	flash = maxf(0.0, flash - delta)
	hint_timer = maxf(0.0, hint_timer - delta)
	var walking := false
	if mode == Mode.PLAYING:
		var pos_before := pos
		var road_before := road_dist
		if on_road:
			_walk_road(delta)
		else:
			_move(delta)
		walking = mode == Mode.PLAYING and (pos != pos_before or road_dist != road_before)
		backtrack_timer -= delta
		if backtrack_timer <= 0.0:
			_backtrack()
			backtrack_timer = rng.randf_range(BACKTRACK_MIN, BACKTRACK_MAX)
	# Restarted whenever it ends, so it loops for as long as Demen keeps moving.
	if walking and not walk_sound.playing:
		walk_sound.play()
	elif not walking and walk_sound.playing:
		walk_sound.stop()
	camera.position = pos
	_update_hud()
	queue_redraw()
	screen.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not event.keycode in [KEY_ENTER, KEY_SPACE]:
		return
	match mode:
		Mode.TITLE:
			_begin_game()
		Mode.MEMORY:
			GameState.night += 1
			start_night()
		Mode.FADED:
			GameState.reset()
			start_night()


func _input_dir() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A): d.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D): d.x += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W): d.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S): d.y += 1.0
	return d.normalized()


## Axis-separated so Demen slides along walls instead of sticking to them.
## Flying into a wall plays the error sound once per contact.
func _move(delta: float) -> void:
	var v := _input_dir() * SPEED * delta
	if v == Vector2.ZERO:
		bumping = false
		return
	var next := pos
	var hit := false
	if v.x != 0.0:
		if level.blocked(next + Vector2(v.x, 0), RADIUS, secret_open):
			hit = true
		else:
			next.x += v.x
	if v.y != 0.0:
		if level.blocked(next + Vector2(0, v.y), RADIUS, secret_open):
			hit = true
		else:
			next.y += v.y
	if hit and not bumping:
		error_sound.play()
	bumping = hit
	if next == pos:
		return
	pos = next
	_check_secret()
	if mode != Mode.PLAYING:
		return
	if level.past_road_edge(pos):
		on_road = true
		road_dist = 0.0
		_show_hint("A long, straight road. The light must be at the end of it.")
		return

	# Trail for backtracking. Never drop a crumb inside a secret wall, or a
	# later backtrack could leave Demen stuck in one after it closes.
	crumb_timer += delta
	if crumb_timer >= CRUMB_INTERVAL and not in_secret and pos.distance_to(crumbs[-1]) > 12.0:
		crumbs.append(pos)
		crumb_timer = 0.0

	_update_sight()
	if not bell_rung and pos.distance_to(level.bell) < TRIGGER_RADIUS:
		_start_minigame()
	elif pos.distance_to(level.end) < TRIGGER_RADIUS:
		_complete_night()


## Charges the penalty once each time Demen enters a grey secret wall.
func _check_secret() -> void:
	var now := level.overlaps_secret(pos, RADIUS)
	if now and not in_secret:
		GameState.cheats_this_night += 1
		_take_damage(SECRET_PENALTY, "You slip through a secret wall. You feel yourself fade.")
	in_secret = now


func _take_damage(amount: float, text: String) -> void:
	GameState.strength = maxf(0.0, GameState.strength - amount)
	hurt_sound.play()
	flash = 0.3
	_show_hint(text)
	if GameState.strength <= 0.0:
		_fade_away()


## The bell tumor pauses the night (including backtracks) for Simon Says.
func _start_minigame() -> void:
	bell_rung = true
	mode = Mode.MINIGAME
	_show_hint("The bell tumor rings...")
	simon.start()


func _on_simon_mistake() -> void:
	_take_damage(SIMON_PENALTY, "A wrong note. You feel yourself fade.")
	simon.message = "Wrong note: -%d%% line strength (now %d%%). Watch again..." % [
		roundi(SIMON_PENALTY * 100), roundi(GameState.strength * 100)]


func _on_simon_finished() -> void:
	mode = Mode.PLAYING
	GameState.strength = minf(1.0, GameState.strength + SIMON_REWARD)
	_show_hint("A pattern remembered. Your lines grow a little stronger.")


## The road only goes one way, and it never arrives.
func _walk_road(delta: float) -> void:
	var d := _input_dir()
	if d.y < 0.0 or d.x < 0.0:
		_show_hint("There's only forward now.")
		return
	if d == Vector2.ZERO:
		return
	var before := int(road_dist / ROAD_STEP)
	road_dist += SPEED * delta
	var after := int(road_dist / ROAD_STEP)
	if after != before and after % 6 == 0:
		_show_hint(ROAD_HINTS[rng.randi_range(0, ROAD_HINTS.size() - 1)])


## Throw Demen back a random distance along the trail they actually flew.
func _backtrack() -> void:
	var was_on_road := on_road
	if on_road:
		on_road = false
		_show_hint("The road dissolves after %d steps. It was never going anywhere." % int(road_dist / ROAD_STEP))
	secret_open = false
	flash = 0.6
	if crumbs.size() <= 1:
		pos = crumbs[0]
		_update_sight()
		return
	var to_start := rng.randf() < RESET_TO_START_CHANCE or crumbs.size() == 2
	var idx := 0 if to_start else rng.randi_range(1, crumbs.size() - 2)
	crumbs.resize(idx + 1)
	pos = crumbs[idx]
	in_secret = level.overlaps_secret(pos, RADIUS)
	if to_start:
		secret_open = true
		_show_hint("Back to the start... the grey walls feel thinner. Passing through will cost you.")
	elif not was_on_road:
		_show_hint("You stumble back.")
	_update_sight()


func _complete_night() -> void:
	var cheats := GameState.cheats_this_night
	if cheats == 0:
		GameState.strength = minf(1.0, GameState.strength + GameState.GAIN_PER_NIGHT)
	mode = Mode.MEMORY
	overlay.visible = true
	var status := "Your lines grow stronger." if cheats == 0 else "You slipped through %d secret wall%s. Your lines did not grow." % [cheats, "" if cheats == 1 else "s"]
	overlay_text.text = "%s\n\n%s\nLine strength: %d%%\n\n[ENTER] Sleep again" % [
		GameState.memory_for(GameState.night), status, roundi(GameState.strength * 100)]


func _fade_away() -> void:
	simon.stop()
	mode = Mode.FADED
	overlay.visible = true
	overlay_text.text = "Demen faded away.\n\nYou tried to skip the human connection and the learning process, and faded into irrelevancy.\nYour daughter pulled the plug. You were a lost cause.\n\n[ENTER] Wake up again"


func _update_sight() -> void:
	sight = level.sight_polygon(pos, secret_open, SIGHT_RAYS, SIGHT_RANGE)


func _show_hint(text: String) -> void:
	hint = text
	hint_timer = 3.5


func _update_hud() -> void:
	var line := "Night %d   |   Line strength %d%%   |   Secret walls crossed tonight: %d" % [
		GameState.night, roundi(GameState.strength * 100), GameState.cheats_this_night]
	if hint_timer > 0.0:
		line += "      " + hint
	hud.text = line


# --- World drawing (map space, follows the camera) ---------------------------

func _draw() -> void:
	var tex := level.texture
	var pulse := 0.5 + 0.5 * sin(time * 3.0)

	# Everything is darkened; what Demen can see is drawn again at full brightness.
	draw_texture(tex, Vector2.ZERO, FOG_TINT)
	_draw_lit_fan(pos, sight)

	# Nothing outside line of sight may hint at the way forward: open secret
	# walls, tumor glows and the road glow only show once Demen can see them.
	if secret_open:
		for r in level.secret_rects:
			if _in_sight(r.get_center()) or _in_sight(r.position) or _in_sight(r.end):
				draw_rect(r.grow(3.0), Color(COLOR_RESTRICTED, 0.3 + 0.35 * pulse))

	# The start stays visible through the dark. The end is a beacon: it glows
	# and sends out rings, so it can be found from anywhere.
	_draw_landmark(level.start, COLOR_START, 40.0, 0.0)
	_draw_landmark(level.end, COLOR_END, 34.0, 0.3 + 0.2 * pulse)
	for k in END_RINGS:
		var t := fmod(time * 0.45 + float(k) / END_RINGS, 1.0)
		draw_arc(level.end, 40.0 + t * 260.0, 0.0, TAU, 64, Color(COLOR_END, 0.55 * (1.0 - t)), 3.0, true)
	for t in level.tumors:
		if _in_sight(t):
			_draw_landmark(t, COLOR_TUMOR, 26.0, 0.2 + 0.25 * pulse)
	if _in_sight(level.bell):
		_draw_landmark(level.bell, COLOR_TUMOR, 46.0, 0.08 if bell_rung else 0.2 + 0.25 * pulse)

	# A blue glow past the road edge, to make it look like a way out.
	if level.road_edge == SIDE_BOTTOM and _sees_bottom_edge():
		var top := Vector2(0, level.size.y)
		var clear := Color(COLOR_ROAD_B, 0.0)
		draw_polygon(
			PackedVector2Array([top, top + Vector2(level.size.x, 0), top + Vector2(level.size.x, 140), top + Vector2(0, 140)]),
			PackedColorArray([Color(COLOR_ROAD_B, 0.6), Color(COLOR_ROAD_B, 0.6), clear, clear]))

	if not on_road:
		_draw_demen(self, pos, DEMEN_SCALE)
		_draw_end_pointer(pulse)


## A yellow arrow circling Demen that always points at the end.
func _draw_end_pointer(pulse: float) -> void:
	var to_end := level.end - pos
	if to_end.length() < POINTER_ORBIT * 1.5:
		return
	var dir := to_end.normalized()
	var tip := pos + dir * (POINTER_ORBIT + 14.0)
	var base := pos + dir * POINTER_ORBIT
	var side := dir.orthogonal() * 8.0
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]),
		Color(COLOR_END, 0.65 + 0.35 * pulse))


func _in_sight(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, sight)


func _sees_bottom_edge() -> bool:
	for p in sight:
		if p.y >= level.size.y - MapLevel.CELL * 2:
			return true
	return false


## Redraws the map at full brightness inside a polygon fanned around `center`.
func _draw_lit_fan(center: Vector2, rim: PackedVector2Array) -> void:
	var white := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
	var uv_center := center / level.size
	for i in rim.size():
		var a := rim[i]
		var b := rim[(i + 1) % rim.size()]
		draw_primitive(PackedVector2Array([center, a, b]), white,
			PackedVector2Array([uv_center, a / level.size, b / level.size]), level.texture)


## Redraws the landmark's patch of the map at full brightness, with a glow.
func _draw_landmark(p: Vector2, color: Color, radius: float, glow: float) -> void:
	if glow > 0.0:
		draw_circle(p, radius * 1.5, Color(color, glow * 0.6))
		draw_circle(p, radius * 1.15, Color(color, glow))
	var rim := PackedVector2Array()
	for i in 24:
		rim.append((p + Vector2.from_angle(TAU * i / 24.0) * radius).clamp(Vector2.ZERO, level.size))
	_draw_lit_fan(p, rim)


## Demen's glow and opacity scale with line strength; wings flap by squashing
## the sprite horizontally.
func _draw_demen(ci: CanvasItem, p: Vector2, scale_: float) -> void:
	var s := GameState.strength
	var alpha := lerpf(0.2, 1.0, s)
	ci.draw_circle(p, demen.get_height() * scale_ * lerpf(0.5, 1.0, s), Color(COLOR_GLOW, 0.15 * alpha))
	var flap := 0.65 + 0.35 * absf(sin(time * 8.0))
	ci.draw_set_transform(p, 0.0, Vector2(scale_ * flap, scale_))
	ci.draw_texture(demen, -demen.get_size() / 2.0, Color(1, 1, 1, alpha))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Screen drawing (fixed to the screen, on the UI layer) -------------------

func _draw_screen() -> void:
	if on_road:
		_draw_road()
	_draw_legend()
	if flash > 0.0:
		screen.draw_rect(get_viewport_rect(), Color(1, 1, 1, flash * 0.5))


## A wall drawn as a soft, wobbly brain fold.
func _draw_fold(a: Vector2, b: Vector2, color: Color) -> void:
	var normal := (b - a).orthogonal().normalized()
	var phase := a.x * 0.037 + a.y * 0.053
	var amp := (b - a).length() * 0.07
	var pts := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		pts.append(a.lerp(b, t) + normal * amp * sin(t * TAU * 1.5 + phase) * sin(t * PI))
	screen.draw_polyline(pts, Color(color, color.a * 0.18), 7.0, true)
	screen.draw_polyline(pts, color, 2.5, true)


## Full-screen view of the endless road. The light always stays ahead.
func _draw_road() -> void:
	var vp := get_viewport_rect().size
	screen.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.88))
	var tile := 80.0
	var top := vp.y * 0.5 - 60.0
	var bottom := vp.y * 0.5 + 60.0
	var offset := fmod(road_dist / ROAD_STEP * tile, tile)
	var mid := COLOR_ROAD_A.lerp(COLOR_ROAD_B, 0.5)
	for i in range(-1, int(vp.x / tile) + 2):
		var x0 := i * tile - offset
		var x1 := x0 + tile
		var fade0 := Color(mid, 1.0 - clampf(x0 / vp.x, 0.0, 1.0))
		var fade1 := Color(mid, 1.0 - clampf(x1 / vp.x, 0.0, 1.0))
		screen.draw_polygon(
			PackedVector2Array([Vector2(x0, top), Vector2(x1, top), Vector2(x1, bottom), Vector2(x0, bottom)]),
			PackedColorArray([fade0, fade1, fade1, fade0]))
		var wall := Color(COLOR_WALL, fade0.a)
		_draw_fold(Vector2(x0, top), Vector2(x1, top), wall)
		_draw_fold(Vector2(x0, bottom), Vector2(x1, bottom), wall)
	var pulse := 0.5 + 0.5 * sin(time * 2.0)
	screen.draw_circle(Vector2(vp.x - 70.0, vp.y * 0.5), 10.0 + 4.0 * pulse, Color(COLOR_END, 0.35 + 0.3 * pulse))
	_draw_demen(screen, Vector2(220.0, vp.y * 0.5), 0.9)
	screen.draw_string(ThemeDB.fallback_font, Vector2(0, top - 24.0),
		"RAGEBAIT ROAD   ·   %d steps in" % int(road_dist / ROAD_STEP),
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, 22, COLOR_ROAD_B.lightened(0.4))


func _draw_legend() -> void:
	var font := ThemeDB.fallback_font
	var entries := [["Path", COLOR_PATH], ["Wall", COLOR_WALL], ["Start", COLOR_START],
		["End", COLOR_END], ["Tumor", COLOR_TUMOR], ["Secret wall", COLOR_SECRET],
		["Ragebait Road", COLOR_ROAD_B]]
	var vp := get_viewport_rect().size
	screen.draw_rect(Rect2(0, vp.y - 30.0, vp.x, 30.0), Color(0, 0, 0, 0.6))
	var x := 16.0
	var y := vp.y - 10.0
	for e in entries:
		screen.draw_rect(Rect2(x, y - 11.0, 12.0, 12.0), e[1])
		x += 18.0
		screen.draw_string(font, Vector2(x, y), e[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.8))
		x += font.get_string_size(e[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 24.0
