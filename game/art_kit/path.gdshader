shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;
#include "res://art_kit/palette.gdshaderinc"
void fragment(){
    float ridge=sin(UV.y*38.+beat*2.);
    float thread=UV.x+(adapter<2.?ridge*.11:sin(UV.y*15.)*.04);
    vec4 layer=palette(pow(abs(ridge),12.),thread,UV);
    ALBEDO=layer.rgb; ALPHA=layer.a;
}
