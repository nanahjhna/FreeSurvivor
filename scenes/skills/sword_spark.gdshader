shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 spark_color : source_color = vec4(1.0, 0.64, 0.23, 1.0);

void fragment() {
	float lengthwise = 1.0 - abs(UV.y * 2.0 - 1.0);
	float taper = pow(max(lengthwise, 0.0), 0.68);
	float across = abs(UV.x * 2.0 - 1.0) / max(taper, 0.03);
	float halo = 1.0 - smoothstep(0.20, 1.0, across);
	float core = 1.0 - smoothstep(0.01, 0.40, across);
	vec3 tint = mix(spark_color.rgb * COLOR.rgb, vec3(1.0, 0.95, 0.80), core * 0.88);
	ALBEDO = tint;
	EMISSION = tint * (0.36 + core * 1.40);
	ALPHA = taper * halo * COLOR.a;
}
