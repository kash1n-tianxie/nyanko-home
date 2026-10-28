shader_type canvas_item;
// Only the separate painted distance plate is graded. No screen texture, veil,
// opaque black layer, flashes, or blur over actors / projectiles / controls.
uniform float strength : hint_range(0.0, 1.0) = 0.70;
uniform float contrast : hint_range(0.5, 1.0) = 0.78;
uniform float saturation : hint_range(0.5, 1.0) = 0.82;
uniform float highlights : hint_range(0.0, 0.4) = 0.16;
uniform vec4 ambient : source_color = vec4(0.77, 0.72, 0.68, 1.0);
uniform vec4 warm : source_color = vec4(1.0, 0.88, 0.68, 1.0);
uniform vec2 light_a = vec2(0.108, 0.282);
uniform vec2 light_b = vec2(0.714, 0.400);
uniform vec2 radius_a = vec2(0.095, 0.22);
uniform vec2 radius_b = vec2(0.12, 0.16);
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float aftermath : hint_range(0.0, 1.0) = 0.0;
uniform float pressure : hint_range(0.0, 1.0) = 0.0;
uniform float quiet : hint_range(0.0, 1.0) = 0.0;

float halo(vec2 point, vec2 center, vec2 radius) {
	vec2 q = (point - center) / radius;
	return exp(-dot(q, q) * 2.0);
}

void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	// Feather the busy middle-distance detail, retaining the sky and floor texture.
	float vertical = smoothstep(0.15, 0.30, UV.y) * (1.0 - smoothstep(0.76, 0.95, UV.y));
	float corridor = smoothstep(0.21, 0.39, UV.x) * vertical;
	float behind_cats = halo(UV, vec2(0.17, 0.48), vec2(0.15, 0.39)) * 0.70;
	float region = max(corridor, behind_cats);
	float weight = region * strength;
	float luma = dot(ink.rgb, vec3(0.299, 0.587, 0.114));
	vec3 softened = mix(vec3(luma), ink.rgb, saturation);
	softened = (softened - vec3(0.42)) * contrast + vec3(0.42);
	softened -= max(softened - vec3(0.58), vec3(0.0)) * highlights;
	softened = mix(softened, ambient.rgb, 0.035 * region);
	vec3 result = mix(ink.rgb, softened, weight);
	// Pressure stays near the perimeter. Counter/death transitions use supplied
	// paused-aware clocks, never shader TIME or brightness flashing.
	float perimeter = (1.0 - smoothstep(0.0, 0.19, UV.x)) + smoothstep(0.83, 1.0, UV.x);
	result = mix(result, result * vec3(0.95, 0.97, 1.02), pressure * perimeter * 0.50);
	// Real lamp/window locations recover gently and hold; no full-screen white wash.
	float lamps = min(1.0, halo(UV, light_a, radius_a) + halo(UV, light_b, radius_b) * 0.78);
	float warm_amount = aftermath * (0.085 + night * 0.055) * lamps * (1.0 + quiet * 0.10);
	result = mix(result, warm.rgb, warm_amount);
	float edge_return = aftermath * 0.025 * perimeter * (1.0 - smoothstep(0.80, 1.0, UV.y));
	result = mix(result, result * vec3(1.06, 1.018, 0.98), edge_return * 8.0);
	COLOR = vec4(clamp(result, vec3(0.0), vec3(1.0)), ink.a);
}
