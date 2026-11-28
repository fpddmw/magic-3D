shader_type spatial;
uniform sampler2D grain : source_color, repeat_enable, filter_linear_mipmap;
void fragment() {
    float bedding = dot(texture(grain, UV*1.8).rgb,vec3(.27,.52,.21));
    float lamina = smoothstep(.03,.32,bedding);
    ALBEDO = mix(vec3(.24,.19,.14),vec3(.65,.56,.40),lamina);
    ROUGHNESS = .82;
}
