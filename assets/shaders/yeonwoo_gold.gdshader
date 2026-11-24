shader_type canvas_item;
// Palette-only swap: preserves every authored pose and transparent atlas pixel.
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
 vec4 c = texture(TEXTURE, UV) * vertex_tint;
 float magenta = step(c.g * 1.30 + 0.015,c.r) * step(c.g * 1.18 + 0.015,c.b) * step(c.b * 0.95,c.r);
 float light = max(c.r,c.b);
 vec3 gold = vec3(light, light * 0.76, light * 0.38);
 COLOR = vec4(mix(c.rgb,gold,magenta),c.a);
}
