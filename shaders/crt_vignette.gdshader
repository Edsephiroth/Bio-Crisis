shader_type canvas_item;

uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.42;
uniform float scanline_opacity : hint_range(0.0, 0.3) = 0.06;

void fragment() {
	vec2 uv = UV;
	float dist = distance(uv, vec2(0.5, 0.5));
	float vignette = smoothstep(0.32, 0.88, dist) * vignette_intensity;
	float scan = sin(FRAGCOORD.y * 1.5) * 0.5 + 0.5;
	float alpha = clamp(vignette + scan * scanline_opacity, 0.0, 0.75);
	COLOR = vec4(0.01, 0.02, 0.04, alpha);
}
