shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform vec3 cloth_color : source_color = vec3(.57,.52,.45);
varying vec3 p;
void vertex(){p=VERTEX;}
float hash(vec3 a){return fract(sin(dot(a,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 a){
 vec3 i=floor(a);vec3 f=fract(a);f=f*f*(3.-2.*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void fragment(){
 float stains=noise(p*18.)*.67+noise(p*49.)*.33;
 float dirt=smoothstep(.59,.80,stains)*.22+smoothstep(.8,.95,noise(p*240.))*.10;
 float edge=(1.-smoothstep(.39,.52,p.y))*.08;
 float loops=noise(p*780.);
 ALBEDO=cloth_color*(.88+loops*.18)*(1.-dirt-edge);
 ROUGHNESS=.96;SPECULAR=.16;
 NORMAL_MAP=vec3(.5+sin(p.x*1700.)*.045,.5+sin(p.y*1300.)*.045,1.);
 NORMAL_MAP_DEPTH=.20;
}
