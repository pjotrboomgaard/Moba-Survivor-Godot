shader_type canvas_item;

// Cinematic world-transition mask for the NEW map layer.
// The new world is rendered into a SubViewport; this shader shows it ONLY inside
// an expanding ring radius so the region outside the ring still shows the OLD
// world that sits underneath. `reveal` (0..1) drives the radius from 0 to full.
uniform vec2 ring_center = vec2(0.0, 0.0);   // in the SubViewport's own pixels
uniform float ring_radius = 2000.0;          // full-map radius in px
uniform float reveal = 0.0;                  // 0 = nothing shown, 1 = fully shown
uniform float softness = 220.0;             // soft edge width in px

void fragment() {
	vec2 uv_px = UV * TEXTURE_SIZE;
	// Distance from the ring centre, measured in SubViewport pixels.
	float dist = distance(uv_px, ring_center);
	float cur = ring_radius * reveal;
	// Inside the ring (dist < cur) -> show the new map; outside -> hide it.
	float edge = smoothstep(cur - softness * 0.5, cur + softness * 0.5, dist);
	// edge == 0 inside, edge == 1 outside. We want the opposite: alpha 1 inside.
	float alpha = 1.0 - edge;
	COLOR = texture(TEXTURE, UV) * vec4(1.0, 1.0, 1.0, alpha);
}
