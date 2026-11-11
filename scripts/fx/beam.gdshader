// PT10-2: each gun's beam is its own pattern, not just its own colour, so the guns read apart even
// for a colour-blind dad on a bright TV. The aim cone (Zapper) is a flat fan: UV.x runs out from the
// gun (0..1), UV.y across the fan (0..1). `flash` (0..1) brightens it when the gun fires.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, blend_mix, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float base = 0.07;
uniform float flash = 0.0;
// GunData.Kind: 0 size, 1 grab, 2 bouncy, 3 balloon, 4 freeze, 5 glue, 6 magnet
uniform int pattern = 0;

float band(float x, float w) {
	return smoothstep(w, 0.0, abs(x));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float u = UV.x;
	float v = UV.y * 2.0 - 1.0;
	float t = TIME;
	float p = 0.0;
	if (pattern == 0) {          // size: rings that swell as they travel out
		float ph = fract(u * 4.0 - t * 1.6);
		p = smoothstep(0.0, 0.06, ph) * smoothstep(0.1 + 0.25 * u, 0.06, ph);
	} else if (pattern == 1) {   // grab: chevrons flowing back to the gun (pulling)
		float ph = fract(u * 6.0 - abs(v) * 0.9 + t * 1.8);
		p = step(ph, 0.22);
	} else if (pattern == 2) {   // bouncy: a springy zigzag
		float y = sin(u * 26.0 - t * 9.0) * 0.6;
		p = band(v - y, 0.2);
	} else if (pattern == 3) {   // balloon: bubbles drifting out
		vec2 g = vec2(u * 9.0 - t * 1.1, v * 1.6 + sin(u * 6.0 + t) * 0.2);
		vec2 c = fract(g) - 0.5;
		float r = length(c);
		p = (smoothstep(0.34, 0.27, r) - smoothstep(0.24, 0.17, r)) * step(0.35, hash(floor(g)));
	} else if (pattern == 4) {   // freeze: twinkling ice crosses
		vec2 g = vec2(u * 16.0, v * 2.5);
		float h = hash(floor(g));
		vec2 c = fract(g) - 0.5;
		float star = band(c.x, 0.06) * band(c.y, 0.42) + band(c.y, 0.06) * band(c.x, 0.42);
		p = star * step(0.45, h) * (0.55 + 0.45 * sin(t * 7.0 + h * 40.0));
	} else if (pattern == 5) {   // glue: a gooey rope that bulges along
		float w = 0.25 + 0.22 * sin(u * 13.0 - t * 3.2);
		p = band(v, w);
	} else {                      // magnet: field arcs rushing in, buzzing
		float ph = fract(u * 5.0 + t * 1.6 - v * v * 0.5);
		p = band(ph - 0.5, 0.07) * (0.65 + 0.35 * step(0.5, fract(t * 14.0)));
	}
	float edge = smoothstep(1.0, 0.8, abs(v)) * smoothstep(1.0, 0.75, u);
	ALBEDO = mix(color.rgb, vec3(1.0), p * 0.35);
	ALPHA = clamp((base + p * (0.22 + 0.5 * flash) + flash * 0.18) * edge, 0.0, 1.0);
}
