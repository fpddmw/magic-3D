// Same parameter domain for the sheet silhouette and its fine moving grains.
uniform float length_m;
uniform float height_m;
uniform float sector_width;
uniform float inner_m;
uniform float bank;
uniform float fan;
uniform float phase_delay;
uniform float fold_duration;
uniform float flow_speed;
uniform float flow_sign;
uniform float grain;
uniform float strength;
uniform float elapsed;
uniform float drift;
uniform float skew;
uniform float ground_y;

vec3 section_at(float s, float v) {
	float folded=smoothstep(0.,fold_duration,elapsed-(flow_sign>0.?s:1.-s)*phase_delay);
	float arch=sin(PI*s);
	float r=inner_m+length_m*pow(1.-s,1.12)*(1.-.21*folded*s);
	float spread=fan*(.22+.78*(1.-s))*v;
	float crease=(sin(v*12.+3.*s+skew)*.09+sin(v*5.-s*3.)*.16)*arch;
	float lift=height_m*(.12+pow(s,.92)*(.81+.18*v)+crease*.74);
	float twist=bank*arch*(.42+.58*folded);
	return vec3(sin(spread)*r+arch*(skew*.24+crease)*sector_width,
		ground_y+lift*(1.-.29*folded)+sin(twist)*v*sector_width*arch,
		cos(spread)*r);
}
