shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform sampler2D flow : repeat_enable, filter_linear_mipmap;
uniform vec4 pigment : source_color = vec4(.53,.69,.80,1.);
uniform vec4 glint : source_color = vec4(.89,.82,.63,1.);
#include "res://art_kit/fields/convergent_section.gdshaderinc"
uniform float fibers;
varying float fold;
varying float inset;
void vertex(){
 inset=UV.x;
 fold=smoothstep(0.,fold_duration,elapsed-(flow_sign>0.?inset:1.-inset)*phase_delay);
 VERTEX=section_at(inset,2.*UV.y-1.);
}
void fragment(){
	float s=inset;
	float v=UV.y;
	vec4 f=texture(flow,vec2(s*1.18-drift*flow_speed*flow_sign*.12,v*.71+s*.14));
	float wav=(f.b-.5)*.36+.037*sin(s*13.+drift*.8);
	float lane=fract((v+wav)*fibers);
	float hair=pow(max(0.,1.-2.*abs(lane-.5)),7.);
	float ridge=exp(-abs(v-.39-wav)*16.);
	float ends=smoothstep(0.,.12,s)*(1.-smoothstep(.78,1.,s));
	float rim=pow(max(0.,sin(PI*v)),.72);
	float feather=smoothstep(.18,.77,f.b+hair*.26);
	float sweep=.58+.42*cos((s-drift*flow_speed*flow_sign*.16)*9.+f.r*2.);
	float sand=smoothstep(.44,.68,texture(flow,vec2(s*11.-drift*.2,v*5.)).b);
	float body=(.16+.27*ridge+.39*hair)*feather*sweep;
	body=mix(body,(.12+.66*hair)*(.24+.76*sand),grain);
	ALBEDO=mix(pigment.rgb,glint.rgb,clamp(hair*.77+ridge*.26,0.,1.))*(1.12+1.1*ridge+1.2*hair);
	ALPHA=clamp(strength*ends*rim*body*(.65+.35*fold),0.,.93);
}
