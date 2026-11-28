shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_test_disabled, depth_draw_never;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D turbulence : repeat_enable, filter_linear;
uniform float inner_radius = .8;
uniform float outer_radius = .99;
uniform float density = .39;
uniform float phase = 0.;
uniform float strength = 1.;
varying vec3 center_view;
void vertex() {
    center_view = (MODELVIEW_MATRIX * vec4(0.,0.,0.,1.)).xyz;
    VERTEX = NORMAL * outer_radius;
}
void fragment(){
    vec3 dir = normalize(VERTEX);
    float centre = dot(center_view,dir);
    float b2 = max(0.,dot(center_view,center_view)-centre*centre);
    float outer_half = sqrt(max(0.,outer_radius*outer_radius-b2));
    float entry = max(0., centre - outer_half);
    float exit_distance = centre + outer_half;
    if (b2 < inner_radius*inner_radius) {
        exit_distance = min(exit_distance, centre-sqrt(inner_radius*inner_radius-b2));
    }
    float d=texture(scene_depth,SCREEN_UV).r;
    vec4 hit=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.-1.,d,1.);
    if(d>0.000001){exit_distance=min(exit_distance,length(hit.xyz/hit.w));}
    float path=max(0.,exit_distance-entry);
    vec3 radial=normalize(dir*(entry+.45*path)-center_view);
    vec3 world_dir=(INV_VIEW_MATRIX*vec4(radial,0.)).xyz;
    float grit = texture(turbulence,world_dir.xz*.47+world_dir.y*.19+vec2(phase*.009,0.)).b;
    float lit = smoothstep(-.7,.85,dot(world_dir,normalize(vec3(-.65,.58,.4))));
    float falloff=smoothstep(0.,outer_radius-inner_radius,path);
    float T=exp(-path*density*(.28+1.5*grit)*falloff);
    ALBEDO=mix(vec3(.095,.19,.27),vec3(.52,.65,.85),lit);
    ALPHA=clamp((1.-T)*strength*(.22+.78*lit),0.,.82);
}
