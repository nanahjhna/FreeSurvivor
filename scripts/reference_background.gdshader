shader_type canvas_item;
render_mode unshaded;

uniform vec4 concealed;

void fragment() {
	vec2 start = smoothstep(concealed.xy - vec2(0.05), concealed.xy, UV);
	vec2 finish = 1.0 - smoothstep(concealed.zw, concealed.zw + vec2(0.05), UV);
	COLOR.a *= start.x * start.y * finish.x * finish.y;
}
