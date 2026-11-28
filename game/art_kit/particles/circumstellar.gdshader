shader_type particles;
render_mode disable_velocity, disable_force;
#include "res://art_kit/fields/orbital_flow.gdshaderinc"
uniform vec3 center = vec3(0.);
uniform vec3 wake[8];
uniform float epoch;
uniform float radius;
uniform float strength;
uniform float spin=1.2;
float hash1(float n){ return fract(sin(n*127.1+311.7)*43758.5453); }
void start() { CUSTOM = vec4(hash1(float(INDEX)+2.),hash1(float(INDEX)+98.),hash1(float(INDEX)+34.),hash1(float(INDEX)+138.)); }
void process(){
	float age=fract(CUSTOM.y + epoch*(.10+CUSTOM.w*.075));
	vec3 q=advect(CUSTOM.x*TAU,1.02+CUSTOM.z*.94,age,(CUSTOM.y-.45)*.85,spin,.38);
	float lane= q.x*.29+q.z*.11;
	q.y+=lane;
	float offset=clamp(age*CUSTOM.z*7.,0.,6.99);
	int i=int(offset);
	vec3 origin=mix(wake[i],wake[i+1],fract(offset));
	TRANSFORM[3].xyz=mix(center,origin,CUSTOM.w)*1.0+q*radius;
	float size=(.008+.023*pow(CUSTOM.w,4.))*radius;
	TRANSFORM[0].xyz=vec3(size,0.,0.);
	TRANSFORM[1].xyz=vec3(0.,size,0.);
	TRANSFORM[2].xyz=vec3(0.,0.,size);
	COLOR=vec4(mix(vec3(.43,.62,.88),vec3(.98,.88,.65),pow(CUSTOM.x,6.)),strength*sin(PI*age)*(.32+.62*CUSTOM.z));
}
