shader_type spatial;
render_mode cull_disabled,diffuse_burley,specular_schlick_ggx;
uniform sampler2D engraving : hint_normal,repeat_enable,filter_linear_mipmap_anisotropic;
uniform vec4 dye : source_color = vec4(.18,.19,.20,1.);
uniform float metal = .2;
void fragment() {
	vec2 uv=UV*vec2(2.0,1.);
	vec3 relief=texture(engraving,uv).rgb;
	float groove=clamp(length(relief.xy-vec2(.5))*2.8,0.,1.);
	float weave=.5+.5*sin(UV.y*490.)*sin(UV.x*310.);
	float edging=(1.-smoothstep(.015,.047,min(UV.y,1.-UV.y)));
	ALBEDO=dye.rgb*(.72+.28*weave+.43*groove)+vec3(.22,.135,.055)*edging*(.37+.62*groove);
	ROUGHNESS=mix(.84,.39,metal)+.12*groove;
	METALLIC=metal;
	NORMAL_MAP=relief;
	NORMAL_MAP_DEPTH=.19+.32*metal;
}
