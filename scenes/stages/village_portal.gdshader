shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_prepass_alpha;

uniform vec4 tint : source_color = vec4(0.3, 0.7, 1.0, 1.0);

void fragment() {
	vec2 point = UV * 2.0 - 1.0;
	float radius = length(point);
	float angle = atan(point.y, point.x);
	float ripple = sin(18.0 * radius - TIME * 2.2 + 1.2 * sin(angle * 5.0 + TIME));
	float rim = smoothstep(0.67, 0.87, radius) * (1.0 - smoothstep(0.89, 1.0, radius));
	float edge = 1.0 - smoothstep(0.88, 1.0, radius);
	ALBEDO = tint.rgb * (0.36 + 0.18 * ripple + rim * 1.14);
	ALPHA = edge * (0.34 + rim * 0.52);
}
