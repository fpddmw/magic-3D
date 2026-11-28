shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never;
uniform sampler2D sprite;
void vertex() {
	float size=length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(INV_VIEW_MATRIX[0].xyz*size,0.),vec4(INV_VIEW_MATRIX[1].xyz*size,0.),vec4(INV_VIEW_MATRIX[2].xyz*size,0.),MODEL_MATRIX[3]);
}
void fragment(){ALBEDO=COLOR.rgb*2.5; ALPHA=texture(sprite,UV).r*COLOR.a;}
