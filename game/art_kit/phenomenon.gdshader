shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;
uniform float beat : hint_range(0,1)=0.0;
uniform float emphasis : hint_range(0,1)=1.0;
uniform float adapter=0.0;
uniform float accent=0.09;
uniform vec4 tint : source_color=vec4(.46,.72,.78,1.);
void fragment(){
    float rim=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),3.);
    float grain=sin(UV.x*85.+sin(UV.y*51.));
    float line=fract(UV.y*(3.+mod(adapter,4.))+UV.x*step(3.,adapter)-beat);
    float seam=1.-smoothstep(0.,accent,min(line,1.-line)*2.);
    float core=max(seam,rim*.45);
    ALBEDO=tint.rgb*(.13+core*(.8+emphasis));
    ALPHA=(.035+core*(.45+.1*grain))*(.4+.6*emphasis);
}
