shader_type canvas_item;

// Inverse of transition_mask: shows the OLD world OUTSIDE an expanding ring, hiding it
// inside the ring so the NEW world (rendered live underneath) shows through. Used on the
// full-screen old-world snapshot during the cinematic transition.
uniform vec2 ring_center = vec2(0.0, 0.0);   // SubViewport / snapshot pixels
uniform float ring_radius = 2000.0;          // full-map radius in px
uniform float reveal = 0.0;                  // 0 = old fully shown, 1 = old fully hidden
uniform float softness = 220.0;

void fragment() {
	vec2 uv_px = UV * TEXTURE_SIZE;
	float dist = distance(uv_px, ring_center);
	float cur = ring_radius * reveal;
	float edge = smoothstep(cur - softness * 0.5, cur + softness * 0.5, dist);
	// We want the old world visible OUTSIDE the ring: alpha 1 when dist > cur, 0 inside.
	COLOR = texture(TEXTURE, UV) * vec4(1.0, 1.0, 1.0, edge);
}
