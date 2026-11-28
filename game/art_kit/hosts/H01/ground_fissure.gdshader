shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

float fissure(vec2 p, float seed) {
	float along = p.x;
	float bend = abs(fract(along * 3.7 + seed) - .5) * .16
		+ abs(fract(along * 10.3 - seed) - .5) * .065;
	float dist = p.y - bend;
	float width = .014 * (1. - smoothstep(.04,.93,along));
	float edge = max(fwidth(dist), .0015);
	return (1. - smoothstep(width, width + edge, abs(dist)))
		* smoothstep(-.04, .05, along) * (1. - smoothstep(.79, .96, along));
}

void fragment() {
	vec2 p = (UV - vec2(.46, .53)) * 2.15;
	float main = fissure(p, .21);
	float fork = fissure(mat2(vec2(.85,-.53),vec2(.53,.85)) * (p - vec2(.24,.08)) * 1.6, .57);
	float heel = fissure(mat2(vec2(-.88,.47),vec2(-.47,-.88)) * p * 1.22, .39);
	ALBEDO = vec3(.019,.016,.013);
	ALPHA = max(main,max(fork,heel)) * .84;
}
