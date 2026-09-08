shader_type canvas_item;

// RTS veil: authored pixels stay untouched in open vision.
// Outside the circle, and in the umbra behind tree groups, a flat dark overlay.
// Terrain stays visible in the umbra; units are hidden in gameplay code.
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform vec2 vision_center_px = vec2(640.0, 360.0);
uniform float vision_radius_px = 420.0;
uniform float softness_px = 110.0;
uniform vec4 fog_color : source_color = vec4(0.06, 0.07, 0.09, 0.34);
uniform vec4 tree_fog_color : source_color = vec4(0.05, 0.07, 0.06, 0.38);
uniform int tree_count = 0;
uniform float tree_radius_px = 22.0;
uniform vec2 tree_px0;
uniform vec2 tree_px1;
uniform vec2 tree_px2;
uniform vec2 tree_px3;
uniform vec2 tree_px4;
uniform vec2 tree_px5;
uniform vec2 tree_px6;
uniform vec2 tree_px7;
uniform vec2 tree_px8;
uniform vec2 tree_px9;
uniform vec2 tree_px10;
uniform vec2 tree_px11;
uniform vec2 tree_px12;
uniform vec2 tree_px13;
uniform vec2 tree_px14;
uniform vec2 tree_px15;

float tree_umbra(vec2 pixel, vec2 tree_px) {
	vec2 to_tree = tree_px - vision_center_px;
	float tree_dist = length(to_tree);
	if (tree_dist < 10.0) {
		return 0.0;
	}
	vec2 dir = to_tree / tree_dist;
	vec2 to_pix = pixel - vision_center_px;
	float along = dot(to_pix, dir);
	if (along < tree_dist - 4.0) {
		return 0.0;
	}
	float side = abs(dot(to_pix, vec2(-dir.y, dir.x)));
	float width = tree_radius_px + (along - tree_dist) * 0.08;
	float band = 1.0 - smoothstep(width, width + 28.0, side);
	float fall = 1.0 - smoothstep(tree_dist, tree_dist + 260.0, along);
	return band * fall;
}

void fragment() {
	vec2 pixel = SCREEN_UV * viewport_size;
	float edge0 = max(vision_radius_px - softness_px, 0.0);
	float radius_cover = smoothstep(edge0, vision_radius_px, distance(pixel, vision_center_px));
	vec4 radius_fog = vec4(fog_color.rgb, fog_color.a * radius_cover);
	COLOR = radius_fog;
}
