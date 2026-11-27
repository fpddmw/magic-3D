shader_type spatial;
varying vec3 world;
varying vec3 outward;
uniform vec4 tone : source_color = vec4(0.26,0.29,0.30,1.0);
uniform sampler2D rock : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float masonry = 1.0;
void vertex() {
    world = (MODEL_MATRIX * vec4(VERTEX,1.)).xyz;
    outward = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
float hash(vec2 p){return fract(sin(dot(p,vec2(53.7,113.1)))*43758.54);}
void fragment(){
    vec3 n=abs(normalize(outward));
    vec2 uv=n.y>max(n.x,n.z)?world.xz:(n.x>n.z?world.zy:world.xy);
    vec2 cell=uv/vec2(1.26,0.53);
    cell.x+=0.5*mod(floor(cell.y),2.);
    vec2 edges=min(fract(cell),1.-fract(cell));
    float joint=smoothstep(0.008,0.05,min(edges.x,edges.y));
    vec3 scanned=texture(rock,uv*.42).rgb;
    vec3 patina=texture(rock,uv*.073+vec2(.27,.51)).rgb;
    float damp=smoothstep(.12,.43,patina.g);
    float grain=dot(scanned,vec3(.24,.58,.18));
    ALBEDO=tone.rgb*(.51+scanned*2.2)*mix(1.,(.57+.43*joint)*(.86+.2*hash(floor(cell))),masonry);
    ROUGHNESS=mix(.88,.32,damp*(n.y>.6?.95:.45));
    NORMAL_MAP=vec3(.5+clamp(dFdx(grain)*.6,-.09,.09),.5+clamp(dFdy(grain)*.6,-.09,.09),1.);
}
