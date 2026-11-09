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
 float front=smoothstep(.07,.12,local_pos.z)*(1.-smoothstep(.05,.073,abs(local_pos.x)));
 float a=exp(-pow((local_pos.y-1.622-.0015*cos(local_pos.x*80.))/.0008,2.));
 float b=exp(-pow((local_pos.y-1.633-.0012*cos(local_pos.x*74.))/.0007,2.));
 float d=exp(-pow((local_pos.y-1.644-.0009*cos(local_pos.x*69.))/.0006,2.));
 float wrinkles=(a+b+d)*front;
 ALBEDO=c*tint*(1.-wrinkles*.12);
 NORMAL_MAP=texture(skin_normal,UV).rgb;
 NORMAL_MAP_DEPTH=normal_strength;
 float pores=hash(floor(UV*2048.));
 float gloss=clamp((c.r-c.b)*2.,0.,1.);
 ROUGHNESS=.57+pores*.09-gloss*.07;
 SPECULAR=.32;
}
