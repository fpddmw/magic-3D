// Closed helical characteristics of the radial/tangential/axial field.
vec3 advect(float angle, float r0, float age, float lift, float spin, float intake) {
	float radius = r0 * exp(-intake*age);
	float theta = angle + spin*age*(1.0 + .13*age);
	return vec3(radius*cos(theta),lift*age + .16*sin(theta*1.9+lift),radius*sin(theta));
}
