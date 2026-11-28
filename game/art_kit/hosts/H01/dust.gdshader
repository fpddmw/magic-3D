shader_type spatial;
render_mode unshaded,blend_mix,depth_draw_never,cull_disabled,shadows_disabled;
uniform sampler2D grains:repeat_enable;
varying float life;
void vertex(){
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(INV_VIEW_MATRIX[0].xyz*length(MODEL_MATRIX[0].xyz),0.),
		vec4(INV_VIEW_MATRIX[1].xyz*length(MODEL_MATRIX[1].xyz),0.),
		vec4(INV_VIEW_MATRIX[2].xyz,0.),MODEL_MATRIX[3]);
	life=INSTANCE_CUSTOM.y;
}
void fragment(){
	float d=length(UV-.5)*2.;
	float grain=texture(grains,UV*.69+vec2(.09,.13)).r;
	ALBEDO=mix(vec3(.17,.13,.085),vec3(.49,.41,.29),grain);
	ALPHA=(1.-smoothstep(.23,1.,d+grain*.25))*(.36+grain*.64)*(1.-smoothstep(.25,1.,life))*.72;
}
