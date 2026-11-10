// Painted sky backdrop for the art-direction diorama: a soft gradient, a sun disc and a few painted clouds.
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 top : source_color;
uniform vec4 horizon : source_color;
uniform vec4 cloud : source_color;
uniform vec4 sun : source_color;
uniform vec2 sun_pos = vec2(0.7, 0.6);

float blob(vec2 uv, vec2 c, vec2 r) {
	vec2 d = (uv - c) / r;
	return 1.0 - smoothstep(0.85, 1.0, length(d));
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	vec3 col = mix(horizon.rgb, top.rgb, smoothstep(0.2, 0.7, uv.y));
	vec2 sd = (uv - sun_pos) * vec2(2.3, 1.0);
	float sl = length(sd);
	col = mix(col, sun.rgb, 0.35 * (1.0 - smoothstep(0.0, 0.25, sl)));
	col = mix(col, sun.rgb, 1.0 - smoothstep(0.075, 0.085, sl));
	float c = 0.0;
	c = max(c, blob(uv, vec2(0.18, 0.72), vec2(0.07, 0.05)));
	c = max(c, blob(uv, vec2(0.24, 0.75), vec2(0.06, 0.07)));
	c = max(c, blob(uv, vec2(0.30, 0.72), vec2(0.07, 0.045)));
	c = max(c, blob(uv, vec2(0.52, 0.86), vec2(0.06, 0.035)));
	c = max(c, blob(uv, vec2(0.57, 0.88), vec2(0.05, 0.05)));
	c = max(c, blob(uv, vec2(0.86, 0.80), vec2(0.07, 0.04)));
	c = max(c, blob(uv, vec2(0.40, 0.55), vec2(0.09, 0.03)));
	col = mix(col, mix(cloud.rgb, horizon.rgb, 0.25), c * 0.85);
	ALBEDO = col;
}
