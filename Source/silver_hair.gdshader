shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D hair_tex : source_color,filter_linear_mipmap_anisotropic;
void fragment(){
 vec4 tex=texture(hair_tex,UV);
 float tone=clamp(dot(tex.rgb,vec3(.3,.59,.11)),0.,1.);
 ALBEDO=mix(vec3(.035,.040,.037),vec3(.21,.22,.20),sqrt(tone));
 ALPHA=tex.a;ALPHA_SCISSOR_THRESHOLD=.40;
 ROUGHNESS=.72;SPECULAR=.25;
}
