shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled;
uniform sampler2D vein:repeat_enable,filter_linear_mipmap;
uniform float load_ratio;
uniform float art_clock;
varying vec3 local;
void vertex(){local=VERTEX;}
void fragment(){
	float crack=texture(vein,fract(UV*1.31+vec2(.19,.42))).r;
	float grains=1.-smoothstep(.012,.092,abs(crack-.30-.08*sin(local.x*9.+art_clock*.7)));
	float side=clamp(.36-local.y-local.z*.55,0.,1.);
	ALBEDO=mix(vec3(.27,.21,.12),vec3(.79,.68,.49),grains);
	ALPHA=grains*side*load_ratio*.64;
}
