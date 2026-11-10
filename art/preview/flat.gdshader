// Flat-shaded look for the art-direction comparison: faceted normals from screen-space derivatives.
shader_type spatial;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 emit : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform sampler2D tex : source_color, hint_default_white;
uniform vec2 uv_off = vec2(0.0);

void fragment() {
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, VIEW) < 0.0) {
		n = -n;
	}
	NORMAL = n;
	vec4 t = texture(tex, UV + uv_off);
	ALBEDO = albedo.rgb * t.rgb;
	ROUGHNESS = 0.85;
	EMISSION = emit.rgb;
}
