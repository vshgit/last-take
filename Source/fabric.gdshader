shader_type spatial;
render_mode cull_disabled;
uniform vec3 cloth_color : source_color = vec3(.27,.31,.29);
uniform float cloth_scale = 1.0;
uniform float grime_amount = .22;
varying vec3 local_pos;
void vertex(){local_pos=VERTEX;}
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1)),f.x),f.y);}
void fragment(){
 vec2 p=(local_pos.xy+local_pos.yz*.37)*cloth_scale;
 // World-sized staining stays consistent across the tiny UV islands of the
 // sewn lapels and the larger panels of the robe.
 vec2 cloth_pos=local_pos.xy+local_pos.yz*.37;
 float grime=n(cloth_pos*18.)*.5+n(cloth_pos*61.)*.3+n(cloth_pos*177.)*.2;
 float weave=sin(p.x*8000.)*sin(p.y*8000.);
 float aa=1.-smoothstep(.3,1.2,max(fwidth(p.x),fwidth(p.y))*8000.);
 vec3 base=cloth_color*(.87+grime*.17);
 base=mix(base,vec3(.11,.085,.061),smoothstep(.65,.78,n(cloth_pos*15.+.7))*grime_amount);
 ALBEDO=base+vec3(weave*.008*aa);
 NORMAL_MAP=normalize(vec3(cos(p.x*8000.)*.045*aa,sin(p.y*8000.)*.045*aa,1.))*.5+.5;
 ROUGHNESS=.88;SPECULAR=.24;
}
