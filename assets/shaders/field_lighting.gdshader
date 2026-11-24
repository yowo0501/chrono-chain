shader_type canvas_item;
render_mode unshaded, blend_mul;
uniform sampler2D old_light : filter_linear, repeat_disable;
uniform float transition : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec3 previous = texture(old_light, UV).rgb;
	vec3 current = texture(TEXTURE, UV).rgb;
	COLOR = vec4(mix(previous, current, smoothstep(0.0, 1.0, transition)), 1.0);
}

