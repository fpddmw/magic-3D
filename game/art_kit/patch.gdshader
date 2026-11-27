shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;
#include "res://art_kit/palette.gdshaderinc"
void fragment(){
    float edge=length(fwidth(UV))*3.;
    float seam=abs(UV.x-.5)+abs(UV.y-.5);
    float film=UV.y+cos(UV.x*7.)*.06;
    vec4 layer=palette(smoothstep(.45-edge,.5,max(abs(UV.x-.5),abs(UV.y-.5))),adapter<3.?seam:film,UV);
    ALBEDO=layer.rgb; ALPHA=layer.a;
}
