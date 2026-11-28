shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled;
uniform sampler2D grains:repeat_enable,filter_linear_mipmap;
uniform float strength;
uniform float art_clock;
void fragment(){
	float fibre=texture(grains,vec2(fract(UV.x*9.+art_clock*.07),.12+UV.y*.65)).r;
	float gap=smoothstep(.13,.70,texture(grains,vec2(fract(UV.x*4.-art_clock*.03),.22)).r);
	float ridge=exp(-pow((UV.y-.16-.05*sin(UV.x*157.))/.13,2.));
	ALBEDO=mix(vec3(.13,.095,.062),vec3(.53,.44,.31),fibre);
	ALPHA=(fibre*.86+ridge*.51)*gap*strength*(1.-smoothstep(.58,1.,UV.y));
}
