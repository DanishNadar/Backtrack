shader_type canvas_item;
// Lays a flat text texture on a plane tilting away toward a horizon, like the
// opening crawl of a space opera. `scroll` is how far (in texture pixels) the
// text has moved past the bottom edge of the screen.

uniform sampler2D text_tex : filter_linear;
uniform vec2 tex_size = vec2(900.0, 600.0);
uniform float scroll = 0.0;
uniform float horizon = 0.92;       // fraction of screen height where the plane vanishes
uniform float depth_scale = 700.0;  // texture pixels per unit of depth
uniform float spread = 1.25;        // screen width at the bottom, in text widths

void fragment() {
	float y = (1.0 - UV.y) / horizon;  // 0 at the bottom, 1 at the horizon
	vec4 c = vec4(0.0);
	if (y < 1.0) {
		float depth = 1.0 / (1.0 - y);
		float dist = (depth - 1.0) * depth_scale;
		float x = (UV.x - 0.5) * depth * spread;
		vec2 tuv = vec2(x + 0.5, (scroll - dist) / tex_size.y);
		if (tuv.x >= 0.0 && tuv.x <= 1.0 && tuv.y >= 0.0 && tuv.y <= 1.0) {
			c = texture(text_tex, tuv);
		}
		c.a *= clamp((1.0 - y) * 1.6, 0.0, 1.0);  // fade into the distance
	}
	COLOR = c;
}
