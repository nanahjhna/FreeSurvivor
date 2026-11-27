shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 edge_color : source_color = vec4(1.0, 0.46, 0.08, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.98, 0.84, 1.0);
uniform float phase : hint_range(0.0, 1.0) = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float across = clamp(UV.y, 0.0, 1.0);
	float tip_fade = smoothstep(0.0, 0.07, UV.x) * smoothstep(0.0, 0.07, 1.0 - UV.x);
	float feather = smoothstep(0.0, 0.12, across) * smoothstep(0.0, 0.55, 1.0 - across);
	float crest = 1.0 - smoothstep(0.025, 0.19, abs(across - 0.17));
	float inner = 1.0 - smoothstep(0.012, 0.070, abs(across - 0.45));
	float bands = 0.78 + 0.22 * sin(UV.x * 31.0 - phase * 19.0 + across * 13.0);
	float hot = max(crest, inner * 0.46 * bands);
	vec3 colored = mix(edge_color.rgb * (0.45 + bands * 0.55), core_color.rgb, hot);
	ALBEDO = colored;
	EMISSION = colored * (0.12 + hot * 1.22);
	ALPHA = COLOR.a * feather * tip_fade * intensity * (0.61 + 0.39 * hot);
}
