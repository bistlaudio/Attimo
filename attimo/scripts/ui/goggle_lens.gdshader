shader_type canvas_item;
// Goggle overlay: two overlapping round lenses (binocular figure of eight). Outside the lenses the screen is darkened,
// the lens edge is a thick brass rim with rivets, the inside gets a faint turquoise tint. All sizes are in units of
// the screen height, so the look scales with the resolution.

uniform float open : hint_range(0.0, 1.5) = 1.0;
uniform float aspect = 1.7778;
uniform vec2 shake = vec2(0.0);
uniform float lens_radius = 0.56;
uniform float lens_offset = 0.34;
uniform float rim_width = 0.02;
uniform float rivet_count = 16.0;
uniform float intro_scale = 1.15;
uniform float vignette_alpha = 0.38;
uniform vec4 brass : source_color = vec4(0.62, 0.45, 0.27, 1.0);
uniform vec4 brass_dark : source_color = vec4(0.24, 0.17, 0.1, 1.0);
uniform vec4 shade : source_color = vec4(0.07, 0.05, 0.04, 1.0);
uniform vec4 tint : source_color = vec4(0.25, 0.9, 0.85, 0.04);

void fragment() {
	float fade = clamp(open, 0.0, 1.0);
	float zoom = mix(intro_scale, 1.0, open);
	vec2 p = ((UV - 0.5) * vec2(aspect, 1.0) - shake) / zoom;

	vec2 cl = vec2(-lens_offset, 0.0);
	vec2 cr = vec2(lens_offset, 0.0);
	float dl = length(p - cl);
	float dr = length(p - cr);
	bool left = dl < dr;
	float dist = left ? dl : dr;
	vec2 centre = left ? cl : cr;
	float sd = dist - lens_radius; // < 0 inside the lens

	vec4 col;
	if (sd > 0.0) {
		// Outside: dark vignette with a soft shadow cast by the rim.
		float shadow = 1.0 - smoothstep(0.0, 0.12, sd);
		col = vec4(shade.rgb, clamp(vignette_alpha + shadow * 0.15, 0.0, 1.0));
	} else if (sd > -rim_width) {
		// Rim: bevelled brass, dark on the outer edge, bright on the inner edge.
		float t = (-sd) / rim_width;
		vec3 metal = mix(brass_dark.rgb, brass.rgb, smoothstep(0.0, 0.55, t));
		metal = mix(metal, brass_dark.rgb, smoothstep(0.8, 1.0, t) * 0.6);
		vec2 d = p - centre;
		float ang = atan(d.y, d.x);
		float cell = fract(ang * rivet_count / 6.2831853) - 0.5;
		float tangent = cell * 6.2831853 * (lens_radius - rim_width * 0.5) / rivet_count;
		float radial = (-sd) - rim_width * 0.5;
		float rivet = 1.0 - smoothstep(rim_width * 0.2, rim_width * 0.28, length(vec2(radial, tangent)));
		vec3 rivet_col = mix(brass_dark.rgb, vec3(0.85, 0.72, 0.5), 0.5 + 0.5 * (-radial / rim_width));
		col = vec4(mix(metal, rivet_col, rivet), 1.0);
	} else {
		// Inside: nearly clear, faint turquoise tint, darker towards the rim.
		float inner = smoothstep(-rim_width, -rim_width - 0.14, sd);
		col = vec4(mix(tint.rgb, shade.rgb, inner * 0.3), tint.a + inner * 0.08);
	}
	col.a *= fade;
	COLOR = col;
}
