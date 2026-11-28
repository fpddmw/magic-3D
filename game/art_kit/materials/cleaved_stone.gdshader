shader_type spatial;
render_mode diffuse_burley,specular_schlick_ggx;
uniform sampler2D rock:source_color,repeat_enable,filter_linear_mipmap;
uniform sampler2D relief:hint_normal,repeat_enable,filter_linear_mipmap;
uniform vec4 tint:source_color;
varying vec3 point;
varying vec3 local_n;
void vertex(){point=VERTEX; local_n=NORMAL;}
void fragment(){
	vec3 w=pow(abs(normalize(local_n)),vec3(4.)); w/=max(.001,w.x+w.y+w.z);
	vec3 p=point*1.7;
	vec3 c=texture(rock,p.yz).rgb*w.x+texture(rock,p.xz).rgb*w.y+texture(rock,p.xy).rgb*w.z;
	float seam=pow(.5+.5*sin(p.y*26.+p.x*4.+c.r*8.),18.);
	ALBEDO=tint.rgb*(.42+1.8*c)+vec3(.19,.16,.10)*seam;
	ROUGHNESS=.72+.19*c.g;
	SPECULAR=.35;
	NORMAL_MAP=texture(relief,UV*1.3).rgb;
	NORMAL_MAP_DEPTH=.29;
}
