// Painted sky backdrop for the yard (Golden Afternoon): a teal-to-blue gradient by height, a soft sun
// that stays put while the camera moves, and painted clouds pinned to the world so they drift past
// slower than the yard (parallax). The card follows the camera in x (YardDressing._process).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 top : source_color;
uniform vec4 horizon : source_color;
uniform vec4 cloud : source_color;
uniform vec4 sun : source_color;
uniform float horizon_y = 0.0;
uniform float top_y = 70.0;
uniform vec2 sun_at = vec2(0.66, 0.62);   // in the card's UV, so it never scrolls
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float blob(vec2 p, vec2 c, vec2 r) {
	vec2 d = (p - c) / r;
	return 1.0 - smoothstep(0.8, 1.0, length(d));
}

float puff(vec2 p, vec2 c, float s) {
	float v = blob(p, c, vec2(1.6, 0.9) * s);
	v = max(v, blob(p, c + vec2(-1.3, -0.25) * s, vec2(1.0, 0.65) * s));
	v = max(v, blob(p, c + vec2(1.4, -0.3) * s, vec2(1.1, 0.6) * s));
	v = max(v, blob(p, c + vec2(0.4, 0.55) * s, vec2(0.9, 0.75) * s));
	return v;
}

void fragment() {
	float h = clamp((wp.y - horizon_y) / (top_y - horizon_y), 0.0, 1.0);
	vec3 col = mix(horizon.rgb, top.rgb, smoothstep(0.05, 0.75, h));
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	vec2 sd = (uv - sun_at) * vec2(3.0, 1.0);
	float sl = length(sd);
	col = mix(col, sun.rgb, 0.35 * (1.0 - smoothstep(0.0, 0.22, sl)));
	col = mix(col, sun.rgb, 1.0 - smoothstep(0.05, 0.056, sl));
	// Painted clouds every ~60 m along the yard, three heights, repeating.
	float c = 0.0;
	float x = mod(wp.x + 300.0, 120.0);
	c = max(c, puff(vec2(x, wp.y), vec2(18.0, 46.0), 4.0));
	c = max(c, puff(vec2(x, wp.y), vec2(62.0, 58.0), 3.0));
	c = max(c, puff(vec2(x, wp.y), vec2(98.0, 38.0), 5.0));
	c = max(c, blob(vec2(x, wp.y), vec2(40.0, 30.0), vec2(14.0, 1.6)));
	c = max(c, blob(vec2(x, wp.y), vec2(85.0, 72.0), vec2(10.0, 1.4)));
	col = mix(col, mix(cloud.rgb, horizon.rgb, 0.3), c * 0.8);
	ALBEDO = col;
}
