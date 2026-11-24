shader_type canvas_item;
// Procedural turquoise vignette for the Loader hold (D-04 "geladen"). Pure radial falloff from the UV: no screen texture read,
// so it costs one cheap full-screen pass. `strength` is the alpha at the screen corners.

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.25, 0.9, 0.85, 1.0);

void fragment() {
	vec2 centred = (UV - vec2(0.5)) * vec2(1.0, 0.8);
	float edge = smoothstep(0.25, 0.8, length(centred) * 1.6);
	COLOR = vec4(tint.rgb, edge * strength);
}
