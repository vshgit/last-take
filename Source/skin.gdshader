shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D skin_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform vec3 tint : source_color = vec3(.91,.88,.85);
uniform float normal_strength = .24;
varying vec3 local_pos;
void vertex(){local_pos=VERTEX;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec3 c=texture(skin_tex,UV).rgb;
 ALBEDO=c*tint;
 NORMAL_MAP=texture(skin_normal,UV).rgb;
 NORMAL_MAP_DEPTH=normal_strength;
 float pores=hash(floor(UV*2048.));
 float gloss=clamp((c.r-c.b)*2.,0.,1.);
 ROUGHNESS=.57+pores*.09-gloss*.07;
 SPECULAR=.32;
}
