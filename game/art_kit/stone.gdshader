shader_type spatial;
varying vec3 world;
varying vec3 outward;
uniform vec4 tone : source_color = vec4(0.26,0.29,0.30,1.0);
uniform float masonry = 1.0;
void vertex() {
    world = (MODEL_MATRIX * vec4(VERTEX,1.)).xyz;
    outward = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
float hash(vec2 p){return fract(sin(dot(p,vec2(53.7,113.1)))*43758.54);}
float noise2(vec2 p){
    vec2 i=floor(p),f=fract(p); f=f*f*(3.-2.*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void fragment(){
    vec3 n=abs(normalize(outward));
    vec2 uv=n.y>max(n.x,n.z)?world.xz:(n.x>n.z?world.zy:world.xy);
    vec2 cell=uv/vec2(1.26,0.53);
    cell.x+=0.5*mod(floor(cell.y),2.);
    vec2 edges=min(fract(cell),1.-fract(cell));
    float joint=smoothstep(0.008,0.05,min(edges.x,edges.y));
    float grain=noise2(uv*5.)*.24+noise2(uv*29.)*.10;
    float damp=smoothstep(.35,.8,noise2(uv*.35));
    ALBEDO=tone.rgb*(.70+grain+noise2(uv*1.2)*.20)*mix(1.,(.57+.43*joint)*(.86+.2*hash(floor(cell))),masonry);
    ROUGHNESS=mix(.88,.32,damp*(n.y>.6?.95:.45));
    NORMAL_MAP=vec3(.5+.12*(noise2(uv*18.)-.5),.5+.10*(noise2(uv*18.+2.)-.5),1.);
}
