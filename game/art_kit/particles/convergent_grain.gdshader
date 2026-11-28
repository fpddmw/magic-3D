shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
#include "res://art_kit/fields/convergent_section.gdshaderinc"
uniform vec4 pigment:source_color;
varying float opacity;
void vertex(){
	float key=INSTANCE_CUSTOM.x;
	float lane=INSTANCE_CUSTOM.y*2.-1.;
	float u=fract(key+drift*flow_sign*flow_speed*(.34+.11*INSTANCE_CUSTOM.z)/max(.3,length_m));
	float offset=UV.x*.036;
	float s=clamp(u+offset,0.,.997);
	vec3 pos=section_at(s,lane);
	pos.y+=.025*sin(key*63.+drift)+.015;
	float w=.004+.004*INSTANCE_CUSTOM.w;
	pos.y+=(UV.y-.5)*w*(.09+sin(PI*UV.x));
	VERTEX=pos;
	opacity=sin(PI*u)*strength*(.22+.65*INSTANCE_CUSTOM.w);
}
void fragment(){ALBEDO=pigment.rgb*2.; ALPHA=opacity*sin(PI*UV.x);}
