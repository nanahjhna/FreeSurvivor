shader_type spatial;

varying vec2 ground_position;

float patches(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec4 seed = dot(cell, vec2(127.1, 311.7)) + vec4(0.0, 127.1, 311.7, 438.8);
	vec4 corners = fract(sin(seed) * 43758.5453);
	return mix(mix(corners.x, corners.y, f.x), mix(corners.z, corners.w, f.x), f.y);
}

void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 p = ground_position;
	float large = patches(p * 0.16);
	float detail = patches(p * 2.15);
	float grass = smoothstep(0.24, 0.73, large * 0.77 + detail * 0.23);
	vec3 earth = vec3(0.20, 0.15, 0.078);
	vec3 meadow = vec3(0.105, 0.193, 0.066);
	ALBEDO = mix(earth, meadow, grass) * (0.83 + detail * 0.27);
	ROUGHNESS = 0.96;
}
