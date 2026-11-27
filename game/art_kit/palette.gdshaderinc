uniform float beat : hint_range(0,1)=0.0;
uniform float emphasis : hint_range(0,1)=1.0;
uniform float adapter=0.0;
uniform float motif=0.;
uniform float distortion=0.;
uniform float accent=0.09;
uniform vec4 tint : source_color=vec4(.46,.72,.78,1.);

vec4 palette(float boundary,float pattern,vec2 uv) {
	float warp=sin(uv.x*(4.+motif)+beat*6.)*.035*distortion;
	float phase=fract((pattern+warp)*(3.+mod(motif,4.))-beat);
	float stroke=1.-smoothstep(0.,accent,min(phase,1.-phase)*2.);
	float core=max(boundary*.39,stroke);
	return vec4(tint.rgb*(.13+core*(.8+emphasis)),(.035+core*.49)*(.4+.6*emphasis));
}
