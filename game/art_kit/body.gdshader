shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;
#include "res://art_kit/palette.gdshaderinc"
void fragment(){
    float facets=floor(UV.x*8.)/8.+UV.y;
    float grazing=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),3.);
    float pattern=adapter<1.?facets:UV.x+abs(UV.y-.5);
    vec4 layer=palette(grazing,pattern,UV);
    ALBEDO=layer.rgb; ALPHA=layer.a;
}
