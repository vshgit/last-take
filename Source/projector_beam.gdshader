shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled;
uniform float strength = .025;
void fragment(){
 float soft_edge=pow(abs(dot(normalize(NORMAL),normalize(VIEW))),.70);
 float longitudinal=smoothstep(0.0,.04,UV.y)*(1.0-.5*UV.y);
 ALBEDO=vec3(.71,.77,.74);
 ALPHA=strength*soft_edge*longitudinal;
}
