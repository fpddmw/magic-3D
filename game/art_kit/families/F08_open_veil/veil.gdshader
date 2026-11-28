shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never, specular_schlick_ggx;

uniform sampler2D silk : repeat_enable, filter_linear_mipmap;
uniform sampler2D fray : repeat_disable, filter_linear_mipmap;
uniform sampler2D crack : repeat_disable, filter_linear_mipmap;
uniform sampler2D screen_color : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;

uniform vec4 silk_dye : source_color = vec4(0.72, 0.68, 0.55, 1.0);
uniform vec4 selvage : source_color = vec4(0.93, 0.83, 0.65, 1.0);
uniform float density = 0.48;
uniform float distortion = 0.0;
uniform float absorption = 0.0;
uniform float edge_gain = 0.34;
uniform float art_clock = 0.0;
uniform float erosion_threshold = 0.0;
uniform float closure = 0.0;
uniform float load_ratio = 0.0;
uniform float flex = 0.0;
uniform vec3 contact_local = vec3(0.0);
varying vec2 cloth_position;

void vertex() {
    cloth_position = VERTEX.xy;
    // Blender's load key supplies the displacement. Narrow its support in metres
    // around the receipt so the same key can flex at either side of the veil.
    vec2 offset = (cloth_position - contact_local.xy) / vec2(1.22, 0.94);
    float footprint = exp(-3.0 * dot(offset, offset));
    float key_depth = 0.42 * sin(3.14159 * UV2.y) * (0.7 + 0.3 * sin(3.14159 * UV2.x));
    VERTEX.z += (1.0 - footprint) * flex * key_depth;
}

float eye_depth(vec2 uv, mat4 inverse_projection) {
    vec4 p = inverse_projection * vec4(uv * 2.0 - 1.0, textureLod(scene_depth, uv, 0.0).r, 1.0);
    return -p.z / p.w;
}

void fragment() {
    vec2 domain = clamp(UV2, vec2(0.0), vec2(1.0));
    vec2 field = texture(silk, UV).rg * 2.0 - 1.0;
    float drift = 0.009 * sin(art_clock * 0.8 + domain.y * 4.0);
    float weave = texture(silk, UV + drift * field + vec2(0.0, art_clock * 0.014)).b;
    float gauze = texture(fray, UV).r;
    float hem_dist = min(domain.y, 1.0-domain.y);
    float side_dist = min(domain.x, 1.0-domain.x);
    float trim = max(1.0-smoothstep(0.002, 0.012, hem_dist), 1.0-smoothstep(0.001, 0.006, side_dist));
    float stitch = exp(-abs(hem_dist-0.025)*370.0) * (0.4 + 0.6*weave);
    float grazing = pow(1.0-clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 1.7);
    float lustre = 0.22+0.42*weave+0.36*grazing;
    float edge = clamp(trim + stitch*0.8 + grazing*0.52, 0.0, 1.0);
    vec3 fibre = mix(silk_dye.rgb * (0.52+lustre), selvage.rgb, edge*0.7);
    float metal_edge = edge_gain*(edge + 0.32*lustre);
    // A fracture exit peels open the authored gore cuts. It never samples X13.
    float cuts = min(abs(domain.x-0.31),abs(domain.x-0.66));
    float tear_order = 0.32*gauze + 0.37*(1.0-domain.y) + 0.31*min(1.0, cuts*5.8);
    float remnant = smoothstep(erosion_threshold-0.045, erosion_threshold+0.018, tear_order);
    // Map the contact displacement into the current UV0 tangent chart.
    // On edge-on hems the chart degenerates; the bounded metric fallback
    // keeps the contact footprint stable.
    vec2 offset = cloth_position - contact_local.xy;
    vec2 dx = dFdx(cloth_position);
    vec2 dy = dFdy(cloth_position);
    vec2 uv_dx = dFdx(UV), uv_dy = dFdy(UV);
    float det = dx.x*dy.y - dx.y*dy.x;
    vec2 stretch = offset;
    if (abs(det) > 0.00000001) {
        vec2 screen_delta = vec2(offset.x*dy.y-offset.y*dy.x, dx.x*offset.y-dx.y*offset.x)/det;
        stretch = (uv_dx*screen_delta.x + uv_dy*screen_delta.y)*vec2(5.8,-2.2);
    }
    vec2 crack_uv = stretch/vec2(2.05,1.82)+0.5;
    float stress = 0.0;
    if (load_ratio > 0.0 && all(greaterThan(crack_uv,vec2(0.0))) && all(lessThan(crack_uv,vec2(1.0)))) {
        stress = smoothstep(0.035,0.68,texture(crack, crack_uv).r)*load_ratio
            * (1.0-smoothstep(0.93,1.25,length(offset)));
    }
    float depth_here = -VERTEX.z;
    float depth_gap = eye_depth(SCREEN_UV, INV_PROJECTION_MATRIX)-depth_here;
    float intersection = smoothstep(-0.008,0.095,depth_gap);
    vec3 optics = vec3(0.0);
    if (distortion > 0.0) {
        vec2 bend = NORMAL.xy*0.7 + field*0.18;
        vec2 sample_uv = clamp(SCREEN_UV + bend*distortion*(0.3+lustre), vec2(0.001),vec2(0.999));
        float safe = smoothstep(0.01,0.18,eye_depth(sample_uv, INV_PROJECTION_MATRIX)-depth_here);
        optics = textureLod(screen_color, mix(SCREEN_UV,sample_uv,safe), 0.0).rgb;
        fibre *= 0.085;
    }
    ALBEDO = fibre;
    ROUGHNESS = mix(0.63, 0.33, lustre);
    SPECULAR = (1.0-absorption)*0.36;
    vec3 dark_nap = absorption * vec3(0.012,0.010,0.019) * (0.24+0.66*lustre+0.10*gauze);
    EMISSION = dark_nap + optics*(0.94-0.12*edge) + selvage.rgb*metal_edge + vec3(1.0,0.65,0.33)*stress*2.15;
    ALPHA = clamp(density*(0.53+0.38*weave+0.29*gauze)+edge*0.27+absorption*0.29+stress*0.75,0.0,0.98)
        * remnant * intersection * (1.0-smoothstep(0.89,1.0,closure));
}
