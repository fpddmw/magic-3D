shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;
#include "res://art_kit/palette.gdshaderinc"
void fragment(){
    float shell=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),2.);
    float pattern=adapter<4.?UV.x+UV.y+sin(UV.x*21.)*.19:length(UV-.5);
    vec4 layer=palette(shell,pattern,UV);
    ALBEDO=layer.rgb; ALPHA=layer.a;
}
