shader_type spatial;
render_mode unshaded,blend_add,depth_draw_never,cull_disabled;
uniform sampler2D frame_tex : source_color, filter_linear_mipmap;
uniform bool show_frame=false;
uniform vec2 content_scale=vec2(1.0);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 float edge=smoothstep(0.,.04,UV.x)*smoothstep(0.,.04,UV.y)*smoothstep(0.,.04,1.-UV.x)*smoothstep(0.,.04,1.-UV.y);
 float frame=floor(TIME*24.);
 vec2 jitter=vec2(hash(vec2(frame,3.)),hash(vec2(frame,17.)))-.5;
 vec2 uv=(UV-.5)/content_scale+.5+jitter*.0012;
 float inside=step(0.,uv.x)*step(uv.x,1.)*step(0.,uv.y)*step(uv.y,1.);
 vec3 c=texture(frame_tex,clamp(uv,vec2(0.),vec2(1.))).rgb*inside;
 float grain=(hash(floor(UV*vec2(1200.,800.))+frame)-.5)*.025;
 float scratch=step(.9975,hash(vec2(floor(UV.x*930.),floor(frame/8.))))*.06;
 ALBEDO=max(c+grain-scratch,vec3(0.))*vec3(.93,.95,.88)*(.96+.012*sin(TIME*47.)+.008*sin(TIME*113.));
 ALPHA=show_frame?edge:0.0;
}
