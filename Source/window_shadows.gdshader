shader_type spatial;
render_mode unshaded,blend_mix,cull_disabled,depth_draw_never,shadows_disabled;
uniform float passage=-1.0;
float stripe(float x,float center,float width){return 1.-smoothstep(width*.65,width,abs(x-center));}
void fragment(){
 float active=step(0.,passage)*(1.-step(1.,passage));
 float center=mix(-.35,1.35,passage);float gait=sin(passage*10.68);
 float left=center-.065+gait*.09*UV.y;float right=center+.065-gait*.09*UV.y;
 float legs=max(stripe(UV.x,left,.040),stripe(UV.x,right,.042));
 float shoes=max(stripe(UV.x,left+.025,.065),stripe(UV.x,right+.026,.065))*smoothstep(.77,.89,UV.y);
 ALBEDO=vec3(.015,.020,.023);ALPHA=max(legs,shoes)*active*.63;
}
