shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform vec3 spine[12];
uniform vec3 frames[12];
uniform float phase;
uniform float width;
uniform float reveal;
uniform float intensity = 1.;
uniform vec3 silver = vec3(.49,.75,1.);
uniform sampler2D flow : repeat_enable,filter_linear;
vec3 cubic(vec3 a,vec3 b,vec3 c,vec3 d,float t){
    return .5*((2.*b)+(-a+c)*t+(2.*a-5.*b+4.*c-d)*t*t+(-a+3.*b-3.*c+d)*t*t*t);
}
void vertex(){
	float u=UV.x*11.; int k=min(10,int(u)); float t=u-float(k);
	vec3 center=cubic(spine[max(k-1,0)],spine[k],spine[k+1],spine[min(k+2,11)],t);
	vec3 n=normalize(mix(frames[k],frames[k+1],t));
	vec3 tangent=normalize(spine[k+1]-spine[k]);
	float twist=.46*sin(UV.x*5.-phase*.5);
	n=n*cos(twist)+cross(tangent,n)*sin(twist);
	float taper=.07+pow(max(0.,sin(PI*UV.x)),.76);
	VERTEX=center+(UV.y-.5)*width*taper*n;
}
void fragment(){
	float s=UV.x; float v=UV.y;
	vec4 eddy=texture(flow,vec2(s*1.7-phase*.045,v*.12+s*.15));
	float w=v-.50+(eddy.b-.5)*.32;
	float mantle=exp(-12.*w*w);
	float fiber=texture(flow,vec2(s*3.3-phase*.06,v*.64+eddy.r*.4)).b;
	float strands=smoothstep(.46,.76,fiber)*pow(max(0.,cos((v+.32*eddy.b)*23.+s*11.+5.*fiber)),4.);
	float leading=1.-smoothstep(reveal-.12,reveal,s);
	float ends=smoothstep(0.,.09,s)*(1.-smoothstep(.88,1.,s));
	ALBEDO=mix(silver*.32,silver*1.85,strands*.54+mantle*.41);
	ALPHA=clamp(leading*ends*intensity*mantle*(.04+.49*eddy.b+.65*strands),0.,.9);
}
