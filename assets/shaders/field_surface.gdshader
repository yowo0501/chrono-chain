shader_type spatial;
render_mode diffuse_burley, specular_disabled, fog_disabled;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform float district_light[12];
uniform float map_scale = 1.0;
uniform vec4 emission_color : source_color = vec4(0.0);
uniform float emission_energy = 0.0;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz / vec3(map_scale, 1.0, map_scale);
}

void fragment() {
	vec3 color = base_color.rgb * texture(albedo_texture, UV).rgb;
	float light_amount = 1.0;
	if (world_position.x >= 0.0 && world_position.x < 25.0 && world_position.z >= 0.0 && world_position.z < 15.0) {
		int area = clamp(int(floor((world_position.x - 1.0) / 4.0)), 0, 5);
		if (world_position.z >= 7.0) { area += 6; }
		light_amount = district_light[area];
	}
	ALBEDO = color * light_amount;
	EMISSION = emission_color.rgb * emission_energy * light_amount;
	ROUGHNESS = 0.92;
}
