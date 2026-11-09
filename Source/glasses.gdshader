shader_type spatial;
render_mode blend_mix,depth_draw_never,cull_disabled;
void fragment(){
 vec2 p=UV-.5;
 float lens=1.-smoothstep(.43,.50,length(p*vec2(.9,1.0)));
 float slash=exp(-pow((p.y+p.x*.38-.10)/.055,2.));
 float small=exp(-dot(p-vec2(.16,.12),p-vec2(.16,.12))*105.);
 float facing=pow(max(dot(normalize(NORMAL),normalize(VIEW)),0.),7.);
 ALBEDO=vec3(.09,.11,.10);ROUGHNESS=.09;SPECULAR=.9;
 EMISSION=vec3(.24,.26,.23)*(slash*.42+small*.65)*facing;
 ALPHA=lens*(.07+(slash*.30+small*.45)*facing);
}
