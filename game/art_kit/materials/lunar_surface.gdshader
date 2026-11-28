shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D geology : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D relief : hint_normal, repeat_enable, filter_linear_mipmap;
uniform float radius = 0.8;
uniform float assembly = 1.0;
uniform float withdrawal = 0.0;
varying vec3 object_normal;
void vertex() {
    object_normal = NORMAL;
    float relief_height = textureLod(geology, UV, 2.0).r;
    VERTEX = NORMAL * radius * (1.0 + (relief_height - 0.5) * 0.009);
}
void fragment() {
    vec3 g = texture(geology, UV).rgb;
    float strata = smoothstep(0.15, 0.77, g.r);
    float front = 0.46 * (object_normal.y + 1.0) + 0.12 * g.r;
    if (front > assembly * 1.12 || withdrawal > 0.003 + (1.0-front*.65)*.54 + g.r*.45) { discard; }
    vec3 regolith = mix(vec3(.014,.022,.036), vec3(.42,.49,.54), strata);
    float ray = smoothstep(.16,.68,g.b);
    ALBEDO = regolith * (0.84 + ray*.32);
    NORMAL_MAP = texture(relief, UV).rgb;
    NORMAL_MAP_DEPTH = 0.69;
    ROUGHNESS = mix(.94,.68,ray);
    METALLIC = .10;
    float terminator = max(0.0, dot(normalize(object_normal), normalize(vec3(-.64,.5,.45))));
    EMISSION = regolith * (.024 + .22 * terminator) + vec3(.30,.50,.66)*ray*terminator*.12;
}
