shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform sampler2D flow_map : filter_linear_mipmap, repeat_disable;
uniform sampler2D erosion_map : filter_linear_mipmap, repeat_disable;
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform float art_clock;
uniform float mist_density = 1.;
uniform float reveal = 1.;
uniform bool central_gather = false;
uniform float erosion = -0.05;
uniform float retreat;
uniform float flow_speed = 1.;
uniform float edge_gain = 1.;
uniform float distortion;
uniform int optical_pack = 0;
uniform bool gray_preview = false;
uniform bool closed_front = false;
uniform float contact_u = -1.;

void fragment() {
	float s = UV2.x;
	float v = UV.y;
	float section = texture(erosion_map, UV).r;
	float window = 1.0 - smoothstep(reveal-.025, reveal+.002, central_gather ? abs(2.0*s-1.0) : s);
	float retract_mask = 1.0-smoothstep(1.02-retreat*1.06, 1.055-retreat*1.06, s);
	float threshold = erosion;
	if (contact_u >= 0.0) {
		threshold += max(0.0, 1.0-abs(s-contact_u)*2.8)*max(0.0,erosion)*.32;
	}
	float intact = smoothstep(threshold-.016,threshold+.012,section);
	float t = art_clock*flow_speed;
	vec2 advect = vec2(.037*sin(t*1.7 + s*6.0 + v*2.), .019*sin(s*21.0-t*1.4+v*5.0));
	float phase = fract(t*.19);
	float phase_b = fract(phase+.5);
	float blend = abs(2.*phase-1.);
	float silk = mix(texture(flow_map,UV+advect-vec2(phase*.13,0.)).r,
		texture(flow_map,UV+advect-vec2(phase_b*.13,0.)).r,blend);
	float threads = texture(flow_map, vec2(.08+.84*s+.049*sin(t*.9+s*10.),v*.83+.034)).r;
	float taper = closed_front ? 1.0 : smoothstep(0.0,.095,min(s,1.0-s));
	float front = COLOR.r;
	float rim = exp(-pow(v/.044,2.0))*(.55+.45*section)*mix(.032,1.,front);
	float density = rim + taper*mist_density*(pow(silk,.72)*.88+threads*.32)*mix(.42,1.,front);
	float depth = texture(scene_depth, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.-1.,depth,1.);
	float gap = -behind.z/behind.w + VERTEX.z;
	float soft = smoothstep(-.012,.11,gap);
	vec3 smoke = mix(vec3(.06,.12,.20),vec3(.61,.84,1.05),clamp(silk*1.6,0.,1.));
	vec3 color = smoke + vec3(2.6,3.15,3.75)*rim*edge_gain;
	float alpha = clamp(density,0.,.88);
	float tear = smoothstep(.025,.11,threshold)*(1.-smoothstep(.014,.060,abs(section-threshold)));
	color += vec3(.92,1.32,1.8)*tear;
	alpha = max(alpha,tear*.70*taper);
	if (optical_pack>0) {
		float notch = exp(-pow(v/.11,2.0))*front;
		vec2 shear = vec2(.75*cos(3.*s+.3)+.22*sin(11.*s+t),.40+sin(7.*s-t*.34)*.27);
		float thickness = sin(3.14159*clamp(v,0.,1.));
		float gust = texture(erosion_map,vec2(fract(4.*s-t*.10),clamp(.42+v*.36,.0,1.))).r;
		float pulse = sin(v*27.+s*13.+5.*gust-t*6.)*.5+.5;
		vec2 offset = shear*distortion*(.24+thickness*.97+silk*.61);
		if (optical_pack==2) { offset *= (.22+.75*pulse)*(.25+thickness); }
		vec2 sampled_uv = clamp(SCREEN_UV+offset,vec2(.001),vec2(.999));
		float shifted_depth = texture(scene_depth,sampled_uv).r;
		if (shifted_depth>FRAGCOORD.z) { sampled_uv=SCREEN_UV; }
		vec3 background = texture(scene_color,sampled_uv).rgb;
		float caustic = exp(-pow((v-.15)/.047,2.0))*.24;
		color = background*(.96+.17*thickness) + vec3(.17,.21,.25)*(caustic+.38*notch);
		if (optical_pack==2) {
			float dust = pow(max(0.,threads*.68+silk*.59),1.65);
			color = mix(background, vec3(.42,.37,.30), clamp((gust*.53+dust*.75)*(.33+.62*pulse),0.,.70));
			color += vec3(.19,.17,.14)*pulse*thickness*gust;
		}
		alpha = clamp((.20+.76*thickness+.45*silk+.75*notch)*mix(.35,1.,front)*taper,0.,.98);
	}
	if (optical_pack==2) { alpha *= .24+.76*smoothstep(.10,.72,section+silk*.21); }
	ALBEDO = color;
	ALPHA = alpha*intact*window*retract_mask*soft;
	if (gray_preview) {
		float key=abs(dot(normalize(NORMAL),normalize(vec3(-.43,.71,.55))));
		ALBEDO=vec3(.47,.49,.51)*(.19+.81*key);
		ALPHA=intact*window*retract_mask;
	}
}
